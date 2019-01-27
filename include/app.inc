; Application definition required for the main entry point.
; This should be included in the source which contains the
; applications main entry point. This will take care that
; the final program will have the load address specified by
; the linker.
;
; Applicable for C64, VIC-20, C128, and others.
;
; Written by Gerhard W. Gruber 27.01.2019

.export __LOADADDR__ = *
.export STARTADDRESS = *

; Needs to be included before the main function to receive
; the memory address where the binary must be loaded to.
.segment "LOADADDR"
.byte .LOBYTE( __LOADADDR__ ), .HIBYTE( __LOADADDR__ )

