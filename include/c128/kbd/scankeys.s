; Scan keyboard matrix
; This code should work on C64 (tested), C128 (tested),
; MEGA65 (untested) and maybe on other Commodore machines as well.
;
; Written by Gerhard W. Gruber in 11.09.2021
;
; If the function is not to be called during an IRQ
; but from regular code, then define SCANKEYS_BLOCK_IRQ.
;

.ifndef _SCANKEYS_INC
_SCANKEYS_INC = 1

;.pushseg
;.code

; Read the keyboard 11x8 matrix. For each line the current
; state is stored in KeyLine[i].
; If any keys are pressed Y contains 1 otherwise 0.
;
; The CIA ports are lowactive. So we set all bits to 1
; to disable them, and only leave the required line bit
; at 0. Then we can read the key states for this line.
; This is repeated for all lines and the 0 bit is shifted
; accordingly. For easier processing, we flip the bits of
; the keys to make them highactive in the keyboardbuffer.
;
; For a real C64 the three extra lines can be skipped, the
; remainder of the code works the same.
;
; If any keys are pressed Y contains #$01
;
; RETURN:
; Carry - set mean keys are pressed
;         clear mean no keys pressed
.proc ScanKeys

	lda #$00
	sta KeyPressed

	; First scan the regular C64 8x8 matrix
	ldx #$07

.ifdef SCANKEYS_BLOCK_IRQ
	sei
.endif
	lda #$ff
	sta VIC_KBD_128	; Disable the extra lines of C128
	lda #%01111111

@NextKey:
	sta KeyTmp
	sta CIA1_PRA	; Port A to low
	lda CIA1_PRB	; Read key
	eor #$ff		; Flip bits to make them highactive
	sta KeyLine,x	; Store key per matrixline
	beq @NextLine
	ldy #$01		; Key pressed flag
	sty KeyPressed

@NextLine:
	lda KeyTmp
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
	sta KeyTmp
	sta VIC_KBD_128	; VIC port to low
	lda CIA1_PRB	; Read key
	eor #$ff		; Flip bits to make them highactive
	sta KeyLine+8,x	; Store key per matrixline
	beq @NextXLine
	ldy #$01		; Key pressed flag
	sty KeyPressed

@NextXLine:
	lda KeyTmp
	sec
	ror
	dex
	bpl @NextXKey

@Done:
.ifdef SCANKEYS_BLOCK_IRQ
	cli
.endif

	lda #$ff
	clc
	adc KeyPressed
	rts
.endproc

; **********************************************

;.bss

; Keyboard handling
KeyTmp: .byte 0
KeyLine: .res KEY_LINES,$00
KeyPressed : .byte 0

;.popseg

.endif ; _SCANKEYS_INC
