;
; c64_screenmap.inc
;
; (c) Copyright 2019, Gerhard W. Gruber (sparhawk@gmx.at)
;
; When using C64 mode, this include converts the characters 
; from PETSCII to screen mapping, so you can write directly to
; the screen memory.
;
; If this include is used, no additional macros are needed

; Char $40 ... $5F -> c - 64
; A-Z

.charmap $40, $00
.charmap $41, $01
.charmap $42, $02
.charmap $43, $03
.charmap $44, $04
.charmap $45, $05
.charmap $46, $06
.charmap $47, $07
.charmap $48, $08
.charmap $49, $09
.charmap $4A, $0A
.charmap $4B, $0B
.charmap $4C, $0C
.charmap $4D, $0D
.charmap $4E, $0E
.charmap $4F, $0F
.charmap $50, $10
.charmap $51, $11
.charmap $52, $12
.charmap $53, $13
.charmap $54, $14
.charmap $55, $15
.charmap $56, $16
.charmap $57, $17
.charmap $58, $18
.charmap $59, $19
.charmap $5A, $1A
.charmap $5B, $1B
.charmap $5C, $1C
.charmap $5D, $1D
.charmap $5E, $1E
.charmap $5F, $1F
