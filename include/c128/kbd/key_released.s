; Wait until no keys are pressed
; Written by Gerhard W. Gruber in 11.09.2021
;
.proc WaitKeyboardRelease
	jsr ScanKeys
	lda KeyPressed
	bne WaitKeyboardRelease
	rts
.endproc
