; Print a zeroterminated String to the screen.
; Written by Gerhard W. Gruber in 11.09.2021
;

; PARAMS:
; CONSOLE_PTR - Pointer to screen
; STRING_PTR - Pointer to string
; Y - offset to the startposition
;
; RETURN:
; Y contains the number of characters printed
;
; Both pointers will not be modified. The string can
; not be longer then 254+1 characters 
; Example: Start can be set to $0400 and Y
; 		to 10 to print the string in the middle
;

.ifndef _PRINTSTRINGZ_INC
_PRINTSTRINGZ_INC = 1

;.segment "CODE"

.proc PrintStringZ

	sty STRZ_POS
	ldy #$00

@Loop:
	lda (STRING_PTR),y
	bne @Print
	rts

@Print:
	iny
	sty STRZ_CHARINDEX
	ldy STRZ_POS
	sta (CONSOLE_PTR),y
	iny
	sty STRZ_POS
	ldy STRZ_CHARINDEX
	jmp @Loop

.endproc

;.segment "DATA"

STRZ_CHARINDEX: .byte 0
STRZ_POS: .byte 0

.endif ; _PRINTSTRINGZ_INC
