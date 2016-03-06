/* memcpy/mempcpy/memmove with vector unaliged loads and rep movsb
   Copyright (C) 2016 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

/* memcpy/mempcpy/memmove is implemented as:
   1. If size is 2 * VEC_SIZE or below, load all sources into registers
      first and copy them to destination together.
   2. If there is no overflap, copy from both ends with 4 * VEC_SIZE
      at a time.
   3. If size is less than 8 * VEC_SIZE, load all sources into registers
      first and copy them to destination together.
   4. If address of destination > address of source, copy 8 * VEC_SIZE
      at a time backward.
   5. Otherwise, copy * VEC_SIZE at a time forward.
 */

#if IS_IN (libc)

# include <sysdep.h>
# include "asm-syntax.h"

# ifndef VZEROUPPER
#  if VEC_SIZE > 16
#   define VZEROUPPER vzeroupper
#  else
#   define VZEROUPPER
#  endif
# endif

# ifdef MEMPCPY
#  ifdef SHARED
ENTRY (MEMPCPY_CHK)
	cmpq	%rdx, %rcx
	jb	HIDDEN_JUMPTARGET (__chk_fail)
END (MEMPCPY_CHK)
#  endif

ENTRY (MEMPCPY)
	mov	%rdi, %rax
	add	%rdx, %rax
	jmp	L(start)
END (MEMPCPY)
# endif

# ifdef MEMCPY
#  ifdef SHARED
ENTRY (MEMCPY_CHK)
	cmpq	%rdx, %rcx
	jb	HIDDEN_JUMPTARGET (__chk_fail)
END (MEMCPY_CHK)
#  endif

ENTRY (MEMCPY)
	movq	%rdi, %rax
L(start):
	cmpq	$VEC_SIZE, %rdx
	je	L(last_vec)
	jb	L(less_vec)
	cmpq	$(VEC_SIZE * 2), %rdx
	ja	L(more_2x_vec)
	VMOVU	(%rsi), %VEC(0)
	VMOVU	-VEC_SIZE(%rsi,%rdx), %VEC(1)
	VMOVU	%VEC(0), (%rdi)
	VMOVU	%VEC(1), -VEC_SIZE(%rdi,%rdx)
	VZEROUPPER
	ret
END (MEMCPY)
# endif

# ifdef SHARED
ENTRY (MEMPCPY_CHK_ERMS)
	cmpq	%rdx, %rcx
	jb	HIDDEN_JUMPTARGET (__chk_fail)
END (MEMPCPY_CHK_ERMS)

ENTRY (MEMPCPY_ERMS)
	mov	%rdi, %rax
	add	%rdx, %rax
	jmp	L(start_erms)
END (MEMPCPY_ERMS)

ENTRY (MEMCPY_CHK_ERMS)
	cmpq	%rdx, %rcx
	jb	HIDDEN_JUMPTARGET (__chk_fail)
END (MEMCPY_CHK_ERMS)
# endif

ENTRY(MEMCPY_ERMS)
	movq	%rdi, %rax
L(start_erms):
	cmpq	$VEC_SIZE, %rdx
	je	L(last_vec)
	jb	L(less_vec)
	cmpq	$REP_MOVSB_THRESHOLD, %rdx
	ja	L(movsb)
	cmpq	$(VEC_SIZE * 2), %rdx
	ja	L(more_2x_vec)
L(last_2x_vec):
	VMOVU	(%rsi), %VEC(0)
	VMOVU	-VEC_SIZE(%rsi,%rdx), %VEC(1)
	VMOVU	%VEC(0), (%rdi)
	VMOVU	%VEC(1), -VEC_SIZE(%rdi,%rdx)
	VZEROUPPER
	ret
L(movsb):
	movq	%rdx, %rcx
	cmpq	%rsi, %rdi
	jbe	L(movsb_forward)
	leaq	(%rsi,%rcx), %rdx
	cmpq	%rdx, %rdi
	jb	L(movsb_backward)
L(movsb_forward):
	rep movsb
	ret
L(movsb_backward):
	leaq	-1(%rdi,%rcx), %rdi
	leaq	-1(%rsi,%rcx), %rsi
	std
	rep movsb
	cld
	ret

L(last_vec):
	/* Last VEC.  */
	VMOVU	(%rsi), %VEC(0)
	VMOVU	%VEC(0), (%rdi)
L(return):
	VZEROUPPER
	ret

	.p2align 4,,10
	.p2align 4
