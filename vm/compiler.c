#include "factor.h"

/* References to undefined symbols are patched up to call this function on
image load */
void undefined_symbol(void)
{
	simple_error(ERROR_UNDEFINED_SYMBOL,F,F);
}

#define CREF(array,i) ((CELL)(array) + CELLS * (i))

INLINE CELL get_literal(CELL literal_start, CELL num)
{
	return get(CREF(literal_start,num));
}

/* Look up an external library symbol referenced by a compiled code block */
void *get_rel_symbol(F_REL *rel, CELL literal_start)
{
	CELL arg = REL_ARGUMENT(rel);
	F_ARRAY *pair = untag_array(get_literal(literal_start,arg));
	F_SYMBOL *symbol = alien_offset(get(AREF(pair,0)));
	CELL library = get(AREF(pair,1));
	F_DLL *dll = (library == F ? NULL : untag_dll(library));

	if(dll != NULL && !dll->dll)
		return undefined_symbol;

	if(!symbol)
		return undefined_symbol;

	void *sym = ffi_dlsym(dll,symbol,false);

	if(sym)
		return sym;
	else
		return undefined_symbol;
}

/* Compute an address to store at a relocation */
INLINE CELL compute_code_rel(F_REL *rel,
	CELL code_start, CELL literal_start, CELL words_start)
{
	switch(REL_TYPE(rel))
	{
	case RT_PRIMITIVE:
		return (CELL)primitive_to_xt(REL_ARGUMENT(rel));
	case RT_DLSYM:
		return (CELL)get_rel_symbol(rel,literal_start);
	case RT_LITERAL:
		return CREF(literal_start,REL_ARGUMENT(rel));
	case RT_DISPATCH:
		return CREF(words_start,REL_ARGUMENT(rel));
	case RT_XT:
		return get(CREF(words_start,REL_ARGUMENT(rel)));
	case RT_LABEL:
		return code_start + REL_ARGUMENT(rel);
	default:
		critical_error("Bad rel type",rel->type);
		return -1;
	}
}

/* Store a 32-bit value into a PowerPC LIS/ORI sequence */
INLINE void reloc_set_2_2(CELL cell, CELL value)
{
	put(cell - CELLS,((get(cell - CELLS) & ~0xffff) | ((value >> 16) & 0xffff)));
	put(cell,((get(cell) & ~0xffff) | (value & 0xffff)));
}

/* Store a value into a bitfield of a PowerPC instruction */
INLINE void reloc_set_masked(CELL cell, F_FIXNUM value, CELL mask, F_FIXNUM shift)
{
	u32 original = *(u32*)cell;
	original &= ~mask;
	*(u32*)cell = (original | ((value >> shift) & mask));
}

/* Perform a fixup on a code block */
void apply_relocation(F_REL *rel,
	CELL code_start, CELL literal_start, CELL words_start)
{
	CELL offset = rel->offset + code_start;
	F_FIXNUM absolute_value = compute_code_rel(rel,
		code_start,literal_start,words_start);
	F_FIXNUM relative_value = absolute_value - offset;

	switch(REL_CLASS(rel))
	{
	case RC_ABSOLUTE_CELL:
		put(offset,absolute_value);
		break;
	case RC_ABSOLUTE:
		*(u32*)offset = absolute_value;
		break;
	case RC_RELATIVE:
		*(u32*)offset = relative_value - sizeof(u32);
		break;
	case RC_ABSOLUTE_PPC_2_2:
		reloc_set_2_2(offset,absolute_value);
		break;
	case RC_RELATIVE_PPC_2:
		reloc_set_masked(offset,relative_value,REL_RELATIVE_PPC_2_MASK,0);
		break;
	case RC_RELATIVE_PPC_3:
		reloc_set_masked(offset,relative_value,REL_RELATIVE_PPC_3_MASK,0);
		break;
	case RC_RELATIVE_ARM_3:
		reloc_set_masked(offset,relative_value - CELLS * 2,
			REL_RELATIVE_ARM_3_MASK,2);
		break;
	case RC_INDIRECT_ARM:
		reloc_set_masked(offset,relative_value - CELLS,
			REL_INDIRECT_ARM_MASK,0);
		break;
	case RC_INDIRECT_ARM_PC:
		reloc_set_masked(offset,relative_value - CELLS * 2,
			REL_INDIRECT_ARM_MASK,0);
		break;
	default:
		critical_error("Bad rel class",REL_CLASS(rel));
		return;
	}
}

/* Perform all fixups on a code block */
void relocate_code_block(F_COMPILED *relocating, CELL code_start,
	CELL reloc_start, CELL literal_start, CELL words_start, CELL words_end)
{
	F_REL *rel = (F_REL *)reloc_start;
	F_REL *rel_end = (F_REL *)literal_start;

	while(rel < rel_end)
		apply_relocation(rel++,code_start,literal_start,words_start);
}

/* After compiling a batch of words, we replace all mutual word references with
direct XT references, and perform fixups */
void finalize_code_block(F_COMPILED *relocating, CELL code_start,
	CELL reloc_start, CELL literal_start, CELL words_start, CELL words_end)
{
	CELL scan;

	if(relocating->finalized != false)
		critical_error("Finalizing a finalized block",(CELL)relocating);

	for(scan = words_start; scan < words_end; scan += CELLS)
		put(scan,(CELL)(untag_word(get(scan))->xt));

	relocating->finalized = true;

	relocate_code_block(relocating,code_start,reloc_start,
		literal_start,words_start,words_end);

	flush_icache(code_start,reloc_start - code_start);
}

