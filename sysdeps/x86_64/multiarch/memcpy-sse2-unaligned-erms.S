#define VEC_SIZE	16
#define VEC(i)		xmm##i
#define VMOVU		movdqu
#define VMOVA		movdqa

#define MEMCPY			__memcpy_sse2_unaligned_2
#define MEMCPY_ERMS		__memcpy_sse2_unaligned_erms
#define MEMPCPY			__mempcpy_sse2_unaligned
#define MEMPCPY_ERMS		__mempcpy_sse2_unaligned_erms
#define MEMMOVE			__memmove_sse2_unaligned
#define MEMMOVE_ERMS		__memmove_sse2_unaligned_erms
#define MEMCPY_CHK		__memcpy_chk_sse2_unaligned
#define MEMCPY_CHK_ERMS		__memcpy_chk_sse2_unaligned_erms
#define MEMPCPY_CHK		__mempcpy_chk_sse2_unaligned
#define MEMPCPY_CHK_ERMS	__mempcpy_chk_sse2_unaligned_erms
#define MEMMOVE_CHK		__memmove_chk_sse2_unaligned
#define MEMMOVE_CHK_ERMS	__memmove_chk_sse2_unaligned_erms

#include "memcpy-vec-unaligned-erms.S"
