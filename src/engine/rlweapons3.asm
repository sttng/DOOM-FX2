	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                      WEAPONS HANDLING MODULE 3                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/rlenemies.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/music.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


;
;	* * * * * * *       CREATE TARGET LIST       * * * * * * *
;
	!rPAngle = r3	; (PlayerAngle-$4000)
	!rY = r4	; |DeltaY|
	!rX = r6	; |DeltaX|
	!rDeltaX = r5	; DeltaX
	!rDeltaY = r7	; DeltaY
	!rSwap = r8	; 0=DeltaX/DeltaY NOT Swapped
	!rrlpfFlags = r13	; RLObject Target/Movable Flags

	!rTargetListPtr = r10	; Pointer to TargetList
	!rObj = r12	; Pointer to Current RLObject
	!rVObj = r9	; Pointer to Current VisibleObject

	%align_pad(4, 16, (_RLFE9200-_RLFireTargetAlign)&$0F)	; align 16,(_RLFE9200-_RLFireTargetAlign)&$0f
;
;	>>>   FINISHED CREATING TARGET LIST   <<<
;
_RLFE9200:
	nop	; @FLUSH ALT2 IN PIPELINE@
;	with	r0				; Terminate TargetList
	sub r0
	jmp r11
;	from	r0
	stw (!rTargetListPtr)

;
;	>>>   START CREATING TARGET LIST   <<<
;
_RLFireTarget:
	iwt !rrlpfFlags,#(rlpfActive|rlpfTarget)	; RLObject TARGETTING Flags
_RLFireTarget2:
	iwt !rVObj,#lo16(VObjListStart-1)	; START of VObjList
	iwt !rTargetListPtr,#lo16(_RLTargetList)	; START of TargetList
	if useMULTIPLAYER == 0
	lm !rPAngle,(PlayerObject+rloAngle&$FFFF)	; Get PlayerAngle
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloAngle	; Get PlayerAngle
	lms !rPAngle,(MPPlayerObject&$FFFF)
;	with	r0
	add !rPAngle
	to !rPAngle
	ldw (r0)
	endif
	iwt r0,#$4000
	with !rPAngle
	sub r0

	%CACHEB(_RLFireTarget)
_RLFireTargetAlign:
;
;	>>>   NEXT VISIBLE OBJECT   <<<
;
_RLFE2200:
	inc !rVObj	; Next VObj
;	to	r0				; Get VObj.Next
	ldw (!rVObj)
	moves !rVObj,r0
	beq _RLFE9200	; No More VisibleObjects!
;
;	>>>   GET OBJECT   <<<
;
;	with	r0				; Get RLObject
	%add_i(rlqObj)
	to !rObj
	ldw (r0)
	from !rObj
;	to	r0
	%add_i(rloFlags)
;	to	r0				; Get RLObject Flags
	ldb (r0)
;	with	r0				; VALID TARGET?
	and !rrlpfFlags
;	with	r0
	sub !rrlpfFlags
	bne _RLFE2200	; No!
	inc !rVObj	; Move to VObj.Next
;
;	>>>   WAS THIS VISIBLE OBJECT DRAWN?   <<<
;
	ibt r0,#(rlqDrawn-(rlqY+1))	; Get VObj.Drawn
;	with	r0
	add !rVObj
;	to	r0
	ldb (r0)
	dec r0	; Drawn?
	bmi _RLFE2200	; NO!  CAN'T TARGET IT!
	nop
;
;	>>>   GET ANGLE TO TARGET   <<<
;
	dec !rVObj	; Move back to VObj.Y
	to !rDeltaY	; Rotated Object World Y
	ldw (!rVObj)
	from !rVObj	; Rotated Object World X
;	to	r0
	%add_i(rlqWX)
	to !rDeltaX
	ldw (r0)
;
;	>>>   SAVE TARGET OBJECT   <<<
;
	moves !rX,!rDeltaX	; DeltaX = 0?
;
	from !rVObj	; Save TargetVObject
	bne _RLFE4200	; NO!
	stw (!rTargetListPtr)
;
	iwt r0,#$4000	; YES!  90 degrees
	bra _RLFE4800
	nop
_RLFE4200:
	bpl _RLFE4220
	with !rX	; |DeltaX|
	not
	inc !rX
_RLFE4220:
	moves !rY,!rDeltaY	; DeltaY = 0?
	bne _RLFE4400
	moves !rDeltaX,!rDeltaX	; Always 0 or 180 degrees
