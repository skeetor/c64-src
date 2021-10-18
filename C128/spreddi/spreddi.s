; Sprite and character editor for C128 with CA65 assembler
; Written by Gerhard W. Gruber in 11.09.2021
;
.macpack cbm

.include "screenmap.inc"

.include "c128_system.inc"
.include "tools/misc.inc"
.include "tools/intrinsics.inc"

; Zeropage variables
ZP_BASE				= $40
ZP_BASE_LEN			= $0f
CONSOLE_PTR			= SCREEN_PTR	; $e0
DATA_PTR			= ZP_BASE+0
STRING_PTR			= ZP_BASE+2
FILE_FRAME			= ZP_BASE+4
LINE_OFFSET			= ZP_BASE+5

MEMCPY_SRC			= ZP_BASE+6
MEMCPY_TGT			= ZP_BASE+8
MEMCPY_LEN			= ZP_BASE+10

KEYTABLE_PTR		= $fb

; Library variables
SKIP_LEADING_ZERO	= TMP_VAL_0
KEY_LINES			= C128_KEY_LINES

; Position of the color text.
COLOR_TXT_ROW = 12
COLOR_TXT_COLUMN = 27

; Sprite editor constants
; =======================
SCREEN_VIC			= $0400
SCREEN_COLUMNS		= 40
SCREEN_LINES		= 23
SPRITE_PTR			= $7f8
SPRITE_PREVIEW		= 0	; Number of the previewsprite
SPRITE_CURSOR		= 1	; Number of the cursor sprite

SPRITE_BUFFER_LEN	= 64
SPRITE_BASE			= $2000		; Sprite data pointer for first frame.
SPRITE_USER_START	= SPRITE_BASE+2*SPRITE_BUFFER_LEN	; First two sprite blocks are reserved
SPRITE_END			= $5000
MAIN_APP_BASE		= SPRITE_END; Address where the main code is relocated to
MAX_FRAMES			= ((MAIN_APP_BASE - SPRITE_USER_START)/SPRITE_BUFFER_LEN) ; The first frame
								; is used for our cursor sprite, so the first
								; user sprite will start at SPRITE_BASE+SPRITE_BUFFER_LEN

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

;TestString: .byte 16, 16
;			.byte "1234567890123456"
;			TESTSTR_LEN = *-(TestString+2)
;			.res TESTSTR_LEN+4, '*'

.proc MainEntry

	jsr Setup

;	lda #'['
;	sta SCREEN_VIC
;	lda #']'
;	sta SCREEN_VIC+17

;	SetPointer (SCREEN_VIC+1), CONSOLE_PTR
;	SetPointer (TestString+2), STRING_PTR

;	ldx TestString
;	ldy TestString+1
;	jsr Input

;	jsr Cleanup
;	rts

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
	lda #(SPRITE_BASE+SPRITE_PREVIEW*SPRITE_BUFFER_LEN)/SPRITE_BUFFER_LEN			; Sprite data address
	sta SPRITE_PTR+SPRITE_PREVIEW
	lda #(1 << SPRITE_PREVIEW)
	sta VIC_SPR_ENA		; Enable sprite 0
	lda SpriteColorValue
	sta SPRITE_COLOR+SPRITE_PREVIEW

	lda #$00
	sta CurFrame
	sta MaxFrame
	jsr SpriteEditor

@KeyLoop:
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

	; We need this only once as we don't
	; do any other multiplication. :)
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
	lda #21
	sta EditLines

	jsr UpdateFrame

	lda #CHAR_SPLIT_TOP
	sta SCREEN_VIC+24+1

	jsr SpritePreviewBorder

	; Print the frame text
	SetPointer (SpriteEditorKeyboardHandler), EditorKeyHandler
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*1), CONSOLE_PTR
	SetPointer FrameTxt, STRING_PTR
	ldy #26
	jsr PrintStringZ

	lda CONSOLE_PTR
	sta STRING_PTR
	lda CONSOLE_PTR+1
	sta STRING_PTR+1
	ldx CurFrame
	inx
	txa
	ldx MaxFrame
	inx
	ldy #26+6
	jsr PrintFrameCounter

	; Print the max frame text
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*21), CONSOLE_PTR
	SetPointer SpriteFramesMaxTxt, STRING_PTR

	ldy #26
	jsr PrintStringZ

	; Print the color choice
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*(COLOR_TXT_ROW+2)), CONSOLE_PTR
	SetPointer ColorTxt, STRING_PTR
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

	jmp (EditorKeyHandler)

