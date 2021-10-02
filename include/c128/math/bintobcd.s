; https://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion

.proc BinToBCD16

	sed				; Switch to decimal mode
	lda #0			; Ensure the result is clear
	sta BCDVal+0
	sta BCDVal+1
	sta BCDVal+2
	ldx #16			; The number of source bits

@cnvbit:
	asl BINVal+0		; Shift out one bit ...
	rol BINVal+1
	lda BCDVal+0		; ... and add into result
	adc BCDVal+0
	sta BCDVal+0
	lda BCDVal+1		; propagating any carry ...
	adc BCDVal+1
	sta BCDVal+1
	lda BCDVal+2		; ... thru whole result
	adc BCDVal+2
	sta BCDVal+2
	dex				; And repeat for next bit
	bne @cnvbit
	cld				; Back to binary mode

	rts

.endproc

; **********************************************
.segment "DATA"

; Binary to decimal conversion
BINVal: .word 12345
BCDVal: .byte 0, 0, 0
