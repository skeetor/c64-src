; Read an already opened file
;
; PARAM:
; X - Fileno
; MEMCPY_TGT	- Startadress
; ReadFileProgressPtr - If it returns with carry
;     set, the load operation is finished even
;     if the file was not fully read. No error
;     is reported in this case.
;
; RETURN:
; C - Carry set on error
;
; Written by Gerhard W. Gruber 02.12.2021 
;
.ifndef _READFILE_INC
_READFILE_INC = 1

;.segment "CODE"

.proc ReadFile

	ldy #$00
	sty STATUS

	; Switch output to our file
	jsr CHKIN
	bcs @Error

	; Read a single character
@ReadByte:
	lda #$00
	sta STATUS
	jsr BSIN
	ldy #$00
	sta (MEMCPY_TGT),y

	lda STATUS
	beq :+
	and #%01000000		; EOF
	bne @Done
	lda STATUS
	bne @Error
:
	jsr ShowReadFileProgress
	bcs @Done

	clc
	lda MEMCPY_TGT
	adc #1
	sta MEMCPY_TGT
	lda MEMCPY_TGT+1
	adc #$00
	sta MEMCPY_TGT+1
	jmp @ReadByte

@Done:
	clc
	rts

@Error:
	sec
	rts
.endproc

.proc ShowReadFileProgress
	jmp (ReadFileProgressPtr)
.endproc

.proc DefaultReadProgess
	clc
	rts
.endproc

;.segment "DATA"

ReadFileProgressPtr: .word DefaultReadProgess

.endif ;_READFILE_INC
