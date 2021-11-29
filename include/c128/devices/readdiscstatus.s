; Read the error channel of a disc drive and get
; the status and description.
; Written by Gerhard W. Gruber in 11.09.2021
; Based on https://codebase64.org/doku.php?id=base:reading_the_error_channel_of_a_disk_drive
;
; PARAMS:
; X - Device number
; STRING_PTR
;
; RETURN:
; A - $00 - OK. Status was successfully retrieve read.
;     $ff - FAILED. Status couldn't be read and is unknown 
;
.ifndef _READDISCSTATUS_INC
_READDISCSTATUS_INC = 1

;.segment "CODE"

.proc ReadDiscStatus
	lda #$00
	sta STATUS

	lda #15				; Fileno
	ldy #15				; Control channel of disc
	jsr SETFPAR

	lda #0				; RAM bank to load file
	ldx #0				; RAM bank of filename
	jsr SETBANK

	jsr CLRCH

	lda #$00      ; no filename
	tax
	tay
	jsr SETNAME

	ldx #$ff
	stx DiscStatusCode
	stx DiscStatusStringLen

	jsr OPEN
	bcs @Fail

	ldx #15
	jsr CHKIN

@ReadLoop:
	jsr READST
	bne @Done		; EOF
	jsr BSIN
	inc DiscStatusStringLen
	ldy DiscStatusStringLen
	jsr PETSCIIToScreen
	sta DiscStatusString,y
	jmp @ReadLoop

@Done:
	jsr ParseDiscStatusValues
	lda #$00

@Close:
	pha

	lda #15
	jsr CLOSE
	jsr CLRCH

	pla
	rts

@Fail:
	lda #$ff
	jmp @Close

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
DiscStatusTrack: .byte 0
DiscStatusSector: .byte 0
DiscStatusStringLen: .byte 0
DiscStatusString: .res 40

.endif ; _READDISCSTATUS_INC
