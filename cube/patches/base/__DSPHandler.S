/*
__DSPHandler.S for Nintendont (Kernel)

Copyright (C) 2014 FIX94
Swiss specific changes by emu_kidid

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation version 2.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/
#define _LANGUAGE_ASSEMBLY
#include "../../reservedarea.h"

.section .text
	.globl __DSPHandler

.set	AI_ADP_BUF,		DECODED_BUFFER_0
.set	AI_CR,			0xCC006C00
.set	AI_VR,			0xCC006C04

.set	AI_DMA_ADDR,	0xCC005030
.set	AI_DMA_SIZE,	0xCC005036

#note:r3 and r12 will get overwritten, safe to use

__DSPHandler:
	lis		r12,	VAR_AREA
	lbz		r3,		VAR_STREAM_DI(r12)
	lis		r12,	AI_CR@h
	lwz		r12,	AI_CR@l(r12)
	and.	r3,		r3,	r12
	bne		startcp
	cmpwi	r0,		0
	blr

startcp:
	stwu	r1,		-0x20(r1)
	stw		r4,		0x0(r1)
	stw		r5,		0x4(r1)
	stw		r6,		0x8(r1)
	stw		r7,		0xC(r1)
	stw		r8,		0x10(r1)
	stw		r9,		0x14(r1)
	stw		r0,		0x18(r1)
	mflr	r0
	stw		r0,		0x1C(r1)

#extract from AI directly
	lis		r12,	AI_DMA_ADDR@h
	lwz		r9,		AI_DMA_ADDR@l(r12)
	rlwinm	r9,		r9,		0,		7,		26 # 0x01ffffe0
	oris	r9,		r9,		0x8000
	lhz		r8,		AI_DMA_SIZE@l(r12)
	rlwinm	r8,		r8,		5,		12,		31 # 0x000fffe0

	lis		r12,	VAR_AREA
	lwz		r4,		VAR_STREAM_BUFLOC(r12)
	li		r3,		BUFSIZE
	cmplw	r4,		r3
	blt		buf1
buf2:
	slwi	r3,		r3,		1		#MAXBUF=0x7000
buf1:
	lis		r6,		AI_ADP_BUF@h
	ori		r6,		r6,		AI_ADP_BUF@l

	li		r5,		0
startcopy:
	lis		r12,	AI_VR@h
#left audiostream
	lhax	r0,		r6,		r4
#calc volume
	lwz		r7,		AI_VR@l(r12)
	clrlwi	r7,		r7,		24
	mullw	r0,		r7,		r0
	srawi	r0,		r0,		8
#left original
	lhax	r7,		r9,		r5
#combine streams
	bl		combinebuffer
#save new stream
	sthx	r7,		r9,		r5

	addi	r4,		r4,		2
	addi	r5,		r5,		2

#right audiostream
	lhax	r0,		r6,		r4
#calc volume
	lwz		r7,		AI_VR@l(r12)
	extrwi	r7,		r7,		8,		16
	mullw	r0,		r7,		r0
	srawi	r0,		r0,		8
#right original
	lhax	r7,		r9,		r5
#combine streams
	bl		combinebuffer
#save new stream
	sthx	r7,		r9,		r5

	addi	r4,		r4,		2
	addi	r5,		r5,		2

	cmplw	r4,		r3
	beq		changebuffer
copy2:
	cmplw	r5,		r8
	blt		startcopy

	srwi	r7,		r8,		5
	mtctr	r7
	mr		r5,		r9
	li		r0,		0
DCFlushRange:
	dcbf	r0,		r5
	addi	r5,		r5,		0x20
	bdnz	DCFlushRange

exit:
	lis		r12,	VAR_AREA
	stw		r4,		VAR_STREAM_BUFLOC(r12)

	lwz		r0,		0x1C(r1)
	mtlr	r0
	lwz		r4,		0x0(r1)
	lwz		r5,		0x4(r1)
	lwz		r6,		0x8(r1)
	lwz		r7,		0xC(r1)
	lwz		r8,		0x10(r1)
	lwz		r9,		0x14(r1)
	lwz		r0,		0x18(r1)
	cmpwi	r0,		0
	addi	r1,		r1,		0x20
	blr

changebuffer:
	li		r0,		1
	lis		r12,	VAR_AREA
	stb		r0,		VAR_STREAM_UPDATE(r12)
	li		r0,		BUFSIZE
	cmplw	r4,		r0
	beq		copy2
	li		r4,		0	#back to buffer one
	b		copy2

#the most simple linear compressor I could come up with
combinebuffer:
	add		r7,		r7,		r0
	cmpwi	r7,		0x4CCC
	bgt		compressPos
	cmpwi	r7,		-0x4CCC
	blt		compressNeg
	blr
compressPos:
	subi	r7,		r7,		0x4CCC
	srawi	r7,		r7,		2
	addi	r7,		r7,		0x4CCC
	blr
compressNeg:
	addi	r7,		r7,		0x4CCC
	srawi	r7,		r7,		2
	subi	r7,		r7,		0x4CCC
	blr
