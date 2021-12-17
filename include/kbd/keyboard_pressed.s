; Wait until a key is pressed
; Written by Gerhard W. Gruber in 11.09.2021
;

.ifndef _KEYBOARD_PRESSED_INC
_KEYBOARD_PRESSED_INC = 1

.proc WaitKeyboardPressed
	jsr ScanKeys
	bcc WaitKeyboardPressed
	rts
.endproc

.include "kbd/scankeys.s"

.endif ; _KEYBOARD_PRESSED_INC