.endproc

.proc SpriteEditorKeyboardHandler
	ldx #$00

	inx						; 01
	lda LastKeyLine,x
	cmp	#$01				; 3
	fbeq IncSpriteColor3

	cmp	#$20				; S
	fbeq SaveSprites

	inx						; 02
	lda LastKeyLine,x
	cmp #$80				; X
	beq TogglePreviewX
	cmp #$10				; C
	fbeq ClearSprite

	inx						; 03
	lda LastKeyLine,x
	cmp #$02				; Y
	beq TogglePreviewY

	inx						; 04
	lda LastKeyLine,x
	cmp #$02				; I
	fbeq InvertSprite

	cmp #$10				; M
	beq ToggleMulticolor

	inx						; 05
	lda LastKeyLine,x
	cmp	#$04				; L
	fbeq LoadSprites

	inx						; 06

	inx						; 07
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

	SetPointer PREVIEW_POS_BIG, CONSOLE_PTR
	lda #SCREEN_COLUMNS
	sta LINE_OFFSET
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
	
	SetPointer (SCREEN_VIC + 2*SCREEN_COLUMNS), CONSOLE_PTR
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

	SetPointer SpriteBuffer, DATA_PTR

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
	lda #SCREEN_COLUMNS
	sta LINE_OFFSET

	lda #' '
	ldy #SCREEN_COLUMNS
	ldx #SCREEN_LINES+2
	jsr FillRectangle

	rts
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
; DATA_PTR - pointer to the data
; EditColumnBytes - number of columnbytes (1 = 8 columns, 2 = 16 columns, etc.)
; EditLines - number of lines
;
; Locals:
; CONSOLE_PTR - pointer to the screen position
; EditCurChar - Current datavalue
; TMP_VAL_0 - Temporary

.proc DrawBitMatrix

	; Editormatrix screen position
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS+1), CONSOLE_PTR
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
.proc UpdateFrame

	lda CurFrame
	jsr CalcFramePointer

	lda FramePtr
	sta MEMCPY_SRC
	lda FramePtr+1
	sta MEMCPY_SRC+1

	lda #<(SPRITE_BASE+SPRITE_PREVIEW*SPRITE_BUFFER_LEN)
	sta MEMCPY_TGT
	sta DATA_PTR
	lda #>(SPRITE_BASE+SPRITE_PREVIEW*SPRITE_BUFFER_LEN)
	sta MEMCPY_TGT+1
	sta DATA_PTR+1
	jsr CopyFrame

	jmp DrawBitMatrix
.endproc

; Copy a sprite frame from MEMCPY_SRC to MEMCPY_TGT.
.proc CopyFrame
	ldy #SPRITE_BUFFER_LEN-1

@Loop:
	lda (MEMCPY_SRC),y
	sta (MEMCPY_TGT),y
	dey
	bpl @Loop

	rts
.endproc

; Calculate the sprite buffer address for the specified frame.
; Result is stored in FramePtr.
;
; A - framenumber 0..MAX_FRAMES-1
;
.proc CalcFramePointer

	sta Multiplicand
	lda #$00
	sta Multiplicand+1
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

; Clear the preview sprite buffer
.proc ClearSprite

	SetPointer (SPRITE_BASE+SPRITE_PREVIEW*SPRITE_BUFFER_LEN), DATA_PTR
	lda #$00
	ldy #SPRITE_BUFFER_LEN-1

@Loop:
	sta (DATA_PTR),y
	dey
	bpl @Loop

	jmp DrawBitMatrix

.endproc

; Invert the preview sprite buffer
.proc InvertSprite

	SetPointer (SPRITE_BASE+SPRITE_PREVIEW*SPRITE_BUFFER_LEN), DATA_PTR
	ldy #SPRITE_BUFFER_LEN-1

@Loop:
	lda (DATA_PTR),y
	eor #$ff
	sta (DATA_PTR),y
	dey
	bpl @Loop

	jmp DrawBitMatrix

.endproc

; Fill a memory rectangle with the specified value
;
; PARAMS:
; X - Number of lines
; Y - Number of columns 1 .. 40
; A - character to use
; CONSOLE_PTR - Pointer to top left corner.
; LINE_OFFSET - Line offset
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
	adc LINE_OFFSET
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

