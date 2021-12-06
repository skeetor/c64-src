; Input a string on the screen. The function
; returns when CR is pressed carry is clear (OK).
; If ESC is pressed, the function returns
; with carry set (CANCEL).
; Y - returns the length
;
; PARAMS:
; X - Current string length
; Y - Max input length
; CONSOLE_PTR - position on the screen
; STRING_PTR - PETSCII string
;
; RETURN:
; A = 0 (Cancel)
;
; A = 1 (OK)
; Y = Length of input string.
;
; The caller can set the pointer InputFilterPtr
; to a function which can check KeyCode/KeyModifier
; to filter individual keys. If this function returns
; with carry clear, the key was accepted and will be entered
; into the string, otherwise the key is ignored.
; Note that this can not change the behavior of
; CRSR, RUN/STOP, DEL and ENTER keys as those are
; handled internally.
;
; Written by Gerhard W. Gruber 12.10.2021
;

.ifndef _INPUT_INC
_INPUT_INC = 1

.include "tools/intrinsics.inc"

EMPTY_CHAR		= 100	; '_'

;.segment "CODE"

.proc Input
	
	sty InputMaxLen
	stx InputCurLen

	ldy #$ff
	sty KeyModifier
	iny
	sty KeyCode
	beq @ShowCurString	; Enter loop

@ShowCurStringLoop:
	lda (STRING_PTR),y
	jsr PETSCIIToScreen
	sta (CONSOLE_PTR),y
	iny

@ShowCurString:
	cpy InputCurLen
	bne @ShowCurStringLoop

	lda #EMPTY_CHAR
	bne @FillRemainder

@FillRemainderLoop:
	sta (CONSOLE_PTR),y
	iny

@FillRemainder:
	cpy InputMaxLen
	bne @FillRemainderLoop

	txa		; InputCurLen
	tay	

	; Show cursor first after end of string.
	; If the string has the maximum length already
	; the cursor stays on the last character.
	cpy InputMaxLen
	bgt :+
	dey
:
	; Show the cursor
	lda (CONSOLE_PTR),y
	eor #$80
	sta (CONSOLE_PTR),y

	sty InputCursorPos
	jmp @CrsrRight

@KeyLoop:
	jsr ReadKeyRepeat

	lda KeyCode

	cmp #$1d			; CRSR-Right
	bne :+

@CrsrRight:
	lda InputCursorPos
	tay
	tax
	inx					; New Cursorpos
	jsr InputMoveCursorRight
	jmp @KeyLoop
:
	cmp #$9d			; CRSR-Left
	bne :+
	tay
	lda KeyModifier
	and #KEY_SHIFT|KEY_EXT
	tax
	tya
	cpx #$00
	beq :+

	lda InputCursorPos
	beq @KeyLoop
	tay
	tax
	dex					; New Cursorpos
	jsr InputMoveCursorLeft
	jmp @KeyLoop
:
	cmp #$03			; RUN-STOP
	bne :+

	ldy InputCursorPos
	lda (CONSOLE_PTR),y
	eor #$80
	sta (CONSOLE_PTR),y

	ldy InputCurLen
	sec
	rts
:
	cmp #$0d			; ENTER
	bne :+

	ldy InputCursorPos
	lda (CONSOLE_PTR),y
	eor #$80
	sta (CONSOLE_PTR),y

	ldy InputCurLen
	clc
	rts
:
	cmp #$14			; DEL
	bne :+

	; If the cursor is at the start
	; we can't delete anymore.
	jsr InputDeleteCharacter
	jmp @KeyLoop
:
	cmp #$94			; INSERT
	bne :+
	jsr InputInsertCharacter
	jmp @KeyLoop
:
	bcc :+
	jmp @KeyLoop
:
	; Add PETSCII character to string
	jsr InputAddCharacter
	jmp @KeyLoop
.endproc

.proc CallKeyboardFilter
	jmp (InputFilterPtr)
.endproc

;------------------------------------------------
.proc InputAddCharacter
	ldy InputCursorPos
	sta (STRING_PTR),y
	jsr PETSCIIToScreen
	ora #$80
	sta (CONSOLE_PTR),y

	lda InputCursorPos
	tay
	tax
	inx					; New Cursorpos
	cmp InputCurLen
	bne :+
	inc InputCurLen
:	jsr InputMoveCursorRight

@Done:
	rts
.endproc

;------------------------------------------------
InputMoveCursorRight:

	cpx InputCurLen
	blt InputMoveCursorLeft
	ldx InputCurLen
	cpx InputMaxLen
	blt InputMoveCursorLeft
	dex

InputMoveCursorLeft:

	; Switch off old cursor position
	jsr InputToggleCursor
	sty InputCursorPos

	rts

.proc InputToggleCursor
	lda (CONSOLE_PTR),y
	eor #$80
	sta (CONSOLE_PTR),y

	; New cursor pos
	txa
	tay

	; Show new cursor position
	lda (CONSOLE_PTR),y
	eor #$80
	sta (CONSOLE_PTR),y

	rts
.endproc

;------------------------------------------------
; This charfilter allows all chars in the string.
; Some keys are filtered, like F1-F8, CRSR UP/DOWN,
; etc.
;
; PARAMS:
; A - KeyCode
;
; RETURN
; A - KeyCode must be preserved if Y == 1
; Y - 0 to skip, 1 to accept character
.proc DefaultInputFilter

	tay
	lda KeyModifier
	and #KEY_SHIFT|KEY_EXT
	tax
	tya

	cmp #$11			; CRSR DOWN
	beq @Skip

	cmp #$91			; CRSR UP + SHIFT
	bne :+
	cpx #$00 
	bne @Skip

	; F1-F7 = $85 - $88
	; F2-F8 = $8A - $8C with SHIFT
:	cmp #$85
	blt :+
	cmp #$88
	ble @Skip

:	tay
	lda KeyModifier
	and #KEY_SHIFT
	tax
	tya

	cpx #KEY_SHIFT
	bne :+				; Not an F2-F8 Key

	cmp #$89
	blt :+
	cmp #$8c
	ble @Skip
:
	clc
	rts

@Skip:
	sec
	rts
.endproc

;----------------------------------------------------
; Delete the character at the current cursor position
; from the string and refresh the display accordingly.
.proc InputDeleteCharacter
	; If the string has 0 length
	; there is nothing to delete
	lda InputCurLen
	bne :+

@Done:
	rts

:	ldy InputCursorPos
	beq @Done

	; Switch off cursor
	lda (CONSOLE_PTR),y
	eor #$80
	sta (CONSOLE_PTR),y

	; If the cursor was on the last
	; character, we stay there
	; because the cursor doesn't move
	; beyond it.
	ldx InputCursorPos
	inx
	cpx InputMaxLen
	bne @CopyString
	cpx InputCurLen
	bne @CopyString

	ldy InputCursorPos
	lda #EMPTY_CHAR+$80
	sta (CONSOLE_PTR),y
	dec InputCurLen
	rts

@CopyStringLoop:
	lda (STRING_PTR),y
	dey
	sta (STRING_PTR),y
	iny

	lda (CONSOLE_PTR),y
	dey
	sta (CONSOLE_PTR),y
	iny

	iny
@CopyString:
	cpy InputCurLen
	bne @CopyStringLoop

	; Replace last character with empty
	lda #EMPTY_CHAR
	dey
	sta (CONSOLE_PTR),y
	dec InputCurLen
	dec InputCursorPos

	; Switch on new cursor
	ldy InputCursorPos
	lda (CONSOLE_PTR),y
	eor #$80
	sta (CONSOLE_PTR),y

	rts
.endproc

.proc InputInsertCharacter
	ldx InputCurLen
	cpx InputMaxLen
	bge @Done

	ldy InputCursorPos
	cpy InputCurLen
	bge @Done

	lda (CONSOLE_PTR),y
	eor #$80
	sta (CONSOLE_PTR),y

	ldy InputCurLen

@InsertLoop:
	dey
	lda (STRING_PTR),y
	iny
	sta (STRING_PTR),y

	dey
	lda (CONSOLE_PTR),y
	iny
	sta (CONSOLE_PTR),y
	dey

	cpy InputCursorPos
	bne @InsertLoop

	lda #' '
	sta (STRING_PTR),y
	lda #EMPTY_CHAR+$80
	sta (CONSOLE_PTR),y

	inc InputCurLen

@Done:
	rts
.endproc

.include "kbd/readkey_repeat.s"
.include "string/petscii_to_screen.s"

;.segment "DATA"

; When a key is pressed this function is called before
; the character is added to the string.
; All other keys, like CRSR Left/Right, Del, etc.
; are handled internally.
;
; PARAMS:
; AC - PETSCII char to be inserted
;
; RETURN;
; AC - PETSCII char to be inserted
; Y - 0 means the char is to be ignored
;     1 the char is added to the string.
InputCursorPos: .byte 0
InputCurLen: .byte 0
InputMaxLen: .byte 0
InputTmp: .byte 0
InputFilterPtr:	.word DefaultInputFilter

.endif ; _INPUT_INC
