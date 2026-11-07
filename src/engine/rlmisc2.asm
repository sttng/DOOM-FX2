	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                     MISCELLANEOUS TASKS MODULE 2                   *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


;
;	* * * * * * *       REALITY_ENGINE MISCELLANEOUS TASKS 2       * * * * * * *
;
_RLMisc2:
;
;	>>>   SET VIEW TO PLAYER   <<<
;
	if useMULTIPLAYER == 0
	iwt r2,#lo16(PlayerObject)
	endif
	if useMULTIPLAYER != 0
	lms r2,(MPPlayerObject&$FFFF)
	endif
	with r2	; Get Player X
	%add_i((rloX+2))
;	to	r0
	ldw (r2)
	sms (ViewX&$FFFF),r0
	with r2	; Get Player Y
	%add_i(((rloY+2)-(rloX+2)))
;	to	r0
	ldw (r2)
	sms (ViewY&$FFFF),r0
	inc r2	; Get Player Z
	inc r2
;	to	r0
	ldw (r2)
	lms r1,(PlayerHeight&$FFFF)	; Height of Eye above Feet
;	with	r0
	add r1
	sms (ViewZ&$FFFF),r0
	with r2	; Get Player Angle
	%add_i((rloAngle-rloZ))
;	to	r0
	ldw (r2)
	sms (ViewAngle&$FFFF),r0
	with r2	; Get Player Health
	%add_i((rloHealth-rloAngle))
;	to	r0
	ldw (r2)
	sms (PlayerHealth&$FFFF),r0
;
;	>>>   LIGHTING ADJUSTMENTS   <<<
;
	lms r0,(LightGoggles&$FFFF)	; Light Goggles?
	dec r0
	ibt r0,#lo16(WeaponLight)	; Get Weapon Light Adjustment
	assert (lo16(WeaponLight))&$FFFF < $80 || (lo16(WeaponLight))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;	to	r0
	alt1
	bmi _RLMisc2E	; No
	ldw (r0)	; (with the ALT1 above: ldb (r0))
	ibt r0,#$FF	; YES!  Everything's Bright!
_RLMisc2E:
	ibt r1,#lo16(LightAdjust)	; Save Light Adjustment
	assert (lo16(LightAdjust))&$FFFF < $80 || (lo16(LightAdjust))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;	from	r0
	stb (r1)
;
;	>>>   BUILD BSP TREE   <<<
;
	if usePATCH == 0
	iwt r0,#lo16(_RLBuildBSP)	; BUILD BSP TREE
	endif
	if usePATCH != 0
	lms r0,(PTRLBuildBSP&$FFFF)	; BUILD BSP TREE
	endif
	ibt r8,#bank(_RLBuildBSP)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop
