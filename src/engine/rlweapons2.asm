	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                      WEAPONS HANDLING MODULE 2                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/rlweapons.inc"
	incsrc "src/include/rlplayer.inc"
	incsrc "src/include/music.inc"

	; public _RLWeapons


;
;	* * * * * * *       WEAPONS DEFINITIONS       * * * * * * *
;
	WeaponYBottom = 85	; Weapon Y Bottom
	WeaponYDelta = 8	; Weapon Y Movement Delta



	%section(ENGINE_GSUCODE)
	arch superfx
;
;	* * * * * * *       REALITY_ENGINE WEAPONS HANDLING       * * * * * * *
;
_RLWeapons:
;
;	>>>   CALL WEAPON STATE HANDLER   <<<
;
	link #4	; Call WeaponState Handler
	iwt r15,#lo16(_RLDoWeaponState)
	nop
;
;	>>>   UPDATE WEAPON SPRITE POSITION   <<<
;
_RLWeapons1:
	lms r1,(WeaponXOffset&$FFFF)	; Get Weapon X Coordinate Offset
	ibt r0,#127	; CutterX Center Offset from Screen
;	with	r0
	add r1
	lms r1,(WeaponYOffset&$FFFF)	; Get Weapon Y Coordinate Offset
	sms (WeaponX&$FFFF),r0
	ibt r0,#(128-(256-224))	; CutterY Center Offset from Screen
;	with	r0
	add r1
	sms (WeaponY&$FFFF),r0
;
;	>>>   UPDATE WEAPON AMMO   <<<
;
	lms r0,(WeaponAmmo&$FFFF)	; Get Address of Ammo
	dec r0
	bmi _RLWeapons2	; Fist/ChainSaw
	inc r0
;	to	r0				; Get Ammo Amount
	ldw (r0)
_RLWeapons2:
	sms (PlayerAmmo&$FFFF),r0	; Player's Ammo
;
;	>>>   HANDLE SECTORS   <<<
;
	if usePATCH == 0
	iwt r0,#lo16(_RLDoSectors)	; HANDLE SECTORS
	endif
	if usePATCH != 0
	lms r0,(PTRLDoSectors&$FFFF)	; HANDLE SECTORS
	endif
	ibt r8,#bank(_RLDoSectors)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop


;
;	* * * * * * *       DROP PLAYER'S WEAPON       * * * * * * *
;
_RLDropWeapon:
	move r12,r11	; Save Return Address
	iwt r0,#(recRemLoop|reIdleChainSaw)	; (this port) Rumble: the chainsaw's idle loop off, as FX3
	link #4
	iwt r15,#lo16(_RLAddRumble)
	nop
_RLDropWeapon2:
	ibt r0,#wdLower	; LOWER STATE
	iwt r15,#lo16(_RLSetWeaponState)
	nop


;
;	* * * * * * *       PICK UP PLAYER'S WEAPON       * * * * * * *
;
_RLPickWeapon:
	move r12,r11	; Save Return Address
_RLPickWeapon2:
	lms r0,(WeaponNext&$FFFF)	; SELECTED WEAPON
	sms (WeaponType&$FFFF),r0
	ibt r1,#wtChainSaw	; (this port) The chainsaw: its raising sound (PC DSSAWUP)
;	from	r0
	cmp r1
	bne _RLPW2100
	nop
	move r10,r11
	ibt r3,#sawup_eff	; Sound Effect
	link #4
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop
	move r11,r10
	lms r0,(WeaponType&$FFFF)
_RLPW2100:
	ibt r1,#bank(WeaponsData)	; Set ROM Bank
	from r1
	romb
;	with	r0				; WEAPON DATA
	%umult_i((wdSize/2))
	iwt r1,#lo16(WeaponsData)
;	with	r0
	add r1
	sms (WeaponData&$FFFF),r0
;	from	r0				; AMMUNITION
	to r14
	%add_i(wdAmmo)
	ibt r0,#0	; FRAME #0
	sms (WeaponFrame&$FFFF),r0
;
	getb	; Get Ammo Address
	inc r14
	getbh
	sms (WeaponAmmo&$FFFF),r0	; Save Address of Ammo
;
	ibt r0,#WeaponYBottom	; Weapon Starts off Bottom
	sms (WeaponYOffset&$FFFF),r0
;	with	r0				; Weapon X Offset
	sub r0
	sms (WeaponXOffset&$FFFF),r0
;
	ibt r0,#wdRaise	; RAISE STATE
;
;
;	* * * * * * *       SET WEAPON STATE       * * * * * * *
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE   !!!
;
_RLSetWeaponState:
	ibt r1,#bank(WeaponsData)	; Set ROM Bank
	from r1
	romb
	lms r1,(WeaponData&$FFFF)	; Address of Current WeaponData