;	with	r0
	bpl _RLFE4800	; 0 degrees
	sub r0
	iwt r0,#$8000	; 180 degrees
	bra _RLFE4800
_RLFE4400:
	nop	; @FLUSH WITH IN PIPELINE@
;
;	>>>   ENSURE RESULTS ARE FROM 0.0 TO 1.0   <<<
;
	from !rY	; |DeltaY| < |DeltaX|?
;	to	r0
	sub !rX
	bne _RLFE4440
	with !rSwap	; Didn't Swap
	iwt r0,#$2000	; |DeltaY| = |DeltaX| (45 Degrees)
	bra _RLFE4500
	nop
_RLFE4440:
	blt _RLFE4460	; Yes
	sub !rSwap
	move r0,!rX	; No, Swap |DeltaY| / |DeltaX|
	move !rX,!rY
	move !rY,r0
	inc !rSwap
;
;	>>>   GET SLOPE |DELTAY| / |DELTAX|   <<<
;
_RLFE4460:
	ibt r0,#bank(InvTable)	; Get InverseTable Entry
	romb
	from !rX	; Get |DeltaX|
;	to	r0
	add !rX
	iwt r1,#lo16(InvTable-2)
;	from	r0
	to r14
	add r1
	dec r0
	dec r0
	to r6	; Get Inverse Value
	getb
	inc r14
;	with	r0				; Low/High Gear?
	hib
	with r6
	getbh
	bne _RLFE4470	; High
	from !rY	; Low
;	to	r0
	lmult
	with r4
	bra _RLFE4480
	to r0
_RLFE4470:
;	to	r0				; <<1
	add !rY
;	with	r0
	lmult
	with r4
	hib
;	with	r0
	lob
;	with	r0
	swap
;	with	r0
	add r4
_RLFE4480:
;	with	r0				; Get Index into |ArcTan| Table
	lsr
	lsr
	lsr
	lsr
;	from	r0
	to r1
	bic #1
	ibt r0,#bank(PArcTanTable)	; Get |ArcTan| Table Entry
	romb
	iwt r0,#lo16(PArcTanTable)
;	from	r0
	to r14
	add r1
	getb	; Get Angle
	inc r14
	dec !rSwap	; Were DeltaX/DeltaY Swapped?
	alt1
	bne _RLFE4500	; No
	getb
;
;	>>>   DETERMINE QUADRANT   <<<
;
;	with	r0				; Yes, 90-Angle
	not
	inc r0
	iwt r1,#$4000
;	with	r0
	add r1
_RLFE4500:
	moves !rDeltaX,!rDeltaX	; DeltaX >= 0?
	bpl _RLFE4800	; Quad0
	nop
	iwt r1,#$8000	; 180-Angle
	from r1
;	to	r0
	sub r0
;
;	>>>   SAVE ANGLE TO TARGET   <<<
;
_RLFE4800:
	inc !rTargetListPtr
	inc !rTargetListPtr
;	with	r0				; Angle+(PlayerAngle-$4000)
	add !rPAngle
;	from	r0				; Angle to Target
	stw (!rTargetListPtr)
	inc !rTargetListPtr
;
;	>>>   ESTIMATE DISTANCE TO TARGET   <<<
;
	moves r0,!rDeltaX	; |DeltaX|
	bpl _RLFE5200
	inc !rTargetListPtr
;	with	r0
	not
	inc r0
_RLFE5200:
	moves r1,!rDeltaY	; |DeltaY|
	bpl _RLFE5220
	nop
	with r1
	not
	inc r1
_RLFE5220:
;	from	r0				; |X| >= |Y|?
	cmp r1
	bge _RLFE5280	; Yes
	from r0
	from r1	; |Y| > |X|
;
;	>>>   SAVE DISTANCE TO TARGET   <<<
;
_RLFE5280:
;	from	r0				; Distance to Target
	stw (!rTargetListPtr)
	inc !rTargetListPtr
	inc !rTargetListPtr
	iwt r15,#lo16(_RLFE2200)	; NEXT VISIBLE OBJECT!
	inc !rVObj	; Move to VObj.Next

	%CACHEE(_RLFireTarget)


;
;	* * * * * * *       LAUNCH PROJECTILE FROM WEAPON       * * * * * * *
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE   !!!
;
	!rSoundEffect = r3	; Sound Effect
	!rDamage = r4	; Damage Multiplier / Points
	!rAmmoCount = r5	; Ammo to Subtract