.proc ClearStatusLine
	ldy #79
	lda #' '

:	sta SCREEN_VIC+SCREEN_COLUMNS*23,y
	dey
	bne :-
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

; Create a sprite shape which makes the border edges better visible.
.proc CreateDebugSprite
	;DEBUG_SPRITE_PTR = SPRITE_BASE+(SPRITE_PREVIEW*SPRITE_BUFFER_LEN)
	DEBUG_SPRITE_PTR = SPRITE_USER_START+(0*SPRITE_BUFFER_LEN)

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

.proc SaveSprites

	; TODO: DEBUG
	lda #$00
	sta FileFrameStart
	lda #MAX_FRAMES-1
	sta FileFrameEnd
	; TODO: END DEBUG

	jsr WaitKeyboardRelease
	jsr GetSpriteSaveInfo
	fbeq @Cancel

	SetPointer OpenFileTxt, STRING_PTR
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*23), CONSOLE_PTR
	ldy #$00
	jsr PrintStringZ

	; Enable kernel for our saving calls
	lda #$00
	sta FARCALL_MEMCFG

	; Prepare filename by appending 
	; ',S,W' to open a SEQ file for writing
	lda #','
	sta FilenameMode
	lda #'w'
	sta FilenameMode+1

	; File set parameters
	lda #2				; Fileno
	ldx DiskDrive		; Device
	ldy #5				; secondary address
	jsr SETFPAR

	lda #0				; RAM bank to load file
	ldx #0				; RAM bank of filename
	jsr SETBANK

	lda FilenameLen
	ldx #<(Filename)
	ldy #>(Filename)
	jsr SETNAME

	; Open the file
	SetPointer OPEN, FARCALL_PTR
	jsr FARCALL
	lda STATUS
	beq :+
	jmp @FileError

	; Switch output to our file
:	SetPointer CKOUT, FARCALL_PTR
	ldx #2
	jsr FARCALL
	lda STATUS
	beq :+
	jmp @FileError

	; print WRITING ...
:	SetPointer WritingTxt, STRING_PTR
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
	sta FILE_FRAME

	; Write a single character to disk
	SetPointer BSOUT, FARCALL_PTR
	ldy #19

	; Write a single sprite buffer
@NextFrame:
	ldx FILE_FRAME
	inx
	tax
	ldx FileFrameEnd
	inx
	ldy #14
	jsr PrintFrameCounter
	ldy #$00		; Current byte of the sprite
	sty FilePosY

@WriteFrame:
	lda (DATA_PTR),y
	inc FilePosY
	jsr FARCALL
	lda STATUS
	bne @FileError
	ldy FilePosY
	cpy #SPRITE_BUFFER_LEN				; Size of a sprite block
	bne	@WriteFrame

	ldy FILE_FRAME
	iny
	sty FILE_FRAME
	cpy FileFrameEnd
	beq @Done

	clc
	lda DATA_PTR
	adc #SPRITE_BUFFER_LEN
	sta DATA_PTR
	lda DATA_PTR+1
	adc #$00
	sta DATA_PTR+1
	jmp @NextFrame

@Done:
	ldx FILE_FRAME
	inx
	tax
	ldx FileFrameEnd
	inx
	ldy #14
	jsr PrintFrameCounter

	; Clear output and reset to STDIN
	; before closing
	SetPointer CLRCH, FARCALL_PTR
	jsr FARCALL

	; Well, it's evident. :)
	SetPointer CLOSE, FARCALL_PTR
	lda #2
	jsr FARCALL

	SetPointer DoneTxt, STRING_PTR
	ldy #$00
	jsr PrintStringZ
	jsr Delay
	jsr ClearStatusLine

	rts

@FileError:
	rts

@Cancel:
	jsr ClearStatusLine

	; Print cancel text in status line
	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*23), CONSOLE_PTR
	SetPointer CanceledTxt, STRING_PTR
	ldy #0
	jsr PrintStringZ

	; Show the status line for a small period of time
	jsr Delay

	jsr ClearStatusLine

	rts
.endproc

; Print the frame counters N/M
; STRING_PTR - point to start of the first digit.
; A - First frame
; X - Last frame
; Y - offset in line
;
; Locals:
; TMP_VAL_0
; TMP_VAL_1
.proc PrintFrameCounter

	stx TMP_VAL_2		; Save max frames
	sty TMP_VAL_3		; and y position in string

	sta BINVal			; First print the CurFrame value
	lda #$00
	sta BINVal+1
	jsr BinToBCD16
	lda #$01			; Skip the first digit otherwise it would be 4
	tax					; We only need 3 digits
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
	jsr BCDToString

	rts
.endproc

.proc GetSpriteSaveInfo

	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*23), CONSOLE_PTR
	SetPointer SaveTxt, STRING_PTR
	ldy #0
	jsr PrintStringZ

	SetPointer FrameTxt, STRING_PTR
	jsr PrintStringZ

	SetPointer (SCREEN_VIC+SCREEN_COLUMNS*23+11), CONSOLE_PTR
	lda #1
	ldx MaxFrame
	ldy #10					; "SAVE FRAME:"
	jsr PrintFrameCounter

	SetPointer NumberInputFilter, InputFilterPtr
	ldx #0
	ldy #3
	jsr Input
	cmp #$00
	beq @Cancel

	SetPointer DefaultInputFilter, InputFilterPtr

	lda #$01
	rts

@Cancel:
	lda #$00
	rts
.endproc

.proc EnterFilename
	rts
.endproc

.proc LoadSprites

	lda #0			; Fileno
	ldx DiskDrive	; Device
	ldy #0			; Load with address (1 = loadadress is in file)
	jsr SETFPAR

	lda FilenameLen
	ldx #<(Filename)
	ldy #>(Filename)
	jsr SETNAME

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
.include "string/printstringz.s"
.include "string/printhex.s"

; **********************************************
.segment "DATA"

TMP_VAL_0: .word 0
TMP_VAL_1: .word 0
TMP_VAL_2: .word 0
TMP_VAL_3: .word 0

; Number of lines/bytes to be printed as bits
EditColumnBytes: .byte 0
EditLines: .byte 0

; Temp for drawing the edit box
EditCurChar: .byte 0
EditCurColumns: .byte 0
EditCurLine: .byte 0

; Keyboard handling
LastKeyLine: .res KEY_LINES, $ff
LastKeyPressed: .byte $ff
LastKeyPressedLine: .byte $00

; Saving/Loading
DiskDrive: .byte 8
FilenameLen: .byte 0
Filename: .res 16,0
FilenameMode: .byte 0,0,0,0
FileFrameStart: .byte 1		; first frame to save
FileFrameEnd: .byte 0		; last frame to save

; Temp for storing the current index in the spritebuffer
; while loading/saving.
FilePosY: .byte 0

; Functionpointer to the current keyboardhandler
EditorKeyHandler: .word 0

; Characters to be used for the sprite preview border
; on the bottom line. This depends on the size, because
; we need to use different chars for the expanded vs.
; unexpanded Y size on the bottom line.
LeftBottomRight: .res $03, $00

FramePtr: .word 0	; Address for current frame pointer
FrameTxt: .byte "FRAME:  1/  1",0
SpriteFramesMaxTxt: .byte "# FRAMES:",.sprintf("%3u",MAX_FRAMES),0
CurFrame: .byte $00		; Number of active frame 1..N
MaxFrame: .byte $00		; Maximum frame number in use 0..MAX_FRAMES-1
ColorTxt: .byte "COLOR :",0
SpriteColorValue: .byte COL_LIGHT_GREY, 1, 2

; User string to save from/to (inclusive) frame
FirstFrameStr:	.byte 0, 3, 0, 0, 0
LastFrameStr:	.byte 0, 3, 0, 0, 0
FilenameStr:	.byte 0, 16
				.res 16

CanceledTxt:	.byte "           OPERATION CANCELED           ",0
SaveTxt:		.byte "SAVE ",0
OpenFileTxt:	.byte "OPEN FILE: ",0
WritingTxt:		.byte "WRITING ",0
LoadingTxt:		.byte "READING ",0
DoneTxt:		.byte "DONE                                    ",0

CharPreviewTxt: .byte "CHARACTER PREVIEW",0

; TODO: Just for early debugging. Can be removed
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

KeyTableLen = KEY_LINES*8
KeyTables = *
SymKeytableNormal		= KeyTables
SymKeytableShift		= KeyTables + KeyTableLen
SymKeytableCommodore 	= KeyTables + (KeyTableLen*2)
SymKeytableControl		= KeyTables + (KeyTableLen*3)
SymKeytableAlt 			= KeyTables + (KeyTableLen*4)

MAIN_APPLICATION_END = *
END:
