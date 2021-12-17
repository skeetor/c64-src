; Print a string to the screen.
; Written by Gerhard W. Gruber in 11.09.2021
;

; PARAMS:
; CONSOLE_PTR - Pointer to screen
; STRING_PTR - Pointer to string
; Y - offset to the startposition
; X - Stringlength
;
; RETURN:
; Y - Offset after last character
;
; Both pointers will not be modified. The string can
; not be longer then 256 characters 
;

.ifndef _PRINTSTRING_INC
_PRINTSTRING_INC = 1

.proc PrintString

	cpx #$00
	bne :+
	rts
:
	sty STR_POS
	ldy #$00

@Loop:
	lda (STRING_PTR),y
	iny
	sty STR_CHARINDEX
	ldy STR_POS
	sta (CONSOLE_PTR),y
	iny
	sty STR_POS
	ldy STR_CHARINDEX
	dex
	bne @Loop

	ldy STR_POS
	rts
.endproc

.pushseg
.bss

STR_CHARINDEX: .byte 0
STR_POS: .byte 0

.popseg

.endif ; _PRINTSTRING_INC
