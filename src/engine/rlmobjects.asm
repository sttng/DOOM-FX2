	arch 65816
;**********************************************************************
;*                                                                    *
;*                  P R O J E C T :   REALITY_ENGINE                  *
;*                                                                    *
;*                  MOVABLE OBJECT HANDLING MODULE 1                  *
;*                                                                    *
;*                    MOVABLE OBJECT STATE MACHINE                    *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlenemies.inc"


	%section(LEVEL)

;
;	* * * * * * *       REALITY_ENGINE INITIALIZE MOVABLE OBJECTS       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitMObjects:
	rep #$30		; mode 'AX!'
	lda.w #0	; NO Movable RLObjects EXIST
	sta.l RLNumMObjs
	sta.l RLNumPMObjs	; NO Movable RLObjects to PROCESS
;
	ldx.w #(MaxRLMObjects-1)*2	; NO Movable RLObjects are PROCESSING
	lda.w #-1
_RIMO200:
	sta.l _RLMObjs,x
	dex
	dex
	bpl _RIMO200
;
	ldx.w #(MaxRLMObjects*rloSize)-2	; (this port) Clear the whole table (no stale data
	lda.w #0	; from the previous level: saves pack the free slots well)
_RIMO300:
	sta.l _RLMObjects,x
	dex
	dex
	bpl _RIMO300
;
	ldy.w #(MaxRLMObjects-1)	; ALL Movable RLObjects are FREE
	ldx.w #0
_RIMO400:
	lda.w #-1
	sta.l _RLMObjects+rloNext,x
	lda.w #rlpfMovable
	sta.l _RLMObjects+rloFlags,x
	txa
	clc
	adc.w #rloSize
	tax
	dey
	bpl _RIMO400
;
	rtl



	%section(ENGINE_GSUCODE)
	arch superfx

	!rRandomNum = r4	; Random Number
	!rStateCount = r6	; StateCount
	!rEnemyTargets = r7	; Enemy Target List
	!rEnemyMoves = r8	; Enemy Move List
	!rProjectileMoves = r5	; Projectile Move List
	!rFPSCount = r9	; Frames in last update
	!rMObjPtr = r10	; Pointer to MObjList
	!rObj = r12	; Pointer to RLObject
	!rMObjCount = r13	; Counter of MObjs


;
;	* * * * * * *       REALITY_ENGINE MOVABLE OBJECTS STATE MACHINE       * * * * * * *
;
	%align_pad(1, 16, (_RLMS10000-_RLMSObjectsAlign)&$0F)	; align 16,(_RLMS10000-_RLMSObjectsAlign)&$0f
;
;	>>>   FINISHED PROCESSING MOVABLE OBJECTS   <<<
;
_RLMS10000:
	ibt r0,#0
	stw (!rEnemyMoves)	; Terminate Enemy Movement List
	stw (!rProjectileMoves)	; Terminate Projectile Movement List
	ibt r0,#$80	; Terminate Enemy Targetting List
	stw (!rEnemyTargets)
;
	if !DEBUGSCR != 0
	iwt r0,#lo16(_RLEnemyTargets)	; #Enemy Targets
	from !rEnemyTargets
;	to	r0
	sub r0
;	with	r0
	lsr
	sm (DebugEnemyTargets&$FFFF),r0
	iwt r0,#lo16(_RLEnemyMoves)	; #Enemy Moves
	from !rEnemyMoves
;	to	r0
	sub r0
;	with	r0
	lsr
	sm (DebugEnemyMoves&$FFFF),r0
	iwt r0,#lo16(_RLProjectileMoves)	; #ProjectileMoves
	from !rProjectileMoves
;	to	r0
	sub r0
;	with	r0
	lsr
	sm (DebugProjectileMoves&$FFFF),r0
	endif
;
	iwt r0,#lo16(_RLProjectileMoves)	; #ProjectileMoves
	from !rProjectileMoves
;	to	r0
	sub r0
;	with	r0
	lsr
	sms (RLNumPObjs&$FFFF),r0
;
	if usePATCH == 0
	iwt r0,#lo16(_RLMAObjects)	; HANDLE MOVABLE OBJECT ANIMATIONS
	endif
	if usePATCH != 0
	lms r0,(PTRLMAObjects&$FFFF)	; HANDLE MOVABLE OBJECT ANIMATIONS
	endif
	ibt r8,#bank(_RLMAObjects)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	>>>   START PROCESSING MOVABLE OBJECTS   <<<
;
_RLMSObjects:
	lms !rFPSCount,(FPSCount+RLGSUSNESXVarsO&$FFFF)	; Get FPSCount
	inc !rFPSCount
	iwt !rMObjPtr,#lo16(_RLMObjs)	; MovableObjects List
	lms !rMObjCount,(RLNumPMObjs&$FFFF)
	iwt !rEnemyTargets,#lo16(_RLEnemyTargets)	; Enemy Target List
	iwt !rEnemyMoves,#lo16(_RLEnemyMoves)	; Enemy Move List
	iwt !rProjectileMoves,#lo16(_RLProjectileMoves)	; Projectile Move List
	iwt r11,#lo16(_RLMS4000)

	%CACHEB(_RLMSObjects)
