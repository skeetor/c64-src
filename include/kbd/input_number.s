; Input a number value which can be 0...65535
;
; PARAMS:
; InputNumberEmpty	0 - Print curValue as default. 1 - Leave string empty
; InputNumberCurVal
; InputNumberMinVal
; InputNumberMaxVal
; InputNumberMaxDigits - Length of input string (1...5)
; CONSOLE_PTR - position of the input string
;
; OPTIONAL:
; InputNumberErrorHandler - pointer to a function which handles a range
;         error. If this function returns with carry set, the input is cancled
;         and returnd with carry set.
;
; RETURN:
; A - Lobyte of value
; X - Hibyte of value
; C - clear (OK) : set (CANCEL)
; If C is set, the value in A is undefined and should not be used.
;
; Written by Gerhard W. Gruber 07.12.2021
;
.ifndef _INPUT_NUMBER_INC
_INPUT_NUMBER_INC = 1

.proc InputNumber
	SetPointer NumberInputFilter, InputFilterPtr

@InputLoop:
	SetPointer InputNumberStr, STRING_PTR
	ldy #InputNumberStrLen-1
						; 5 digits + clear the last
						; byte to make sure the number
						; conversion doesn't pick up a
						; stray digit.
	lda #' '

@ClearString:
	sta (STRING_PTR),y
	dey
	bpl @ClearString

	lda InputNumberEmpty
	beq @PrintCurVal
	ldx #$00
	jmp @SkipPrint

@PrintCurVal:
	lda InputNumberCurVal
	sta BINVal
	lda InputNumberCurVal HI
	sta BINVal HI

	lda InputNumberMaxDigits
	ldx #0				; Left aligned
	ldy #0
	jsr PrintDecimal

@SkipPrint:
	ldy InputNumberMaxDigits
	jsr Input
	bcs @Cancel			; User pressed cancel button
	cpy #$00			; Empty string was entered
	beq @RangeError

	; String length of input string
	tya
	tax
	jsr StringToBin16
	sta InputNumberCurVal
	stx InputNumberCurVal HI

   ; X = HiByte
   ; A = LoByte

	; Check range of input against the
	; range limits.
	; if (v < min || v > max)
	;	error
	;
	; Hi < Min: RangeError
	; Hi = Min: Lo-Byte decides
	; Hi > Min: Lo-Byte is not needed

	; V < Min?
	cpx InputNumberMinVal HI
	bcc @RangeError				; Hi < Min
	bne @CheckMax				; Hi != Min
	cmp InputNumberMinVal
	bcc @RangeError				; Lo < Min

@CheckMax:
	; V > Max?
	cpx InputNumberMaxVal HI
	bcc @Accept					; Hi < Max
	bne @RangeError				; Hi != Max

	cmp InputNumberMaxVal
	beq @Accept					; Lo == Max
	bcs @RangeError				; Lo >= Max

@Accept:
	jmp @Done

@Cancel:
	sec
	bcs @Exit

@Done:
	clc

@Exit:
	pha
	SetPointer DefaultInputFilter, InputFilterPtr
	pla
	rts

@RangeError:
	jsr InputNumberError
	bcc @InputLoop
	rts
.endproc

.proc InputNumberError
	jmp (InputNumberErrorHandler)
.endproc

.proc DefaultInputNumberError
	sec
	rts
.endproc

.pushseg
.data

InputNumberErrorHandler: .word DefaultInputNumberError

.bss

InputNumberStrLen = 7
InputNumberStr: .res InputNumberStrLen
InputNumberMaxDigits: .byte 0
InputNumberEmpty: .byte 0		; 1 - InputNumber will not print the current value
InputNumberCurVal: .word 0
InputNumberMinVal: .word 0
InputNumberMaxVal: .word 0

.popseg

.include "kbd/input.s"
.include "string/printdec.s"

.endif ; _INPUT_NUMBER_INC
