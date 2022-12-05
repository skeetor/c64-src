; Sprite and character editor for C128 with CA65 assembler
; Written by Gerhard W. Gruber in 11.09.2021
;
.macpack cbm

.include "screenmap.inc"

.include "c128_system.inc"

.include "tools/misc.inc"
.include "tools/intrinsics.inc"

; Debug defines
KEYBOARD_DEBUG_PRINT = 1

.ifdef C64
CMDR_SHIFT_LOCK		= $291
.else
CMDR_SHIFT_LOCK		= LOCKS
.endif

; Zeropage variables
CONSOLE_PTR			= SCREEN_PTR	; $e0

ZP_BASE				= $40
ZP_BASE_LEN			= $0f

MEMCPY_SRC			= ZP_BASE+0
MEMCPY_TGT			= ZP_BASE+2
MEMCPY_LEN			= ZP_BASE+4
MEMCPY_LEN_LO		= ZP_BASE+4
MEMCPY_LEN_HI		= ZP_BASE+5
DATA_PTR_END		= ZP_BASE+4
FILENAME_PTR		= ZP_BASE+6
DATA_PTR			= ZP_BASE+6	
STRING_PTR			= ZP_BASE+8
KEYMAP_PTR			= ZP_BASE+10
CURSOR_LINE			= ZP_BASE+12
PIXEL_LINE			= ZP_BASE+14

KEYTABLE_PTR		= $fb

; Library variables
.define KEY_LINES	C128_KEY_LINES

; Position of the color text.
COLOR_TXT_ROW		= 12
COLOR_TXT_COLUMN	= 26

;  Import segment definitions for relocation
.export __LOADADDR__ = *
.export STARTADDRESS = *

.import __BASE_LOAD__
.import __BASE_SIZE__
.import __CODE_LOAD__
.import __CODE_SIZE__
.import __DATA_LOAD__
.import __DATA_SIZE__
.import __BSS_LOAD__
.import __BSS_SIZE__

MAIN_APP_BASE		= SPRITE_END; Address where the main code is relocated to
CURSOR_HOME_POS		= SCREEN_VIC+SCREEN_COLUMNS+1
BASIC_MAX_LINE_LEN	= 255

; Editor bit flags
EDIT_DIRTY			= $01

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

.segment "LOADADDR"
.byte .LOBYTE( __LOADADDR__ ), .HIBYTE( __LOADADDR__ )

.segment "BASE"

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

	; Wait until the first key is pressed and
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

.proc Setup

	MAIN_APPLICATION_LEN	= (__CODE_SIZE__+__DATA_SIZE__)
	MAIN_APPLICATION_LOAD	= (__BASE_LOAD__+__BASE_SIZE__)
	MAIN_APPLICATION		= __CODE_LOAD__
	BSS_LEN					= __BSS_SIZE__
	BSS_START				= __BSS_LOAD__

	; Switch to default C128 config. Doesn't hurt on C64
	lda #$00
	sta MainExitFlag
	sta MMU_CR_IO
	sta EditCursorX
	sta EditCursorY

	sei

	; Save lock state and disable it
	lda CMDR_SHIFT_LOCK
	sta LockFlag
	lda #$ff
	sta CMDR_SHIFT_LOCK

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

	SetPointer BSS_LEN, MEMCPY_LEN
	SetPointer BSS_START, MEMCPY_TGT
	lda #$00
	jsr memset

	lda #SPRITE_BUFFER_LEN
	sta Multiplier

	jsr DetectSystem
	jsr CopyKeytables

	; Reset all sprite expansions
	lda	#$00
	sta SPRITE_EXP_X
	sta SPRITE_EXP_Y

	; Init the default pointers, constants and values
	SetPointer (EditorKeyboardHandler), EditorKeyHandler
	SetPointer (STATUS_LINE), EnterNumberConsolePtr
	SetPointer 10000, ExportFirstLineNr
	SetPointer    10, ExportStepSize
	SetPointer NumberRangeError, InputNumberErrorHandler
	lda #SCREEN_COLUMNS
	sta BorderScreenWidth

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
	sta CMDR_SHIFT_LOCK

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

