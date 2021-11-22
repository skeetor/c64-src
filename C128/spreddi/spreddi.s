; Sprite and character editor for C128 with CA65 assembler
; Written by Gerhard W. Gruber in 11.09.2021
;
.macpack cbm

.include "screenmap.inc"

.include "c128_system.inc"
.include "tools/misc.inc"
.include "tools/intrinsics.inc"

; Zeropage variables
CONSOLE_PTR			= SCREEN_PTR	; $e0

ZP_BASE				= $40
ZP_BASE_LEN			= $0f
DATA_PTR			= ZP_BASE+0
STRING_PTR			= ZP_BASE+2
KEYMAP_PTR			= ZP_BASE+4
MEMCPY_SRC			= ZP_BASE+6
MEMCPY_TGT			= ZP_BASE+8
MEMCPY_LEN			= ZP_BASE+10
CURSOR_LINE			= ZP_BASE+12
PIXEL_LINE			= ZP_BASE+14

KEYTABLE_PTR		= $fb

; Library variables
KEY_LINES			= C128_KEY_LINES

; Position of the color text.
COLOR_TXT_ROW = 12
COLOR_TXT_COLUMN = 27
; Position of the character that shows the selected color 


; Sprite editor constants
; =======================
SCREEN_VIC			= $0400
SCREEN_COLUMNS		= 40
SCREEN_LINES		= 23
STATUS_LINE			= SCREEN_LINES-1
SPRITE_PTR			= $7f8
SPRITE_PREVIEW		= 0	; Number of the previewsprite
SPRITE_CURSOR		= 1	; Number of the cursor sprite

SPRITE_BUFFER_LEN	= 64
SPRITE_BASE			= $2000		; Sprite data pointer for preview.
SPRITE_USER_START	= SPRITE_BASE+2*SPRITE_BUFFER_LEN	; First two sprite frames are reserved
SPRITE_PREVIEW_BUFFER = SPRITE_BASE+(SPRITE_PREVIEW*SPRITE_BUFFER_LEN)
SPRITE_END			= $5000
MAIN_APP_BASE		= SPRITE_END; Address where the main code is relocated to
MAX_FRAMES			= ((MAIN_APP_BASE - SPRITE_USER_START)/SPRITE_BUFFER_LEN) ; The first frame
								; is used for our cursor sprite, so the first
								; user sprite will start at SPRITE_BASE+SPRITE_BUFFER_LEN


; Flags for copying sprites from/to the preview buffer
SPRITE_PREVIEW_SRC	= $01
SPRITE_PREVIEW_TGT	= $02


; Editor bit flags
EDIT_DIRTY			= $01

SPRITE_COLOR		= VIC_SPR0_COLOR
SPRITE_EXP_X		= VIC_SPR_EXP_X
SPRITE_EXP_Y		= VIC_SPR_EXP_Y 

; Special screen codes for drawing the border
CHAR_ROUND_TOP_LEFT		= $55
CHAR_ROUND_TOP_RIGHT	= $49
CHAR_ROUND_BOT_LEFT		= $4A
CHAR_ROUND_BOT_RIGHT	= $4B
CHAR_VERTICAL			= $42
CHAR_HORIZONTAL			= $43
CHAR_SPLIT_LEFT			= $6B
CHAR_SPLIT_RIGHT		= $73
CHAR_SPLIT_BOT			= $71
CHAR_SPLIT_TOP			= $72

; MMU Konfiguration. Data Becker 128 Intern P. 150
EDITOR_RAM_CFG			= %00001110	; Bank 0 + $D000 + $C000-$FFFF
EDITOR_COMMON_RAM_CFG	= %00000000 ; No common area 

.export __LOADADDR__ = *
.export STARTADDRESS = *

.segment "LOADADDR"
.byte .LOBYTE( __LOADADDR__ ), .HIBYTE( __LOADADDR__ )

.segment "CODE"

_EntryPoint = MainEntry

basicstub:
.word @nextLine
.word 10 ; line number
.byte $9e ;SYS
.byte ' '

;.byte <(((_EntryPoint / 10000) .mod 10) + $30)
.byte <(((_EntryPoint / 1000)  .mod 10) + $30)
.byte <(((_EntryPoint / 100 )  .mod 10) + $30)
.byte <(((_EntryPoint / 10 )   .mod 10) + $30)
.byte <((_EntryPoint           .mod 10) + $30)
.byte 0 ;end of line

@nextLine:
.word 0 ;empty line == end pf BASIC

.proc MainEntry

	jsr Setup

	lda #COL_BLACK
	sta VIC_BORDERCOLOR
	sta VIC_BG_COLOR0

	lda #COL_GREEN
	jsr SetBackgroundColor
	jsr ClearScreen

	jsr DrawScreenborder

	; Disable BASIC sprite handling by C128 Kernel
	lda #1
	sei
	sta SPRINT
	cli

	;jsr CreateDebugSprite

	; Enable preview sprite
	lda #(SPRITE_BASE+SPRITE_PREVIEW*SPRITE_BUFFER_LEN)/SPRITE_BUFFER_LEN			; Sprite data address
	sta SPRITE_PTR+SPRITE_PREVIEW

	ldx #$00
	stx EditFlags
	stx CurFrame
	stx MaxFrame
	jsr TogglePreviewX
	jsr TogglePreviewY

	; Clear the first frame on startup so we start with
	; a clean editor.
	SetPointer (SPRITE_BASE), MEMCPY_SRC
	SetPointer (SPRITE_USER_START), MEMCPY_TGT
	ldy #SPRITE_BUFFER_LEN
	jsr memcpy255

	; Clear the buffer on frame update
	lda #$01
	sta EditClearPreview

	; Now switch to sprite editor as default
	jsr SpriteEditor

@KeyLoop:
	bit EditorWaitRelease
	bmi @WaitKey
	jsr WaitKeyboardRelease

@WaitKey:
	jsr ScanKeys
	dey					; returned 1 if a key was pressed
	bne @WaitKey

	jsr SaveKeys

	ldy #$06			; Check the first 7 Matrixlines
	ldx #$00

@CheckRUNSTOP:
	; Validate that *only* RUN/STOP was pressed without any other key.
	lda LastKeyLine,x
	cmp #$00
	bne @ExecKey		; Any other key was pressed

	inx
	dey
	bpl @CheckRUNSTOP

	lda LastKeyLine,x
	cmp #$80			; RUN/STOP
	beq @Exit			; Only RUN/STOP was pressed so we can exit.

@ExecKey:
	jsr KeyboardTrampolin
	jmp @KeyLoop

@Exit:
	jsr ClearScreen
	jsr Cleanup

	SetPointer SCREEN_VIC, $e0

	rts
.endproc

.proc Setup

	MAIN_APPLICATION_LEN = (MAIN_APPLICATION_END-MAIN_APPLICATION)

	; Switch to default C128 config
	lda #$00
	sta MMU_CR_IO

	sei

	; Save Zeropage
	ldy #ZP_BASE_LEN
@ZPSafe:
	lda ZP_BASE,y
	sta ZPSafe,y
	dey
	bpl @ZPSafe

	; Safe MMU registers
	ldy #$0a

