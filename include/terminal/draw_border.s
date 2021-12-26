; Draw a border to the text screen.
;
; PARAMS:
; BorderWidth
; BorderHeight
;
; Characters to be used for the border
; BorderTopLeft
; BorderTopRight
; BorderBottomLeft
; BorderBottomRight
; BorderVertical
; BorderHorizontal
; BorderScreenWidth	-	Must be set to the column width
;						of the screen. i.E. 40, 80 or whatever
;
; CONSOLE_PTR	Pointer where the border starts, top left edge.
;
; Written by Gerhard W. Gruber in 17.12.2021
;

; AC - Character to be printed
; Y - Offset to screen position
; Pointer to screen location in CONSOLE_PTR

.ifndef _DRAW_BORDER_INC
_DRAW_BORDER_INC = 1

.proc DrawBorder

	ldy BorderWidth
	dey					; 0...N
	lda BorderTopRight
	sta (CONSOLE_PTR),y

	; Draw top line
	jsr BorderHorizontalLine

	lda BorderTopLeft
	ldy #0
	sta (CONSOLE_PTR),y

	ldx BorderHeight

@NextLine:

	; Advance line and color pointers
	clc
	lda CONSOLE_PTR
	adc BorderScreenWidth
	sta CONSOLE_PTR
	lda CONSOLE_PTR HI
	adc #$00
	sta CONSOLE_PTR HI

	; Left side
	ldy #$00
	lda BorderVertical
	sta (CONSOLE_PTR),y

	; Right side
	ldy BorderWidth
	dey
	lda BorderVertical
	sta (CONSOLE_PTR),y

	dex
	bpl @NextLine	; Correct would be 'bne', but we
					; want to add one extra line so
					; the pointers will be correct
					; for the bottom line.

	ldy BorderWidth
	dey					; 0...N
	lda BorderBottomRight
	sta (CONSOLE_PTR),y

	; Draw top line
	jsr BorderHorizontalLine

	lda BorderBottomLeft
	ldy #0
	sta (CONSOLE_PTR),y

	rts
.endproc

.proc BorderHorizontalLine

	dey				; Exclude right side

@DrawLine:
	lda BorderHorizontal
	sta (CONSOLE_PTR),y
	dey
	bpl @DrawLine

	rts
.endproc

.pushseg
.bss

BorderTopLeft:		.byte 0
BorderTopRight:		.byte 0
BorderBottomLeft:	.byte 0
BorderBottomRight:	.byte 0
BorderVertical:		.byte 0
BorderHorizontal:	.byte 0
BorderScreenWidth:	.byte 0

BorderWidth:		.byte 0
BorderHeight:		.byte 0

.popseg

.endif ; _DRAW_BORDER_INC
