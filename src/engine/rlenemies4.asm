	arch 65816
;**********************************************************************
;*                                                                    *
;*                  P R O J E C T :   REALITY_ENGINE                  *
;*                                                                    *
;*                      ENEMIES HANDLING MODULE 4                     *
;*                                                                    *
;*                          ENEMIES MOVEMENT                          *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlenemies.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


	!rEnemyMoves = r11	; Pointer to Enemy Movement List
	!rObj = r12	; Pointer to RLObject


;
;	* * * * * * *       ENEMIES MOVEMENT       * * * * * * *
;
	%align_pad(10, 16, (_RLEM10000-_RLEnemiesMoveAlign)&$0F)	; align 16,(_RLEM10000-_RLEnemiesMoveAlign)&$0f
;
;	>>>   FINISHED ENEMIES MOVEMENT   <<<
;
_RLEM10000:
	iwt r0,#lo16(_RLEnemiesAttack)	; HANDLE ENEMY ATTACKS
	ibt r8,#bank(_RLEnemiesAttack)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	* * * * * * *       START ENEMIES MOVEMENT       * * * * * * *
;
_RLEnemiesMove:
	iwt r1,#lo16(MVULMask)	; LineFlags Type Mask
	ibt r0,#(rllfTriggerE>>8)
;	from	r0
	stb (r1)
	iwt r1,#lo16(MVIMask)	; ObjectFlags Collision Mask
	ibt r0,#rlpfSolid
;	from	r0
	stb (r1)
	iwt !rEnemyMoves,#lo16(_RLEnemyMoves)	; Pointer to Enemy MoveList
;
;	* * * * * * *       PROCESS NEXT ENEMY       * * * * * * *
;
_RLEM2000:
	%CACHEB(_RLEnemiesMove)
_RLEnemiesMoveAlign:
_RLEM2200:
;	to	r0				; Get Next Enemy
	ldw (!rEnemyMoves)
	inc !rEnemyMoves
	moves !rObj,r0
	beq _RLEM10000	; No More Enemies!
	inc !rEnemyMoves
;
	ibt r0,#bank(_MObjData)	; MObjData Bank
	romb
	ibt r0,#rloMData	; Get Pointer to MObjData
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
;	from	r0				; Get MOVEVELOCITIES
	to r14
	%add_i(rlmodMoveVelocities)
	sms (ENEnemy&$FFFF),!rEnemyMoves	; Save Enemy Movement List Index
;
	ibt r4,#rloTDistance	; Get TARGET DISTANCE
	with r4
	add !rObj
	ibt r1,#edFightDistance	; Within Fighting Distance of Target?
;	to	r0
	ldw (r4)
;	with	r0				; @CMP@
	sub r1
	blt _RLEM2200	; Yes, Don't Move Closer!
;
	getb
	inc r14
	ibt r4,#rloAngle	; Get TARGET ANGLE
	with r4
	add !rObj
	to r2
	getbh
	from !rObj	; Was Enemy Movement Blocked?
;	to	r0
	%add_i(rloFlags)
;	to	r0
	ldw (r0)
;	with	r0
	%and_i(rlpfEnemyBlocked)
	to r4	; Get TARGET ANGLE
	beq _RLEM4800	; NO
	ldw (r4)
;
;	>>>   REDIRECT ENEMY MOVEMENT   <<<
;
	%umult_i(($20>>2))	; Multiple of $2000 Degrees
;	with	r0
	add r0
;	with	r0
	add r0
;	from	r0
	to r6
	swap
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
	getb
;	from	r0
	to r1
	and #7
	bne _RLEM4200+1
	with r4
	ibt r1,#$F0
;	with	r0
	and r1
;	from	r0
	to r6
	swap
_RLEM4200:
	with r4
	add r6
	ibt r0,#rloTObj	; Get TARGET OBJECT
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
	dec r0	; Any Target?
	bpl _RLEM4800-1	; YES!
	ibt r0,#rloAngle	; NO!  RESET ANGLE!
;	with	r0
	add !rObj
	from r4
	stw (r0)
_RLEM4800:
	link #4
	iwt r15,#lo16(_RLMoveObject2)
	from r4
;
;	>>>   WAS ENEMY BLOCKED?   <<<
;
	lms r0,(MVIPercent&$FFFF)	; Percentage of Movement Allowed
	dec r0
	bmi _RLEM5000
	nop
	iwt r15,#lo16(_RLEM9000)	; Movement NOT Blocked
	nop

;
;	* * * * * * *       ENEMY MOVEMENT BLOCKED       * * * * * * *
;
_RLEM5000:
	lms r2,(MVMLPtr&$FFFF)	; Get Blocking Line's Flags
	from r2
;	to	r0
	%add_i(rlmlFlags)
;	to	r0
	ldb (r0)
;
;	>>>   SOLID WALL?   <<<
;
;	with	r0				; SOLID?
	lsr
	bcc _RLEM5200	; TRANSPARENT -- Try to Use/Operate!
	nop
	iwt r15,#lo16(_RLEM8000)	; Yes, Can't Use/Operate!
	nop
;
;	>>>   DOOR?   <<<
;
_RLEM5200:
;	with	r0				; DOOR?
	%and_i((rllfDoor>>1))
	beq _RLEM7000	; No
	nop