L(more_2x_vec):
	/* More than 2 * VEC.  */
	cmpq	%rsi, %rdi
	jbe	L(copy_forward)
	leaq	(%rsi,%rdx), %rcx
	cmpq	%rcx, %rdi
	jb	L(more_2x_vec_overlap)
L(copy_forward):
	leaq	(%rdi,%rdx), %rcx
	cmpq	%rcx, %rsi
	jb	L(more_2x_vec_overlap)
	VMOVU	(%rsi), %VEC(0)
	VMOVU	VEC_SIZE(%rsi), %VEC(1)
	VMOVU	-VEC_SIZE(%rsi,%rdx), %VEC(2)
	VMOVU	-(VEC_SIZE * 2)(%rsi,%rdx), %VEC(3)
	VMOVU	%VEC(0), (%rdi)
	VMOVU	%VEC(1), VEC_SIZE(%rdi)
	VMOVU	%VEC(2), -VEC_SIZE(%rdi,%rdx)
	VMOVU	%VEC(3), -(VEC_SIZE * 2)(%rdi,%rdx)
	cmpq	$(VEC_SIZE * 4), %rdx
	jbe	L(return)
	VMOVU	(VEC_SIZE * 2)(%rsi), %VEC(0)
	VMOVU	(VEC_SIZE * 3)(%rsi), %VEC(1)
	VMOVU	-(VEC_SIZE * 3)(%rsi,%rdx), %VEC(2)
	VMOVU	-(VEC_SIZE * 4)(%rsi,%rdx), %VEC(3)
	VMOVU	%VEC(0), (VEC_SIZE * 2)(%rdi)
	VMOVU	%VEC(1), (VEC_SIZE * 3)(%rdi)
	VMOVU	%VEC(2), -(VEC_SIZE * 3)(%rdi,%rdx)
	VMOVU	%VEC(3), -(VEC_SIZE * 4)(%rdi,%rdx)
	cmpq	$(VEC_SIZE * 8), %rdx
	jbe	L(return)
	leaq	(VEC_SIZE * 4)(%rdi), %rcx
	addq	%rdi, %rdx
	andq	$-(VEC_SIZE * 4), %rdx
	andq	$-(VEC_SIZE * 4), %rcx
	movq	%rcx, %r11
	subq	%rdi, %r11
	addq	%r11, %rsi
	cmpq	%rdx, %rcx
	je	L(return)
	movq	%rsi, %r10
	subq	%rcx, %r10
	leaq	VEC_SIZE(%r10), %r9
	leaq	(VEC_SIZE * 2)(%r10), %r8
	leaq	(VEC_SIZE * 3)(%r10), %r11
	.p2align 4,,10
	.p2align 4
L(loop):
	VMOVU	(%rcx,%r10), %VEC(0)
	VMOVU	(%rcx,%r9), %VEC(1)
	VMOVU	(%rcx,%r8), %VEC(2)
	VMOVU	(%rcx,%r11), %VEC(3)
	VMOVA	%VEC(0), (%rcx)
	VMOVA	%VEC(1), VEC_SIZE(%rcx)
	VMOVA	%VEC(2), (VEC_SIZE * 2)(%rcx)
	VMOVA	%VEC(3), (VEC_SIZE * 3)(%rcx)
	addq	$(VEC_SIZE * 4), %rcx
	cmpq	%rcx, %rdx
	jne	L(loop)
	VZEROUPPER
	ret
L(less_vec):
	/* Less than 1 VEC.  */
# if VEC_SIZE != 16 && VEC_SIZE != 32
#  error Unsupported VEC_SIZE!
# endif
# if VEC_SIZE > 16
	cmpb	$16, %dl
	je	L(last_16)
	ja	L(between_15_31)
# endif
	cmpb	$8, %dl
	je	L(last_8)
	ja	L(between_9_15)
	cmpb	$4, %dl
	je	L(last_4)
	ja	L(between_5_7)
	cmpb	$2, %dl
	je	L(last_2)
	jb	L(between_0_1)
	movzwl	-2(%rsi,%rdx), %ecx
	movzbl	(%rsi), %esi
	movw	%cx, -2(%rdi,%rdx)
	movb	%sil, (%rdi)
	ret
L(between_0_1):
	testb	%dl, %dl
	je	1f
	movzbl	(%rsi), %ecx
	movb	%cl, (%rdi)
1:
	ret
