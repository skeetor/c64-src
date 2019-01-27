; C64 Kernel functions
;
; Written by Gerhard W. Gruber 27.01.2019


BANK_FULL_RAM                   %00				; RAM visible in  all three areas
BANK_BASIC_KERNEL_RAM           %01				; RAM visible at $A000-$BFFF and $E000-$FFFF
BANK_BASIC_RAM                  %10				; RAM visible at $A000-$BFFF; KERNAL ROM visible at $E000-$FFFF.
BANK_BASIC_KERNEL_RAM           %11				; BASIC ROM visible at $A000-$BFFF; KERNAL ROM visible at $E000-$FFFF.
BANK_CHAR_IO_FLAG               4				; 0 = Character ROM visible at $D000-$DFFF. (Except for the value BANK_FULL_RAM)
BANK_RAM_MASK                   7				; Bits 0-2 masking the RAM bank state

; Default address of screen memory
SCREEN_MEM						= $0400

BASIC_ROM_START					= $a000
BASIC_ROM_END					= $bfff

CHARACTER_ROM					= $d000

KERNEL_ROM_START				= $e000
KERNEL_ROM_END					= $ffff

NMI_SERVICE_VECTOR				= $fffa      ; LO-btye
COLD_RESET_SERVICE_VECTOR		= $fffc      ; LO-byte
IRQ_SERVICE_VECTOR				= $fffe      ; LO-byte

; Clear screen. Screen address is stored in SCREEN_PTR
;
; Params: None
CLRSCR							= $e544