.proc DetectSystem
	lda #0
	sta SystemMode

	ldy #3
@C64Check:
	lda $eb81,y
	cmp C64Id,y
	bne @IsC128
	dey
	bpl @C64Check

	; It's a C64, now check if it is a real one
	lda SystemMode
	ora #C64_MODE
	sta SystemMode

	; TODO: Will this also work on M65?
	lda #$00
	sta VIC_KBD_128
	lda VIC_KBD_128
	ldy #C64_MODE
	cmp #$ff
	beq @Done

	lda SystemMode
	ora #C128_MODE
	sta SystemMode
	jmp @Done

@IsC128:
	ldy #3
@C128Check:
	lda $eb81,y
	cmp C64Id,y
	bne @Done
	dey
	bpl @C128Check

	lda SystemMode
	ora #C128_MODE
	sta SystemMode

@Done:
	rts
.endproc

.proc FarCaller
	jmp (FARCALL_PTR)
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

.code
;.org MAIN_APP_BASE
MAIN_APPLICATION = *

.proc IRQHandler
	; Switch to our editor config with hi kernel enabled
	sta MMU_LOAD_CRD

	cld

	inc $0400

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

	; TODO: IRQ handler not working, this was just experimental
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

; Copy the kernel key decoding tables to our memory
; so we can easily access it.
.proc CopyKeytables

	lda SystemMode
	and #C64_MODE
	beq @C128_KT

	SetPointer KT_64_NORMAL, KeytableNormal
	SetPointer KT_64_SHIFT, KeytableShift
	SetPointer KT_64_COMMODORE, KeytableCommodore
	SetPointer KT_64_CONTROL, KeytableControl
	SetPointer KT_64_ALT, KeytableAlt

	jmp @CopyTables

@C128_KT:
	SetPointer KT_128_NORMAL, KeytableNormal
	SetPointer KT_128_SHIFT, KeytableShift
	SetPointer KT_128_COMMODORE, KeytableCommodore
	SetPointer KT_128_CONTROL, KeytableControl
	SetPointer KT_128_ALT, KeytableAlt

@CopyTables:
	CopyPointer KeytableNormal, MEMCPY_SRC
	SetPointer SymKeytableNormal, MEMCPY_TGT

	ldy #KeyTableLen
	jsr memcpy255
	CopyPointer MEMCPY_TGT, KeytableNormal

	; Shifted keys
	CopyPointer KeytableShift, MEMCPY_SRC
	SetPointer SymKeytableShift, MEMCPY_TGT

	ldy #KeyTableLen
	jsr memcpy255
	CopyPointer MEMCPY_TGT, KeytableShift

	; Commodore keys
	CopyPointer KeytableCommodore, MEMCPY_SRC
	SetPointer SymKeytableCommodore, MEMCPY_TGT

	ldy #KeyTableLen
	jsr memcpy255
	CopyPointer MEMCPY_TGT, KeytableCommodore

	; CTRL keys
	CopyPointer KeytableControl, MEMCPY_SRC
	SetPointer SymKeytableControl, MEMCPY_TGT

	ldy #KeyTableLen
	jsr memcpy255
	CopyPointer MEMCPY_TGT, KeytableControl

	; ALT keys
	CopyPointer KeytableAlt, MEMCPY_SRC
	SetPointer SymKeytableAlt, MEMCPY_TGT

	ldy #KeyTableLen
	jsr memcpy255
	CopyPointer MEMCPY_TGT, KeytableAlt

	; Unused keycode in the kernel
	; but we want it, so we patch it 
	lda #$a0
	ldy #$00				; DEL
	sta SymKeytableControl,y

	rts
.endproc

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

.proc HideCursor
	ldy EditCursorX
	lda EditDoubleCursor
	beq @DoCursor
	jsr @DoCursor
	iny

