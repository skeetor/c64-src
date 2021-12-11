; This filter allows only Y or N as input.
;
; Written by Gerhard W. Gruber 07.12.2021
;

.ifndef YN_INPUT_FILTER_INC
YN_INPUT_FILTER_INC = 1

;.pushseg
;.code

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

;.popseg

.endif ; YN_INPUT_FILTER_INC
