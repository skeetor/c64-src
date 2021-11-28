; Memmove copies a region of memory. It is safe
; to use an overlapping region as memmove will determine
; if it should copy up- or downwards.
; For regions smaller than 257 bytes it is more
; efficient to use a specific copy.
;
;        S-----E
;        T-----E			<- 0. S == T -> NOP
;  T-----E					<- 1.Copy S ==> E to T
;              T-----E		<- 2.Copy S ==> E to T
;     T-----E				<- 3.Copy S ==> E to T
;           T-----E			<- 4.Copy S <== E to T
; 
; PARAM:
; A - Hibyte count
; X - Lobyte count 
; MEMCPY_SRC
; MEMCPY_TGT
;
; Written by Gerhard W. Gruber 27.11.2021
;
.ifndef _MEMCPY_INC
_MEMCPY_INC = 1

;.segment "CODE"

.proc memcpy
	sta MEMCPY_LEN_HI
	stx MEMCPY_LEN_LO

	; Check case 1+3. If target is below
	; start then we know we can copy forward.
	lda MEMCPY_SRC+1
	cmp MEMCPY_TGT+1
	bgt MemCopyForward

	lda MEMCPY_SRC
	cmp MEMCPY_TGT
	bgt MemCopyForward

	bne :+
	lda MEMCPY_SRC+1
	cmp MEMCPY_TGT+1
	bne :+

	rts				; Case 0. SRC and TRGT is equal.

:
	; Case 4.
	; If target is higher than start but below
	; the end, then the range overlaps and we
	; have to copy backwards. So we have to
	; calculate the endaddress to check this case.
	clc
	lda MEMCPY_SRC
	adc MEMCPY_LEN_HI
	sta MemMoveEnd
	lda MEMCPY_SRC+1
	adc MEMCPY_LEN_LO
	sta MemMoveEnd+1

	; Check case 2. Target is higher or equal
	; than the end.
	lda MEMCPY_TGT
	cmp MemMoveEnd
	bgt MemCopyForward

	lda MEMCPY_TGT+1
	cmp MemMoveEnd+1
	bge MemCopyForward

	; Copy backward.
	lda MemMoveEnd
	sta MEMCPY_SRC
	lda MemMoveEnd+1
	sta MEMCPY_SRC+1

	clc
	lda MEMCPY_TGT
	adc MEMCPY_LEN_HI
	sta MEMCPY_TGT
	lda MEMCPY_TGT+1
	adc MEMCPY_LEN_LO
	sta MEMCPY_TGT+1
	jmp MemCopyReverse
.endproc

.include "mem/memcpy_forward.s"
.include "mem/memcpy_reverse.s"

;.segment "DATA"

MemMoveEnd: .word 0

.endif ; _MEMCPY_INC
