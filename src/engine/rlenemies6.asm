	arch 65816
;**********************************************************************
;*                                                                    *
;*                  P R O J E C T :   REALITY_ENGINE                  *
;*                                                                    *
;*                      ENEMIES HANDLING MODULE 6                     *
;*                                                                    *
;*                          ENEMIES BIRTHING                          *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlenemies.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


	!rEnemyBirths = r6	; Pointer to Enemy Birth List
	!rX = r7	; Birth RLObject X Coordinate
	!rY = r8	; Birth RLObject Y Coordinate
;rSector	equ	r6			; RLObject Sector
	!rPObj = r10	; Pointer to Parent RLObject
	!rBirthCode = r11	; Pointer to Enemy Birth Code
	!rObj = r12	; Pointer to Birth RLObject
	!rMObjData = r13	; Pointer to MObjData

;
;	* * * * * * *       ENEMIES BIRTHING       * * * * * * *
;
	%align_pad(8, 16, (_RLEB10000-_RLEnemiesBirthAlign)&$0F)	; align 16,(_RLEB10000-_RLEnemiesBirthAlign)&$0f

;
;	>>>   FINISHED ENEMIES BIRTHS   <<<
;
_RLEB10000:
	if usePATCH == 0
	iwt r0,#lo16(_RLPlayer)	; HANDLE PLAYER
	endif
	if usePATCH != 0
	lms r0,(PTRLPlayer&$FFFF)	; HANDLE PLAYER
	endif
	ibt r8,#bank(_RLPlayer)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	>>>   START ENEMIES BIRTHING   <<<
;
_RLEnemiesBirth:
	iwt !rEnemyBirths,#lo16(_RLEnemyBirths)	; Pointer to Enemy BirthList
;
;	>>>   PROCESS NEXT ENEMY   <<<
;
_RLEB2000:
;	to	r0				; Get Enemy Birth MObjData
	ldw (!rEnemyBirths)
	moves !rMObjData,r0
	beq _RLEB10000	; No More Enemies!
	inc !rEnemyBirths
	inc !rEnemyBirths
	to !rPObj	; Get Parent Enemy RLObject
	ldw (!rEnemyBirths)
	inc !rEnemyBirths
	inc !rEnemyBirths
	to !rBirthCode	; Get Enemy Birth Code
	ldw (!rEnemyBirths)
	inc !rEnemyBirths
	inc !rEnemyBirths
;
	lms r0,(RLNumPObjs&$FFFF)	; Get #ProjectileRLObjects
	ibt r1,#(MaxRLMoveProjectiles-1)
;	with	r0
	sub r1
	bge _RLEB10000
	nop
;
	lms r0,(RLNumMObjs&$FFFF)	; Get #MovableRLObjects
	iwt r1,#(MaxRLMObjects-8)	; Too Many RLMObjs? (iwt: more than 127 slots)
;	from	r0
	cmp r1
	bge _RLEB10000	; Yes!  Can't Add Anymore!
	inc r0	; MovableRLObjects++
;	from	r0
	sbk
;
;	>>>   BIRTH THIS ENEMY!   <<<
;
	iwt r2,#lo16(_RLMObjects-rloSize)	; RLMovableObjects
	ibt r1,#rloSize	; Size of RLMovableObject
	sms (ENEnemy&$FFFF),!rEnemyBirths	; Save Enemy Births List Index

	%CACHEB(_RLEnemiesBirth)
_RLEnemiesBirthAlign:

;
;	>>>   FIND EMPTY MOVABLE OBJECT   <<<
;
_RLEB3000:
	with r2	; Move to Next MObj
	add r1
;	to	r0				; Find Empty MObj
	ldw (r2)
	inc r0
	bne _RLEB3000+1	; Check Next MObj
	move !rObj,r2	; Save MObj
;
;	>>>   FIND EMPTY MOVABLE OBJECT PROCESSING SLOT   <<<
;
	iwt r1,#lo16(_RLMObjs-1)	; MovableObjects Processing List
_RLEB3200:
	inc r1
;	to	r0				; Find Empty MObj Processing Slot
	ldw (r1)
	inc r0
	bne _RLEB3200	; Check Next MObj
	inc r1
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
	with r14
	%sub_i(((rlmodBirthA+1)-rlmodHealth))
	from r2
	stw (r4)
	with r4	; Health
	%add_i((rloHealth-rloAnim))
	getb
	inc r14
	getbh
	ibt r3,#(rlmodBirthFlags-(rlmodHealth+1))
	with r3
	add r14
	from r2	; Get Animation First Frame
	to r14
	add #1
