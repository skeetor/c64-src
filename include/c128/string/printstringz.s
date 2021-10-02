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
; LOCALS:
; $57 - Remember the position in the string
; $58 - Remember the position on screen
;
; Both pointers will not be modified. The string can
; not be longer then 254+1 characters 
; Example: Start can be set to $0400 and Y
; 		to 10 to print the string in the middle
;
.proc PrintStringZ

	sty STRING_POS
	ldy #$00

@Loop:
	lda (STRING_PTR),y
	bne @Print
	rts

@Print:
	iny
	sty STR_CHARINDEX
	ldy STRING_POS
	sta (CONSOLE_PTR),y
	iny
	sty STRING_POS
	ldy STR_CHARINDEX
	jmp @Loop

.endproc
