	arch 65816
;**********************************************************************
;*                                                                    *
;*                  P R O J E C T :   REALITY_ENGINE                  *
;*                                                                    *
;*                      OBJECT MOVEMENT MODULE 8                      *
;*                                                                    *
;*                            ITEM PICKUPS                            *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlweapons.inc"
	incsrc "src/include/music.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


	!rTemp = r12	; Temporary Variable
;
	!rDX = r5	; DeltaX
	!rDY = r6	; DeltaY
;
	!rX0 = r7	; Initial Object X Coordinate
	!rY0 = r8	; Initial Object Y Coordinate
	!rX1 = r9	;   Final Object X Coordinate
	!rY1 = r10	;   Final Object Y Coordinate
;
	!rMoveLinesPtr = r11	; MoveLines Pointer
;
	!rLX0 = r3	; Line X0 Coordinate
	!rLY0 = r13	; Line Y0 Coordinate
	!rLDY = r14	; Line Delta Y
;
	!rObj = r12	; Pointer to RLObject
	!rSectorData = r9	; Pointer to Object's SectorData


;
;	* * * * * * *       BACKPACK       * * * * * * *
;
_IBackPack:
	ibt r1,#lo16(BackPack)	; Give Player BackPack
	assert (lo16(BackPack))&$FFFF < $80 || (lo16(BackPack))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	ibt r0,#1
;	from	r0
	stb (r1)
;
	ibt r4,#10
	link #4
	with r11
	bra _IClip3
	to r12
;
	ibt r4,#4
	link #4
	with r11
	bra _IShells3
	to r12
;
	ibt r4,#1
	link #4
	with r11
	bra _IRocket3
	to r12
;
	ibt r4,#20
	iwt r11,#lo16(_RM7XY8000)
	move r12,r11
	iwt r15,#lo16(_ICell3)	; (long jump: out of branch range)
	nop

;
;	* * * * * * *       CLIP       * * * * * * *
;
_IClip:
	ibt r4,#5
	bra _IClip2
	nop
;
;	* * * * * * *       AMMO BOX       * * * * * * *
;
_IAmmoBox:
	ibt r4,#50
_IClip2:
	iwt r12,#lo16(_RM7XY1000)
_IClip3:
	lms r0,(SkillLevel&$FFFF)	; Easy/Nightmare: double ammo (this port, as PC DOOM)
	%and_i(3)
	bne _IClipDbl
	nop
	with r4
	add r4
_IClipDbl:
	ibt r0,#lo16(BackPack)	; Does Player have BackPack?
	assert (lo16(BackPack))&$FFFF < $80 || (lo16(BackPack))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;	to	r0
	ldb (r0)
	iwt r1,#200	; 200 Max. Bullets
	dec r0
	bmi _IClip4
	with r1	; Yes, Double the Max
	add r1
_IClip4:
	lms r0,(WeaponBullets&$FFFF)
;	from	r0				; >= Max?
	to r1
	sub r1
	bpl _IRocket9	; Yes
;	with	r0				; Beyond Maximum?
	add r4
	with r1
	add r4
	bmi _IClip5
	with r0	; Yes, Limit to Maximum!
	sub r1
_IClip5:
	jmp r11
;	from	r0
	sbk

;
;	* * * * * * *       SHELLS       * * * * * * *
;
_IShells:
	ibt r4,#4
	bra _IShells2
	nop
;
;	* * * * * * *       SHELLS BOX       * * * * * * *
;
_IShellsBox:
	ibt r4,#20
_IShells2:
	iwt r12,#lo16(_RM7XY1000)
_IShells3:
	lms r0,(SkillLevel&$FFFF)	; Easy/Nightmare: double ammo (this port, as PC DOOM)
	%and_i(3)
	bne _IShellsDbl
	nop
	with r4
	add r4
_IShellsDbl:
	ibt r0,#lo16(BackPack)	; Does Player have BackPack?
	assert (lo16(BackPack))&$FFFF < $80 || (lo16(BackPack))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;	to	r0
	ldb (r0)
	ibt r1,#50	; 50 Max. Shells
	dec r0
	bmi _IShells4
	with r1	; Yes, Double the Max
	add r1
_IShells4:
	lms r0,(WeaponShells&$FFFF)
;	from	r0				; >= Max?
	to r1
	sub r1
	bpl _IRocket9	; Yes
;	with	r0				; Beyond Maximum?
	add r4
	with r1
	add r4
	bmi _IShells5
	with r0	; Yes, Limit to Maximum!
	sub r1
_IShells5:
	jmp r11
;	from	r0
	sbk

;
;	* * * * * * *       ROCKET       * * * * * * *
;
_IRocket:
	ibt r4,#1
	bra _IRocket2
	nop
;
;	* * * * * * *       ROCKETS BOX       * * * * * * *
;
_IRocketsBox:
	ibt r4,#5
_IRocket2:
	iwt r12,#lo16(_RM7XY1000)
_IRocket3:
	lms r0,(SkillLevel&$FFFF)	; Easy/Nightmare: double ammo (this port, as PC DOOM)
	%and_i(3)
	bne _IRocketDbl
	nop
	with r4
	add r4
_IRocketDbl:
	ibt r0,#lo16(BackPack)	; Does Player have BackPack?
	assert (lo16(BackPack))&$FFFF < $80 || (lo16(BackPack))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;	to	r0
	ldb (r0)
	ibt r1,#50	; 50 Max. Rockets
	dec r0
	bmi _IRocket4
	with r1	; Yes, Double the Max
	add r1
_IRocket4:
	lms r0,(WeaponRockets&$FFFF)
;	from	r0				; >= Max?
	to r1
	sub r1
	bpl _IRocket9	; Yes
;	with	r0				; Beyond Maximum?
	add r4
	with r1
	add r4
	bmi _IRocket5
	with r0	; Yes, Limit to Maximum!
	sub r1
_IRocket5:
	jmp r11
;	from	r0
	sbk
_IRocket9:
	jmp r12
	nop

;
;	* * * * * * *       CELL       * * * * * * *
;
_ICell:
	ibt r4,#20
	bra _ICell2
	nop
;
;	* * * * * * *       CELL PACK       * * * * * * *
;
_ICellPack:
	ibt r4,#100
_ICell2:
	iwt r12,#lo16(_RM7XY1000)
_ICell3:
	lms r0,(SkillLevel&$FFFF)	; Easy/Nightmare: double ammo (this port, as PC DOOM)
	%and_i(3)
	bne _ICellDbl
	nop
	with r4
	add r4
_ICellDbl:
	ibt r0,#lo16(BackPack)	; Does Player have BackPack?
	assert (lo16(BackPack))&$FFFF < $80 || (lo16(BackPack))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;	to	r0
	ldb (r0)
	iwt r1,#300	; 300 Max. Cells
	dec r0
	bmi _ICell4
	with r1	; Yes, Double the Max
	add r1
_ICell4:
	lms r0,(WeaponCells&$FFFF)
;	from	r0				; >= Max?
	to r1
	sub r1
	bpl _IRocket9	; Yes
;	with	r0				; Beyond Maximum?
	add r4
	with r1
	add r4
	bmi _ICell5
	with r0	; Yes, Limit to Maximum!
	sub r1
_ICell5:
	jmp r11
;	from	r0
	sbk

;
;	* * * * * * *       SOUL SPHERE       * * * * * * *
;
_ISoulSphere:
	ibt r4,#-100	; +100%
	iwt r1,#200	; Max 200%
	iwt r12,#lo16(_RM7XY1000)
	bra _IHealth2
	nop
;
;	* * * * * * *       HEALTH BONUS       * * * * * * *
;
_IHealthBonus:
	ibt r4,#-1	; +1%
	iwt r1,#200	; Max 200%
	with r11
	bra _IHealth2
	to r12
;
;	* * * * * * *       STIMPACK       * * * * * * *
;
_IStimPack:
	ibt r4,#-10	; +10%
	iwt r12,#lo16(_RM7XY1000)
	bra _IHealth	; Max 100%
	nop
;
;	* * * * * * *       MEDIKIT       * * * * * * *
;
_IMediKit:
	ibt r4,#-25
	iwt r12,#lo16(_RM7XY1000)
_IHealth:
	ibt r1,#100	; Maximum
_IHealth2:
;
	if useMULTIPLAYER == 0
	lm r0,(PlayerObject+rloHealth&$FFFF)	; Get Player's Health
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloHealth
	lms r2,(MPPlayerObject&$FFFF)
;	with	r0
	add r2
;	to	r0
	ldw (r0)
	endif
;
;	with	r0				; Already got Max?
	sub r1
	bpl _IHealth9	; Yes, don't add more!