;	from	r0
	stw (r4)
	inc r4
	inc r4
;	with	r0				; Target RLObject
	sub r0
;	from	r0
	stw (r4)
	with r4	; Image
	%sub_i((rloTObj-rloImage))
	getb
	move r14,r3	; Get BirthFlags/BirthType
;	from	r0				; Image
	stb (r4)
	getb	; BirthFlags
	inc r14
	getbh	; BirthType
	from !rObj
	to r4
	%add_i(rloFlags)
;
;	>>>   CALL ENEMY BIRTH ROUTINE   <<<
;
	jmp !rBirthCode
;	from	r0				; Flags/Type
	stw (r4)

;
;	>>>   ADD RLOBJECT TO NEW SECTOR   <<<
;
_RLEB5000:
	link #4	; Add RLObject to Sector's ObjectList
	iwt r15,#lo16(_RLAddSectorObject)
	nop
;
;	>>>   START SOUND EFFECT   <<<
;
	ibt r0,#bank(_MObjData)	; MObjData Bank
	romb
	ibt r0,#rloMData	; Get Pointer to MObjData
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
	ibt r1,#rlmodBirthSound	; Get Birth Sound Effect
;	from	r0
	to r14
	add r1
	from !rObj	; Get Sound Origin Coordinates
;	to	r0
	%add_i((rloX+2))
	to r4
	ldw (r0)
	to r3	; Get SoundEffect#
	getb
	inc r14
;	with	r0
	%add_i(((rloY+2)-(rloX+2)))
	to r6
	ldw (r0)
	with r3	; Get SoundEffect#
	getbh
	link #4
	iwt r15,#lo16(_RLSoundEffect)
	dec r3
;
;	>>>   NEXT ENEMY BIRTH   <<<
;
	lms !rEnemyBirths,(ENEnemy&$FFFF)	; Restore Enemy Births List Index
	iwt r15,#lo16(_RLEB2000)+1
;	to	r0				; Get Next Enemy
	ldw (!rEnemyBirths)

;
;	* * * * * * *       ENEMIES BIRTHING SUBROUTINES       * * * * * * *
;

;
;	>>>   BIRTH A MISSILE   <<<
;
_RLEBirthMissile:
	ibt r0,#1	; (rockets keep their speed)
	bra _RLEBFB100
	nop
	if !RLDOOM2MONSTERS != 0
;
;	>>>   BIRTH A FIREBALL ANG90/8 TO THE LEFT/RIGHT (MANCUBUS)   <<<
;
_RLEBirthFireBallSL:
	ibt r0,#1
	bra _RLEBFBLR
	nop
_RLEBirthFireBallSR:
	ibt r0,#-1
_RLEBFBLR:
	iwt r1,#lo16(BirthAngleOfs)	; (_RLEBirthEnemy adds it to the angle)
	stb (r1)
	iwt r15,#lo16(_RLEBirthFireBall)
	nop
;
;	>>>   BIRTH AN EFFECT AT THE PARENT'S TARGET (ARCH-VILE FLAMES)   <<<
;
_RLEBirthAtTarget:
	ibt r0,#rloTObj
	add !rPObj
	to !rPObj
	ldw (r0)
	iwt r15,#lo16(_RLEBirthEnemy)
	nop
