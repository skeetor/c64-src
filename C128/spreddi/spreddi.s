; Sprite and character editor for C128 with CA65 assembler
; Written by Gerhard W. Gruber in 11.09.2021
;
.include "screenmap.inc"

.include "c128.inc"

COL_BLACK			= 0
COL_WHITE			= 1
COL_RED				= 2
COL_CYAN			= 3
COL_PURPLE			= 4
COL_GREEN			= 5
COL_BLUE			= 6
COL_YELLOW			= 7
COL_ORANGE			= 8
COL_BROWN			= 9
COL_LIGHT_RED		= 10
COL_DARK_GREY		= 11
COL_MEDIUM_GREY		= 12
COL_LIGHT_GREEN		= 13
COL_LIGHT_BLUE		= 14
COL_LIGHT_GREY		= 15

; C128 ROM functions
; ******************

; NMI - $0318 ($fa40) : Vector $fffa : p. 369
; IRQ - $0314 ($fa65) : Vector $fffe : p. 369

; Set bank
;
SETBNK				= $ff68

; Set file parameter
;
; A - Fileno
; X - Device number
; Y - Secondary device number
SETLFS				= $ffba

; Set filename
;
; 

; Load File
;
; X - Lo Start
; Y - Hi Start
LOADSP				= $ffd5

; Save File
;
; A - Zeropage address of the start
; (A) - Lo Start
; (A) - Hi Start
; X - Lo End
; Y - Hi End
SAVESP				= $ffd8

; To be added to cc65
INP_NDX				= $D0
VIC_COLOR_RAM		= $d800

; MMU_CR = Configuration register
; ===============================
; Bit 7 : RAM Bank 2/3 Unused
; Bit 6 : 1 = RAM bank 1, 0 = RAM bank 0
; Bit 5/4 : C000 - FFFF
;           11 = RAM (Bits 7/6)
;           10 = External function ROM
;           01 = Internal function ROM
;           00 = System ROM Kernal
; Bit 3/2 : 8000 - BFFFF
;           11 = RAM (Bits 7/6)
;           10 = External function ROM
;           01 = Internal function ROM
;           00 = System ROM BASIC
; Bit 1   : 4000 - 7FFFF
;           1 = RAM (Bits 7/6)
;           0 = System ROM BASIC
; Bit 0   : D000 - DFFFF
;           1 = RAM / ROM (Bits 5/4)
;           0 = IO
MMU_CR_IO			= $d500 ; Active configuration

; The preconfiguration registers can be written to
; with a desired RAM configuration, but will not 
; change the active configuration. To activate it
; the correspoding MMU_LOAD_CRx register has to be written
; to. It will only then copy its config to MMU_CR.
MMU_PRE_CRA			= $d501
MMU_PRE_CRB			= $d502
MMU_PRE_CRC			= $d503
MMU_PRE_CRD			= $d504

MMU_MODE_CR			= $d505
MMU_RAM_CR			= $d506
MMU_P0_LO			= $d507
MMU_P0_HI			= $d508
MMU_P1_LO			= $d509
MMU_P1_HI			= $d50a
MMU_VERSION_REG		= $d50b

; Load configuration registers. These
; are always available, no matter what
; config has been selected. They can be
; read. Writing to them doesn't change
; them, instead it will load the
; corresponding value from MMU_PRE_CRx
; instead, so the value to be written
; doesn't matter.
MMU_LOAD_CR			= $ff00
MMU_LOAD_CRA		= $ff01
MMU_LOAD_CRB		= $ff02
MMU_LOAD_CRC		= $ff03
MMU_LOAD_CRD		= $ff04

; Disable sprite/SID/lightpen processing during
; regular C128 IRQ processing.
; If set to 0 IRQ is not handling it. If set to 1
; IRQ is currently handling it, which will disable
; further processing.
SPRINT					= $12fd

; Sprite editor constants
; =======================
C128_KEY_LINES 		= 11
SCREEN_VIC			= $0400
SCREEN_COLUMNS		= 40
SCREEN_LINES		= 23
CONSOLE_PTR			= SCREEN_PTR
DATA_PTR			= $55
STRING_PTR			= $55

