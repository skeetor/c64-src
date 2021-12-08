; Write a memoryblock to an already opened file
;
; PARAM:
; X - Fileno
; MEMCPY_SRC	- Startadress
; MEMCPY_TGT	- Endadress
; WriteFileProgressPtr - If this function returns with
;			carry set, the function will return. No error
;			is set in this case.
;
; RETURN:
; C - Carry set on error.
;
; Written by Gerhard W. Gruber 02.12.2021 
;
.ifndef _WRITEFILE_INC
_WRITEFILE_INC = 1

;.pushseg
;.code

.proc WriteFile

	ldy #$00
	sty STATUS

	; Switch output to our file
	jsr CKOUT
	lda STATUS
	bne @Error

	; Write a single character
@WriteByte:
	ldy #$00
	lda (MEMCPY_SRC),y
	jsr BSOUT		; Write byte in A
	bit STATUS
	bvs @Error

	clc
	lda MEMCPY_SRC
	adc #1
	sta MEMCPY_SRC
	lda MEMCPY_SRC+1
	adc #$00
	sta MEMCPY_SRC+1

	jsr ShowWriteFileProgress
	bcs @Done

	lda MEMCPY_SRC+1
	cmp MEMCPY_TGT+1
	bne @WriteByte
	lda MEMCPY_SRC
	cmp MEMCPY_TGT
	bne @WriteByte

@Done:
	clc
	rts

@Error:
	sec
	rts

.endproc

.proc ShowWriteFileProgress
	jmp (WriteFileProgressPtr)
.endproc

.proc DefaultWriteProgess
	clc
	rts
.endproc

;.data

WriteFileProgressPtr: .word DefaultWriteProgess
;.popseg

.endif ;_WRITEFILE_INC
