; https://codebase64.org/doku.php?id=base:16bit_multiplication_32-bit_product

.proc Mult16x16

	lda	#$00
	sta	Product+2	; clear upper bits of product
	sta	Product+3
	ldx	#$10		; set binary count to 16

@shift_r:
	lsr	Multiplier+1	; divide multiplier by 2
	ror Multiplier
	bcc	@rotate_r
	lda	Product+2	; get upper half of product and add multiplicand
	clc
	adc	Multiplicand
	sta	Product+2
	lda	Product+3
	adc	Multiplicand+1

@rotate_r:
	ror				; rotate partial product
	sta	Product+3
	ror	Product+2
	ror	Product+1
	ror	Product
	dex
	bne	@shift_r
	rts
.endproc

; **********************************************
.segment "DATA"

; 16x16 multiplication
Multiplier:		.byte 0, 0
Multiplicand:	.byte 0, 0
Product:		.byte 0, 0, 0, 0 