MEMCPY_SRC			= $53
MEMCPY_TGT			= $55
MEMCPY_LEN			= $57

SPRITE_PTR			= $7f8
SPRITE_PREVIEW		= 0

; Sprites used to highlight the color. For normal sprites
; only COLOR0 is needed. For multicolor sprites we need
; to select the two extra colors as well.
SPRITE_COLOR0		= 1
SPRITE_COLOR1		= 2
SPRITE_COLOR2		= 3

; Position of the color text.
COLOR_TXT_ROW = 12
COLOR_TXT_COLUMN = 27

SPRITE_BASE			= $2000		; Sprite data pointer for first frame.
MAIN_APP_BASE		= $5000		; Address where the main code is relocated to
MAX_FRAMES			= ((MAIN_APP_BASE - SPRITE_BASE)/64)-1 ; The first frame
								; is used for our cursor sprite, so the first
								; user sprite will start at SPRITE_BASE+64

SPRITE_COLOR		= VIC_SPR0_COLOR
SPRITE_EXP_X		= VIC_SPR_EXP_X
SPRITE_EXP_Y		= VIC_SPR_EXP_Y 

; Screen mappings
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

	lda #$00
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

	jsr CreateDebugSprite

	; Enable preview sprite
	lda #(SPRITE_BASE+SPRITE_PREVIEW*64)/64			; Sprite data address
	sta SPRITE_PTR+SPRITE_PREVIEW
	lda #(1 << SPRITE_PREVIEW)
	sta VIC_SPR_ENA		; Enable sprite 0
	lda SpriteColorValue
	sta SPRITE_COLOR+SPRITE_PREVIEW

	jsr SpriteEditor

@KeyLoop:
	jsr WaitKeyboardRelease

@WaitKey:
	jsr ScanKeys
	lda KeyPressed
	beq @WaitKey

	jsr SaveKeys

	ldy #$06			; Check the first 6 Matrixlines
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
	jsr WaitKeyboardRelease
	jsr ClearScreen
	jsr Cleanup

	lda #<SCREEN_VIC
	sta $e0
	lda #>SCREEN_VIC
	sta $e1

	rts
.endproc

.proc Setup

	MAIN_APPLICATION_LEN = (MAIN_APPLICATION_END-MAIN_APPLICATION)

	; Switch to default C128 config
	lda #$00
	sta MMU_CR_IO

	sei

	; Save Zeropage
	ldy #$0f
@ZPSafe:
	lda $50,y
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

	lda #<MAIN_APPLICATION_LEN
	sta MEMCPY_LEN
	lda #>MAIN_APPLICATION_LEN
	sta MEMCPY_LEN+1

	lda #<(MAIN_APPLICATION_LOAD+MAIN_APPLICATION_LEN)
	sta MEMCPY_SRC
	lda #>(MAIN_APPLICATION_LOAD+MAIN_APPLICATION_LEN)
	sta MEMCPY_SRC+1

	lda #<MAIN_APPLICATION_END
	sta MEMCPY_TGT
	lda #>MAIN_APPLICATION_END
	sta MEMCPY_TGT+1
	jsr MemCopyReverse
	lda #$01
	sta RelocationFlag

@SkipRelocation:

	lda	#$00
	sta SPRITE_EXP_X
	sta SPRITE_EXP_Y

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
	ldy #$0f
@ZPRestore:
	lda ZPSafe,y
	sta $50,y
	dey
	bpl @ZPRestore

	; Restore MMU registers
	ldy #$0a

@MMURestore:
	lda MMUConfig,y
	sta MMU_CR_IO,Y
	dey
	bpl @MMURestore

	lda #$00
	sta INP_NDX

	sta MMU_CR

	cli

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

	rts

.endproc

; This data has to be here so we can cleanly exit after
; moving the code.
MMUConfig: .res $0b, 0
ZPSafe: .res $10,0
ScreenCol: .byte $00, $00
RelocationFlag: .byte $00

