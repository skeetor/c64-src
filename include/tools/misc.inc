; Macros for everyday use.
;
; Written by Gerhard W. Gruber 12.10.2021
;

.ifndef _TOOLS_INC
_TOOLS_INC = 1

.define HI +1

C128_MODE			= %01
C64_MODE			= %10

; SetPointer will set the pointer to the specified
; address.
.macro  SetPointer   addrValue, Pointer
		lda     #<addrValue
		sta     Pointer
		lda     #>addrValue
		sta     Pointer+1
.endmacro

.macro  CopyPointer   PointerSrc, PointerTgt
		lda     PointerSrc
		sta     PointerTgt
		lda     PointerSrc HI
		sta     PointerTgt HI
.endmacro

.macro AddWordTgt Value, SrcAddress, TgtAddress
	clc
	lda SrcAddress
	adc #<Value
	sta TgtAddress
	lda SrcAddress+1
	adc #>Value
	sta TgtAddress+1
.endmacro

.macro AddWord Value, Address
	AddWordTgt Value, Address, Address
.endmacro

.macro SubWordTgt Value, SrcAddress, TgtAddress
	sec
	lda SrcAddress
	sbc #<Value
	sta TgtAddress
	lda SrcAddress+1
	sbc #>Value
	sta TgtAddress+1
.endmacro

.macro SubWord Value, Address
	SubWordTgt Value, Address, Address
.endmacro

; This macro can be used as a reminder when nops are
; inserted to avoid the jmp (abs) bug on page boundaries.
.macro PAGE_NOP
	nop
.warning "nop inserted for jmp (abs) across border page workaround!"
.endmacro

.endif	; _TOOLS_INC
