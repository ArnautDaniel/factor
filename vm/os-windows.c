#include "factor.h"

F_STRING *get_error_message()
{
	DWORD id = GetLastError();
	F_CHAR *msg = error_message(id);
	F_STRING *string = from_u16_string(msg);
	LocalFree(msg);
	return string;
}

/* You must LocalFree() the return value! */
F_CHAR *error_message(DWORD id)
{
	F_CHAR *buffer;
	int index;

	FormatMessage(
		FORMAT_MESSAGE_ALLOCATE_BUFFER |
		FORMAT_MESSAGE_FROM_SYSTEM,
		NULL,
		id,
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
		(LPTSTR)(void *) &buffer,
		0, NULL);

	/* strip whitespace from end */
	index = wcslen(buffer) - 1;
	while(index >= 0 && isspace(buffer[index]))
		buffer[index--] = 0;

	return buffer;
}

s64 current_millis(void)
{
	FILETIME t;
	GetSystemTimeAsFileTime(&t);
	return (((s64)t.dwLowDateTime | (s64)t.dwHighDateTime<<32)
		- EPOCH_OFFSET) / 10000;
}

void ffi_dlopen (F_DLL *dll, bool error)
{
	HMODULE module = LoadLibrary(alien_offset(dll->path));

	if (!module)
	{
		dll->dll = NULL;
		if(error)
			simple_error(ERROR_FFI,F,
				tag_object(get_error_message()));
		else
			return;
	}

	dll->dll = module;
}

void *ffi_dlsym (F_DLL *dll, F_SYMBOL *symbol, bool error)
{
	void *sym = GetProcAddress(
		dll ? (HMODULE)dll->dll : GetModuleHandle(NULL),
		symbol);

	if (!sym)
	{
		if(error)
			simple_error(ERROR_FFI,
				tag_object(from_symbol_string(symbol)),
				tag_object(get_error_message()));
		else
			return NULL;
	}

	return sym;
}

void ffi_dlclose(F_DLL *dll)
{
	FreeLibrary((HMODULE)dll->dll);
	dll->dll = NULL;
}

void primitive_stat(void)
{
	WIN32_FILE_ATTRIBUTE_DATA st;

	if(!GetFileAttributesEx(
		unbox_u16_string(),
		GetFileExInfoStandard,
		&st))
	{
		dpush(F);
		dpush(F);
		dpush(F);
		dpush(F);
	}
	else
	{
		box_boolean(st.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY);
		box_signed_4(0);
		box_unsigned_8(
			(s64)st.nFileSizeLow | (s64)st.nFileSizeHigh << 32);
		box_unsigned_8((int)
			((*(s64*)&st.ftLastWriteTime - EPOCH_OFFSET) / 10000000));
	}
}

void primitive_read_dir(void)
{
	HANDLE dir;
	WIN32_FIND_DATA find_data;
	F_CHAR path[MAX_PATH + 4];

	snwprintf(path, MAX_PATH + 4, STR_FORMAT "\\*", unbox_u16_string());

	GROWABLE_ARRAY(result);

	if(INVALID_HANDLE_VALUE != (dir = FindFirstFile(path, &find_data)))
	{
		do
		{
			REGISTER_ARRAY(result);
			CELL name = tag_object(from_u16_string(
				find_data.cFileName));
			UNREGISTER_ARRAY(result);
			GROWABLE_ADD(result,name);
		}
		while (FindNextFile(dir, &find_data));
		CloseHandle(dir);
	}

	GROWABLE_TRIM(result);

	dpush(tag_object(result));
}

void primitive_cwd(void)
{
	F_CHAR buf[MAX_PATH];

	if(!GetCurrentDirectory(MAX_PATH, buf))
		io_error();

	box_u16_string(buf);
}

void primitive_cd(void)
{
	SetCurrentDirectory(unbox_u16_string());
}

F_SEGMENT *alloc_segment(CELL size)
{
	char *mem;
	DWORD ignore;

	if((mem = (char *)VirtualAlloc(NULL, getpagesize() * 2 + size,
		MEM_COMMIT, PAGE_EXECUTE_READWRITE)) == 0)
		fatal_error("Out of memory in alloc_segment",0);

	if (!VirtualProtect(mem, getpagesize(), PAGE_NOACCESS, &ignore))
		fatal_error("Cannot allocate low guard page", (CELL)mem);

	if (!VirtualProtect(mem + size + getpagesize(),
		getpagesize(), PAGE_NOACCESS, &ignore))
		fatal_error("Cannot allocate high guard page", (CELL)mem);

	F_SEGMENT *block = safe_malloc(sizeof(F_SEGMENT));

	block->start = (CELL)mem + getpagesize();
	block->size = size;
	block->end = block->start + size;

	return block;
}

void dealloc_segment(F_SEGMENT *block)
{
	SYSTEM_INFO si;
	GetSystemInfo(&si);
	if(!VirtualFree((void*)(block->start - si.dwPageSize), 0, MEM_RELEASE))
		fatal_error("dealloc_segment failed",0);
	free(block);
}

long getpagesize(void)
{
	static long g_pagesize = 0;
	if (! g_pagesize)
	{
		SYSTEM_INFO system_info;
		GetSystemInfo (&system_info);
		g_pagesize = system_info.dwPageSize;
	}
	return g_pagesize;
}

const char *default_image_path(void)
{
	return "factor.image";
}

/* SEH support. Proceed with caution. */
typedef long exception_handler_t(
	PEXCEPTION_RECORD rec, void *frame, void *context, void *dispatch);

typedef struct exception_record
{
	struct exception_record *next_handler;
	void *handler_func;
} exception_record_t;

void seh_call(void (*func)(), exception_handler_t *handler)
{
	exception_record_t record;
	asm volatile("mov %%fs:0, %0" : "=r" (record.next_handler));
	asm volatile("mov %0, %%fs:0" : : "r" (&record));
	record.handler_func = handler;
	func();
	asm volatile("mov %0, %%fs:0" : "=r" (record.next_handler));
}

static long exception_handler(PEXCEPTION_RECORD rec, void *frame, void *ctx, void *dispatch)
{
	memory_protection_error(rec->ExceptionInformation[1],
		SIGSEGV,native_stack_pointer());
	return -1; /* unreachable */
}

void run(void)
{
	interpreter();
}

void run_toplevel(void)
{
	seh_call(run, exception_handler);
}
