	arch 65816
;**********************************************************************
;*                                                                    *
;*                      P R O J E C T :   R A G E                     *
;*                                                                    *
;*                           LOGO PAGE MODULE                         *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/xfer.inc"

	if useLOGO != 0

	; public Logo


	%section(LOGO)
;
;	* * * * * * *       LOGO PAGE       * * * * * * *
;
	; dpr 0
	; dbr ?
Logo:
	jsl.l InitNormalNMI
;
	sep #$20
	rep #$10		; mode 'aX!'
	ldx.w #lo16(LogoXFer)	; Transfer Logo DataBlock
	lda.b #bank(LogoXFer)
	jsl.l XFer
;
	jsl.l InitSNES	; Initialize Hardware
	; mode 'ax'
	lda.b #$80	; Transfer RGB Palette to CGRAM
	sta.w RGBXFer
	stz.w BGMODE	; Mode0 BG1:8x8
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
	jsl.l ScreenOn
;
	if useSOUND != 0
	jsl.l _InitMusicDriver	; Load MUSIC Driver
	endif
;
	rep #$20		; mode 'A!'
LGO200:
	lda.w JOY1L	; Joystick pressed?
	bne LGO200	; Yes, wait until released
LGO400:
	lda.w JOY1L	; Wait until pressed
	beq LGO400
LGO600:
	lda.w JOY1L	; Joystick pressed?
	bne LGO600	; Yes, wait until released
;
	jml.l ScreenOff


;
;	* * * * * * *       TRANSFER LIST       * * * * * * *
;
	; mode '@A@X'
LogoXFer:
	dw xftVRAM16	; Transfer LogoDef0 to $0000W
	dd LogoDef0
	dd $0000
	dw 0,0,0
;
	dw xftVRAM16	; Transfer LogoMap to $7c00W
	dd LogoMap
	dd $7C00
	dw 0,0,0
;
	dw xftRAM	; Transfer RGB
	dd LogoRGB
	dd RGBData
	dw 512
	dw 0,0
;
	dw xftEND


;
;	* * * * * * *       LOGO DATA       * * * * * * *
;
	%section(LOGO_DATA_0)
LogoDef0:
	incbin "data/RLDATA/COMP/Logo.def0"
LogoMap:
	incbin "data/RLDATA/COMP/Logo.map0"
LogoRGB:
	incbin "data/RLDATA/COMP/Logo.rgb"
	endif
