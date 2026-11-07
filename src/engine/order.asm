	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                         ORDER SCREEN MODULE                        *
;*                                                                    *
;**********************************************************************
;
;	(this port: the shareware set, levels.inc !RLORDERSCREEN.  A new game on an
;	episode the set does not have, and the end of the game, show the WAD's order
;	screen (HELP2, converted by wad2art.py --order) until a button is pressed;
;	then the game goes to the title.)

	incsrc "src/include/rage.inc"
	incsrc "src/include/rl.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/xfer.inc"
	incsrc "src/include/music.inc"

	%section(ORDER)
	if defined("RLORDERSCREEN")
;
;	* * * * * * *       ORDER SCREEN       * * * * * * *
;
	; dpr 0
	; dbr ?
OrderScreen:
	if useSOUND != 0
	rep #$30		; mode 'AX!'
	lda.w #DCOM_FADE_AND_STOP	; Fade out the music
	ldy.w #$0201
	jsl.l __SendDriverCommand
	endif
	jsl.l ScreenOff	; Turn Screen Off
	jsl.l InitSNES
	; mode 'ax'
	rep #$10		; mode 'X!'
	ldx.w #lo16(OrderXFer)	; Transfer the picture
	lda.b #bank(OrderXFer)
	jsl.l XFer
	; mode 'AX'
	jsl.l InitNormalNMI
	sep #$30		; mode 'ax!'
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
	stz.w BG12NBA	; BG1 Chars @$0000
	stz.w MOSAIC
	stz.w SETINI	; 224 Lines
	stz.w CGSWSEL	; No colour maths
	stz.w CGADSUB
	lda.b #$01	; BG1 only
	sta.w TM
	stz.w TS
	jsl.l ScreenOn
;
	rep #$30		; mode 'AX!'
ORD200:
	lda.w PlayerJoy	; Joystick pressed?
	bne ORD200	; Yes, wait until released
ORD300:
	wai
	lda.w PlayerJoy	; Wait until pressed
	beq ORD300
ORD400:
	lda.w PlayerJoy	; and released
	bne ORD400
;
	ldx.w #16-1	; Fade to black (brightness $0F..$01)
	lda.w #$0F
ORD500:
	wai
	wai
	sep #$20		; mode 'a!'
	sta.w INIDISP
	rep #$20		; mode 'A!'
	dec a
	dex
	bne ORD500
	jml.l ScreenOff


;
;	* * * * * * *       TRANSFER LIST       * * * * * * *
;
	; mode '@A@X'
OrderXFer:
	dw xftVRAM16	; Transfer OrderDef0 to $0000W
	dd OrderDef0
	dd $0000
	dw 0,0,0
;
	dw xftVRAM16	; Transfer OrderDef1 to $2000W
	dd OrderDef1
	dd $2000
	dw 0,0,0
;
	dw xftVRAM16	; Transfer OrderMap to $7c00W
	dd OrderMap
	dd $7C00
	dw 0,0,0
;
	dw xftRAM	; Transfer RGB
	dd OrderRGB
	dd RGBData
	dw 512
	dw 0,0
;
	dw xftEND
	endif


;
;	* * * * * * *       ORDER SCREEN DATA       * * * * * * *
;
	%section(ORDER_DATA_0)
	if defined("RLORDERSCREEN")
OrderDef0:
	incbin "data/RLDATA/COMP/Order.def.0"
	endif

	%section(ORDER_DATA_1)
	if defined("RLORDERSCREEN")
OrderDef1:
	incbin "data/RLDATA/COMP/Order.def.1"
	endif

	%section(ORDER_DATA_2)
	if defined("RLORDERSCREEN")
OrderMap:
	incbin "data/RLDATA/COMP/Order.map0"
	endif

	%section(ORDER_DATA_3)
	if defined("RLORDERSCREEN")
OrderRGB:
	incbin "data/RLDATA/COMP/Order.rgb"
	endif
