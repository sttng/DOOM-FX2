	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                      MISCELLANEOUS TASKS MODULE                    *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


	%align_pad(14, 16, (_RLMisc-_RLMisc0)&$0F)	; align 16,(_RLMisc-_RLMisc0)&$0f
;
;	* * * * * * *       REALITY_ENGINE MISCELLANEOUS TASKS       * * * * * * *
;
_RLMisc:

	%CACHEB(_RLMisc)
;
;	* * * * * * *       HANDLE GENERATION COUNTER WRAPAROUND       * * * * * * *
;
_RLMisc0:
	lms r0,(RLCount&$FFFF)	; RLEngine Generation Counter
	iwt r6,#$F000	; Wrap at $F000
;	with	r0
	sub r6
	bcc _RLMisc500
;	with	r0
	sub r0
	sbk	; Reset Generation Counter
	iwt r1,#lo16(_RLSectorData-rlsdSize+rlsdRLCount)
	iwt r13,#lo16(_RLMisc100)
	lms r12,(EMNUMSECTORS&$FFFF)
_RLMisc100:
	with r1	; Next SectorData
	%add_i(rlsdSize)
	loop
;	from	r0				; Reset SectorData.RLEngineCount
	stw (r1)

;
;	* * * * * * *       HANDLE LINE GENERATION COUNTER WRAPAROUND       * * * * * * *
;
_RLMisc500:
	lms r0,(RLLineCount&$FFFF)	; RLEngine Line Generation Counter
;	with	r0
	sub r6
	bcc _RLMisc1000
;	with	r0
	sub r0
	sbk	; Reset Line Generation Counter
	iwt r1,#lo16(_RLLineRLCounts-1)
	iwt r13,#lo16(_RLMisc600)
	lms r12,(EMNUMLINES&$FFFF)
_RLMisc600:
	inc r1	; Next Line
;	from	r0				; Reset Line.RLEngineCount
	stw (r1)
	loop
	inc r1

	%CACHEE(_RLMisc)

;
;	* * * * * * *       GET FRAMES_PER_SECOND COUNTER       * * * * * * *
;
_RLMisc1000:
	lms r7,(FPSCount+RLGSUSNESXVarsO&$FFFF)	; R7 = FPSCount

;
;	* * * * * * *       ANIMATE IMAGERY       * * * * * * *
;
	lms r0,(RLFrame&$FFFF)	; Get Total #Frames
;	with	r0				; Update Total
	add r7
	sbk
	inc r0	; (+2 VBlanks)
	inc r0
;	with	r0				; Animate every 8 VBlanks (7.5fps)
	lsr
;	with	r0
	lsr
;	with	r0
	lsr
;	from	r0				; Anim2
	to r1
	%and_i($01)
;	with	r0				; Anim4
	%and_i($03)
;	with	r0
	swap
;	with	r0
	add r1
	sms (Anim2Frame&$FFFF),r0	; Anim2/Anim4

;
;	* * * * * * *       HANDLE COUNT-DOWN TIMERS       * * * * * * *
;
	lms r1,(Timer1&$FFFF)	; 1 Second CountDown Timer
	from r1
;	to	r0
	sub r7
	bpl _RLMisc1200	; Not done yet
	nop
	moves r1,r1	; Previously 0?
	bne _RLMisc1200	; No
;	with	r0				; =0
	sub r0
	ibt r0,#60	; ReStart Counter
_RLMisc1200:
	sbk

;
;	* * * * * * *       INITIALIZE RGBANIM       * * * * * * *
;
	ibt r0,#!rgbNone	; No RGB Anim Change
	sms (RLRGB&$FFFF),r0

;
;	* * * * * * *       INITIALIZE SOUND COMMAND LIST       * * * * * * *
;
;	with	r0				; NO Sounds to Process!
	sub r0
	sms (RLNumSounds&$FFFF),r0
	sm (RLNumRumbles&$FFFF),r0	; (this port) NO Rumble requests
;
	ibt r1,#lo16(PlayerHurt)	; Player NOT Hurt Yet
	assert (lo16(PlayerHurt))&$FFFF < $80 || (lo16(PlayerHurt))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	ibt r0,#1
;	from	r0
	stb (r1)

