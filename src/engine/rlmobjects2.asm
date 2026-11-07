	arch 65816
;**********************************************************************
;*                                                                    *
;*                  P R O J E C T :   REALITY_ENGINE                  *
;*                                                                    *
;*                  MOVABLE OBJECT HANDLING MODULE 2                  *
;*                                                                    *
;*               MOVABLE OBJECT ANIMATION STATE MACHINE               *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlenemies.inc"
	incsrc "src/include/rlobjects.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


	!rRadiusDamages = r7	; Radius Damage List
	!rEnemyAttacks = r8	; Enemy Attack List
	!rFPSCount = r9	; Frames in last update
	!rMObjPtr = r10	; Pointer to MObjList
	!rObj = r12	; Pointer to RLObject
	!rMObjCount = r13	; Counter of MObjs


;
;	* * * * * * *       REALITY_ENGINE MOVABLE OBJECTS ANIMATION STATE MACHINE       * * * * * * *
;
	%align_pad(1, 16, (_RLMA10000-_RLMAObjectsAlign)&$0F)	; align 16,(_RLMA10000-_RLMAObjectsAlign)&$0f
;
;	>>>   FINISHED PROCESSING MOVABLE OBJECTS   <<<
;
_RLMA10000:
	ibt r0,#0
	stw (!rEnemyAttacks)	; Terminate Attack List
	stw (!rRadiusDamages)	; Terminate Radius Damage List
;
	if !DEBUGSCR != 0
	iwt r0,#lo16(_RLEnemyAttacks)	; #Enemy Attacks
	from !rEnemyAttacks
;	to	r0
	sub r0
;	with	r0
	lsr
;	with	r0
	lsr
	sm (DebugEnemyAttacks&$FFFF),r0
	endif
;
	if usePATCH == 0
	iwt r0,#lo16(_RLEnemiesTarget)	; HANDLE ENEMY TARGETTING
	endif
	if usePATCH != 0
	lms r0,(PTRLEnemiesTarget&$FFFF)	; HANDLE ENEMY TARGETTING
	endif
	ibt r8,#bank(_RLEnemiesTarget)
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
_RLMAObjects:
	lms !rFPSCount,(FPSCount+RLGSUSNESXVarsO&$FFFF)	; Get FPSCount
	inc !rFPSCount
	lms r0,(SkillLevel&$FFFF)	; Nightmare: monsters animate (and attack) twice as fast
	%sub_i(4)
	sms (NMFast&$FFFF),r0	; (0 = Nightmare)
	iwt !rMObjPtr,#lo16(_RLMObjs)	; MovableObjects List
	lms !rMObjCount,(RLNumPMObjs&$FFFF)
	iwt !rEnemyAttacks,#lo16(_RLEnemyAttacks)	; Enemy Attack List
	iwt !rRadiusDamages,#lo16(_RLRadiusDamages)	; Radius Damages List
	iwt r11,#lo16(_RLMA3000)	; Return Address from Code
	ibt r0,#bank(_MObjData)
	romb

	%CACHEB(_RLMAObjects)
_RLMAObjectsAlign:
;
;	>>>   NEXT MOVABLE OBJECT   <<<
;
_RLMA2200:
	dec !rMObjCount	; Any More MObjs?
	bmi _RLMA10000	; No
_RLMA2300:
	to !rObj	; Get Next MovableObject
	ldw (!rMObjPtr)
	inc !rMObjPtr
	inc !rObj
	beq _RLMA2300
	inc !rMObjPtr
;
;	>>>   GET ANIMATION COUNTER   <<<
;
	move r3,!rFPSCount	; VBlanks to advance
	lms r0,(NMFast&$FFFF)
	moves r0,r0
	bne _RLMA2400	; Not Nightmare
	nop
	ibt r0,#rloType	; A monster?
	add !rObj
	ldb (r0)
	%sub_i(otSoldier)
	ibt r1,#(otMObj-otSoldier)
	from r1
	cmp r0
	bcc _RLMA2400	; (unsigned: no)
	nop
	with r3	; Yes: twice as fast
	add r3
_RLMA2400:
	ibt r6,#rloAnimCount	; Get AnimCount
	with r6
	add !rObj
;	to	r0
	ldb (r6)
;	with	r0				; HOLD State?
	sex
	bmi _RLMA2200	; Yes, Next MObj
	dec r0
;	from	r0				; R5 = AnimCount
	to r5
	sub r3
	bpl _RLMA8000
	inc r5
	ibt r0,#rloAnim	; Get AnimationPointer
;	with	r0
	add !rObj
	to r14
	ldw (r0)
;
;	>>>   NEXT ANIMATION COMMAND   <<<
;
_RLMA3000:
	getb	; Get ImageCount
	inc r14
;	from	r0
	to r1
	sex
	bmi _RLMA4000	; Call Routine/Change Animations
;
;	>>>   NEXT IMAGE   <<<
;
	with r5	; Underflow += ImageCount
	add r1
	to r4	; Get Image#
	getb
	inc r14
;	bcs	_RLMA6000			; NOT USED
	dec r5
	bpl _RLMA7000
	inc r5
	bra _RLMA3000+1
	getb	; Get ImageCount
;
;	>>>   CHANGE ANIMATIONS   <<<
;
_RLMA4000:
	with r0	; @WITH IN PIPELINE@
	lsr
	bcs _RLMA5000
	getb	; Get Animation Pointer
	inc r14
	to r14
	alt1
	bra _RLMA3000
	getb	; (with the ALT1 above: getbh)

;
;	>>>   CALL SUBROUTINE   <<<
;
_RLMA5000:
;	getb					; Get Routine Address
	inc r14
	ibt r5,#0	; No AnimCount Underflow
	to r15
	getbh
	inc r14
;
;	>>>   FORCE DISPLAY OF IMAGE   <<<
;
_RLMA6000:
	move r5,r1	; Reset AnimCount
;
;	>>>   SAVE IMAGE/ANIMATION POINTER   <<<
;
_RLMA7000:
	ibt r0,#rloImage	; Move to Image
;	with	r0
	add !rObj
	from r4	; Save Image#
	stb (r0)
	inc r0
	from r14	; Save AnimPointer
	stw (r0)
;
;	>>>   SAVE NEW ANIMCOUNT   <<<
;
_RLMA8000:
	from r5	; Save AnimCount
	alt1
	bra _RLMA2200
	stw (r6)	; (with the ALT1 above: stb (r6))

;
;	* * * * * * *       REALITY_ENGINE OBJECTS ANIMATION SUBROUTINES       * * * * * * *
;

;
;	>>>   QUEUE AN ENEMY ATTACK   <<<
;
_RLMAQEnemyAttack:
	iwt r0,#lo16(_RLEnemyAttacksE-4)	; Attacking List Full?
;	with	r0				; @CMP@
	sub !rEnemyAttacks
	getb	; Get Enemy Attack Routine
	beq _RLMAQEnemyAttack2	; Yes!  Can't Attack!
	inc r14
	from !rObj	; Enemy RLObject
	stw (!rEnemyAttacks)
	inc !rEnemyAttacks
	inc !rEnemyAttacks
	getbh
;	from	r0				; Enemy Attack Routine
	stw (!rEnemyAttacks)
	inc !rEnemyAttacks
	inc !rEnemyAttacks
_RLMAQEnemyAttack2:
	jmp r11
	inc r14

;
;	>>>   QUEUE AN ENEMY ATTACK BASED ON DISTANCE   <<<
;
_RLMAQEnemyDAttack:
	iwt r0,#lo16(_RLEnemyAttacksE-4)	; Attacking List Full?
;	with	r0				; @CMP@
	sub !rEnemyAttacks
	move r2,r14	; Save AnimState Pointer
	beq _RLMAQEnemyDAttack9	; Yes!  Can't Attack!
	from !rObj	; Enemy RLObject
	stw (!rEnemyAttacks)
	inc !rEnemyAttacks
	inc !rEnemyAttacks
	ibt r0,#rloTDistance	; Get Distance to Target
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
	ibt r1,#edFightDistance	; CLOSE or FAR?
;	with	r0				; @CMP@
	sub r1
	blt _RLMAQEnemyDAttack2	; CLOSE
	nop
	inc r14	; FAR
	inc r14
_RLMAQEnemyDAttack2:
	getb	; Get Enemy Attack Routine
	inc r14
	getbh
;	from	r0
	stw (!rEnemyAttacks)
	inc !rEnemyAttacks
	inc !rEnemyAttacks
_RLMAQEnemyDAttack9:
	from r2	; Move Past Attack Code
	to r14
	add #4
	jmp r11
	nop

;
;	>>>   BFG HAS EXPLODED -- REMOVE THE MOVEABLE RLOBJECT   <<<
;
_RLMABFGDie:
;
;	>>>   MISSILE/BARREL HAS EXPLODED -- REMOVE THE MOVEABLE RLOBJECT   <<<
;
_RLMAMissileDie:
_RLMABarrelDie:
	iwt r0,#lo16(_RLRadiusDamagesE-6)	; Radius Damage List Full?
;	with	r0				; @CMP@
	sub !rRadiusDamages
	ibt r0,#rloMData
	beq _RLMAEnemyDie2	; Yes!  No Radius Damage!
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
	ibt r1,#rlmodAttackFarDamage	; Move to AttackFarDamage
	move r2,r14	; Save AnimState Pointer
;	from	r0
	to r14
	add r1
	getb	; DAMAGE
	inc r14
	getbh
;	from	r0
	stw (!rRadiusDamages)
	inc !rRadiusDamages
	inc !rRadiusDamages
	from !rObj	; OBJECT X
;	to	r0
	%add_i((rloX+2))
;	to	r0
	ldw (r0)
;	from	r0
	stw (!rRadiusDamages)
	inc !rRadiusDamages
	inc !rRadiusDamages
	from !rObj	; OBJECT Y
;	to	r0
	%add_i((rloY+2))
;	to	r0
	ldw (r0)
;	from	r0
	stw (!rRadiusDamages)
	move r14,r2	; Restore AnimState Pointer
	inc !rRadiusDamages
	bra _RLMAEnemyDie2
	inc !rRadiusDamages
;
;	>>>   SOLDIER/SERGEANT HAS DIED -- CONVERT TO ITEM   <<<
;
_RLMASoldierDie:
_RLMASergeantDie:
	from !rObj	; ENEMY NOW DEAD!
;	to	r0
	%add_i(rloFlags)
;	to	r0
	ldw (r0)
	ibt r1,#rlpfItem	; Now an ITEM!
;	with	r0
	or r1
	bra _RLMAEnemyDie
;	from	r0
	sbk
;
;	>>>   PROJECTILE HAS EXPLODED -- REMOVE THE MOVEABLE RLOBJECT   <<<
;
_RLMAProjectileDie:
;
;	>>>   ENEMY HAS DIED -- REMOVE THE MOVEABLE RLOBJECT   <<<
;
_RLMAEnemyDie2:
	ibt r0,#rloSector	; Get Sector
;	with	r0
	add !rObj
;	to	r0
	ldb (r0)
;	with	r0
	%umult_i(rlsdSize)
	iwt r1,#lo16(_RLSectorData+rlsdObjects)	; R1 = SectorData.FirstObject
	with r1
	add r0
;
	lms r0,(RLNumMObjs&$FFFF)	; RLNumMObjects--
	dec r0
;	from	r0
	sbk
;
	move r2,!rObj	; R2 = RLObject.Next
	to r2
	ldw (r2)
	ibt r0,#-1	; Free the RLMObject!
;	from	r0
	sbk
_RLMAEnemyDie2E:
;	to	r0				; R0 = Object.Next
	ldw (r1)
;	from	r0				; Object.Next = RLObject?
	cmp !rObj
;
	if !useCHECKSECTOROBJECTS == 0
	with r0	; Object = Object.Next
	bne _RLMAEnemyDie2E
	to r1
	endif
;
	if !useCHECKSECTOROBJECTS != 0
	beq _RLMAEnemyDie2R	; YES!  Remove It!
	nop
	moves r1,r0	; Object = Object.Next
	bne _RLMAEnemyDie2E
	%HALTGSU($72)	; ERROR!
_RLMAEnemyDie2R:
	endif
;
	from r2	; Object.Next = RLObject.Next
	sbk
	moves r2,r2	; Any Next?
	beq _RLMAEnemyDie	; No!
	inc r2	; RLObject.Next.Prev = RLObject.Prev
	inc r2
	from !rObj
;	to	r0
	%add_i(rloPrev)
;	to	r0				; R0 = RLObject.Previous
	ldw (r0)
;	from	r0
	stw (r2)
;
;	>>>   ENEMY HAS DIED -- LEAVE THE MOVABLE RLOBJECT   <<<
;
_RLMAEnemyDie:
	lms r0,(RLNumPMObjs&$FFFF)	; RLNumPMObjects--
	dec r0
;	from	r0
	sbk
	from !rObj	; ENEMY NOW DEAD!
;	to	r0
	%add_i(rloFlags)
;	to	r0
	ldw (r0)
	ibt r1,#(rlpfSolid|rlpfTarget)	; Neither SOLID, nor TARGET!
;	with	r0
	bic r1
;	from	r0
	sbk
	from !rMObjPtr	; Remove MObject from Process List
	to r1
	sub #2
	ibt r0,#-1
;	iwt	r15,#<_RLMA3000
	jmp r11
;	from	r0
	stw (r1)

;
;	>>>   ENEMY IS FALLING   <<<
;
_RLMAEnemyFall:
	ibt r0,#rloSector	; Get Sector's Floor
;	with	r0
	add !rObj
;	to	r0				; Get Sector
	ldb (r0)
;	with	r0
	%umult_i(rlsdSize)
	iwt r1,#lo16(_RLSectorData+rlsdFloorHeight)
;	with	r0				; R2 = FloorHeight
	add r1
	to r2
	ldw (r0)
	ibt r0,#rloZ	; Get Object's Z
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
	ibt r1,#8	; Fall Speed
	with r1
	umult !rFPSCount
;	with	r0
	sub r1
;	from	r0				; Z < Floor?
	cmp r2
	bge _RLMAEnemyFall5	; No, Keep Falling
	moves r0,r2	; YES!
	bra _RLMAEnemyDie	; Kill the Enemy
	sbk
_RLMAEnemyFall5:
	iwt r15,#lo16(_RLMA2200)	; Process Next Enemy
	sbk

;
;	>>>   CYBERDEMON -- LEVEL END E2M8; E4M6: THE DOORS TAGGED 666 OPEN   <<<
;
_RLMACyberDemonDie:
	if !RLMAP07 != 0
	iwt r15,#lo16(_RLMAEnemyDie)	; (this port) DOOM II sets: no level end (PC: only MAP07 bosses)
	nop
	endif
	lms r1,(EMNUM&$FFFF)	; Get Level#
	iwt r0,#((6<<8)+4)	; E4M6? (this port, as the PC: the last one opens the doors
	sub r1	;  tagged 666; the FX3 cartridge ended the level)
	bne _RLMACDD2
	nop
	iwt r2,#otCyberDemon
	iwt r4,#(((666&$FF)<<8)|0)	; (type 0: open the doors)
	iwt r15,#lo16(_RLMAD2Boss)
	nop
_RLMACDD2:
	iwt r0,#((8<<8)+2)	; E2M8?
	sub r1
	beq _RLMASpiderDemonDie
	nop
	iwt r15,#lo16(_RLMAEnemyDie)	; No (original: "bne _RLMAEnemyDie-1" ran a stray "stw (r2)")
	nop
;
;	>>>   SPIDERDEMON (DOOM: ANY LEVEL BUT E4M8) AND BOSS BRAIN -- LEVEL END   <<<
;
_RLMASpiderDie:
	if !RLMAP07 != 0
	iwt r15,#lo16(_RLMAEnemyDie)	; (this port) DOOM II sets: the Spider Mastermind ends no level
	nop
	endif
	lms r1,(EMNUM&$FFFF)	; E4M8? (this port, as the PC: the last one lowers the floor
	iwt r0,#((8<<8)+4)	;  tagged 666 to its lowest neighbour; the FX3 cartridge ended
	sub r1	;  the level)
	bne _RLMASpiderDemonDie
	nop
	iwt r2,#otSpiderDemon
	iwt r4,#(((666&$FF)<<8)|38)	; (W1 lower floor to lowest neighbour)
	iwt r15,#lo16(_RLMAD2Boss)
	nop
_RLMASpiderDemonDie:	; (the Boss Brain enters here)
	ibt r0,#11	; 11=GO TO NEXT LEVEL
	sms (ExitLevel&$FFFF),r0
	bra _RLMAEnemyDie
	nop

;
;	>>>   BARON OF HELL HAS DIED -- SPECIAL TRIGGER ON E1M8 *CONTINUED*   <<<
;
_RLMABaronOfHellDie2:
	iwt r11,#lo16(_RLMA3000)
	ibt r0,#bank(_MObjData)
	romb
	ibt r5,#0	; No AnimCount Underflow
	lms !rObj,(ENEnemy&$FFFF)
	ibt r6,#rloAnimCount	; Get AnimCount
	with r6
	add !rObj
	lms !rMObjPtr,(ENTObj&$FFFF)
	lms !rEnemyAttacks,(ENBirthsPtr&$FFFF)
	lms !rRadiusDamages,(ENRadiusPtr&$FFFF)
	lms !rFPSCount,(FPSCount+RLGSUSNESXVarsO&$FFFF)	; Get FPSCount
	inc !rFPSCount
	iwt r15,#lo16(_RLMAEnemyDie)	; (this port: out of bra range)
	nop
;
;	>>>   BARON OF HELL HAS DIED -- SPECIAL TRIGGER ON E1M8   <<<
;
_RLMABaronOfHellDie:
	if !RLMAP07 != 0
	iwt r15,#lo16(_RLMAEnemyDie)	; (this port) DOOM II sets: no E1M8 trigger
	nop
	endif
	lms r0,(EMNUM&$FFFF)	; Get Level#
	iwt r1,#((8<<8)+1)	; E1M8?
;	with	r0
	sub r1
	beq _RLMABOHD1	; Yes (_RLMAEnemyDie is out of branch range)
	nop
	iwt r15,#lo16(_RLMAEnemyDie)
	nop
_RLMABOHD1:
	iwt r1,#lo16(BaronOfHellCount)	; BaronOfHell Counter++
;	to	r0
	ldb (r1)
	inc r0
	stb (r1)
;	with	r0				; BOTH BARONS DEAD?
	sub #2
	beq _RLMABOHD2	; Yes (_RLMAEnemyDie is out of branch range)
	nop
	iwt r15,#lo16(_RLMAEnemyDie)
	nop
_RLMABOHD2:
;
;	>>>   SPECIAL TRIGGER 666   <<<
;
	sms (ENTObj&$FFFF),!rMObjPtr
	ibt r6,#30	; R6 = SECTOR
	iwt r5,#-136	; R5 = DESTINATION HEIGHT
	sms (ENRadiusPtr&$FFFF),!rRadiusDamages
	ibt r7,#(_TPCFloorLower-_TPlatformCode)
	sms (ENEnemy&$FFFF),!rObj
	iwt r12,#lo16(_RLMABaronOfHellDie2)
	sms (ENBirthsPtr&$FFFF),!rEnemyAttacks
	iwt r15,#lo16(_RLAddPlatformFloor)
	nop


	if !RLDOOM2MONSTERS != 0
;
;	>>>   HANG FROM THE CEILING (COMMANDER KEEN, DOOM II)   <<<
;
_RLMAHang:
	ibt r0,#rloSector	; Get Sector's Ceiling
;	with	r0
	add !rObj
	ldb (r0)
	%umult_i(rlsdSize)
	iwt r1,#lo16(_RLSectorData+rlsdCeilingHeight)
	add r1
	ldw (r0)
	iwt r1,#odhKeen	; Z = Ceiling - Height
	sub r1
	ibt r1,#rloZ
	with r1
	add !rObj
	stw (r1)
	jmp r11
	nop
;
;	>>>   TARGET THE PLAYER (MAP30 BOSS SHOOTER: it sits out of sight)   <<<
;
_RLMATargetPlayer:
	ibt r0,#rloTObj
	add !rObj
	iwt r1,#lo16(PlayerObject)
	from r1
	stw (r0)
	jmp r11
	nop

;
;	>>>   BOSS SPECIALS (PC A_BossDeath, A_KeenDie)   <<<
;
;	DOOM II MAP07: the last Mancubus lowers the floors tagged 666 (to the lowest
;	neighbour), the last Arachnotron raises the ones tagged 667; MAP32: the last
;	Commander Keen opens the doors tagged 666.  DOOM E4M6: the last Cyberdemon opens
;	the doors tagged 666, E4M8: the last Spider Mastermind lowers the floor tagged
;	666 (_RLMACyberDemonDie, _RLMASpiderDie).  (wad2rl.py and fx3_convert_levels.py
;	add the FLOORS/DOORS records; tags are bytes: 666 -> 154, 667 -> 155)
;
_RLMAMancubusDie:
	iwt r1,#!RLMAP07
	iwt r2,#otMancubus
	iwt r4,#(((666&$FF)<<8)|38)	; (W1 lower floor to lowest neighbour)
	bra _RLMAD2Boss
	nop
_RLMAArachnotronDie:
	iwt r1,#!RLMAP07
	iwt r2,#otArachnotron
	iwt r4,#(((667&$FF)<<8)|30)	; (W1 raise floor by the shortest lower texture)
	bra _RLMAD2Boss
	nop
_RLMAKeenDie:
	iwt r1,#!RLMAP32
	iwt r2,#otKeen
	iwt r4,#(((666&$FF)<<8)|0)	; (type 0: open the doors)
	endif
;
;	R1 = EMNUM of the map, R2 = type that has to be all dead, R4 = Tag.B/LineType.B
;	(every build; the DOOM II entries above fall through to it)
;
_RLMAD2Boss:
	lms r0,(EMNUM&$FFFF)	; This map?
	sub r1
	bne _RLMAD2B8
	nop
	iwt r1,#lo16(_RLMObjects)	; Any other one of this type alive?
	iwt r3,#MaxRLMObjects
_RLMAD2B2:
	to r0	; Free?
	ldw (r1)
	inc r0
	beq _RLMAD2B4
	nop
	from r1	; Itself?
	cmp !rObj
	beq _RLMAD2B4
	nop
	ibt r0,#rloType
	add r1
	ldb (r0)
	sub r2
	bne _RLMAD2B4
	nop
	ibt r0,#rloFlags	; Alive? (still a target)
	add r1
	ldb (r0)
	lsr	; (rlpfTarget = $20)
	lsr
	lsr
	lsr
	lsr
	%and_i(1)
	bne _RLMAD2B8	; Yes: not the last one
	nop
_RLMAD2B4:
	ibt r0,#rloSize
	with r1
	add r0
	dec r3
	bne _RLMAD2B2
	nop
	bra _RLMAD2B7
	nop
_RLMAD2B8:
	iwt r15,#lo16(_RLMAEnemyDie)
	nop
_RLMAD2B7:
;
;	>>>   THE LAST ONE: SAVE THE ANIMATION STATE, RUN THE SPECIAL   <<<
;
	sms (ENTObj&$FFFF),!rMObjPtr
	sms (ENRadiusPtr&$FFFF),!rRadiusDamages
	sms (ENEnemy&$FFFF),!rObj
	sms (ENBirthsPtr&$FFFF),!rEnemyAttacks
	sms (MVLine&$FFFF),r14
	from r4	; MVTag = Tag.B, MVType = LineType.B
	hib
	iwt r1,#lo16(MVTag)
	stb (r1)
	from r4
	lob
	iwt r1,#lo16(MVType)
	stb (r1)
	moves r0,r0	; Type 0: doors
	beq _RLMAD2Door
	nop
;
;	>>>   FLOORS: the FLOORS record of Tag/Type   <<<
;
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb
	lms r14,(EMFLOORS&$FFFF)	; Base of FloorData
	iwt r1,#lo16(MVTag)
	to r1
	ldb (r1)
	with r4
	lob
_RLMAD2F3:
	getb	; FloorTag = Tag?
	sub r1
	bne _RLMAD2F4
	inc r14
	getb	; FloorType = Type?
	sub r4
	beq _RLMAD2F5
_RLMAD2F4:
	inc r14
	getb	; Next FloorData
	%umult_i(rlpfsSize)
	inc r0
	with r14
	bra _RLMAD2F3
	add r0
