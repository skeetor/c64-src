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

.proc WaitKeyboardReleaseIgnoreMod

@WaitRelease:
	jsr ScanKeys
	bcc @Done	; No key pressed

	; Now check if any modifier was pressed.
	ldx #1
	lda KeyLine,x
	and #$80				; LSHIFT

	pha
	tsx
	txa
	tay
	iny

	ldx #6
	lda KeyLine,x
	and #$10				; RSHIFT
	ora	$0100,y
	sta $0100,y

	ldx #7
	lda KeyLine,x
	and #$24				; C= + CTRL
	ora	$0100,y
	sta $0100,y

	ldx #10
	lda KeyLine,x
	and #$01				; ALT
	ora	$0100,y
	sta $0100,y
	pla
	beq @WaitRelease

@Done:
	rts
.endproc

.include "kbd/scankeys.s"

.endif ; _KEYBOARD_RELEASED_INC
