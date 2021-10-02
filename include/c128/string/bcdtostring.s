; Convert BCD value to string
; Written by Gerhard W. Gruber in 11.09.2021
;
; Pointer in STRING_PTR
; Y - Offset in string
; X - Offset in BCDVal
; A - 1 = Skip first digit. This is needed when an uneven
;		number of digits is desired, otherwise it will always be
;		a multiple of 2 digits.
;
.proc BCDToString

	pha
	lda #$00
	sta SKIP_LEADING_ZERO

	pla
	cmp #$01
	beq @SkipFirstDigit

@Digit:
	lda BCDVal,x

	clc
	lsr
	lsr
	lsr
	lsr
	clc
	adc #'0'
	cmp #'0'
	beq @CheckZero0
	sta SKIP_LEADING_ZERO	; No longer leading zeroes
	jmp @Store0

@CheckZero0:
	bit SKIP_LEADING_ZERO
	bne @Store0
	lda #' '

@Store0:
	sta (STRING_PTR),y
	iny

@SkipFirstDigit:
	lda BCDVal,x
	and #$0f
	clc
	adc #'0'
	cmp #'0'
	beq @CheckZero1
	sta SKIP_LEADING_ZERO	; No longer leading zeroes
	jmp @Store1

@CheckZero1:
	bit SKIP_LEADING_ZERO
	bne @Store1
	lda #' '

@Store1:
	sta (STRING_PTR),y
	iny

	dex
	bpl @Digit

	; If the whole string was empty we write a 0.
	dey
	lda (STRING_PTR),y
	cmp #' '
	bne @Done
	lda #'0'
	sta (STRING_PTR),y

@Done:
	iny
	rts

.endproc
