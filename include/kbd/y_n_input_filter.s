; This filter allows only Y or N as input.
;
; Written by Gerhard W. Gruber 07.12.2021
;

.ifndef _YN_INPUT_FILTER_INC
_YN_INPUT_FILTER_INC = 1

.proc YNInputFilter

	tay

	; If a modifier was pressed, 
	lda KeyModifier
	bne @Skip

	tya
	cmp #$59			; 'Y'
	beq @OK

	cmp #$4e			; 'N'
	bne @Skip

@OK:
	clc
	rts

@Skip:
	sec
	rts
.endproc

.endif ; _YN_INPUT_FILTER_INC
