; Sprite and character editor for C128 with CA65 assembler
; Written by Gerhard W. Gruber in 11.09.2021
;
.macpack cbm

.include "screenmap.inc"

.include "c128_system.inc"
.include "c128_system.inc"
.include "tools/misc.inc"
.include "tools/intrinsics.inc"

; Debug defines
;SHOW_DEBUG_SPRITE  = 1
KEYBOARD_DEBUG_PRINT = 1

; Zeropage variables
CONSOLE_PTR			= SCREEN_PTR	; $e0

ZP_BASE				= $40
ZP_BASE_LEN			= $0f
FILENAME_PTR		= ZP_BASE+0
DATA_PTR			= ZP_BASE+0	
STRING_PTR			= ZP_BASE+2
KEYMAP_PTR			= ZP_BASE+4
MEMCPY_SRC			= ZP_BASE+6
MEMCPY_TGT			= ZP_BASE+8
MEMCPY_LEN			= ZP_BASE+10
MEMCPY_LEN_LO		= ZP_BASE+10
MEMCPY_LEN_HI		= ZP_BASE+11
CURSOR_LINE			= ZP_BASE+12
PIXEL_LINE			= ZP_BASE+14

KEYTABLE_PTR		= $fb

; Library variables
.define KEY_LINES	C128_KEY_LINES

; Position of the color text.
COLOR_TXT_ROW		= 12
COLOR_TXT_COLUMN	= 27

; Position of the character that shows the selected color 

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
SPRITE_END			= $5000
MAIN_APP_BASE		= SPRITE_END; Address where the main code is relocated to
MAX_FRAMES			= ((MAIN_APP_BASE - SPRITE_USER_START)/SPRITE_BUFFER_LEN) ; The first frame
								; is used for our cursor sprite, so the first
								; user sprite will start at SPRITE_BASE+SPRITE_BUFFER_LEN
CURSOR_HOME_POS		= SCREEN_VIC+SCREEN_COLUMNS+1
BASIC_MAX_LINE_LEN	= 255

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

NO_REPEAT_KEY	= $00		; Editor wont repeat this key default
REPEAT_KEY		= $80		; Editor can repeat this key (i.e. cursor keys)

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

	ldy #FilenameDefaultTxtLen
	sty FilenameLen
	dey

@CopyDefaultFilename:
	lda FilenameDefaultTxt,y
	sta Filename,y
	dey
	bpl @CopyDefaultFilename

	; Clear the buffer on frame update
	lda #$01
	sta EditClearPreview

	; Now switch to sprite editor as default
	jsr SpriteEditor

.ifdef SHOW_DEBUG_SPRITE
	jsr CreateDebugSprite
.else
	jsr CreateWelcomeSprite
.endif

	lda #$ff
	sta WelcomeDone

	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*(SCREEN_LINES+1)), CONSOLE_PTR
	SetPointer VersionTxt, STRING_PTR
	ldy #2
	jsr PrintStringZ

	; Wait untile the first key is pressed and
	; clear the welcome and statusline
	jsr WaitKeyboardRelease
	jsr WaitKeyboardPressed

	bit WelcomeDone
	bpl :+
	jsr ClearWelcome

	; First key should be processed
	lda #$ff
	sta KeyMapWaitRelease
:
@KeyLoop:
	bit KeyMapWaitRelease
	bmi @SaveKeys

@WaitRelease:
	; We want to wait until a key is released
	; but we dont care if modifiers are still pressed
	; like i.e. SHIFT. Otherwise handling certain keys
	; is inconvenient like i.e. SHIFT-DEL (INS), because
	; it would require the user to release also the shift
	; key between multiple inserts.
	jsr WaitKeyboardReleaseIgnoreMod

@SaveKeys:
	jsr SaveKeys

	lda MainExitFlag
	bne @Exit

@ExecKey:
	jsr CallKeyboard
	jmp @KeyLoop

@Exit:
	jsr ClearScreen
	jsr Cleanup

	SetPointer SCREEN_VIC, $e0

	rts
.endproc

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

.else ; SHOW_DEBUG_SPRITE

.proc CreateWelcomeSprite
	ldy #SPRITE_BUFFER_LEN-1

@Loop:
	lda WelcomeSpriteData,y
	sta SPRITE_USER_START,y
	dey
	bpl @Loop

	lda #0					; A - Source frame
	ldy	#SPRITE_PREVIEW_TGT	;     SPRITE_PREVIEW_TGT - Copy sprite from source to preview
	jsr CopySpriteFrame
	jsr DrawBitMatrix
	jsr ToggleMulticolor
	jsr TogglePreviewX

	lda WelcomeColor
	sta SpriteColorValue
	jsr SetSpriteColor1
	lda WelcomeColor+1
	sta SpriteColorValue+1
	jsr SetSpriteColor2
	lda WelcomeColor+2
	sta SpriteColorValue+2
	jsr SetSpriteColor3

	rts
.endproc

.endif ; SHOW_DEBUG_SPRITE

.proc Setup

	MAIN_APPLICATION_LEN = (MAIN_APPLICATION_END-MAIN_APPLICATION)

	; Switch to default C128 config
	lda #$00
	sta MainExitFlag
	sta MMU_CR_IO
	sta EditCursorX
	sta EditCursorY

	sei

	; Save lock state and disable it
	lda LOCKS
	sta LockFlag
	lda #$ff
	sta LOCKS

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
	; be started again. Because the program was
	; already relocated, we can just skip the
	; memcpy for another run.
	lda RelocationFlag
	bne @SkipRelocation

	SetPointer MAIN_APPLICATION_LEN, MEMCPY_LEN
	SetPointer (MAIN_APPLICATION_LOAD+MAIN_APPLICATION_LEN), MEMCPY_SRC
	SetPointer (MAIN_APPLICATION+MAIN_APPLICATION_LEN), MEMCPY_TGT

	jsr MemCopyReverse
	lda #$01
	sta RelocationFlag

@SkipRelocation:

	BSS_LEN = BSS_END - BSS_START
	SetPointer BSS_LEN, MEMCPY_LEN
	SetPointer BSS_START, MEMCPY_TGT
	lda #$00
	jsr memset

	lda #SPRITE_BUFFER_LEN
	sta Multiplier

	jsr CopyKeytables

	; Reset all sprite expansions
	lda	#$00
	sta SPRITE_EXP_X
	sta SPRITE_EXP_Y

	; Init the default keyboardhandler
	SetPointer (EditorKeyboardHandler), EditorKeyHandler

	lda #8
	sta DeviceNumber

	jsr InstallIRQ

	rts

.endproc

.proc Cleanup
	jsr RestoreIRQ

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

	lda LockFlag
	sta LOCKS

	cli

	jsr WaitKeyboardRelease

	; Disable RUN/STOP
	lda #$ff
	sta STKEY

	; Clear keybuffer
	lda #$00
	sta INP_NDX

	; Restore MMU registers
	ldy #$0a

@MMURestore:
	lda MMUConfig,y
	sta MMU_CR_IO,Y
	dey
	bpl @MMURestore

	sta MMU_CR

	rts
.endproc

.proc IRQHandler
	; Switch to our editor config with hi kernel enabled
	sta MMU_LOAD_CRD

	cld

	inc $0400

@SkipBCD:
	pla
	sta MMU_LOAD_CR
	pla
	tay
	pla
	tax
	pla
	rti
.endproc

.proc InstallIRQ
	lda $0314
	sta IRQVector
	lda $0315
	sta IRQVector HI

	; TODO: IRQ handler not working properly
	rts

	sei

	SetPointer IRQHandler, $0314

	cli
	rts
.endproc

.proc RestoreIRQ
	sei
	lda IRQVector
	sta $0314
	lda IRQVector HI
	sta $0315
	cli
	rts
.endproc

.proc SetMainExit
	lda #$01
	sta MainExitFlag
	rts
.endproc

.include "mem/memcpy.s"
.include "mem/memset.s"

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
	pha

	; Switch to the new memory layout
	lda FARCALL_MEMCFG
	sta MMU_PRE_CRC
	sta MMU_LOAD_CRC
	pla

	jsr FarCaller

@SysRestore:

	sta MMU_LOAD_CRD	; Switch back to our bank

	rts
.endproc

.proc FarCaller
	jmp (FARCALL_PTR)
.endproc

; Copy the kernel key decoding tables to our memory
; so we can easily access it.
.proc CopyKeytables

	; Standard keytable without modifiers
	SetPointer $fa80, MEMCPY_SRC
	SetPointer SymKeytableNormal, MEMCPY_TGT

	ldy #KeyTableLen
	jsr memcpy255
	lda MEMCPY_TGT
	sta KeytableNormal
	lda MEMCPY_TGT HI
	sta KeytableNormal HI

	; Shifted keys
	SetPointer $fad9, MEMCPY_SRC
	SetPointer SymKeytableShift, MEMCPY_TGT

	ldy #KeyTableLen
	jsr memcpy255
	lda MEMCPY_TGT
	sta KeytableShift
	lda MEMCPY_TGT HI
	sta KeytableShift HI

	; Commodore keys
	SetPointer $fb32, MEMCPY_SRC
	SetPointer SymKeytableCommodore, MEMCPY_TGT

	ldy #KeyTableLen
	jsr memcpy255
	lda MEMCPY_TGT
	sta KeytableCommodore
	lda MEMCPY_TGT HI
	sta KeytableCommodore HI

	; CTRL keys
	SetPointer $fb8b, MEMCPY_SRC
	SetPointer SymKeytableControl, MEMCPY_TGT

	ldy #KeyTableLen
	jsr memcpy255
	lda MEMCPY_TGT
	sta KeytableControl
	lda MEMCPY_TGT HI
	sta KeytableControl HI

	; Unused keycode in the kernel
	; but we want it, so we patch it 
	lda #$a0
	ldy #$00				; DEL
	sta SymKeytableControl,y

	; ALT keys
	SetPointer $fbe4, MEMCPY_SRC
	SetPointer SymKeytableAlt, MEMCPY_TGT

	ldy #KeyTableLen
	jsr memcpy255
	lda MEMCPY_TGT
	sta KeytableAlt
	lda MEMCPY_TGT HI
	sta KeytableAlt HI

	rts
.endproc

.proc memcpy255
	dey

@Loop:
	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y

	dey
	bne @Loop
	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y

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
MainExitFlag: .byte 0
LockFlag: .byte 0

IRQVector: .word 0

; Address of the entry stub. This is only the initialization
; part which will move the main application up to MAIN_APP_BASE
; so  we can use the space between $2000 and MAIN_APP_BASE
; for our sprite frames.
; If more frames are needed, we could move it further up
; by increasing MAIN_APP_BASE.
MAIN_APPLICATION_LOAD = *

.org MAIN_APP_BASE
MAIN_APPLICATION = *

.proc ClearWelcome
	lda #$00
	sta WelcomeDone

	lda SpriteColorDefaults
	sta SpriteColorValue
	jsr SetSpriteColor1
	lda SpriteColorDefaults+1
	sta SpriteColorValue+1
	jsr SetSpriteColor2
	lda SpriteColorDefaults+2
	sta SpriteColorValue+2
	jsr SetSpriteColor3

	lda	VIC_SPR_MCOLOR
	and #$ff ^ (1 << SPRITE_PREVIEW)
	jsr SpriteColorMode

	lda	SPRITE_EXP_Y
	ora #(1 << SPRITE_PREVIEW)
	jsr SetPreviewX

	jsr ClearGridHome
	jmp ClearStatusLines
.endproc

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

	; Cursor position
	SetPointer CURSOR_HOME_POS, CURSOR_LINE
	SetPointer SPRITE_PREVIEW_BUFFER, PIXEL_LINE

	ldy #0
	sty EditCursorX
	sty EditCursorY
	jsr ShowCursor

	lda #$00
	jsr SpriteColorMode

	; The keymap for the sprite editing functions
	SetPointer SpriteEditorKeyMap, KeyMapBasePtr

	rts
.endproc

.proc CallKeyboard
	jmp (EditorKeyHandler)
.endproc

.proc EditorKeyboardHandler
	jsr ReadKeyRepeat
	jmp CheckKeyMap
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

.proc HideCursor
	ldy EditCursorX
	lda (CURSOR_LINE),y
	and #$7f
	sta (CURSOR_LINE),y
	rts
.endproc

.proc ShowCursor
	ldy EditCursorX
	lda (CURSOR_LINE),y
	ora #$80
	sta (CURSOR_LINE),y
	rts
.endproc

.proc MoveCursorHome

	jsr HideCursor

	; Reset line pointer ...
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS+1), CURSOR_LINE

	; ... and set cursor.
	ldy #$00
	sty EditCursorX
	sty EditCursorY

	jmp ShowCursor
.endproc

.proc MoveCursorNextLine
	jsr HideCursor
	ldy #$00
	sty EditCursorX
	jmp MoveCursorDown
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

	jsr HideCursor

	txa
	tay

	sty EditCursorX
	jmp ShowCursor
.endproc

.proc MoveCursorDown
	ldy EditCursorY
	iny
	cpy EditLines
	bge @Done

	sty EditCursorY
	jsr HideCursor

	jsr NextCursorLine

	; Go to next line
	clc
	lda PIXEL_LINE
	adc EditColumnBytes
	sta PIXEL_LINE
	lda PIXEL_LINE HI
	adc #$00
	sta PIXEL_LINE HI

	jmp ShowCursor

@Done:
	rts
.endproc

.proc MoveCursorUp

	ldy EditCursorY
	beq @Done

	dey
	sty EditCursorY
	jsr HideCursor

	jsr PrevCursorLine

	; Go to previous line
	sec
	lda PIXEL_LINE
	sbc EditColumnBytes
	sta PIXEL_LINE
	lda PIXEL_LINE HI
	sbc #$00
	sta PIXEL_LINE HI

	jmp ShowCursor

@Done:
	rts
