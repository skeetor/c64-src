; Wait until a key is pressed
; Written by Gerhard W. Gruber in 11.09.2021
;

.ifndef _KEYBOARD_PRESSED_INC
_KEYBOARD_PRESSED_INC = 1

;.segment "CODE"

.proc WaitKeyboardPressed
	jsr ScanKeys
	lda KeyPressed
	beq WaitKeyboardPressed
	rts
.endproc

.include "kbd/scankeys.s"

.endif ; _KEYBOARD_PRESSED_INC