;
;	>>>   BIRTH A MONSTER (PAIN ELEMENTAL'S LOST SOUL)   <<<
;
_RLEBirthMonster:
	ibt r0,#rloVX	; Not moving
	add !rObj
	ibt r1,#0
	from r1
	stw (r0)
	inc r0
	inc r0
	from r1
	stw (r0)
	iwt r15,#lo16(_RLEBirthEnemy)
	nop
	endif
;
;	>>>   BIRTH A FIREBALL   <<<
;
_RLEBirthFireBall:
	lms r0,(SkillLevel&$FFFF)	; Nightmare: fireballs 1.5x as fast (PC: 20 instead of 10/15)
	%sub_i(4)
_RLEBFB100:
	sms (NMFastShot&$FFFF),r0	; (0 = fast)
	move r3,!rPObj	; R3 = Source Object
	ibt r0,#rloTObj	; R5 = Target Object
;	with	r0
	add !rPObj
	to r5
	ldw (r0)
	ibt r0,#rloAngle	; Get Angle to Target
;	with	r0
	add !rPObj
	link #4
	iwt r15,#lo16(_RLGetObjTObjDistance)	; Get Distance from Enemy to Target
;	to	r0
	ldw (r0)
;
;	from	r0				; R4 = Distance*2
	to r4
	add r0
;
	ibt r3,#rloVXY	; Velocity X/Y
	with r3
	add !rObj
	iwt r0,#($8000+(16>>1))
	lms r1,(NMFastShot&$FFFF)
	moves r1,r1
	bne _RLEBFB200
	nop
	iwt r0,#($8000+(24>>1))
_RLEBFB200:
;	from	r0
	stw (r3)
	dec r3
	dec r3
;
	ibt r0,#bank(InvTable)	; Get InverseTable Entry
	romb
	iwt r0,#lo16(InvTable-2)
;	from	r0
	to r14
	add r4
;
	ibt r1,#rloZ	; ParentZ
	from r1
;	to	r0
	add !rPObj
	to r2
	ldw (r0)
	ibt r0,#rloTObj	; TargetObject
;	with	r0
	add !rPObj
;	to	r0
	ldw (r0)
;	with	r0				; TargetZ
	add r1
;	to	r0
	ldw (r0)
;	with	r0				; R0 = (TargetZ-ParentZ)
	sub r2
;
;	>>>   GET VELOCITY Z ((dZ*VelocityXY)/Distance)   <<<
;
;	with	r0				; R2 = (DZ*VelocityXY)
	add r0
	add r0
	add r0	; *8
	move r1,r0
	add r0	; *16
	lms r6,(NMFastShot&$FFFF)
	moves r6,r6
	bne _RLEBFB300
	nop
	add r1	; *24 (fast)
_RLEBFB300:
;	from	r0				; <<1 for Divide
	to r2
	add r0
;
	getb
	inc r14
	dec r4
	dec r4
	with r4	; Low/High Gear?
	hib
	to r6
	getbh
	bne _RLEBirthFireBallE	; High
	from r2	; Low
;	to	r0
	alt1
	bra _RLEBirthFireBallR
	fmult
_RLEBirthFireBallE:
;	to	r0
	add r2
;	with	r0
	lmult
_RLEBirthFireBallR:
;	from	r0				; Velocity Z
	stw (r3)
	with r3	; Z Coordinate Fraction
	%add_i((rloZF-rloVZ))
;	with	r0
	sub r0
;	from	r0
	stw (r3)
;
;	>>>   BIRTH AN ENEMY   <<<
;
_RLEBirthEnemy:
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
	ibt r0,#bank(_ObjData)	; R1 = Height(Parent)/2 (this port; original: 28
	romb	; for every monster: the Cyberdemon's rockets came out of its knees)
	from !rPObj
	%add_i(rloType)
	ldb (r0)
	%umult_i(rlodSize)
	iwt r1,#lo16(_ObjData+rlodHeight)
	to r14
	add r1
	getb
	to r1
	lsr
;	to	r0				; BirthZ = ParentZ + Height/2
	ldw (r3)
;	with	r0
	add r1
;	from	r0
	stw (r2)
	ibt r1,#(rloAngle-rloZ)	; Angle
	with r3
	add r1
	with r2
	add r1
;	to	r0				; BirthAngle = ParentAngle
	ldw (r3)
	if !RLDOOM2MONSTERS != 0
	iwt r1,#lo16(BirthAngleOfs)	; (+ the Mancubus' spread: -1/0/1 * ANG90/8)
	to r1
	ldb (r1)
	with r1	; ($01 -> $0100, $FF -> $FF00)
	swap
	with r1
	add r1
	with r1
	add r1
	with r1
	add r1
	add r1
	endif
;	from	r0
	stw (r2)
	if !RLDOOM2MONSTERS != 0
	iwt r1,#lo16(BirthAngleOfs)
	sub r0
	stb (r1)
	endif
	ibt r1,#(rloSector-rloAngle)	; Sector
	with r3
	add r1
	with r2
	add r1
;	to	r0				; BirthSector = ParentSector
	ldb (r3)
;	from	r0
	stb (r2)
	iwt r15,#lo16(_RLEB5000)	; Finish Birthing MObj
	nop

	%CACHEE(_RLEnemiesBirth)