# if VEC_SIZE > 16
L(between_15_31):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	-16(%rsi,%rdx), %xmm1
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm1, -16(%rdi,%rdx)
	ret
L(last_16):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	%xmm0, (%rdi)
	ret
# endif
L(between_9_15):
	movq	-8(%rsi,%rdx), %rcx
	movq	(%rsi), %rsi
	movq	%rcx, -8(%rdi,%rdx)
	movq	%rsi, (%rdi)
	ret
L(last_8):
	movq	(%rsi), %rcx
	movq	%rcx, (%rdi)
	ret
L(between_5_7):
	movl	-4(%rsi,%rdx), %ecx
	movl	(%rsi), %esi
	movl	%ecx, -4(%rdi,%rdx)
	movl	%esi, (%rdi)
	ret
L(last_4):
	movl	(%rsi), %ecx
	movl	%ecx, (%rdi)
	ret
L(last_2):
	movzwl	(%rsi), %ecx
	movw	%cx, (%rdi)
	ret

L(more_2x_vec_overlap):
	/* More than 2 * VEC and there is overlap bewteen destination
	   and source.  */
	cmpq	$(VEC_SIZE * 8), %rdx
	ja	L(more_8x_vec)
	cmpq	$(VEC_SIZE * 4), %rdx
	jb	L(last_4x_vec)
L(between_4x_vec_and_8x_vec):
	/* Copy from 4 * VEC to 8 * VEC, inclusively. */
	VMOVU	(%rsi), %VEC(0)
	VMOVU	VEC_SIZE(%rsi), %VEC(1)
	VMOVU	(VEC_SIZE * 2)(%rsi), %VEC(2)
	VMOVU	(VEC_SIZE * 3)(%rsi), %VEC(3)
	VMOVU	-VEC_SIZE(%rsi,%rdx), %VEC(4)
	VMOVU	-(VEC_SIZE * 2)(%rsi,%rdx), %VEC(5)
	VMOVU	-(VEC_SIZE * 3)(%rsi,%rdx), %VEC(6)
	VMOVU	-(VEC_SIZE * 4)(%rsi,%rdx), %VEC(7)
	VMOVU	%VEC(0), (%rdi)
	VMOVU	%VEC(1), VEC_SIZE(%rdi)
	VMOVU	%VEC(2), (VEC_SIZE * 2)(%rdi)
	VMOVU	%VEC(3), (VEC_SIZE * 3)(%rdi)
	VMOVU	%VEC(4), -VEC_SIZE(%rdi,%rdx)
	VMOVU	%VEC(5), -(VEC_SIZE * 2)(%rdi,%rdx)
	VMOVU	%VEC(6), -(VEC_SIZE * 3)(%rdi,%rdx)
	VMOVU	%VEC(7), -(VEC_SIZE * 4)(%rdi,%rdx)
	VZEROUPPER
	ret
L(last_4x_vec):
	/* Copy from 2 * VEC to 4 * VEC. */
	VMOVU	(%rsi), %VEC(0)
	VMOVU	VEC_SIZE(%rsi), %VEC(1)
	VMOVU	-VEC_SIZE(%rsi,%rdx), %VEC(2)
	VMOVU	-(VEC_SIZE * 2)(%rsi,%rdx), %VEC(3)
	VMOVU	%VEC(0), (%rdi)
	VMOVU	%VEC(1), VEC_SIZE(%rdi)
	VMOVU	%VEC(2), -VEC_SIZE(%rdi,%rdx)
	VMOVU	%VEC(3), -(VEC_SIZE * 2)(%rdi,%rdx)
	VZEROUPPER
	ret
L(between_0_and_4x_vec):
	/* Copy from 0 to 4 * VEC. */
	cmpl	$(VEC_SIZE * 2), %edx
	jae	L(last_4x_vec)
	/* Copy from 0 to 2 * VEC. */
	cmpl	$VEC_SIZE, %edx
	je	L(last_vec)
	ja	L(last_2x_vec)
	/* Copy from 0 to VEC. */
	VZEROUPPER
	jmp	L(less_vec)
L(more_8x_vec):
	cmpq	%rsi, %rdi
	ja	L(more_8x_vec_backward)

	.p2align 4,,10
	.p2align 4
