; Sample hello world for C64 with CA65 assembler
; Written by Gerhard W. Gruber in 22.01.2019
;
; Execute with SYS __LOADADDR__
; Default is 49152 ($C000)

.include "c64.inc"

.export __LOADADDR__ = *
.export STARTADDRESS = *

; Here we define the address bytes needed by C64 so it knows where it should load it
; to if loaded with LOAD "PRG",8,1
; I expected that the linker should do this, but it doesn't seem to work, so this is a workaround.

.segment "LOADADDR"
.byte .LOBYTE( __LOADADDR__ ), .HIBYTE( __LOADADDR__ )

.segment "CODE"

main:
    ldx #32             ; max repeats

@mainLoop:
	ldy #$00

@cmpLoop:
    lda BasicPrg,y
    cmp $0801,y
    bne @cmpFailed
    iny
    tya
    cmp #BasicPrgLen
    bne @cmpLoop
    dex
    bne @mainLoop

    lda #'+'
    jmp @Done

@cmpFailed:
    lda #'-'

@Done:
    ldy #0
    sta (SCREEN_PTR),y

    rts

.segment "DATA"

BasicPrg: 

.byte  $12, $08, $0a, $00, $81, $20, $41, $20, $b2, $20, $31, $20, $a4, $20, $34, $30
.byte  $00, $22, $08, $14, $00, $97, $20, $31, $30, $32, $36, $aa, $41, $2c, $38, $31
.byte  $00, $2a, $08, $1e, $00, $82, $20, $41, $00, $00, $00

BasicPrgLen = *-BasicPrg

.byte 0
