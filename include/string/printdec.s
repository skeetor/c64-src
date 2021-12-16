; Print a binary number as decimal
;
; PARAMS:
; A - Number of digits (1...6)
; X - Flags
;		DEC_ALIGN_RIGHT
;		DEC_LEADING_ZEROES
;
;       If DEC_ALIGN_RIGHT is not set, then
;       DEC_LEADING_ZEROES has no effect.
;
; Y - Offset in String
; STRING_PTR
; BINVal - binary value to be printed
;
; RETURN:
; Y - Position after last char printed
;
; Written by Gerhard W. Gruber in 08.12.2021

.ifndef _PRINTDEC_INC
_PRINTDEC_INC = 1

; Bitflags
DEC_ALIGN_RIGHT		= $01
DEC_LEADING_ZEROES	= $02

.proc PrintBCD
	pha					; Number of digits
	txa
	pha					; Flags
	jmp PrintBCDValues
.endproc

.proc PrintDecimal
	pha					; Number of digits
	txa
	pha					; Flags

	jsr BinToBCD16
.endproc

; Same parameters as for Print BCD/Decimal
; Only A and X are expected on the stack.
;
; This function can not be used with jsr.
;
;          0   1   2
; BCDVal: $35 $55 $06 = 65535
;
; 1 -> Index 0
;      Skip 1
; 2 -> Index 0
;      Skip 0
; 3 -> Index 1
;      Skip 1
; 4 -> Index 1
;      Skip 0
; 5 -> Index 2
;      Skip 1
; 6 -> Index 2
;      Skip 0

.proc PrintBCDValues
	tsx
	inx					; Flags
	lda #$ff			; Left aligned
	sta LeftAligned
	lda $0100,x
	and #DEC_ALIGN_RIGHT
	beq :+
	inc LeftAligned		; Set right alignment
:
	lda #$ff			; No leading zeroes
	sta ShowLeadingZeroes
	lda $0100,x
	and #DEC_LEADING_ZEROES
	beq :+
	inc ShowLeadingZeroes	; Set leading zeroes
:
	NR_DIGITS = 0
	BCD_INDEX = 1
	SKIP_HIBYTE = 2

	dex
	lda $0100+SKIP_HIBYTE,x	; Number of digits
	pha						; NR_DIGITS

	lsr						; div 2 - Two digits per BCD byte.
	; We now have the number BCD bytes required
	sta $0100+BCD_INDEX,x

	lda $0100+NR_DIGITS,x	; Number of digits again
	and #$01				; If odd number, the first digit must be skipped
	sta $0100+SKIP_HIBYTE,x
	bne :+
	dec $0100+BCD_INDEX,x	; If even number, the highbyte
							; has the same BCD index as the lowbyte
:
	pla					; Discard TMP_VAL
	pla
	tax					; Index in BCDVal
	pla					; Skip-Hibyte flag

	; Y - Offset in string
	; X - Index of BCDVal
	; A - 1 = Skip first digit.
	jmp BCDToString
.endproc

.include "math/bintobcd16.s"
.include "string/bcdtostring.s"

.endif ; _PRINTDEC_INC
