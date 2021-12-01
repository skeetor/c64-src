; Open a file for reading or writing.
; Filename must be already present. If an error
; happens, the disc status is retrieved. The file
; is closed and carry is set.
;
; PARAM:
; A - 'r' for read or 'w' for write
; X - Devicenumber
; Y - Filenumber
; DeviceChannel
; Filename - Filename in PETSCII
; FilenameLen - Length of the filename.
;               Note that this may be 0 if i.e. the
;               disc status channel is to be opened.
; FilenameBank - (optional) default = 0
;
; RETURN:
; C - Carry set on error
; DiskStatus
; If a device not present error occurs, the DiscStatusCode
; is set to $ff.
;
; Written by Gerhard W. Gruber 02.12.2021 
;
.ifndef _OPENFILE_INC
_OPENFILE_INC = 1

;.segment "CODE"
.proc OpenFile	; Prepare filename by appending 

	sta OpenMode
	stx DeviceNumber
	sty FileNumber

	lda #$00
	sta STATUS
	lda #$ff
	sta DiscStatusCode

	; File set parameters
	tya					; Fileno
	; ldx DeviceNumber
	; ldy FileNumber
	ldy DeviceChannel
	jsr SETFPAR

	lda #0				; RAM bank to load file
	ldx FilenameBank	; RAM bank of filename
	jsr SETBANK

	; ',P,W' to open a file for writing
	ldy FilenameLen
	beq @NoFilename

	lda #','
	sta Filename,y
	iny
	lda #'p'
	sta Filename,y
	iny
	lda #','
	sta Filename,y
	iny
	lda OpenMode
	sta Filename,y

@NoFilename:
	jsr CLRCH

	lda FilenameLen
	bne @UseFilename
	tax
	tay
	beq @SetFilename

@UseFilename:
	clc
	adc #4
	ldx #<(Filename)
	ldy #>(Filename)

@SetFilename:
	jsr SETNAME

	; Open the file
	jsr OPEN
	bcs @DeviceError	; Device not present
	lda STATUS
	bne @DeviceError

	; Check if the open was successfull.
	; This is unfortunately not covered
	; by the Kernel, so we have to check
	; for ourselve.
	ldx DeviceNumber
	jsr ReadDiscStatus
	lda DiscStatusCode
	bne @Error

@Done:
	lda #$00
	sta STATUS

	clc
	rts

@Error:
	lda FileNumber
	jsr CloseFile
	sec
	rts

@DeviceError:
	ldx DeviceNumber
	jsr ReadDiscStatus
	jmp @Error

.endproc

.include "devices/closefile.s"
;.segment "DATA"

DeviceNumber: .byte 8
DeviceChannel: .byte 5
OpenMode: .byte 0
FileNumber: .byte 0
FilenameBank: .byte 0
FilenameLen: .byte 0
Filename: .res 21			; Filename is in PETSCII
FILENAME_LEN = *-Filename
FILENAME_MAX = 16

.endif ;_OPENFILE_INC
