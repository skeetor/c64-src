; C128 system defines
; Written by Gerhard W. Gruber in 11.09.2021
;

.ifndef C128_SYSTEM_INC
C128_SYSTEM_INC		= 1

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
SETBANK				= $ff68

; Set file parameter
;
; A - Fileno
; X - Device number
; Y - Secondary device number
SETFPAR				= $ffba

; Set filename
;
; A - Namelen
; X - NameAdrLo
; Y - NameAdrHi
SETNAME				= $ffbd

; Load File
;
; X - Lo Start
; Y - Hi Start
LOAD				= $ffd5

; Save File
;
; A - Zeropage address of the startadress
; (A) - Lo Start
; (A+1) - Hi Start
; X - Lo Endadress
; Y - Hi Endadress
SAVE				= $ffd8

; Open logical file
;
; $b8 - logical file number
; $b9 - secondary address
; $b7 - filename length
; $bb/$bc - filename address
; $c7 - bank filename
; These values can also be set using
; SETPAR, SETNAM and SETBANK
OPEN				= $ffc0

; Close logical file
;
; A - logical filenumber
CLOSE				= $ffc3

; Set input filenumber
;
; A - logical filenumber
CHKIN				= $ffc6

; Set output filenumber
;
; A - logical filenumber
CKOUT				= $ffc9

; Clear channel
;
; -
CLRCH				= $ffcc

; Read from current input
;
; -
; Returns the character in A.
BSIN				= $ffcf

; Write to current output
;
; A - byte to write
BSOUT				= $ffd2

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

C128_KEY_LINES 		= 11

.endif		; C128_SYSTEM_INC
