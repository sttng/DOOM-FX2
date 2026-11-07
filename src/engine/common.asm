	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                          COMMON CODE MODULE                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"

	; public WaitVBlank
	; public ScreenOff,ScreenOn
	; public FadeScreenOff,FadeScreenOn


	%section(COMMON)

;
;	* * * * * * *       WAIT FOR VBLANK/NMI       * * * * * * *
;
	; dbr ?
	; dpr ?
	; mode '@X'
WaitVBlank:
	php
	sep #$20		; mode 'a!'
WaitVBlank2:
	bit.w _HVBJOY	; Wait for NOT in VBlank Period
	bmi WaitVBlank2
WaitVBlank3:
	bit.w _HVBJOY	; Wait for IN VBlank Period
	bpl WaitVBlank3
	plp
	rtl


;
;	* * * * * * *       TURN SCREEN ON       * * * * * * *
;
	; dbr ?
	; dpr ?
	; mode '@X'
ScreenOn:
	sep #$20		; mode 'a!'
	lda.b #$81	; ENABLE NMI
	if (!DEBUG*WIRE) != 0
	sta.l NMITIMEN_XS
	endif
	sta.w NMITIMEN
	jsl.l WaitVBlank	; Wait for VBlank
SON200:
	bit.w RGBXFer	; Wait for first RGB Transfer
	bmi SON200
	lda.b #$0F	; Enable Display
	sta.w INIDISP_S
	sta.w INIDISP
	rtl


;
;	* * * * * * *       FADE SCREEN ON       * * * * * * *
;
	; dbr ?
	; dpr ?
	; mode '@X'
FadeScreenOn:
	sep #$30		; mode 'ax!'
	stz.w INIDISP_S
	stz.w INIDISP
	lda.b #$81	; ENABLE NMI
	if (!DEBUG*WIRE) != 0
	sta.l NMITIMEN_XS
	endif
	sta.w NMITIMEN
	jsl.l WaitVBlank	; Wait for VBlank
FON200:
	bit.w RGBXFer	; Wait for first RGB Transfer
	bmi FON200
	ldx.b #16-1	; 16 Steps to FadeIn
	lda.b #$00
FON500:
	wai
	wai
	inc a	; Next Fade Value
	sta.w INIDISP_S
	sta.w INIDISP	; Fade Value
	dex
	bne FON500
	rtl


;
;	* * * * * * *       FADE SCREEN OFF       * * * * * * *
;
	; dbr ?
	; dpr ?
	; mode '@X'
FadeScreenOff:
	sep #$30		; mode 'ax!'
	ldx.b #16-1	; 16 Steps to FadeOut
	lda.b #$0F
FOF200:
	wai
	wai
	dec a	; Next Fade Value
	sta.w INIDISP_S
	sta.w INIDISP	; Fade Value
	dex
	bne FOF200
;	jmp	ScreenOff
;
;	* * * * * * *       TURN SCREEN OFF       * * * * * * *
;
;	!!!   WARNING!!!   FALLS THROUGH FROM ABOVE   !!!
;
	; dbr ?
	; dpr ?
	; mode '@X'
ScreenOff:
	sep #$20		; mode 'a!'
	lda.b #$80	; Disable Display
	sta.w INIDISP_S
	jsl.l WaitVBlank	; Wait for VBlank
	sta.w INIDISP
	lda.b #$01	; DISABLE NMI,VIRQ,HIRQ
	if (!DEBUG*WIRE) != 0
	sta.l NMITIMEN_XS
	lda.b #$81
	endif
	sta.w NMITIMEN
	stz.w HDMAEN
	bit.w _TIMEUP	; Clear IRQ Flag
	lda.b #$E0	; FixedColour
	sta.w COLDATA
	jml.l WaitVBlank	; Wait for VBlank
