; Delete the specified filename
;
; PARAM:
; Filename - Filename in PETSCII
; FilenameLen - Length of the filename
;
; Written by Gerhard W. Gruber 07.12.2021 
;
.ifndef _DELETEFILE_INC
_DELETEFILE_INC = 1

;.pushseg
;.code

.proc DeleteFile
	lda #'s'			; lowercase PETSCII 'S'
	sta FilenameCommand
	lda #':'
	sta FilenameCommand+1

	inc FilenameLen
	inc FilenameLen

	SetPointer FilenameCommand, FILENAME_PTR

	lda DeviceChannel
	pha

	; OPEN #15,8,15,"S:<filename>"
	lda #15
	sta DeviceChannel
	tay
	lda #$00
	ldx DeviceNumber
	jsr OpenFile

	lda #15
	jsr CloseFile

	pla
	sta DeviceChannel
	dec FilenameLen
	dec FilenameLen

	SetPointer Filename, FILENAME_PTR
	clc
	rts

@Error:
	SetPointer Filename, FILENAME_PTR
	sec
	rts
.endproc

;.popseg

.include "devices/openfile.s"
.include "devices/closefile.s"

.endif ;_DELETEFILE_INC
