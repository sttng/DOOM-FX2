	arch 65816
;**********************************************************************
;*                                                                    *
;*                  P R O J E C T :   REALITY_ENGINE                  *
;*                                                                    *
;*                  MOVABLE OBJECT HANDLING MODULE 3                  *
;*                                                                    *
;*              MOVABLE OBJECT UTILITY ROUTINES/FUNCTIONS             *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlenemies.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


;
;	* * * * * * *       DAMAGE RLOBJECT MULTIPLIER       * * * * * * *
;
;	R4 = #Damage Multipler/Range Offset
;
	!rObj = r12	; Pointer to RLObject
	!rTObj = r13	; Pointer to Target RLObject

_RLDamageObjectM:
	ibt r0,#bank(_MObjData)	; MObjData Bank
	romb
	ibt r0,#rloMData	; Get Pointer to MObjData
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
;	from	r0				; Get Damage Multiplier/Range
	to r14
	add r4
	getb
	inc r14
	to r4
	getbh
;
;	* * * * * * *       DAMAGE RLOBJECT MULTIPLIER RANGE       * * * * * * *
;
;	R4 = #Damage Multipler/Range
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE!!!
;
	!rTObj = r13	; Pointer to Target RLObject
	!rTObjSectorData = r1	; Target RLObject SectorData (FIXED ONLY)

_RLDamageObjectMR:
	ibt r0,#bank(RandomTable)	; Get Random Number
	romb
	ibt r0,#lo16(RandomNumI)	; Get Random Number
	assert (lo16(RandomNumI))&$FFFF < $80 || (lo16(RandomNumI))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	to r14
	ldb (r0)
	move r0,r14
	inc r0
;	from	r0
	sbk
;	to	r0
	getb
;	with	r0				; (Random & Range)
	and r4
	inc r0	; ((Random & Range)+1)
	with r4	; Get Multiplier
	swap
	with r4	; Get (((Random & Range)+1)*Multiplier)
	mult r0
;
;	* * * * * * *       DAMAGE RLOBJECT       * * * * * * *
;
;	R4 = #HitPoints Damage
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE!!!
;
	!rTObj = r13	; Pointer to Target RLObject
	!rTObjSectorData = r1	; Target RLObject SectorData (FIXED ONLY)

_RLDamageObject:
	if usePATCH != 0
	lms r15,(PTRLDamageObject&$FFFF)
	nop
_RLDamageObject0:
	endif
;
	if useMULTIPLAYER == 0
	iwt r0,#lo16(PlayerObject)	; Damage to PLAYER?
	endif
	if useMULTIPLAYER != 0
	lms r0,(MPPlayerObject&$FFFF)	; Damage to PLAYER?
	endif
;	with	r0
	sub !rTObj
	bne _RLDO200
	from !rTObj	; Get RLObject Flags
	iwt r15,#lo16(_RLDamagePlayer)	; YES!
	nop
;
;	>>>   MOVABLE/FIXED RLOBJECT?   <<<
;
_RLDO200:
;	from	rTObj				; Get RLObject Flags
;	to	r0
	%add_i(rloFlags)
;	to	r0
	ldb (r0)
;	with	r0				; MOVABLE?
	add r0
;	with	r0
	sex
	bmi _RLDO2000	; Yes
	nop
;
;	>>>   FIXED RLOBJECT   <<<
;
_RLDO1000:
	with r4	; Enough Damage?
	sub #12	; (12 HitPoints or more)
	bmi _RLDO2800	; No!
	nop
	iwt r15,#lo16(_RLBirthSectorFObject)	; Yes, turn it into a movable RLObject
	nop
;
;	>>>   MOVABLE RLOBJECT   <<<
;
_RLDO2000:
	ibt r0,#bank(_MObjData)	; MObjData Bank
	romb
	ibt r1,#rloHealth	; Get Object's Health
	with r1
	add !rTObj
;	to	r0
	ldw (r1)
	dec r0	; Already Dead?
	bmi _RLDO2800	; YES!
;	with	r0				; Health -= Damage
	sub r4
	bpl _RLDO2400	; Still Alive?
	inc r0
;
;	>>>   RLOBJECT IS DEAD!   <<<
;
;	with	r0
	sub r0
