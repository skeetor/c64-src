; Spriteeditor for C128 with CA65 assembler
; Written by Gerhard W. Gruber in 11.09.2021

; Debug defines
;SHOW_DEBUG_SPRITE  = 1

; Sprite editor constants
; =======================
SCREEN_VIC			= $0400
SCREEN_COLUMNS		= 40
SCREEN_LINES		= 23
STATUS_LINE_NR		= SCREEN_LINES+1		; Last line of screen
SPRITE_PTR			= $7f8
SPRITE_PREVIEW		= 0	; Number of the previewsprite
SPRITE_CURSOR		= 1	; Number of the cursor sprite
INPUT_LINE			= (SCREEN_VIC+SCREEN_COLUMNS*SCREEN_LINES)
STATUS_LINE			= (SCREEN_VIC+SCREEN_COLUMNS*STATUS_LINE_NR)

SPRITE_BUFFER_LEN	= 64
SPRITE_BASE			= $2000		; Sprite data pointer for preview.
SPRITE_USER_START	= SPRITE_BASE+2*SPRITE_BUFFER_LEN	; First two sprite frames are reserved
SPRITE_PREVIEW_BUFFER = SPRITE_BASE+(SPRITE_PREVIEW*SPRITE_BUFFER_LEN)
SPRITE_END			= __CODE_LOAD__
MAX_FRAMES = <((__CODE_LOAD__-SPRITE_USER_START)/SPRITE_BUFFER_LEN)	; The first frame
								; is used for our cursor sprite, so the first
								; user sprite will start at SPRITE_BASE+SPRITE_BUFFER_LEN

; Flags for copying sprites from/to the preview buffer
SPRITE_PREVIEW_SRC	= $01
SPRITE_PREVIEW_TGT	= $02

SPRITE_COLOR		= VIC_SPR0_COLOR
SPRITE_EXP_X		= VIC_SPR_EXP_X
SPRITE_EXP_Y		= VIC_SPR_EXP_Y 

.pushseg
.code

.ifdef SHOW_DEBUG_SPRITE

.proc CreateDebugSprite
	ldy #SPRITE_BUFFER_LEN-1
	lda #255

@InitSprite:
	sta SPRITE_USER_START,y
	dey
	bpl @InitSprite

	lda #0
	sta SPRITE_USER_START+1
	sta SPRITE_USER_START+(3*20)+1

	lda #$7f
	sta SPRITE_USER_START+(3*7)
	sta SPRITE_USER_START+(3*8)
	sta SPRITE_USER_START+(3*9)
	sta SPRITE_USER_START+(3*10)
	sta SPRITE_USER_START+(3*11)
	sta SPRITE_USER_START+(3*12)
	sta SPRITE_USER_START+(3*13)

	lda #$fe

	sta SPRITE_USER_START+(3*7)+2
	sta SPRITE_USER_START+(3*8)+2
	sta SPRITE_USER_START+(3*9)+2
	sta SPRITE_USER_START+(3*10)+2
	sta SPRITE_USER_START+(3*11)+2
	sta SPRITE_USER_START+(3*12)+2
	sta SPRITE_USER_START+(3*13)+2

	lda #0					; A - Source frame
	ldy	#SPRITE_PREVIEW_TGT	;     SPRITE_PREVIEW_TGT - Copy sprite from source to preview
	jsr CopySpriteFrame
	jmp DrawBitMatrix
.endproc

.endif ; SHOW_DEBUG_SPRITE

; ******************************************
; Sprite Editor
; ******************************************
.proc SpriteEditor

	; Set the dimension of the sprite editing matrix
	lda #3
	sta EditColumnBytes
	lda #24
	sta EditColumns
	lda #21
	sta EditLines
	ldx #SPRITE_BUFFER_LEN
	stx EditFrameSize
	dex
	stx EditBufferLen

	lda #(1 << SPRITE_PREVIEW)
	sta VIC_SPR_ENA		; Enable preview sprite

	jsr UpdateFrameEditor
	jsr SpritePreviewBorder

	; Print the frame text
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*1), CONSOLE_PTR
	SetPointer FrameTxt, STRING_PTR
	ldy #26
	jsr PrintStringZ

	lda CONSOLE_PTR
	sta STRING_PTR
	lda CONSOLE_PTR HI
	sta STRING_PTR HI
	lda CurFrame
	ldx MaxFrame
	ldy #26+6
	jsr PrintFrameCounter

	; Print the max frame text
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*21), CONSOLE_PTR
	SetPointer SpriteFramesMaxTxt, STRING_PTR

	ldy #26
	jsr PrintStringZ

	CopyPointer CONSOLE_PTR, STRING_PTR
	SetPointer MAX_FRAMES, BINVal
	lda #3				; Max 3 digits (one byte)
	ldx #DEC_ALIGN_RIGHT
	ldy #36
	jsr PrintDecimal

	; Cursor position
	SetPointer CURSOR_HOME_POS, CURSOR_LINE
	SetPointer SPRITE_PREVIEW_BUFFER, PIXEL_LINE

	ldy #0
	sty EditCursorX
	sty EditCursorY
	jsr ShowCursor

	lda #$00
	jsr SpriteColorMode

	ldx #$01
	jsr SetMultiColor

	; The keymap for the sprite editing functions
	SetPointer SpriteEditorKeyMap, KeyMapBasePtr

	rts
.endproc

.proc TogglePreviewX
	lda	SPRITE_EXP_X
	eor #(1 << SPRITE_PREVIEW)
.endproc

.proc SetPreviewX
	sta SPRITE_EXP_X
	jsr SpritePreviewBorder

	rts
.endproc

.proc TogglePreviewY
	lda	SPRITE_EXP_Y
	eor #(1 << SPRITE_PREVIEW)
.endproc

.proc SetPreviewY
	sta SPRITE_EXP_Y
	jsr SpritePreviewBorder

	rts
.endproc

.proc IsMulticolor
	lda	VIC_SPR_MCOLOR
	and #(1 << SPRITE_PREVIEW)
	rts
.endproc

.proc ToggleMulticolor
	lda	VIC_SPR_MCOLOR
	eor #(1 << SPRITE_PREVIEW)
.endproc

