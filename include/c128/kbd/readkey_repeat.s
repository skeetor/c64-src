; Wait until a key is pressed or repeated.
; This function will either return when a key
; is pressed or when it was already pressed and
; the repeat delay has expired.
;
; RETURN:
; KeyCode
; KeyModifier
;
; Written by Gerhard W. Gruber 11.09.2021
;

.ifndef _READKEY_REPEAT_INC
_READKEY_REPEAT_INC = 1

;.segment "CODE"

.proc ReadKeyRepeat

@WaitKeyPress:
	jsr ScanKeys
	dey
	beq @KeyPressed

@KeyReleased:
	; Destroy the last keycode and the modifier
	; so it will trigger a new key repeat on
	; next real key press.
	ldy #$00
	sty LastKeyCode
	dey
	sty LastKeyModifier
	
	jmp @WaitKeyPress

@KeyPressed:
	; Convert scancodes to PETSCII
	jsr TranslateKey

	; Check if a real key was pressed.
	; If it was only a modifier we ignore it.
	lda KeyCode
	beq @KeyReleased

	; If the last key is not the same as before
	; we have to reset the repeat value.
	cmp LastKeyCode
	bne @NewKey

	lda KeyModifier
	cmp LastKeyModifier
	bne @NewKey

	; Key was the same (Modifer and Code)
	dec KeyDelayCount
	bne ReadKeyRepeat

	lda KeyRepeatDelay
	sta KeyDelayCount

	dec KeyDelayCount+1
	bne ReadKeyRepeat

	lda KeyRepeatDelay+1
	sta KeyDelayCount+1

	rts

@NewKey:
	; Remember the key/mod for the next check
	sta LastKeyCode
	lda KeyModifier
	sta LastKeyModifier

	; and set the KeyPressDelay to start with.
	lda KeyPressDelay
	sta KeyDelayCount
	lda KeyPressDelay+1
	sta KeyDelayCount+1

	rts
.endproc

.include "kbd/translate_key.s"
.include "kbd/keyboard_pressed.s"

;.segment "DATA"

KeyPressDelay: 	.byte 0, 3	; Delay when the key is pressed the first time
KeyRepeatDelay: .byte 60, 1	; Repeat delay while the key is held
KeyDelayCount:	.byte 0, 0

LastKeyModifier: .byte 0
LastKeyCode: .byte 0

.endif ; _READKEY_REPEAT_INC
