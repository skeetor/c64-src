; Handle keyboard functions by creating a map which 
; maps the modifier and the key to the respective
; function.
; This function will not read the keyboard. This has to be
; done prior to calling this function so that KeyModifier
; and KeyCode are already set.
;
; We loop through the keymap and check if there is an entry
; which matches the Modifierand KeyCode. If such an entry is
; found, the associated keyhandler is executed.
;
; The SHIFT key is handled in a special way. If KEY_SHIFT
; is set, we ignore KEY_SHIFT_LEFT or KEY_SHIFT_RIGHT
; as this means that any SHIFT key is allowed to be pressed.
; If KEY_SHIFT is not set, then it must also match exactly. 
;
; PARAM:
; KeyModifier
; KeyCode
; KeyMapBasePtr - points to the keymap definig the functions.
;
; KEYMAP_PTR - ZP address must be provided, but doesn't need to
;           be initialized.
; 
; RETURN:
; KeyMapWaitRelease - Bit 7 cleared if the handler should allow
;           the key to be repeated.
;           If set, the keyboard should be wait for release.
;
; Written by Gerhard W. Gruber in 11.09.2021

.ifndef _KEYBOARD_MAPPING_INC
_KEYBOARD_MAPPING_INC = 1

;.pushseg
;.code

; NOTE: When defining a key assignment using SHIFT keys we can
; only use either KEY_SHIFT or KEY_SHIFT_LEFT/KEY_SHIFT_RIGHT.
; If KEY_SHIFT is set then LEFT/RIGHT is ignored for the comparison.
;
; If LEFT/RIGHT is desired it must be defined without the KEY_SHIFT
; flag to work. LEFT/RIGHT may be used together, but this means the
; user would really have to press both shift keys to trigger.
;
; Example:
;	Space key + any shift key will trigger
;	DefineKey KEY_SHIFT, $20, Function
;
;	Space key + RIGHT SHIFT only will trigger
;	DefineKey KEY_SHIFT_RIGHT, $20, Function
;
; Possible SHIFT states
; =======================
; Code reported |  Map
; SHIFT L-R     |  SHIFT L/R
;  1    1 1     |   1    0 0  Any SHIFT is a match
;               |   1    x x  Any SHIFT is a match. L/R is ignored
;  1    1 0     |   0    1 1  Both SHIFT is a match
;  1    0 1     |   0    1 0  L-SHIFT is a match
;               |   0    0 1  R-SHIFT is a match
;
.macro  DefineKey	Modifier, Code, Flags, Function
	.byte Modifier, Code
	.byte Flags
	.word Function
.endmacro
KEYMAP_SIZE = 5

.proc CheckKeyMap

	lda KeyMapBasePtr
	sta KEYMAP_PTR
	lda KeyMapBasePtr+1
	sta KEYMAP_PTR HI

@CheckKeyLoop:
	ldy #0
	lda (KEYMAP_PTR),y

	; If we have an exact match, we are already done
	; and can process the key directly.
	cmp KeyModifier
	beq @CheckKey

	; If the modifier did not match, we now have to
	; check if the SHIFT key is part of the modifier.

	; If the Mapcode uses KEY_SHIFT, we have to check if any
	; SHIFT was pressed.
	and #KEY_SHIFT
	bne @CheckAnyShift

	lda KeyModifier
	and #$ff ^ KEY_SHIFT
	sta KeyMapModifier

	lda (KEYMAP_PTR),y

	cmp KeyMapModifier	
	beq @CheckKey
	bne @NextKey

@CheckAnyShift:
	lda KeyModifier
	and #$ff ^ (KEY_SHIFT_LEFT|KEY_SHIFT_RIGHT)
	sta KeyMapModifier

	; Ignore L/R flags
	lda (KEYMAP_PTR),y
	and #$ff ^ (KEY_SHIFT_LEFT|KEY_SHIFT_RIGHT)
	cmp KeyMapModifier
	bne @NextKey

@CheckKey:
	iny
	lda (KEYMAP_PTR),y
	cmp KeyCode
	bne @NextKey

	; We found a valid key combination, so we execute
	; the handler.
	ldy #$02
	lda (KEYMAP_PTR),y
	sta KeyMapWaitRelease
	iny
	lda (KEYMAP_PTR),y
	sta KeyMapFunction
	iny
	lda (KEYMAP_PTR),y
	sta KeyMapFunction+1
	jmp (KeyMapFunction)

@NextKey:
	clc
	lda KEYMAP_PTR
	adc #KEYMAP_SIZE
	sta KEYMAP_PTR
	lda KEYMAP_PTR HI
	adc #$00
	sta KEYMAP_PTR HI

	; If the functionpointer is a nullptr we have reached the end of the map.
	ldy #$03
	lda (KEYMAP_PTR),y
	bne @CheckKeyLoop
	iny
	lda (KEYMAP_PTR),y
	bne @CheckKeyLoop
	rts

.endproc

;.bss

; This map contains the modifier, keycode and the function to trigger
KeyMapBasePtr: .word 0
KeyMapFunction: .word 0
KeyMapModifier: .byte 0	; Copy of KeyModifier to handle SHIFT flags

; Main loop should wait for keyboard release
; before next key is read if bit 7 is set.
KeyMapWaitRelease: .byte $00

;.popseg

.endif ; _KEYBOARD_MAPPING_INC
