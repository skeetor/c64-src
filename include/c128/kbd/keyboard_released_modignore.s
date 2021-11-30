; Wait until no keys are pressed except modifiers
; which are ignored.
; When dealing with user input it may be
; inconvenient if he presses i.e. SHIFT/DEL (INS)
; multiple times and has to release also the SHIFT
; key in between. To avoid repetetion of the key
; it is more practical to only have to release
; the DEL key only.
;
; Written by Gerhard W. Gruber in 30.11.2021
;
.ifndef _KEYBOARD_RELEASED_MODIGNORE_INC
_KEYBOARD_RELEASED_MODIGNORE_INC = 1

;.segment "CODE"

.proc WaitKeyboardReleaseIgnoreMod
	jsr ScanKeys
	dey
	bne @Done				; No key pressed

	; Now check if any modifier was pressed.

	ldx #1
	lda KeyLine,x
	and #(~$80)&$ff				; LSHIFT

	pha
	tsx
	txa
	tay
	iny

	ldx #6
	lda KeyLine,x
	and #(~$10)&$ff				; RSHIFT
	ora	$0100,y
	sta $0100,y

	ldx #7
	lda KeyLine,x
	and #(~$24)&$ff				; C= + CTRL
	ora	$0100,y
	sta $0100,y

	ldx #10
	lda KeyLine,x
	and #(~$01)&$ff				; ALT
	ora	$0100,y
	sta $0100,y
	pla
	bne WaitKeyboardReleaseIgnoreMod

@Done:
	rts
.endproc

.include "kbd/scankeys.s"

.endif ; _KEYBOARD_RELEASED_INC