;
;	>>>   ONE MORE KILLED ENEMY   <<<
;
	lms r2,(NumKills&$FFFF)	; Number of KILLS++
	inc r2
	from r2
	sbk
;
;	>>>   UPDATE OBJECT'S REMAINING HEALTH   <<<
;
_RLDO2400:
;	from	r0				; Update Health
	stw (r1)
	dec r1	; Get Pointer to MObjData
	dec r1
;
	dec r0	; Is Object DEAD?
;
;	to	r0				; Get MObjData
	ldw (r1)
;	from	r0				; Get Damage State
	to r14
	bpl _RLDO2500	; NO, Check for RLObject State Interrupt!
;
;	>>>   ALWAYS INTERRUPT STATE WHEN RLOBJECT DIES!   <<<
;
	%add_i(rlmodDamageS)
	dec r1	; Set MObjState to _DAMAGE
	bra _RLDO2600
	dec r1
;
;	>>>   WILL THIS DAMAGE INTERRUPT THE RLOBJECT?   <<<
;
_RLDO2500:
;	from	r0				; Get Damage Chance
;	to	r14
;	add	#rlmodDamageChance
	db $50+rlmodDamageChance	; @DANGER ABOVE!@
;
	move r4,r14	; Save Pointer to MObjData
	to r1	; R1 = Damage Chance
	getb
;
	ibt r0,#bank(RandomTable)	; Get Random Number
	romb
	ibt r0,#lo16(RandomNumI)
	assert (lo16(RandomNumI))&$FFFF < $80 || (lo16(RandomNumI))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	to r14
	ldb (r0)
	move r0,r14
	inc r0
;	from	r0
	sbk
;	to	r0
	getb
;
;	with	r0				; Random Number < Damage Chance?
	sub r1	; @CMP@
	bge _RLDO2800-1	; NO!  DON'T INTERRUPT RLOBJECT!
;
;	>>>   INTERRUPT RLOBJECT STATE!   <<<
;
	ibt r0,#bank(_MObjData)	; MObjData Bank
	romb
	from r4	; Move to DamageState
	to r14
	add #1
	ibt r1,#rloState	; Move to State
	with r1
	add !rTObj
;
;	>>>   SET RLOBJECT STATE TO _DAMAGE   <<<
;
_RLDO2600:
	getb	; Get DamageState
	inc r14
	getbh
	jmp r11	; Return to Caller
;	from	r0
	stw (r1)
;
;	>>>   DON'T INTERRUPT RLOBJECT   <<<
;
_RLDO2800:
	jmp r11	; Return to Caller
	nop


;
;	* * * * * * *       MOVE RLOBJECT 2       * * * * * * *
;
;	rObj	  = Object to Move
;	r(SOURCE) = Angle
;	r2	  = Base of Velocity Table
;
	!rObj = r12	; Pointer to RLObject

_RLMoveObject2:
;	to	r0				; Get Direction based on Angle
	hib
	lsr
	lsr
	lsr
;	with	r0				; Get Index into Velocity Table
	bic #1
	with r2	; Add Index to Base
	add r0
;
	ibt r0,#bank(_RLMoveVelocities)	; Move to Velocity Table
	romb
;
	lms r0,(SkillLevel&$FFFF)	; Nightmare Difficulty Setting?
;	with	r0
	and #4
;	with	r0				; Yes, Move to Second Velocity Table
	%umult_i((32/4))
;
;	from	r0
	to r14
	add r2
	ibt r1,#rloVX	; Move to RLObject Velocities
	with r1
	add !rObj
	getb	; Velocity X
	inc r14
;	with	r0
	swap
;	from	r0
	stw (r1)
	inc r1
	inc r1
	getb	; Velocity Y
;	with	r0
	swap
;	from	r0
	stw (r1)
	iwt r0,#lo16(_RLMoveXY5)	; MOVE RLOBJECT XY 5 (ENEMIES)
;
;	* * * * * * *       MOVE RLOBJECT       * * * * * * *
;
;	r0   = Code for OBJECT<->LINE COLLISIONS 2
;	rObj = RLMOBJECT to Move
;
_RLMoveObject:
	sms (MOReturnAddress&$FFFF),r11	; Save Return Address
	link #4
	iwt r15,#lo16(_RLMoveXY)	; Move the Object
	nop
	lms r11,(MOReturnAddress&$FFFF)	; Restore Return Address
