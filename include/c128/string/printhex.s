; Print hex string
; Written by Gerhard W. Gruber in 11.09.2021
;

; AC - Character to be printed
; Y - Offset to screen position
; Pointer to screen location in CONSOLE_PTR

.ifndef _PRINTHEX_INC
_PRINTHEX_INC = 1

;.pushseg
;.code

.proc PrintHex

	ldx #$02
	pha

	lsr
	lsr
	lsr
	lsr

@PrintChar:
	and #$0f

	cmp #$0a
	bcs @Alpha
	adc #$3a

@Alpha:
	sbc #$09
	sta (CONSOLE_PTR),y
	pla	
	iny
	dex
	bne @PrintChar
	pha

	rts
.endproc

;.popseg

.endif ; _PRINTHEX_INC