;	with	r0				; More than Max?
	sub r4
	bmi _IHealth5	; No
	with r4	; Yes!  Only up to Max!
	add r0
_IHealth5:
	iwt r15,#lo16(_RLSubHealth)
	nop
_IHealth9:
	jmp r12
	nop

;
;	* * * * * * *       ARMOR BONUS       * * * * * * *
;
_IArmorBonus:
	ibt r4,#1	; +1%
	iwt r1,#200	; Max 200%
	with r11
	bra _IArmor2
	to r12
;
;	* * * * * * *       ARMOR GREEN       * * * * * * *
;
_IArmorGreen:
	ibt r4,#100	; +100%
	with r4	; Max 100%
	bra _IArmor
	to r1
;
;	* * * * * * *       ARMOR BLUE       * * * * * * *
;
_IArmorBlue:
	iwt r4,#200	; +200%
	move r1,r4	; Max 200%
_IArmor:
	iwt r12,#lo16(_RM7XY1000)
_IArmor2:
	lms r0,(PlayerArmor&$FFFF)	; Get Player's Armor
;	from	r0				; >= Max?
	to r1
	sub r1
	bpl _IArmor9	; Yes
;	with	r0				; Beyond Max?
	add r4
	with r1
	add r4
	bmi _IArmor5
	with r0	; Yes, Limit to Maximum!
	sub r1
_IArmor5:
	jmp r11
;	from	r0
	sbk
_IArmor9:
	jmp r12
	nop

;
;	* * * * * * *       KEYS       * * * * * * *
;
_IKeySkullRed:
	ibt r4,#%00100000	; RED SKULLKEY
	bra _IKey
	nop
_IKeySkullBlue:
	ibt r4,#%00000010	; BLUE SKULLKEY
	bra _IKey
	nop
_IKeySkullYellow:
	ibt r4,#%00001000	; YELLOW SKULLKEY
	bra _IKey
	nop
_IKeyCardRed:
	ibt r4,#%00010000	; RED KEYCARD
	bra _IKey
	nop
_IKeyCardBlue:
	ibt r4,#%00000001	; BLUE KEYCARD
	bra _IKey
	nop
_IKeyCardYellow:
	ibt r4,#%00000100	; YELLOW KEYCARD
_IKey:
	iwt r6,#lo16(PlayerKeys)	; Give Player Key
;	to	r0
	ldb (r6)
;	with	r0
	or r4
;	from	r0
	stb (r6)
	jmp r11
	nop

;
;	* * * * * * *       WEAPONS       * * * * * * *
;
_IBFG9000:
	ibt r4,#40	; BFG9000
	iwt r3,#wtbBFG
	ibt r2,#wtBFG
	iwt r11,#lo16(_IWeapon)
	move r12,r11
	iwt r15,#lo16(_ICell3)
	nop
_IPlasmaGun:
	ibt r4,#40	; PLASMA GUN
	ibt r3,#wtbPlasma
	ibt r2,#wtPlasma
	iwt r11,#lo16(_IWeapon)
	move r12,r11
	iwt r15,#lo16(_ICell3)
	nop
_IRocketGun:
	ibt r4,#2	; ROCKET LAUNCHER
	ibt r3,#wtbRocket
	ibt r2,#wtRocket
	iwt r11,#lo16(_IWeapon)
	move r12,r11
	iwt r15,#lo16(_IRocket3)
	nop
_IChainGun:
	ibt r4,#20	; CHAINGUN
	ibt r3,#wtbChainGun
	ibt r2,#wtChainGun
	iwt r11,#lo16(_IWeapon)
	move r12,r11
	iwt r15,#lo16(_IClip3)
	nop
_IChainSaw:
	ibt r3,#wtbChainSaw	; CHAINSAW
	ibt r2,#wtChainSaw
	bra _IWeapon
	nop
_IShotGun:
	ibt r4,#4	; SHOTGUN
	ibt r3,#wtbShotGun
	ibt r2,#wtShotGun
	iwt r11,#lo16(_IWeapon)
	move r12,r11
	iwt r15,#lo16(_IShells3)
	nop
	if !RLDOOM2MONSTERS != 0
;
;	SUPER SHOTGUN (DOOM II): 8 shells (PC: two loads of 4), PlayerKeys bit 7, and the
;	Shotgun's bit (the weapon cycle reaches the Super Shotgun from the Shotgun)
;
_ISuperShotGun:
	ibt r4,#8
	iwt r11,#lo16(_ISSGWeapon)
	move r12,r11
	iwt r15,#lo16(_IShells3)
	nop
_ISSGWeapon:
	iwt r6,#lo16(PlayerArms)	; + the Shotgun
	ldb (r6)
	ibt r1,#wtbShotGun
	or r1
	stb (r6)
	iwt r6,#lo16(PlayerKeys)	; Had it already?
	ldb (r6)
	sex
	bmi _ISSG8
	nop
	iwt r1,#pkSuperShotGun
	or r1
	stb (r6)
	ibt r2,#wtSuperShotGun	; No!  Switch to it!
	sms (WeaponNext&$FFFF),r2
	iwt r11,#lo16(_RM7XY8000)
	iwt r15,#lo16(_RLDropWeapon)
	nop
_ISSG8:
	iwt r15,#lo16(_RM7XY8000)
	nop
	endif
_IWeapon:
	iwt r6,#lo16(PlayerArms)	; Give Player Weapon
;	to	r0
	ldb (r6)
;	from	r0
	to r1
	or r3
;	with	r0				; Did Player Already Have Weapon?
	and r3
	iwt r11,#lo16(_RM7XY8000)
	from r1
	alt1
	beq _IWeapon5	; No!  Switch to New Weapon!
	stw (r6)
;	stb	(r6)
	jmp r11
	nop
_IWeapon5:
	sms (WeaponNext&$FFFF),r2	; Switch to New Weapon!
	iwt r15,#lo16(_RLDropWeapon)
	nop

;
;	* * * * * * *       BERSERK       * * * * * * *
;
_IBerserk:
	iwt r0,#(60*60)	; VBlanks
	sms (BerserkCount&$FFFF),r0
	if useID4 != 0
	sms (Berserk&$FFFF),r0
	endif
	ibt r1,#100	; Maximum
	ibt r4,#-100
;
	if useMULTIPLAYER == 0
	lm r0,(PlayerObject+rloHealth&$FFFF)	; Get Player's Health
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloHealth
	lms r2,(MPPlayerObject&$FFFF)
;	with	r0
	add r2
;	to	r0
	ldw (r0)
	endif
;
;	with	r0				; Already got Max?
	sub r1
	bpl _IBerserk5	; Yes, don't add more!
;	with	r0				; More than Max?
	sub r4
	bmi _IBerserk2	; No
	with r4	; Yes!  Only up to Max!
	add r0
_IBerserk2:
	link #4
	iwt r15,#lo16(_RLSubHealth)
	nop
_IBerserk5:
	ibt r0,#wtFist	; Switch to Fist!
	sms (WeaponNext&$FFFF),r0
	link #4
	iwt r15,#lo16(_RLDropWeapon)
	nop
	ibt r0,#rgbBerserk	; Use Berserk Strength RGBAnim
	iwt r15,#lo16(_RM7XY8200)
	nop

;
;	* * * * * * *       RADIATION SUIT       * * * * * * *
;
_IRadiation:
	iwt r0,#(60*60)	; #VBlanks
	sms (RadCount&$FFFF),r0
	ibt r0,#rgbRad	; Use Radiation Suit RGBAnim
	iwt r15,#lo16(_RM7XY8200)
	nop

;
;	* * * * * * *       INVISIBILITY       * * * * * * *
;
_IInvisible:
	iwt r0,#(60*60)	; #VBlanks
	sms (InvisibleCount&$FFFF),r0
	jmp r11
	nop

;
;	* * * * * * *       INVULNERABILITY       * * * * * * *
;
_IInvulnerable:
	iwt r0,#(60*60)	; #VBlanks
	sms (InvulnerableCount&$FFFF),r0
	link #4	; ReCalculate Face Animation
	iwt r15,#lo16(_RLCalcFaceAnim)
	nop
	iwt r15,#lo16(_RM7XY8000)
	nop

;
;	* * * * * * *       COMPUTER MAP       * * * * * * *
;
_IComputerMap:
	ibt r1,#lo16(ComputerMap)	; Give Player ComputerMap
	assert (lo16(ComputerMap))&$FFFF < $80 || (lo16(ComputerMap))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	ibt r0,#1
;	from	r0
	stb (r1)
	jmp r11
	nop

;
;	* * * * * * *       LIGHT GOGGLES       * * * * * * *
;
_ILightGoggles:
	iwt r0,#(60*60)	; #VBlanks
	sms (LightGoggles&$FFFF),r0
	jmp r11
	nop