.proc SpriteColorMode

	sta VIC_SPR_MCOLOR

	pha
	lda SpriteColorValue+1
	ldx #$00
	jsr SetSpriteColor2
	lda SpriteColorValue+2
	ldx #$00
	jsr SetSpriteColor3

	; Make sure that a double cursor is hidden.
	ldx #$01
	stx EditDoubleCursor
	jsr HideCursor

	; Set default as single cursor
	dec EditDoubleCursor

	pla
	and #(1 << SPRITE_PREVIEW)
	beq @SingleMode

	; Make sure the cursor is on an even position
	; and enable the double cursor
	inc EditDoubleCursor
	lda EditCursorX
	and #$fe
	sta EditCursorX

	; Print three colors
	lda #$01
	ldx #3
	jmp @Print

@SingleMode:
	; Clear color 2+3+Selection
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*(COLOR_TXT_ROW+1)+COLOR_TXT_COLUMN), CONSOLE_PTR

	lda #' '
	ldx #3

@ClearLine:
	ldy #ColorTxtLen+2

@Clear:
	sta (CONSOLE_PTR),y
	dey
	bpl @Clear
	jsr NextLine
	lda #' '
	dex
	bne @ClearLine

	; Print only color 1
	ldx #1

@Print:
	jsr ShowCursor

	SetPointer ColorTxt, STRING_PTR
	jsr PrintSpriteColor

	jsr IsMulticolor
	beq @Done

	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*(COLOR_TXT_ROW+3)), CONSOLE_PTR
	SetPointer SelectedColorTxt, STRING_PTR
	ldy #COLOR_TXT_COLUMN
	jsr PrintStringZ

	ldx MultiColorValue
	jmp SetMultiColorValue

@Done:
	rts
.endproc

.proc PrintSpriteColor

	; Print the color choice
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*COLOR_TXT_ROW), CONSOLE_PTR
	stx TMP_VAL_1
	ldx #$01

.endproc

.proc PrintColorText
	ldy #COLOR_TXT_COLUMN
	jsr PrintStringZ
	txa
	clc
	adc #'0'
	ldy #COLOR_TXT_COLUMN+ColorTxtLen
	sta (CONSOLE_PTR),y
	ldy #COLOR_TXT_COLUMN+ColorTxtLen+2
	lda #81		; Inverse O
	sta (CONSOLE_PTR),y
	jsr NextLine

	inx
	cpx TMP_VAL_1
	ble PrintColorText
	
	rts
.endproc

.proc IncSpriteColor1
	inc SpriteColorValue
.endproc

.proc SetSpriteColor1
	COLOR1_POS = SCREEN_COLUMNS*COLOR_TXT_ROW+COLOR_TXT_COLUMN+8

	SetPointer (SCREEN_VIC+COLOR1_POS+2), CONSOLE_PTR

	lda SpriteColorValue
	sta VIC_SPR0_COLOR+SPRITE_PREVIEW
	sta VIC_COLOR_RAM+COLOR1_POS
	ldx #$01
	jsr PrintSpriteColorName
	ldx #$03
	jmp UpdateSelectedColor
.endproc

.proc PrintSpriteColorNameMC
	tsx
	pha
	lda	VIC_SPR_MCOLOR
	and #(1 << SPRITE_PREVIEW)
	bne @Color

	; Show empty colorname
	ldx #$00

@Color:
	pla
.endproc

; Print the sprite color as name
;
; PARAM
; A - color value
; X - Clear color = 0
; CONSOLE_PTR
; STRING_PTR
.proc PrintSpriteColorName
	cpx #$00
	bne @PrintName
	lda #$10
	bne @PrintEmpty

@PrintName:
	and #$0f
@PrintEmpty:
	tsx
	pha
	asl
	clc
	adc $0100,x
	tax
	pla
	txa

	clc
	adc #<ColorNameTxt
	sta STRING_PTR
	lda #>ColorNameTxt
	adc #0
	sta STRING_PTR HI

	ldy #0
	ldx #3
	jmp PrintString
.endproc

.proc IncSpriteColor2
	inc SpriteColorValue+1
.endproc

.proc SetSpriteColor2
	COLOR2_POS = SCREEN_COLUMNS*(COLOR_TXT_ROW+1)+COLOR_TXT_COLUMN+8

	SetPointer (SCREEN_VIC+COLOR2_POS+2), CONSOLE_PTR

	lda SpriteColorValue+1
	sta VIC_SPR_MCOLOR0
	sta VIC_COLOR_RAM+COLOR2_POS
	jsr PrintSpriteColorNameMC
	ldx #$02
	jmp UpdateSelectedColor
.endproc

.proc IncSpriteColor3
	inc SpriteColorValue+2
.endproc

.proc SetSpriteColor3
	COLOR3_POS = SCREEN_COLUMNS*(COLOR_TXT_ROW+2)+COLOR_TXT_COLUMN+8

	SetPointer (SCREEN_VIC+COLOR3_POS+2), CONSOLE_PTR

	lda SpriteColorValue+2
	sta VIC_SPR_MCOLOR1
	sta VIC_COLOR_RAM+COLOR3_POS
	
	jsr PrintSpriteColorNameMC
	ldx #$03
	jmp UpdateSelectedColor
.endproc

; Draw a border around the preview sprite, so the user
; has a reference frame.
;
; Locals:
; CONSOLE_PTR - Pointer to screen
; MEMCPY_TGT - Pointer to screen
; $57 - Columns
; $58 - Lines
; 
.proc SpritePreviewBorder

	PREVIEW_LINE		= 3
	PREVIEW_COL 		= 30

	PREVIEW_POS_SMALL		= SCREEN_VIC + (SCREEN_COLUMNS*PREVIEW_LINE) + PREVIEW_COL
	PREVIEW_POS_BIG			= SCREEN_VIC + (SCREEN_COLUMNS*PREVIEW_LINE) + PREVIEW_COL-1

	lda #(1 << SPRITE_PREVIEW)
	sta VIC_SPR_HI_X
	lda #82
	sta VIC_SPR0_Y+(SPRITE_PREVIEW*2)

	; Clear the previous border area
	ldx #7					; Number of lines
	ldy #8					; max 6 columns

	SetPointer PREVIEW_POS_BIG, CONSOLE_PTR
	lda #SCREEN_COLUMNS
	sta RectangleLineOffset
	lda #' '
	jsr FillRectangle

	lda #97+128
	sta LeftBottomRight
	lda #119+128
	sta LeftBottomRight+1
	lda #97
	sta LeftBottomRight+2

	ldx #6					; Number of expanded lines
	lda VIC_SPR_EXP_Y
	and #(1 << SPRITE_PREVIEW)
	bne @YExpanded

	ldx #3					; Number of shrunk lines

	; Character reference Data Becker C128 Intern: P.800
	lda #97+128
	sta LeftBottomRight
	lda #98
	lda #121
	sta LeftBottomRight+1
	lda #97
	sta LeftBottomRight+2