@DoCursor:
	lda (CURSOR_LINE),y
	and #$7f
	sta (CURSOR_LINE),y
	rts
.endproc

.proc ShowCursor
	ldy EditCursorX
	lda EditDoubleCursor
	beq @DoCursor
	jsr @DoCursor
	iny

@DoCursor:
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

	lda EditDoubleCursor
	beq @DoCursorRight
	jsr @DoCursorRight

@DoCursorRight:

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

	lda EditDoubleCursor
	beq @DoCursorLeft
	jsr @DoCursorLeft

@DoCursorLeft:
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
; Draw the border frame.
;
; ZP Usage:
; CONSOLE_PTR - pointer to screen
; TMP_VAL_0 - line counter
.proc DrawScreenborder

	lda #CHAR_ROUND_TOP_LEFT
	sta BorderTopLeft
	lda #CHAR_ROUND_TOP_RIGHT
	sta BorderTopRight
	lda #CHAR_ROUND_BOT_LEFT
	sta BorderBottomLeft
	lda #CHAR_ROUND_BOT_RIGHT
	sta BorderBottomRight
	lda #CHAR_HORIZONTAL
	sta BorderHorizontal
	lda #CHAR_VERTICAL
	sta BorderVertical
	lda #SCREEN_COLUMNS
	sta BorderWidth
	lda #SCREEN_LINES-2
	sta BorderHeight

	SetPointer SCREEN_VIC, CONSOLE_PTR
	jmp DrawBorder
.endproc

; We assume that the border still contains the top
; left, etc. characters, so we only update those that
; actually change.
.proc DrawMatrixBorder

	lda #CHAR_SPLIT_TOP
	sta BorderTopRight
	lda #CHAR_SPLIT_BOT
	sta BorderBottomRight

	ldy EditColumns
	iny
	iny
	sty BorderWidth
	lda EditLines
	sta BorderHeight

	SetPointer SCREEN_VIC, CONSOLE_PTR
	jmp DrawBorder
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

	jsr NextLine

	dec EditCurLine
	bne @nextLine

	jmp DrawMatrixBorder
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

.proc ShowCancel
	; Print cancel text in status line
	SetPointer CanceledTxt, STRING_PTR
	jmp ShowStatusLine
.endproc

.proc ShowStatusLine
	jsr ClearStatusLines

	SetPointer (INPUT_LINE), CONSOLE_PTR
	ldy #0
	jsr PrintStringZ

	; Show the status line for a small period of time
	jsr Delay

	jmp ClearStatusLines
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
	sta InputNumberMaxDigits

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

; Input a number value which can be 0...255
;
; PARAMS:
; A - CurValue
; X - MinValue
; Y - MaxValue
; CONSOLE_PTR - position of the input string
; InputNumberMaxDigits - Length of input string (1...3)
;
; RETURN:
; A - Lobyte of value
; X - Hibyte of value
; C - clear (OK) : set (CANCEL)
; If C is set the value in A is undefined and should not be used.
.proc EnterNumberValue
	sta InputNumberCurVal
	stx InputNumberMinVal
	sty InputNumberMaxVal

	lda #$00
	sta InputNumberCurVal HI
	sta InputNumberMinVal HI
	sta InputNumberMaxVal HI
	jmp InputNumber
.endproc

