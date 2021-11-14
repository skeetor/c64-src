; Convert decimal string to binary 
; Written by Gerhard W. Gruber in 20.10.2021
;
; PARAM:
; Pointer to string in STRING_PTR
; X - Length of string
;
; RETURN:
; A - LowValue
; X - HiValue
; Y - Number of converted characters (includes whitespaces)
;     If the string contains only WS -> Y = 0

.ifndef _STRING_TO_DEC16_INC
_STRING_TO_DEC16_INC = 1

;.segment "CODE"

.proc StringToBin16

	stx StringLenSave
	ldy #$00
	sty Product
	sty Product+1

	; If the string contains leading whitespaces
	; we ignore them.
@SkipLeadingWhitespace:
	lda (STRING_PTR),y
	cmp #' '
	beq @NextWS
	cmp #$08		; TAB
	bne @Enter

@NextWS:
	iny
	dec StringLenSave
	bne @SkipLeadingWhitespace
	ldy #$00		; Nothing converted
	beq @Done

@Loop:

	lda (STRING_PTR),y

@Enter:
	; If it is not a number, we are done
	cmp #'0'
	blt @Done
	cmp #'9'
	bgt @Done

	pha
	; Multiply current result by ten
	lda #10
	sta Multiplier
	lda #0
	sta Multiplier+1

	lda Product
	sta Multiplicand
	lda Product+1
	sta Multiplicand+1
	jsr Mult16x16
	pla

	sec
	sbc #'0'
	clc
	adc Product
	sta Product
	lda #0
	adc Product+1
	sta Product+1

@NextDigit:
	iny
	dec StringLenSave
	bne @Loop

@Done:
	lda Product
	ldx Product+1

	rts
.endproc

.include "math/mult16x16.s"

;.segment "DATA"

StringLenSave: .byte 0

.endif ; _STRING_TO_DEC16_INC