.endproc

.proc ShiftGridUp
	jsr SetDirty

	SetPointer SPRITE_PREVIEW_BUFFER, MEMCPY_TGT

	; When moving up, we copy from the next line to the previous
	clc
	lda #<SPRITE_PREVIEW_BUFFER
	adc EditColumnBytes
	sta MEMCPY_SRC
	lda #>SPRITE_PREVIEW_BUFFER
	adc #$00
	sta MEMCPY_SRC HI

	ldy EditColumnBytes
	dey

	; Save the previous line
@SaveTopLine:
	lda (MEMCPY_TGT),y
	sta TMP_VAL_0,y
	dey
	bpl @SaveTopLine

	ldy #$00

@CopyLoop:
	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y
	iny
	cpy EditBufferLen
	bne @CopyLoop

	; Also copy the last byte
	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y

	ldx EditColumnBytes
	dex
	dey

	; Restore the previous line
@RestoreBottomLine:
	lda TMP_VAL_0,x
	sta (MEMCPY_TGT),y
	dey
	dex
	bpl @RestoreBottomLine

	jsr DrawBitMatrix
	jmp ShowCursor
.endproc

.proc ShiftGridDown
	jsr SetDirty

	SetPointer SPRITE_PREVIEW_BUFFER, MEMCPY_SRC

	; When moving down, we copy from the prev line to the next
	clc
	lda #<SPRITE_PREVIEW_BUFFER
	adc EditColumnBytes
	sta MEMCPY_TGT
	lda #>SPRITE_PREVIEW_BUFFER
	adc #$00
	sta MEMCPY_TGT HI

	ldy EditBufferLen
	ldx EditColumnBytes
	dex
	dey

	; Restore the previous line
@SaveBottomLine:
	lda (MEMCPY_SRC),y
	sta TMP_VAL_0,x
	dey
	dex
	bpl @SaveBottomLine

	ldy EditBufferLen
	dey

@CopyLoop:
	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y
	dey
	bpl @CopyLoop

	ldy EditColumnBytes
	dey

@RestoreTopLine:
	lda TMP_VAL_0,y
	sta (MEMCPY_SRC),y
	dey
	bpl @RestoreTopLine

	jsr DrawBitMatrix
	jmp ShowCursor
.endproc

.proc ShiftGridLeft
	jsr SetDirty
	SetPointer CURSOR_HOME_POS, CONSOLE_PTR
	jsr HideCursor

	ldx EditLines
	dex

@NextLine:
	ldy #$00
	lda (CONSOLE_PTR),y			; First byte of grid line needs to be saved
	sta TMP_VAL_0

@LineLoop:
	iny
	lda (CONSOLE_PTR),y
	dey
	sta (CONSOLE_PTR),y
	iny
	cpy EditColumns
	bne @LineLoop

	; Restore the saved first byte to the right side
	dey
	lda TMP_VAL_0
	sta (CONSOLE_PTR),y

	jsr NextLine
	dex
	bpl @NextLine

	jsr GridToMem
	jsr DrawBitMatrix
	jmp ShowCursor
.endproc

.proc ShiftGridRight
	jsr SetDirty

	SetPointer CURSOR_HOME_POS, CONSOLE_PTR
	jsr HideCursor

	ldx EditLines
	dex

@NextLine:
	ldy EditColumns
	dey
	lda (CONSOLE_PTR),y			; Last byte of grid line needs to be saved
	sta TMP_VAL_0

@LineLoop:
	dey
	lda (CONSOLE_PTR),y
	iny
	sta (CONSOLE_PTR),y
	dey
	bpl @LineLoop

	iny
	lda TMP_VAL_0
	sta (CONSOLE_PTR),y

	jsr NextLine

	dex
	bpl @NextLine

	jsr GridToMem
	jsr DrawBitMatrix
	jmp ShowCursor
.endproc

.proc FlipHorizontal
	jsr HideCursor
	jsr SetDirty

	SetPointer CURSOR_HOME_POS, CONSOLE_PTR

	; Calculate the bottom line
	ldy EditLines
	dey
	lda #>MEMCPY_TGT
	ldx #<MEMCPY_TGT
	jsr SetCursorLine

	ldx EditLines			; Backward linecount
	dex
	lda #$00
	sta TMP_VAL_0			; Forward linecount 

@NextLine:
	ldy EditColumns
	dey

@CopyGridLine:
	lda (CONSOLE_PTR),y
	pha
	lda (MEMCPY_TGT),y
	sta (CONSOLE_PTR),y
	pla
	sta (MEMCPY_TGT),y
	dey
	bpl @CopyGridLine

	inc TMP_VAL_0
	dex
	cpx TMP_VAL_0
	beq @Done
	bcc @Done

	jsr NextLine

	sec
	lda MEMCPY_TGT
	sbc #SCREEN_COLUMNS
	sta MEMCPY_TGT
	lda MEMCPY_TGT HI
	sbc	#$00
	sta MEMCPY_TGT HI
	jmp @NextLine

@Done:
	jsr GridToMem
	jmp ShowCursor
.endproc

.proc FlipVertical
	jsr HideCursor
	jsr SetDirty

	SetPointer CURSOR_HOME_POS, CONSOLE_PTR

	ldx EditLines
	stx TMP_VAL_1		; Linecount
	bne @EnterLoop

@LineLoop:
	ldy TMP_VAL_0		; Left index
	lda (CONSOLE_PTR),y	; Load left value

	tax					; Remember left value
	ldy TMP_VAL_0 HI	; Right index
	lda (CONSOLE_PTR),y	; Load right value

	pha					; Swap with left value
	txa
	sta (CONSOLE_PTR),y	; Write left value to right side
	ldy TMP_VAL_0
	pla
	sta (CONSOLE_PTR),y	; Write right value to left side

	inc TMP_VAL_0
	dec TMP_VAL_0 HI

	iny
	cpy TMP_VAL_0 HI
	beq @LineLoop
	bcc @LineLoop
	jsr NextLine

@EnterLoop:
	dec TMP_VAL_1		; Linecount
	bmi @Done

	ldy #$00
	sty TMP_VAL_0		; Front
	ldy EditColumns		; Back
	dey
	sty TMP_VAL_0 HI
	jmp @LineLoop

@Done:
	jsr GridToMem
	jmp ShowCursor
.endproc

.proc DeleteColumn
	ldy EditCursorX
	beq @Done

	dey
	sty EditCursorX

	jsr HideCursor
	jsr SetDirty

	jsr DeleteColumnPixel

	SetPointer CURSOR_HOME_POS, CONSOLE_PTR

	jsr GridToMem
	jmp ShowCursor

@Done:
	rts
.endproc

.proc DeleteColumns
	ldy EditCursorX
	beq @Done

	dey
	sty EditCursorX

	jsr HideCursor
	jsr SetDirty

	lda CURSOR_LINE
	pha
	lda CURSOR_LINE HI
	pha

	SetPointer CURSOR_HOME_POS, CURSOR_LINE

	ldx EditLines
	dex

