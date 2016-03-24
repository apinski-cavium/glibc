#define VEC_SIZE	64
#define VEC(i)		zmm##i
#define VMOVU		vmovdqu64
#define VMOVA		vmovdqa64

#define MEMCPY_ERMS		__memcpy_avx512_unaligned_erms
#define MEMPCPY_ERMS		__mempcpy_avx512_unaligned_erms
#define MEMMOVE_ERMS		__memmove_avx512_unaligned_erms
#define MEMCPY_CHK_ERMS		__memcpy_chk_avx512_unaligned_erms
#define MEMPCPY_CHK_ERMS	__mempcpy_chk_avx512_unaligned_erms
#define MEMMOVE_CHK_ERMS	__memmove_chk_avx512_unaligned_erms

#include "memcpy-vec-unaligned-erms.S"