;
;	* * * * * * *       OPEN DOOR       * * * * * * *
;
_RLEM6000:
	ibt r0,#lo16(EMBSP+2)	; Bank of EM Data
	assert (lo16(EMBSP+2))&$FFFF < $80 || (lo16(EMBSP+2))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	ldb (r0)
	romb
;	from	r2				; LINE_TYPE = 1 (DOOR ENEMIES CAN OPEN)?
;;	to	r0
;	add	#rlmlLine
;	to	r0
	ldw (r2)
	ibt r6,#rllSize
;	with	r0
	lmult
	lms r0,(EMLINES&$FFFF)	; Base Address of LINES (level RAM $71)
;	with	r0
	add r4
	from r0	; Pointer to Line Type
	to r6
	%add_i(rllType)
	%RAMB71(r1)
	to r1	; Get Line Type
	ldb (r6)
	with r6	; Move to Face
	%sub_i((rllType-rllFace))
	ldw (r6)	; Get Line's Face
	%RAMB70(r6)
	dec r1	; LineType = 1?
	bne _RLEM7000	; NO!  TRY FIND ANOTHER ROUTE
	nop
;
;	>>>   GET LINE FACE   <<<
;
	lms r1,(EMFACES&$FFFF)	; Add Base of Faces
	with r1
	add r0
	inc r1	; Move to SectorFar
	move r14,r1	; Get SectorFar
	iwt r12,#lo16(_RLEM6500)
	to r6	; Sector
	getb
	ibt r7,#(_TPCDoorOpenClose-_TPlatformCode)
;
;	>>>   OPEN DOOR IF CLOSED/CLOSING   <<<
;
	iwt r15,#lo16(_RLEnemyAddPlatformDoor)
	nop
_RLEM6500:
	lms r1,(ENEnemy&$FFFF)	; Restore Enemy Movement List Index
	dec r1
	dec r1
	moves r0,r0	; Door Already Open? (R0 = 0)
	to !rObj	; Get Current Enemy
	beq _RLEM6600	; Yes, still blocked
	ldw (r1)
	iwt r15,#lo16(_RLEM9000)	; No, Opening: Wait Until Open!
	nop
_RLEM6600:
	lms r2,(MVMLPtr&$FFFF)	; Get Blocking Line

;
;	* * * * * * *       FLOATING ENEMY       * * * * * * *
;
_RLEM7000:
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
	getb	; Get Object Flags
;	with	r0				; Does this Object FLOAT?
	%and_i(rlodfFloat)
	beq _RLEM8000-1	; NO!
;
;	>>>   MOVE UP/DOWN TO PASS THROUGH OPENING   <<<
;
	ibt r0,#rlmlHighFloorHeight	; R1 = Blocking Line's HighFloor
	with r2
	add r0
	with r14	; Move to Object Height
	%add_i((rlodHeight-rlodFlags))
	to r1
	ldw (r2)
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
;	from	r0				; Z < HighFloor?
	cmp r1
	with r1
	blt _RLEM7400	; Yes, Move Upwards!
	add r4
;	from	r0				; Close to Target Z?
	cmp r1
	blt _RLEM8000	; Yes, Don't Move!
	inc r2
	inc r2
	to r1	; R1 = Blocking Line's LowCeiling
	ldw (r2)
	from r3	; (Z+Height) >= LowCeiling?
	cmp r1
	blt _RLEM8000-1	; No
	ibt r4,#-8	; Move Downwards
_RLEM7400:
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
	bge _RLEM7800	; Yes!  Move to Floor!
	inc r1
	inc r1
;	to	r0				; Get CeilingHeight
	ldw (r1)
;	from	r0				; ObjectZ+Height+Movement <= Ceiling?
	cmp r3
	blt _RLEM9000	; No!  Can't Move!
	from r4	; Update Object's Z
_RLEM7800:
	bra _RLEM9000
	stw (r6)

;
;	* * * * * * *       ENEMY MOVEMENT BLOCKED!       * * * * * * *
;
_RLEM8000:
	from !rObj	; Mark ENEMY MOVEMENT BLOCKED!
;	to	r0
	%add_i(rloFlags)
;	to	r0
	ldw (r0)
;	from	r0
	to r1
	%bic_i(rlpfEnemyBlocked)
	inc r0
;	with	r0
	%and_i(rlpfEnemyBlocked)
;	with	r0
	add r1
	bra _RLEM9500
;	from	r0
	sbk

;
;	* * * * * * *       ENEMY MOVEMENT NOT BLOCKED!       * * * * * * *
;
_RLEM9000:
	from !rObj	; Clear ENEMY MOVEMENT BLOCKED!
;	to	r0
	%add_i(rloFlags)
;	to	r0
	ldw (r0)
;	with	r0
	%bic_i(rlpfEnemyBlocked)
;	from	r0
	sbk

;
;	* * * * * * *       NEXT ENEMY       * * * * * * *
;
_RLEM9500:
	lms !rEnemyMoves,(ENEnemy&$FFFF)	; Restore Enemy Movement List Index
_RLEM9700:
	iwt r15,#lo16(_RLEM2000)
	nop


	%CACHEE(_RLEnemiesMove)
