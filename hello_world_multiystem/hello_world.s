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

.endif

; Default is C64 mode

.ifndef SCREEN_PTR

.out "Building C64 variant"

.include "c64.inc"

CLRSCR				= $e544

.endif

.export __LOADADDR__ = *
.export STARTADDRESS = *

; Here we define the address bytes needed by C64 so it knows where it should load it
; to if loaded with LOAD "PRG",8,1
; I expected that the linker should do this, but it doesn't seem to work, so this is a workaround.

.segment "LOADADDR"
.byte .LOBYTE( __LOADADDR__ ), .HIBYTE( __LOADADDR__ )

.segment "CODE"

main:

	jsr	CLRSCR

	lda SCREEN_PTR
	sta @screenWrite1+1
	sta @screenWrite2+1
	
	lda SCREEN_PTR+1
	sta @screenWrite1+2
	sta @screenWrite2+2
	
    ldy #GreetingsLen

@print:
    lda Greetings-1,y

@screenWrite1:

    sta $0400-1,y

    dey
    bne @print

	lda #'A'
	
@screenWrite2:

    sta $0400
	
    rts

.segment "DATA"

Greetings: .byte "---===<* GREETINGS *>===---"
GreetingsLen = *-Greetings