; Address of the entry stub. This is only the initialization
; part which will move the main application up to $3000 so
; we can use the space of $2000-2ffff for our 64 sprite frames.
; If more frames are needed, we could move it further app
; by increasing MAIN_APP_BASE.
MAIN_APPLICATION_LOAD = *

.org MAIN_APP_BASE
MAIN_APPLICATION = *

; ******************************************
; Sprite Editor
; ******************************************
.proc SpriteEditor

	; Editormatrix screen position
	lda #<(SCREEN_VIC+SCREEN_COLUMNS+1)
	sta CONSOLE_PTR
	lda #>(SCREEN_VIC+SCREEN_COLUMNS+1)
	sta CONSOLE_PTR+1

	lda #<(SPRITE_BASE+(SPRITE_PREVIEW*64))
	sta DATA_PTR
	lda #>(SPRITE_BASE+(SPRITE_PREVIEW*64))
	sta DATA_PTR+1

	lda #3
	sta EditColumnBytes
	lda #21
	sta EditLines
	jsr DrawBitMatrix

	lda #CHAR_SPLIT_TOP
	sta SCREEN_VIC+24+1

	jsr SpritePreviewBorder

	lda #<(SpriteEditorKeyboardHandler-1)
	sta EditorKeyHandler
	lda #>(SpriteEditorKeyboardHandler-1)
	sta EditorKeyHandler+1

	; Print the frame text
	lda #<(SCREEN_VIC+SCREEN_COLUMNS*1)
	sta CONSOLE_PTR
	lda #>(SCREEN_VIC+SCREEN_COLUMNS*1)
	sta CONSOLE_PTR+1

	lda #<SpriteFrameTxt
	sta STRING_PTR
	lda #>SpriteFrameTxt
	sta STRING_PTR+1
	ldy #26
	jsr PrintStringZ

	; Print the max frame text
	lda #<(SCREEN_VIC+SCREEN_COLUMNS*21)
	sta CONSOLE_PTR
	lda #>(SCREEN_VIC+SCREEN_COLUMNS*21)
	sta CONSOLE_PTR+1

	lda #<SpriteFramesMaxTxt
	sta STRING_PTR
	lda #>SpriteFramesMaxTxt
	sta STRING_PTR+1
	ldy #26
	jsr PrintStringZ

	; Print the color choice
	lda #<(SCREEN_VIC+SCREEN_COLUMNS*(COLOR_TXT_ROW+2))
	sta CONSOLE_PTR
	lda #>(SCREEN_VIC+SCREEN_COLUMNS*(COLOR_TXT_ROW+2))
	sta CONSOLE_PTR+1

	lda #<ColorTxt
	sta STRING_PTR
	lda #>ColorTxt
	sta STRING_PTR+1

	ldx #2

@ColorSelection:
	stx $50
	ldy #COLOR_TXT_COLUMN
	jsr PrintStringZ
	ldx $50
	txa
	clc
	adc #'1'
	ldy #COLOR_TXT_COLUMN+5
	sta (CONSOLE_PTR),y
	ldy #COLOR_TXT_COLUMN+8
	lda #81		; Inverse O
	sta (CONSOLE_PTR),y
	jsr PrevLine
	dex
	bpl @ColorSelection

	lda SpriteColorValue
	sta VIC_COLOR_RAM+SCREEN_COLUMNS*COLOR_TXT_ROW+COLOR_TXT_COLUMN+8
	lda SpriteColorValue+1
	sta VIC_COLOR_RAM+SCREEN_COLUMNS*(COLOR_TXT_ROW+1)+COLOR_TXT_COLUMN+8
	lda SpriteColorValue+2
	sta VIC_COLOR_RAM+SCREEN_COLUMNS*(COLOR_TXT_ROW+2)+COLOR_TXT_COLUMN+8

	rts
.endproc

.proc KeyboardTrampolin
	; Virtual function call :)
	lda EditorKeyHandler+1
	pha
	lda EditorKeyHandler
	pha
	rts
.endproc

