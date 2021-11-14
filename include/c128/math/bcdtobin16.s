; https://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion


.ifndef _BCDTOBIN16_INC
_BCDTOBIN16_INC = 1

;.segment "CODE"

.proc BCDToBin16

	lda #$00        ; Init result bytes
	sta hiResult

	lda loInput     ; Fetch ones and tens
	tay             ; Save to Y
	and #$f0        ; this two instructions, or use the undocumented ALR #$f0 = (and #$f0) + (lsr)
	lsr
	sta loResult
	lsr
	lsr
	adc loResult
	sta loResult
	tya
	and #$0f        ; Strip the ones
	adc loResult

	ldx hiInput     ; Fetch the hundreds
	beq END         ; No hundreds? Then go to end

@HUND:
	clc
	adc #$64        ; Add as many hundreds as value of X
	bcc loop
	inc hiResult    ; Increase high byte every passed $FF

@loop:
	dex
	bne HUND

@END:
	sta loResult    ; Store low byte
	rts

.endproc

; **********************************************
;.segment "DATA"

; Binary to decimal conversion
hiInput:	.byte $00
loInput:	.byte $01
hiResult:	.byte $00
loResult:	.byte $00

.endif ; _BCDTOBIN16_INC