;
	!rTargetListPtr = r8	; Pointer to TargetList
	!rTDistance = r9	; Best Distance to Target
	!rDistance = r12	; Distance to Current Target
	!rMObjData = r11	; Birth RLObject MObjData
	!rPObj = r10	; Player RLObject
	!rObj = r12	; Projectile RLObject
	!rTObj = r7	; Target RLObject
	!rMinX = r6	; Minimum Screen Column
	!rMaxX = r13	; Maximum Screen Column
;
;rSector	var	r6			; Birth RLObject Sector
	!rX = r7	; Birth RLObject X Coordinate
	!rY = r8	; Birth RLObject Y Coordinate
;
;	* * * * * * *       FIRE ROCKET       * * * * * * *
;
_RLFireRocket:
	iwt !rrlpfFlags,#(rlpfActive|rlpfTarget|rlpfMovable)	; RLObject TARGETTING Flags
	link #4	; Create TargetList
	if usePATCH == 0
	iwt r15,#lo16(_RLFireTarget2)
	endif
	if usePATCH != 0
	lms r15,(PTRLFireTarget2&$FFFF)
	endif
	nop
	ibt !rSoundEffect,#firsht_eff	; Sound Effect
	ibt !rAmmoCount,#1	; #Ammo to subtract
	ibt r0,#16	; Light Level
	iwt r7,#lo16(modMissile)	; Birth a MISSILE
	bra _RLFireProjectile
	nop
;
;	* * * * * * *       FIRE PLASMA       * * * * * * *
;
_RLFirePlasma:
	iwt !rrlpfFlags,#(rlpfActive|rlpfTarget|rlpfMovable)	; RLObject TARGETTING Flags
	link #4	; Create TargetList
	if usePATCH == 0
	iwt r15,#lo16(_RLFireTarget2)
	endif
	if usePATCH != 0
	lms r15,(PTRLFireTarget2&$FFFF)
	endif
	nop
	ibt !rSoundEffect,#firsht_eff	; Sound Effect
	ibt !rAmmoCount,#1	; #Ammo to subtract
	ibt r0,#24	; Light Level
	iwt r7,#lo16(modPlasma)	; Birth a PLASMA
	bra _RLFireProjectile
	nop
;
;	* * * * * * *       FIRE BFG9000       * * * * * * *
;
	%align_pad(10, 16, (_RLFireBFG-_RLFireProjectileAlign)&$0F)	; align 16,(_RLFireBFG-_RLFireProjectileAlign)&$0f
_RLFireBFG:
	iwt !rrlpfFlags,#(rlpfActive|rlpfTarget|rlpfMovable)	; RLObject TARGETTING Flags
	link #4	; Create TargetList
	if usePATCH == 0
	iwt r15,#lo16(_RLFireTarget2)
	endif
	if usePATCH != 0
	lms r15,(PTRLFireTarget2&$FFFF)
	endif
	nop
	ibt !rSoundEffect,#firsht_eff	; Sound Effect
	ibt !rAmmoCount,#40	; #Ammo to subtract
	ibt r0,#32	; Light Level
	iwt r7,#lo16(modBFG)	; Birth a BFG
;
;	* * * * * * *       LAUNCH PROJECTILE FROM WEAPON       * * * * * * *
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE   !!!
;
_RLFireProjectile:
	ibt r1,#lo16(WeaponLight)	; LIGHT CREATED BY WEAPON
	assert (lo16(WeaponLight))&$FFFF < $80 || (lo16(WeaponLight))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;	from	r0
	stb (r1)
;
	lms r0,(RLNumPObjs&$FFFF)	; Get #ProjectileRLObjects
	ibt r1,#(MaxRLMoveProjectiles-1)
;	with	r0
	sub r1
	blt _RLFP1100
	nop
	iwt r15,#lo16(_RLFP9200)	; YES!  TOO MANY RLPOBJECTS!
	nop
_RLFP1100:
	lms r0,(RLNumMObjs&$FFFF)	; Get #MovableRLObjects
	iwt r1,#(MaxRLMObjects-1)	; Too Many RLMObjs? (iwt: more than 127 slots)
;	from	r0
	cmp r1
	blt _RLFP1200	; No!  Add this Projectile!
	inc r0	; MovableRLObjects++
	iwt r15,#lo16(_RLFP9200)	; YES!  TOO MANY RLMOBJECTS!
	nop
_RLFP1200:
;	from	r0
	sbk
;
;	>>>   UPDATE AMMO COUNT   <<<
;
	lms r0,(WeaponAmmo&$FFFF)	; Get Address of Ammo