.proc SpriteEditorKeyboardHandler
	ldx #$02
	lda LastKeyLine,x
	cmp #$80				; X
	beq TogglePreviewX

	ldx #$03
	lda LastKeyLine,x
	cmp #$02				; Y
	beq TogglePreviewY

	ldx #$04
	lda LastKeyLine,x
	cmp #$10				; M
	beq ToggleMulticolor

	ldx #$01
	lda LastKeyLine,x
	cmp	#$01				; 3
	beq IncSpriteColor3

	ldx #$07
	lda LastKeyLine,x
	cmp	#$01				; 1
	beq IncSpriteColor1
	cmp	#$08				; 2
	beq IncSpriteColor2

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
	sta VIC_SPR_MCOLOR
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
	lda #<PREVIEW_POS_BIG
	sta CONSOLE_PTR
	lda #>PREVIEW_POS_BIG
	sta CONSOLE_PTR+1
	lda #SCREEN_COLUMNS
	sta $55
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

	lda #<PREVIEW_POS_BIG
	sta CONSOLE_PTR
	lda #>PREVIEW_POS_BIG
	sta CONSOLE_PTR+1

	lda #6				; Number expanded columns
	jmp @DrawBorder

@NotXExpanded:
	lda #16
	sta VIC_SPR0_X+(SPRITE_PREVIEW*2)

	lda #<PREVIEW_POS_SMALL
	sta CONSOLE_PTR
	lda #>PREVIEW_POS_SMALL
	sta CONSOLE_PTR+1

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

; $f7
.proc TestChar
	lda VIC_SPR_EXP_Y
	and #(1 << SPRITE_PREVIEW)
	beq @YExpanded
	rts

@YExpanded:
	ldx #$00

@l:
	txa
	pha
	jsr WaitKeyboardRelease
	jsr WaitKeyboardPressed
	pla

	pha
	tax

	lda CONSOLE_PTR
	sta KeyLine
	lda CONSOLE_PTR+1
	sta KeyLine+1
	
	lda #<(SCREEN_VIC + 2*SCREEN_COLUMNS)
	sta CONSOLE_PTR
	lda #>(SCREEN_VIC + 2*SCREEN_COLUMNS)
	sta CONSOLE_PTR+1
	txa
	ldy #34
	sta (CONSOLE_PTR),y
	ldy #34+4*SCREEN_COLUMNS
	sta (CONSOLE_PTR),y

	txa
	ldy #31
	jsr PrintHex

	lda KeyLine
	sta CONSOLE_PTR
	lda KeyLine+1
	sta CONSOLE_PTR+1

	pla
	tax

	ldy #$01
	sta (CONSOLE_PTR),Y
	iny
	sta (CONSOLE_PTR),Y
	iny
	sta (CONSOLE_PTR),Y
	dex
	bne @l

	rts
.endproc


; ******************************************
; Character Editor
; ******************************************

.proc CharEditor

	; Editormatrix screen position
	lda #<(SCREEN_VIC+SCREEN_COLUMNS+1)
	sta CONSOLE_PTR
	lda #>(SCREEN_VIC+SCREEN_COLUMNS+1)
	sta CONSOLE_PTR+1

	lda #<SpriteBuffer
	sta DATA_PTR
	lda #>SpriteBuffer
	sta DATA_PTR+1

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

	lda #<SCREEN_VIC
	sta CONSOLE_PTR
	lda #>SCREEN_VIC
	sta CONSOLE_PTR+1
	lda #SCREEN_COLUMNS
	sta $55

	lda #' '
	ldy #SCREEN_COLUMNS
	ldx #25
	jsr FillRectangle

	rts
.endproc

; =================================================
; Draw the border frame. Color has already been set
; and will not change.
;
; ZP Usage:
; CONSOLE_PTR - pointer to screen
; $55 - line counter
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
	lda #<(SCREEN_VIC+SCREEN_COLUMNS)
	sta CONSOLE_PTR
	lda #>(SCREEN_VIC+SCREEN_COLUMNS)
	sta CONSOLE_PTR+1

	; Number of lines - 2 for Border. The last line will be used for character preview
	lda #SCREEN_LINES-2
	sta $55

	ldx #CHAR_VERTICAL

