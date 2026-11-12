	arch 65816
;**********************************************************************
;*                                                                    *
;*                  P R O J E C T :   REALITY_ENGINE                  *
;*                                                                    *
;*                      ENEMIES HANDLING MODULE 5                     *
;*                                                                    *
;*                          ENEMIES ATTACKING                         *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlenemies.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


	!rEnemyAttacks = r11	; Pointer to Enemy Attack List
	!rObj = r12	; Pointer to RLObject
	!rTObj = r13	; Pointer to Target RLObject


;
;	* * * * * * *       ENEMIES ATTACKING       * * * * * * *
;

;
;	>>>   START ENEMIES ATTACKING   <<<
;
_RLEnemiesAttack:
	iwt r0,#lo16(_RLEnemyBirths)	; Pointer to Enemy BirthList
	sms (ENBirthsPtr&$FFFF),r0
	iwt !rEnemyAttacks,#lo16(_RLEnemyAttacks)	; Pointer to Enemy AttackList
;
;	>>>   PROCESS NEXT ENEMY   <<<
;
_RLEA2000:
;	to	r0				; Get Next Enemy
	ldw (!rEnemyAttacks)
	inc !rEnemyAttacks
	moves !rObj,r0
	beq _RLEA10000-1	; No More Enemies!
;
;	>>>   TARGET STILL ACQUIRED?   <<<
;
	ibt r0,#rloTObj	; Get TARGET OBJECT
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
	moves !rTObj,r0
	beq _RLEA2000	; NO!  CAN'T ATTACK!
	inc !rEnemyAttacks
;
;	>>>   CALL ENEMY ATTACK ROUTINE   <<<
;
	to r10	; Get Enemy Attack Code
	ldw (!rEnemyAttacks)
	sms (ENEnemy&$FFFF),!rEnemyAttacks	; Save Enemy Attacks List Index
	jmp r10
	nop
;
;	>>>   START SOUND EFFECT   <<<
;
_RLEA5000:
	ibt r0,#bank(_MObjData)	; MObjData Bank
	romb
	ibt r0,#rloMData	; Get Pointer to MObjData
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
;	from	r0				; Get Attack Sound Effect
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
	link #4	; Start Sound Effect
	iwt r15,#lo16(_RLSoundEffect)
	dec r3
;
;	>>>   NEXT ENEMY ATTACK   <<<
;
_RLEA8000:
	lms !rEnemyAttacks,(ENEnemy&$FFFF)	; Restore Enemy Attacks List Index
_RLEA8200:
	inc !rEnemyAttacks	; Move to Next Enemy Attack
	inc !rEnemyAttacks
	bra _RLEA2000+1
;	to	r0				; Get Next Enemy
	ldw (!rEnemyAttacks)

;
;	>>>   FINISHED ENEMIES ATTACKS   <<<
;
_RLEA10000:
	lms r1,(ENBirthsPtr&$FFFF)	; Terminate BirthList
;	with	r0
	sub r0
;	from	r0
	stw (r1)
;
	if !DEBUGSCR != 0
	iwt r0,#lo16(_RLEnemyBirths-1)	; #Enemy Births
	from r1
;	to	r0
	sub r0
	iwt r6,#((32768/6)<<1)
;	with	r0
	fmult
	sm (DebugEnemyBirths&$FFFF),r0
	endif
;
	iwt r0,#lo16(_RLEnemiesBirth)	; HANDLE ENEMY BIRTHS
	ibt r8,#bank(_RLEnemiesBirth)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	* * * * * * *       ENEMIES ATTACKING SUBROUTINES       * * * * * * *
;

;
;	* * * * * * *       FIGHT WITH TARGET       * * * * * * *
;
_RLEAFight:
	ibt r0,#rloTDistance	; Get TARGET DISTANCE
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
	ibt r1,#(edFightDistance+1)	; Within Fighting Distance of Target?
;	with	r0				; @CMP@
	sub r1
	bge _RLEA8200-1	; No!  Can't Fight!
;
;	>>>   ENSURE WITHIN VERTICAL DISTANCE!   <<<
;
	ibt r1,#rloZ	; Get ENEMY Z
	from r1
;	to	r0
	add !rObj
;	to	r0
	ldw (r0)
	with r1	; Get TARGET Z
	add !rTObj
	to r1
	ldw (r1)
	with r1	; R1 = (ENEMY Z - TARGET Z)
	sub r0
	ibt r4,#(odhTarget*3/4)
	from r1	; WITHIN 3/4H ABOVE?
;	to	r0
	sub r4
	bge _RLEA8200	; No!  Too Far Above!
;	with	r0
	not
	inc r0
;	with	r0
	lsr
;	with	r0				; WITHIN 3/4H BELOW?
	sub r4
	bge _RLEA8200-1	; No!  Too Far Below!
;
;	>>>   DAMAGE TARGET RLOBJECT   <<<
;
	ibt r4,#rlmodAttackCloseDamage	; Damage Multiplier/Range
	link #4
	iwt r15,#lo16(_RLDamageObjectM)
	nop
	ibt r1,#rlmodAttackCloseSound	; Fighting Sound Effect
	bra _RLEA5000+1	; Finished Fighting Target!

;
;	* * * * * * *       SHOOT AT TARGET       * * * * * * *
;
_RLEAShoot:
;
;	>>>   GET RANDOM NUMBER   <<<
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
	getb
;	with	r0				; 1/8 Chance of Missing
	%and_i($07)
	beq _RLEAShoot2-1	; Missed Target!
;
;	>>>   INACCURACY INCREASES WITH DISTANCE   <<<
;
	ibt r4,#(rloTDistance+1)	; Get TARGET DISTANCE
	with r4
	add !rObj
	to r4
	ldb (r4)
;	with	r0				; Random < TargetDistance?
	sub r4
	blt _RLEAShoot2-1	; Missed Target!
;
;	>>>   DAMAGE TARGET RLOBJECT   <<<
;
	ibt r4,#rlmodAttackFarDamage	; Damage Multiplier/Range
	link #4
	iwt r15,#lo16(_RLDamageObjectM)
	nop
_RLEAShoot2:
	ibt r1,#rlmodAttackFarSound	; Shooting Sound Effect
	iwt r15,#lo16(_RLEA5000)-2	; Finished Shooting Target!

;
;	>>>   LAUNCH MISSILE AT TARGET   <<<
;
_RLEALaunchMissile:
	iwt r0,#lo16(modMissile)	; Birth a MISSILE
	iwt r1,#lo16(_RLEBirthMissile)
	bra _RLEAQEnemyBirth
	nop
;
;	>>>   LAUNCH FIREBALL7 AT TARGET   <<<
;
_RLEALaunchFireBall7:
	iwt r0,#lo16(modFireBall7)	; Birth a FIREBALL7
	bra _RLEALaunchFireBall
	nop
;
;	>>>   LAUNCH FIREBALL2 AT TARGET   <<<
;
_RLEALaunchFireBall2:
	iwt r0,#lo16(modFireBall2)	; Birth a FIREBALL2
	bra _RLEALaunchFireBall
	nop
;
;	>>>   LAUNCH FIREBALL1 AT TARGET   <<<
;
_RLEALaunchFireBall1:
	iwt r0,#lo16(modFireBall1)	; Birth a FIREBALL1
_RLEALaunchFireBall:
	iwt r1,#lo16(_RLEBirthFireBall)	; Birth a FIREBALL
;
;	>>>   QUEUE AN ENEMY BIRTH   <<<
;
;	!!!   WARNING!!!   FALLS THROUGH FROM ABOVE!!!
;
_RLEAQEnemyBirth:
	lms r4,(ENBirthsPtr&$FFFF)	; BirthList Pointer
;	from	r0				; Birth MovableRLObject Data
	stw (r4)
	inc r4
	inc r4
	from !rObj	; Parent RLObject
	stw (r4)
	inc r4
	inc r4
	from r1	; Birth Routine
	stw (r4)
	inc r4
	inc r4
	sms (ENBirthsPtr&$FFFF),r4
	iwt r15,#lo16(_RLEA8200)+1
	inc !rEnemyAttacks	; Move to Next Enemy Attack

	if !RLDOOM2MONSTERS != 0
;
;	>>>   DOOM II ATTACKS   <<<
;
_RLEALaunchArachPlasma:
	iwt r0,#lo16(modArachPlasma)	; Arachnotron: plasma
	iwt r15,#lo16(_RLEALaunchFireBall)
	nop
_RLEALaunchRevenantShot:
	iwt r0,#lo16(modRevenantShot)	; Revenant: missile (not homing)
	iwt r15,#lo16(_RLEALaunchFireBall)
	nop
_RLEALaunchMancubusL:
	iwt r0,#lo16(modMancubusShot)	; Mancubus: fireball ANG90/8 to the left
	iwt r1,#lo16(_RLEBirthFireBallSL)
	iwt r15,#lo16(_RLEAQEnemyBirth)
	nop
_RLEALaunchMancubusR:
	iwt r0,#lo16(modMancubusShot)	; Mancubus: fireball ANG90/8 to the right
	iwt r1,#lo16(_RLEBirthFireBallSR)
	iwt r15,#lo16(_RLEAQEnemyBirth)
	nop
