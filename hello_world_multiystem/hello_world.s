; Sample hello world for C64 with CA65 assembler
; Written by Gerhard W. Gruber in 22.01.2019
;
; Execute with SYS __LOADADDR__
; Default is 49152 ($C000)

.include "c64_screenmap.inc"

.ifdef VC20

.out "Building VC20 variant"

.include "vic20.inc"

CLRSCR				= $e55f
BORDER_COLOR		= $900f

.endif

; Default is C64 mode

.ifndef SCREEN_PTR

.out "Building C64 variant"

.include "c64.inc"

CLRSCR				= $e544
BORDER_COLOR		= $d020

.endif

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

	jsr	CLRSCR

	ldy SCREEN_PTR
	dey
	tya
	sta @screenWrite1+1
	
	ldy SCREEN_PTR+1
	dey
	tya
	sta @screenWrite1+2
	
    ldy #GreetingsLen

@print:
    lda Greetings-1,y

@screenWrite1:

    sta $0000,y

    dey
    bne @print

    rts

.segment "DATA"

.macpack cbm

Greetings: .byte "---===<* GREETINGS *>===---"
GreetingsLen = *-Greetings
