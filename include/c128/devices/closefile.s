; Close the file which was previously opened
;
; PARAM:
; A - FileNo
;
; Written by Gerhard W. Gruber 02.12.2021 
;
.ifndef _CLOSEFILE_INC
_CLOSEFILE_INC = 1

;.pushseg
;.code
.proc CloseFile
	jsr CLOSE
	jsr CLRCH
	clc
	rts
.endproc
;.popseg

.endif ;_CLOSEFILE_INC
