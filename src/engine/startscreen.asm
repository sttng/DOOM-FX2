	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                         START SCREEN MODULE                        *
;*                                                                    *
;**********************************************************************
;
;	(this port; replaces the original legal page, legal.a) The PC game's start-up
;	log, shown while the music driver loads: the WAD's title bar (BG2, a grey bar
;	behind text row !STARTBARROW), "adding doom.wad", ... (tools/startscreen.py)

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/xfer.inc"

	; public StartScreen

	!STARTBARROW = 1	; the title bar's map row (tools/startscreen.py BAR)


	%section(STARTSCREEN)

;
;	* * * * * * *       START SCREEN       * * * * * * *
;
	; dpr 0
	; dbr ?
	; mode '@A@X'
StartScreen:
	jsl.l ScreenOff	; Turn Screen Off
	jsl.l InitSNES
	; mode 'ax'
;
	rep #$10		; mode 'X!'
	ldx.w #lo16(StartXFer)	; Transfer Start Screen DataBlock
	lda.b #bank(StartXFer)
	jsl.l XFer
;
	; mode 'AX'
	stz.w RGBData+(0*2)
	lda.w #((21<<10)|(21<<5)|21)	; Text: DOS light grey (palette 7)
	sta.w RGBData+(7*16*2)+(7*2)
	sta.w RGBData+(7*16*2)+(11*2)
	sta.w RGBData+(6*16*2)+(15*2)	; Title bar: grey (palette 6, colour 15)
	lda.w #21	; Title bar text: DOS red
	sta.w RGBData+(6*16*2)+(7*2)
	sta.w RGBData+(6*16*2)+(11*2)
	sep #$20		; mode 'a!'
	lda.b #$80	; Transfer RGB Palette to CGRAM
	sta.w RGBXFer
	lda.b #1	; Mode1 BG1:8x8
	sta.w BGMODE
	lda.b #$20	; BG1 Screen at $2000
	sta.w BG1SC
	lda.b #$24	; BG2 Screen at $2400 (the title bar)
	sta.w BG2SC
	lda.b #$FF
	sta.w BG2VOFS
	sta.w BG2VOFS
	stz.w BG2HOFS
	stz.w BG2HOFS
	lda.b #$FF	; Offset $FFFF
	sta.w BG1VOFS
	sta.w BG1VOFS
	stz.w BG1HOFS	; Offset $0000
	stz.w BG1HOFS
	stz.w BG12NBA	; BG1 @$0000
	stz.w MOSAIC
;
	lda.b #%00001000	; PseudoH512, 224Lines
	sta.w SETINI
	lda.b #%00000010	; Colour Add Enable
	sta.w CGSWSEL
	lda.b #%01000001	; Add 1/2 Enable BG1
	sta.w CGADSUB
	ldx.w #$0303	; BG1+BG2
	stx.w TM
;
	ldx.w #lo16(StartSText)	; Show Start Screen Text
	lda.b #bank(StartSText)
	jsl.l SystemText
	sep #$20		; mode 'a!'
	rep #$10		; mode 'X!'
	lda.b #$80	; The title bar: BG2 row !STARTBARROW = tile 1 (solid colour 15),
	sta.w VMAINC	;  palette 6; BG1's text on it: palette 6
	ldx.w #$2400+(!STARTBARROW*32)
	stx.w VMADDL
	ldy.w #32
STS200:
	lda.b #$01
	sta.w VMDATAL
	lda.b #$38
	sta.w VMDATAH
	dey
	bne STS200
	ldx.w #$2000+(!STARTBARROW*32)
	stx.w VMADDL
	ldy.w #32
	lda.b #$38	; (palette 6, priority: high byte only)
STS300:
	sta.w VMDATAH
	dey
	bne STS300
;
	jsl.l ScreenOn
;
	if useSOUND != 0
	jsl.l _InitMusicDriver	; Load MUSIC Driver (the screen shows meanwhile)
	endif
;
	jml.l ScreenOff


;
;	* * * * * * *       TRANSFER LIST       * * * * * * *
;
	; mode '@A@X'
StartXFer:
	dw xftVRAMF16+xftRAW	; Fill $0000W-$2FFFW with $00
	dd StartXFerA
	dd $0000
	dw ($3000*2)
StartXFerA:
	dw 0,0
	dw xftVRAMF16+xftRAW	; Tile 1 ($0010W): solid colour 15 (the title bar)
	dd StartXFerB
	dd $0010
	dw 32
StartXFerB:
	dw $FFFF,$FFFF
	dw xftVRAM16	; Transfer TextFontDef to $0200W
	dd TextFontDef
	dd $0200
	dw 0,0,0
	dw xftEND


;
;	* * * * * * *       START SCREEN TEXT       * * * * * * *
;
	incsrc "data/RLDATA/COMP/starttext.inc"	; StartSText (tools/startscreen.py)
