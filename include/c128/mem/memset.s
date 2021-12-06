; MemCopyForward copies memory from startto end.
;
; PARAM:
; A - Value
; MEMCPY_LEN_HI
; MEMCPY_LEN_LO
; MEMCPY_TGT
;
; Written by Gerhard W. Gruber 06.12.2021
;

.ifndef _MEMSET_INC
_MEMSET_INC = 1

;.segment "CODE"

.proc memset

	ldy MEMCPY_LEN_LO
	beq @MainStart

@SmallLoop:
	sta (MEMCPY_TGT),y
	dey
	bne @SmallLoop
	sta (MEMCPY_TGT),y

@MainStart:
	pha
	lda MEMCPY_LEN_HI
	beq @Done

	clc
	lda MEMCPY_TGT
	adc MEMCPY_LEN_LO
	sta MEMCPY_TGT
	lda MEMCPY_TGT+1
	adc #$00
	sta MEMCPY_TGT+1

@MemsetLoop:

	ldy #$00
	pla
	pha

@PageLoop:
	sta (MEMCPY_TGT),y
	dey
	bne @PageLoop

	inc MEMCPY_TGT+1
	dec MEMCPY_LEN_HI
	bne @MemsetLoop

@Done:
	pla
	rts
.endproc

.endif ; _MEMSET_INC
