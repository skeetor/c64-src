; Wait until no keys are pressed
; Written by Gerhard W. Gruber in 11.09.2021
;

.ifndef _KEYBOARD_RELEASED_INC
_KEYBOARD_RELEASED_INC = 1

;.pushseg
;.code

.proc WaitKeyboardRelease
	jsr ScanKeys
	bcs WaitKeyboardRelease
	rts
.endproc

;.popseg

.include "kbd/scankeys.s"

.endif ; _KEYBOARD_RELEASED_INC