_RLMAD2F5:
	sms (MVSector&$FFFF),r14	; Save FloorData Pointer
	getb	; #Sectors
	sms (MVCount&$FFFF),r0
	iwt r12,#lo16(_RLMAD2F6)
_RLMAD2F6:
	iwt r0,#lo16(EMSECTORS+2)
	ldb (r0)
	romb
	lms r0,(MVCount&$FFFF)
	dec r0
	bmi _RLMAD2Done
	sbk
	lms r14,(MVSector&$FFFF)
	inc r14
	move r10,r14	; R10 = FLOORDATA
	to r6	; R6 = SECTOR
	getb
	inc r14
	getb	; R5 = DESTINATION HEIGHT
	inc r14
	to r5
	getbh
	from r14
	%add_i((rlpfsSize-(rlpfsHeight+1)-1))
	sbk
	from r6	; R9 = SECTORDATA
	%umult_i(rlsdSize)
	iwt r9,#lo16(_RLSectorData)
	with r9
	add r0
	ibt r7,#(_TPCFloorLower-_TPlatformCode)
	from r9
	%add_i(rlsdFloorHeight)
	ldw (r0)
	sub r5	; Destination < Current?
	bge _RLMAD2F8	; Yes, Lower Floor
	nop
	ibt r7,#(_TPCFloorRise-_TPlatformCode)
_RLMAD2F8:
	iwt r15,#lo16(_RLAddPlatformFloor2)
	nop
;
;	>>>   DOORS: every door sector with the tag opens   <<<
;
_RLMAD2Door:
	lms r0,(EMDOORS&$FFFF)	; Base of Doors
	sms (MVSector&$FFFF),r0
_RLMAD2D2:
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb
	lms r14,(MVSector&$FFFF)	; Door Sector
	iwt r1,#lo16(MVTag)
	to r1
	ldb (r1)
	lms r11,(EMSECTORS&$FFFF)	; R11 = Base of Sectors
	with r11
	%add_i(rlsTag)
_RLMAD2D3:
	to r6	; Get Sector
	getb
	from r6	; End of Door Sectors?
	sex
	inc r0
	beq _RLMAD2Done
	with r14
	%add_i((rlpdNumLines-rlpdSector))
	getb	; Get #Lines
	add r0
	inc r0
	from r14	; Next DoorData
	to r12
	add r0
	from r6	; Get Sector Tag
	%umult_i(rlsSize)
	to r14
	add r11
	getb
	sub r1	; SectorTag = Tag?
	with r12
	bne _RLMAD2D3
	to r14
	ibt r4,#103	; (S1 open door: a door that stays open)
	sms (MVSector&$FFFF),r12
	iwt r12,#lo16(_RLMAD2D2)
	ibt r7,#(_TPCDoorOpen-_TPlatformCode)
	iwt r15,#lo16(_RLAddPlatformDoor2)
	nop
;
;	>>>   DONE: RESTORE THE ANIMATION STATE   <<<
;
_RLMAD2Done:
	iwt r11,#lo16(_RLMA3000)
	ibt r0,#bank(_MObjData)
	romb
	ibt r5,#0	; No AnimCount Underflow
	lms !rObj,(ENEnemy&$FFFF)
	ibt r6,#rloAnimCount	; Get AnimCount
	with r6
	add !rObj
	lms !rMObjPtr,(ENTObj&$FFFF)
	lms !rEnemyAttacks,(ENBirthsPtr&$FFFF)
	lms !rRadiusDamages,(ENRadiusPtr&$FFFF)
	lms r14,(MVLine&$FFFF)
	lms !rFPSCount,(FPSCount+RLGSUSNESXVarsO&$FFFF)	; Get FPSCount
	inc !rFPSCount
_RLMAD2B9:
	iwt r15,#lo16(_RLMAEnemyDie)
	nop

	if usePATCH != 0
;
;	>>>   PLAYER HAS DIED   <<<
;
_RLMAPlayerDie:
	lms r15,(PTRLMAPlayerDie&$FFFF)	; Call Player Death Routine
	nop
	endif


	%CACHEE(_RLMAObjects)