@YExpanded:
	lda VIC_SPR_EXP_X
	and #(1 << SPRITE_PREVIEW)
	beq @NotXExpanded

	; Set sprite preview position
	; Unexpanded: x/y = 272/82 
	; Expanded: x/y = 268/82 
	lda #8
	sta VIC_SPR0_X+(SPRITE_PREVIEW*2)

	SetPointer PREVIEW_POS_BIG, CONSOLE_PTR
	lda #6				; Number expanded columns
	jmp @DrawBorder

@NotXExpanded:
	lda #16
	sta VIC_SPR0_X+(SPRITE_PREVIEW*2)

	SetPointer PREVIEW_POS_SMALL, CONSOLE_PTR
	lda #3				; Number of shrunk columns 

@DrawBorder:
	sta $57

	; Top left corner
	ldy #0
	lda #108
	sta (CONSOLE_PTR),y

	; Top right corner
	ldy $57
	iny
	lda #123
	sta (CONSOLE_PTR),y

	; Top line
	dey
	lda #98

@TopLine:
	sta (CONSOLE_PTR),y
	dey
	bne @TopLine

@LeftRight:
	jsr NextLine
	lda #97
	ldy $57
	iny
	sta (CONSOLE_PTR),y
	lda #97+128
	ldy #$00
	sta (CONSOLE_PTR),y
	dex
	bne @LeftRight

	; Bottom right corner
	ldy $57
	iny
	lda LeftBottomRight+2
	sta (CONSOLE_PTR),y

	dey
	lda LeftBottomRight+1

@BottomLine:
	sta (CONSOLE_PTR),y
	dey
	bne @BottomLine

	; Bottom left corner
	lda LeftBottomRight
	sta (CONSOLE_PTR),y

	;jsr TestChar
	rts
.endproc

; Copy the current frame to the preview sprite buffer
; and update the editing matrix.
.proc UpdateFrameEditor

	lda EditClearPreview
	and #$02
	bne @SkipCopy

	; Copy current sprite to preview
	lda EditClearPreview
	and #$01
	beq @OnlyCopy

	; Clear flag
	jsr ClearGrid
	jsr @UpdateFrame
	lda #$00
	sta EditClearPreview

	jmp ShowCursor

@OnlyCopy:
	lda CurFrame
	ldy #SPRITE_PREVIEW_TGT
	jsr CopySpriteFrame

@SkipCopy:
	jsr DrawBitMatrix
	jsr ShowCursor
@UpdateFrame:

	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*1), STRING_PTR

	lda CurFrame
	ldx MaxFrame
	ldy #32
	jmp PrintFrameCounter

.endproc

; Calculate the sprite buffer address for the specified frame.
; Result is stored in FramePtr.
;
; PARAM:
; A - framenumber 0..MAX_FRAMES-1
;
; RETURN:
; FramePtr - pointer to frame memory
;
.proc CalcFramePointer

	sta Multiplicand
	lda #$00
	sta Multiplicand HI

	sta Multiplier HI
	lda #SPRITE_BUFFER_LEN
	sta Multiplier
	jsr Mult16x16

	clc
	lda #<(SPRITE_USER_START)
	adc Product
	sta FramePtr
	lda #>(SPRITE_USER_START)
	adc Product HI
	sta FramePtr+1

	rts

.endproc

.proc NextFrame
	ldy CurFrame
	cpy MaxFrame
	bne @Update
	ldy #$ff		; Wrap around to first frame

@Update:
	iny
	ldx CurFrame
	jmp SwitchFrame
.endproc

.proc PreviousFrame

	ldy CurFrame
	bne @Update

	ldy MaxFrame
	iny

@Update:
	dey
	ldx CurFrame
	jmp SwitchFrame
.endproc

.proc GotoFrame
	lda MaxFrame
	bne :+

	jsr Flash
	rts
:
	SetPointer (INPUT_LINE), CONSOLE_PTR
	ldy #$00
	jsr ClearLine

	; We don't want a default value here, as we can not know
	; where the user wants to jump to, and it is annoying to
	; always have to delete the default first, before the target
	; can be entered.
	lda #$01
	sta InputNumberEmpty

	lda CurFrame
	ldy #$00
	jsr EnterFrameNumber
	bcs @Cancel

	; Already there
	cmp CurFrame
	beq @Cancel

	; Frame number we go to.
	tay

	; Reset the empty input flag to default.
	lda #$00
	sta InputNumberEmpty

	; User entered the current frame number?
	cpy CurFrame
	beq @Cancel		; Then we are done.

	ldx CurFrame
	jsr SwitchFrame

@Cancel:
	SetPointer (INPUT_LINE), CONSOLE_PTR
	ldy #0
	jmp ClearLine
.endproc

.proc DeleteCurrentFrame
	lda MaxFrame
	beq @Clear		; Only a single frame, so we just delete it.

	lda CurFrame
	tax

	; A - Last frame
	; X - First frame
	jsr DeleteFrameRange
	jmp UpdateFrameEditor

@Clear:
	jsr ClearGridHome
	jmp ClearStatusLines
.endproc

.proc DeleteRange
	lda CurFrame
	bne :+
	cmp MaxFrame		; Only one frame?
	beq @Cancel			; Nothing to delete
:
	jsr SaveDirtyFrame

	SetPointer (INPUT_LINE), CONSOLE_PTR
	SetPointer DeleteTxt, STRING_PTR
	ldy #$00
	jsr PrintStringZ
	iny
	tya
	clc
	adc #6
	sta FramenumberOffset

	lda #1
	sta FrameNumberStartLo
	lda CurFrame
	sta InputNumberCurVal
	lda MaxFrame
	sta FrameNumberStartHi
	sta FrameNumberEndHi
	; Y - End of delete string
	jsr EnterFrameNumbers
	bcs @Done

	ldx FrameNumberStart
	lda FrameNumberEnd
	jsr DeleteFrameRange
	jsr UpdateFrameEditor

@Done:
	SetPointer (INPUT_LINE), CONSOLE_PTR
	ldy #$00
	jmp ClearLine