;	from	r0				; Move to WeaponState Data Address
	to r14
	add r1
	sms (WeaponState&$FFFF),r0
	bra _RLDWS2200	; Handle New WeaponState
	nop


;
;	* * * * * * *       CALL WEAPON STATE CODE       * * * * * * *
;
_RLDoWeaponState:
	lms r1,(FPSCount+RLGSUSNESXVarsO&$FFFF)	; Subtract FPS Counter
	lms r0,(WeaponStateCount&$FFFF)	; Time to switch states?
;	with	r0
	sub r1
	sbk	; Save new Counter
	dec r0	; Finished this State?
	with r11	; Save Return Address
	bmi _RLDWS2000	; YES!
	to r12
	jmp r11	; Return to Caller
	nop
;
;	>>>   GET NEXT WEAPON STATE   <<<
;
_RLDWS2000:
	ibt r0,#bank(WeaponsData)	; Set ROM Bank
	romb
_RLDWS2100:
	lms r0,(WeaponStateData&$FFFF)	; Address of Current WeaponState
;	from	r0				; Move to Next WeaponState
	to r14
	%add_i(wsNextState)
_RLDWS2200:
	getb
	inc r14
;	from	r0				; Move to New WeaponState
	to r14
	getbh
	sms (WeaponStateData&$FFFF),r14	; Save Address of New WeaponState
;
;	>>>   CALL NEW STATE CODE   <<<
;
	getb	; Get Address of WeaponStateCode
	inc r14
;	from	r0
	to r10
	getbh
	link #2
	jmp r10	; Call Weapon StateCode
	nop
;
;	>>>   GET #CYCLES AT NEW STATE   <<<
;
_RLDWS3000:
	lms r0,(WeaponStateData&$FFFF)	; Get #CYCLES at this State
;	from	r0
	to r14
	%add_i(wsCount)
	getb
	inc r14
	moves r0,r0
	beq _RLDWS2100	; 0=Move to Next State Immediately
	sex
	lms r1,(WeaponStateCount&$FFFF)	; Get Counter Underflow
;	with	r0
	add r1
	bpl _RLDWS3400	; Underflow?
	nop
;	with	r0				; Yes!
	sub r0
_RLDWS3400:
	sbk	; Save New Counter
;
;	>>>   GET SPRITE IMAGERY   <<<
;
	getb	; Get CutSpriteNumber
	sms (WeaponFrame&$FFFF),r0
;
;	>>>   FINISHED HANDLING WEAPON STATE   <<<
;
	jmp r12	; Return to Caller
	nop


;
;	* * * * * * *       RAISE WEAPON       * * * * * * *
;
_RLRaiseWeapon:
	lms r0,(PlayerDead&$FFFF)	; Is Player Dead?
	dec r0
	bpl _RLRW900	; Yes, Don't Raise Weapon!
	nop
	lms r0,(WeaponTypeBuilt+RLGSUSNESXVarsO&$FFFF)
	lms r1,(WeaponType&$FFFF)
;	with	r0				; Is CORRECT Weapon Built?
	sub r1	; @CMP@
	bne _RLRW900-1	; No, Don't Raise Weapon!
;
;	>>>   CALCULATE WEAPON SPEED DELTA   <<<
;
	ibt r6,#-WeaponYDelta
	lms r0,(FPSRatio&$FFFF)	; Get FramesPerSecond Ratio
;	with	r0
	lmult
;	with	r0				; Get Whole Pixels Only
	lob
;	with	r0
	swap
	with r4
	hib
;	with	r0				; R0 = -WeaponYDelta
	or r4
;
	lms r1,(WeaponYOffset&$FFFF)	; Get Weapon Y Offset
	with r1
	add r0
	bpl _RLRW800	; At Top?
;
;	>>>   WEAPON READY FOR USE!   <<<
;
;	with	r0
	sub r0
	sbk	; Yes, Weapon Ready!
	sms (WeaponStateCount&$FFFF),r0	; Reset WeaponState Counter

	if useWILLIAMS == 0
;
;	>>>   MAKE SOUND EFFECT   <<<
;
	ibt r3,#wpnup_eff	; Make WeaponUp SoundEffect
	link #4
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop
	endif

_RLRW700:
	ibt r0,#wdReady	; READY STATE
	iwt r15,#lo16(_RLSetWeaponState)
	nop
_RLRW800:
	from r1	; Save New Weapon Y Offset
	sbk
_RLRW900:
	jmp r11
	nop