@LineLoop:
	jsr DeleteColumnPixel
	jsr NextCursorLine

	dex
	bpl @LineLoop

	pla
	sta CURSOR_LINE HI
	pla
	sta CURSOR_LINE

	SetPointer CURSOR_HOME_POS, CONSOLE_PTR

	jsr GridToMem
	jmp ShowCursor

@Done:
	rts
.endproc

; Delete a column from a single line and move
; the remainder of the line to the left
.proc DeleteColumnPixel
	ldy EditColumns
	dey
	sty TMP_VAL_0

	ldy EditCursorX
	dey
	jmp @EnterLoop

@CopyLoop:
	iny
	lda (CURSOR_LINE),y
	dey
	sta (CURSOR_LINE),y

@EnterLoop:
	iny
	cpy TMP_VAL_0
	bne @CopyLoop

	rts
.endproc

.proc InsertColumn
	; Cursor at last column?
	ldy EditColumns
	dey
	cpy EditCursorX
	bne :+
	rts
:
	jsr HideCursor
	jsr SetDirty

	SetPointer CURSOR_HOME_POS, CONSOLE_PTR

	jsr InsertColumnPixel

	jsr GridToMem
	jmp ShowCursor
.endproc

.proc InsertColumns
	; Cursor at last column?
	ldy EditColumns
	dey
	cpy EditCursorX
	bne :+
	rts
:
	jsr HideCursor
	jsr SetDirty

	lda CURSOR_LINE
	pha
	lda CURSOR_LINE HI
	pha

	SetPointer CURSOR_HOME_POS, CURSOR_LINE

	ldy EditColumns
	dey

	ldx EditLines
	dex

@LineLoop:
	jsr InsertColumnPixel
	jsr NextCursorLine

	dex
	bpl @LineLoop

	pla
	sta CURSOR_LINE HI
	pla
	sta CURSOR_LINE

	SetPointer CURSOR_HOME_POS, CONSOLE_PTR

	jsr GridToMem
	jmp ShowCursor
.endproc

; Insert an empty column at the current line
; and move the remainder of the line to the left
.proc InsertColumnPixel
	ldy EditColumns
	dey

@CopyLoop:
	dey
	lda (CURSOR_LINE),y
	iny
	sta (CURSOR_LINE),y
	dey
	cpy EditCursorX
	bne @CopyLoop

	lda #'.'
	sta (CURSOR_LINE),y

	rts
.endproc

.proc InsertLine
	jsr HideCursor
	jsr SetDirty

	; Bottom line
	ldy EditLines
	dey
	lda #>MEMCPY_SRC
	ldx #<MEMCPY_SRC
	jsr SetCursorLine

	ldx EditLines
	dex
	jmp @EnterLoop

@NextLine:
	ldy EditColumns
	dey

@CopyLine:
	; Copy the line to the next one
	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y
	dey
	bpl @CopyLine

	dex
	cpx EditCursorY
	beq @ClearCursorLine

	; Previous line as we need to copy backward
	SubWord SCREEN_COLUMNS, MEMCPY_SRC

@EnterLoop:
	AddWordTgt SCREEN_COLUMNS, MEMCPY_SRC, MEMCPY_TGT
	jmp @NextLine

@ClearCursorLine:
	lda #'.'
	ldy EditColumns
	dey

@ClearLine:
	sta (CURSOR_LINE),y
	dey
	bpl @ClearLine

	jsr GridToMem
	jmp ShowCursor
.endproc

.proc DeleteLine
	jsr HideCursor
	jsr SetDirty

	; We copy into the current cursor line
	lda CURSOR_LINE
	sta MEMCPY_TGT
	lda CURSOR_LINE HI
	sta MEMCPY_TGT HI

	ldx EditCursorY
	jmp @EnterLoop

@NextLine:
	ldy EditColumns
	dey

@CopyLine:
	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y
	dey
	bpl @CopyLine

	inx
	cpx EditLines
	beq @ClearLastLine

	lda MEMCPY_SRC
	sta MEMCPY_TGT
	lda MEMCPY_SRC HI
	sta MEMCPY_TGT HI

@EnterLoop:
	AddWordTgt SCREEN_COLUMNS, MEMCPY_TGT, MEMCPY_SRC
	jmp @NextLine

@ClearLastLine:
	lda #'.'
	ldy EditColumns
	dey

@ClearLine:
	sta (MEMCPY_TGT),y
	dey
	bpl @ClearLine

	jsr GridToMem
	jmp ShowCursor
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

	lda	CONSOLE_PTR HI
	adc #0
	sta CONSOLE_PTR HI

	rts
.endproc

.proc PrevLine
	sec
	lda CONSOLE_PTR
	sbc #SCREEN_COLUMNS
	sta CONSOLE_PTR

	lda CONSOLE_PTR HI
	sbc	#$00
	sta CONSOLE_PTR HI

	rts
.endproc

.proc NextCursorLine
	clc
	lda CURSOR_LINE
	adc #SCREEN_COLUMNS
	sta CURSOR_LINE

	lda	CURSOR_LINE HI
	adc #0
	sta CURSOR_LINE HI

	rts
.endproc

.proc PrevCursorLine
	sec
	lda CURSOR_LINE
	sbc #SCREEN_COLUMNS
	sta CURSOR_LINE

	lda CURSOR_LINE HI
	sbc	#$00
	sta CURSOR_LINE HI

	rts
.endproc

; Calculate the cursor line 
;
; PARAMS:
;	A - PTR HI		Where the result is stored
;   X - PTR LO
; 	Y - Cursor line 1..N
;
; RETURNS:
; The address of the cursor line in the given pointer
; 
.proc SetCursorLine
	dey
	sty Multiplicand

	stx DATA_PTR
	sta DATA_PTR HI

	lda #$00
	tay
	sta Multiplicand HI
	sta Multiplier HI
	lda #SCREEN_COLUMNS
	sta Multiplier
	jsr Mult16x16

	clc
	lda #<(CURSOR_HOME_POS)
	adc Product
	sta (DATA_PTR),y
	lda #>(CURSOR_HOME_POS)
	adc Product HI
	iny
	sta (DATA_PTR),y

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
	SetPointer (SPRITE_PREVIEW_BUFFER), MEMCPY_TGT

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
	lda (MEMCPY_TGT),y
	ldy TMP_VAL_0
	sta EditCurChar

	; next byte
	clc
	lda	MEMCPY_TGT
	adc #1
	sta MEMCPY_TGT
	lda MEMCPY_TGT HI
	adc #0
	sta MEMCPY_TGT HI

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

; Convert the current grid to memory binary
.proc GridToMem
	SetPointer CURSOR_HOME_POS, CONSOLE_PTR

	; Bitmask for current bit
	ldx EditLines
	dex
	stx TMP_VAL_2			; Linecount

	lda #$80
	sta TMP_VAL_0			; Bitmask for current bit
	lda #$00
	tax								; Sprite buffer index
	sta TMP_VAL_1			; Current value
	lda #$07
	sta TMP_VAL_3			; bitcount
	bne @EnterLoop