@MMUSafe:
	lda MMU_CR_IO,y
	sta MMUConfig,y
	dey
	bpl @MMUSafe

	lda VIC_BORDERCOLOR
	sta ScreenCol
	lda VIC_BG_COLOR0
	sta ScreenCol+1

	; We want to have more RAM :)
	; Enable IO and Kernal ROM. Everything else
	; is RAM now. $0000 - $C000 so we can
	; move the main application anywhere in
	; this area.

	lda #EDITOR_RAM_CFG
	sta MMU_CR_IO
	sta MMU_PRE_CRD

	lda #EDITOR_COMMON_RAM_CFG
	sta MMU_RAM_CR

	cli

	; If the program is loaded the first time
	; we need to relocate it, to make room for
	; the VIC sprite buffers. Since this will
	; overwrite the original data, it can not
	; be started again. Since the program is
	; already relocated, we can just skip the
	; memcpy for another run.
	lda RelocationFlag
	bne @SkipRelocation

	SetPointer MAIN_APPLICATION_LEN, MEMCPY_LEN
	SetPointer (MAIN_APPLICATION_LOAD+MAIN_APPLICATION_LEN), MEMCPY_SRC
	SetPointer MAIN_APPLICATION_END, MEMCPY_TGT

	jsr MemCopyReverse
	lda #$01
	sta RelocationFlag

@SkipRelocation:

	lda #SPRITE_BUFFER_LEN
	sta Multiplier

	lda	#$00
	sta Multiplicand
	sta Multiplicand+1
	sta Multiplier+1
	sta Product
	sta Product+1
	sta Product+2
	sta Product+3

	jsr CopyKeytables

	; Reset all sprite expansions
	lda	#$00
	sta SPRITE_EXP_X
	sta SPRITE_EXP_Y

	; Init the default keyboardhandler
	SetPointer (EditorKeyboardHandler), EditorKeyHandler

	rts

.endproc

.proc Cleanup

	sei

	lda #$00
	sta VIC_SPR_ENA		; Disable all sprites

	; Reenable BASIC sprite handling
	lda #0
	sta SPRINT

	lda ScreenCol
	sta VIC_BORDERCOLOR
	lda ScreenCol+1
	sta VIC_BG_COLOR0

	; Restore the zeropage
	ldy #ZP_BASE_LEN
@ZPRestore:
	lda ZPSafe,y
	sta ZP_BASE,y
	dey
	bpl @ZPRestore

	; Restore MMU registers
	ldy #$0a

@MMURestore:
	lda MMUConfig,y
	sta MMU_CR_IO,Y
	dey
	bpl @MMURestore

	sta MMU_CR

	cli

	jsr WaitKeyboardRelease

	; Disable RUN/STOP
	lda #$ff
	sta STKEY

	; Clear keybuffer
	lda #$00
	sta INP_NDX

	rts
.endproc

.proc MemCopyReverse

	ldy #$00

	sec
	lda MEMCPY_SRC
	sbc #$01
	sta MEMCPY_SRC
	lda MEMCPY_SRC+1
	sbc #$00
	sta MEMCPY_SRC+1

	sec
	lda MEMCPY_TGT
	sbc #$01
	sta MEMCPY_TGT
	lda MEMCPY_TGT+1
	sbc #$00
	sta MEMCPY_TGT+1

	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y

	dec MEMCPY_LEN
	bne MemCopyReverse

	dec MEMCPY_LEN+1
	bpl MemCopyReverse

	lda #8
	sta DiskDrive

	rts

.endproc

; FARCALL is used to call a function
; across the bank boundaries.
; A/X/Y are passed to the function
; as provided by the caller.
; The function to be called must be
; stored in the FARCALL_PTR. 
.proc FARCALL

	; We need AC here, so we have to save it
	; in order to be able to pass it on to the
	; FARCALL.
	sta FARCALL_RESTORE

	; Switch to the new memory layout
	lda FARCALL_MEMCFG
	sta MMU_PRE_CRC
	sta MMU_LOAD_CRC

	; Save the address so the memory
	; will be reset
	phr @SysRestore
	lda FARCALL_RESTORE

	jmp (FARCALL_PTR)

@SysRestore:

	sta MMU_LOAD_CRD	; Switch back to our bank

	rts
.endproc

; Copy the kernel key decoding tables to our memory
; so we can easily access it.
.proc CopyKeytables

	SetPointer KeyTables, MEMCPY_TGT

	; Standard keytable without modifiers
	SetPointer $fa80, MEMCPY_SRC

	ldy #KeyTableLen
	jsr memcpy255
	clc
	lda MEMCPY_TGT
	sta KeytableNormal
	adc #KeyTableLen
	sta MEMCPY_TGT
	lda MEMCPY_TGT+1
	sta KeytableNormal+1
	adc #$00
	sta MEMCPY_TGT+1

	; Shifted keys
	SetPointer $fad9, MEMCPY_SRC

	ldy #KeyTableLen
	jsr memcpy255
	clc
	lda MEMCPY_TGT
	sta KeytableShift
	adc #KeyTableLen
	sta MEMCPY_TGT
	lda MEMCPY_TGT+1
	sta KeytableShift+1
	adc #$00
	sta MEMCPY_TGT+1

	; Commodore keys
	SetPointer $fb32, MEMCPY_SRC

	ldy #KeyTableLen
	jsr memcpy255
	clc
	lda MEMCPY_TGT
	sta KeytableCommodore
	adc #KeyTableLen
	sta MEMCPY_TGT
	lda MEMCPY_TGT+1
	sta KeytableCommodore+1
	adc #$00
	sta MEMCPY_TGT+1

	; CTRL keys
	SetPointer $fb8b, MEMCPY_SRC

	ldy #KeyTableLen
	jsr memcpy255
	clc
	lda MEMCPY_TGT
	sta KeytableControl
	adc #KeyTableLen
	sta MEMCPY_TGT
	lda MEMCPY_TGT+1
	sta KeytableControl+1
	adc #$00
	sta MEMCPY_TGT+1

	; ALT keys
	SetPointer $fbe4, MEMCPY_SRC

	ldy #KeyTableLen
	jsr memcpy255
	clc
	lda MEMCPY_TGT
	sta KeytableAlt
	lda MEMCPY_TGT+1
	sta KeytableAlt+1

	rts
.endproc

.proc memcpy255
	dey
@Loop:
	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y
	dey
	cpy #$ff
	bne @Loop

	rts
.endproc

; This data has to be here so we can cleanly exit after
; moving the code.
FARCALL_PTR:		.word 0		; Pointer to function in other bank
FARCALL_MEMCFG:		.byte 0		; Bank config to switch to
FARCALL_RESTORE:	.byte 0		; Bank config we need switch back to

MMUConfig: .res $0b, 0
ZPSafe: .res $10,0
ScreenCol: .byte $00, $00
RelocationFlag: .byte $00

; Address of the entry stub. This is only the initialization
; part which will move the main application up to MAIN_APP_BASE
; so  we can use the space between $2000 and MAIN_APP_BASE
; for our sprite frames.
; If more frames are needed, we could move it further up
; by increasing MAIN_APP_BASE.
MAIN_APPLICATION_LOAD = *

.org MAIN_APP_BASE
MAIN_APPLICATION = *

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
	lda #SPRITE_BUFFER_LEN
	sta EditFrameSize

	lda #(1 << SPRITE_PREVIEW)
	sta VIC_SPR_ENA		; Enable preview sprite

	jsr UpdateFrameEditor

	lda #CHAR_SPLIT_TOP
	sta SCREEN_VIC+24+1

	jsr SpritePreviewBorder

	; Print the frame text
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*1), CONSOLE_PTR
	SetPointer FrameTxt, STRING_PTR
	ldy #26
	jsr PrintStringZ

	lda CONSOLE_PTR
	sta STRING_PTR
	lda CONSOLE_PTR+1
	sta STRING_PTR+1
	lda CurFrame
	ldx MaxFrame
	ldy #26+6
	jsr PrintFrameCounter

	; Print the max frame text
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*21), CONSOLE_PTR
	SetPointer SpriteFramesMaxTxt, STRING_PTR

	ldy #26
	jsr PrintStringZ

	; Cursor position
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS+1), CURSOR_LINE
	SetPointer SPRITE_PREVIEW_BUFFER, PIXEL_LINE

	ldy #0
	sty EditCursorX
	sty EditCursorY
	lda (CURSOR_LINE),y
	ora #$80
	sta (CURSOR_LINE),y

	lda #$00
	jsr SpriteColorMode

	; The keymap for the sprite editing functions
	SetPointer SpriteEditorKeyMap, KeyMapBasePtr

	rts