@Cancel:
	jsr Flash
	jmp @Done

.endproc

; Delete a range of frames
;
; PARAMS:
; A - Last frame
; X - First frame
.proc DeleteFrameRange
	cmp MaxFrame
	beq @LastFrame

	; Example: Frames 1..10
	; Delete 3..5 -> Copy 6..10 -> 3
	stx FrameNumberStartLo
	sta FrameNumberStartHi

	; Set first frame as target (3)
	txa
	tay

	; Lo is the frame after last (6)
	ldx FrameNumberStartHi
	inx

	lda MaxFrame

	; A - Last frame
	; X - First frame
	; Y - Target frame
	jsr CopyFrameBufferRange

	; Number of frames deleted
	sec
	lda FrameNumberStartHi
	sbc FrameNumberStartLo
	sta FrameNumberStartHi

	; New maxframe - deleted frames
	lda MaxFrame
	clc
	sbc FrameNumberStartHi
	sta MaxFrame

	lda MaxFrame
	cmp CurFrame
	bge @Done

	sta CurFrame
	rts

@LastFrame:
	cpx #$00
	beq :+
	dex
:
	stx MaxFrame
	stx CurFrame

@Done:
	rts
.endproc

.proc CopyFromFrame
	lda MaxFrame
	beq @Error

	SetPointer (INPUT_LINE), CONSOLE_PTR

	ldx CurFrame
	beq :+			; If we are not on the first frame
	dex				; we set the previous frame to default
					; as it doesn't make sense to provide the
					; current frame as default value when it
					; can not be used as we don't copy to
					; itself.

:	txa
	ldy #$00
	jsr EnterFrameNumber
	bcs @Cancel

	; Copy to itself doesn't make sense
	cmp CurFrame
	beq @Cancel

	; A - contains the source frame from the input as return value
	ldx CurFrame
	ldy #$00
	jsr CopySpriteFrame

	jsr UpdateFrameEditor

@Cancel:
	SetPointer (INPUT_LINE), CONSOLE_PTR
	ldy #0
	jsr ClearLine
	rts

@Error:
	jsr Flash
	jmp @Cancel
.endproc

; Append a new frame at the end and copy the current
; frame to it.
.proc AppendFrameCopy
	ldx MaxFrame
	cpx #MAX_FRAMES-1
	beq @Done		; We still call AppendFrame to
					; trigger the error handling as
					; it will also fail

	; Copy the current frame to the last frame+1
	inx
	ldy #SPRITE_PREVIEW_SRC		; Copy frame to frame
	jsr CopySpriteFrame
	
@Done:
	jmp AppendFrame
.endproc

; Create a new frame at the end and switch to it.
.proc AppendFrameKey
	; The new frame should be cleared
	lda #$01
	sta EditClearPreview
.endproc

; Append a new frame at the end
.proc AppendFrame
	ldy MaxFrame
	cpy #MAX_FRAMES-1
	beq @Stopped

	iny
	sty MaxFrame
	ldx CurFrame
	jmp SwitchFrame
@Stopped:
.endproc

.proc MaxFramesReached
	SetPointer (STATUS_LINE), CONSOLE_PTR
	SetPointer MaxFramesReachedTxt, STRING_PTR
	
	ldy #0
	jsr PrintStringZ

	; Reset the clear flag.
	lda #$00
	sta EditClearPreview
	jsr Flash
	ldy #0
	jmp ClearLine

.endproc

.proc InsertEmptyFrame
	lda #$01
.endproc

; Insert a frame at the current position
;
; PARAMS:
; A  - 1 Clear Current frame
;      0 Keep copy of current frame
.proc InsertFrame
	ldy MaxFrame
	cpy #MAX_FRAMES-1
	beq @Stopped

	pha
	ldx CurFrame
	jsr SaveDirtyFrame

	inc MaxFrame

	; X - First frame
	; A - Last frame
	; Y - Target frame
	lda MaxFrame
	ldx CurFrame
	ldy CurFrame
	iny
	jsr CopyFrameBufferRange

	pla
	sta EditClearPreview
	jmp UpdateFrameEditor

@Stopped:
	jmp MaxFramesReached
.endproc

.proc InsertCopyFrame
	lda #$00
	jmp InsertFrame
.endproc

; Set the specified frame as the current editor frame
;
; PARAMS:
; X - Old frame
; Y - New frame
;
; RETURN: -
.proc SwitchFrame
	sty CurFrame
	jsr SaveDirtyFrame
	jmp UpdateFrameEditor
.endproc

.proc UndoSpriteFrame
	lda CurFrame
	ldy #SPRITE_PREVIEW_TGT
	jsr CopySpriteFrame

	jsr ClearDirty
	jmp UpdateFrameEditor
.endproc

; Copy the sprite buffer from source to target
;
; PARAM:
; A - Source frame
; X - Target frame
; Y - 0 = Normal copy
;     SPRITE_PREVIEW_SRC(1) - Copy sprite from preview to target
;     SPRITE_PREVIEW_TGT(2) - Copy sprite from source to preview
;
; If Y is not 0, the value in A or X is ignored
; depending on Y. If Y is SPRITE_PREVIEW_SRC then
; A is ignored, otherwise X. Only if Y is 0
; will both values be needed.
.proc CopySpriteFrame

	; Remember the source
	sta MEMCPY_SRC
	sty CopyFrameFlag
	beq @CalcTarget
	cpy #SPRITE_PREVIEW_TGT
	bne @CalcTarget
	SetPointer SPRITE_PREVIEW_BUFFER, MEMCPY_TGT
	jmp @CheckSrc

@CalcTarget:
	txa
	jsr CalcFramePointer

	lda FramePtr
	sta MEMCPY_TGT
	lda FramePtr+1
	sta MEMCPY_TGT HI

@CheckSrc:
	ldy CopyFrameFlag
	beq @CalcSrc
	cpy #SPRITE_PREVIEW_SRC
	bne @CalcSrc
	SetPointer SPRITE_PREVIEW_BUFFER, MEMCPY_SRC
	jmp CopyFrameBuffer

@CalcSrc:
	lda MEMCPY_SRC
	jsr CalcFramePointer
	lda FramePtr
	sta MEMCPY_SRC
	lda FramePtr+1
	sta MEMCPY_SRC HI
.endproc

