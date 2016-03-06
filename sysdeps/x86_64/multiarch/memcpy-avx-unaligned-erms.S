#define VEC_SIZE	32
#define VEC(i)		ymm##i
#define VMOVU		vmovdqu
#define VMOVA		vmovdqa

#define MEMCPY_ERMS		__memcpy_avx_unaligned_erms
#define MEMPCPY_ERMS		__mempcpy_avx_unaligned_erms
#define MEMMOVE_ERMS		__memmove_avx_unaligned_erms
#define MEMCPY_CHK_ERMS		__memcpy_chk_avx_unaligned_erms
#define MEMPCPY_CHK_ERMS	__mempcpy_chk_avx_unaligned_erms
#define MEMMOVE_CHK_ERMS	__memmove_chk_avx_unaligned_erms

#include "memcpy-vec-unaligned-erms.S"