.endproc

.proc KeyboardTrampolin

	jmp (EditorKeyHandler)

.endproc

.proc EditorKeyboardHandler
	jsr ReadKeyRepeat

	; By default we assume that the
	; keyboard should be released before we
	; read the next key. Some functions, like
	; CURSOR processing, disables this, as we
	; want them to repeat. They have to reset
	; this on their own.
	lda #$00
	sta EditorWaitRelease
.endproc

; We loop through the keymap and check if there is an entry
; which matches the Modifierand KeyCode. If such an entry is
; found, the associated keyhandler is executed.
;
; The SHIFT key is handled in a special way. If KEY_SHIFT
; is set, we ignore KEY_SHIFT_LEFT or KEY_SHIFT_RIGHT
; as this means that any SHIFT key is allowed to be pressed.
; If KEY_SHIFT is not set, then it must also match exactly. 
.proc CheckKeyMap

	lda KeyMapBasePtr
	sta KEYMAP_PTR
	lda KeyMapBasePtr+1
	sta KEYMAP_PTR+1

	; Remove the KEY_SHIFT flag so we can properly compare
	; against the SHIFT_LEFT/RIGHT flags.
	lda KeyModifier
	and #$ff ^ KEY_SHIFT
	sta KeyMapModifier

@CheckKeyLoop:
	ldy #0
	lda (KEYMAP_PTR),y

	tsx
	pha
	and #KEY_SHIFT
	beq @CheckModifier

	; If the modifier has the SHIFT key set
	; We can ignore the LEFT or RIGHT flags.
	lda $0100,x
	and #$ff ^ KEY_SHIFT
	sta $0100,x				; Save the modifiers without the SHIFT flags
	lda KeyMapModifier		; Original modifiers ...
	and #(KEY_SHIFT_LEFT|KEY_SHIFT_RIGHT) ; .. and extract the shift states
	ora $0100,x				; Add the shift keys from the actual key
	sta $0100,x				; push the required shift states.

@CheckModifier:
	pla
	cmp KeyMapModifier
	bne @NextKey

@CheckKey:
	iny
	lda (KEYMAP_PTR),y
	cmp KeyCode
	bne @NextKey

	; We found a valid key combination, so we execute
	; the handler.
	ldy #$02
	lda (KEYMAP_PTR),y
	sta KeyMapFunction
	iny
	lda (KEYMAP_PTR),y
	sta KeyMapFunction+1
	jmp (KeyMapFunction)

@NextKey:
	clc
	lda KEYMAP_PTR
	adc #$04
	sta KEYMAP_PTR
	lda KEYMAP_PTR+1
	adc #$00
	sta KEYMAP_PTR+1

	; If the functionpointer is a nullptr we have reached the end of the map.
	ldy #$02
	lda (KEYMAP_PTR),y
	bne @CheckKeyLoop
	iny
	lda (KEYMAP_PTR),y
	bne @CheckKeyLoop
	rts

.endproc

.proc Flash
	lda #COL_RED
	sta VIC_BORDERCOLOR

	jsr Delay

	lda #COL_BLACK
	sta VIC_BORDERCOLOR
	rts
.endproc

.proc TogglePreviewX
	lda	SPRITE_EXP_X
	eor #(1 << SPRITE_PREVIEW)
	sta SPRITE_EXP_X
	jsr SpritePreviewBorder

	rts
.endproc

.proc TogglePreviewY
	lda	SPRITE_EXP_Y
	eor #(1 << SPRITE_PREVIEW)
	sta SPRITE_EXP_Y
	jsr SpritePreviewBorder

	rts
.endproc

.proc ToggleMulticolor
	lda	VIC_SPR_MCOLOR
	eor #(1 << SPRITE_PREVIEW)
.endproc

.proc SpriteColorMode

	sta VIC_SPR_MCOLOR

	and #(1 << SPRITE_PREVIEW)
	beq @SingleMode

	; Print three colors
	lda #$01
	ldx #3
	jmp @Print

@SingleMode:
	; Clear color 2+3
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*(COLOR_TXT_ROW+1)+COLOR_TXT_COLUMN), CONSOLE_PTR

	lda #' '
	ldx #2

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
	lda #$01
	ldx #1

@Print:
.endproc

.proc PrintSpriteColor

	; Print the color choice
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*(COLOR_TXT_ROW)), CONSOLE_PTR
	SetPointer ColorTxt, STRING_PTR
	stx TMP_VAL_1
	ldx #$01

@ColorSelection:
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
	ble @ColorSelection

	jsr SetSpriteColor1
	jsr SetSpriteColor2
	jsr SetSpriteColor3

	rts
.endproc

.proc IncSpriteColor1
	inc SpriteColorValue
.endproc

.proc SetSpriteColor1
	lda SpriteColorValue
	sta VIC_SPR0_COLOR+SPRITE_PREVIEW
	sta VIC_COLOR_RAM+SCREEN_COLUMNS*COLOR_TXT_ROW+COLOR_TXT_COLUMN+8
	rts
.endproc

.proc IncSpriteColor2
	inc SpriteColorValue+1
.endproc

.proc SetSpriteColor2
	lda SpriteColorValue+1
	sta VIC_SPR_MCOLOR0
	sta VIC_COLOR_RAM+SCREEN_COLUMNS*(COLOR_TXT_ROW+1)+COLOR_TXT_COLUMN+8
	rts
.endproc

.proc IncSpriteColor3
	inc SpriteColorValue+2
.endproc

.proc SetSpriteColor3
	lda SpriteColorValue+2
	sta VIC_SPR_MCOLOR1
	sta VIC_COLOR_RAM+SCREEN_COLUMNS*(COLOR_TXT_ROW+2)+COLOR_TXT_COLUMN+8
	rts
.endproc

.proc MoveCursorHome

	; Clear old cursor
	ldy EditCursorX
	lda (CURSOR_LINE),y
	and #$7f
	sta (CURSOR_LINE),y

	; Reset line pointer ...
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS+1), CURSOR_LINE

	; ... and set cursor.
	ldy #$00
	sty EditCursorX
	sty EditCursorY

	lda (CURSOR_LINE),y
	ora #$80
	sta (CURSOR_LINE),y
	rts
.endproc

.proc MoveCursorRight
	ldy EditCursorX
	tya
	tax
	inx
	cpx EditColumns
	blt MoveCursorHoriz

	; Already last line?
	ldy EditCursorY
	iny
	cpy EditLines
	bge @Done

	ldy EditCursorX
	ldx #$00
	jsr MoveCursorHoriz
	jmp MoveCursorDown

@Done:
	rts
.endproc

.proc MoveCursorLeft

	lda EditCursorX
	beq @ToPrevLine

	tay
	tax
	dex
	jmp MoveCursorHoriz

@ToPrevLine:
	; First line, so we stop
	ldx EditCursorY
	beq @Done

	; Otherwise we move to end of line
	; and one line up
	ldx EditColumns
	dex
	ldy EditCursorX
	jsr MoveCursorHoriz
	jmp MoveCursorUp

@Done:
	rts
.endproc

; Move the cursor left/right
; Y - Old position
; X - New position
.proc MoveCursorHoriz

	lda (CURSOR_LINE),y
	and #$7f
	sta (CURSOR_LINE),y

	txa
	tay

	lda (CURSOR_LINE),y
	ora #$80
	sta (CURSOR_LINE),y

	sty EditCursorX

	; Enable repeat mode
	lda #$80
	sta EditorWaitRelease

	rts
