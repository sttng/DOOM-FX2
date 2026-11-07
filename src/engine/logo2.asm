	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                           LOGO 2 PAGE MODULE                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/xfer.inc"
	incsrc "src/include/music.inc"

	if useLOGO2 != 0

	; public Logo2


	%section(LOGO2)
;
;	* * * * * * *       LOGO2 PAGE       * * * * * * *
;
	; dpr 0
	; dbr ?
Logo2:
	jsl.l ScreenOff	; Turn Screen Off
	jsl.l InitSNES
	; mode 'ax'
;
	rep #$10		; mode 'X!'
	ldx.w #lo16(Logo2XFer)	; Transfer Logo2 DataBlock
	lda.b #bank(Logo2XFer)
	jsl.l XFer
;
	if useSOUND != 0
	rep #$30		; mode 'AX!'
	lda.w #((e1m2_sng_MODULE<<8)|e1m2_sng)	; E1M2 Song
	jsl.l _PlaySong
	endif
;
	jsl.l InitNormalNMI
	sep #$20		; mode 'a!'
	lda.b #$80	; Transfer RGB Palette to CGRAM
	sta.w RGBXFer
	lda.b #1	; Mode1 BG1:8x8
	sta.w BGMODE
	lda.b #$7C	; BG1 Screen at $7c00
	sta.w BG1SC
	lda.b #$FF	; Offset $FFFF
	sta.w BG1VOFS
	sta.w BG1VOFS
	stz.w BG1HOFS	; Offset $0000
	stz.w BG1HOFS
	stz.w BG12NBA	; BG1 @$0000
	stz.w MOSAIC
	lda.b #%00001000	; PseudoH512, 224Lines
	sta.w SETINI
	lda.b #%00000010	; Colour Add Enable
	sta.w CGSWSEL
	lda.b #%01000001	; Add 1/2 Enable BG1
	sta.w CGADSUB
	lda.b #$01	; BG1
	sta.w TM
	sta.w TS
;
	jsl.l FadeScreenOn
	rep #$30		; mode 'AX!'
LG2O200:
;	lda	JOY1L				; Joystick pressed?
;	bne	LG2O200				; Yes, wait until released
	ldx.w #(60*3)-1
LG2O300:
;	lda	JOY1L				; Wait until pressed
;	bne	LG2O400
	wai
	dex
	bpl LG2O300
LG2O400:
;
;	>>>   FADE MUSIC OUT   <<<
;
	if useSOUND != 0
	lda.w #DCOM_FADE_AND_STOP	; Fade out Music
	ldy.w #$0201
	jsl.l __SendDriverCommand
	endif
;
	jml.l FadeScreenOff


;
;	* * * * * * *       TRANSFER LIST       * * * * * * *
;
	; mode '@A@X'
Logo2XFer:
	dw xftVRAM16	; Transfer Logo2Def0 to $0000W
	dd Logo2Def0
	dd $0000
	dw 0,0,0
;
	dw xftVRAM16	; Transfer Logo2Map to $7c00W
	dd Logo2Map
	dd $7C00
	dw 0,0,0
;
	dw xftRAM	; Transfer RGB
	dd Logo2RGB
	dd RGBData
	dw 512
	dw 0,0
;
	dw xftEND


;
;	* * * * * * *       LOGO2 DATA       * * * * * * *
;
	%section(LOGO2_DATA_0)
Logo2Def0:
	if (useOCEAN+useIMAGINEER) == 0
	incbin "data/RLDATA/COMP/Logo2.def0"
	endif
	if useOCEAN != 0
	incbin "data/RLDATA/COMP/Logo3.def0"
	endif
	if useIMAGINEER != 0
	incbin "data/RLDATA/COMP/Logo4.def0"
	endif

	%section(LOGO2_DATA_1)
Logo2Map:
	if (useOCEAN+useIMAGINEER) == 0
	incbin "data/RLDATA/COMP/Logo2.map0"
	endif
	if useOCEAN != 0
	incbin "data/RLDATA/COMP/Logo3.map0"
	endif
	if useIMAGINEER != 0
	incbin "data/RLDATA/COMP/Logo4.map0"
	endif
Logo2RGB:
	if (useOCEAN+useIMAGINEER) == 0
	incbin "data/RLDATA/COMP/Logo2.rgb"
	endif
	if useOCEAN != 0
	incbin "data/RLDATA/COMP/Logo3.rgb"
	endif
	if useIMAGINEER != 0
	incbin "data/RLDATA/COMP/Logo4.rgb"
	endif

	endif
