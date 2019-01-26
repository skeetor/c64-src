; Sample hello world for C64 with CA65 assembler
; Written by Gerhard W. Gruber in 22.01.2019
;
; Execute with SYS __LOADADDR__
; Default is 49152 ($C000)

.include "screenmap.inc"

SCREEN              = $0400
VIC_BORDERCOLOR     = $D020
VIC_BG_COLOR0       = $D021
VIC_CHAR_COLOR      = $D800

BLACK       = 0
DARK_GREY   = 12

.export __LOADADDR__ = *
.export STARTADDRESS = *

; Here we define the address bytes needed by C64 so it knows where it should load it
; to if loaded with LOAD "PRG",8,1
; I expected that the linker should do this, but it doesn't seem to work, so this is a workaround.

.segment "LOADADDR"
.byte .LOBYTE( __LOADADDR__ ), .HIBYTE( __LOADADDR__ )

.segment "CODE"

main:
    lda #BLACK
    sta VIC_BORDERCOLOR
    sta VIC_BG_COLOR0

    ldy #GreetingsLen
    ldx #DARK_GREY

.ifdef UNDEFINED_SYMBOL
	lda #<Greetings
	ldy #>Greetings
	jsr $ab1e
.endif

@print:
    lda Greetings-1,y
    sta SCREEN-1,y
    txa
    sta VIC_CHAR_COLOR-1,y

    dey
    bne @print

    sta VIC_CHAR_COLOR+40
	lda #'A'
    sta SCREEN+40
	
    rts

.segment "DATA"

Greetings: .byte "ABC abc"
GreetingsLen = *-Greetings

.byte 0
