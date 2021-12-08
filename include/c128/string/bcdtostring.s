; Convert BCD value to string
; Written by Gerhard W. Gruber in 11.09.2021
;
; Prints as many BCD bytes as specified by X.
; The BCD bytes must be in reverse order, highest
; byte rightmost.
;
; BCDVal is by default only 3 bytes (for 16 bit bin to decimal)
; but this function makes no such assumptions, so 
; BCDVal can be increased to store as large BCD values
; as desired.
;
; Pointer in STRING_PTR
; Y - Offset in string
; X - Index of BCDVal
; A - 1 = Skip first digit. This is needed when an uneven
;		number of digits is desired, otherwise it will always be
;		a multiple of 2 digits.
; STRING_PTR - Pointer to the string
; ShowLeadingZeroes 
;                 $00 : show leading zeroes
;				  $ff : fill with spaces
;                 If left aligned is enabled ($00), this flag has no effect
; LeftAligned   - $00 : Left aligned
;				  $ff : Right aligned
;
; Return:
; Y - Offset after the last char
; X - Number of digits not 0.
; NumberOfDigits - Same as X

.ifndef _BCDTOSTRING_INC
_BCDTOSTRING_INC = 1

;.pushseg
;.code

.proc BCDToString

	pha
	lda #$ff
	sta LeadingZeroFlag
	lda #$00
	sta NumberOfDigits
	pla

	; Should we start with the lowbyte?
	bne @LoByte

@HiByte:
	lda #$00
	sta DigitToggle
	lda BCDVal,x
	lsr
	lsr
	lsr
	lsr
	jmp @MakeDigit

@LoByte:
	lda #$ff
	sta DigitToggle
	lda BCDVal,x
	and #$0f

@MakeDigit:
	clc
	adc #'0'
	cmp #'0'
	beq @CheckZero
	inc LeadingZeroFlag	; Clear leading zero marker
	bpl @Store			; Not a zero so we can always store it

@CheckZero:
	; Check the hi-bit if we still have leading zeroes
	bit LeadingZeroFlag
	bpl @Store			; Not leading, so we have to store it

	bit LeftAligned		; Skip leading zeroes
	bmi @NextDigit

	bit ShowLeadingZeroes ; Show leading zero or space? 
	bpl @Store
	lda #' '

@Store:
	inc NumberOfDigits
	sta (STRING_PTR),y
	iny

@NextDigit:
	bit DigitToggle
	bpl @LoByte

	dex
	bpl @HiByte

	; If the whole string was empty we write a single 0.
	; This only happens if left aligned is set, as in the other
	; case we will have either leading zeroes or blanks
	ldx NumberOfDigits
	bne @CheckBlanks

	lda #'0'
	sta (STRING_PTR),y
	iny
	inc NumberOfDigits
	bne @Done			; Will always jump

@CheckBlanks:
	; If we are not left aligned, we have to check if the
	; whole string consists of blanks. If ShowLeadingZeroes
	; is enabled this can not happen and we are done.
	bit ShowLeadingZeroes
	bpl @Done

	dey
	lda (STRING_PTR),y
	cmp #' '
	bne @AlmostDone		; it is a digit so we can return
	lda #'0'
	sta (STRING_PTR),y
	inc NumberOfDigits

@AlmostDone:
	iny

@Done:
	ldx NumberOfDigits
	rts

.endproc

;.data

; Internal use

; Set to $ff if the hiyte of a BCDValue is to be printed, otherwise $00 for the lowbyte
DigitToggle: .byte 0
; Marker to check if we are still having leading zerores ($ff).
LeadingZeroFlag: .byte 0

; Input parameters, can be set by the caller
ShowLeadingZeroes: .byte 0
LeftAligned: .byte 0

; Return value: Number of digits printed. If leading zeroes are shown, they are included in the count.
NumberOfDigits: .byte 0

;.popseg

.endif ; _BCDTOSTRING_INC