.endproc

.proc MoveCursorDown
	ldy EditCursorY
	iny
	cpy EditLines
	bge @Done

	sty EditCursorY
	ldy EditCursorX
	lda (CURSOR_LINE),y
	and #$7f
	sta (CURSOR_LINE),y

	clc
	lda CURSOR_LINE
	adc #SCREEN_COLUMNS
	sta CURSOR_LINE
	lda CURSOR_LINE+1
	adc #$00
	sta CURSOR_LINE+1

	; Go to next line
	clc
	lda PIXEL_LINE
	adc EditColumnBytes
	sta PIXEL_LINE
	lda PIXEL_LINE+1
	adc #$00
	sta PIXEL_LINE+1

	lda (CURSOR_LINE),y
	ora #$80
	sta (CURSOR_LINE),y

	; Enable repeat mode
	lda #$80
	sta EditorWaitRelease

@Done:
	rts
.endproc

.proc MoveCursorUp

	ldy EditCursorY
	beq @Done

	dey
	sty EditCursorY

	ldy EditCursorX
	lda (CURSOR_LINE),y
	and #$7f
	sta (CURSOR_LINE),y

	sec
	lda CURSOR_LINE
	sbc #SCREEN_COLUMNS
	sta CURSOR_LINE
	lda CURSOR_LINE+1
	sbc #$00
	sta CURSOR_LINE+1

	; Go to previous line
	sec
	lda PIXEL_LINE
	sbc EditColumnBytes
	sta PIXEL_LINE
	lda PIXEL_LINE+1
	sbc #$00
	sta PIXEL_LINE+1

	lda (CURSOR_LINE),y
	ora #$80
	sta (CURSOR_LINE),y

	; Enable repeat mode
	lda #$80
	sta EditorWaitRelease

@Done:
	rts
.endproc

; Draw a border around the preview sprite, so the user
; has a reference frame.
;
; Locals:
; CONSOLE_PTR - Pointer to screen
; DATA_PTR - Pointer to screen
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

; ******************************************
; Character Editor
; ******************************************

.proc CharEditor

	lda #$01
	sta EditColumnBytes
	lda #$08
	sta EditLines
	jsr DrawBitMatrix

	lda #CHAR_SPLIT_TOP
	sta SCREEN_VIC+8+1
	lda #CHAR_ROUND_BOT_RIGHT
	sta SCREEN_VIC+SCREEN_COLUMNS*9+8+1
	lda #CHAR_SPLIT_LEFT
	sta SCREEN_VIC+SCREEN_COLUMNS*9

	rts
.endproc

; ******************************************
; Library
; ******************************************

.proc ClearScreen

	SetPointer SCREEN_VIC, CONSOLE_PTR
	ldy #SCREEN_COLUMNS
	sty RectangleLineOffset

	lda #' '
	ldy #SCREEN_COLUMNS
	ldx #SCREEN_LINES+2
	jmp FillRectangle

.endproc

; =================================================
; Draw the border frame. Color has already been set
; and will not change.
;
; ZP Usage:
; CONSOLE_PTR - pointer to screen
; TMP_VAL_0 - line counter
.proc DrawScreenborder

	; Draw the corners
    lda #CHAR_ROUND_TOP_LEFT
	sta SCREEN_VIC

    lda #CHAR_ROUND_TOP_RIGHT
	sta SCREEN_VIC+39
	lda #CHAR_ROUND_BOT_LEFT
	sta SCREEN_VIC+(SCREEN_COLUMNS*(SCREEN_LINES-1))
	lda #CHAR_ROUND_BOT_RIGHT
	sta SCREEN_VIC+(SCREEN_COLUMNS*SCREEN_LINES)-1

	ldy #38
	lda #CHAR_HORIZONTAL

	; Top and bottom border
@HLoop:
	sta SCREEN_VIC,y
	sta SCREEN_VIC+(SCREEN_COLUMNS*(SCREEN_LINES-1)),y

	dey
	bne	@HLoop

	; Left/right border
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS), CONSOLE_PTR

	; Number of lines - 2 for Border. The last line will be used for character preview
	lda #SCREEN_LINES-2
	sta TMP_VAL_0

	ldx #CHAR_VERTICAL

@VLoop:
	txa
	ldy #0
	sta (CONSOLE_PTR),y
	ldy #39
	sta (CONSOLE_PTR),y

	jsr NextLine

	dec TMP_VAL_0
	bne @VLoop

    rts
.endproc

; Switch to next line with the screen pointer in CONSOLE_PTR
.proc NextLine
	clc
	lda CONSOLE_PTR
	adc #SCREEN_COLUMNS
	sta CONSOLE_PTR

	lda	CONSOLE_PTR+1
	adc #0
	sta CONSOLE_PTR+1

	rts
.endproc

.proc PrevLine

	lda CONSOLE_PTR
	sec
	sbc #SCREEN_COLUMNS
	sta CONSOLE_PTR

	lda CONSOLE_PTR+1
	sbc	#$00
	sta CONSOLE_PTR+1

	rts
.endproc

; =================================================
; Fill the whole color RAM with the character color
; Accumulator contains the color. 
.proc SetBackgroundColor
	ldy #0

@fillLoop:
	sta VIC_COLOR_RAM,y
	sta VIC_COLOR_RAM+256,y
	sta VIC_COLOR_RAM+512,y
	sta VIC_COLOR_RAM+768-24,y

	dey
	bne	@fillLoop

	rts
.endproc

; =================================================
; Draw the editor matrix. This will already also
; draw part of the left border as well. Since this
; function doesn't know where it is called from, the
; caller must adjust the edges if appropriate.
;
; PARAMS:
; EditColumnBytes - number of columnbytes (1 = 8 columns, 2 = 16 columns, etc.)
; EditLines - number of lines
;
; Locals:
; CONSOLE_PTR - pointer to the screen position
; EditCurChar - Current datavalue
; TMP_VAL_0 - Number of editor bytes per line 
; TMP_VAL_0 - Temporary

.proc DrawBitMatrix

	; Editormatrix screen position
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS+1), CONSOLE_PTR
	SetPointer (SPRITE_PREVIEW_BUFFER), DATA_PTR

	lda EditLines
	sta EditCurLine

@nextLine:
	; Reset the columns
	lda EditColumnBytes
	sta EditCurColumns
	ldy #0

@nextColumn:
	sty TMP_VAL_0
	ldy #0
	lda (DATA_PTR),y
	ldy TMP_VAL_0
	sta EditCurChar

	; next byte
	clc
	lda	DATA_PTR
	adc #1
	sta DATA_PTR
	lda DATA_PTR+1
	adc #0
	sta DATA_PTR+1

	ldx #8

@nextBit:
	lda #'.'
	asl EditCurChar
	bcc @IsSet
	lda #'*'

@IsSet:
	sta (CONSOLE_PTR),y
	iny
	dex
	bne @nextBit

	dec EditCurColumns
	bne @nextColumn

	; Drawing part of the border is almost
	; free here.
	lda #CHAR_VERTICAL
	sta (CONSOLE_PTR),y

	jsr NextLine

	dec EditCurLine
	bne @nextLine

	; We are already in the right position
	; so we can just as well draw the bottom
	; line here as well, without the need of
	; doing extra calculations. Only the
	; corners will have to be adjusted by the
	; caller.
	lda #CHAR_SPLIT_BOT
	sta (CONSOLE_PTR),y
	dey	
	lda #CHAR_HORIZONTAL

@bottomLine:
	sta (CONSOLE_PTR),y
	dey
	bpl @bottomLine

	rts
.endproc