;
;	* * * * * * *       CALCULATE FRAMES_PER_SECOND <-> SPEED RATIO       * * * * * * *
;
	ibt r0,#bank(_RLSpeedFPSRatios)	; Bank of SpeedFPSRatios
	romb
	from r7	; FPSCount
;	to	r0
	add r7
	iwt r1,#lo16(_RLSpeedFPSRatios)	; Add Base of SpeedFPSRatios
;	from	r0
	to r14
	add r1
	getb	; Get SpeedFPSRatio from Table
	inc r14
	getbh
	sms (FPSRatio&$FFFF),r0	; Save FPS<->Speed Ratio

;
;	* * * * * * *       NIGHTMARE: MONSTERS COME BACK (this port, as PC DOOM)       * * * * * * *
;
	lms r0,(SkillLevel&$FFFF)
	%sub_i(4)
	bne _RLNightmareRet
	nop
	iwt r15,#lo16(_RLNightmare)
	nop
_RLNightmareRet:

;
;	* * * * * * *       HANDLE TASKS       * * * * * * *
;
	if usePATCH == 0
	iwt r0,#lo16(_RLDoTasks)	; DO TASKS
	endif
	if usePATCH != 0
	lms r0,(PTRLDoTasks&$FFFF)	; DO TASKS
	endif
	ibt r8,#bank(_RLDoTasks)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop


;
;	* * * * * * *       SPEED <-> FPS RATIOS       * * * * * * *
;
_RLSpeedFPSRatios:
	!fps #= 0
	for __rep = 0..40
	dw (!fps*20*$100)/60	; (20*fps) / 60
	!fps #= !fps+1
	endfor


;
;	* * * * * * *       NIGHTMARE RESPAWN (this port)       * * * * * * *
;
;	As PC DOOM on Nightmare: a dead monster (not a Lost Soul) comes back at
;	its start position some time after 12 seconds (5/256 chance per 32 tics
;	there, 23/65536 per VBlank here).  Its corpse object is reused: the slot
;	number of a movable object is its position among the level's movable
;	objects (they are created in level object order), so the start position
;	is found again in the level object list.  The respawn waits while the
;	player stands on the spot.  At most one monster per frame.
;
;	The corpse's rloTObj = $FFFF marks a running timer in rloTDistance
;	(VBlanks since death).
;
	!rNMObj = r12	; Object
	!rNMCount = r13	; Slots left
	!rNMFPS = r10	; VBlanks in the last frame

macro NMRAND()
;	r0 = random byte (clobbers r14, ROM bank)
	ibt r0,#bank(RandomTable)
	romb
	ibt r0,#lo16(RandomNumI)
	assert (lo16(RandomNumI))&$FFFF < $80, "ibt: value does not fit a signed byte"
	to r14
	ldb (r0)
	move r0,r14
	inc r0
	sbk
	getb
endmacro

	%align_pad(9, 16, (_RLNightmare-_RLNM1000)&$0F)
_RLNightmare:
	move !rNMFPS,r7	; FPSCount
	iwt !rNMObj,#lo16(_RLMObjects)	; (slot 0 is the player)
	iwt !rNMCount,#(MaxRLMObjects-1)
	%CACHEB(_RLNightmare)
_RLNM1000:
	ibt r0,#rloSize	; Next slot
	with !rNMObj
	add r0
	dec !rNMCount
	bpl _RLNM1100
	nop
_RLNM9000:
	iwt r15,#lo16(_RLNightmareRet)	; Done
	nop
_RLNM1100:
	move r1,!rNMObj	; Free slot?
	ldw (r1)
	inc r0
	beq _RLNM1000
	nop
	ibt r0,#rloType	; A monster (not a Lost Soul)?
	add !rNMObj
	ldb (r0)
	ibt r1,#otLostSoul
	cmp r1
	beq _RLNM1000
	nop
	%sub_i(otSoldier)
	ibt r1,#(otMObj-otSoldier)
	from r1
	cmp r0
	bcc _RLNM1000	; (unsigned: type < otSoldier or > otMObj)
	nop
	ibt r0,#rloFlags	; Dead? (not a target any more)
	add !rNMObj
	ldb (r0)
	ibt r1,#rlpfTarget
	and r1
	bne _RLNM1000
	nop
	ibt r2,#rloTObj	; Timer running?
	with r2
	add !rNMObj
	to r1
	ldw (r2)
	inc r1
	bne _RLNM2000	; No, start it (r2 = rloTObj+1 there: the odd
	inc r2	; address is the same word, and $FFFF/$0000 read the same)
	inc r2	; r2 -> rloTDistance
	to r1
	ldw (r2)
	with r1	; VBlanks since death
	add !rNMFPS
	bpl _RLNM1200
	nop
	iwt r1,#$7FFF
_RLNM1200:
	from r1
	stw (r2)
	iwt r0,#(12*60)	; 12 seconds over?
	from r1
	cmp r0
	blt _RLNM1000
	nop
	%NMRAND()	; R3 = 16-bit random, chance VBlanks*23/65536
	to r3
	swap
	%NMRAND()
	from r0
	to r3
	or r3
	from !rNMFPS
	%umult_i(15)
	add !rNMFPS
	add !rNMFPS
	add !rNMFPS	; *18
	add !rNMFPS
	add !rNMFPS
	add !rNMFPS
	add !rNMFPS
	add !rNMFPS	; *23
	from r3
	cmp r0
	bcc _RLNM1300	; (unsigned random < VBlanks*23: now)
	nop
	iwt r15,#lo16(_RLNM1000)	; Not yet
	nop
_RLNM1300:
	iwt r15,#lo16(_RLNMRespawn)
	nop
_RLNM2000:
	ibt r0,#-1	; Start the timer
	from r0
	stw (r2)
	inc r2
	inc r2
	ibt r0,#0
	iwt r15,#lo16(_RLNM1000)
	stw (r2)
	%CACHEE(_RLNightmare)

;
;	>>>   RESPAWN THE MONSTER AT r12   <<<
;
_RLNMRespawn:
;
;	>>>   SLOT NUMBER (= its position among the level's movable objects)   <<<
;
	iwt r0,#lo16(_RLMObjects)
	from !rNMObj
	to r1
	sub r0
	iwt r6,#1725	; *65536/38, exact below 4681 slots
	assert rloSize == 38
	from r1
	lmult
	move r3,r0	; r3 = slot
;
;	>>>   FIND ITS LEVEL OBJECT (GSU RAM $71)   <<<
;
	lms r4,(EMOBJECTS&$FFFF)
	%RAMB71(r1)
_RLNMR100:
	to r5	; Flags/Type
	ldw (r4)
	moves r5,r5	; End of the list?
	bne _RLNMR120
	nop
	%RAMB70(r1)
	iwt r15,#lo16(_RLNM9000)	; (not found: leave it dead)
	nop
_RLNMR120:
	ibt r0,#rlpfMultiPlayer
	and r5
	bne _RLNMR300	; Multiplayer only
	nop
	from r5
	%and_i(rlpfSkill45)	; (Nightmare)
	beq _RLNMR300	; Not at this skill
	nop
	ibt r0,#rlpfMovable
	and r5
	beq _RLNMR300	; Not movable
	nop
	dec r3	; This one?
	bmi _RLNMR500	; Yes
	nop
_RLNMR300:
	from r5	; Next level object
	hib
	ibt r1,#otAngular
	from r1
	cmp r0
	ibt r0,#rlpSize0
	bcc _RLNMR320	; (unsigned: type > otAngular)
	nop
	ibt r0,#rlpSize
_RLNMR320:
	with r4
	add r0
	bra _RLNMR100
	nop
_RLNMR500:
	ibt r0,#rlpX
	add r4
	to r7	; X
	ldw (r0)
	ibt r0,#rlpY
	add r4
	to r8	; Y
	ldw (r0)
	ibt r0,#rlpAngle	; (as the level start: the word after X/Y)
	add r4
	ldw (r0)
	sms (NMAngle&$FFFF),r0
	%RAMB70(r1)
	sms (NMX&$FFFF),r7
	sms (NMY&$FFFF),r8
;
;	>>>   NOT WHILE THE PLAYER STANDS ON THE SPOT   <<<
;
	lms r2,(MPPlayerObject&$FFFF)
	ibt r0,#(rloX+2)
	add r2
	ldw (r0)
	sub r7
	bpl _RLNMR600
	nop
	not
	inc r0
_RLNMR600:
	iwt r1,#48
	cmp r1
	bge _RLNMR700	; Far enough
	nop
	ibt r0,#(rloY+2)
	add r2
	ldw (r0)
	sub r8
	bpl _RLNMR620
	nop
	not
	inc r0
_RLNMR620:
	cmp r1
	bge _RLNMR700
	nop
	iwt r15,#lo16(_RLNM9000)	; Try again later
	nop
_RLNMR700:
;
;	>>>   TELEPORT SOUND WHERE IT APPEARS   <<<
;
	move r4,r7
	move r6,r8
	iwt r3,#lo16(sxTeleport-1)
	link #4
	iwt r15,#lo16(_RLSoundEffect)
	nop
;
;	>>>   MOVE THE OBJECT   <<<
;
	link #4	; Remove it from its sector's object list
	iwt r15,#lo16(_RLRemSectorObject)
	nop
	lms r7,(NMX&$FFFF)	; Sector at the start position
	lms r8,(NMY&$FFFF)
	link #4
	iwt r15,#lo16(_RLGetXYSectorData)	; -> r6 Sector, r9 SectorData
	nop
	from !rNMObj
	to r2
	%add_i(rloX)
	ibt r0,#0
	stw (r2)	; X fraction
	inc r2
	inc r2
	from r7
	stw (r2)	; X
	inc r2
	inc r2
	stw (r2)	; Y fraction
	inc r2
	inc r2
	from r8
	stw (r2)	; Y
	inc r2
	inc r2
	ibt r0,#rlsdFloorHeight	; Z = floor (+32 for a Cacodemon)
	add r9
	to r1
	ldw (r0)
	ibt r0,#rloType
	add !rNMObj
	ldb (r0)
	ibt r3,#otCacoDemon
	cmp r3
	bne _RLNMR800
	nop
	ibt r0,#32
	with r1
	add r0
_RLNMR800:
	from r1
	stw (r2)	; Z
	inc r2
	inc r2
	ibt r0,#0
	stw (r2)	; VX
	inc r2
	inc r2
	stw (r2)	; VY
	inc r2
	inc r2
	lms r0,(NMAngle&$FFFF)
	stw (r2)	; Angle
	inc r2
	inc r2
	from r6
	stb (r2)	; Sector
	link #4	; Into the new sector's object list
	iwt r15,#lo16(_RLAddSectorObject)
	nop
;
;	>>>   ALIVE AGAIN   <<<
;
	ibt r2,#rloFlags	; SOLID and TARGET, not an item
	with r2
	add !rNMObj
	to r1
	ldb (r2)
	ibt r3,#(rlpfSolid|rlpfTarget)
	with r1
	or r3
	ibt r3,#rlpfItem
	with r1
	bic r3
	from r1
	stb (r2)
	ibt r0,#bank(_MObjData)
	romb
	ibt r0,#rloMData
	add !rNMObj
	to r5
	ldw (r0)	; r5 = MObjData
	from r5
	to r14
	%add_i(rlmodHealth)
	getb
	inc r14
	getbh
	ibt r1,#rloHealth
	with r1
	add !rNMObj
	stw (r1)
	from r5
	to r14
	%add_i(rlmodSleepS)
	getb
	inc r14
	getbh
	ibt r1,#rloState
	with r1
	add !rNMObj
	stw (r1)
	from r5
	to r14
	%add_i(rlmodSleepA)
	getb
	inc r14
	getbh
	ibt r1,#rloAnim
	with r1
	add !rNMObj
	stw (r1)
	iwt r0,#(35<<8)	; AnimCount 0, StateCount 35
	ibt r1,#rloAnimCount
	with r1
	add !rNMObj
	stw (r1)
	ibt r0,#0	; No target, no timer
	ibt r1,#rloTObj
	with r1
	add !rNMObj
	stw (r1)
	inc r1
	inc r1
	stw (r1)
;
;	>>>   BACK INTO THE PROCESSING LIST   <<<
;
	iwt r1,#lo16(_RLMObjs-2)
_RLNMR900:
	inc r1
	inc r1
	ldw (r1)
	inc r0	; Free entry (-1)?
	bne _RLNMR900
	nop
	from !rNMObj
	to r0
	sub #1
	stw (r1)
	lms r0,(RLNumPMObjs&$FFFF)
	inc r0
	sbk
	lms r0,(NMCount&$FFFF)
	inc r0
	sbk
	iwt r15,#lo16(_RLNM9000)
	nop
