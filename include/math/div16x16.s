; Divide 16/16
; https://codebase64.org/doku.php?id=base:16bit_division_16-bit_result

.ifndef _DIV16X16_INC
_DIV16X16_INC = 1

.proc Div16

	lda #$00		; preset remainder to 0
	sta Remainder
	sta Remainder+1
	ldx #16			; repeat for each bit: ...

@divloop:
	asl Dividend	; Dividend lb & hb*2, msb -> Carry
	rol Dividend+1	
	rol Remainder	; Remainder lb & hb * 2 + msb from carry
	rol Remainder+1
	lda Remainder
	sec
	sbc Divisor		; substract divisor to see if it fits in
	tay				; lb result -> Y, for we may need it later
	lda Remainder+1
	sbc Divisor+1
	bcc @skip		; if carry=0 then divisor didn't fit in yet

	sta Remainder+1	; else save substraction result as new remainder,
	sty Remainder	
	inc DivResult		; and increment result cause divisor fit in 1 times

@skip:
	dex
	bne @divloop	

	rts
.endproc

; **********************************************

.pushseg
.bss

Divisor: .word 0
Dividend: .word 0
Remainder: .word 0
DivResult: .byte 0

.popseg

.endif ; _DIV16X16_INC
