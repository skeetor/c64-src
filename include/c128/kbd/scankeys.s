; Scan keyboard for C128 matrix
; Written by Gerhard W. Gruber in 11.09.2021
;
; If the function is not to be called during an IRQ
; but from regular code, then define SCANKEYS_BLOCK_IRQ.
;
.segment "CODE"

; Read the keyboard 11x8 matrix. For each line the current
; state is stored.
; If any keys are pressed Y contains #$01
.proc ScanKeys

	ldy #$ff			; No Key pressed
	sty KeyPressedLine
	iny
	sty KeyPressed

	; First scan the regular C64 8x8 matrix
	ldx #$07

.ifdef SCANKEYS_BLOCK_IRQ
	sei
.endif
	sta VIC_KBD_128	; Disable the extra lines of C128
	lda #%01111111

@NextKey:
	sta SCANKEY_TMP
	sta CIA1_PRA	; Port A to low
	lda CIA1_PRB	; Read key
	eor #$ff		; Flip bits to make them highactive
	sta KeyLine,x	; Store key per matrixline
	beq @NextLine
	sta KeyPressed
	stx KeyPressedLine
	ldy #$01		; Key pressed flag

@NextLine:
	lda SCANKEY_TMP
	sec
	ror
	dex
	bpl @NextKey

	; Now scan the 3 extra lines for the extended
	; C128 keys with their own set of lines via VIC.
	ldx #$02
	lda #$ff
	sta CIA1_PRA	; Disable the regular lines
	lda #%11111011

@NextXKey:
	sta SCANKEY_TMP
	sta VIC_KBD_128	; VIC port to low
	lda CIA1_PRB	; Read key
	eor #$ff		; Flip bits to make them highactive
	sta KeyLine+8,x	; Store key per matrixline
	beq @NextXLine
	sta KeyPressed
	stx KeyPressedLine
	ldy #$01		; Key pressed flag

@NextXLine:
	lda SCANKEY_TMP
	sec
	ror
	dex
	bpl @NextXKey

@Done:
.ifdef SCANKEYS_BLOCK_IRQ
	cli
.endif

	rts
.endproc

; **********************************************
.segment "DATA"

; Keyboard handling
KeyLine: .res C128_KEY_LINES,$ff
KeyPressed: .byte $ff
KeyPressedLine: .byte $00