@VLoop:
	txa
	ldy #0
	sta (CONSOLE_PTR),y
	ldy #39
	sta (CONSOLE_PTR),y

	jsr NextLine

	dec $55
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
; CONSOLE_PTR - pointer to the screen position
; DATA_PTR - pointer to the data
; EditColumnBytes - number of columnbytes (1 = 8 columns, 2 = 16 columns, etc.)
; EditLines - number of lines
;
; Locals:
; EditCurChar - Current datavalue
; $57 - Temporary

.proc DrawBitMatrix

@nextLine:
	; Reset the columns
	lda EditColumnBytes
	sta EditCurColumns
	ldy #0

@nextColumn:
	sty $57
	ldy #0
	lda (DATA_PTR),y
	ldy $57
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

	dec EditLines
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

; Fill a memory rectangle with the specified value
;
; PARAMS:
; X - Number of lines
; Y - Number of columns 1 .. 40
; A - character to use
; CONSOLE_PTR - Pointer to top left corner.
; $55 - Line offset
;
; Locals:
; $56/$57 - Helper
;
.proc FillRectangle

	dey
	sty $56
	sta $57

@nextLine:
	sta (CONSOLE_PTR),y
	dey
	bpl @nextLine

	; Advance to next Line
	clc
	lda CONSOLE_PTR
	adc $55
	sta CONSOLE_PTR
	lda CONSOLE_PTR+1
	adc #0
	sta CONSOLE_PTR+1

	ldy $56
	lda $57

	dex
	bne @nextLine

	rts
.endproc

; AC - Character to be printed
; Y - Offset to screen position
; Pointer to screen location in CONSOLE_PTR
.proc PrintHex

	ldx #$02
	pha

	lsr
	lsr
	lsr
	lsr

@PrintChar:
	and #$0f

	cmp #$0a
	bcs @Alpha
	adc #$3a

@Alpha:
	sbc #$09
	sta (CONSOLE_PTR),y
	pla	
	iny
	dex
	bne @PrintChar
	pha

	rts
.endproc

; AC - Character to be printed
; Y - Offset to screen position
; Pointer to screen location in CONSOLE_PTR
.proc PrintBinary
	ldx #$07

@Loop:
	lsr
	pha
	bcs @Print1
	lda #$30
	bne @Print

@Print1:
	lda #$31

@Print:
	sta (CONSOLE_PTR),y
	pla
	iny
	dex
	bpl @Loop

	rts
.endproc

; Wait until no keys are pressed
.proc WaitKeyboardRelease
	jsr ScanKeys
	lda KeyPressed
	bne WaitKeyboardRelease
	rts
.endproc

; Wait until a key is pressed
.proc WaitKeyboardPressed
	jsr ScanKeys
	lda KeyPressed
	beq WaitKeyboardPressed
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

; Read the keyboard 11x8 matrix. For each line the current
; state is stored.
; If any keys are pressed Y contains #$01
.proc ScanKeys

	ldy #$ff			; No Key pressed
	sty KeyPressedLine
	iny
	sty KeyPressed

	; First scan the regular C64 8x8 matrix
	ldx #$07

	sei
	sta VIC_KBD_128	; Disable the extra lines of C128
	lda #%01111111

@NextKey:
	sta $50
	sta CIA1_PRA	; Port A to low
	lda CIA1_PRB	; Read key
	eor #$ff		; Flip bits to make them highactive
	sta KeyLine,x	; Store key per matrixline
	beq @NextLine
	sta KeyPressed
	stx KeyPressedLine
	ldy #$01		; Key pressed flag

@NextLine:
	lda $50
	sec
	ror
	dex
	bpl @NextKey

	; Now scan the 3 extra lines for the extended
	; C128 keys with their own set of lines via VIC.
	ldx #$02
	lda #$ff
	sta CIA1_PRA	; Disable the regular lines
	lda #%11111011

@NextXKey:
	sta $50
	sta VIC_KBD_128	; VIC port to low
	lda CIA1_PRB	; Read key
	eor #$ff		; Flip bits to make them highactive
	sta KeyLine+8,x	; Store key per matrixline
	beq @NextXLine
	sta KeyPressed
	stx KeyPressedLine
	ldy #$01		; Key pressed flag

