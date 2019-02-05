; A sample which rotates a single character to create
; a scrolling effect for background
;
; Written by Gerhard W. Gruber 27.01.2019

.include "screenmap.inc"
.include "c64.inc"

; included as this 
.include "app.inc"

;*** VIC-II Speicher-Konstanten
VICBANKNO               = 0                             ;Nr. (0 - 3) der 16KB Bank                              | Standard: 0
VICSCREENBLOCKNO        = 1                             ;Nr. (0 -15) des 1KB-Blocks für den Textbildschirm      | Standard: 1
VICCHARSETBLOCKNO       = 7                             ;Nr. (0 - 7) des 2KB-Blocks für den Zeichensatz         | Standard: 2
VICBITMAPBBLOCKNO       = 0                             ;Nr. (0 - 1) des 8KB-Blocks für die BITMAP-Grafik       | Standard: 0
VICBASEADR              = VICBANKNO*16384               ;Startadresse der gewählten VIC-Bank                    | Standard: $0000
VICCHARSETBLOCK         = VICCHARSETBLOCKNO*2048        ;Adresse des Zeichensatzes                              | Standard: $1000 ($d000)
VICCHARSETADR           = VICCHARSETBLOCK+VICBASEADR	; $3800
SCROLLCHARADDR			= VICCHARSETADR+8				; Uses 'A' to scroll $3808

CHARROMADR				= $d000
ZP_HELPADR1             = $fb
ZP_HELPADR2             = $fd

.segment "CODE"

; We want to have a basic loder, so we 
_EntryPoint = MainEntry
;.include "basicstub.inc"

MainEntry:

	lda #VICSCREENBLOCKNO*16+VICCHARSETBLOCKNO*2
	sta $d018                          ;Adresse für Bildschirm und Zeichensatz festlegen

	jsr CopyCharrROM                   ;Zeichensatz kopieren
	jsr SetupIRQ

    rts

.proc CopyCharrROM

	sei                                ;IRQs sperren

	lda $01                            ;ROM-'Konfig' in den Akku
	pha                                ;auf dem Stack merken
	and #%11111011                     ;BIT-2 (E/A-Bereich) ausblenden
	sta $01                            ;und zurückschreiben

	lda #<CHARROMADR                   ;Quelle (CharROM) auf die Zero-Page
	sta ZP_HELPADR1
	lda #>CHARROMADR
	sta ZP_HELPADR1+1

	lda #<VICCHARSETADR                ;Ziel (RAM-Adr. Zeichensatz) in die Zero-Page
	sta ZP_HELPADR2
	lda #>VICCHARSETADR
	sta ZP_HELPADR2+1

	ldx #$08                           ;wir wollen 8*256 = 2KB kopieren

@loopPage:
	ldy #$00                           ;Schleifenzähler für je 256 Bytes

@loopChar:
	lda (ZP_HELPADR1),Y                ;Zeichenzeile (Byte) aus dem CharROM holen
	sta (ZP_HELPADR2),Y                ;und in unseren gewählten Speicherbereich kopieren
	dey                                ;Blockzähler (256 Bytes) verringern
	bne @loopChar                      ;solangen ungleich 0 nach loopChar springen

	inc ZP_HELPADR1+1                  ;Sonst das MSB der Adressen auf der Zeropage
	inc ZP_HELPADR2+1                  ;um eine 'Seite' (256 Bytes) erhöhen
	dex                                ;'Seiten'-Zähler (acht Seiten zu 256 Bytes) verringern
	bne @loopPage                      ;solange ungleich 0 nach loopPage springen

	pla                                ;ROM-Einstellung vom Stack holen
	sta $01                            ;wiederherstellen
	cli

	rts

.endproc

.proc SetupIRQ

	lda HDelayValue
	sta HDelay
	lda VDelayValue
	sta VDelay

	lda $0314
	sta IRQAddress
	lda $0315
	sta IRQAddress+1

	sei
	lda #<@IRQ                          ;LSB unserer IRQ-Routine in den Akku
	sta $0314
	lda #>@IRQ                          ;MSB
	sta $0315
	cli

	rts

@IRQ:
; State saving must be enabled if not using kernel
; For this version the kernel already does it, so we don't need to do it
; here as well.

;	pha
;	txa
;	pha
;	tya
;	pha

	lda HDelayValue
	beq @VScroll

	jsr CharScrollHorizontal

@VScroll:

	lda VDelayValue
	beq @Continue

	jsr CharScrollVertical

@Continue:
;	pla
;	tay
;	pla
;	tax
;	pla
	jmp $0000
IRQAddress = *-2

.endproc

.proc CharScrollHorizontal

	dec HDelay
	bne @Done

	lda HDelayValue
	sta HDelay

	ldx #8

	lda HDirection
	beq @ScrollLeft

@ScrollRight:
	lda SCROLLCHARADDR-1,x

	tay
	ror
	tya

	ror
	sta SCROLLCHARADDR-1,x
	dex
	bne @ScrollRight

	rts

@ScrollLeft:
	lda SCROLLCHARADDR-1,x

	tay
	rol
	tya

	rol
	sta SCROLLCHARADDR-1,x
	dex
	bne @ScrollLeft

@Done:

	rts

.endproc


.proc CharScrollVertical

	dec VDelay
	bne @Done

	lda VDelayValue
	sta VDelay

	lda VDirection
	beq @ScrollUp

	lda SCROLLCHARADDR+7
	pha

	ldx #7

@ScrollDownLoop:
	lda SCROLLCHARADDR-1,x
	sta SCROLLCHARADDR,x
	dex
	bne @ScrollDownLoop

	pla
	sta SCROLLCHARADDR
	jmp @Done

@ScrollUp:
	ldy #7
	ldx #0

	lda SCROLLCHARADDR
	pha

@ScrollUpLoop:
	lda SCROLLCHARADDR+1,x
	sta SCROLLCHARADDR,x
	inx
	dey
	bne @ScrollUpLoop

	pla
	sta SCROLLCHARADDR+7

@Done:

	rts

.endproc

.segment "DATA"
HDirection: .byte 1
HDelayValue: .byte 5
HDelay: .byte 1

VDirection: .byte 1
VDelayValue: .byte 9
VDelay: .byte 1
