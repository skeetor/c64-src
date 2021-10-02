; Print binary string
; Written by Gerhard W. Gruber in 11.09.2021
;

; AC - Character to be printed
; Y - Offset to screen position
; Pointer to screen location in CONSOLE_PTR
.proc PrintBinary
	ldx #$07

@Loop:
	lsr
	pha
	bcs @Print1
	lda #$30
	bne @Print

@Print1:
	lda #$31

@Print:
	sta (CONSOLE_PTR),y
	pla
	iny
	dex
	bpl @Loop

	rts
.endproc