;
;	* * * * * * *       LOWER WEAPON       * * * * * * *
;
_RLLowerWeapon:
;
;	>>>   CALCULATE WEAPON SPEED DELTA   <<<
;
	ibt r6,#WeaponYDelta
	lms r0,(FPSRatio&$FFFF)	; Get FramesPerSecond Ratio
;	with	r0
	lmult
;	with	r0				; Get Whole Pixels Only
	lob
;	with	r0
	swap
	with r4
	hib
;	with	r0				; R0 = WeaponYDelta
	or r4
;
	lms r1,(WeaponYOffset&$FFFF)	; Get Weapon Y Offset
	with r1	; Weapon Delta
	add r0
	ibt r0,#WeaponYBottom-1	; Too Low?
;	from	r0
	cmp r1
	bge _RLLW800
	inc r0
	sbk	; Yes, Weapon fully lowered (WeaponYBottom)
	iwt r15,#lo16(_RLPickWeapon2)	; Pick up New Weapon
	nop
_RLLW800:
	from r1	; Save New Weapon Y Offset
	sbk
	jmp r11
	nop

;
;	* * * * * * *       FIRE CHAINSAW SOUND       * * * * * * *
;
_RLChainSawNull:
	ibt r3,#sawful_eff	; Sound Effect
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop
	if !RLDOOM2MONSTERS != 0
;
;	* * * * * * *       SUPER SHOTGUN OPEN/LOAD/CLOSE SOUNDS (PC DBOPN/DBLOAD/DBCLS)   * * * * * * *
;
;	(the cartridge's switch and weapon-up sounds stand in for them)
;
_RLSSGOpen:
	ibt r3,#swtchn_eff
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop
_RLSSGLoad:
	ibt r3,#wpnup_eff
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop
_RLSSGClose:
	ibt r3,#swtchx_eff
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop
	endif
;
;	* * * * * * *       READY CHAINSAW       * * * * * * *
;
_RLReadyChainSaw:
	lms r0,(AutoMapMode&$FFFF)	; In AutoMap Mode?
;	with	r0
	sex
	bne _RLReadyChainSaw2	; Yes, can't use Weapon!
	nop
	lms r0,(PlayerJoy+RLGSUSNESXVarsO&$FFFF)	; Get Joystick Buttons
	iwt r1,#pjFIRE	; <A> TO USE WEAPON
;	with	r0
	and r1
	bne _RLReadyWeapon	; Using ChainSaw -- Don't Make Idle Sound!
_RLReadyChainSaw2:
	move r10,r11
	ibt r3,#sawidl_eff	; Sound Effect
	link #4
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop
	ibt r0,#(recAddLoop|reIdleChainSaw)	; (this port) Rumble: the idle loop, as FX3
	link #4
	iwt r15,#lo16(_RLAddRumble)
	nop
	move r11,r10
;
;	* * * * * * *       READY WEAPON       * * * * * * *
;
_RLReadyWeapon:
;
;	>>>   SWAY PLAYER'S WEAPON   <<<
;
	lms r0,(VBlankTotal+RLGSUSNESXVarsO&$FFFF)	; Get VBlank Counter Total
	ibt r1,#(WeaponSwayVBlanks-1)	; Complete Sway in #VBlanks
;	with	r0
	and r1
	ibt r1,#(1024/WeaponSwayVBlanks*2)
;	from	r0
	to r1
	umult r1
;
;	>>>   GET ROTATIONAL SINE/COSINE CONSTANTS   <<<
;
	ibt r0,#bank(CosTable)	; Bank of CosTable
	romb
	iwt r0,#lo16(CosTable)
;	from	r0
	to r14
	add r1
;
	lms r6,(PlayerSway&$FFFF)	; Get Player's Sway Factor
;
;	to	r0				; Get COSINE
	getb
	inc r14
;
	iwt r4,#(1024/2*2)-1	; Mask SINE around UPPER HALF ONLY!
	with r1
	and r4
	iwt r4,#lo16(SinTable)
;
;	with	r0
	getbh
;
	from r4	; Move to SINE
	to r14
	add r1
;
;	from	r0				; Calculate Sway Weapon X
	to r1
	fmult
;
;	to	r0				; Get SINE
	getb
	inc r14
;
	sms (WeaponXOffset&$FFFF),r1	; Save Weapon X Coordinate Offset
;
;	with	r0
	getbh
;
;	from	r0				; Calculate Sway Weapon Y
	to r1
	fmult
;
	sms (WeaponYOffset&$FFFF),r1	; Save Weapon Y Coordinate Offset
	ibt r0,#bank(WeaponsData)	; Set ROM Bank
	romb
;
;	* * * * * * *       USE WEAPON       * * * * * * *
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE   !!!
;
_RLUseWeapon:
	lms r0,(AutoMapMode&$FFFF)	; In AutoMap Mode?
;	with	r0
	sex
	bne _RLUW800	; Yes, can't use Weapon!
	nop
	lms r0,(PlayerJoy+RLGSUSNESXVarsO&$FFFF)	; Get Joystick Buttons
	iwt r1,#pjFIRE	; <A> TO USE WEAPON
;	with	r0
	and r1
	beq _RLUW800
	nop
	lms r0,(WeaponAmmo&$FFFF)	; ANY Ammo Left?
	dec r0
	bmi _RLUseWeapon2	; Fist/ChainSaw
	inc r0
;	to	r0				; Get Ammo
	ldw (r0)
	if !RLDOOM2MONSTERS != 0
	lms r1,(WeaponType&$FFFF)	; Super Shotgun: 2 shells
	ibt r2,#wtSuperShotGun
	from r1
	cmp r2
	bne _RLUseWeapon1
	nop
	from r0	; Fewer than 2?
	to r1
	sub #2
	bmi _RLNewWeapon
	nop
_RLUseWeapon1:
	endif
	moves r0,r0	; Any Ammo Left?
	beq _RLNewWeapon	; NO!  PLAYER CAN'T USE WEAPON!
	if useID3 == 0
	nop
	endif
_RLUseWeapon2:
	if useID3 != 0
;	with	r0				; R0 = 0
	sub r0
	sms (WeaponXOffset&$FFFF),r0	; New Weapon X Coordinate Offset
	sms (WeaponYOffset&$FFFF),r0	; New Weapon Y Coordinate Offset
	endif
	ibt r0,#wdUse	; USE STATE
	iwt r15,#lo16(_RLSetWeaponState)
	nop
_RLUW800:
	jmp r11	; Return to Caller
	nop
;
;	>>>   NO AMMO -- SWITCH TO NEXT MOST POWERFUL WEAPON   <<<
;
_RLNewWeapon:
	iwt r6,#lo16(PlayerArms)	; Get Available Weapons
	to r6
	ldb (r6)
	ibt r0,#bank(_WeaponTypeBitsTable)
	romb
	iwt r0,#lo16(_WeaponTypeBitsTable)
	lms r2,(WeaponType&$FFFF)	; Current Weapon
	if !RLDOOM2MONSTERS != 0
	ibt r1,#wtSuperShotGun	; (Super Shotgun: from the Shotgun's place)
	from r2
	cmp r1
	bne _RLNewWeapon1
	nop
	ibt r2,#wtShotGun
_RLNewWeapon1:
	endif
;	from	r0
	to r14
	add r2
	to r3	; R3 = Weapon Type Bit
	getb
	move r4,r3	; R4 = Weapon Type Bit
	ibt r0,#bank(WeaponsData)	; Set ROM Bank
	romb
	iwt r1,#lo16(WeaponsData+wdAmmo)
_RLNewWeapon2:
	inc r2	; Next Weapon
	inc r2
	with r2	; Limit to Maximum Weapon Types
	and #15
	with r3
	beq _RLNewWeapon5	; No Better Weapons!
	add r3	; (original: "rol", which shifted the carry of the ChainSaw check
	; below into bit 0, the Fist's: the weapon after the ChainSaw counted
	; as owned, so out of shells it switched to the ChainGun without having it)
	from r3	; Does Player have this Weapon?
;	to	r0
	and r6
	beq _RLNewWeapon2	; No!  Next Weapon!
	from r2	; ChainSaw?
;	to	r0
	%sub_i(wtChainSaw)
	beq _RLNewWeapon2	; Yes, Don't Take Initially!
	from r2	; WEAPON DATA
;	to	r0
	%umult_i((wdSize/2))
;	from	r0				; AMMUNITION
	to r14
	add r1
	getb	; Get Ammo Address
	inc r14
	getbh
;	to	r0				; Any Ammo?
	ldw (r0)
	dec r0
	bpl _RLNewWeapon9	; Yes!  Use This Weapon!
	nop
	bra _RLNewWeapon2+1
	inc r2	; Next Weapon
_RLNewWeapon5:
	lms r2,(WeaponType&$FFFF)	; Current Weapon
	if !RLDOOM2MONSTERS != 0
	ibt r0,#wtSuperShotGun
	from r2
	cmp r0
	bne _RLNewWeapon5A
	nop
	ibt r2,#wtShotGun
_RLNewWeapon5A:
	endif
_RLNewWeapon6:
	dec r2	; Next Weapon
	dec r2
	beq _RLNewWeapon7	; Don't Take Fist unless No ChainSaw!
	with r4
	bmi _RLNewWeapon7	; No Worse Weapons?!
	asr
	from r4	; Does Player have this Weapon?
;	to	r0
	and r6
	beq _RLNewWeapon6	; No!  Next Weapon!
	from r2	; ChainSaw?
;	to	r0
	%sub_i(wtChainSaw)
	beq _RLNewWeapon6	; Yes, Don't Take Initially!
	from r2	; WEAPON DATA
;	to	r0
	%umult_i((wdSize/2))
;	from	r0				; AMMUNITION
	to r14
	add r1
	getb	; Get Ammo Address
	inc r14
	getbh
;	to	r0				; Any Ammo?
	ldw (r0)
	dec r0
	bpl _RLNewWeapon9	; Yes!  Use This Weapon!
	nop
	bra _RLNewWeapon6+1
	dec r2	; Next Weapon
_RLNewWeapon7:
	with r6	; Does Player Have ChainSaw?
	%and_i(wtbChainSaw)
	with r2
	beq _RLNewWeapon9	; No, Use Fist!
	sub r2
	ibt r2,#wtChainSaw	; Yes!  Use It!
;
;	>>>   SELECT NEW WEAPON   <<<
;
_RLNewWeapon9:
	sms (WeaponNext&$FFFF),r2	; YES!  NEW NEXT WEAPON!
	iwt r15,#lo16(_RLDropWeapon2)
	nop


	if useWILLIAMS != 0
;
;	* * * * * * *       CHAINGUN SOUND       * * * * * * *
;
_RLChainGunLight0:
	move r10,r11
	ibt r3,#pistol_eff	; Make Pistol SoundEffect
	link #4
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop
	move r11,r10
	endif
;
;	* * * * * * *       WEAPON LIGHT 0       * * * * * * *
;
_RLWeaponLight0:
	ibt r1,#lo16(WeaponLight)	; NO LIGHT CREATED BY WEAPON
	assert (lo16(WeaponLight))&$FFFF < $80 || (lo16(WeaponLight))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;	with	r0
	sub r0
;	from	r0
	stb (r1)
;
;	* * * * * * *       WEAPON NULL       * * * * * * *
;
_RLWeaponNull:
	jmp r11
	nop


;
;	* * * * * * *       WEAPONS DATA TABLE       * * * * * * *
;
WeaponsData:
wFistData:
	dw lo16(wsFISTUP)	; FIST
	dw lo16(wsFISTDOWN)
	dw lo16(wsFIST)
	dw lo16(wsFIST1)
	dw -1
wPistolData:
	dw lo16(wsPISTOLUP)	; PISTOL
	dw lo16(wsPISTOLDOWN)
	dw lo16(wsPISTOL)
	dw lo16(wsPISTOL1)
	dw lo16(WeaponBullets)
wShotGunData:
	dw lo16(wsSHOTGUNUP)	; SHOTGUN
	dw lo16(wsSHOTGUNDOWN)
	dw lo16(wsSHOTGUN)
	dw lo16(wsSHOTGUN1)
	dw lo16(WeaponShells)
wChainSawData:
	dw lo16(wsCHAINSAWUP)	; CHAINSAW
	dw lo16(wsCHAINSAWDOWN)
	dw lo16(wsCHAINSAW)
	dw lo16(wsCHAINSAW2)
	dw -1
wChainGunData:
	dw lo16(wsCHAINGUNUP)	; CHAINGUN
	dw lo16(wsCHAINGUNDOWN)
	dw lo16(wsCHAINGUN)
	dw lo16(wsCHAINGUN1)
	dw lo16(WeaponBullets)
wRocketData:
	dw lo16(wsROCKETUP)	; ROCKET
	dw lo16(wsROCKETDOWN)
	dw lo16(wsROCKET)
	dw lo16(wsROCKET1)
	dw lo16(WeaponRockets)
wPlasmaData:
	dw lo16(wsPLASMAUP)	; PLASMA
	dw lo16(wsPLASMADOWN)
	dw lo16(wsPLASMA)
	dw lo16(wsPLASMA1)
	dw lo16(WeaponCells)
wBFGData:
	dw lo16(wsBFGUP)	; BFG
	dw lo16(wsBFGDOWN)
	dw lo16(wsBFG)
	dw lo16(wsBFG1)
	dw lo16(WeaponCells)
	if !RLDOOM2MONSTERS != 0
wSuperShotGunData:
	dw lo16(wsSSGUP)	; SUPER SHOTGUN (DOOM II)
	dw lo16(wsSSGDOWN)
	dw lo16(wsSSG)
	dw lo16(wsSSG1)
	dw lo16(WeaponShells)
	endif

;
;	* * * * * * *       FIST STATE TABLE       * * * * * * *
;
wsFISTUP:
	dw lo16(_RLRaiseWeapon)	; wsFISTUP
	db 1
	db wfPUNGA0
	dw lo16(wsFISTUP)

wsFISTDOWN:
	dw lo16(_RLLowerWeapon)	; wsFISTDOWN
	db 1
	db wfPUNGA0
	dw lo16(wsFISTDOWN)

wsFIST:
	dw lo16(_RLReadyWeapon)	; wsFIST
	db 1
	db wfPUNGA0
	dw lo16(wsFIST)
wsFIST1:
	dw lo16(_RLFireFist)	; wsFIST1
	db 6
	db wfPUNFA0
	dw lo16(wsFIST2)
wsFIST2:
	dw lo16(_RLWeaponNull)	; wsFIST2
	db 6
	db wfPUNFB0
	dw lo16(wsFIST3)
wsFIST3:
	dw lo16(_RLWeaponNull)	; wsFIST3
	db 6
	db wfPUNFC0
	dw lo16(wsFIST4)
wsFIST4:
	dw lo16(_RLWeaponNull)	; wsFIST4
	db 6
	db wfPUNFB0
	dw lo16(wsFIST5)
wsFIST5:
	dw lo16(_RLWeaponNull)	; wsFIST5
	db 6
	db wfPUNFA0
	dw lo16(wsFIST)

;
;	* * * * * * *       PISTOL STATE TABLE       * * * * * * *
;
wsPISTOLUP:
	dw lo16(_RLRaiseWeapon)	; wsPISTOLUP
	db 1
	db wfPISGA0
	dw lo16(wsPISTOLUP)

wsPISTOLDOWN:
	dw lo16(_RLLowerWeapon)	; wsPISTOLDOWN
	db 1
	db wfPISGA0
	dw lo16(wsPISTOLDOWN)

wsPISTOL:
	dw lo16(_RLReadyWeapon)	; wsPISTOL
	db 1
	db wfPISGA0
	dw lo16(wsPISTOL)
wsPISTOL1:
	dw lo16(_RLFirePistol)	; wsPISTOL1
	db 12
	db wfPISFA0
	dw lo16(wsPISTOL2)
wsPISTOL2:
	dw lo16(_RLWeaponNull)	; wsPISTOL2
	db 10
	db wfPISFB0
	dw lo16(wsPISTOL3)
wsPISTOL3:
	dw lo16(_RLWeaponLight0)	; wsPISTOL3
	db 6
	db wfPISGA0
	dw lo16(wsPISTOL)

;
;	* * * * * * *       SHOTGUN STATE TABLE       * * * * * * *
;
wsSHOTGUNUP:
	dw lo16(_RLRaiseWeapon)	; wsSHOTGUNUP
	db 1
	db wfSHTGA0
	dw lo16(wsSHOTGUNUP)

wsSHOTGUNDOWN:
	dw lo16(_RLLowerWeapon)	; wsSHOTGUNDOWN
	db 1
	db wfSHTGA0
	dw lo16(wsSHOTGUNDOWN)

wsSHOTGUN:
	dw lo16(_RLReadyWeapon)	; wsSHOTGUN
	db 1
	db wfSHTGA0
	dw lo16(wsSHOTGUN)
wsSHOTGUN1:
	dw lo16(_RLWeaponNull)	; wsSHOTGUN1
	db 6
	db wfSHTFA0
	dw lo16(wsSHOTGUN2)
wsSHOTGUN2:
	dw lo16(_RLFireShotGun)	; wsSHOTGUN2
	db 6
	db wfSHTFB0
	dw lo16(wsSHOTGUN3)
wsSHOTGUN3:
	dw lo16(_RLWeaponNull)	; wsSHOTGUN3
	db 6
	db wfSHTFC0
	dw lo16(wsSHOTGUN4)
wsSHOTGUN4:
	dw lo16(_RLWeaponNull)	; wsSHOTGUN4
	db 8
	db wfSHTFD0
	dw lo16(wsSHOTGUN5)
wsSHOTGUN5:
	dw lo16(_RLWeaponLight0)	; wsSHOTGUN5
	db 10
	db wfSHTFE0
	dw lo16(wsSHOTGUN6)
wsSHOTGUN6:
	dw lo16(_RLWeaponNull)	; wsSHOTGUN6
	db 10
	db wfSHTFD0
	dw lo16(wsSHOTGUN7)
wsSHOTGUN7:
	dw lo16(_RLWeaponNull)	; wsSHOTGUN7
	db 10
	db wfSHTFC0
	dw lo16(wsSHOTGUN8)
wsSHOTGUN8:
	dw lo16(_RLWeaponNull)	; wsSHOTGUN8
	db 8
	db wfSHTGA0
	dw lo16(wsSHOTGUN)

;
;	* * * * * * *       CHAINSAW STATE TABLE       * * * * * * *
;
wsCHAINSAWUP:
	dw lo16(_RLRaiseWeapon)	; wsCHAINSAWUP
	db 1
	db wfSAWGA0
	dw lo16(wsCHAINSAWUP)

wsCHAINSAWDOWN:
	dw lo16(_RLLowerWeapon)	; wsCHAINSAWDOWN
	db 1
	db wfSAWGA0
	dw lo16(wsCHAINSAWDOWN)

wsCHAINSAW:
	dw lo16(_RLReadyChainSaw)	; wsCHAINSAW
	db 6
	db wfSAWGA0
	dw lo16(wsCHAINSAW1)
wsCHAINSAW1:
	dw lo16(_RLReadyChainSaw)	; wsCHAINSAW1
	db 6
	db wfSAWGB0
	dw lo16(wsCHAINSAW)
wsCHAINSAW2:
	dw lo16(_RLFireChainSaw)	; wsCHAINSAW2
	db 6
	db wfSAWFA0
	dw lo16(wsCHAINSAW3)
wsCHAINSAW3:
	dw lo16(_RLChainSawNull)	; wsCHAINSAW3
	db 6
	db wfSAWFB0
	dw lo16(wsCHAINSAW)

;
;	* * * * * * *       CHAINGUN STATE TABLE       * * * * * * *
;
wsCHAINGUNUP:
	dw lo16(_RLRaiseWeapon)	; wsCHAINGUNUP
	db 1
	db wfCHGGA0
	dw lo16(wsCHAINGUNUP)

wsCHAINGUNDOWN:
	dw lo16(_RLLowerWeapon)	; wsCHAINGUNDOWN
	db 1
	db wfCHGGA0
	dw lo16(wsCHAINGUNDOWN)

wsCHAINGUN:
	dw lo16(_RLReadyWeapon)	; wsCHAINGUN
	db 1
	db wfCHGGA0
	dw lo16(wsCHAINGUN)
wsCHAINGUN1:
	dw lo16(_RLFireChainGun)	; wsCHAINGUN1
	db 8
	db wfCHGFA0
	dw lo16(wsCHAINGUN2)
wsCHAINGUN2:
	if useWILLIAMS == 0
	dw lo16(_RLWeaponLight0)	; wsCHAINGUN2
	endif
	if useWILLIAMS != 0
	dw lo16(_RLChainGunLight0)	; wsCHAINGUN2
	endif
	db 8
	db wfCHGFB0
	dw lo16(wsCHAINGUN)

;
;	* * * * * * *       ROCKET STATE TABLE       * * * * * * *
;
wsROCKETUP:
	dw lo16(_RLRaiseWeapon)	; wsROCKETUP
	db 1
	db wfMISGA0
	dw lo16(wsROCKETUP)

wsROCKETDOWN:
	dw lo16(_RLLowerWeapon)	; wsROCKETDOWN
	db 1
	db wfMISGA0
	dw lo16(wsROCKETDOWN)

wsROCKET:
	dw lo16(_RLReadyWeapon)	; wsROCKET
	db 1
	db wfMISGA0
	dw lo16(wsROCKET)
wsROCKET1:
	dw lo16(_RLWeaponNull)	; wsROCKET1
	db 6
	db wfMISFA0
	dw lo16(wsROCKET2)
wsROCKET2:
	dw lo16(_RLWeaponNull)	; wsROCKET2
	db 6
	db wfMISFB0
	dw lo16(wsROCKET3)
wsROCKET3:
	dw lo16(_RLWeaponNull)	; wsROCKET3
	db 6
	db wfMISFC0
	dw lo16(wsROCKET4)
wsROCKET4:
	dw lo16(_RLFireRocket)	; wsROCKET4
	db 6
	db wfMISFD0
	dw lo16(wsROCKET5)
wsROCKET5:
	dw lo16(_RLWeaponLight0)	; wsROCKET5
	db 12
	db wfMISFE0
	dw lo16(wsROCKET6)
wsROCKET6:
	dw lo16(_RLWeaponNull)	; wsROCKET6
	db 20
	db wfMISGA0
	dw lo16(wsROCKET)

;
;	* * * * * * *       PLASMA STATE TABLE       * * * * * * *
;
wsPLASMAUP:
	dw lo16(_RLRaiseWeapon)	; wsPLASMAUP
	db 1
	db wfPLSGA0
	dw lo16(wsPLASMAUP)

wsPLASMADOWN:
	dw lo16(_RLLowerWeapon)	; wsPLASMADOWN
	db 1
	db wfPLSGA0
	dw lo16(wsPLASMADOWN)

wsPLASMA:
	dw lo16(_RLReadyWeapon)	; wsPLASMA
	db 1
	db wfPLSGA0
	dw lo16(wsPLASMA)
wsPLASMA1:
	dw lo16(_RLFirePlasma)	; wsPLASMA1
	db 6
	db wfPLSFA0
	dw lo16(wsPLASMA2)
wsPLASMA2:
	dw lo16(_RLWeaponNull)	; wsPLASMA2
	db 6
	db wfPLSFB0
	dw lo16(wsPLASMA3)
wsPLASMA3:
	dw lo16(_RLUseWeapon)	; wsPLASMA3
	db 12
	db wfPLSFC0
	dw lo16(wsPLASMA4)
wsPLASMA4:
	dw lo16(_RLWeaponLight0)	; wsPLASMA4
	db 12
	db wfPLSFC0
	dw lo16(wsPLASMA)

;
;	* * * * * * *       BFG STATE TABLE       * * * * * * *
;
wsBFGUP:
	dw lo16(_RLRaiseWeapon)	; wsBFGUP
	db 1
	db wfBFGGA0
	dw lo16(wsBFGUP)

wsBFGDOWN:
	dw lo16(_RLLowerWeapon)	; wsBFGDOWN
	db 1
	db wfBFGGA0
	dw lo16(wsBFGDOWN)

wsBFG:
	dw lo16(_RLReadyWeapon)	; wsBFG
	db 1
	db wfBFGGA0
	dw lo16(wsBFG)
wsBFG1:
	dw lo16(_RLWeaponNull)	; wsBFG1
	db 30
	db wfBFGGA0
	dw lo16(wsBFG2)
wsBFG2:
	dw lo16(_RLWeaponNull)	; wsBFG2
	db 8
	db wfBFGFA0
	dw lo16(wsBFG3)
wsBFG3:
	dw lo16(_RLFireBFG)	; wsBFG3
	db 8
	db wfBFGFB0
	dw lo16(wsBFG4)
wsBFG4:
	dw lo16(_RLWeaponLight0)	; wsBFG4
	db 6
	db wfBFGGA0
	dw lo16(wsBFG)

	if !RLDOOM2MONSTERS != 0
;
;	* * * * * * *       SUPER SHOTGUN STATE TABLE (DOOM II)       * * * * * * *
;
;	PC (35 Hz): A 3, A 7 fire (flash I 5, J 4), B 7, C 7, D 7 open, E 7, F 7 load,
;	G 6, H 6 close, A 5; here (60 Hz) without C, E, G (tools/wad2cut.py)
;
wsSSGUP:
	dw lo16(_RLRaiseWeapon)
	db 1
	db wfSHT2A0
	dw lo16(wsSSGUP)

wsSSGDOWN:
	dw lo16(_RLLowerWeapon)
	db 1
	db wfSHT2A0
	dw lo16(wsSSGDOWN)

wsSSG:
	dw lo16(_RLReadyWeapon)
	db 1
	db wfSHT2A0
	dw lo16(wsSSG)
wsSSG1:
	dw lo16(_RLWeaponNull)
	db 5
	db wfSHT2A0
	dw lo16(wsSSG2)
wsSSG2:
	dw lo16(_RLFireSuperShotGun)
	db 9
	db wfSHT2FA0
	dw lo16(wsSSG3)
wsSSG3:
	dw lo16(_RLWeaponLight0)
	db 12
	db wfSHT2B0
	dw lo16(wsSSG4)
wsSSG4:
	dw lo16(_RLWeaponNull)
	db 12
	db wfSHT2B0
	dw lo16(wsSSG5)
wsSSG5:
	dw lo16(_RLSSGOpen)
	db 12
	db wfSHT2D0
	dw lo16(wsSSG6)
wsSSG6:
	dw lo16(_RLWeaponNull)
	db 12
	db wfSHT2D0
	dw lo16(wsSSG7)
wsSSG7:
	dw lo16(_RLSSGLoad)
	db 12
	db wfSHT2F0
	dw lo16(wsSSG8)
wsSSG8:
	dw lo16(_RLWeaponNull)
	db 10
	db wfSHT2D0
	dw lo16(wsSSG9)
wsSSG9:
	dw lo16(_RLSSGClose)
	db 10
	db wfSHT2H0
	dw lo16(wsSSG10)
wsSSG10:
	dw lo16(_RLWeaponNull)
	db 8
	db wfSHT2A0
	dw lo16(wsSSG)
	endif
