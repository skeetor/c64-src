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

.proc memcpy
	sta MEMCPY_LEN_HI
	stx MEMCPY_LEN_LO

	; Check case 1+3. If target is below
	; start then we know we can copy forward.
	lda MEMCPY_TGT+1		; 20
	cmp MEMCPY_SRC+1		; 20
	beq @CheckLo
	bcc MemCopyForward

@CheckLo:
	lda MEMCPY_TGT			; 80
	cmp MEMCPY_SRC			; C0
	beq @Done
	bcc MemCopyForward

@Backwards:
	; Case 4.
	; If target is higher than start but below
	; the end, then the range overlaps and we
	; have to copy backwards. So we have to
	; calculate the endaddress to check this case.
	clc
	lda MEMCPY_SRC
	adc MEMCPY_LEN_LO
	sta MEMCPY_SRC
	lda MEMCPY_SRC+1
	adc MEMCPY_LEN_HI
	sta MEMCPY_SRC+1

	clc
	lda MEMCPY_TGT
	adc MEMCPY_LEN_LO
	sta MEMCPY_TGT
	lda MEMCPY_TGT+1
	adc MEMCPY_LEN_HI
	sta MEMCPY_TGT+1

	jmp MemCopyReverse

@Done:
	rts
.endproc

.include "mem/memcpy_forward.s"
.include "mem/memcpy_reverse.s"

.endif ; _MEMCPY_INC