; Error handler for number input range error.
; Just prints a message and allows the user to re-enter.
.proc NumberRangeError

	lda CONSOLE_PTR
	pha
	lda CONSOLE_PTR HI
	pha

	lda EnterNumberConsolePtr
	sta CONSOLE_PTR
	lda EnterNumberConsolePtr HI
	sta CONSOLE_PTR HI

	SetPointer EnterNumberErrorMsg, STRING_PTR
	ldy #0
	ldx #EnterNumberErrorMsgLen
	jsr PrintString

	lda CONSOLE_PTR
	sta STRING_PTR
	lda CONSOLE_PTR HI
	sta STRING_PTR HI

	; Print allowed range values
	; Lower value
	lda InputNumberMinVal
	sta BINVal
	lda InputNumberMinVal HI
	sta BINVal HI

	lda InputNumberMaxDigits
	ldx #0				; Left aligned
	jsr PrintDecimal

	; Upper value
	lda InputNumberMaxVal
	sta BINVal
	lda InputNumberMaxVal HI
	sta BINVal HI

	lda #'/'
	sta (CONSOLE_PTR),y
	iny

	lda InputNumberMaxDigits
	ldx #0				; Left aligned
	jsr PrintDecimal

	jsr Delay
	jsr Delay

	ldy #0
	jsr ClearLine

	pla
	sta CONSOLE_PTR HI
	pla
	sta CONSOLE_PTR

	clc
	rts
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
; FileType - 's' for SEQ or 'p' for PRG
; Filename - Filename in PETSCII
; FilenameLen - Length of the filename
; MEMCPY_SRC	- Startadress
; MEMCPY_TGT	- Endadress
; WriteFileProgressPtr
;
; RETURN:
; Carry - set on error
.proc SaveFile

@Retry:
	ldx DeviceNumber
	jsr OpenDiscStatus
	bcs @Error

	lda #$00
	sta STATUS

	SetPointer Filename, FILENAME_PTR

	lda #'w'			; Write mode
	ldy #2				; Fileno
	ldx DeviceNumber	; Device
	jsr OpenFile
	bcc @Write			; Open worked

	jsr CheckOverwrite
	bcc @Retry
	bcs @Error

@Write:
	ldx #2
	jsr WriteFile
	bcs @Error

@Close:
	jsr SaveFileCleanup
	clc
	rts

@Error:
	jsr FileError

@Cancel:
	jsr SaveFileCleanup
	sec
	rts
.endproc

.proc SaveFileCleanup

	lda #2
	jsr CloseFile

	ldx DeviceNumber
	jsr CloseDiscStatus

	rts
.endproc

; Internal Routine for SaveFile. This will check if the
; disc error code is FILE EXISTS. If not, then it was a
; different error and should be handled by the caller.
; Otherwise the user is asked if he wants to overwrite
; the file. If Y, the file is delete, otherwise a new
; filename is asked.
;
; RETURN:
; C - Clear if save operation should be retried, either
;     because the file was deleted, or a new filename was
;     enterd. The Z flag in this case is undefined.
;     Set if an error occured or the request was canceled.
;
; Z - Set if C set. The user canceled the operation.
;     Clear if C set. Any other error than FILE_EXISTS
;     which should be handled by the caller.
;
.proc CheckOverwrite
	; Check if file exists error
	lda DiscStatusCode
	cmp #63
	bne @Error			; Some other error

	lda CONSOLE_PTR
	sta ConsolePtrBackup
	lda CONSOLE_PTR HI
	sta ConsolePtrBackup HI

	; Backup the current line, so we can make use of it.
	ldy #SCREEN_COLUMNS-1

@BackupLoop:
	lda INPUT_LINE,y
	sta LineMem,y
	dey
	bpl @BackupLoop

	; If file exists we have to check for overwriting
	jsr OverwriteFileDlg
	bcs @Cancel
	bne @DeleteFile		; User answered Y, so the file should be deleted

	; When entering 'N' The user is asked for a new filename
	jsr EnterFilename
	bcs @Cancel

	jsr @Cancel
	clc
	rts					; Try again with new filename

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

	jsr SaveFileCleanup
	jsr DeleteFile

	jsr @Restore
	clc
	rts					; Try again after file was deleted.

@Cancel:
	jsr SaveFileCleanup
	jsr @Restore
	lda #$00
	sec
	rts

@Error:
	lda #$01
	sec
	rts

@Restore:
	ldy #SCREEN_COLUMNS-1

@RestoreLoop:
	lda LineMem,y
	sta INPUT_LINE,y
	dey
	bpl @RestoreLoop

	lda ConsolePtrBackup
	sta CONSOLE_PTR
	lda ConsolePtrBackup HI
	sta CONSOLE_PTR HI
	rts
.endproc

; Load a memoryblock from a file.
;
; PARAM:
; FileType - 's' for SEQ or 'p' for PRG
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

.proc ExportBasicDataDlg
	SetPointer ExportTxt, STRING_PTR
	jsr InitSaveDlg
	lbcs @Done

	SetPointer ExportBasicTxt, STRING_PTR
	ldy #$00
	jsr PrintStringZ

	; Linenr range = 1 - 60000
	SetPointer     1, InputNumberMinVal
	SetPointer 60000, InputNumberMaxVal
	CopyPointer ExportFirstLineNr, InputNumberCurVal

	; LineNr
	SetPointer (INPUT_LINE+4), CONSOLE_PTR
	lda #5
	sta InputNumberMaxDigits
	jsr InputNumber
	lbcs @Cancel
	stx ExportFirstLineNr HI
	sta ExportFirstLineNr

	; Stepsize
	SetPointer (INPUT_LINE+15), CONSOLE_PTR
	CopyPointer ExportStepSize, InputNumberCurVal
	lda #4
	sta InputNumberMaxDigits
	jsr InputNumber
	lbcs @Cancel
	stx ExportStepSize HI
	sta ExportStepSize

	; Pretty/Compressed
	SetPointer (INPUT_LINE+33), CONSOLE_PTR
	SetPointer ExportPretty, STRING_PTR
	SetPointer ExportPrettyFilter, InputFilterPtr
	ldx #$43				; 'C'
	stx ExportPretty
	ldx #1
	ldy #1
	jsr Input
	bcs @Cancel

	lda ExportPretty
	ldy #$00
	sty ExportPretty
	cmp #$43
	bne @OpenFile
	dec ExportPretty

@OpenFile:
	jsr ExportBasicFile

@Done:
	SetPointer DefaultInputFilter, InputFilterPtr
	SetPointer DefaultWriteProgess, WriteFileProgressPtr
	jsr ClearStatusLines

	rts

@Cancel:
	jsr @Done
	jmp ShowCancel
.endproc

.macro AddBasicByte
	sta LineMem,y
	iny
.endmacro

.proc ExportBasicFile
	SetPointer INPUT_LINE, CONSOLE_PTR

	ldy #0
	jsr ClearLine

	SetPointer ExportTxt, STRING_PTR
	ldy #0
	jsr PrintStringZ

	SetPointer FrameTxt, STRING_PTR
	jsr PrintStringZ

	lda CONSOLE_PTR
	sta STRING_PTR
	lda CONSOLE_PTR HI
	sta STRING_PTR HI
	lda FrameNumberStart
	ldx FrameNumberEnd
	ldy #13
	jsr PrintFrameCounter

@Retry:
	ldx DeviceNumber
	jsr OpenDiscStatus
	lbcs @Error

	lda #$00
	sta STATUS

	SetPointer Filename, FILENAME_PTR

	lda #'p'
	sta FileType
	lda #'w'			; Write mode
	ldy #2				; Fileno
	ldx DeviceNumber	; Device
	jsr OpenFile
	bcc @InitExport		; Open worked

	jsr CheckOverwrite
	lbcc @Retry
	lbcs @Error

@InitExport:
	; Since we are writing blockwise on our own
	; we don't really need a progress function here.
	SetPointer DefaultWriteProgess, WriteFileProgressPtr

	SetPointer LineMem, MEMCPY_SRC
	SetPointer (LineMem+2), MEMCPY_TGT

	SetPointer (__LOADADDR__), LineMem

	; Write BASIC start address.
	ldx #2
	jsr WriteFile
	lbcs @Error

	lda FrameNumberStart
	sta FrameNumberCur
	jsr CalcFramePointer	

	lda FramePtr
	sta DATA_PTR
	lda FramePtr HI
	sta DATA_PTR HI

	lda ExportFirstLineNr
	sta ExportCurLineNr
	lda ExportFirstLineNr HI
	sta ExportCurLineNr HI

	; Initialize Link pointer
	SetPointer (__LOADADDR__), LineMem

@ExportLoop:
	lda FrameNumberCur
	sta ExportProgressFrame
	jsr ExportProgress

	bit ExportPretty
	bpl @WritePretty

	; Compressed data is written in a single
	; block.
	ldx FrameNumberEnd
	inx
	txa
	jsr CalcFramePointer	

	lda FramePtr
	sta DATA_PTR_END
	lda FramePtr HI
	sta DATA_PTR_END HI

	dec FrameNumberCur
	jsr WriteMemoryDATA
	jmp @Finalize

@WritePretty:
	SetPointer LineMem, MEMCPY_SRC
	ldy #0
	jsr WriteInfoLine
	bcs @Error

	jsr WritePrettySprite

@NextFrame:
	lda FrameNumberCur
	cmp FrameNumberEnd
	beq @Finalize

	inc FrameNumberCur
	jmp @ExportLoop

@Finalize:
	; Save empty link pointer as end of BASIC
	ldy #0
	lda #0
	AddBasicByte
	AddBasicByte
	SetPointer LineMem, MEMCPY_SRC
	SetPointer (LineMem+2), MEMCPY_TGT
	ldx #2
	jsr WriteFile
	bcs @Error

@Close:
	jsr SaveFileCleanup
	clc
	rts

@Error:
	jsr FileError

@Cancel:
	jsr SaveFileCleanup
	sec
	rts
.endproc

; Write a memory block as data lines
;
; PARAM:
; DATA_PTR
; DATA_PTR_END
; ExportCurLineNr
; ExportStepSize
;
; RETURN:
; C - set on error
.proc WriteMemoryDATA
	lda #$00
	sta BINVal+1

	lda FrameNumberStart
	sta ExportProgressFrame

	lda #SPRITE_BUFFER_LEN
	sta ExportProgressIndex

@WriteLine:
	lda #$00
	sta ExportCurIndex	; End of Line marker
	sta ExportCurByte	; End of buffer marker

	ldy #0
	jsr CalcStringPointer

	jsr IncBasicLineNr

	lda #$83			; DATA
	AddBasicByte
	lda #' '
	AddBasicByte

@WriteDATAValue:
	; Check if we reached the end of the memory
	; we want to save.
	lda DATA_PTR HI
	cmp DATA_PTR_END HI
	bne @NextVal
	lda DATA_PTR
	cmp DATA_PTR_END
	bne @NextVal

	inc ExportCurByte
	jmp @Finalize

@NextVal:
	sty ExportTmp
	ldy #0
	lda (DATA_PTR),y
	inc ExportCurIndex
	ldy ExportTmp
	sta BINVal
	lda #3
	ldx #0
	jsr PrintDecimal
	lda #','
	AddBasicByte

	; Next byte
	clc
	lda DATA_PTR
	adc #1
	sta DATA_PTR
	lda DATA_PTR HI
	adc #0
	sta DATA_PTR HI

	; Increase the frame number here. The progress
	; is called for every written byte, but we write
	; BASIC strings and not sprite bytes so
	; the progress function has no idea which frame
	; we are currently in.
	dec ExportProgressIndex
	bne @Cont

	lda #SPRITE_BUFFER_LEN
	sta ExportProgressIndex

	lda STRING_PTR
	sta ConsolePtrBackup
	lda STRING_PTR HI
	sta ConsolePtrBackup HI

	tya
	pha
	inc FrameNumberCur
	jsr ExportProgress
	pla
	tay

	; Reset our string pointer after the export update
	lda ConsolePtrBackup
	sta STRING_PTR
	lda ConsolePtrBackup HI
	sta STRING_PTR HI

@Cont:
	; Y needs to still allow space for up to three 
	; digits, the comma and the endbyte.
	; Well, if the current byte is only one or two digits
	; it might still fit, but that is to complicated to check.
	cpy #$ff - 3 - 1 - 1
	bcc @WriteDATAValue
	beq @WriteDATAValue

@Finalize:
	; If current line is empty (previous was last byte
	; and ended on a line boundary), we are done.
	lda ExportCurIndex
	beq @Done

	dey		; Remove the last ','
	lda #0
	AddBasicByte

	SetPointer LineMem, MEMCPY_SRC
	jsr CalcLineEnding

	ldx #2
	jsr WriteFile
	bcs @Error

	; Did we reach the end of the buffer?
	lda ExportCurByte
	lbeq @WriteLine

@Done:
	clc

@Error:
	rts
.endproc

; This function is only needed for the compressed
; export. In the pretty printer, we write each
; frame seperately,so we can always update it
; after each frame.
.proc ExportProgress
	SetPointer (INPUT_LINE), STRING_PTR
	ldy #13
	ldx FrameNumberCur
	txa
	ldx FrameNumberEnd
	jsr PrintFrameCounter

	clc
	rts
.endproc

; Create the REM info line and save it.
.proc WriteInfoLine
	lda #0
	sta BINVal+1

@SaveInfoLine:
	jsr IncBasicLineNr

	lda #$8f			; REM
	AddBasicByte
	lda #' '
	AddBasicByte

	ldx #0

@FrameTxtCopy:
	lda FramePETSCIITxt,x
	AddBasicByte
	inx
	cpx #FramePETSCIITxtLen
	bne @FrameTxtCopy

	SetPointer LineMem, STRING_PTR

	; Add current frame number
	ldx FrameNumberCur
	inx					; 1..N
	stx BINVal
	lda #3
	ldx #0
	jsr PrintDecimal

	lda #'/'
	AddBasicByte

	ldx FrameNumberEnd
	inx					; 1..N
	stx BINVal
	lda #3
	ldx #0
	jsr PrintDecimal

	; End of Line marker
	lda #0
	AddBasicByte

	jsr CalcLineEnding

	; ... and save the line.
	ldx #2				; FileNo
	jsr WriteFile

	rts
.endproc

.proc CalcLineEnding
	; y points now beyond the end of line, so we
	; can calculate the link pointer
	tsx
	tya
	pha
	clc
	lda LineMem
	adc $0100,x
	sta LineMem
	lda LineMem HI
	adc #0
	sta LineMem HI

	; Now set the line length end address ...
	clc
	lda MEMCPY_SRC
	adc $0100,x
	sta MEMCPY_TGT
	lda MEMCPY_SRC HI
	adc #$00
	sta MEMCPY_TGT HI
	pla

	rts
.endproc

; Set the current linenumber after the link pointer
; and increase the line nr by STEP size.
;
; RETURN:
; Y - points after line number
;
.proc IncBasicLineNr
	ldy #2				; Skip link pointer for now

	tya
	lda ExportCurLineNr
	AddBasicByte
	lda ExportCurLineNr HI
	AddBasicByte

	; Increase line number by STEP size
	clc
	lda ExportCurLineNr
	adc ExportStepSize
	sta ExportCurLineNr
	lda ExportCurLineNr HI
	adc ExportStepSize HI
	sta ExportCurLineNr HI
	rts
.endproc

; Calculate the current line pointer based on
; y as offset
; 
.proc CalcStringPointer
	tya

	tsx
	pha
	clc
	lda #<LineMem
	adc $0100,x
	sta STRING_PTR
	lda #>LineMem
	adc #$00
	sta STRING_PTR HI
	pla

	rts
.endproc

.proc ExportPrettyFilter
	tay
	lda KeyModifier
	bne @Invalid

	tya
	cmp #$43				; 'C'
	beq @Valid

	cmp #$50				; 'P'
	beq @Valid

@Invalid:
	sec
	rts

@Valid:
	clc
	rts
.endproc

; Library imports
SCANKEYS_BLOCK_IRQ = 1
.include "kbd/keyboard_pressed.s"
.include "kbd/keyboard_released.s"
.include "kbd/keyboard_released_modignore.s"
.include "kbd/keyboard_mapping.s"
.include "kbd/input.s"
.include "kbd/input_number.s"
.include "kbd/number_input_filter.s"
.include "kbd/y_n_input_filter.s"

.include "math/mult16x16.s"

.include "terminal/draw_border.s"

.include "string/printdec.s"
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

; App includes
.include "sprite_editor.s"

; **********************************************
.data
;                            1         2         3         4
;                  0123456789012345678901234567890123456789
VersionTxt: .byte   "SPREDDI V1.00 BY GERHARD GRUBER 2021",0
C64Id:	.byte $14, $0d, $1d, $88

C128Id:	.word $fa80
		.byte $14, $0d, $1d, $88

; Saving/Loading
FilenameDefaultTxt: .byte "spritedata"	; Filename is in PETSCII
FilenameDefaultTxtLen = *-FilenameDefaultTxt

EnterNumberErrorMsg: .byte "VALUE MUST BE IN RANGE "
EnterNumberErrorMsgLen = *-EnterNumberErrorMsg

WelcomeColor: .byte COL_GREEN, COL_RED, COL_WHITE

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
FileExistsTxt: .byte "FILE EXISTS! OVERWRITE? N",0
ExportBasicTxt: .byte "LNR: 1000 STEP:  10 CMPR/PRETTY: C",0

ErrorDeviceNotPresentTxt: .byte "DEVICE NOT PRESENT",0
ErrorDeviceNotPresentTxtLen = (*-ErrorDeviceNotPresentTxt)-1
ErrorFileIOTxt: .byte "FILE I/O ERROR",0
ErrorFileIOTxtLen = (*-ErrorFileIOTxt)-1

CharPreviewTxt: .byte "CHARACTER PREVIEW",0

ColorTxt: .byte "COLOR:",0
ColorTxtLen = *-ColorTxt-1
ColorNameTxt:
	.byte "BLK"
	.byte "WHT"
	.byte "RED"
	.byte "CYN"
	.byte "PRP"
	.byte "GRN"
	.byte "BU1"
	.byte "YLW"
	.byte "ORN"
	.byte "BRN"
	.byte "LRD"
	.byte "DGY"
	.byte "MGY"
	.byte "LGN"
	.byte "BU2"
	.byte "LGY"
	.byte "   "

; The applicaiton data ends here. After that is BSS data which
; does not need to be initialized and will be set to 0 on startup.
;====================================================
.bss

; Functionpointer to the current keyboardhandler
EditorKeyHandler: .word 0
WelcomeDone: .word 0
SystemMode:.byte 0				; C64/C128/M65

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
EditDoubleCursor: .byte 0
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

ExportFirstLineNr: .word 0
ExportCurLineNr: .word 0
ExportLineNr: .word 0
ExportStepSize: .word 0
ExportPretty: .byte 0		; $00 - pretty, $ff - compressed
ExportCurIndex: .byte 0		; Index in framebuffer for export
ExportCurByte: .byte 0		; Number of bytes to export
ExportTmp: .byte 0
ExportProgressIndex: .byte 0
ExportProgressFrame: .byte 0
EnterNumberConsolePtr: .word 0	; Where to print the error message

; Characters to be used for a frame border
LeftBottomRight: .res 8

; Decodiertabelle Intern p.359 $FA80
KeyTableLen = KEY_LINES*8
SymKeytableNormal:		.res KeyTableLen
SymKeytableShift:		.res KeyTableLen
SymKeytableCommodore:	.res KeyTableLen
SymKeytableControl:		.res KeyTableLen
SymKeytableAlt:			.res KeyTableLen

ConsolePtrBackup: .word 0
LineMem: .res BASIC_MAX_LINE_LEN
LineMemLen = SCREEN_COLUMNS

END:
