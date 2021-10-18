; Sprite and character editor for C128 with CA65 assembler
; Written by Gerhard W. Gruber in 11.09.2021
;

.include "screenmap.inc"

.include "c128_system.inc"

C128_MODE			= %01
C64_MODE			= %10
KEY_LINES			= C128_KEY_LINES

SCREEN_LINES		= 25
TEXT_LINES			= 25
SCREEN_COLUMNS		= 40

CONSOLE_PTR			= SCREEN_PTR
STRING_PTR			= $50
SCREEN_VIC			= $0400

.export __LOADADDR__ = *
.export STARTADDRESS = *

.segment "LOADADDR"
.byte .LOBYTE( __LOADADDR__ ), .HIBYTE( __LOADADDR__ )

.segment "CODE"

_EntryPoint = MainEntry

basicstub:
.word @BASIC20	; Pointer to line 20
.word 10 ; line number
.byte $8f ;REM
; Note! This must be lowercase, so it is converted properly to the BASIC characters!
.byte " to run this on a c64 you *must*  use *load",$22,"name",$22,",8* and not use *,8,1*!!!"
.byte 0

@BASIC20:
.word @BASIC_END
.word 20 ; line number
.byte $9e ;SYS
.byte ' '

;.byte <(((_EntryPoint / 10000) .mod 10) + $30)
.byte <(((_EntryPoint / 1000)  .mod 10) + $30)
.byte <(((_EntryPoint / 100 )  .mod 10) + $30)
.byte <(((_EntryPoint / 10 )   .mod 10) + $30)
.byte <((_EntryPoint           .mod 10) + $30)
.byte 0 ;end of line

@BASIC_END:
.word 0 ;empty line == end pf BASIC

MainEntry:
	lda VIC_BORDERCOLOR
	sta ScreenCol
	lda VIC_BG_COLOR0
	sta ScreenCol+1

	lda #COL_BLACK
	sta VIC_BORDERCOLOR
	sta VIC_BG_COLOR0

	ldy #$0f
@ZPSafe:
	lda $50,y
	sta ZPSafe,y
	dey
	bpl @ZPSafe

	lda #COL_GREEN
	jsr SetBackgroundColor
	jsr ClearScreen

	jsr PrintKeys
	jmp @MainLoop

@WaitKey:
	jsr ScanKeys
	cpy #$01			; Any key pressed?
	bne @MainLoop		; Nope

	; Check for RUN/STOP-Q
	ldx #$07			; RUN/STOP and Q are both in matrixline 7
	lda KeyLine,x
	tay
	and #%10000000		; RUN/STOP key pressed?
	beq @MainLoop

	tya
	and #%01000000		; Q Key pressed?
	beq @MainLoop
	jmp @Done

@MainLoop:
	ldx #$00
	stx TextLine

	lda #<(SCREEN_VIC + SCREEN_COLUMNS)
	sta CONSOLE_PTR
	lda #>(SCREEN_VIC + SCREEN_COLUMNS)
	sta CONSOLE_PTR+1

@NextLine:
	ldx TextLine
	cpx #C128_KEY_LINES
	beq @WaitKey

	inc TextLine

	txa
	pha
	lda KeyLine,x
	ldy #38
	jsr PrintHex

	pla
	tax
	lda KeyLine,x
	ldx #$08		; Number of bits to print
	ldy #$07		; Character offset

@NextBit:
	asl
	pha
	lda #'0'
	adc #$00
	sta (CONSOLE_PTR),y
	tya
	clc
	adc #4
	tay
	pla
	dex
	bne @NextBit

	jsr NextLine
	jsr NextLine

	ldx TextLine
	cpx #$08
	bne @Cont

	jsr NextLine

@Cont:
	jmp @NextLine

@Done:
	lda ScreenCol
	sta VIC_BORDERCOLOR
	lda ScreenCol+1
	sta VIC_BG_COLOR0

	ldy #$0f
@ZPRestore:
	lda ZPSafe,y
	sta $50,y
	dey
	bpl @ZPRestore

	jsr ClearScreen

	lda #$00
	sta INP_NDX

	rts

; Print the list of keys from the table to the screen
.proc PrintKeys

	jsr KeyColor

	lda #' '
	sta LineNrTxt+1
	lda #'0'
	sta LineNrTxt+2

	lda #<SCREEN_VIC
	sta CONSOLE_PTR
	lda #>SCREEN_VIC
	sta CONSOLE_PTR+1

	lda #<Line00
	sta STRING_PTR
	lda #>Line00
	sta STRING_PTR+1

	lda #$00
	sta ShowLineTxt
	sta TextLine

@NextString:

	; The last two lines are just messages
	cmp #23
	bcs @StartOfLine		; >=

	; Skip the C128 info line
	cmp #16
	bne @MatrixLine

@StartOfLine:
	lda #$01
	sta ShowLineTxt
	ldy #$00
	jmp @PrintLine

@MatrixLine:
	ldy #$04

