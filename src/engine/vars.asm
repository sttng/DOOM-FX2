	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                     VARIABLES MAINTENANCE MODULE                   *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"


	; public CheckVars
	; public InitVars
	; public CheckSumVars


	%section(VARS)


;
;	* * * * * * *       RESTORE SAVED VARIABLES       * * * * * * *
;
	; dpr 0
	; dbr ?
RestoreVars:
	jsl.l CheckVars	; Verify/Initialize Saved Variables
	; mode 'A'
	lda.w _SkillLevel	; Player's Skill Level
	sta.l SkillLevel
	rtl


;
;	* * * * * * *       VERIFY/INITIALIZE SAVED VARIABLES       * * * * * * *
;
	; dpr 0
	; dbr ?
CheckVars:
	rep #$20		; mode 'A!'
	lda.w RandSentry	; RAND SENTRY VALID?
	cmp.w #$4152
	bne InitVars	; No, Invalid VARS
	lda.w RandSentry+2
	cmp.w #$444E
	bne InitVars	; No, Invalid VARS
	jsl.l CheckSumVars	; CHECKSUM VALID?
	bne InitVars	; No, Invalid VARS
	rtl


;
;	* * * * * * *       	INITIALIZE SAVED VARIABLES       * * * * * * *
;
	; dpr 0
	; dbr ?
InitVars:
;
;	>>>   RESET COUNTER   <<<
;
	rep #$20		; mode 'A!'
	stz.w _ResetCount	; Reset Counter
	if usePAL == 0
	stz.w _TitleCount	; Title Counter
	endif
;
;	>>>   INITIALIZE GAME GLOBALS   <<<
;
	lda.w #2	; Hurt Me Plenty Skill Level
	sta.w _SkillLevel
	lda.w #$FFFF	; Enable Music/SoundEffects/Rumble
	sta.w _SoundsOn
	sta.w _MusicOn
	sta.w _RumbleOn	; (this port)
;
	lda.w #$4152	; VARS Now Valid
	sta.w RandSentry
	lda.w #$444E
	sta.w RandSentry+2
;
;	* * * * * * *       CALCULATE SAVED VARIABLES CHECKSUM       * * * * * * *
;
;	!!!   WARNING!!!   FALLS THROUGH FROM ABOVE   !!!
;
	; dpr 0
	; dbr ?
CheckSumVars:
	sep #$20
	rep #$10		; mode 'aX!'
	lda.b #0	; Check VARS Checksum
	ldx.w #(VarsEnd-Vars)-1
CSVS200:
	eor.w Vars,x
	clc
	adc.b #$52
	dex
	bpl CSVS200
	tay
	xba
	tya
	eor.b #$FF
	sec
	sbc.b #$4C
	rep #$20		; mode 'A!'
	cmp.w VarsCheckSum	; Does Checksum Match?
	sta.w VarsCheckSum	; Update CheckSum
	rtl
