; Read a key, which has been read from the keyboard
; And convert it to a PETSCII code. This will not
; support multiple keys being pressed at the same
; time.
;
; Written by Gerhard W. Gruber in 11.09.2021
;
; Required defines:
; 	KEYTABLE_PTR (ZP)

.ifndef _READKEYS_INC
_READKEYS_INC = 1

.include "tools/misc.inc"

;.segment "CODE"

KEY_NONE		= 	$00
KEY_SHIFT_LEFT	=	$01
KEY_SHIFT_RIGHT	=	$02
KEY_SHIFT		=	$04	; Not an actual flag but a convenience for ANY shift key
KEY_COMMODORE	=	$08
KEY_CTRL		=	$10
KEY_ALT			=	$20
KEY_EXT			=	$40	; One of the extended C128 keys were pressed
						; This bit can only be set after the KeyTable
						; was evaluated.

.macro  LoadPointer   addrValue, Pointer
		lda     addrValue
		sta     Pointer
		lda     addrValue+1
		sta     Pointer+1
.endmacro

.proc ReadKey
	; The caller should have already called ScanKeys
	;jsr ScanKeys

	jsr CheckModifier

	; Show hex value of the keycode + modifier at
	; the bottom of the screen if enabled.
.if 1
	.out "[readkey.s] Debug output of keycodes activated"
	jsr EvaluateKeyTable

	lda CONSOLE_PTR
	pha
	lda CONSOLE_PTR+1
	pha
	SetPointer ($0400+40*24), CONSOLE_PTR
	lda KeyCode
	ldy #$00
	jsr PrintHex
	lda KeyModifier
	ldy #$03
	jsr PrintHex
	pla
	sta CONSOLE_PTR+1
	pla
	sta CONSOLE_PTR
	rts
.else
	jmp EvaluateKeyTable
.endif

.endproc

; Check if the current keyscan contains modifier
; keys being pressed. If yes, the appropriate table
; is loaded and the bits are set in KeyModifier.
; The keys are then removed from the scan.
;
; NOTICE: If multiple modifier keys are pressed
; only the latest table will be set. The modifier
; flags are still all availablke. The order of
; evalution is:
; ALT, CTRL, C=, SHL, SHR
;
; So if the user presses i.E. CTRL+(ANY)SHIFT, the
; keytable for SHIFT takes is used.
;
; If multiple modifiers are required, the caller
; can provide his own table in KEYTABLE_PTR
; and call EvaluateKeyTable directly.
;
.proc CheckModifier

	lda #$00
	sta KeyModifier

	LoadPointer KeytableNormal, KEYTABLE_PTR

	; First we check if the modifier keys are pressed.
	; These keys will be masked out, as we are only
	; interested here in normal keys.

@CheckALTKey:
	ldx #10
	lda KeyLine,x
	beq @CheckControlKey
	tay
	and #%00000001
	beq @CheckControlKey

	; Remove ALT from the matrix
	; and set the modifier flag
	tya
	and	#%11111110
	sta KeyLine,x
	lda KeyModifier
	ora #KEY_ALT|KEY_EXT
	sta KeyModifier
	LoadPointer KeytableAlt, KEYTABLE_PTR

@CheckControlKey:
	ldx #7
	lda KeyLine,x
	beq @CheckCommodoreKey
	tay
	and #%00000100
	beq @CheckCommodoreKey

	; Remove CTRL from the matrix
	; and set the modifier flag
	tya
	and	#%11111011
	sta KeyLine,x
	lda KeyModifier
	ora #KEY_CTRL
	sta KeyModifier
	LoadPointer KeytableControl, KEYTABLE_PTR

@CheckCommodoreKey:
	lda KeyLine,x
	beq @CheckShiftLeft
	tay
	and #%00100000
	beq @CheckShiftLeft

	; Remove C= from the matrix
	; and set the modifier flag
	tya
	and	#%11011111
	sta KeyLine,x
	lda KeyModifier
	ora #KEY_COMMODORE
	sta KeyModifier
	LoadPointer KeytableCommodore, KEYTABLE_PTR

@CheckShiftLeft:
	ldx #1
	lda KeyLine,x
	beq @CheckShiftRight
	tay
	and #%10000000
	beq @CheckShiftRight

	; Remove ShiftLeft from the matrix
	; and set the modifier flag
	tya
	and #%01111111
	sta KeyLine,x
	lda KeyModifier
	ora #KEY_SHIFT_LEFT|KEY_SHIFT
	sta KeyModifier
	LoadPointer KeytableShift, KEYTABLE_PTR

@CheckShiftRight:
	ldx #6
	lda KeyLine,x
	beq @Done
	tay
	and #%00010000
	beq @Done

	; Remove ShiftRight from the matrix
	; and set the modifier flag
	tya
	and	#%11101111
	sta KeyLine,x
	lda KeyModifier
	ora #KEY_SHIFT_RIGHT|KEY_SHIFT
	sta KeyModifier
	LoadPointer KeytableShift, KEYTABLE_PTR

@Done:
	rts
.endproc

.proc EvaluateKeyTable

	ldx #KEY_LINES-1

@NextLine:
	lda KeyLine,x
	beq	@NextKeyLine

	ldy #$07

@CheckKeyBit:
	asl
	bcs @KeyPressed
	dey
	bpl @CheckKeyBit

@NextKeyLine:
	dex
	bpl @NextLine
	inx

	; No keys pressed
	; modifiers may be active.
	stx KeyCode
	rts

@KeyPressed:
	cpx #8
	blt :+
	lda KeyModifier
	ora #KEY_EXT
	sta KeyModifier

:	txa

	; Calculate the position of the key
	; in the codetable.
	; Line * 8 + bitnumber
	asl
	asl
	asl

	sta KeyCode
	tya
	clc
	adc KeyCode
	tay

	lda (KEYTABLE_PTR),y
	sta KeyCode

@Done:
	rts
.endproc

.include "kbd/scankeys.s"

;.segment "DATA"

; Contains bit flags for the Modifier keys
; like SHIFT
KeyModifier: .byte 0

; The keycode without the modifier keys.
KeyCode: .byte 0

; Default are the normal pointers to the keycode
; tables in the kernel.
KeytableNormal:		.word $fa80
KeytableShift:		.word $fad9
KeytableCommodore:	.word $fb32
KeytableControl:	.word $fb8b
KeytableAlt:		.word $fbe4

; KeytableASCII:
;	.byte $14, $0D, $1D, $88, $85, $86, $87, $11 ; L 0
;	.byte $33, $57, $41, $34, $5A, $53, $45, $01 ; L 1
;	.byte $35, $52, $44, $36, $43, $46, $54, $58 ; L 2
;	.byte $37, $59, $47, $38, $42, $48, $55, $56 ; L 3
;	.byte $39, $49, $4A, $30, $4D, $4B, $4F, $4E ; L 4
;	.byte $2B, $50, $4C, $2D, $2E, $3A, $40, $2C ; L 5
;	.byte $5C, $2A, $3B, $13, $01, $3D, $5E, $2F ; L 6
;	.byte $31, $5F, $04, $32, $20, $02, $51, $03 ; L 7
;	.byte $84, $3a, $55, $09, $32, $34, $37, $31 ; L 8
;	.byte $1B, $20, $20, $0A, $0D, $36, $39, $33 ; L 9
;	.byte $08, $30, $2E, $91, $11, $9D, $10, $FF ; L10

.endif ; _READKEYS_INC