@LineLoop:
	lda (CONSOLE_PTR),y
	cmp #'*'
	bne @NextBit			; If bit is not set, we can advance to the next bit

	; Set the current bit
	lda TMP_VAL_1
	ora TMP_VAL_0
	sta TMP_VAL_1

@NextBit:
	lda TMP_VAL_0
	clc
	ror
	sta TMP_VAL_0
	iny						; Grid columnindex
	dec TMP_VAL_2 HI		; Columncount
	dec TMP_VAL_3			; Bitcount
	bpl @LineLoop

	; Save the updated byte
	lda TMP_VAL_1
	sta SPRITE_PREVIEW_BUFFER,x

	; Reset byte values
	lda #$80
	sta TMP_VAL_0			; Bitmask for current bit
	lda #$00
	sta TMP_VAL_1			; Current value
	lda #$07
	sta TMP_VAL_3			; bitcount

	inx						; Bytebuffer index
	lda TMP_VAL_2 HI			; Columncount
	bpl @LineLoop

	jsr NextLine

	dec TMP_VAL_2			; Lines done?
	bmi @Done

@EnterLoop:
	ldy EditColumns
	dey
	sty TMP_VAL_2 HI			; Columncount

	ldy #$00

	jmp @LineLoop

@Done:
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

	jsr ShowCursor
	rts

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

; If the user pressed the key, we move the cursor
; to the top left corner, otherwise it stays where it is.
.proc ClearGridHome
	jsr ClearGrid
	SetPointer SPRITE_PREVIEW_BUFFER, PIXEL_LINE
	jmp MoveCursorHome
.endproc

; Clear the preview sprite buffer
.proc ClearGrid
	jsr SetDirty

	lda #$00
	ldy EditBufferLen
	dey

@Loop:
	sta SPRITE_PREVIEW_BUFFER,y
	dey
	bpl @Loop

	jmp DrawBitMatrix

.endproc

.proc InvertGrid
	jsr SetDirty
	ldy EditBufferLen
	dey

@Loop:
	lda SPRITE_PREVIEW_BUFFER,y
	eor #$ff
	sta SPRITE_PREVIEW_BUFFER,y
	dey
	bpl @Loop

	jsr DrawBitMatrix
	jmp ShowCursor
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
	sta EnterNumberEmpty

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
	sta EnterNumberEmpty

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
	jsr SaveDirty

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
	sta EnterNumberCurVal
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
	jsr SaveDirty

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
	jsr SaveDirty
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
	lda CONSOLE_PTR HI
	adc #0
	sta CONSOLE_PTR HI

	ldy TMP_VAL_0
	lda TMP_VAL_1

	dex
	bne @nextLine

	rts
.endproc

.proc SaveKeys
	ldy #KEY_LINES

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
; CONSOLE_PTR - points to the line
.proc ClearLine
	lda #' '
	ldx #SCREEN_COLUMNS-1
.endproc

; Fill max 255 with char
;
; PARAMS:
; A - char to write
; X - Number of character
; Y - Offset on CONSOLE_PTR
; CONSOLE_PTR
;
; RETURN:
; X - $ff
.proc FillChar

:
	sta (CONSOLE_PTR),y
	iny
	dex
	bpl :-

	rts
.endproc

.proc ClearStatusLines
	lda #' '
	ldy #79

:	sta INPUT_LINE,y
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

; Print a single byte value as decimal
;
; PARAMS:
; A - Skip number of digits
; X - Value
; Y - Offset in String
; STRING_PTR
;
; OPTIONAL:
; LeadingZeroes
; LeftAligned
;
; RETURN:
; Y - Position after last char printed
.proc PrintByteDec

	stx BINVal
	tax
	tya
	pha					; Save line offset

	lda #$00
	sta BINVal HI
	jsr BinToBCD16

	pla
	tay					; Restore line offset
	inx					; Skip the first digit otherwise it would be 4
	txa
	jmp BCDToString
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

	LAST_FRAME_VAL = TMP_VAL_2

	; For display to the user we want to have the counter
	; from 1...MAX_FRAMES
	inx
	stx LAST_FRAME_VAL

	tax
	inx

	lda #$00			; We want right alignment
	sta LeftAligned
	lda #$01
	jsr PrintByteDec

	ldx LAST_FRAME_VAL

	lda #$01			; Skip the first digit otherwise it would be 4
	iny
	jmp PrintByteDec
.endproc

.proc ToggleGridPixel
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

; Check if the current frame has changes. If yes
; it will be copied to it's target.
;
; PARAMS:
; X - Target frame
.proc SaveDirty
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

; Function asking the user for framenumber and
; filename which is used in all saving dialogs
; A prefix must be set so the user knows which
; save method he uses.
.proc InitSaveDlg
	; Copy the current edit buffer to the sprite frame buffer
	ldx CurFrame
	jsr SaveDirty

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
	sta BackupLen

	SetPointer SpriteSaveProgress, WriteFileProgressPtr
	jsr SaveFile
	bcs :+				; Error was already shown

	SetPointer DoneTxt, STRING_PTR
	ldy #$00
	jsr PrintStringZ
	jsr Delay
:
	jmp ClearStatusLines

@Cancel:
	; Print cancel text in status line
	SetPointer CanceledTxt, STRING_PTR
	jmp ShowStatusLine
.endproc

.proc SpriteSaveProgress

	SetPointer (INPUT_LINE), CONSOLE_PTR

	ldy BackupLen
	beq @DoProgress

@RestoreLoop:
	lda LineBackup,y
	sta (CONSOLE_PTR),y
	dey
	bpl @RestoreLoop

	iny
	sty BackupLen

@DoProgress:

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

.proc ShowStatusLine
	jsr ClearStatusLines

	SetPointer (INPUT_LINE), CONSOLE_PTR
	ldy #0
	jsr PrintStringZ

	; Show the status line for a small period of time
	jsr Delay

	jsr ClearStatusLines
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
	sta EnterNumberCurVal
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
; EnterNumberCurVal		- Current value of lowframe
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

	SetPointer EnterNumberStr, STRING_PTR

	lda #3
	sta EnterNumberMaxDigits

	; Get low frame
	clc
	lda CONSOLE_PTR
	adc FramenumberOffset
	sta CONSOLE_PTR
	lda CONSOLE_PTR HI
	adc #$00
	sta CONSOLE_PTR HI

	ldx #1
	lda EnterNumberCurVal
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

; Ask the user for a filename.
;
; PARAM:
;
; RETURN:
; Carry - Set if canceled
.proc EnterFilename
	SetPointer (INPUT_LINE), CONSOLE_PTR
	SetPointer FilenameTxt, STRING_PTR

	ldy #0
	jsr ClearLine

	ldy #0
	ldx FilenameLen
	jsr PrintString

	SetPointer DriveTxt, STRING_PTR
	ldy #27
	jsr PrintStringZ

@InputLoop:
	SetPointer (INPUT_LINE+FilenameTxtLen), CONSOLE_PTR
	SetPointer Filename, STRING_PTR

	ldx FilenameLen
	ldy #16
	jsr Input
	bcs @Cancel

	cpy #$00
	beq @EmptyFilename
	sty FilenameLen

	; Get drive number 
	SetPointer (INPUT_LINE+33), CONSOLE_PTR

	lda #$02
	sta EnterNumberMaxDigits

	lda DeviceNumber
	ldx #8
	ldy #12
	jsr EnterNumberValue
	bcs @Cancel
	sta DeviceNumber

	; Success
	clc
	rts

@Cancel:
	sec
	rts

@EmptyFilename:
	lda STRING_PTR
	pha
	lda STRING_PTR HI
	pha

	lda CONSOLE_PTR
	pha
	lda CONSOLE_PTR HI
	pha

	SetPointer (STATUS_LINE), CONSOLE_PTR
	SetPointer EmptyFilenameTxt, STRING_PTR
	ldy #0
	jsr PrintStringZ

	jsr Delay
	jsr Delay

	ldy #0
	jsr ClearLine

	pla
	sta CONSOLE_PTR HI
	pla
	lda CONSOLE_PTR

	pla
	sta STRING_PTR HI
	pla
	lda STRING_PTR

	jmp @InputLoop
.endproc

; Input a single frame number. It prints the frame text to 
; the specified location in CONSOLE_PTR.
;
; PARAMS:
; A - Framenumber to use as default
; Y - Offset of frame string.
; CONSOLE_PTR - position of the FRAME text.
; EnterNumberMaxDigits - Length of input string (1...3)
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
	sta EnterNumberMaxDigits

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

; Input a number value which can be 0...255
;
; PARAMS:
; A - CurValue
; X - MinValue
; Y - MaxValue
; CONSOLE_PTR - position of the input string
; EnterNumberMaxDigits - Length of input string (1...3)
;
; RETURN:
; A - Lobyte of value
; X - Hibyte of value
; C - clear (OK) : set (CANCEL)
; If C is set the value in A is undefined and should not be used.
.proc EnterNumberValue
	sta EnterNumberCurVal
	stx EnterNumberMinVal
	sty EnterNumberMaxVal

	lda #$00
	sta EnterNumberCurVal HI
	sta EnterNumberMinVal HI
	sta EnterNumberMaxVal HI

.endproc

; Input a number value which can be 0...65535
;
; PARAMS:
; EnterNumberEmpty	0 - Print curValue as default. 1 - Leave string empty
; EnterNumberCurVal
; EnterNumberMinVal
; EnterNumberMaxVal
; EnterNumberMaxDigits
; CONSOLE_PTR - position of the input string
; EnterNumberMaxDigits - Length of input string (1...5)
;
; RETURN:
; A - Lobyte of value
; X - Hibyte of value
; C - clear (OK) : set (CANCEL)
; If C is set, the value in A is undefined and should not be used.
.proc InputNumber
	SetPointer NumberInputFilter, InputFilterPtr

@InputLoop:
	SetPointer EnterNumberStr, STRING_PTR
	ldy #EnterNumberStrLen-1
						; 5 digits + clear the last
						; byte to make sure the number
						; conversion doesn't pick up a
						; stray digit.
	lda #' '

@ClearString:
	sta (STRING_PTR),y
	dey
	bpl @ClearString

	lda EnterNumberEmpty
	beq @PrintDefault
	ldx #$00
	jmp @SkipPrint

@PrintDefault:
	lda EnterNumberCurVal
	sta BINVal
	lda EnterNumberCurVal HI
	sta BINVal HI
	jsr BinToBCD16

	lda #$ff			; Enable left alignment for the input
	sta LeftAligned
	lda #$01			; We only need 3 digits, so we have to skip the highbyte
	tax
	ldy #0
	jsr BCDToString

@SkipPrint:
	ldy EnterNumberMaxDigits
	jsr Input
	bcs @Cancel			; User pressed cancel button
	cpy #$00			; Empty string was entered
	beq @RangeError

	; String length of input string
	tya
	tax

	jsr StringToBin16
	cpx #$00			; Value can not be higher than 255
	bne @RangeError		; So the highbyte must be 0

	cmp EnterNumberMinVal
	blt @RangeError
	cmp EnterNumberMaxVal
	bgt @RangeError

	jmp @Done

@Cancel:
	sec
	bcs @Exit

@Done:
	clc

@Exit:
	pha
	SetPointer DefaultInputFilter, InputFilterPtr
	pla
	rts

@RangeError:
	lda STRING_PTR
	sta EnterNumberStringPtr
	lda STRING_PTR HI
	sta EnterNumberStringPtr+1

	lda CONSOLE_PTR
	sta EnterNumberConsolePtr
	lda CONSOLE_PTR HI
	sta EnterNumberConsolePtr+1

	SetPointer (STATUS_LINE), CONSOLE_PTR
	SetPointer EnterNumberMsg, STRING_PTR
	ldy #0
	ldx #EnterNumberMsgLen
	jsr PrintString

	lda CONSOLE_PTR
	sta STRING_PTR
	lda CONSOLE_PTR HI
	sta STRING_PTR HI

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
	sta CONSOLE_PTR HI

	lda EnterNumberStringPtr
	sta STRING_PTR
	lda EnterNumberStringPtr+1
	sta STRING_PTR HI

	jmp @InputLoop
.endproc

; Check if the specified file exists and ask
; user to overwrite it.
;
; PARAM:
; Filename - Filename in PETSCII
; FilenameLen - Length of the filename
;
; RETURN:
; Z - 1 : Overwrite, 0 : Keep. The returncode
;     is set last on exit, so the caller
;     can directly use the Z-flag as well.
; Carry - Set if canceled
;         If cleared, then A/Z contains response
.proc OverwriteFileDlg

	SetPointer INPUT_LINE, CONSOLE_PTR
	ldy #0
	jsr ClearLine

	SetPointer FileExistsTxt, STRING_PTR
	ldy #0
	jsr PrintStringZ

	; Position cursor on the 'N'
	dey
	sty TMP_VAL_0

	clc
	lda CONSOLE_PTR
	adc TMP_VAL_0
	sta CONSOLE_PTR
	lda CONSOLE_PTR HI
	adc #$00
	sta CONSOLE_PTR HI

	; Default is 'N'
	SetPointer TMP_VAL_0, STRING_PTR
	lda #$4e				; 'N'
	sta TMP_VAL_0

	SetPointer YNInputFilter, InputFilterPtr

	ldx #1
	ldy #1
	jsr Input
	bcs @Cancel

	SetPointer DefaultInputFilter, InputFilterPtr

	lda TMP_VAL_0
	cmp #$4e				; 'N'
	bne @Done				; Read Z-1 to Overwrite file

	; Z - 0 : Keep file

@Done:
	clc
	rts

@Cancel:
	SetPointer DefaultInputFilter, InputFilterPtr
	sec
	rts
.endproc

; Write a memoryblock into a sequential
; file. If the file already exists the
; user is asked if he wants to overwrite
; and if not, to enter a new filename.
;
; PARAM:
; Filename - Filename in PETSCII
; FilenameLen - Length of the filename
; MEMCPY_SRC	- Startadress
; MEMCPY_TGT	- Endadress
; WriteFileProgressPtr
;
; RETURN:
; Carry - set on error
.proc SaveFile

	lda CONSOLE_PTR
	sta ConsolePtrBackup
	lda CONSOLE_PTR HI
	sta ConsolePtrBackup HI

	ldy #SCREEN_COLUMNS-1
	sty BackupLen

@BackupLoop:
	lda (CONSOLE_PTR),y
	sta LineBackup,y
	dey
	bpl @BackupLoop

@Retry:
	ldx DeviceNumber
	jsr OpenDiscStatus
	bcs @Error

	lda #$00
	sta STATUS

	SetPointer Filename, FILENAME_PTR

	lda #'s'
	sta FileType
	lda #'w'			; Write mode
	ldy #2				; Fileno
	ldx DeviceNumber	; Device
	jsr OpenFile
	bcc @Write			; Open worked

	; Check if file exists error
	lda DiscStatusCode
	cmp #63
	bne @Error			; Some other error

	; If file exists we have to check for overwriting
	jsr OverwriteFileDlg
	bcs @Cancel
	bne @DeleteFile	; User answered Y, so the file should be deleted

	; When entering 'N' The user is asked for a new filename
	jsr EnterFilename
	bcs @Cancel

	jsr @Cleanup
	jmp @Retry			; Try again with new filename

@DeleteFile:
	SetPointer INPUT_LINE, CONSOLE_PTR
	ldy #$00
	jsr ClearLine

	SetPointer DeleteTxt, STRING_PTR
	ldy #$00
	jsr PrintStringZ
	SetPointer Filename, STRING_PTR
	iny
	ldx FilenameLen
	jsr PrintPETSCII

	jsr @Cleanup
	jsr DeleteFile
	jmp @Retry		; Try again with after file was deleted.

@Write:
	ldx #2
	jsr WriteFile
	bcs @Error

@Close:
	jsr @Cleanup
	clc
	rts

@Error:
	jsr FileError

@Cancel:
	jsr @Cleanup
	sec
	rts

@Cleanup:
	lda #2
	jsr CloseFile

	ldx DeviceNumber
	jsr CloseDiscStatus

	lda ConsolePtrBackup
	sta CONSOLE_PTR
	lda ConsolePtrBackup HI
	sta CONSOLE_PTR HI

	rts
.endproc

; Write a memoryblock into a sequential
; file.
;
; PARAM:
; Filename - Filename in PETSCII
; FilenameLen - Length of the filename
; MEMCPY_SRC	- Startadress
; MEMCPY_TGT	- Endadress
; ReadFileProgressPtr
;
; RETURN:
; STATUS - Errorstatus from OS
;
.proc LoadFile

	ldx DeviceNumber
	jsr OpenDiscStatus
	bcs @Error

	lda #$00
	sta STATUS

	SetPointer Filename, FILENAME_PTR
	lda #'s'
	sta FileType
	lda #'r'			; Read mode
	ldy #2				; Fileno
	ldx DeviceNumber	; Device
	jsr OpenFile
	bcs @Error

	ldx #2
	jsr ReadFile
	bcs @Error

@Close:
	lda #2
	jsr CloseFile

	ldx DeviceNumber
	jsr CloseDiscStatus

	clc
	rts

@Error:
	jsr FileError
	jsr @Close
	sec
	rts
.endproc

; Print an appropriate errormessage
.proc FileError
	SetPointer (INPUT_LINE), CONSOLE_PTR

	; Check if DiscStatus was already called
	ldx DiscStatusCode
	cpx #$ff
	bne @DiscError

	ldx DeviceNumber
	jsr ReadDiscStatus
	ldx DiscStatusCode
	cpx #$ff
	bne @DiscError

@DeviceNotPresent:
	SetPointer ErrorDeviceNotPresentTxt, STRING_PTR
	ldx #ErrorDeviceNotPresentTxtLen
	jmp @Done

@DiscError:
	SetPointer DiscStatusString, STRING_PTR
	ldx DiscStatusStringLen
	bne @Done

@IOError:
	SetPointer ErrorFileIOTxt, STRING_PTR
	ldx #ErrorFileIOTxtLen

@Done:
	ldy #SCREEN_COLUMNS
	jsr PrintString
	jsr Flash
	jsr WaitKeyboardPressed
	jsr WaitKeyboardRelease

@Close:
	lda #2
	jsr CloseFile

	ldy #0
	jsr ClearLine
	ldy #SCREEN_COLUMNS
	jsr ClearLine
	lda #$00
	sta STATUS
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
	jmp ClearStatusLines

@Cancel:
	; Print cancel text in status line
	SetPointer CanceledTxt, STRING_PTR
	jmp ShowStatusLine
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

.proc ExportBasicData
	SetPointer ExportTxt, STRING_PTR
	jsr InitSaveDlg

	SetPointer ExportBasicTxt, STRING_PTR
	ldy #$00
	jsr PrintStringZ

	rts
.endproc

; Library includes
SCANKEYS_BLOCK_IRQ = 1
.include "kbd/keyboard_pressed.s"
.include "kbd/keyboard_released.s"
.include "kbd/keyboard_released_modignore.s"
.include "kbd/keyboard_mapping.s"
.include "kbd/input.s"
.include "kbd/number_input_filter.s"
.include "kbd/y_n_input_filter.s"

.include "math/bintobcd16.s"
.include "math/mult16x16.s"

.include "string/bcdtostring.s"
.include "string/printstring.s"
.include "string/printpetscii.s"
.include "string/printstringz.s"
.include "string/printhex.s"
.include "string/string_to_bin16.s"

.include "devices/readdiscstatus.s"
.include "devices/openfile.s"
.include "devices/readfile.s"
.include "devices/writefile.s"
.include "devices/deletefile.s"
; **********************************************
.segment "DATA"
;                            1         2         3         4
;                  0123456789012345678901234567890123456789
VersionTxt: .byte   "SPREDDI V0.80 BY GERHARD GRUBER 2021",0

; Saving/Loading
FilenameDefaultTxt: .byte "spritedata"	; Filename is in PETSCII
FilenameDefaultTxtLen = *-FilenameDefaultTxt

EnterNumberMsg: .byte "VALUE MUST BE IN RANGE "
EnterNumberMsgLen = *-EnterNumberMsg

MaxFrameValue: .word MAX_FRAMES
FrameTxt: .byte "FRAME:  1/  1",0
FrameTxtOnlyLen = 6
SpriteFramesMaxTxt: .byte "# FRAMES:",.sprintf("%3u",MAX_FRAMES),0
CurFrame: .byte $00		; Number of active frame 0...MAX_FRAMES-1
MaxFrame: .byte $00		; Maximum frame number in use 0..MAX_FRAMES-1
ColorTxt: .byte "COLOR:",0
ColorTxtLen = *-ColorTxt-1

WelcomeColor: .byte COL_GREEN, COL_RED, COL_WHITE
SpriteColorDefaults: .byte COL_LIGHT_GREY, COL_GREEN, COL_BLUE

CanceledTxt:	.byte "           OPERATION CANCELED           ",0
FilenameTxt:	.byte "FILENAME: ",0
FilenameTxtLen	= (*-FilenameTxt)-1
SaveTxt:		.byte "SAVE ",0
ExportTxt:		.byte "EXPORT ",0
OpenFileTxt:	.byte "OPEN FILE: ",0
WritingTxt:		.byte "WRITING ",0
LoadingTxt:		.byte "READING ",0
DeleteTxt:		.byte "DELETE",0
DoneTxt:		.byte "DONE                                    ",0
EmptyFilenameTxt: .byte "FILENAME CAN NOT BE EMPTY!",0
DriveTxt:		.byte "DRIVE: ",0
MaxFramesReachedTxt: .byte "MAX. # OF FRAMES REACHED!",0
FileExistsTxt: .byte "FILE EXISTS! OVERWRITE? N",0
ExportBasicTxt: .byte "LNR: 1000 STEP: 100 CMPR/PRETTY: C",0

ErrorDeviceNotPresentTxt: .byte "DEVICE NOT PRESENT",0
ErrorDeviceNotPresentTxtLen = (*-ErrorDeviceNotPresentTxt)-1
ErrorFileIOTxt: .byte "FILE I/O ERROR",0
ErrorFileIOTxtLen = (*-ErrorFileIOTxt)-1

CharPreviewTxt: .byte "CHARACTER PREVIEW",0

WelcomeSpriteData:
.if 0	; HAVE FUN
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
.endif

; Candle
	.byte $00, $00, $00
	.byte $00, $00, $00
	.byte $00, $02, $00
	.byte $20, $20, $00
	.byte $00, $28, $20
	.byte $00, $38, $00
	.byte $08, $A8, $00
	.byte $00, $A0, $00
	.byte $00, $20, $00
	.byte $00, $00, $00
	.byte $00, $54, $00
	.byte $01, $54, $00
	.byte $01, $54, $00
	.byte $01, $54, $00
	.byte $01, $54, $00
	.byte $01, $55, $00
	.byte $01, $55, $00
	.byte $F1, $55, $4C
	.byte $3F, $FF, $FC
	.byte $03, $FF, $C0
	.byte $00, $00, $00
	.byte 0


SpriteEditorKeyMap:
	DefineKey 0, $1d, REPEAT_KEY,    MoveCursorRight				; CRSR-Right
	DefineKey 0, $11, REPEAT_KEY,    MoveCursorDown					; CRSR-Down
	DefineKey 0, $20, REPEAT_KEY,    ToggleGridPixel				; SPACE
	DefineKey 0, $2e, REPEAT_KEY,    NextFrame						; .
	DefineKey 0, $2c, REPEAT_KEY,    PreviousFrame					; ,
	DefineKey 0, $14, REPEAT_KEY,    DeleteColumn					; DEL
	DefineKey 0, $13, NO_REPEAT_KEY, MoveCursorHome					; HOME
	DefineKey 0, $0d, NO_REPEAT_KEY, MoveCursorNextLine				; ENTER
	DefineKey 0, $43, NO_REPEAT_KEY, CopyFromFrame					; C
	DefineKey 0, $44, NO_REPEAT_KEY, DeleteCurrentFrame				; D
	DefineKey 0, $45, NO_REPEAT_KEY, ExportBasicData				; E
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
	DefineKey KEY_SHIFT|KEY_CTRL, $94, REPEAT_KEY, InsertColumns	; CTRL-INS
	DefineKey KEY_SHIFT|KEY_COMMODORE, $94, REPEAT_KEY, InsertLine	; CMDR-INS

	; COMMODORE keys
	DefineKey KEY_COMMODORE, $aa, NO_REPEAT_KEY, AppendFrameCopy	; CMDR-N
	DefineKey KEY_COMMODORE, $b3, REPEAT_KEY, ShiftGridUp			; CMDR-W
	DefineKey KEY_COMMODORE, $ae, REPEAT_KEY, ShiftGridDown			; CMDR-S
	DefineKey KEY_COMMODORE, $b0, REPEAT_KEY, ShiftGridLeft			; CMDR-A
	DefineKey KEY_COMMODORE, $ac, REPEAT_KEY, ShiftGridRight		; CMDR-D
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
MAIN_APPLICATION_END = *
;====================================================
.bss

BSS_START = *

; Functionpointer to the current keyboardhandler
EditorKeyHandler: .word 0
WelcomeDone: .word 0

TMP_VAL_0: .word 0
TMP_VAL_1: .word 0
TMP_VAL_2: .word 0
TMP_VAL_3: .word 0

RectangleLineOffset: .byte 0

SpriteColorValue: .byte 0, 0, 0

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
; Same as EditFrameSize, only it can differ slightly.
; A sprite is 3*21 = 63 bytes, but the sprite pointer accepts only multiples of 64
; so this value defines the actual bytelength.
EditBufferLen:	.byte 0

; Temp for drawing the edit box
EditCurChar: .byte 0
EditCurColumns: .byte 0
EditCurLine: .byte 0

; Keyboard handling
LastKeyLine: .res KEY_LINES
LastKeyPressed: .byte $00
LastKeyPressedLine: .byte $00

FrameNumberStart: .byte 0		; first frame input
FrameNumberEnd: .byte 0			; last frame input
FrameNumberCur: .byte 0			; current frame
FramenumberOffset: .byte 0

; Range values for Frame number input
FrameNumberStartLo: .byte 0
FrameNumberStartHi: .byte 0
FrameNumberEndHi: .byte 0

EnterNumberStrLen = 7
EnterNumberStr: .res EnterNumberStrLen
EnterNumberMaxDigits: .byte 0
EnterNumberEmpty: .byte 0		; 1 - InputNumber will not print the current value
EnterNumberCurVal: .word 0
EnterNumberMinVal: .word 0
EnterNumberMaxVal: .word 0
EnterNumberStringPtr: .word 0
EnterNumberConsolePtr: .word 0

MoveFrameCnt: .byte 0
MoveFirstFrame: .byte 0
MoveLastFrame: .byte 0
MoveTargetFrame: .byte 0
MoveDirection: .word 0
CopyFrameFlag: .word 0

; Characters to be used for a frame border
LeftBottomRight: .res 8

FramePtr: .word 0	; Address for current frame pointer

; Decodiertabelle Intern p.359 $FA80
KeyTableLen = KEY_LINES*8
SymKeytableNormal:		.res KeyTableLen
SymKeytableShift:		.res KeyTableLen
SymKeytableCommodore:	.res KeyTableLen
SymKeytableControl:		.res KeyTableLen
SymKeytableAlt:			.res KeyTableLen

BackupLen: .byte 0
ConsolePtrBackup: .word 0
LineBackup: .res BASIC_MAX_LINE_LEN
LineBackupLen = SCREEN_COLUMNS

BSS_END = *

END:
