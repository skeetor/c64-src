; Convert PETSCII code in AC to Screencode
; https://www.forum64.de/index.php?thread/3906-screencodes-vs-petascii/&postID=29482#post29482
;

.ifndef _PETSCII_TO_SCREEN_INC
_PETSCII_TO_SCREEN_INC  = 1

.segment "CODE"

.proc PETSCIIToScreen

	asl
	bcs @Cont
	cmp #$C0
	bcc @Cont
	and #$3f

@Cont:
	php
	asl
	plp
	ror
	lsr

	rts

.endproc

.endif ; _PETSCII_TO_SCREEN_INC
