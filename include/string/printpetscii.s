; Print a PETSCII string to the screen.
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

.ifndef _PRINTPETSCII_INC
_PRINTPETSCII_INC = 1

.proc PrintPETSCII

	sty PSTR_POS
	ldy #$00

@Loop:
	lda (STRING_PTR),y
	iny
	sty PSTR_CHARINDEX
	jsr PETSCIIToScreen
	ldy PSTR_POS
	sta (CONSOLE_PTR),y
	iny
	sty PSTR_POS
	ldy PSTR_CHARINDEX
	dex
	bne @Loop

	ldy PSTR_POS
	rts
.endproc

.pushseg
.bss

PSTR_CHARINDEX: .byte 0
PSTR_POS: .byte 0

.popseg

.include "string/petscii_to_screen.s"

.endif ; _PRINTPETSCII_INC