; Copy a single sprite frame buffer
;
; PARAMS:
; MEMCPY_SRC
; MEMCPY_TGT
.proc CopyFrameBuffer
	ldy #SPRITE_BUFFER_LEN
	jmp memcpy255
.endproc

; Copy a range of frames. The caller is
; responsible that the values are not
; beyond the boundaries 0 < N < MAX_FRAME.
;
; PARAMS:
; X - First frame
; A - Last frame
; Y - Target frame
;
.proc CopyFrameBufferRange

	sta MoveLastFrame
	stx MoveFirstFrame
	sty MoveTargetFrame

	txa
	jsr CalcFramePointer
	lda FramePtr
	sta MEMCPY_SRC
	lda FramePtr+1
	sta MEMCPY_SRC HI

	lda MoveTargetFrame
	jsr CalcFramePointer
	lda FramePtr
	sta MEMCPY_TGT
	lda FramePtr+1
	sta MEMCPY_TGT HI

	; Last frame is increased by 1 because we want the
	; endaddress of the last frame.
	ldx MoveLastFrame
	inx
	txa
	jsr CalcFramePointer

	; Now calculate the length of the blocks
	sec
	lda FramePtr
	sbc MEMCPY_SRC
	tax
	lda FramePtr+1
	sbc MEMCPY_SRC HI
	jmp memcpy

.endproc

; Print the frame counters N/M
; STRING_PTR - point to start of the first digit.
; A - First frame - 0 ... MAX_FRAMES-1
; X - Last frame - 0 ... MAX_FRAMES-1
; Y - offset in line
;
; Locals:
; TMP_VAL_2
.proc PrintFrameCounter

	LAST_FRAME_VAL = EditCurChar

	inx					; Convert to 1..N for display
	stx LAST_FRAME_VAL

	; Lower vlaue
	clc
	adc #$01			; Convert to 1..N for display
	sta BINVal

	; We assume that at most 255 frames are more then enough.
	ldx #$00
	stx BINVal+1		; Clear HiByte

	lda #3				; Max 3 digits (one byte)
	ldx #DEC_ALIGN_RIGHT
	jsr PrintDecimal

	; Upper value
	lda LAST_FRAME_VAL
	sta BINVal

	lda #3				; Max 3 digits (one byte)
	ldx #DEC_ALIGN_RIGHT
	iny					; Skip the separator
	jmp PrintDecimal
.endproc

; Check if the current frame has changes. If yes
; it will be copied to it's target.
;
; PARAMS:
; X - Target frame
.proc SaveDirtyFrame
	lda EditFlags
	and #EDIT_DIRTY
	beq @SkipCopy

	jsr ClearDirty

	; Copy the current editor frame to the sprite
	ldy #SPRITE_PREVIEW_SRC
	jmp CopySpriteFrame

@SkipCopy:
	rts
.endproc

; Function asking the user for framenumber and
; filename which is used in all saving dialogs
; A prefix must be set so the user knows which
; save method he uses.
;
; RETURN:
; C - set if canceled
;
.proc InitSaveDlg
	; Copy the current edit buffer to the sprite frame buffer
	ldx CurFrame
	jsr SaveDirtyFrame

	jsr WaitKeyboardRelease
	jsr GetSpriteSaveInfoDlg
	bcs @Cancel

	; Calculate address of first frame where we want
	; to save from.
	lda FrameNumberStart
	jsr CalcFramePointer

	lda FramePtr
	sta MEMCPY_SRC
	lda FramePtr+1
	sta MEMCPY_SRC HI

	lda FrameNumberEnd
	jsr CalcFramePointer

	; End of frame
	clc
	lda FramePtr
	adc #SPRITE_BUFFER_LEN
	sta MEMCPY_TGT
	lda FramePtr+1
	adc #$00
	sta MEMCPY_TGT HI

	SetPointer (INPUT_LINE), CONSOLE_PTR
	ldy #$00
	jsr ClearLine

	clc
	rts

@Cancel:
	ldy #$00
	jsr ClearLine

	sec
	rts

.endproc

.proc SaveSprites
	; Set prefix
	SetPointer SaveTxt, STRING_PTR
	jsr InitSaveDlg
	bcs @Cancel

	; print WRITING ...
	SetPointer WritingTxt, STRING_PTR
	ldy #$00
	jsr PrintStringZ

	; ... and append the frame counter 
	SetPointer FrameTxt, STRING_PTR
	jsr PrintStringZ

	lda CONSOLE_PTR
	sta STRING_PTR
	lda CONSOLE_PTR HI
	sta STRING_PTR HI

	lda FrameNumberStart
	ldx FrameNumberEnd
	ldy #14
	jsr PrintFrameCounter

	lda #$00
	sta FrameNumberStart
	sta FrameNumberCur

	SetPointer SpriteSaveProgress, WriteFileProgressPtr
	lda #'s'
	sta FileType
	jsr SaveFile
	bcs :+				; Error was already shown

	SetPointer DoneTxt, STRING_PTR
	ldy #$00
	jsr PrintStringZ
	jsr Delay
:
	jmp ClearStatusLines

@Cancel:
.endproc

.proc SpriteSaveProgress

	; We have to reset the pointers, just in case.
	; If the user was asked to overwrite the
	; file, these pointers point "somewhere", thus
	; corrupting the memory.
	lda CONSOLE_PTR
	sta STRING_PTR
	lda CONSOLE_PTR HI
	sta STRING_PTR HI

	ldx FrameNumberCur
	inx
	cpx #SPRITE_BUFFER_LEN-1
	bne @Done

	lda FrameNumberStart
	ldx FrameNumberEnd
	ldy #14
	jsr PrintFrameCounter

	inc FrameNumberStart
	ldx #$00

@Done:
	stx FrameNumberCur
	clc
	rts
.endproc

; Ask the user for the frame start and end to save.
; Also for the filename and device number.
;
.proc GetSpriteSaveInfoDlg

	SetPointer (INPUT_LINE), CONSOLE_PTR
	ldy #0
	jsr ClearLine

	ldy #0
	jsr PrintStringZ

	; Append FrameTxt after our prefix
	; to position the cursor on the first
	; input field.
	tya
	clc
	adc #6				; "FRAME:"
	sta FramenumberOffset

	; Set Frame limits
	lda #0
	sta InputNumberCurVal
	sta FrameNumberStartLo
	lda MaxFrame
	sta FrameNumberStartHi
	sta FrameNumberEndHi

	jsr EnterFrameNumbers
	bcs @Cancel

	ldy #0
	jsr ClearLine

	; And finally get the filename
	jsr EnterFilename
	bcs @Cancel