_RLMSObjectsAlign:
;
;	>>>   NEXT MOVABLE OBJECT   <<<
;
_RLMSHalt:
_RLMS2200:
	dec !rMObjCount	; Any More MObjs?
	bmi _RLMS10000	; No
_RLMS2300:
	to !rObj	; Get Next MovableObject
	ldw (!rMObjPtr)
	inc !rMObjPtr
	inc !rObj
	beq _RLMS2300
	inc !rMObjPtr
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
	to !rRandomNum
	getb
;
;	>>>   GET STATE/COUNT   <<<
;
	ibt r0,#bank(_MObjData)
	romb
	ibt r0,#rloState	; Get State
;	with	r0
	add !rObj
	to r14
	ldw (r0)
	dec r0	; Get StateCount
	to !rStateCount
	ldb (r0)
;
;	>>>   CALL STATE CODE   <<<
;
_RLMS3000:
	getb	; Get StateCode
	inc r14
	to r15	; Call StateCode
	getbh
	inc r14
_RLMS4000:
	ibt r1,#rloState	; Save State
	with r1
	add !rObj
	dec r0
	from r14
	bmi _RLMS3000
	stw (r1)
;
;	>>>   UPDATE STATE COUNTER   <<<
;
_RLMS6000:
	ibt r0,#rloStateCount	; Save StateCount
;	with	r0
	add !rObj
	from !rStateCount
	stb (r0)
	bra _RLMS2200
	nop

;
;	* * * * * * *       MOVABLE OBJECTS STATE MACHINE SUBROUTINES       * * * * * * *
;

;
;	>>>   QUEUE AN ENEMY MOVEMENT   <<<
;
_RLMSQEnemyMove:
	iwt r0,#lo16(_RLEnemyMovesE-2)	; Move List Full?
;	with	r0				; @CMP@
	sub !rEnemyMoves
	beq _RLMSQEnemyTarget2	; Yes!  Can't Move!
	from !rObj
	stw (!rEnemyMoves)
	inc !rEnemyMoves
	inc !rEnemyMoves
;
;	>>>   WAIT FOR STATE EXPIRATION   <<<
;
_RLMSWait:
;	moves	r0,rStateCount			; Constant State?
;	bmi	_RLMS2200			; Yes!  Don't Change State!
	with !rStateCount	; StateCount -= FPSCount
	sub !rFPSCount
	bpl _RLMS6000	; State Expired?  No!
	nop
	bra _RLMS3000
	nop

;
;	>>>   QUEUE AN ENEMY TARGET   <<<
;
_RLMSQEnemyTarget:
	ibt r0,#rloTObj	; Previously Targetted?
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
	moves r0,r0
	beq _RLMSQEnemyTargetA	; No
	from !rRandomNum
;	to	r0
	and #3
	bne _RLMSQEnemyTargetA
	nop
	ibt r1,#rlmodAwakeSound	; Yes!  Start Awake Sound
	link #4
	iwt r15,#lo16(_RLMSSoundEffect)
	nop
_RLMSQEnemyTargetA:
	iwt r0,#lo16(_RLEnemyTargetsE-2)	; Targetting List Full?
;	with	r0				; @CMP@
	sub !rEnemyTargets
	beq _RLMSQEnemyTarget2	; Yes!  Can't Target!
	from !rObj
	stw (!rEnemyTargets)
;	with	r0				; STOP STATE
	sub r0
	inc !rEnemyTargets
	inc !rEnemyTargets
	jmp r11
	inc r0	; STOP STATE
_RLMSQEnemyTarget2:
	ibt r0,#1	; STOP STATE
	dec r14
	jmp r11	; Can't Target -- Hold this State!
	dec r14

;
;	>>>   ENEMY AWAKE!   <<<
;
_RLMSEnemyAwake:
	ibt r1,#rlmodAwakeSound	; Start Awake Sound
	link #4
	iwt r15,#lo16(_RLMSSoundEffect)
	nop
	ibt !rStateCount,#80	; StateCount
	jmp r11
;	with	r0				; GO STATE
	sub r0

;
;	>>>   ENEMY SLEEPING -- AWAKEN?   <<<
;
_RLMSEnemySleep:
	ibt r0,#rloTObj	; Has Enemy Acquired Target (Player)?
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
	dec r0
	bpl _RLMSEnemyAnimState	; YES!  AWAKEN!
	with r14	; Skip past SLEEP Data
	add #4
	ibt !rStateCount,#90	; StateCount
	jmp r11
;	with	r0				; GO STATE
	sub r0
_RLMSEnemyAnimState:
	ibt !rStateCount,#70	; StateCount
	getb	; Get Animation
	inc r14
	ibt r2,#rloAnim
	with r2
	add !rObj
	getbh
	inc r14