; Copy the current frame to the preview sprite buffer
; and update the editing matrix.
.proc UpdateFrameEditor

	; Copy current sprite to preview
	lda EditClearPreview
	cmp #$00
	beq @DoCopy

	; Clear flag
	jsr ClearPreviewSprite
	jsr @UpdateFrame
	lda #$00
	sta EditClearPreview

	ldy EditCursorX
	lda (CURSOR_LINE),y
	ora #$80
	sta (CURSOR_LINE),y
	rts

@DoCopy:
	lda CurFrame
	ldy #SPRITE_PREVIEW_TGT
	jsr CopySpriteFrame

	jsr DrawBitMatrix
	;jsr MoveCursorHome
	ldy EditCursorX
	lda (CURSOR_LINE),y
	ora #$80
	sta (CURSOR_LINE),y

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
	sta Multiplicand+1

	sta Multiplier+1
	lda #SPRITE_BUFFER_LEN
	sta Multiplier
	jsr Mult16x16

	clc
	lda #<(SPRITE_USER_START)
	adc Product
	sta FramePtr
	lda #>(SPRITE_USER_START)
	adc Product+1
	sta FramePtr+1

	rts

.endproc

; If the user pressed the key, we move the cursor
; to the top left corner, otherwise it stays where it is.
.proc ClearPreviewSpriteKey
	jsr ClearPreviewSprite
	SetPointer SPRITE_PREVIEW_BUFFER, PIXEL_LINE
	jmp MoveCursorHome
.endproc

; Clear the preview sprite buffer
.proc ClearPreviewSprite
	jsr SetDirty

	lda #$00
	ldy #SPRITE_BUFFER_LEN-1

@Loop:
	sta SPRITE_PREVIEW_BUFFER,y
	dey
	bpl @Loop

	jmp DrawBitMatrix

.endproc

; Invert the preview sprite buffer
.proc InvertSprite

	jsr SetDirty
	ldy #SPRITE_BUFFER_LEN-1

@Loop:
	lda SPRITE_BASE+SPRITE_PREVIEW*SPRITE_BUFFER_LEN,y
	eor #$ff
	sta SPRITE_BASE+SPRITE_PREVIEW*SPRITE_BUFFER_LEN,y
	dey
	bpl @Loop

	jmp DrawBitMatrix

.endproc

.proc NextFrame
	lda #$80
	sta EditorWaitRelease

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
	lda #$80
	sta EditorWaitRelease

	ldy CurFrame
	bne @Update

	ldy MaxFrame
	iny

@Update:
	dey
	ldx CurFrame
	jmp SwitchFrame
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
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*STATUS_LINE), CONSOLE_PTR
	SetPointer MaxFramesReachedTxt, STRING_PTR
	
	ldy #0
	jsr PrintStringZ

	; Reset the clear flag.
	lda #$00
	sta EditClearPreview
	jmp Flash

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

	lda EditFlags
	and #EDIT_DIRTY
	beq @SkipCopy

	; Copy the current editor frame to the sprite
	ldy #SPRITE_PREVIEW_SRC
	jsr CopySpriteFrame

@SkipCopy:
	jmp UpdateFrameEditor
.endproc

.proc UndoFrame	
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
;     SPRITE_PREVIEW_SRC - Copy sprite from preview to target
;     SPRITE_PREVIEW_TGT - Copy sprite from source to preview
;
; If Y is not 0 the value in A or X is ignored
; depending on Y. If Y is SPRITE_PREVIEW_SRC then
; A is ignored, otherwise X. Only if Y is 0
; will both values be needed.
.proc CopySpriteFrame

	; Remember the source
	sta MEMCPY_SRC
	tya
	and #SPRITE_PREVIEW_TGT
	beq @CalcTarget
	SetPointer SPRITE_PREVIEW_BUFFER, MEMCPY_TGT
	jmp @CheckSrc

@CalcTarget:
	txa
	jsr CalcFramePointer

	lda FramePtr
	sta MEMCPY_TGT
	lda FramePtr+1
	sta MEMCPY_TGT+1

@CheckSrc:
	tya
	and #SPRITE_PREVIEW_SRC
	beq @CalcSrc
	SetPointer SPRITE_PREVIEW_BUFFER, MEMCPY_SRC
	jmp @Copy

@CalcSrc:
	lda MEMCPY_SRC
	jsr CalcFramePointer
	lda FramePtr
	sta MEMCPY_SRC
	lda FramePtr+1
	sta MEMCPY_SRC+1

@Copy:
	ldy #SPRITE_BUFFER_LEN
	jmp memcpy255

.endproc

; Fill a memory rectangle with the specified value
;
; PARAMS:
; X - Number of lines
; Y - Number of columns 1 .. SCREEN_COLUMNS
; A - character to use
; CONSOLE_PTR - Pointer to top left corner.
; RectangleLineOffset - Line offset
;
.proc FillRectangle

	dey
	sty TMP_VAL_0
	sta TMP_VAL_1

@nextLine:
	sta (CONSOLE_PTR),y
	dey
	bpl @nextLine

	; Advance to next Line
	clc
	lda CONSOLE_PTR
	adc RectangleLineOffset
	sta CONSOLE_PTR
	lda CONSOLE_PTR+1
	adc #0
	sta CONSOLE_PTR+1

	ldy TMP_VAL_0
	lda TMP_VAL_1

	dex
	bne @nextLine

	rts
.endproc

.proc SaveKeys
	ldy #C128_KEY_LINES+1

@Loop:
	lda KeyLine,y
	sta LastKeyLine,y
	dey
	bpl @Loop

	rts
.endproc

; Clear a single line on the console
;
; PARAM:
; Y - Offset in the line
; CONSOL_PTR - points to the line
.proc ClearLine

	lda #' '
	ldx #SCREEN_COLUMNS

:
	sta (CONSOLE_PTR),y
	iny
	dex
	bpl :-

	rts
.endproc

.proc ClearStatusLine
	ldy #79
	lda #' '

:	sta SCREEN_VIC+SCREEN_COLUMNS*SCREEN_LINES,y
	dey
	bpl :-

	rts
.endproc

.proc Delay
	lda #$02
	sta TMP_VAL_0

	; Delay loop
:	ldx #$00
:	ldy #$00
:	dey
	bne :-
	dex
	bne :--
	dec TMP_VAL_0
	bne :---

	rts
.endproc

; Print the frame counters N/M
; STRING_PTR - point to start of the first digit.
; A - First frame - 0 ... MAX_FRAMES-1
; X - Last frame - 0 ... MAX_FRAMES-1
; Y - offset in line
;
; Locals:
; TMP_VAL_0
; TMP_VAL_1
.proc PrintFrameCounter

	; For display to the user we want to have the counter
	; from 1...MAX_FRAMES
	inx
	stx TMP_VAL_2		; Save max frames
	sty TMP_VAL_3		; and y position in string

	tax
	inx
	stx BINVal			; First print the CurFrame value
	lda #$00
	sta BINVal+1
	jsr BinToBCD16

	ldx #$00			; We want right alignment
	stx LeftAligned

	inx					; Skip the first digit otherwise it would be 4
	txa					; We only need 3 digits
	ldy TMP_VAL_3
	jsr BCDToString
	sty TMP_VAL_3

	lda TMP_VAL_2		; Max frames
	sta BINVal			; First print the CurFrame value
	jsr BinToBCD16
	lda #$01			; Skip the first digit otherwise it would be 4
	tax					; We only need 3 digits
	ldy TMP_VAL_3
	iny
	jmp BCDToString
.endproc

.if 0
; Create a sprite shape which makes the border edges better visible.
.proc CreateDebugSprite
	DEBUG_SPRITE_PTR = SPRITE_BASE+(SPRITE_PREVIEW*SPRITE_BUFFER_LEN)

	ldy #3*21
	lda #255