@PrintLine:
	jsr PrintStringZ

	; Switch to next line string
	iny		; Skip 0-Byte
	tya
	clc
	adc STRING_PTR
	pha
	lda STRING_PTR+1
	adc #$00
	pha

	; Next line, as the matrix line number
	; is printed below each character line
	jsr NextLine

	lda ShowLineTxt
	eor #$01
	sta ShowLineTxt
	beq @NextLineNr

	; Print the matrixline
	lda #<LineNrTxt
	sta STRING_PTR
	lda #>LineNrTxt
	sta STRING_PTR+1
	ldy #$00
	jsr PrintStringZ

	inc LineNrTxt+2
	lda LineNrTxt+2
	cmp #'9'+1
	bne @NextLineNr

	ldx #'1'
	stx LineNrTxt+1 
	dex
	stx LineNrTxt+2

@NextLineNr:
	pla
	sta STRING_PTR+1
	pla
	sta STRING_PTR

	inc TextLine
	lda TextLine
	cmp #TEXT_LINES
	bne @NextString

	jsr PrevLine
	jsr PrevLine

@ShowSystemMode:
	lda SystemMode
	cmp	#C128_MODE|C64_MODE
	beq @C64OnC128
	cmp #C64_MODE
	beq @C64Mode

	lda #<C128Txt
	sta STRING_PTR
	lda #>C128Txt
	sta STRING_PTR+1
	ldy #SCREEN_COLUMNS-1-4
	bne @Cont

@C64Mode:
	lda #<C64Txt
	sta STRING_PTR
	lda #>C64Txt
	sta STRING_PTR+1
	ldy #SCREEN_COLUMNS-1-3
	bne @Cont

@C64OnC128:
	lda #<C64ModeTxt
	sta STRING_PTR
	lda #>C64ModeTxt
	sta STRING_PTR+1
	ldy #SCREEN_COLUMNS-1-8

@Cont:
	jsr PrintStringZ

	; We have to cheat with this character, because the
	; 0-byte can not be printed with
	lda #$00
	sta SCREEN_VIC+10*SCREEN_COLUMNS+11

	rts
.endproc

.proc ClearScreen

	lda #<SCREEN_VIC
	sta CONSOLE_PTR
	lda #>SCREEN_VIC
	sta CONSOLE_PTR+1
	lda #SCREEN_COLUMNS
	sta $55

	lda #' '
	ldy #SCREEN_COLUMNS
	ldx #SCREEN_LINES
	jsr FillRectangle

	rts
.endproc

.proc KeyColor

	lda #<(VIC_COLOR_RAM+SCREEN_COLUMNS)
	sta $53
	lda #>(VIC_COLOR_RAM+SCREEN_COLUMNS)
	sta $54

	lda #COL_LIGHT_GREY
	ldy #SCREEN_COLUMNS-1
	ldx #C128_KEY_LINES

@Loop:
	sta ($53),y
	dey
	bpl @Loop

	dex
	beq @Done

	clc
	lda #SCREEN_COLUMNS
	adc $53
	sta $53
	lda $54
	adc #$00
	sta $54

@SkipLine:
	clc
	lda #SCREEN_COLUMNS
	adc $53
	sta $53
	lda $54
	adc #$00
	sta $54

	cpx #$03
	bne @Cont

	; Skip the info line
	clc
	lda #SCREEN_COLUMNS
	adc $53
	sta $53
	lda $54
	adc #$00
	sta $54

@Cont:
	lda #COL_LIGHT_GREY
	ldy #SCREEN_COLUMNS-1
	jmp @Loop

@Done:
	rts
.endproc

; Fill a memory rectangle with the specified value
;
; PARAMS:
; X - Number of lines
; Y - Number of columns 1 .. SCREEN_COLUMNS
; A - character to use
; CONSOLE_PTR - Pointer to top left corner.
; $55 - Line offset
;
; Locals:
; $56/$57 - Helper
;
.proc FillRectangle

	sty $56
	sta $57

@nextLine:
	sta (CONSOLE_PTR),y
	dey
	bne @nextLine

	; Advance to next Line
	clc
	lda $55
	adc CONSOLE_PTR
	sta CONSOLE_PTR
	lda #0
	adc CONSOLE_PTR+1
	sta CONSOLE_PTR+1

	ldy $56
	lda $57

	dex
	bne @nextLine

	rts
.endproc

.proc NextLine
	lda #SCREEN_COLUMNS
	clc
	adc CONSOLE_PTR
	sta CONSOLE_PTR

	lda #0
	adc	CONSOLE_PTR+1
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

SCANKEYS_BLOCK_IRQ = 1

.include "kbd/scankeys.s"
.include "string/printhex.s"
.include "string/printbin.s"
.include "string/printstringz.s"

.proc DetectSystem
	rts
.endproc

.segment "DATA"

.macpack cbm

ScreenCol: .byte 0,0
LineNrTxt: .byte 'L',0,0,':',0
TextLine: .byte 0
ShowLineTxt: .byte 0

C64Txt: .byte " C64",0
C128Txt: .byte " C128",0
C64ModeTxt: .byte " C128/C64",0
SystemMode: .byte C128_MODE
ZPSafe: .res $10,0

Line00: .byte "CRSD  F5  F3  F1  F7CRSL  CR DEL",0
		.byte "   0   0   0   0   0   0   0   0",0
Line01: .byte " SHL   E   S   Z   4   A   W   3",0
		.byte "   0   0   0   0   0   0   0   0",0
Line02: .byte "   X   T   F   C   6   D   R   5",0
		.byte "   0   0   0   0   0   0   0   0",0
Line03: .byte "   V   U   H   B   8   G   Y   7",0
		.byte "   0   0   0   0   0   0   0   0",0
Line04: .byte "   N   O   K   M   0   J   I   9",0
		.byte "   0   0   0   0   0   0   0   0",0
Line05: .byte "   ,       :   .   -   L   P   +",0
		.byte "   0   0   0   0   0   0   0   0",0
Line06: .byte "   /   ",30,"   = SHR HOM   ;   *   ",28,0
		.byte "   0   0   0   0   0   0   0   0",0
Line07: .byte " RUN   Q  C= SPC   2 CTL   ",31,"   1",0
		.byte "   0   0   0   0   0   0   0   0",0
		.byte "----====<* C128 EXTENDED KEYS *>====----",0
Line08: .byte "  #1  #7  #4  #2 TAB  #5  #8 HLP",0
		.byte "   0   0   0   0   0   0   0   0",0
Line09: .byte "  #3  #9  #6 #CR  LF  #-  #+ ESC",0
		.byte "   0   0   0   0   0   0   0   0",0
Line10: .byte "NOSC CSR CSL CSD CSU  #.  #0 ALT",0
		.byte "   0   0   0   0   0   0   0   0",0
		.byte "---- WRITTEN BY SPARHAWK ---------------",0
		.byte "     PRESS RUN-STOP+Q TO EXIT",0

PROGRAM_LEN = *-basicstub

; If this is to be used only on a C128, everything below can be removed
; as this drastically reduces the size of the program.
;
; This is a NOP sled, so we can load it on the C64 and RUN it from BASIC
; without any changes.
.res 4096,$ea

; This code is only used when running on a C64 (either real or under 128).
	SRC_PTR		= $53
	TGT_PTR		= $55
	SIZE_VAL	= $57

	; offset between C64 and C128 BASIC
	PRG_DISTANCE	= $1c01-$0801

; This part may not contain any references to lables, as we don't know where it
; will be located in memory exactly. Whenever the above code changes, it may move
; to some different place.

	; First we have to move the code from the C64 BASIC start $0801
	; to the C128 BASIC start $1c01. The code doesn't need to be relocated
	; because it was already compiled for that start address.
	; Since we can not risk to overwrite the current running code, we
	; have to copy this from some save location $c000.

	lda #<(@CopyReverse-PRG_DISTANCE)
	sta SRC_PTR
	lda #>(@CopyReverse-PRG_DISTANCE)
	sta SRC_PTR+1

	ldy #COPY_LEN

@CopyCopy:
	lda (SRC_PTR),y
	sta $c000,y
	dey
	bpl @CopyCopy

	lda #<($0801+PROGRAM_LEN)
	sta SRC_PTR
	lda #>($0801+PROGRAM_LEN)
	sta SRC_PTR+1

	lda #<($1c01+PROGRAM_LEN)
	sta TGT_PTR
	lda #>($1c01+PROGRAM_LEN)
	sta TGT_PTR+1

	lda #<PROGRAM_LEN
	sta SIZE_VAL
	lda #>PROGRAM_LEN
	sta SIZE_VAL+1

	; We have to do the copy in reverse order, so we wont overwrite
	; the later parts as the blocks may overlap.

	; Could be better optimized, but here it's not critical.
	ldy #$00
	jmp $c000

@CopyReverse:
	sec
	lda SRC_PTR
	sbc #$01
	sta SRC_PTR
	lda SRC_PTR+1
	sbc #$00
	sta SRC_PTR+1

	sec
	lda TGT_PTR
	sbc #$01
	sta TGT_PTR
	lda TGT_PTR+1
	sbc #$00
	sta TGT_PTR+1

	lda (SRC_PTR),y
	sta (TGT_PTR),y

	dec SIZE_VAL
	bne @CopyReverse

	dec SIZE_VAL+1
	bpl @CopyReverse

	; here we have copied to the correct address, so we
	; can now reference labels again.

	lda #$00
	sta VIC_KBD_128
	lda VIC_KBD_128
	ldy #C64_MODE
	cmp #$ff
	beq @StoreMode
	iny

@StoreMode:
	sty SystemMode

	jmp MainEntry

COPY_LEN	= *-@CopyReverse
