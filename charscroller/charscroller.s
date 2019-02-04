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
VICCHARSETADR           = VICCHARSETBLOCK+VICBASEADR

CHARROMADR				= $d000
ZP_HELPADR1             = $fb
ZP_HELPADR2             = $fd

.segment "CODE"

; We want to have a basic loder, so we 
_EntryPoint = MainEntry
.include "basicstub.inc"

MainEntry:

	lda #VICSCREENBLOCKNO*16+VICCHARSETBLOCKNO*2
	sta $d018                          ;Adresse für Bildschirm und Zeichensatz festlegen

	sei                                ;IRQs sperren

	lda $01                            ;ROM-'Konfig' in den Akku
	pha                                ;auf dem Stack merken
	and #%11111011                     ;BIT-2 (E/A-Bereich) ausblenden
	sta $01                            ;und zurückschreiben

	jsr CopyCharrROM                   ;Zeichensatz kopieren

	pla                                ;ROM-Einstellung vom Stack holen
	sta $01                            ;wiederherstellen

	cli                                ;Interrupts freigeben

	jsr SetupIRQ

    rts

.proc CopyCharrROM

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

rts

.endproc

.proc SetupIRQ

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
	inc	VIC_BORDERCOLOR

	jmp $0000
IRQAddress = *-2

.endproc

.segment "DATA"
