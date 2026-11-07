	arch 65816
;**********************************************************************
;*                                                                    *
;*                  P R O J E C T :   REALITY_ENGINE                  *
;*                                                                    *
;*                        PROJECTILES MOVEMENT                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlenemies.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


	!rProjectileMoves = r11	; Pointer to Projectile Movement List
	!rObj = r12	; Pointer to RLObject
	!rTObj = r13	; Pointer to Target RLObject
	!rTObjSectorData = r1	; Target RLObject SectorData (FIXED ONLY)


;
;	* * * * * * *       PROJECTILES MOVEMENT       * * * * * * *
;
	%align_pad(4, 16, (_RLPM10000-_RLProjectilesMoveAlign)&$0F)	; align 16,(_RLPM10000-_RLProjectilesMoveAlign)&$0f
;
;	>>>   FINISHED PROJECTILES MOVEMENT   <<<
;
_RLPM10000:
	iwt r0,#lo16(_RLRadiusDamage)	; HANDLE RADIUS DAMAGES
	ibt r8,#bank(_RLRadiusDamage)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	* * * * * * *       START PROJECTILES MOVEMENT       * * * * * * *
;
_RLProjectilesMove:
	iwt r1,#lo16(MVULMask)	; LineFlags Type Mask
;	with	r0
	sub r0
;	from	r0
	stb (r1)
	iwt r1,#lo16(MVIMask)	; ObjectFlags Collision Mask
	ibt r0,#rlpfSolid
;	from	r0
	stb (r1)
	iwt !rProjectileMoves,#lo16(_RLProjectileMoves)	; Pointer to Projectile MoveList
;
;	* * * * * * *       PROCESS NEXT PROJECTILE       * * * * * * *
;
_RLPM2000:
	%CACHEB(_RLProjectilesMove)
_RLProjectilesMoveAlign:
;	to	r0				; Get Next Projectile
	ldw (!rProjectileMoves)
	inc !rProjectileMoves
	moves !rObj,r0
	beq _RLPM10000	; No More Projectiles!
	inc !rProjectileMoves
;
	sms (ENEnemy&$FFFF),!rProjectileMoves	; Save Projectile Movement List Index
	link #4
	iwt r15,#lo16(_RLMoveObject3)
	nop
;
;	>>>   IS PROJECTILE FAST ALREADY?   <<<
;
_RLPM4000:
	from !rObj	; Get Projectile's Flags
;	to	r0
	%add_i(rloFlags)
;	to	r0
	ldw (r0)
;	with	r0				; rlpfProjectileFast?
	lsr
	bcs _RLPM4800	; Yes
;	with	r0				; No, Make Projectile Fast!
	add r0
	inc r0
;	from	r0
	sbk
	ibt r0,#rloVXY	; Double X/Y Velocity
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
;	with	r0
	add r0
;	from	r0
	sbk
	ibt r0,#rloVZ	; Double Z Velocity
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
;	with	r0
	add r0
;	from	r0
	sbk
_RLPM4800:
;
;	>>>   WAS PROJECTILE BLOCKED?   <<<
;
	lms r0,(MVIPercent&$FFFF)	; Percentage of Movement Allowed
	inc r0
	bpl _RLPM5000-1	; Movement BLOCKED!
;
;	>>>   DID PROJECTILE HIT FLOOR/CEILING?   <<<
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
	to r2	; Get FloorHeight
	ldw (r1)
	ibt r0,#rloZ	; Get Projectile Z
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
;	from	r0				; Below Floor?
	cmp r2
	blt _RLPM8000	; YES!
	inc r1
	inc r1
	to r2	; Get CeilingHeight
	ldw (r1)
;	with	r0				; Above Ceiling?
	sub r2	; @CMP@
	blt _RLPM9000	; NO!
	nop
	bra _RLPM8000	; YES!
	nop
;
;	* * * * * * *       PROJECTILE MOVEMENT BLOCKED       * * * * * * *
;
_RLPM5000:
	lms r2,(MVMLPtr&$FFFF)	; Get Blocking Line's Flags
	from r2
;	to	r0
	%add_i(rlmlFlags)
;	to	r0
	ldw (r0)
	inc r0	; OBJECT/WALL?
	bpl _RLPM8000	; WALL
;
;	>>>   GET BLOCKING RLOBJECT   <<<
;
	to !rTObj	; Get RLObject
	ldw (r2)
	from !rTObj	; Get RLObject.Flags
;	to	r0
	%add_i((rloFlags+1))
;	to	r0				; @RAM FETCH INVERTED@
	ldw (r0)
;	with	r0				; rlpfMovable -> .S
	add r0
;	with	r0				; rlpfMovable -> .C
	add r0
	bpl _RLPM8000	; NOT A TARGET!
	nop
	bcs _RLPM6000-1	; MOVABLE!
;
	ibt r0,#rlmlSectorData	; FIXED!
;	with	r0
	add r2
;	to	r0				; Get RLObject.SectorData.Objects
	ldw (r0)
;	from	r0				; Move Back to SectorData
	to !rTObjSectorData
	%sub_i(rlsdObjects)
;
;	>>>   DAMAGE THE BLOCKING TARGET OBJECT!   <<<
;
_RLPM6000:
	ibt r4,#rlmodAttackFarDamage	; Damage Multiplier/Range
	link #4
	iwt r15,#lo16(_RLDamageObjectM)
	nop
	lms !rObj,(MVRObj&$FFFF)	; Get RLObject Pointer

;
;	* * * * * * *       DESTROY PROJECTILE       * * * * * * *
;
_RLPM8000:
;
;	>>>   SET RLOBJECT STATE TO _DAMAGE   <<<
;
	ibt r0,#bank(_MObjData)	; MObjData Bank
	romb
	ibt r1,#rloMData
	with r1
	add !rObj
;	to	r0
	ldw (r1)
;	from	r0				; Move to DamageState
	to r14
	%add_i(rlmodDamageS)
	dec r1	; Move to State
	dec r1
	getb	; Get DamageState
	inc r14
	getbh
;	from	r0
	stw (r1)

;
;	* * * * * * *       NEXT PROJECTILE       * * * * * * *
;
_RLPM9000:
	lms !rProjectileMoves,(ENEnemy&$FFFF)	; Restore Projectile Movement List Index
_RLPM9200:
	iwt r15,#lo16(_RLPM2000)
	nop


	%CACHEE(_RLProjectilesMove)
