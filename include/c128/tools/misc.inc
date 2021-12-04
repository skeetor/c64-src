; Macros for everyday use.
;
; Written by Gerhard W. Gruber 12.10.2021
;

.ifndef _TOOLS_INC
_TOOLS_INC = 1

; SetPointer will set the pointer to the specified
; address.
.macro  SetPointer   addrValue, Pointer
		lda     #<addrValue
		sta     Pointer
		lda     #>addrValue
		sta     Pointer+1
.endmacro

.define HI +1
.endif	; _TOOLS_INC
