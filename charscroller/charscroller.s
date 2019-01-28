; A sample which rotates a single character to create
; a scrolling effect for background
;
; Written by Gerhard W. Gruber 27.01.2019

.include "screenmap.inc"
.include "c64.inc"

.include "app.inc"

.segment "CODE"

_EntryPoint = MainEntry
.include "basicstub.inc"

MainEntry:

	jsr CopyKernel

    rts

.proc CopyKernel

	rts

.endproc

.segment "DATA"
