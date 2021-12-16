; MemCopyReverse copies memory from the end to start.
;
; PARAM:
; MEMCPY_LEN_HI
; MEMCPY_LEN_LO
; MEMCPY_SRC
; MEMCPY_TGT
;
; Written by Gerhard W. Gruber 27.11.2021
;

.ifndef _MEMCOPY_REVERSE_INC
_MEMCOPY_REVERSE_INC = 1

.proc MemCopyReverse

	lda MEMCPY_LEN_LO
	bne @Start
	lda MEMCPY_LEN_HI
	beq @Done

@Start:
	; Subtract the low byte from the target
	; to get on a pageboundary
	sec
	lda MEMCPY_SRC
	sbc MEMCPY_LEN_LO
	sta MEMCPY_SRC
	lda MEMCPY_SRC+1
	sbc #$00
	sta MEMCPY_SRC+1

	sec
	lda MEMCPY_TGT
	sbc MEMCPY_LEN_LO
	sta MEMCPY_TGT
	lda MEMCPY_TGT+1
	sbc #$00
	sta MEMCPY_TGT+1

	ldy MEMCPY_LEN_LO
	lda #$00
	sta MEMCPY_LEN_LO
	tya
	bne @EnterLoop

@ReverseCopy:
	ldy #$ff

@ReverseLoop:
	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y

@EnterLoop:
	dey
	bne @ReverseLoop
	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y

	lda MEMCPY_LEN_HI
	beq @Done

	; Prev page
	dec MEMCPY_LEN_HI
	dec MEMCPY_SRC+1
	dec MEMCPY_TGT+1
	jmp @ReverseCopy

@Done:
	rts
.endproc

.endif ; _MEMCOPY_REVERSE_INC
