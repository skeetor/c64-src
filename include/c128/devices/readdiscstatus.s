; Read the error channel of a disc drive and get
; the status and description.
; Written by Gerhard W. Gruber in 11.09.2021
; Based on https://codebase64.org/doku.php?id=base:reading_the_error_channel_of_a_disk_drive
;
; IMPORTANT NOTE! After calling the Open function, all open 
; files are no longer accessible.
;
; PARAMS:
; X - Device number
; STRING_PTR
;
; RETURN:
; C - Carry set on error.
; If a device not present occurs then DiscStatusCode is $ff.
; In this case, all other fields are undefined.
; A - $00 - OK. Status was successfully retrieve read.
;     $ff - FAILED. Status couldn't be read and is unknown 
;
; Written by Gerhard W. Gruber 02.12.2021 
;
.ifndef _READDISCSTATUS_INC
_READDISCSTATUS_INC = 1

;.segment "CODE"

.proc OpenDiscStatus
	lda #$00
	sta STATUS

	stx DiscStatusDrive

	txa					; Fileno
	ldy #15				; Control channel of disc
	jsr SETFPAR

	lda #0				; RAM bank to load file
	ldx #0				; RAM bank of filename
	jsr SETBANK

	lda #$00			; no filename
	tax
	tay
	jsr SETNAME

	jsr OPEN
	bcs @Error
	lda STATUS
	bne @Error

	clc
	rts

@Error:
	sec
	rts
.endproc

.proc ReadDiscStatus
	stx DiscStatusDrive	; FileNo

	lda #$ff
	sta DiscStatusCode
	sta DiscStatusTrack
	sta DiscStatusSector
	lda #$00
	sta DiscStatusStringLen

	jsr CHKIN
	bcs @Error

@ReadLoop:
	jsr READST
	bne @Done			; EOF
	jsr BSIN
	jsr PETSCIIToScreen
	bcs @Done
	ldy DiscStatusStringLen
	sta DiscStatusString,y
	inc DiscStatusStringLen
	cpy #DISC_STATUS_MAX_LEN
	bne @ReadLoop

@Done:
	lda DiscStatusStringLen
	beq :+				; EOF
	dec DiscStatusStringLen
	jsr ParseDiscStatusValues
:
	clc
	rts

@Error:
	sec
	rts
.endproc

.proc CloseDiscStatus
	txa					; FileNo
	jsr CLOSE
	jsr CLRCH

	clc
	rts

.endproc

.proc ParseDiscStatusValues
	ldy #$00
	jsr ParseDiscValue
	sta DiscStatusCode

	; Index now after first ','
	iny

@FindComma:
	lda DiscStatusString,y
	cmp #','
	beq @Track
	iny
	jmp @FindComma

@Track:
	iny
	jsr ParseDiscValue
	sta DiscStatusTrack
	iny
	jsr ParseDiscValue
	sta DiscStatusSector

	rts
.endproc

.proc ParseDiscValue
	lda DiscStatusString,y

	; Convert to binary
	sec
	sbc #'0'

	; Multiplay by 10 = 8n + 2n
	sta DiscStatusSector
	asl
	asl
	asl					; 8n

	; 2n
	clc
	adc DiscStatusSector
	adc DiscStatusSector
	sta DiscStatusSector	; Remember hivalue

	iny						; Next digit
	lda DiscStatusString,y
	sec
	sbc #'0'
	clc

	adc DiscStatusSector	; add lovalue
	iny

	rts
.endproc

.include "string/petscii_to_screen.s"

;.segment "DATA"

DiscStatusCode: .byte 0
DiscStatusDrive: .byte 0
DiscStatusTrack: .byte 0
DiscStatusSector: .byte 0
DiscStatusStringLen: .byte 0
DiscStatusString: .res 40
DISC_STATUS_MAX_LEN = (*-DiscStatusString)

.endif ; _READDISCSTATUS_INC