@InitSprite:
	sta DEBUG_SPRITE_PTR-1,y
	dey
	bne @InitSprite

	lda #0
	sta DEBUG_SPRITE_PTR+1
	sta DEBUG_SPRITE_PTR+(3*20)+1

	lda #$7f
	sta DEBUG_SPRITE_PTR+(3*7)
	sta DEBUG_SPRITE_PTR+(3*8)
	sta DEBUG_SPRITE_PTR+(3*9)
	sta DEBUG_SPRITE_PTR+(3*10)
	sta DEBUG_SPRITE_PTR+(3*11)
	sta DEBUG_SPRITE_PTR+(3*12)
	sta DEBUG_SPRITE_PTR+(3*13)

	lda #$fe

	sta DEBUG_SPRITE_PTR+(3*7)+2
	sta DEBUG_SPRITE_PTR+(3*8)+2
	sta DEBUG_SPRITE_PTR+(3*9)+2
	sta DEBUG_SPRITE_PTR+(3*10)+2
	sta DEBUG_SPRITE_PTR+(3*11)+2
	sta DEBUG_SPRITE_PTR+(3*12)+2
	sta DEBUG_SPRITE_PTR+(3*13)+2

	rts
.endproc
.endif

.proc ToggleSpritePixel
	jsr SetDirty

	ldy #$00			; Byte index
	lda EditCursorX
	cmp #8
	blt @GetPixelMask
	iny
	sec
	sbc #$08
	cmp #8
	blt @GetPixelMask
	iny
	sec
	sbc #$08

	; Now we have the bitnumber in A
	; 0 - Leftmost
	; 7 - Rightmost
@GetPixelMask:
	tax
	lda #$80
	cpx #$00
	beq @ToggleBit

@FindBitMask:
	clc
	lsr
	dex
	bne @FindBitMask

@ToggleBit:
	; Save the bitmask
	sta TMP_VAL_0
	lda (PIXEL_LINE),y
	eor TMP_VAL_0
	sta (PIXEL_LINE),y

.endproc

.proc ToggleCursorPixel
	ldy EditCursorX
	lda (CURSOR_LINE),y
	eor #$04			; Toggle bewtween highlighted '.' and '*'
	sta (CURSOR_LINE),y

	jmp MoveCursorRight
.endproc

.proc SetDirty
	lda EditFlags
	ora #EDIT_DIRTY
	sta EditFlags
	rts
.endproc

.proc ClearDirty
	lda EditFlags
	and #$ff ^ EDIT_DIRTY
	sta EditFlags
	rts
.endproc

.proc SaveSprites

	; Copy the current edit buffer to the sprite frame buffer
	ldx CurFrame
	ldy #SPRITE_PREVIEW_SRC
	jsr CopySpriteFrame
	jsr ClearDirty

	jsr WaitKeyboardRelease
	jsr GetSpriteSaveInfo
	lbeq @Cancel

	SetPointer OpenFileTxt, STRING_PTR
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*SCREEN_LINES), CONSOLE_PTR
	ldy #0
	jsr ClearLine
	ldy #SCREEN_COLUMNS
	jsr ClearLine
	ldy #$00
	jsr PrintStringZ

	SetPointer Filename, STRING_PTR
	ldy #12
	ldx FilenameLen
	jsr PrintPETSCII

	; Enable kernel for our saving calls
	lda #$00
	sta FARCALL_MEMCFG

	; File set parameters
	lda #2				; Fileno
	ldx DiskDrive		; Device
	ldy #5				; secondary address
	jsr SETFPAR

	lda #0				; RAM bank to load file
	ldx #0				; RAM bank of filename
	jsr SETBANK

	lda #'w'
	jsr OpenFile
	bcc :+
	jmp FileError
:
	; Switch output to our file
	SetPointer CKOUT, FARCALL_PTR
	ldx #2
	jsr FARCALL
	bcc :+
	jmp FileError
:
	ldy #0
	jsr ClearLine

	; print WRITING ...
	SetPointer WritingTxt, STRING_PTR
	ldy #$00
	jsr PrintStringZ

	; ... and append the frame counter 
	SetPointer FrameTxt, STRING_PTR
	jsr PrintStringZ

	lda CONSOLE_PTR
	sta STRING_PTR
	lda CONSOLE_PTR+1
	sta STRING_PTR+1

	; Calculate address of first frame where we want
	; to save from
	lda FileFrameStart
	jsr CalcFramePointer

	lda FramePtr
	sta DATA_PTR
	lda FramePtr+1
	sta DATA_PTR+1

	lda FileFrameStart
	sta FileFrameCur

	; Write a single character to disk
	SetPointer BSOUT, FARCALL_PTR
	ldy #19

	; Write a single sprite buffer
@NextFrame:
	ldx FileFrameCur
	tax
	ldx FileFrameEnd
	ldy #14
	jsr PrintFrameCounter
	ldy #$00		; Current byte of the sprite
	sty FilePosY

@WriteFrame:
	lda (DATA_PTR),y
	inc FilePosY
	jsr FARCALL		; Write byte
	bcc :+

	; Write error
	jmp FileError

:
	ldy FilePosY
	cpy #SPRITE_BUFFER_LEN				; Size of a sprite block
	bne	@WriteFrame

	ldy FileFrameCur
	iny
	sty FileFrameCur
	cpy FileFrameEnd
	bgt @Done

	; Switch to next sprite buffer
	clc
	lda DATA_PTR
	adc #SPRITE_BUFFER_LEN
	sta DATA_PTR
	lda DATA_PTR+1
	adc #$00
	sta DATA_PTR+1
	jmp @NextFrame

@Done:
	ldx FileFrameCur
	tax
	ldx FileFrameEnd
	ldy #14
	jsr PrintFrameCounter

	lda #2
	jsr CloseFile

	SetPointer DoneTxt, STRING_PTR
	ldy #$00
	jsr PrintStringZ
	jsr Delay
	jsr ClearStatusLine

	rts

@Cancel:
	; Print cancel text in status line
	SetPointer CanceledTxt, STRING_PTR
	jmp ShowStatusLine
.endproc

.proc ShowStatusLine
	jsr ClearStatusLine

	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*SCREEN_LINES), CONSOLE_PTR
	ldy #0
	jsr PrintStringZ

	; Show the status line for a small period of time
	jsr Delay

	jsr ClearStatusLine
	rts
.endproc

.proc GetSpriteSaveInfo

	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*SCREEN_LINES), CONSOLE_PTR
	SetPointer SaveTxt, STRING_PTR
	ldy #0
	jsr ClearLine

	ldy #0
	jsr PrintStringZ

	SetPointer FrameTxt, STRING_PTR
	jsr PrintStringZ

	lda CONSOLE_PTR
	sta STRING_PTR
	lda CONSOLE_PTR+1
	sta STRING_PTR+1

	lda CurFrame
	ldx MaxFrame
	ldy #11
	jsr PrintFrameCounter

	SetPointer DriveTxt, STRING_PTR
	ldy #20
	jsr PrintStringZ

	SetPointer EnterNumberStr, STRING_PTR

	lda #3
	sta EnterNumberStrLen

	; Get low frame
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*SCREEN_LINES+11), CONSOLE_PTR
	lda #1
	ldx #1
	ldy MaxFrame
	iny					; User deals with 1..N
	jsr EnterNumber
	cpy #1
	bne @Cancel
	sta FileFrameStart
	dec FileFrameStart	; Back to 0 based

	; Get high frame
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*SCREEN_LINES+15), CONSOLE_PTR
	ldx MaxFrame	; User deals with 1..N
	inx
	txa
	tay
	jsr EnterNumber
	cpy #1
	bne @Cancel
	sta FileFrameEnd
	dec FileFrameEnd	; Back to 0 based

	; Get drive number 
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*SCREEN_LINES+27), CONSOLE_PTR
	lda #$02
	sta EnterNumberStrLen
	lda DiskDrive
	ldx #8
	ldy #11
	jsr EnterNumber
	cpy #1
	bne @Cancel
	sta DiskDrive

	ldy #0
	jsr ClearLine

	; And finally get the filename
	jsr EnterFilename

	ldy #0
	jsr ClearLine

	; Everything went ok
	lda #$01
	rts