L(loop_8x_vec_forward):
	/* Copy 8 * VEC a time forward.  */
	VMOVU	(%rsi), %VEC(0)
	VMOVU	VEC_SIZE(%rsi), %VEC(1)
	VMOVU	(VEC_SIZE * 2)(%rsi), %VEC(2)
	VMOVU	(VEC_SIZE * 3)(%rsi), %VEC(3)
	VMOVU	(VEC_SIZE * 4)(%rsi), %VEC(4)
	VMOVU	(VEC_SIZE * 5)(%rsi), %VEC(5)
	VMOVU	(VEC_SIZE * 6)(%rsi), %VEC(6)
	VMOVU	(VEC_SIZE * 7)(%rsi), %VEC(7)
	VMOVU	%VEC(0), (%rdi)
	VMOVU	%VEC(1), VEC_SIZE(%rdi)
	VMOVU	%VEC(2), (VEC_SIZE * 2)(%rdi)
	VMOVU	%VEC(3), (VEC_SIZE * 3)(%rdi)
	VMOVU	%VEC(4), (VEC_SIZE * 4)(%rdi)
	VMOVU	%VEC(5), (VEC_SIZE * 5)(%rdi)
	VMOVU	%VEC(6), (VEC_SIZE * 6)(%rdi)
	VMOVU	%VEC(7), (VEC_SIZE * 7)(%rdi)
	addq	$(VEC_SIZE * 8), %rdi
	addq	$(VEC_SIZE * 8), %rsi
	subq	$(VEC_SIZE * 8), %rdx
	cmpq	$(VEC_SIZE * 8), %rdx
	je	L(between_4x_vec_and_8x_vec)
	ja	L(loop_8x_vec_forward)
	/* Less than 8 * VEC to copy.  */
	cmpq	$(VEC_SIZE * 4), %rdx
	jb	L(between_0_and_4x_vec)
	jmp	L(between_4x_vec_and_8x_vec)

L(more_8x_vec_backward):
	leaq	-VEC_SIZE(%rsi, %rdx), %rcx
	leaq	-VEC_SIZE(%rdi, %rdx), %r9

	.p2align 4,,10
	.p2align 4
L(loop_8x_vec_backward):
	/* Copy 8 * VEC a time backward.  */
	VMOVU	(%rcx), %VEC(0)
	VMOVU	-VEC_SIZE(%rcx), %VEC(1)
	VMOVU	-(VEC_SIZE * 2)(%rcx), %VEC(2)
	VMOVU	-(VEC_SIZE * 3)(%rcx), %VEC(3)
	VMOVU	-(VEC_SIZE * 4)(%rcx), %VEC(4)
	VMOVU	-(VEC_SIZE * 5)(%rcx), %VEC(5)
	VMOVU	-(VEC_SIZE * 6)(%rcx), %VEC(6)
	VMOVU	-(VEC_SIZE * 7)(%rcx), %VEC(7)
	VMOVU	%VEC(0), (%r9)
	VMOVU	%VEC(1), -VEC_SIZE(%r9)
	VMOVU	%VEC(2), -(VEC_SIZE * 2)(%r9)
	VMOVU	%VEC(3), -(VEC_SIZE * 3)(%r9)
	VMOVU	%VEC(4), -(VEC_SIZE * 4)(%r9)
	VMOVU	%VEC(5), -(VEC_SIZE * 5)(%r9)
	VMOVU	%VEC(6), -(VEC_SIZE * 6)(%r9)
	VMOVU	%VEC(7), -(VEC_SIZE * 7)(%r9)
	subq	$(VEC_SIZE * 8), %rcx
	subq	$(VEC_SIZE * 8), %r9
	subq	$(VEC_SIZE * 8), %rdx
	cmpq	$(VEC_SIZE * 8), %rdx
	je	L(between_4x_vec_and_8x_vec)
	ja	L(loop_8x_vec_backward)
	/* Less than 8 * VEC to copy.  */
	cmpq	$(VEC_SIZE * 4), %rdx
	jb	L(between_0_and_4x_vec)
	jmp	L(between_4x_vec_and_8x_vec)
END (MEMCPY_ERMS)

strong_alias (MEMCPY_ERMS, MEMMOVE_ERMS)
# ifdef SHARED
strong_alias (MEMCPY_CHK_ERMS, MEMMOVE_CHK_ERMS)
# endif
# ifdef MEMCPY
strong_alias (MEMCPY, MEMMOVE)
#  ifdef SHARED
strong_alias (MEMCPY_CHK, MEMMOVE_CHK)
#  endif
# endif

#endif