@Done:
	ldy #0
	jsr ClearLine

	; Everything went ok
	clc
	rts

@Cancel:
	jsr @Done

	sec
	rts
.endproc

; Enter low and high frame numbers.
;
; PARAMS:
; Y - Offset of frame string.
; CONSOLE_PTR - Screen location for input
; FrameNumberStartLo	- lowest value for start
; FrameNumberStartHi	- Highest value for start
; FrameNumberEndHi		- Highest value for end range
;                         lowest value is the start value entered
; FramenumberOffset 	- First Input field
; InputNumberCurVal		- Current value of lowframe
;
; RETURN:
; Carry - set if canceled
; Y - Offset of frame string.
; FrameNumberStart
; FrameNumberEnd
.proc EnterFrameNumbers
	SetPointer FrameTxt, STRING_PTR
	jsr PrintStringZ

	lda CONSOLE_PTR
	sta STRING_PTR
	lda CONSOLE_PTR HI
	sta STRING_PTR HI

	lda FrameNumberStartLo
	ldx FrameNumberEndHi
	ldy FramenumberOffset
	jsr PrintFrameCounter

	lda #3
	sta InputNumberMaxDigits

	; Get low frame
	clc
	lda CONSOLE_PTR
	adc FramenumberOffset
	sta CONSOLE_PTR
	lda CONSOLE_PTR HI
	adc #$00
	sta CONSOLE_PTR HI

	ldx #1
	lda InputNumberCurVal
	clc
	adc #1
	ldy MaxFrame
	iny					; User deals with 1..N
	jsr EnterNumberValue
	bcs @Cancel
	sta FrameNumberStart
	dec FrameNumberStart	; Back to 0 based

	; Get high frame +4
	clc
	lda CONSOLE_PTR
	adc #4
	sta CONSOLE_PTR
	lda CONSOLE_PTR HI
	adc #$00
	sta CONSOLE_PTR HI

	; A - CurValue
	; X - MinValue
	; Y - MaxValue
	ldx FrameNumberStart ; User deals with 1..N
	inx
	ldy FrameNumberEndHi
	iny
	tya
	jsr EnterNumberValue
	bcs @Cancel
	sta FrameNumberEnd
	dec FrameNumberEnd	; Back to 0 based

	; Everything went ok
	clc
	rts

@Cancel:
	sec
	rts
.endproc

; Input a single frame number. It prints the frame text to 
; the specified location in CONSOLE_PTR.
;
; PARAMS:
; A - Framenumber to use as default
; Y - Offset of frame string.
; CONSOLE_PTR - position of the FRAME text.
; InputNumberMaxDigits - Length of input string (1...3)
;
; RETURN:
; A - Lobyte of value
; X - Hibyte of value
; Carry - clear (OK) : set (CANCEL)
; If carry is set the value in A is undefined and should not be used.
.proc EnterFrameNumber
	pha
	SetPointer FrameTxt, STRING_PTR
	ldx #FrameTxtOnlyLen
	jsr PrintString

	lda #3
	sta InputNumberMaxDigits

	; Set intput cursor after the text.
	clc
	tya
	adc CONSOLE_PTR
	sta CONSOLE_PTR
	lda CONSOLE_PTR HI
	adc #$00
	sta CONSOLE_PTR HI

	; Framenumber is internally stored as 0..N-1
	; but the user should be able to enter 1...N
	; so we have to adjust it.
	pla
	tax
	inx
	txa
	ldx #$01
	ldy MaxFrame
	iny
	jsr EnterNumberValue
	bcs @Done

	; Back to 0..N-1
	sec
	sbc #1

	clc

@Done:
	rts
.endproc

.proc LoadSprites

	jsr HideCursor
	jsr WaitKeyboardRelease
	jsr EnterFilename
	bcc :+
	jmp @Cancel
:
	; Reset to first frame
	lda #$00
	sta FrameNumberCur
	sta CurFrame
	sta MaxFrame
	jsr CalcFramePointer

	lda FramePtr
	sta MEMCPY_TGT
	lda FramePtr+1
	sta MEMCPY_TGT HI

	; print READING ...
	SetPointer (INPUT_LINE), CONSOLE_PTR
	ldy #$00
	jsr ClearLine

	SetPointer LoadingTxt, STRING_PTR
	ldy #$00
	jsr PrintStringZ

	; ... and append the frame counter 
	SetPointer FrameTxt, STRING_PTR
	jsr PrintStringZ

	lda CONSOLE_PTR
	sta STRING_PTR
	lda CONSOLE_PTR HI
	sta STRING_PTR HI

	lda #$ff
	ldx #$ff
	ldy #14
	jsr PrintFrameCounter

	SetPointer SpriteLoadProgress, ReadFileProgressPtr
	lda #'s'
	sta FileType
	jsr LoadFile
	bcc @Success

	ldx #$00
	stx CurFrame
	inx					; Will be decreased on exit
	stx MaxFrame
	jsr ClearGridHome
	ldx #$00
	ldy #SPRITE_PREVIEW_SRC
	jsr CopySpriteFrame

	lda #$02
	bne @Failed

@Success:
	SetPointer DoneTxt, STRING_PTR
	ldy #$00
	jsr PrintStringZ
	lda #$00

@Failed:
	sta EditClearPreview
	jsr ClearDirty

	; When we reach EOF, we are already past the last
	; byte of the last frame and the counter is already
	; increased, so we have to decrease it here.
	lda #$00
	sta CurFrame
	dec MaxFrame
	jsr MoveCursorHome
	jsr UpdateFrameEditor
	jsr ClearStatusLines
	rts

@Cancel:
	jmp ShowCancel
.endproc

.proc SpriteLoadProgress

	ldx FrameNumberCur
	inx
	cpx #SPRITE_BUFFER_LEN-1
	bne @Done

	ldx #$00
	lda MaxFrame
	cmp #MAX_FRAMES
	beq @MaxReached

	lda CurFrame
	ldx MaxFrame
	ldy #14
	jsr PrintFrameCounter

	inc CurFrame
	inc MaxFrame
	ldx #$00

@Done:
	stx FrameNumberCur
	clc
	rts

@MaxReached:
	sec
	rts
.endproc

; Write a single frame as BASIC DATA
;
; PARAM:
; DATA_PTR - Spriteframe
; ExportCurLineNr
; ExportStepSize
;
; RETURN:
; C - set on error
;
.proc WritePrettySprite

	lda #$00
	sta ExportCurIndex
	sta BINVal+1

@WriteLine:
	ldy #0
	jsr CalcStringPointer

	jsr IncBasicLineNr

	lda #$83			; DATA
	AddBasicByte
	lda #' '
	AddBasicByte

	lda #3
	sta ExportCurByte

@WriteDATAValue:
	sty ExportTmp
	ldy ExportCurIndex
	lda (DATA_PTR),y
	inc ExportCurIndex
	ldy ExportTmp
	sta BINVal
	lda #3
	ldx #DEC_ALIGN_RIGHT
	jsr PrintDecimal
	lda #','
	AddBasicByte
	dec ExportCurByte
	bne @WriteDATAValue

	dey		; Remove the last ','
	lda #0
	AddBasicByte

	SetPointer LineMem, MEMCPY_SRC
	jsr CalcLineEnding

	; Save the current DATA line
	sty ExportTmp
	ldx #2
	jsr WriteFile
	bcs @Error

	ldy ExportTmp

	; A sprite has only 3*7 bytes, but the
	; spritepointer adresses 64 bytes, so
	; we have to add a fake byte after the
	; last sprite byte. This will make a POKE
	; loop easier, because the FOR..NEXT can
	; simply iterate on, without skipping this
	; extra byte.
	lda #SPRITE_BUFFER_LEN-1
	cmp ExportCurIndex
	bgt @WriteLine

	; One extra byte
	lda #1
	sta ExportCurByte
	dey
	lda #','
	AddBasicByte

	lda #SPRITE_BUFFER_LEN
	cmp ExportCurIndex
	bne @WriteDATAValue

	clc
	lda DATA_PTR
	adc #SPRITE_BUFFER_LEN
	sta DATA_PTR
	lda DATA_PTR HI
	adc #0
	sta DATA_PTR HI

	clc

@Error:
	rts

.endproc

.proc SelectMultiColor1
	ldx #$01
	jmp SetMultiColorValue
.endproc

.proc SelectMultiColor2
	ldx #$02
	jmp SetMultiColorValue
.endproc

.proc SelectMultiColor3
	ldx #$03
	jmp SetMultiColorValue
.endproc

; X = Color to use
.proc SetMultiColorValue
	jsr IsMulticolor
	bne SetMultiColor
	rts
.endproc

.proc SetMultiColor
	stx MultiColorValue
	txa
	clc
	adc #'0'
	sta SCREEN_VIC+SCREEN_COLUMNS*(COLOR_TXT_ROW+3)+COLOR_TXT_COLUMN+6
.endproc

.proc UpdateSelectedColor
	ldx MultiColorValue
	lda SpriteColorValue-1,x
	sta VIC_COLOR_RAM+SCREEN_COLUMNS*(COLOR_TXT_ROW+3)+COLOR_TXT_COLUMN+8

	rts
.endproc

.proc ToggleSpritePixel
	jsr IsMulticolor
	bne @ToggleMCPixel
	jmp ToggleGridPixel

@ToggleMCPixel:
	rts

.endproc

; **********************************************
.data

MaxFrameValue: .word MAX_FRAMES
FramePETSCIITxt: .byte "frame: "
FramePETSCIITxtLen = * - FramePETSCIITxt

SelectedColorTxt: .byte "SELCT:  ",81,0

FrameTxt: .byte "FRAME:  1/  1",0
FrameTxtOnlyLen = 6
SpriteFramesMaxTxt: .byte "# FRAMES:",0
CurFrame: .byte $00		; Number of active frame 0...MAX_FRAMES-1
MaxFrame: .byte $00		; Maximum frame number in use 0..MAX_FRAMES-1
SpriteColorDefaults: .byte COL_LIGHT_GREY, COL_GREEN, COL_BLUE
MaxFramesReachedTxt: .byte "MAX. # OF FRAMES REACHED!",0

WelcomeSpriteData:
	.byte $00, $00, $00
	.byte $12, $64, $BC
	.byte $12, $94, $A0
	.byte $1E, $F4, $B8
	.byte $12, $93, $20
	.byte $12, $93, $3C
	.byte $00, $00, $00
	.byte $07, $A5, $20
	.byte $04, $25, $A0
	.byte $07, $25, $60
	.byte $04, $25, $20
	.byte $04, $19, $20
	.byte $00, $00, $00
	.byte $00, $00, $00
	.byte $00, $66, $00
	.byte $00, $66, $00
	.byte $02, $00, $40
	.byte $02, $00, $40
	.byte $01, $00, $80
	.byte $00, $FF, $00
	.byte $00, $00, $00
	.byte 0

SpriteEditorKeyMap:
	DefineKey 0, $1d, REPEAT_KEY,    MoveCursorRight				; CRSR-Right
	DefineKey 0, $11, REPEAT_KEY,    MoveCursorDown					; CRSR-Down
	DefineKey 0, $20, REPEAT_KEY,    ToggleSpritePixel				; SPACE
	DefineKey 0, $2e, REPEAT_KEY,    NextFrame						; .
	DefineKey 0, $2c, REPEAT_KEY,    PreviousFrame					; ,
	DefineKey 0, $14, REPEAT_KEY,    DeleteColumn					; DEL
	DefineKey 0, $13, NO_REPEAT_KEY, MoveCursorHome					; HOME
	DefineKey 0, $0d, NO_REPEAT_KEY, MoveCursorNextLine				; ENTER
	DefineKey 0, $43, NO_REPEAT_KEY, CopyFromFrame					; C
	DefineKey 0, $44, NO_REPEAT_KEY, DeleteCurrentFrame				; D
	DefineKey 0, $45, NO_REPEAT_KEY, ExportBasicDataDlg				; E
	DefineKey 0, $46, NO_REPEAT_KEY, FlipVertical					; F
	DefineKey 0, $47, NO_REPEAT_KEY, GotoFrame						; G
	DefineKey 0, $49, NO_REPEAT_KEY, InvertGrid						; I
	DefineKey 0, $4e, NO_REPEAT_KEY, AppendFrameKey					; N
	DefineKey 0, $4c, NO_REPEAT_KEY, LoadSprites					; L
	DefineKey 0, $53, NO_REPEAT_KEY, SaveSprites					; S
	DefineKey 0, $4d, NO_REPEAT_KEY, ToggleMulticolor				; M
	DefineKey 0, $58, NO_REPEAT_KEY, TogglePreviewX					; X
	DefineKey 0, $59, NO_REPEAT_KEY, TogglePreviewY					; Y
	DefineKey 0, '1', NO_REPEAT_KEY, IncSpriteColor1				; 1
	DefineKey 0, '2', NO_REPEAT_KEY, IncSpriteColor2				; 2
	DefineKey 0, '3', NO_REPEAT_KEY, IncSpriteColor3				; 3
	DefineKey 0, $55, NO_REPEAT_KEY, UndoSpriteFrame				; U
	DefineKey 0, $03, NO_REPEAT_KEY, SetMainExit					; RUN/STOP

	; SHIFT keys
	DefineKey KEY_SHIFT, $9d, REPEAT_KEY,    MoveCursorLeft			; SHIFT CRSR-Right (CRSR-Left)
	DefineKey KEY_SHIFT, $91, REPEAT_KEY,    MoveCursorUp			; SHIFT CRSR-Down (CRSR-Up)
	DefineKey KEY_SHIFT, $ce, NO_REPEAT_KEY, InsertEmptyFrame		; SHIFT-N
	DefineKey KEY_SHIFT, $c4, NO_REPEAT_KEY, DeleteRange			; SHIFT-D
	DefineKey KEY_SHIFT, $C6, NO_REPEAT_KEY, FlipHorizontal			; SHIFT-F
	DefineKey KEY_SHIFT, $94, REPEAT_KEY,    InsertColumn			; INS
	DefineKey KEY_SHIFT, $93, NO_REPEAT_KEY, ClearGridHome			; CLEAR
	DefineKey KEY_SHIFT, $21, NO_REPEAT_KEY, SelectMultiColor1		; SHIFT 1
	DefineKey KEY_SHIFT, $22, NO_REPEAT_KEY, SelectMultiColor2		; SHIFT 2
	DefineKey KEY_SHIFT, $23, NO_REPEAT_KEY, SelectMultiColor3		; SHIFT 3
	DefineKey KEY_SHIFT|KEY_CTRL, $94, REPEAT_KEY, InsertColumns	; CTRL-INS
	DefineKey KEY_SHIFT|KEY_COMMODORE, $94, REPEAT_KEY, InsertLine	; CMDR-INS
	DefineKey KEY_SHIFT|KEY_COMMODORE, $91, REPEAT_KEY, ShiftGridUp	; SHIFT CMDR CRSR Up
	DefineKey KEY_SHIFT|KEY_COMMODORE, $9d, REPEAT_KEY, ShiftGridLeft	; SHIFT CMDR CRSR Left

	; COMMODORE keys
	DefineKey KEY_COMMODORE, $aa, NO_REPEAT_KEY, AppendFrameCopy	; CMDR-N
	DefineKey KEY_COMMODORE, $b3, REPEAT_KEY, ShiftGridUp			; CMDR-W
	DefineKey KEY_COMMODORE, $ae, REPEAT_KEY, ShiftGridDown			; CMDR-S
	DefineKey KEY_COMMODORE, $b0, REPEAT_KEY, ShiftGridLeft			; CMDR-A
	DefineKey KEY_COMMODORE, $ac, REPEAT_KEY, ShiftGridRight		; CMDR-D
	DefineKey KEY_COMMODORE, $91, REPEAT_KEY, ShiftGridDown			; CMDR CRSR-Down
	DefineKey KEY_COMMODORE, $9d, REPEAT_KEY, ShiftGridRight		; CMDR CRSR-Right
	DefineKey KEY_COMMODORE, $94, REPEAT_KEY, DeleteLine			; CMDR-DEL

	; CONTROL keys
	DefineKey KEY_CTRL, $0e, NO_REPEAT_KEY, InsertCopyFrame			; CTRL-N
	DefineKey KEY_CTRL, $a0, REPEAT_KEY, DeleteColumns				; CTRL-DEL

	; Extended keys
	DefineKey KEY_EXT, $1d, REPEAT_KEY,      MoveCursorRight		; CRSR-Right/Keypad
	DefineKey KEY_EXT, $9d, REPEAT_KEY,      MoveCursorLeft			; CRSR-Left/Keypad
	DefineKey KEY_EXT, $11, REPEAT_KEY,      MoveCursorDown			; CRSR-Down/Keypad
	DefineKey KEY_EXT, $91, REPEAT_KEY,      MoveCursorUp			; CRSR-Up/Keypad

	DefineKey KEY_EXT|KEY_SHIFT, $1d, REPEAT_KEY, NextFrame			; CRSR-Right/Keypad
	DefineKey KEY_EXT|KEY_SHIFT, $9d, REPEAT_KEY, PreviousFrame		; CRSR-Left/Keypad

	DefineKey KEY_EXT|KEY_COMMODORE, $91, REPEAT_KEY, ShiftGridUp	; CMDR-CRSR-Up
	DefineKey KEY_EXT|KEY_COMMODORE, $11, REPEAT_KEY, ShiftGridDown	; CMDR-CRSR-Down
	DefineKey KEY_EXT|KEY_COMMODORE, $9d, REPEAT_KEY, ShiftGridLeft	; CMDR-CRSR-Left
	DefineKey KEY_EXT|KEY_COMMODORE, $1d, REPEAT_KEY, ShiftGridRight; CMDR-CRSR-Right

	; End of map
	DefineKey 0,0,0,0

; The applicaiton data ends here. After that is BSS data which
; does not need to be initialized and will be set to 0 on startup.
;====================================================
.bss

SpriteColorValue: .byte 0, 0, 0
MultiColorValue: .byte 0

FrameNumberStart: .byte 0		; first frame input
FrameNumberEnd: .byte 0			; last frame input
FrameNumberCur: .byte 0			; current frame
FramenumberOffset: .byte 0

; Range values for Frame number input
FrameNumberStartLo: .byte 0
FrameNumberStartHi: .byte 0
FrameNumberEndHi: .byte 0

MoveFrameCnt: .byte 0
MoveFirstFrame: .byte 0
MoveLastFrame: .byte 0
MoveTargetFrame: .byte 0
CopyFrameFlag: .word 0

FramePtr: .word 0	; Address for current frame pointer

.popseg