_RLEALaunchLostSoul:
	iwt r0,#lo16(modLostSoulPE)	; Pain Elemental: a lost soul
	iwt r1,#lo16(_RLEBirthMonster)
	iwt r15,#lo16(_RLEAQEnemyBirth)
	nop
;
;	Arch-Vile: 20 damage to a target in sight (PC: + 70 radius and a lift), flames on it
;
_RLEAVileAttack:
	ibt r4,#rlmodAttackFarDamage	; Damage Multiplier/Range
	link #4
	iwt r15,#lo16(_RLDamageObjectM)
	nop
	lms !rEnemyAttacks,(ENEnemy&$FFFF)	; (restore: the damage code uses R11)
	iwt r0,#lo16(modVileFire)	; Flames at the target
	iwt r1,#lo16(_RLEBirthAtTarget)
	iwt r15,#lo16(_RLEAQEnemyBirth)
	nop

;
;	Arch-Vile (this port, as the PC's A_VileChase; queued by its walk animation):
;	a corpse that can rise (VileRaiseAnims; dead: no longer TARGET) close to it
;	(|dX|, |dY| < the corpse's radius + 35: the PC takes the vile's radius 20
;	and a step of 15 ahead) with room around it (no ACTIVE SOLID object
;	overlapping, the vile included) rises: alive again (rlmisc.asm
;	_RLAliveAgain: health, flags, its sleep state), its death frames backwards;
;	the vile heals, DSSLOP (its close attack sound, unused otherwise).
;
	!rVX = r7	; Vile X
	!rVY = r8	; Vile Y
	!rCount = r9	; Objects left
	!rCorpse = r10	; The object looked at
	!rRaiseA = r5	; Its raise animation
	VileRaiseReach = 35	; (radius 20 + step 15)
;
_RLEAVileSeek:
	from !rObj	; The vile's X/Y
	%add_i((rloX+2))
	to !rVX
	ldw (r0)
	%add_i(((rloY+2)-(rloX+2)))
	to !rVY
	ldw (r0)
	iwt !rCorpse,#lo16(_RLMObjects)	; (slot 0 is the player)
	iwt !rCount,#(MaxRLMObjects-1)
_RLEAVS1:
	ibt r0,#bank(_MObjData)	; (VileRaiseAnims)
	romb
_RLEAVS8:
	ibt r0,#rloSize	; Next object
	with !rCorpse
	add r0
	dec !rCount
	bmi _RLEAVS9
	from !rCorpse	; A monster that rises?
	%add_i(rloType)
	ldb (r0)
	%sub_i(otSoldier)
	ibt r1,#(otMObj-otSoldier)
	from r1
	cmp r0
	bcc _RLEAVS8	; (unsigned: no)
;	with	r0
	add r0
	iwt r1,#lo16(VileRaiseAnims)
	to r14
	add r1
	getb
	inc r14
	getbh
	moves !rRaiseA,r0
	beq _RLEAVS8
	from !rCorpse	; Dead? (no longer TARGET; a free slot holds none that rises)
	%add_i(rloFlags)
	ldb (r0)
	ibt r1,#rlpfTarget
	and r1
	bne _RLEAVS8
	nop
	link #4	; Close to the vile, with room to rise?
	iwt r15,#lo16(_RLVileRoom)
	nop
	moves r1,r1
	bne _RLEAVS1
	nop
;
;	>>>   THE CORPSE RISES, THE VILE HEALS   <<<
;
	move r8,!rRaiseA
	move r13,!rObj
	move !rObj,!rCorpse
	link #4
	iwt r15,#lo16(_RLAliveAgain)
	nop
	ibt r1,#rloAnim	; Its raise animation
	with r1
	add !rObj
	from r8
	stw (r1)
	move !rObj,r13
	ibt r1,#rloAnim	; The vile heals
	with r1
	add !rObj
	iwt r0,#lo16(moaARCHVILE_HEAL)
	stw (r1)
	inc r1
	iwt r0,#(51<<8)	; AnimCount 0, StateCount 51 (3 heal frames)
	inc r1
	stw (r1)
	inc r1
	inc r1
	iwt r0,#lo16(mosARCHVILE_HEAL)
	stw (r1)
	ibt r1,#rlmodAttackCloseSound	; DSSLOP
	iwt r15,#lo16(_RLEA5000)
	nop
_RLEAVS9:
	iwt r15,#lo16(_RLEA8000)	; No corpse
	nop
;
;	>>>   CLOSE TO THE VILE, WITH ROOM TO RISE?  (R1 = 0: YES)   <<<
;
;	R10 = the corpse, R7/R8 = the vile's X/Y; R0-R4, R6, R13, R14; ROM bank _ObjData
;
_RLVileRoom:
	ibt r0,#bank(_ObjData)
	romb
	from !rCorpse	; R2 = its radius
	%add_i(rloType)
	ldb (r0)
	%umult_i(rlodSize)
	iwt r1,#lo16(_ObjData+rlodDiameter)
	to r14
	add r1
	getb
	to r2
	lsr
	from !rCorpse	; R3/R4 = its X/Y
	%add_i((rloX+2))
	to r3
	ldw (r0)
	%add_i(((rloY+2)-(rloX+2)))
	to r4
	ldw (r0)
	ibt r13,#VileRaiseReach	; Close to the vile?
	with r13
	add r2
	from r3
	sub !rVX
	bpl _RLVR0
	nop
	not
	inc r0
_RLVR0:
	cmp r13
	bge _RLVR9
	from r4
	sub !rVY
	bpl _RLVR1
	nop
	not
	inc r0
_RLVR1:
	cmp r13
	bge _RLVR9
	nop
	iwt r1,#lo16(_RLMObjects)	; Every movable object (the player first; a
	iwt r6,#MaxRLMObjects	;  corpse or a free slot is not SOLID)
_RLVR2:
	from r1	; ACTIVE and SOLID?
	%add_i(rloFlags)
	ldb (r0)
	iwt r13,#(rlpfActive|rlpfSolid)
	and r13
	cmp r13
	bne _RLVR8
	from r1	; R13 = the two radii
	%add_i(rloType)
	ldb (r0)
	%umult_i(rlodSize)
	iwt r13,#lo16(_ObjData+rlodDiameter)
	to r14
	add r13
	getb
;	with	r0
	lsr
	to r13
	add r2
	from r1	; |dX| < R13?
	%add_i((rloX+2))
	ldw (r0)
	sub r3
	bpl _RLVR4
	nop
	not
	inc r0
_RLVR4:
	cmp r13
	bge _RLVR8
	from r1	; |dY| < R13?
	%add_i((rloY+2))
	ldw (r0)
	sub r4
	bpl _RLVR5
	nop
	not
	inc r0
_RLVR5:
	cmp r13
	bge _RLVR8
	nop
_RLVR9:
	jmp r11	; No (too far, or no room)
	ibt r1,#1
_RLVR8:
	ibt r0,#rloSize	; Next object
	with r1
	add r0
	dec r6
	bne _RLVR2
	nop
	jmp r11	; Yes
	ibt r1,#0
;
;	MAP30 boss shooter: a monster (_RLBrainSpawnMods) at a random spawn spot (otBossTarget)
;
_RLEABrainSpit:
	ibt r0,#bank(RandomTable)	; R3 = Random Number (spots to pass)
	romb
	ibt r0,#lo16(RandomNumI)
	assert (lo16(RandomNumI))&$FFFF < $80 || (lo16(RandomNumI))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	to r14
	ldb (r0)
	move r0,r14
	inc r0
	sbk
	to r3
	getb
	ibt r4,#0	; R4 = spot seen in this pass?
_RLEABS1:
	iwt r2,#lo16(_RLMObjects)
	iwt r5,#MaxRLMObjects
_RLEABS2:
	to r0	; Free?
	ldw (r2)
	inc r0
	beq _RLEABS3
	nop
	ibt r0,#rloType	; A spawn spot?
	add r2
	ldb (r0)
	ibt r1,#otBossTarget
	sub r1
	bne _RLEABS3
	nop
	ibt r4,#1
	dec r3	; This one?
	bmi _RLEABS5
	nop
_RLEABS3:
	ibt r0,#rloSize
	with r2
	add r0
	dec r5
	bne _RLEABS2
	nop
	dec r4	; Another pass if there are spots
	bpl _RLEABS1
	ibt r4,#0
	iwt r15,#lo16(_RLEA8200)	; No spawn spots
	nop
_RLEABS5:
	move !rObj,r2	; (the spot is the "parent" of the birth)
	ibt r0,#bank(RandomTable)	; Which monster?
	romb
	ibt r0,#lo16(RandomNumI)
	to r14
	ldb (r0)
	move r0,r14
	inc r0
	sbk
	getb
	%and_i(15)
	to r2
	add r0
	ibt r0,#bank(_RLBrainSpawnMods)	; (ROMB before R14: the ROM read starts with R14)
	romb
	iwt r1,#lo16(_RLBrainSpawnMods)
	from r2
	to r14
	add r1
	getb
	inc r14
	getbh
	iwt r1,#lo16(_RLEBirthMonster)
	iwt r15,#lo16(_RLEAQEnemyBirth)
	nop
	endif