/* Write a sequence of integers to memory, with 'format' bytes per integer */
void deposit_integers(CELL here, F_VECTOR *vector, CELL format)
{
	CELL count = untag_fixnum_fast(vector->top);
	F_ARRAY *array = untag_array_fast(vector->array);
	CELL i;

	for(i = 0; i < count; i++)
	{
		F_FIXNUM value = to_fixnum(get(AREF(array,i)));
		if(format == 1)
			cput(here + i,value);
		else if(format == sizeof(unsigned int))
			*(unsigned int *)(here + format * i) = value;
		else if(format == CELLS)
			put(CREF(here,i),value);
		else
			critical_error("Bad format in deposit_integers()",format);
	}
}

/* Write a sequence of tagged pointers to memory */
void deposit_objects(CELL here, F_VECTOR *vector, CELL literal_length)
{
	F_ARRAY *array = untag_array_fast(vector->array);
	memcpy((void*)here,array + 1,literal_length);
}

#define FROB \
	CELL code_format = to_cell(get(ds)); \
	F_VECTOR *code = untag_vector(get(ds - CELLS)); \
	F_VECTOR *words = untag_vector(get(ds - CELLS * 2)); \
	F_VECTOR *literals = untag_vector(get(ds - CELLS * 3)); \
	F_VECTOR *rel = untag_vector(get(ds - CELLS * 4)); \
	CELL code_length = align8(untag_fixnum_fast(code->top) * code_format); \
	CELL rel_length = untag_fixnum_fast(rel->top) * sizeof(unsigned int); \
	CELL literal_length = untag_fixnum_fast(literals->top) * CELLS; \
	CELL words_length = untag_fixnum_fast(words->top) * CELLS;

void primitive_add_compiled_block(void)
{
	CELL start;

	{
		/* Read parameters from stack, leaving them on the stack */
		FROB

		/* Try allocating a new code block */
		CELL total_length = sizeof(F_COMPILED) + code_length
			+ rel_length + literal_length + words_length;

		start = heap_allot(&code_heap,total_length);

		/* If allocation failed, do a code GC */
		if(start == 0)
		{
			primitive_code_gc();
			start = heap_allot(&code_heap,total_length);

			/* Insufficient room even after code GC, give up */
			if(start == 0)
				critical_error("Out of memory in add-compiled-block",0);
		}
	}

	/* we have to read the parameters again, since we may have called
	GC above in which case the data heap semi-spaces will have switched */
	FROB

	/* now we can pop the parameters from the stack */
	ds -= CELLS * 5;

	/* begin depositing the code block's contents */
	CELL here = start;

	/* compiled header */
	F_COMPILED header;
	header.code_length = code_length;
	header.reloc_length = rel_length;
	header.literal_length = literal_length;
	header.words_length = words_length;
	header.finalized = false;

	memcpy((void*)here,&header,sizeof(F_COMPILED));
	here += sizeof(F_COMPILED);

	/* code */
	deposit_integers(here,code,code_format);
	here += code_length;

	/* relation info */
	deposit_integers(here,rel,sizeof(unsigned int));
	here += rel_length;

	/* literals */
	deposit_objects(here,literals,literal_length);
	here += literal_length;

	/* words */
	deposit_objects(here,words,words_length);
	here += words_length;

	/* push the XT of the new word on the stack */
	F_WORD *word = allot_word(F,F);
	word->xt = (XT)(start + sizeof(F_COMPILED));
	word->compiledp = T;
	dpush(tag_word(word));
}

#undef FROB

/* After batch compiling a bunch of words, perform various fixups to make them
executable */
void primitive_finalize_compile(void)
{
	F_ARRAY *array = untag_array(dpop());

	/* set word XT's */
	CELL count = untag_fixnum_fast(array->capacity);
	CELL i;
	for(i = 0; i < count; i++)
	{
		F_ARRAY *pair = untag_array(get(AREF(array,i)));
		F_WORD *word = untag_word(get(AREF(pair,0)));
		XT xt = untag_word(get(AREF(pair,1)))->xt;
		F_BLOCK *block = xt_to_block(xt);
		if(block->status != B_ALLOCATED)
			critical_error("bad XT",(CELL)xt);

		word->xt = xt;
		word->compiledp = T;
	}

	/* perform relocation */
	for(i = 0; i < count; i++)
	{
		F_ARRAY *pair = untag_array(get(AREF(array,i)));
		F_WORD *word = untag_word(get(AREF(pair,0)));
		XT xt = word->xt;
		iterate_code_heap_step(xt_to_compiled(xt),finalize_code_block);
	}
}

void primitive_xt_map(void)
{
	GROWABLE_ARRAY(array);
	F_BLOCK *scan = first_block(&code_heap);

	while(scan)
	{
		if(scan->status != B_FREE)
		{
			F_COMPILED *compiled = (F_COMPILED *)(scan + 1);
			CELL code_start = (CELL)(compiled + 1);
			CELL literal_start = code_start
				+ compiled->code_length
				+ compiled->reloc_length;

			CELL word = get_literal(literal_start,0);
			GROWABLE_ADD(array,word);
			REGISTER_ARRAY(array);
			CELL xt = allot_cell(code_start);
			UNREGISTER_ARRAY(array);
			GROWABLE_ADD(array,xt);
		}

		scan = next_block(&code_heap,scan);
	}

	GROWABLE_TRIM(array);

	dpush(tag_object(array));
}