;	from	r0
	stw (r2)
	inc r2
	inc r2
;	with	r0				; AnimCount
	sub r0
;	from	r0
	stb (r2)
_RLMSState:
	getb	; Get State
	inc r14
	to r14
	getbh
	jmp r11
;	with	r0				; GO STATE
	sub r0

;
;	>>>   DECIDE TO MOVE OR ATTACK   <<<
;
_RLMSEnemyMove0:
	ibt r2,#edInvisibleDistance	; Beyond Attack Distance?
	iwt r3,#$7FFF	; Yes?  Can't Attack!
	bra _RLMSEnemyMove2
	nop
_RLMSEnemyMove:
	iwt r2,#edMoveAttackDistance	; Beyond Maximum Move/Attack Distance?
	move r3,r2
_RLMSEnemyMove2:
	ibt r1,#rloTObj	; Has Enemy Acquired Target?
	with r1
	add !rObj
;	to	r0
	ldw (r1)
	dec r0
	bmi _RLMSEnemyMove9	; No
	inc r1	; Get Distance to Target
	inc r1
;	to	r0
	ldw (r1)
;	from	r0
	cmp r2
	blt _RLMSEnemyMove5	; No
	moves r0,r3	; Yes, Attack 30% of Time (or never if $7FFF)
_RLMSEnemyMove5:
;	with	r0				; @CMP@
	sub !rRandomNum	; Distance < RandomNumber?
	blt _RLMSEnemyAnimState+1	; Yes, Attack! (the IBT in the delay slot
;						; takes #70 from _RLMSEnemyAnimState+1)
;
;	>>>   KEEP MOVING   <<<
;
_RLMSEnemyMove9:
	ibt !rStateCount,#50	; StateCount
	with r14	; Skip past ATTACK Data
	add #4
	jmp r11
;	with	r0				; GO STATE
	sub r0

;
;	>>>   ENEMY HAS BEEN DAMAGED   <<<
;
_RLMSEnemyDamage:
	ibt r0,#rloHealth	; Get Health
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
	ibt !rStateCount,#40	; STATECOUNT
	ibt r1,#rlmodDamageSound	; _DAMAGE
	from r14	; Skip past DAMAGE Data
	to r2
	add #4
	ibt r3,#rloState	; Move to State
	dec r0
	bpl _RLMSEnemyDamage3+1	; Enemy Still Alive!
	with r3
	inc r1	; _DIE
	inc r1
	inc r14	; Move to Death Animation
	inc r14
_RLMSEnemyDamage2:
	iwt !rStateCount,#255	; STATECOUNT
_RLMSEnemyDamage3:
	with r3
	add !rObj
	from r2
	stw (r3)
	dec r3
	getb	; Get Damage Animation
	inc r14
	from !rStateCount	; StateCount/AnimCount
	stw (r3)
	dec r3
	dec r3
	dec r3
	iwt r11,#lo16(_RLMS2200)	; Hold This State!
	getbh
	iwt r15,#lo16(_RLMSSoundEffect2)
;	from	r0				; Save Damage/Death Animation
	stw (r3)

;
;	>>>   PROJECTILE HAS BEEN DAMAGED   <<<
;
_RLMSProjectileDamage:
	from r14	; Skip past DAMAGE Data
	to r2
	add #2
	ibt r3,#rloState	; Move to State
	ibt r1,#rlmodDieSound	; _DIE
	bra _RLMSEnemyDamage2
	nop

;
;	>>>   QUEUE A PROJECTILE MOVEMENT   <<<
;
_RLMSQProjectileMove:
	iwt r0,#lo16(_RLProjectileMovesE-2)	; Move List Full?
;	with	r0				; @CMP@
	sub !rProjectileMoves
	beq _RLMSQProjectileMove2	; Yes!  Can't Move!
	from !rObj
	stw (!rProjectileMoves)
	inc !rProjectileMoves
	inc !rProjectileMoves
_RLMSQProjectileMove2:
	iwt r15,#lo16(_RLMS2200)	; Hold This State!
	nop

;
;	>>>   ADD SOUND EFFECT   <<<
;
_RLMSSoundEffect:
	move r2,r14	; Save StatePointer
_RLMSSoundEffect2:
	ibt r0,#rloMData	; Get Pointer to MObjData
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
;	from	r0				; Get Sound Effect
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
	sms (MOReturnAddress&$FFFF),r11	; Save Return Address
	link #4	; Start Sound Effect
	iwt r15,#lo16(_RLSoundEffect)
	dec r3
;
	iwt r11,#lo16(_RLMS4000)
	ibt r0,#bank(_MObjData)	; MObjData Bank
	romb
	move r14,r2	; Restore StatePointer
	lms r15,(MOReturnAddress&$FFFF)
;	with	r0				; GO STATE
	sub r0


	%CACHEE(_RLMSObjects)
