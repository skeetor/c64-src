; Sample hello world for C128 with CA65 assembler
; Written by Gerhard W. Gruber in 10.09.2021
;
; Execute with SYS __LOADADDR__

.include "screenmap.inc"

.include "c64.inc"

SCREEN_VIC			= $0400
BORDER_COLOR		= $d020

VDC_DSP_START_HI	= 12
VDC_DSP_START_LO	= 13
VDC_DSP_CRSR_HI		= 14
VDC_DSP_CRSR_LO		= 15
VDC_DSP_UPDATE_HI	= 18
VDC_DSP_UPDATE_LO	= 19
VDC_DSP_ATTRMEM_HI	= 20
VDC_DSP_ATTRMEM_LO	= 21
VDC_WORD_COUNT		= 30
VDC_DATA_REG		= 31

.export __LOADADDR__ = *
.export STARTADDRESS = *

.segment "LOADADDR"
.byte .LOBYTE( __LOADADDR__ ), .HIBYTE( __LOADADDR__ )

.segment "CODE"

_EntryPoint = MainEntry

basicstub:
.word @nextline
.word 10 ; line number
.byte $9e ;SYS

.byte <(((_EntryPoint / 10000) .mod 10) + $30)
.byte <(((_EntryPoint / 1000)  .mod 10) + $30)
.byte <(((_EntryPoint / 100 )  .mod 10) + $30)
.byte <(((_EntryPoint / 10 )   .mod 10) + $30)
.byte <((_EntryPoint           .mod 10) + $30)
.byte 0 ;end of line

@nextline:
.word 0 ;empty line == end pf BASIC

MainEntry:
	lda #0
	sta BORDER_COLOR

	jsr	ClearScreenVIC
	jsr HelloWorldVIC

	jsr HelloWorldVDC

	rts

HelloWorldVIC:
    ldy #GreetingsLen

@print:
    lda Greetings-1,y

@screenWrite1:

    sta SCREEN_VIC,y

    dey
    bne @print

    rts

ClearScreenVIC:
	lda #' '
	
FillScreenVIC:
	ldy #0

@fillLoop:
	sta SCREEN_VIC,y
	sta SCREEN_VIC+256,y
	sta SCREEN_VIC+512,y
	sta SCREEN_VIC+768-24,y

	dey
	bne	@fillLoop

	rts


VDCSync:
	bit	VDC_INDEX
	bpl	VDCSync
	rts

HelloWorldVDC:

	lda	#VDC_DSP_START_HI
	sta VDC_INDEX
	lda #0
	sta	VDC_DATA
	jsr	VDCSync

	lda	#VDC_DSP_START_LO
	sta VDC_INDEX
	lda #0
	sta	VDC_DATA
	jsr	VDCSync

	lda	#VDC_DSP_UPDATE_HI
	sta VDC_INDEX
	lda #0
	sta	VDC_DATA
	jsr	VDCSync

	ldy #GreetingsLen

@PrintLoop:
	lda	#VDC_DSP_UPDATE_LO
	sta VDC_INDEX
	sty	VDC_DATA
	jsr	VDCSync

	lda	#VDC_DATA_REG
	sta VDC_INDEX
	lda Greetings-1,y
	sta	VDC_DATA
	jsr	VDCSync

	lda	#VDC_WORD_COUNT
	sta VDC_INDEX
	lda #1
	sta	VDC_DATA
	jsr	VDCSync

	dey
	bne	@PrintLoop

	rts

.segment "DATA"

.macpack cbm

Greetings: .byte "---===<* GREETINGS *>===---"
GreetingsLen = *-Greetings