@NextXLine:
	lda $50
	sec
	ror
	dex
	bpl @NextXKey

@Done:
	cli

	rts
.endproc

; Print a zeroterminated String to the screen.
; PARAMS:
; CONSOLE_PTR - Pointer to screen
; STRING_PTR - Pointer to string
; X - offset to the startposition
;
; RETURN:
; Y contains the number of characters printed
;
; LOCALS:
; $57 - Remember the position in the string
; $58 - Remember the position on screen
;
; Both pointers will not be modified. The string can
; not be longer then 254+1 characters 
; Example: Start can be set to $0400 and Y
; 		to 10 to print the string in the middle
;
.proc PrintStringZ

	STRING_POS			= $57
	STR_CHARINDEX		= $58

	sty STRING_POS
	ldy #$00

@Loop:
	lda (STRING_PTR),y
	bne @Print
	rts

@Print:
	iny
	sty STR_CHARINDEX
	ldy STRING_POS
	sta (CONSOLE_PTR),y
	iny
	sty STRING_POS
	ldy STR_CHARINDEX
	jmp @Loop

.endproc

.proc DetectSystem
	rts
.endproc

.proc CreateDebugSprite
	ldy #3*21
	lda #255

@InitSprite:
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)-1,y
	dey
	bne @InitSprite

	lda #0
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+1
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*20)+1

	lda #$7f
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*7)
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*8)
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*9)
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*10)
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*11)
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*12)
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*13)

	lda #$fe

	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*7)+2
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*8)+2
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*9)+2
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*10)+2
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*11)+2
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*12)+2
	sta SPRITE_BASE+(SPRITE_PREVIEW*64)+(3*13)+2

	rts
.endproc

; **********************************************
.segment "DATA"

.macpack cbm

; Number of lines/bytes to be printed as bits
EditColumnBytes: .byte 0
EditLines: .byte 0

; Temp for drawing the edit box
EditCurChar: .byte 0
EditCurColumns: .byte 0

; Keyboard handling
KeyLine: .res C128_KEY_LINES,$ff
KeyPressed: .byte $ff
KeyPressedLine: .byte $00

LastKeyLine: .res C128_KEY_LINES,$ff
LastKeyPressed: .byte $ff
LastKeyPressedLine: .byte $00

; Funtionpointer to the current keyboardhandler
EditorKeyHandler: .word 0

; Characters to be used for the sprite preview border
; on the bottom line. This depends on the size, because
; we need to use different chars for the expanded vs.
; unexpanded Y size on the bottom line.
LeftBottomRight: .res $03, $00

SpriteFrameTxt: .byte "FRAME:  1/  1",0
SpriteFramesMaxTxt: .byte "# FRAMES:",.sprintf("%3u",MAX_FRAMES),0
CurFrame: .byte $00		; Number of active frame 1..N
ColorTxt: .byte "COLOR :",0
SpriteColorValue: .byte COL_LIGHT_GREY, 1, 2

CharPreviewTxt: .byte "CHARACTER PREVIEW",0

SpriteBuffer: 
	.byte $00, $3c, $0f
	.byte $01, $3c, $0f
	.byte $02, $3c, $0f
	.byte $04, $3c, $0f
	.byte $08, $3c, $0f
	.byte $10, $3c, $0f
	.byte $20, $3c, $0f
	.byte $40, $3c, $0f
	.byte $80, $3c, $0f
	.byte $81, $3c, $0f
	.byte $82, $3c, $0f
	.byte $84, $3c, $0f
	.byte $88, $3c, $0f
	.byte $90, $3c, $0f
	.byte $a0, $3c, $0f
	.byte $c0, $3c, $0f
	.byte $c1, $3c, $0f
	.byte $c2, $3c, $0f
	.byte $c4, $3c, $0f
	.byte $c8, $3c, $0f
	.byte $d0, $3c, $0f
MAIN_APPLICATION_END = *
END:
