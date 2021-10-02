; Wait until a key is pressed
; Written by Gerhard W. Gruber in 11.09.2021
;
.proc WaitKeyboardPressed
	jsr ScanKeys
	lda KeyPressed
	beq WaitKeyboardPressed
	rts
.endproc
