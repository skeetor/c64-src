; Macros for ASM like mnemonics.
;
; Written by Gerhard W. Gruber 12.10.2021
;

.ifndef _MNEMONICS_INC
_MNEMONICS_INC = 1

; Push return address. This can be used
; to trigger an indirect jmp or jsr
.macro phr address
	lda #>(address-1)
	pha
	lda #<(address-1)
	pha
.endmacro

.macro lbeq address
	.local @l1
	bne @l1
	jmp address
@l1:
.endmacro

.macro lbne address
	.local @l1
	beq @l1
	jmp address
@l1:
.endmacro

.macro lbcs address
	.local @l1
	bcc @l1
	jmp address
@l1:
.endmacro

.macro lbcc address
	.local @l1
	bcs @l1
	jmp address
@l1:
.endmacro

; Branch greater
.macro bgt address
	.local @l1
	beq @l1
	bcs address
@l1:
.endmacro

; Branch greater or equal
.macro bge address
	bcs address
.endmacro

; Branch less than
.macro blt address
	bcc address
.endmacro

; Branch less or equal
.macro ble address
	beq address
	bcc address
.endmacro

.endif	; _MNEMONICS_INC
