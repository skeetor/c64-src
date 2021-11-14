; Numeric filter function for the input routine.
; This filter allows only 0-9 as input.
;
; Written by Gerhard W. Gruber 12.10.2021
;

.ifndef _NUMBER_INPUT_FILTER_INC
_NUMBER_INPUT_FILTER_INC = 1

.include "tools/intrinsics.inc"

.proc NumberInputFilter

	tay

	; If a modifier was pressed, 
	lda KeyModifier
	beq :+
	and #^(KEY_EXT)
	bne @Skip

:	tya
	cmp #'0'
	blt @Skip

	cmp #'9'
	bgt @Skip

	ldy #$01
	rts

@Skip:
	ldy #$00
	rts
.endproc

.endif ; _NUMBER_INPUT_FILTER_INC
