#define FACTOR_CPU_STRING "x86"

register CELL ds asm("esi");
register CELL rs asm("edi");
void **primitives;

INLINE void flush_icache(CELL start, CELL len) {}

void *native_stack_pointer(void);

typedef CELL F_COMPILED_FRAME;

#define PREVIOUS_FRAME(frame) (frame + 1)
#define RETURN_ADDRESS(frame) (*(frame))

void execute(F_WORD *word);
