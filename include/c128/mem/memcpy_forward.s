; MemCopyForward copies memory from startto end.
;
; PARAM:
; MEMCPY_LEN_HI
; MEMCPY_LEN_LO
; MEMCPY_SRC
; MEMCPY_TGT
;
; Written by Gerhard W. Gruber 27.11.2021
;

.ifndef _MEMCOPY_FORWARD_INC
_MEMCOPY_FORWARD_INC = 1

;.segment "CODE"

.proc MemCopyForward

	ldy #$00

@SmallLoop:
	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y
	iny
	cpy MEMCPY_LEN_LO
	bne @SmallLoop

	; Adjust to page boundary
	clc
	lda MEMCPY_SRC
	adc MEMCPY_LEN_LO
	sta MEMCPY_SRC
	lda MEMCPY_LEN_HI
	beq @Done
	adc MEMCPY_SRC+1
	sta MEMCPY_SRC+1

	clc
	lda MEMCPY_TGT
	adc MEMCPY_LEN_LO
	sta MEMCPY_TGT
	lda MEMCPY_SRC+1
	adc MEMCPY_LEN_HI
	sta MEMCPY_TGT+1

@CopyPages:

	ldy #$00

@PageLoop:
	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y
	iny
	bne @PageLoop

	lda MEMCPY_LEN_HI
	beq @Done

	dec MEMCPY_LEN_HI
	inc MEMCPY_SRC+1
	inc MEMCPY_TGT+1
	jmp @CopyPages

@Done:
	rts
.endproc

.endif ; _MEMCOPY_FORWARD_INC
