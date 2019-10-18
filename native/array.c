#include "factor.h"

/* untagged */
F_ARRAY* allot_array(CELL type, CELL capacity)
{
	F_ARRAY* array;
	array = allot_object(type,sizeof(F_ARRAY) + capacity * CELLS);
	array->capacity = capacity;
	return array;
}

/* untagged */
F_ARRAY* array(CELL capacity, CELL fill)
{
	int i;

	F_ARRAY* array = allot_array(ARRAY_TYPE, capacity);

	for(i = 0; i < capacity; i++)
		put(AREF(array,i),fill);

	return array;
}

F_ARRAY* grow_array(F_ARRAY* array, CELL capacity, CELL fill)
{
	/* later on, do an optimization: if end of array is here, just grow */
	int i;
	F_ARRAY* new_array;

	if(array->capacity >= capacity)
		return array;

	new_array = allot_array(untag_header(array->header),capacity);

	memcpy(new_array + 1,array + 1,array->capacity * CELLS);

	for(i = array->capacity; i < capacity; i++)
		put(AREF(new_array,i),fill);

	return new_array;
}

void primitive_grow_array(void)
{
	F_ARRAY* array = untag_array(dpop());
	CELL capacity = to_fixnum(dpop());
	dpush(tag_object(grow_array(array,capacity,F)));
}

F_ARRAY* shrink_array(F_ARRAY* array, CELL capacity)
{
	F_ARRAY* new_array = allot_array(untag_header(array->header),capacity);
	memcpy(new_array + 1,array + 1,capacity * CELLS);
	return new_array;
}

void fixup_array(F_ARRAY* array)
{
	int i = 0;
	for(i = 0; i < array->capacity; i++)
		data_fixup((void*)AREF(array,i));
}

void collect_array(F_ARRAY* array)
{
	int i = 0;
	for(i = 0; i < array->capacity; i++)
		copy_object((void*)AREF(array,i));
}