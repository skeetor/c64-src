; C64 Kernel functions
;
; Written by Gerhard W. Gruber 27.01.2019

; Default address of screen memory
SCREEN_MEM                     = $0400

BASIC_ROM_START                = $a000
BASIC_ROM_END                  = $bfff

KERNEL_ROM_START               = $e000
KERNEL_ROM_END                 = $ffff

NMI_SERVICE_VECTOR             = $fffa      ; LO-btye
COLD_RESET_SERVICE_VECTOR      = $fffc      ; LO-byte
IRQ_SERVICE_VECTOR             = $fffe      ; LO-byte

; Clear screen. Screen address is stored in SCREEN_PTR
;
; Params: None
CLRSCR				            = $e544