;
;	>>>   HANDLE GRAVITY   <<<
;
	ibt r0,#bank(_ObjData)	; Move to _ObjData Bank
	romb
	from !rObj	; Move to RLObject Type
;	to	r0
	%add_i(rloType)
;	to	r0				; Get RLObject Type
	ldb (r0)
;	with	r0				; Get Offset into _ObjData
	%umult_i(rlodSize)
	iwt r1,#lo16(_ObjData+rlodFlags)	; Add Base of _ObjData
;	from	r0				; Move to Object Flags
	to r14
	add r1

	if 1 != 0
;
;	>>>   IS THIS A PLAYER OBJECT?   <<<
;
	dec r0	; Doing a Player Object?
	ibt r0,#rloZ2
;	with	r0				; Move to PlayerObject.Z2
	bmi _RLMO2100	; Yes, Use Z2 for FloorHeight!
	add !rObj
	endif

;
;	>>>   GET OBJECT'S SECTOR'S FLOORHEIGHT   <<<
;
	ibt r0,#rloSector	; Get Sector
;	with	r0
	add !rObj
;	to	r0
	ldb (r0)
;	with	r0
	%umult_i(rlsdSize)
	iwt r1,#lo16(_RLSectorData+rlsdFloorHeight)
;	with	r0
	add r1
_RLMO2100:
	to r2	; Get FloorHeight
	ldw (r0)
;
	lms r3,(FPSRatio&$FFFF)	; Get FramesPerSecond Ratio
;
	ibt r1,#rloZ	; Get Object's Z
	with r1
	add !rObj
	to r1
	ldw (r1)
;
	getb	; Get Object Flags
;	with	r0				; Does this Object FLOAT?
	%and_i(rlodfFloat)
	bne _RLMO4000-1	; YES!  NO GRAVITY!
;
;
;	>>>   THE PLAYER FALLS AS ON THE PC (this port)   <<<
;
;	From rest, 1 unit per tic per tic (PC DOOM: 35 tics a second), so a run
;	carries over a gap as far as there (the original engine dropped 16 units per
;	20th of a second at once).  n = tics this frame = FPSRatio*7/4 (8.8);
;	drop = (v + n/2) * n, then v += n.
;
	if useMULTIPLAYER == 0
	iwt r0,#lo16(PlayerObject)	; The player?
	else
	lms r0,(MPPlayerObject&$FFFF)	; The player?
	endif
	sub !rObj
	bne _RLMO2150	; No
	nop
	from r2	; On the ground (FloorHeight >= ObjectZ)?
	cmp r1
	blt _RLMO2120	; No, falling
	nop
	sub r0	; Yes, no fall speed
	sms (PlayerFallV&$FFFF),r0
	move r6,r0
	bra _RLMO2190
	nop
_RLMO2120:
	from r3	; R6 = n = FPSRatio*7/4 (tics, 8.8)
	to r6
	lsr
	with r6
	lsr	; FPSRatio/4
	from r6
	add r6	; FPSRatio/2
	add r6	; FPSRatio*3/4
	to r6
	add r3
	lms r4,(PlayerFallV&$FFFF)	; R4 = v (8.8 units per tic)
	from r6
	lsr	; v + n/2
	add r4
	with r4	; v += n
	add r6
	sms (PlayerFallV&$FFFF),r4
	lmult	; R0 = (v + n/2) * n >> 16 (whole units)
	move r6,r0
	bra _RLMO2190
	nop
_RLMO2150:
	ibt r6,#16	; Gravity Constant
	from r3
;	to	r0
	lmult
;	with	r0				; Get Whole Pixels Only
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0				; R6 = |GravityConstant|
	to r6
	or r4
;
_RLMO2190:
	ibt r0,#rloZ	; (lms/sms above moved sbk's RAM address: point it at ObjectZ again)
	add !rObj
	ldw (r0)
	from r1	; ObjectZ -= Gravity
;	to	r0
	sub r6
_RLMO2200:
;	from	r0				; ObjectZ >= FloorHeight?
	cmp r2
	bge _RLMO2220	; Yes
	moves r0,r2	; No!  Move to FloorHeight!
_RLMO2220:
;
;	>>>   OBJECT MOVEMENT COMPLETED!   <<<
;
;	from	r0				; Update ObjectZ
	sbk
_RLMO2300:
	jmp r11	; Return to Caller
	nop
;
;	>>>   FLOATING OBJECT   <<<
;
_RLMO4000:
	lms r0,(MVIPercent&$FFFF)	; Percentage of Movement Allowed
	dec r0
	bmi _RLMO2300-1	; Movement Blocked!
	ibt r0,#rloTObj	; Get TargetObject
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
	moves r4,r0
	beq _RLMO2300
	with r14	; Move to Object Height
	%add_i((rlodHeight-rlodFlags))
	ibt r0,#rloZ	; Get Target Z
;	with	r0
	add r4
	to r1
	ldw (r0)
	ibt r0,#32	; Destination Z
	with r1
	add r0
	to r3	; R3 = Object Height
	getb
	from !rObj	; R0 = Object Z
	to r6
	%add_i(rloZ)
;	to	r0
	ldw (r6)
	with r3	; R3 = (Object Z + Object Height)
	add r0
	ibt r4,#8	; Move Upwards
;	from	r0				; Z < Target Z?
	cmp r1
	blt _RLMO4200	; Yes, Move Upwards!
	with r1	; Close to Target Z?
	add r4
;	from	r0
	cmp r1
	blt _RLMO4900-1	; Yes, Don't Move!
	ibt r4,#-8	; Move Downwards
_RLMO4200:
	with r3	; R3 = ObjectZ+Height+Movement
	add r4
	with r4	; R4 = ObjectZ+Movement
	add r0
;
;	>>>   ENSURE OBJECT FITS WITHIN SECTOR HEIGHTS   <<<
;
	ibt r0,#rloSector	; Get Sector
;	with	r0
	add !rObj
;	to	r0
	ldb (r0)
;	with	r0
	%umult_i(rlsdSize)
	iwt r1,#lo16(_RLSectorData+rlsdFloorHeight)
	with r1
	add r0
;
;	to	r0				; Get FloorHeight
	ldw (r1)
;	from	r0				; ObjectZ+Movement < Floor?
	cmp r4
	bge _RLMO4800	; Yes!  Move to Floor!
	inc r1
	inc r1
;	to	r0				; Get CeilingHeight
	ldw (r1)
;	with	r0				; ObjectZ+Height+Movement <= Ceiling?
	sub r3
	blt _RLMO4900	; No!  Can't Move!
	from r4	; Update Object's Z
_RLMO4800:
	stw (r6)
_RLMO4900:
	jmp r11
	nop


;
;	* * * * * * *       MOVE RLOBJECT 3       * * * * * * *
;
;	rObj	  = Object to Move
;
	!rObj = r12	; Pointer to RLObject

_RLMoveObject3:
;
;	>>>   GET VELOCITY OF PROJECTILE   <<<
;
	ibt r0,#rloVXY	; Get X/Y Velocity
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
;	from	r0
	to r6
	add r0
	lms r0,(FPSRatio&$FFFF)	; Get FramesPerSecond Ratio
;	with	r0
	lmult
	with r4
	add r4
;	with	r0
	rol
;	with	r0
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0				; R6 = ProjectileVelocity
	to r6
	or r4
;
;	>>>   GET ANGLE OF PROJECTILE   <<<
;
	ibt r0,#bank(SinTable)	; Bank of SinTable
	romb
	ibt r2,#rloAngle	; Get Movement Angle
	with r2
	add !rObj
;	to	r0
	ldw (r2)
;	with	r0				; Get Velocities based on Angle
	lsr
	lsr
	lsr
	lsr
	lsr	; >>5
;	from	r0				; Remove lowest bit
	to r1
	bic #1
	iwt r0,#lo16(SinTable)	; Add Base of SinTable
;	from	r0
	to r14
	add r1
;
	iwt r0,#lo16(CosTable)	; Add Base of CosTable
	with r1
	add r0
	dec r2	; Move to RLObject Velocities
	dec r2
;
	getb	; Get Sine from Table
	inc r14
	getbh
	move r14,r1
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
;	from	r0
	stw (r2)
	dec r2
	dec r2
;
	getb	; Get CoSine from Table
	inc r14
	getbh
;
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
	iwt r15,#lo16(_RLMoveXYP)	; Move the Object
;	from	r0
	stw (r2)
