; Open a file for reading or writing.
; Filename must be already present. If an error
; happens, the disc status is retrieved. The file
; is closed and carry is set.
;
; PARAM:
; A - 'r' for read or 'w' for write, 0 for nothing
; X - Devicenumber
; Y - Filenumber
; DeviceChannel
; FILENAME_PTR - Filename in PETSCII
; FilenameLen - Length of the filename.
;               Note that this may be 0 if i.e. the
;               disc status channel is to be opened.
; FileType - specifies the filetype 'p' = PRG, 's' = SEQ
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

;.pushseg
;.code
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

	ldy FilenameLen
	beq @InitFilename

	; Dont append the filemode
	lda OpenMode
	beq @InitFilename

	; Add filetype and mode to the filename
	lda #','
	sta (FILENAME_PTR),y
	iny
	lda FileType
	sta (FILENAME_PTR),y
	iny
	lda #','
	sta (FILENAME_PTR),y
	iny
	lda OpenMode
	sta (FILENAME_PTR),y

@InitFilename:
	jsr CLRCH

	lda FilenameLen
	bne @UseFilename
	tax
	tay
	beq @SetFilename

@UseFilename:
	clc
	adc #4
	ldx FILENAME_PTR
	ldy FILENAME_PTR HI

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

;.pushseg
;.data

DeviceChannel: .byte 5

;.bss
DeviceNumber: .byte 0
OpenMode: .byte 0
FileType: .byte 0
FileNumber: .byte 0
FilenameBank: .byte 0
FilenameLen: .byte 0
FilenameCommand: .byte 0, 0	; 2 bytes for commands, like Scratch or New.
Filename: .res 21			; Filename is in PETSCII
FILENAME_LEN = *-Filename
FILENAME_MAX = 16

;.popseg

.include "devices/closefile.s"

.endif ;_OPENFILE_INC