;	to	r0				; Get Ammo Amount
	ldw (r0)
;	with	r0
	sub !rAmmoCount
	bpl _RLFP1400
	nop
;	with	r0
	sub r0
;
;	>>>   MAKE SOUND EFFECT   <<<
;
_RLFP1400:
	link #4	; Make Sound Effect
	iwt r15,#lo16(_RLPlayerSoundEffect)
;	from	r0				; Update Ammo Amount
	sbk
	link #4	; (this port) Rumble: the weapon's fire effect, as FX3
	iwt r15,#lo16(_RLWeaponRumble)
	nop
;
;	>>>   ACQUIRE TARGET OBJECT   <<<
;
_RLFP1600:
	move !rMObjData,r7	; Birth RLObject MObjData
	iwt !rTargetListPtr,#lo16(_RLTargetList-2)	; START of TargetList
	iwt !rTDistance,#$7FFF	; Maximum Distance to Target
	ibt !rTObj,#0	; Target RLObject
	if useMULTIPLAYER == 0
	iwt !rPObj,#lo16(PlayerObject)	; Player RLObject
	endif
	if useMULTIPLAYER != 0
	lms !rPObj,(MPPlayerObject&$FFFF)	; Player RLObject
	endif
	ibt !rMinX,#(((RLViewPixX/2)-16)>>1)	; Minimum Screen Column>>1
	ibt !rMaxX,#((RLViewPixX/2)+16)	; Maximum Screen Column

	%CACHEB(_RLFireProjectile)
_RLFireProjectileAlign:	; @ALIGNMENT ABOVE!@
;
;	>>>   NEXT TARGETTED OBJECT   <<<
;
_RLFP2200:
	inc !rTargetListPtr
	inc !rTargetListPtr
;	to	r0				; Get Next Target
	ldw (!rTargetListPtr)
	moves r1,r0	; Any More Targets?
	beq _RLFP3000	; No!
	with !rTargetListPtr	; Move to Distance
	%add_i((4-1))
;
;	>>>   WITHIN TARGETTING ANGLE RANGE?   <<<
;
	with r1	; Screen X1 (rXs1)
	%add_i(rlqXs1)
;	to	r0
	ldw (r1)
;	with	r0
	sub !rMaxX
	bpl _RLFP2200	; Not in range
	inc !rTargetListPtr
	inc r1	; Screen X2 (rXs2)
	inc r1
;	to	r0
	ldw (r1)
;	with	r0
	sub !rMinX
	bmi _RLFP2200
	nop
;
;	>>>   CLOSER THAN BEST TARGET?   <<<
;
;	to	r0				; Get Distance
	ldw (!rTargetListPtr)
;	from	r0				; < Best Distance?
	cmp !rTDistance
	bge _RLFP2200	; No
	move !rDistance,r0
;
;	>>>   NEW BEST TARGET   <<<
;
	move !rTObj,!rTargetListPtr	; Found It!
	with !rDistance
	bra _RLFP2200
	to !rTDistance
;
;	>>>   FIND EMPTY MOVABLE OBJECT   <<<
;
_RLFP3000:
	iwt r2,#lo16(_RLMObjects-rloSize)	; RLMovableObjects
	ibt r1,#rloSize	; Size of RLMovableObject
_RLFP3200:
	with r2	; Move to Next MObj
	add r1
;	to	r0				; Find Empty MObj
	ldw (r2)
	inc r0
	bne _RLFP3200+1	; Check Next MObj
	move !rObj,r2	; Save MObj
;
;	>>>   FIND EMPTY MOVABLE OBJECT PROCESSING SLOT   <<<
;
	iwt r1,#lo16(_RLMObjs-1)	; MovableObjects Processing List
_RLFP3400:
	inc r1
;	to	r0				; Find Empty MObj Processing Slot
	ldw (r1)
	inc r0
	bne _RLFP3400	; Check Next MObj
	inc r1

	%CACHEE(_RLFireProjectile)

;
;	>>>   ADD MOVABLE OBJECT TO PROCESSING LIST   <<<
;
	dec !rObj	; Save RLObject
	dec r1
	from !rObj
	stw (r1)
	inc !rObj
	lms r0,(RLNumPMObjs&$FFFF)	; #Processing MObjs++
	inc r0
;	from	r0
	sbk
;
;	>>>   INITIALIZE MOVABLE OBJECT   <<<
;
	ibt r0,#bank(_MObjData)	; MObjData Bank
	romb
	from !rMObjData	; Get Birth State
	to r14
	%add_i(rlmodBirthS)
;
	ibt r4,#rloMData	; Move to MObjData
	with r4
	add !rObj
	from !rMObjData	; MObjData
	stw (r4)
	dec r4
	dec r4
	getb	; State
	inc r14
	getbh
	inc r14
;	from	r0
	stw (r4)
	dec r4
	dec r4
;	with	r0				; AnimCount/StateCount
	sub r0
;	from	r0
	stw (r4)
	dec r4
	dec r4
	getb	; Animation
	inc r14
	to r2
	getbh
	ibt r3,#(rlmodBirthFlags-(rlmodBirthA+1))
	with r3
	add r14
	from r2	; Get Animation First Frame
	to r14
	add #1
	from r2
	stw (r4)
	dec r4	; Image
	getb
	move r14,r3	; Get BirthFlags/BirthType
;	from	r0				; Image
	stb (r4)
	getb	; BirthFlags
	inc r14
	from !rObj
	to r4
	%add_i(rloFlags)
	getbh	; BirthType
;	from	r0				; Flags/Type
	stw (r4)
;
	ibt r3,#rloVXY	; Velocity X/Y
	with r3
	add !rObj
	iwt r0,#($8000+(16>>1))
;	from	r0
	stw (r3)
	dec r3
	dec r3
;
;	>>>   TARGET ACQUIRED?   <<<
;
	if useMULTIPLAYER == 0
	lm r1,(PlayerObject+rloAngle&$FFFF)	; Get PlayerAngle
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloAngle	; Get PlayerAngle
	lms r1,(MPPlayerObject&$FFFF)
;	with	r0
	add r1
	to r1
	ldw (r0)
	endif
	moves !rTObj,!rTObj	; Target Acquired? (test 0, not the sign:
	beq _RLFP5400	; the target list can lie above $8000)  NO!  NO Z VELOCITY!
;	with	r0
	sub r0
	dec !rTObj
;
;	>>>   CALCULATE VELOCITY Z FOR INTERCEPTION   <<<
;
	move r3,!rPObj	; R3 = Source Object
	with !rTObj	; Get Target VObj
	sub #3
;	to	r0
	ldw (!rTObj)
;	with	r0				; Get Target RLObject
	%add_i(rlqObj)
	to r5	; R5 = Target Object
	ldw (r0)
	from !rTObj	; Get Target Angle
;	to	r0
	add #2
	link #4
	iwt r15,#lo16(_RLGetObjTObjDistance)	; Get Distance from Player to Target
;	to	r0
	ldw (r0)
;
;	from	r0				; TargetDistance
	to r4
	add r0
	ibt r0,#bank(InvTable)	; Get InverseTable Entry
	romb
	iwt r0,#lo16(InvTable-2)
;	from	r0
	to r14
	add r4
;
;	to	r0				; TargetVObj
	ldw (!rTObj)
;	with	r0				; TargetZ
	%add_i(rlqWZ)
;	to	r0				; WZ = (OZ-(PZ+PH))
	ldw (r0)
	lms r1,(PlayerHeight&$FFFF)	; Get (TargetZ-PlayerZ)
;	with	r0
	add r1
;
;	>>>   GET VELOCITY Z ((dZ*VelocityXY)/Distance)   <<<
;
;	with	r0				; R2 = (DZ*VelocityXY)
	add r0
	add r0
	add r0
	add r0
;	add	r0
;	from	r0				; <<1 for Divide
	to r2
	add r0
;
	getb
	inc r14
;
	inc !rTObj	; TargetAngle
	inc !rTObj
	to r1
	ldw (!rTObj)
	ibt r3,#rloVZ	; Move to Velocity Z
	with r3
	add !rObj
;
	dec r4
	dec r4
	with r4	; Low/High Gear?
	hib
	to r6
	getbh
	bne _RLFP5200	; High
	from r2	; Low
;	to	r0
	alt1
	bra _RLFP5400
	fmult
_RLFP5200:
;	to	r0
	add r2
;	with	r0
	lmult
_RLFP5400:
;	from	r0				; Velocity Z
	stw (r3)
	with r3	; Z Coordinate Fraction
	%add_i((rloZF-rloVZ))
;	with	r0
	sub r0
;	from	r0
	stw (r3)
;
	from !rPObj	; R3 = Parent RLObj
	to r3
	%add_i((rloX+2))
	from !rObj	; R2 = Birth RLObj
	to r2
	%add_i(rloX)
;	with	r0				; X Coordinate
	sub r0
;	from	r0
	stw (r2)
	inc r2
	inc r2
	to !rX	; BirthX = ParentX
	ldw (r3)
	from !rX
	stw (r2)
	inc r2	; Y Coordinate
	inc r2
	with r3
	%add_i(((rloY+2)-(rloX+2)))
;	with	r0
	sub r0
;	from	r0
	stw (r2)
	inc r2
	inc r2
	to !rY	; BirthY = ParentY
	ldw (r3)
	from !rY
	stw (r2)
	inc r2	; Z Coordinate
	inc r2
	inc r3
	inc r3
;	to	r0				; BirthZ = ParentZ
	ldw (r3)
	ibt r4,#(56/2)	; Z Adjust
;	with	r0
	add r4
;	from	r0
	stw (r2)
	with r2	; BirthAngle
	%add_i((rloAngle-rloZ))
	from r1
	stw (r2)
;
	with r3	; BirthSector = ParentSector
	%add_i((rloSector-rloZ))
	to r1
	ldb (r3)
	ibt r0,#rloSector
;	with	r0
	add !rObj
	from r1
	stb (r0)
;
;	>>>   ADD RLOBJECT TO NEW SECTOR   <<<
;
	link #4	; Add RLObject to Sector's ObjectList
	iwt r15,#lo16(_RLAddSectorObject)
	nop
;
;	>>>   RETURN TO WEAPONS STATE MACHINE   <<<
;
_RLFP9200:
	ibt r0,#bank(WeaponsData)	; Set ROM Bank
	romb
	iwt r12,#lo16(_RLWeapons1)
	iwt r15,#lo16(_RLDWS3000)	; Return to Caller
	nop


;
;	* * * * * * *       FIRE GUN       * * * * * * *
;
	!rSoundEffect = r3	; Sound Effect
	!rDamage = r4	; Damage Multiplier / Points
	!rAmmoCount = r5	; Ammo to Subtract

	!rMinX = r6	; Minimum Screen Column
	!rMaxX = r7	; Maximum Screen Column
	!rTargetListPtr = r8	; Pointer to TargetList
	!rTDistance = r9	; Best Distance to Target
	!rDistance = r10	; Distance to Current Target
	!rTObj = r13	; Pointer to Target RLObject
	!rTObjSectorData = r1	; Target RLObject SectorData (FIXED ONLY)
;
;	* * * * * * *       USE FIST       * * * * * * *
;
_RLFireFist:
	link #4	; Create TargetList
	if usePATCH == 0
	iwt r15,#lo16(_RLFireTarget)
	endif
	if usePATCH != 0
	lms r15,(PTRLFireTarget&$FFFF)
	endif
	nop
	ibt !rTDistance,#edFightDistance	; Minimum Distance to Target
	iwt !rDamage,#((2<<8)|7)	; Damage Multiplier / Points
	ibt !rSoundEffect,#punch_eff	; Sound Effect
	if useID4 == 0
	lms r0,(BerserkCount&$FFFF)	; BERSERK?
	endif
	if useID4 != 0
	lms r0,(Berserk&$FFFF)	; BERSERK?
	endif
	dec r0
	bmi _RLFireGun2
;	with	r0				; Light Level
	sub r0
	iwt !rDamage,#((16<<8)|7)	; Damage Multiplier / Points
	bra _RLFireGun2
;
;	* * * * * * *       USE CHAINSAW       * * * * * * *
;
_RLFireChainSaw:
	link #4	; Create TargetList
	if usePATCH == 0
	iwt r15,#lo16(_RLFireTarget)
	endif
	if usePATCH != 0
	lms r15,(PTRLFireTarget&$FFFF)
	endif
	nop
	ibt !rTDistance,#edFightDistance	; Minimum Distance to Target
	iwt !rDamage,#((3<<8)|15)	; Damage Multiplier / Points
	ibt !rSoundEffect,#sawful_eff	; Sound Effect
	bra _RLFireGun2
;	with	r0				; Light Level
	sub r0
;
;	* * * * * * *       FIRE CHAINGUN       * * * * * * *
;
_RLFireChainGun:
	link #4	; Create TargetList
	if usePATCH == 0
	iwt r15,#lo16(_RLFireTarget)
	endif
	if usePATCH != 0
	lms r15,(PTRLFireTarget&$FFFF)
	endif
	nop
	iwt !rDamage,#((4<<8)|7)	; Damage Multiplier / Points
	ibt !rSoundEffect,#pistol_eff	; Sound Effect
	ibt !rAmmoCount,#1	; #Ammo to subtract
	ibt r0,#8	; Light Level
	bra _RLFireGun
;
;	* * * * * * *       FIRE PISTOL       * * * * * * *
;
_RLFirePistol:
	link #4	; Create TargetList
	if usePATCH == 0
	iwt r15,#lo16(_RLFireTarget)
	endif
	if usePATCH != 0
	lms r15,(PTRLFireTarget&$FFFF)
	endif
	nop
	iwt !rDamage,#((3<<8)|7)	; Damage Multiplier / Points
	ibt !rSoundEffect,#pistol_eff	; Sound Effect
	ibt !rAmmoCount,#1	; #Ammo to subtract
	ibt r0,#8	; Light Level
	bra _RLFireGun
	nop
;
;	* * * * * * *       FIRE SHOTGUN       * * * * * * *
;
	%align_pad(14, 16, (_RLFireShotGun-_RLFireGunAlign)&$0F)	; align 16,(_RLFireShotGun-_RLFireGunAlign)&$0f
_RLFireShotGun:
	link #4	; Create TargetList
	if usePATCH == 0
	iwt r15,#lo16(_RLFireTarget)
	endif
	if usePATCH != 0
	lms r15,(PTRLFireTarget&$FFFF)
	endif
	nop
	iwt !rDamage,#((32<<8)|3)	; Damage Multiplier / Points
	ibt !rSoundEffect,#shotgn_eff	; Sound Effect
	ibt !rAmmoCount,#1	; #Ammo to subtract
	ibt r0,#16	; Light Level
;
;	* * * * * * *       FIRE GUN       * * * * * * *
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE   !!!
;
_RLFireGun:
	iwt !rTDistance,#$7FFF	; Maximum Distance to Target
_RLFireGun2:
	ibt r1,#lo16(WeaponLight)	; LIGHT CREATED BY WEAPON
	assert (lo16(WeaponLight))&$FFFF < $80 || (lo16(WeaponLight))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;	from	r0
	stb (r1)
;
	iwt !rTargetListPtr,#lo16(_RLTargetList-2)	; START of TargetList
	ibt !rTObj,#0	; TObj
	ibt !rMinX,#(((RLViewPixX/2)-16)>>1)	; Minimum Screen Column>>1
	ibt !rMaxX,#((RLViewPixX/2)+16)	; Maximum Screen Column

	%CACHEB(_RLFireGun)
_RLFireGunAlign:	; @ALIGNMENT ABOVE!@
;
;	>>>   NEXT TARGETTED OBJECT   <<<
;
_RLFG2200:
	inc !rTargetListPtr
	inc !rTargetListPtr
;	to	r0				; Get Next Target
	ldw (!rTargetListPtr)
	moves r1,r0	; Any More Targets?
	beq _RLFG4000	; No!
	with !rTargetListPtr	; Move to Distance
	%add_i((4-1))
;
;	>>>   WITHIN TARGETTING ANGLE RANGE?   <<<
;
	with r1	; Screen X1 (rXs1)
	%add_i(rlqXs1)
;	to	r0
	ldw (r1)
;	with	r0
	sub !rMaxX
	bpl _RLFG2200	; Not in range
	inc !rTargetListPtr
	inc r1	; Screen X2 (rXs2)
	inc r1
;	to	r0
	ldw (r1)
;	with	r0
	sub !rMinX
	bmi _RLFG2200
	nop
;
;	>>>   CLOSER THAN BEST TARGET?   <<<
;
;	to	r0				; Get Distance
	ldw (!rTargetListPtr)
;	from	r0				; < Best Distance?
	cmp !rTDistance
	bge _RLFG2200	; No
	move !rDistance,r0
;
;	>>>   NEW BEST TARGET   <<<
;
	move !rTObj,!rTargetListPtr	; Found It!
	with !rDistance
	bra _RLFG2200
	to !rTDistance

	%CACHEE(_RLFireGun)
;
;	>>>   UPDATE AMMO COUNT   <<<
;
_RLFG4000:
	lms r0,(WeaponAmmo&$FFFF)	; Get Address of Ammo
	dec r0
	bmi _RLFG5000	; No Ammo (Fist/ChainSaw)
	inc r0
;	to	r0				; Get Ammo Amount
	ldw (r0)
;	with	r0
	sub !rAmmoCount
	bpl _RLFG4200
	nop
;	with	r0
	sub r0
_RLFG4200:
	bra _RLFG7000
;	from	r0				; Update Ammo Amount
	sbk
;
;	>>>   FIST/CHAINSAW   <<<
;
_RLFG5000:
	moves r0,!rTObj	; Target Acquired? (test 0, not the sign:
	if useID == 0	; the target list can lie above $8000)
	beq _RLFG9000	; No
	endif
	if useID != 0
	beq _RLFG5800
	endif
	sub #4	; (delay slot)
	to r1	; Get RLVObject
	ldw (r0)
	with r1	; Get VObjZ (Adjusted by ViewZ)
	%add_i(rlqWZ)
	to r1
	ldw (r1)
	lms r0,(PlayerHeight&$FFFF)	; Get |(TargetZ-PlayerZ)|
;	with	r0
	add r1
	bpl _RLFG5200
	nop
;	with	r0
	not
	inc r0
_RLFG5200:
	ibt r1,#(odhTarget*3/4)	; WITHIN 3/4H?
;	with	r0
	sub r1
	if useID == 0
	bpl _RLFG9000	; No!  Too Far!
	endif
	if useID != 0
	bmi _RLFG7000
	nop
_RLFG5800:
	ibt r0,#punch_eff	; Punching?
;	with	r0
	sub !rSoundEffect
	bne _RLFG9000	; No, ChainSaw
	nop
	bra _RLFG9200	; No Sound Effect!
	nop
	endif
;
;	>>>   TARGET ACQUIRED?   <<<
;
_RLFG7000:
	moves r0,!rTObj	; Target Acquired? (see _RLFG5000)
	beq _RLFG9000	; NO!
	sub #4	; (delay slot)
;
;	>>>   GET TARGET RLOBJECT   <<<
;
;	to	r0				; Get RLVObject
	ldw (r0)
;	with	r0				; Get RLObject
	%add_i(rlqObj)
	to !rTObj
	ldw (r0)
;	with	r0				; Get RLObject.SectorData
	%add_i((rlqSectorData-rlqObj))
	to !rTObjSectorData
	ldw (r0)
;
;	>>>   DAMAGE TARGET RLOBJECT   <<<
;
	link #4
	iwt r15,#lo16(_RLDamageObjectMR)
	nop
	ibt r0,#sawful_eff	; (this port) The chainsaw hit: its hitting sound (PC DSSAWHIT)
;	with	r0
	sub !rSoundEffect
	bne _RLFG9000
	nop
	ibt !rSoundEffect,#sawhit_eff
;
;	>>>   MAKE SOUND EFFECT   <<<
;
_RLFG9000:
	link #4	; (this port) Rumble: the weapon's fire effect, as FX3
	iwt r15,#lo16(_RLWeaponRumble)
	nop
	link #4	; Make Sound Effect
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop
_RLFG9200:
	ibt r0,#bank(WeaponsData)	; Set ROM Bank
	romb
	iwt r12,#lo16(_RLWeapons1)
	iwt r15,#lo16(_RLDWS3000)	; Return to Caller
	nop

	if !RLDOOM2MONSTERS != 0
;
;	* * * * * * *       FIRE SUPER SHOTGUN (DOOM II)       * * * * * * *
;
;	PC: 2 shells, 20 pellets of 5*(1..3) spread over +-11 degrees (100-300 if all
;	hit).  Here as the shotgun (one target, the closest in the aim window) with
;	64*(1..4) and a window of +-40 columns instead of +-16
;
_RLFireSuperShotGun:
	link #4	; Create TargetList
	if usePATCH == 0
	iwt r15,#lo16(_RLFireTarget)
	endif
	if usePATCH != 0
	lms r15,(PTRLFireTarget&$FFFF)
	endif
	nop
	iwt !rDamage,#((64<<8)|3)	; Damage Multiplier / Points
	ibt !rSoundEffect,#dshtgn_eff	; Sound Effect (this port: its own, DSDSHTGN)
	ibt !rAmmoCount,#2	; #Ammo to subtract
	ibt r0,#16	; Light Level
	iwt !rTDistance,#$7FFF	; Maximum Distance to Target
	ibt r1,#lo16(WeaponLight)	; LIGHT CREATED BY WEAPON
;	from	r0
	stb (r1)
	iwt !rTargetListPtr,#lo16(_RLTargetList-2)	; START of TargetList
	ibt !rTObj,#0	; TObj
	iwt !rMinX,#(((RLViewPixX/2)-40)>>1)	; Minimum Screen Column>>1
	iwt !rMaxX,#((RLViewPixX/2)+40)	; Maximum Screen Column
	iwt r15,#lo16(_RLFG2200)
	nop
	endif