@Cancel:
	lda #$00
	rts
.endproc

.proc EnterFilename
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*SCREEN_LINES), CONSOLE_PTR
	SetPointer FilenameTxt, STRING_PTR

	ldy #0
	jsr ClearLine

	ldy #0
	ldx FilenameLen
	jsr PrintString

	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*SCREEN_LINES+FilenameTxtLen), CONSOLE_PTR
	SetPointer Filename, STRING_PTR

@InputLoop:
	ldx FilenameLen
	ldy #16
	jsr Input

	cmp #$00
	beq @Cancel

	cpy #$00
	beq @EmptyFilename
	sty FilenameLen

	lda #$10
	rts

@Cancel:
	lda #$00
	rts

@EmptyFilename:
	lda STRING_PTR
	pha
	lda STRING_PTR+1
	pha

	lda CONSOLE_PTR
	pha
	lda CONSOLE_PTR+1
	pha

	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*STATUS_LINE), CONSOLE_PTR
	SetPointer EmptyFilenameTxt, STRING_PTR
	ldy #0
	jsr PrintStringZ

	jsr Delay
	jsr Delay

	ldy #0
	jsr ClearLine

	pla
	sta CONSOLE_PTR+1
	pla
	lda CONSOLE_PTR

	pla
	sta STRING_PTR+1
	pla
	lda STRING_PTR

	jmp @InputLoop
.endproc

; Input a number value which can be 0...255
;
; PARAMS:
; A - CurValue
; X - MinValue
; Y - MaxValue
; CONSOLE_PTR - position of the input string
; EnterNumberStrLen - Length of input string (1...3)
;
; RETURN:
; A - Lobyte of value
; X - Hibyte of value
; Y - 1 (OK) : 0 (CANCEL)
; If Y != 1 the value in A is undefined and should not be used.
.proc EnterNumber
	sta EnterNumberCurVal
	stx EnterNumberMinVal
	sty EnterNumberMaxVal

	SetPointer NumberInputFilter, InputFilterPtr

@InputLoop:
	SetPointer EnterNumberStr, STRING_PTR
	ldy #4
	lda #' '

@ClearString:
	sta (STRING_PTR),y
	dey
	bpl @ClearString

	lda EnterNumberCurVal
	sta BINVal
	lda #$00
	sta BINVal+1
	jsr BinToBCD16

	lda #$ff			; Enable left alignment for the input
	sta LeftAligned
	lda #$01			; We only need 3 digits, so we have to skip the highbyte
	tax
	ldy #0
	jsr BCDToString

	ldy EnterNumberStrLen
	jsr Input
	cmp #$00			; User pressed cancel button
	beq @Cancel
	cpy #$00			; Empty string was entered
	beq @RangeError

	jsr StringToBin16
	cpx #$00			; Value can not be higher than 255
	bne @RangeError		; So the highbyte must be 0

	cmp EnterNumberMinVal
	blt @RangeError
	cmp EnterNumberMaxVal
	bgt @RangeError

	ldy #1
	jmp @Done

@Cancel:
	ldy #0

@Done:
	pha
	SetPointer DefaultInputFilter, InputFilterPtr
	pla
	rts

@RangeError:
	lda STRING_PTR
	sta EnterNumberStringPtr
	lda STRING_PTR+1
	sta EnterNumberStringPtr+1

	lda CONSOLE_PTR
	sta EnterNumberConsolePtr
	lda CONSOLE_PTR+1
	sta EnterNumberConsolePtr+1

	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*STATUS_LINE), CONSOLE_PTR
	SetPointer EnterNumberMsg, STRING_PTR
	ldy #0
	ldx #EnterNumberMsgLen
	jsr PrintString

	lda CONSOLE_PTR
	sta STRING_PTR
	lda CONSOLE_PTR+1
	sta STRING_PTR+1

	ldx EnterNumberMinVal
	dex
	txa
	ldx EnterNumberMaxVal
	dex
	ldy #24
	jsr PrintFrameCounter

	lda #'/'
	ldy #27
	sta (CONSOLE_PTR),y

	jsr Delay
	jsr Delay

	ldy #0
	jsr ClearLine

	lda EnterNumberConsolePtr
	sta CONSOLE_PTR
	lda EnterNumberConsolePtr+1
	sta CONSOLE_PTR+1

	lda EnterNumberStringPtr
	sta STRING_PTR
	lda EnterNumberStringPtr+1
	sta STRING_PTR+1

	jmp @InputLoop
.endproc

; Open a sequential file for reading or writing.
; Filename must be already present.
;
; PARAM:
; A - 'r' for read or 'w' for write
; Filename - Filename in PETSCII
; FilenameLen - Length of the filename
;
; RETURN:
; STATUS - Errorstatus from OS
;
.proc OpenFile	; Prepare filename by appending 

	pha
	; ',S,W' to open a SEQ file for writing
	ldy FilenameLen
	lda #','
	sta Filename,y
	iny
	lda #'s'
	sta Filename,y
	iny
	lda #','
	sta Filename,y
	iny
	pla
	sta Filename,y

	SetPointer CLRCH, FARCALL_PTR
	jsr FARCALL

	lda FilenameLen
	clc
	adc #4
	ldx #<(Filename)
	ldy #>(Filename)
	jsr SETNAME

	; Open the file
	SetPointer OPEN, FARCALL_PTR
	jsr FARCALL

	rts
.endproc

; Close the file which was previously opened
;
; PARAM:
; A - FileNo
;
.proc CloseFile

	pha
	; Well, it's evident. :)
	SetPointer CLOSE, FARCALL_PTR
	pla
	jsr FARCALL

	; Clear output and reset to STDIN
	; before closing
	SetPointer CLRCH, FARCALL_PTR
	jsr FARCALL
	rts
.endproc

.proc FileError
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*SCREEN_LINES), CONSOLE_PTR

	bit $90
	bpl @UnknownError

	; Device not present error
	SetPointer ErrorDeviceNotPresentTxt, STRING_PTR
	ldy #SCREEN_COLUMNS
	jsr PrintStringZ
	jmp @Done

@UnknownError:
	; Some unspecified error (most likely read or write error)
	SetPointer ErrorFileIOTxt, STRING_PTR
	ldy #SCREEN_COLUMNS
	jsr PrintStringZ

@Done:
	jsr Flash
	jsr Delay

@Close:
	lda #2
	jsr CloseFile

	ldy #0
	jsr ClearLine
	ldy #SCREEN_COLUMNS
	jsr ClearLine
	rts
.endproc

.proc LoadSprites

	lda #0			; Fileno
	ldx DiskDrive	; Device
	ldy #0			; Load with address (1 = loadadress is in file)
	jsr SETFPAR

	lda #'r'
	jsr OpenFile
	lda STATUS

	lda #0			; RAM bank to load file
	ldx #0			; RAM bank of filename
	jsr SETBANK

	lda #0			; LOAD
	ldx #<SPRITE_BASE
	ldy #>SPRITE_BASE
	jsr LOAD

	rts
.endproc

; Library includes
SCANKEYS_BLOCK_IRQ = 1
.include "kbd/keyboard_pressed.s"
.include "kbd/keyboard_released.s"
.include "kbd/input.s"
.include "kbd/number_input_filter.s"

.include "math/bintobcd16.s"
.include "math/mult16x16.s"

.include "string/bcdtostring.s"
.include "string/printstring.s"
.include "string/printpetscii.s"
.include "string/printstringz.s"
.include "string/printhex.s"
.include "string/string_to_bin16.s"

; **********************************************
.segment "DATA"

TMP_VAL_0: .word 0
TMP_VAL_1: .word 0
TMP_VAL_2: .word 0
TMP_VAL_3: .word 0
RectangleLineOffset: .byte 0

; Number of lines/bytes to be printed as bits
EditFlags:		.byte 0
EditColumnBytes: .byte 0
EditColumns:	.byte 0
EditLines:		.byte 0
EditCursorX:	.byte 0
EditCursorY:	.byte 0
EditClearPreview: .byte 0	; Clear the preview when the frame is updated if set to 1
; Size of a framebuffer. 64 for a sprite and 8 for a character
EditFrameSize: .byte 0

; Temp for drawing the edit box
EditCurChar: .byte 0
EditCurColumns: .byte 0
EditCurLine: .byte 0

; Functionpointer to the current keyboardhandler
EditorKeyHandler: .word 0
; Main loop should wait for keyboard release
; before next key is read if bit 7 is set.
EditorWaitRelease: .byte $00

; Keyboard handling
LastKeyLine: .res KEY_LINES, $ff
LastKeyPressed: .byte $ff
LastKeyPressedLine: .byte $00

; Saving/Loading
DiskDrive: .byte 8
FilenameLen: .byte FilenameDefaultLen
Filename: .byte "SPRITEDATA"
FilenameDefaultLen = *-Filename
		.res 21-FilenameDefaultLen,0	; Excess placeholder for the filename

FileFrameStart: .byte 0		; first frame to save
FileFrameEnd: .byte 0		; last frame to save
FileFrameCur: .byte 0		; current frame to save

EnterNumberMsg: .byte "VALUE MUST BE IN RANGE "
EnterNumberMsgLen = *-EnterNumberMsg

EnterNumberStr: .res 7,0
EnterNumberStrLen: .byte 0	; Length of the input string
EnterNumberCurVal: .byte 0
EnterNumberMinVal: .byte 0
EnterNumberMaxVal: .byte 0
EnterNumberStringPtr: .word 0
EnterNumberConsolePtr: .word 0

; Temp for storing the current index in the spritebuffer
; while loading/saving.
FilePosY: .byte 0

; Characters to be used for the sprite preview border
; on the bottom line. This depends on the size, because
; we need to use different chars for the expanded vs.
; unexpanded Y size on the bottom line.
LeftBottomRight: .res $03, $00

FramePtr: .word 0	; Address for current frame pointer
FrameTxt: .byte "FRAME:  1/  1",0
SpriteFramesMaxTxt: .byte "# FRAMES:",.sprintf("%3u",MAX_FRAMES),0
CurFrame: .byte $00		; Number of active frame 0...MAX_FRAMES-1
MaxFrame: .byte $00		; Maximum frame number in use 0..MAX_FRAMES-1
ColorTxt: .byte "COLOR:",0
ColorTxtLen = *-ColorTxt-1
SpriteColorValue: .byte COL_LIGHT_GREY, COL_GREEN, COL_BLUE

CanceledTxt:	.byte "           OPERATION CANCELED           ",0
FilenameTxt:	.byte "FILENAME: ",0
FilenameTxtLen	= (*-FilenameTxt)-1
SaveTxt:		.byte "SAVE ",0
OpenFileTxt:	.byte "OPEN FILE: ",0
WritingTxt:		.byte "WRITING ",0
LoadingTxt:		.byte "READING ",0
DoneTxt:		.byte "DONE                                    ",0
EmptyFilenameTxt: .byte "FILENAME CAN NOT BE EMPTY!",0
DriveTxt:		.byte "DRIVE: ",0
MaxFramesReachedTxt: .byte "MAX. # OF FRAMES REACHED!",0

ErrorDeviceNotPresentTxt: .byte "DEVICE NOT PRESENT",0
ErrorFileIOTxt: .byte "FILE I/O ERROR",0

CharPreviewTxt: .byte "CHARACTER PREVIEW",0

; This map contains the modifier, keycode and the function to trigger
KeyMapBasePtr: .word 0
KeyMapFunction: .word 0
KeyMapModifier: .byte 0	; Copy of KeyModifier to handle SHIFT flags

.macro  DefineKey	Modifier, Code, Function
	.byte Modifier, Code
	.word Function
.endmacro

; NOTE: When defining a key assignment using SHIFT keys we can
; only use either KEY_SHIFT or KEY_SHIFT_LEFT/KEY_SHIFT_RIGHT.
; If KEY_SHIFT is set then LEFT/RIGHT is ignored for the comparison.
;
; If LEFT/RIGHT is desired it must be defined without the KEY_SHIFT
; flag to work. LEFT/RIGHT may be used together, but this means the
; user would really have to press both shift keys to trigger.
;
; Example:
;	Space key + any shift key will trigger
;	DefineKey KEY_SHIFT, $20, Function
;
;	Space key + RIGHT SHIFT only will trigger
;	DefineKey KEY_SHIFT_RIGHT, $20, Function
SpriteEditorKeyMap:
	DefineKey 0, $20, ToggleSpritePixel				; SPACE
	DefineKey 0, $1d, MoveCursorRight				; CRSR-Right
	DefineKey 0, $11, MoveCursorDown				; CRSR-Down
	DefineKey 0, $2c, PreviousFrame					; ,
	DefineKey 0, $2e, NextFrame						; .
	DefineKey 0, $14, ClearPreviewSpriteKey			; DEL
	DefineKey 0, $13, MoveCursorHome				; HOME
	DefineKey 0, $49, InvertSprite					; I
	DefineKey 0, $4e, AppendFrameKey				; N
	DefineKey 0, $4c, LoadSprites					; L
	DefineKey 0, $53, SaveSprites					; S
	DefineKey 0, $4d, ToggleMulticolor				; M
	DefineKey 0, $58, TogglePreviewX				; X
	DefineKey 0, $59, TogglePreviewY				; Y
	DefineKey 0, '1', IncSpriteColor1				; 1
	DefineKey 0, '2', IncSpriteColor2				; 2
	DefineKey 0, '3', IncSpriteColor3				; 3
	DefineKey 0, $55, UndoFrame						; U

	; SHIFT keys
	DefineKey KEY_SHIFT, $9d, MoveCursorLeft		; CRSR-Left
	DefineKey KEY_SHIFT, $91, MoveCursorUp			; CRSR-Up
	DefineKey KEY_SHIFT, $ce, AppendFrameCopy		; SHIFT-N

	; Extended keys
	DefineKey KEY_EXT, $1d, MoveCursorRight			; CRSR-Right/Keypad
	DefineKey KEY_EXT, $9d, MoveCursorLeft			; CRSR-Left/Keypad
	DefineKey KEY_EXT, $11, MoveCursorDown			; CRSR-Down/Keypad
	DefineKey KEY_EXT, $91, MoveCursorUp			; CRSR-Up/Keypad

	DefineKey KEY_EXT|KEY_SHIFT, $1d, NextFrame		; CRSR-Right/Keypad
	DefineKey KEY_EXT|KEY_SHIFT, $9d, PreviousFrame	; CRSR-Left/Keypad

	; End of map
	DefineKey 0,0,0

KeyTableLen = KEY_LINES*8
KeyTables = *
SymKeytableNormal		= KeyTables
SymKeytableShift		= KeyTables + KeyTableLen
SymKeytableCommodore 	= KeyTables + (KeyTableLen*2)
SymKeytableControl		= KeyTables + (KeyTableLen*3)
SymKeytableAlt 			= KeyTables + (KeyTableLen*4)

MAIN_APPLICATION_END = *
END:
