	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       PLAYER HANDLING MODULE 2                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlplayer.inc"
	incsrc "src/include/rlweapons.inc"
	incsrc "src/include/music.inc"


	; public _RLPlayer


	%section(ENGINE_GSUCODE)
	arch superfx

;
;	* * * * * * *       REALITY_ENGINE PLAYER HANDLING       * * * * * * *
;
_RLPlayer:
;
;	* * * * * * *       ACTIONS AFFECTING MOVEMENT/USE/OPERATION       * * * * * * *
;
_RLP1000:
	lms r9,(PlayerJoy+RLGSUSNESXVarsO&$FFFF)	; Get Joystick Bits

;
;	>>>   PLAYER DEAD?   <<<
;
	lms r1,(PlayerDead&$FFFF)	; Is Player Dead?
	dec r1
	bmi _RLP2000	; NO!
	nop
;
;	>>>   PLAYER IS DEAD -- WAIT FOR RESTART   <<<
;
_RLP1500:
	lms r0,(PlayerJoy+RLGSUSNESXVarsO&$FFFF)	; Get Joystick Bits
	lms r1,(PlayerJoyOld&$FFFF)
	with r1
	sub r0
	beq _RLP1600
	nop
	if useID == 0
	iwt r1,#(pjWEAPON|pjUSE)
	endif
	if useID != 0
	iwt r1,#(pjWEAPON|pjUSE|pjFIRE|pjRUN)
	endif
;	with	r0
	and r1
	if useID == 0
;	with	r0				; BOTH PRESSED?
	sub r1
	bne _RLP1600-1	; No
	endif
	if useID != 0
	beq _RLP1600-1	; ANYTHING PRESSED?
	endif
	ibt r0,#-2	; YES, -2 = DIED: RESTART LEVEL!
	sms (ExitLevel&$FFFF),r0
_RLP1600:
	if useWILLIAMS != 0
;	with	r0				; Don't Die in AutoMap Mode!
	sub r0
	sms (AutoMapMode&$FFFF),r0
	endif
	iwt r15,#lo16(_RLP20000)	; Don't allow anything
	nop

;
;	>>>   PLAYER FALLING?   <<<
;
_RLP2000:
	if useMULTIPLAYER == 0
	lm r0,(PlayerObject+rloZ&$FFFF)	; Get Object's Z
	lm r1,(PlayerObject+rloZ2&$FFFF)	; Get Object's Z2
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloZ2	; Get Object's Z2
	lms r2,(MPPlayerObject&$FFFF)
;	with	r0
	add r2
	to r1
	ldw (r0)
	ibt r0,#rloZ	; Get Object's Z
;	with	r0
	add r2
;	to	r0
	ldw (r0)
	endif
	with r1	; FloorHeight >= ObjectZ?
	sub r0	; @CMP@
	bge _RLP2100	; Yes
	nop
;
;	>>>   PLAYER IS FALLING   <<<
;
	iwt r15,#lo16(_RLP5000)	; Yes!  Don't allow movement
	nop
;
;	>>>   STRAFE LEFT/RIGHT   <<<
;
_RLP2100:
	move r0,r9	; <LEFT>?
	ibt r1,#pjSTRAFELEFT
	and r1
	beq _RLP2200	; No
	nop
	iwt r2,#$4000
	bra _RLP2500
	nop
_RLP2200:
	move r0,r9	; <RIGHT>?
	ibt r1,#pjSTRAFERIGHT
	and r1
	beq _RLP3000	; No
	nop
	iwt r2,#$C000
_RLP2500:
	if useFX3CONTROLS == 0
	lms r6,(PlayerMouseX+RLGSUSNESXVarsO&$FFFF)
	endif
	if useFX3CONTROLS != 0
	iwt r6,#$05A0	; Strafe velocity (FX3: $3C0 *1.5 for this FPSRatio)
	move r0,r9	; RUNNING?
	iwt r1,#pjRUN
	and r1
	beq _RLP2510	; No
	nop
	iwt r6,#$0B40	; Yes, *2 (FX3: $780)
_RLP2510:
	endif
	lms r0,(FPSRatio&$FFFF)	; Get FPSRatio
;	with	r0
	lmult
;	with	r0				; Get Whole Pixels Only
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0
	to r6
	or r4
;
	if useMULTIPLAYER == 0
	lm r0,(PlayerObject+rloAngle&$FFFF)	; Get PlayerAngle
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloAngle	; Get PlayerAngle
	lms r1,(MPPlayerObject&$FFFF)
;	with	r0
	add r1
;	to	r0
	ldw (r0)
	endif
;
;	with	r0				; Add Angle Offset
	add r2
	lsr
	lsr
	lsr
	lsr
	lsr	; >>5
	lsr	; Remove lowest bit
	to r2
	add r0
	ibt r0,#bank(SinTable)	; Bank of SinTable
	romb
	iwt r0,#lo16(SinTable)	; Add Base of SinTable
;	from	r0
	to r14
	add r2
	getb	; Get Sin from Table
	inc r14
	getbh
	fmult
;
	if useMULTIPLAYER == 0
	lm r1,(PlayerObject+rloVY&$FFFF)
	endif
	if useMULTIPLAYER != 0
	ibt r1,#rloVY
	lms r4,(MPPlayerObject&$FFFF)
	with r1
	add r4
	to r1
	ldw (r1)
	endif
;
;	with	r0
	add r1
;	from	r0
	sbk
;
	iwt r0,#lo16(CosTable)	; Add Base of CosTable
;	from	r0
	to r14
	add r2
	getb	; Get Cos from Table
	inc r14
	getbh
	fmult
;
	if useMULTIPLAYER == 0
	lm r1,(PlayerObject+rloVX&$FFFF)
	endif
	if useMULTIPLAYER != 0
	ibt r1,#rloVX
	lms r4,(MPPlayerObject&$FFFF)
	with r1
	add r4
	to r1
	ldw (r1)
	endif
;
;	with	r0
	add r1
	if useFX3CONTROLS == 0
	bra _RLP4000	; Don't Rotate while STRAFING!
	endif
;	from	r0
	sbk
;
;	>>>   ROTATE LEFT/RIGHT   <<<
;
_RLP3000:
	lms r6,(PlayerMouseX+RLGSUSNESXVarsO&$FFFF)
	moves r6,r6
	beq _RLP4000
	nop
;
	lms r0,(FPSRatio&$FFFF)	; Get FPSRatio
;	with	r0
	lmult
;	with	r0				; Get Whole Pixels Only
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0
	to r6
	or r4
;
	if useMULTIPLAYER == 0
	lm r0,(PlayerObject+rloAngle&$FFFF)
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloAngle
	lms r1,(MPPlayerObject&$FFFF)
;	with	r0
	add r1
;	to	r0
	ldw (r0)
	endif
;
;	with	r0
	add r6
;	with	r0
	bic #1
;	from	r0
	sbk
;
_RLP4000:
;
;	>>>   MOUSE TURN (exact, also while strafing)   <<<
;
	lms r0,(MouseTurn&$FFFF)	; Mouse turn since the last frame
	ibt r1,#0
	sms (MouseTurn&$FFFF),r1	; (used)
	if useMULTIPLAYER == 0
	iwt r1,#lo16(PlayerObject+rloAngle)
	endif
	if useMULTIPLAYER != 0
	ibt r1,#rloAngle
	lms r2,(MPPlayerObject&$FFFF)
	with r1
	add r2
	endif
	to r2
	ldw (r1)
	with r2
	add r0
	with r2
	bic #1
	from r2
	stw (r1)
;
;	>>>   MOVE FORWARDS/BACKWARDS   <<<
;
	lms r6,(PlayerMouseY+RLGSUSNESXVarsO&$FFFF)
	moves r6,r6
	beq _RLP5000
	nop
;
	lms r0,(FPSRatio&$FFFF)	; Get FPSRatio
;	with	r0
	lmult
;	with	r0				; Get Whole Pixels Only
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0
	to r6
	or r4
;
	if useMULTIPLAYER == 0
	lm r0,(PlayerObject+rloAngle&$FFFF)	; Get PlayerAngle
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloAngle
	lms r1,(MPPlayerObject&$FFFF)
;	with	r0
	add r1
;	to	r0
	ldw (r0)
	endif
;
	lsr
	lsr
	lsr
	lsr
	lsr	; >>5
	lsr	; Remove lowest bit
	to r2
	add r0
	ibt r0,#bank(SinTable)	; Bank of SinTable
	romb
	iwt r0,#lo16(SinTable)	; Add Base of SinTable
;	from	r0
	to r14
	add r2
	getb	; Get Sin from Table
	inc r14
	getbh
	fmult
;
	if useMULTIPLAYER == 0
	lm r1,(PlayerObject+rloVY&$FFFF)
	endif
	if useMULTIPLAYER != 0
	ibt r1,#rloVY
	lms r4,(MPPlayerObject&$FFFF)
	with r1
	add r4
	to r1
	ldw (r1)
	endif
;
;	with	r0
	add r1
;	from	r0
	sbk
;
	iwt r0,#lo16(CosTable)	; Add Base of CosTable
;	from	r0
	to r14
	add r2
	getb	; Get Cos from Table
	inc r14
	getbh
	fmult
;
	if useMULTIPLAYER == 0
	lm r1,(PlayerObject+rloVX&$FFFF)
	endif
	if useMULTIPLAYER != 0
	ibt r1,#rloVX
	lms r4,(MPPlayerObject&$FFFF)
	with r1
	add r4
	to r1
	ldw (r1)
	endif
;
;	with	r0
	add r1
;	from	r0
	sbk
;
;	>>>   USE/OPERATE   <<<
;
_RLP5000:
	move r0,r9	; Use/Operate?
	iwt r1,#pjUSE
	and r1
	beq _RLP10000
	nop
	lms r0,(PlayerJoyOld&$FFFF)
	and r1
	bne _RLP10000
	nop
	iwt r1,#lo16(MVULMask)	; LineFlags Type Mask
	ibt r0,#(rllfUsable>>8)
;	from	r0
	stb (r1)
	if useMULTIPLAYER == 0
	iwt r12,#lo16(PlayerObject)	; Pointer to Player's RLObject
	endif
	if useMULTIPLAYER != 0
	lms r12,(MPPlayerObject&$FFFF)	; Pointer to Player's RLObject
	endif
	link #4
	iwt r15,#lo16(_RLUseXY)	; USE/OPERATE SPECIAL LINES
	nop

;
;	* * * * * * *       ACTIONS NOT AFFECTING MOVEMENT       * * * * * * *
;
;	>>>   <SELECT> TO TOGGLE AUTOMAP   <<<
;
_RLP10000:
	lms r9,(PlayerJoy+RLGSUSNESXVarsO&$FFFF)	; Get Joystick Bits
	if useAUTOMAP != 0
	move r0,r9
	iwt r1,#pjAUTOMAP
;	with	r0
	sub r1
	bne _RLP13000
	nop
	lms r0,(PlayerJoyOld&$FFFF)
	and r1
	bne _RLP13000
	nop
	lms r0,(AutoMapMode&$FFFF)	; Toggle AutoMap Mode
	xor #1
	sbk
	endif

;
;	>>>   <FIRE> TO EXPAND AUTOMAP SCALE   <<<
;
_RLP13000:
	lms r0,(AutoMapMode&$FFFF)	; In AutoMap Mode?
	moves r0,r0
	beq _RLP17000	; No, can't Scale View!
	nop
	move r0,r9
	iwt r1,#pjFIRE
	and r1
	beq _RLP14000
	nop
	lms r2,(AutoMapScale&$FFFF)	; Get Current AutoMap Scale
	move r1,r2	; Get Enlargement Adjustment Value
	with r1
	hib
	ibt r0,#$10
;	with	r0
	umult r1
	with r2	; Adjust AutoMap Scale
	add r0
	bpl _RLP13200	; Ensure not too Large!
	nop
	iwt r2,#$7FFF
_RLP13200:
	sms (AutoMapScale&$FFFF),r2	; Save new AutoMap Scale
;
;	>>>   <WEAPON CYCLE> TO REDUCE AUTOMAP SCALE   <<<
;
_RLP14000:
	move r0,r9
	ibt r1,#pjWEAPON
	and r1
	beq _RLP15000
	nop
	lms r2,(AutoMapScale&$FFFF)	; Get Current AutoMap Scale
	move r1,r2	; Get Reduction Adjustment Value
	with r1
	hib
	ibt r0,#$10
;	with	r0
	umult r1
	with r2	; Adjust AutoMap Scale
	sub r0
;	move	r1,#$0600			; Ensure not too Small!
	iwt r1,#$0300	; Ensure not too Small!
	from r2
;	to	r0
	sub r1
	bge _RLP14200
	nop
	move r2,r1
_RLP14200:
	sms (AutoMapScale&$FFFF),r2	; Save new AutoMap Scale

	if !DEBUGSCR != 0
;
;	>>>   <RUN> TO TOGGLE DEBUGGING SCREEN   <<<
;
_RLP15000:
	move r0,r9
	iwt r1,#pjRUN
	and r1
	beq _RLP20000
	nop
	lms r0,(PlayerJoyOld&$FFFF)
	and r1
	bne _RLP20000
	nop
	lm r0,(DebugScreen&$FFFF)	; Toggle Debugging Screen
;	with	r0
	xor #1
	sbk
	endif
	if !DEBUGSCR == 0
_RLP15000:
	endif
	bra _RLP20000
	nop

;
;	>>>   <WEAPON CYCLE> TO SELECT NEXT WEAPON   <<<
;
_RLP17000:
	move r0,r9
	ibt r1,#pjWEAPON
	and r1
	if useID7 == 0
	beq _RLP20000
	endif
	if useID7 != 0
	beq _RLP18000
	endif
	nop
	lms r0,(PlayerJoyOld&$FFFF)
	and r1
	if useID7 == 0
	bne _RLP20000
	endif
	if useID7 != 0
	bne _RLP18000
	endif
	nop
	if useID7 == 0
	lms r0,(WeaponState&$FFFF)	; Currently Lowering Weapon?
;	with	r0
	%sub_i(wdLower)
	beq _RLP20000	; YES!  Don't Switch!
	nop
	endif
	if !RLDOOM2MONSTERS != 0
	lms r2,(WeaponNext&$FFFF)	; (DOOM II) Shotgun -> Super Shotgun, if the player has it
	ibt r0,#wtShotGun
	sub r2
	bne _RLP17050
	nop
	iwt r1,#lo16(PlayerKeys)
	ldb (r1)
	sex	; (pkSuperShotGun = $80)
	bpl _RLP17050
	nop
	ibt r2,#wtSuperShotGun
	sms (WeaponNext&$FFFF),r2
	iwt r15,#lo16(_RLP17450)
	nop
_RLP17050:
	endif
	iwt r1,#lo16(PlayerArms)	; Get Available Weapons
	to r1
	ldb (r1)
	ibt r0,#bank(_WeaponTypeBitsTable)
	romb
	iwt r0,#lo16(_WeaponTypeBitsTable)
	lms r2,(WeaponNext&$FFFF)	; Current Next Weapon
	if !RLDOOM2MONSTERS != 0
	ibt r4,#wtSuperShotGun	; (Super Shotgun: on from the Shotgun)
	from r2
	sub r4
	bne _RLP17100
	nop
	ibt r2,#wtShotGun
_RLP17100:
	iwt r0,#lo16(_WeaponTypeBitsTable)
	endif
;	from	r0
	to r14
	add r2
	getb	; Get Weapon Type Bit
_RLP17200:
	inc r2	; Next Weapon
	inc r2
	with r2	; Limit to Maximum Weapon Types
	and #15
	beq _RLP17400	; Player ALWAYS Has Fist!
;	with	r0
	rol
;	from	r0				; Does Player have this Weapon?
	to r4
	and r1
	beq _RLP17200	; No!  Next Weapon!
_RLP17400:
	from r2	; YES!  NEW NEXT WEAPON!
	sbk
	if !RLDOOM2MONSTERS != 0
_RLP17450:
	endif

;
;	>>>   SWITCH TO SELECTED WEAPON   <<<
;
	if useID7 != 0
_RLP18000:
	lms r0,(WeaponType&$FFFF)	; Current Weapon = Next Weapon?
	lms r1,(WeaponNext&$FFFF)
;	with	r0
	sub r1
	beq _RLP20000	; Yes!  Don't Switch Weapons!
	nop
	lms r0,(WeaponState&$FFFF)	; Currently Lowering Weapon?
;	with	r0
	%sub_i(wdLower)
	beq _RLP20000	; YES!  Don't Switch!
	nop
	link #4
	iwt r15,#lo16(_RLDropWeapon)	; DROP CURRENT WEAPON!
	nop
	endif

;
;	* * * * * * *       COMPLETED JOYSTICK/MOUSE PROCESSING       * * * * * * *
;
_RLP20000:
	lms r0,(PlayerJoy+RLGSUSNESXVarsO&$FFFF)	; JoyOld = Joy
	sms (PlayerJoyOld&$FFFF),r0
;
;	>>>   HANDLE PLAYER'S HEIGHT MOVEMENT   <<<
;
_RLP21000:
	ibt r6,#6	; PlayerHeightMovement
	lms r0,(FPSRatio&$FFFF)	; Get FramesPerSecond Ratio
;	with	r0
	lmult
;	with	r0				; Get Whole Pixels Only
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0				; R6 = |PlayerHeightMovement|
	to r6
	or r4
;
	lms r1,(PlayerDead&$FFFF)	; Player Dead?
	lms r0,(PlayerHeight&$FFFF)	; Player's Height
	moves r1,r1
	beq _RLP21500	; Live
	nop
;
;	>>>   PLAYER IS DEAD   <<<
;
;	with	r0				; Move Down
	sub r6
	ibt r1,#6	; Player's Minimum Eye Height
;	from	r0
	cmp r1
	bge _RLP21800
	nop
	bra _RLP21800
	from r1	; Already at Bottom
;
;	>>>   PLAYER IS LIVE   <<<
;
_RLP21500:
	ibt r1,#odhPlayerEye	; Player's Maximum Eye Height
;	with	r0				; Move Up
	add r6
;	from	r0
	cmp r1
	blt _RLP21800	; Already at Top
	nop
	from r1
_RLP21800:
	sbk

;
;	>>>   HANDLE PLAYER DEATH/BIRTH   <<<
;
_RLP25000:
	lms r0,(PlayerDead&$FFFF)	; Is Player DEAD or ALIVE?
	lms r1,(PlayerDeadOld&$FFFF)	; Was Player DEAD or ALIVE?
;	from	r0
	cmp r1
	beq _RLP30000	; Same as Last Time!
	nop
	link #4
	iwt r15,#lo16(_RLDropWeapon)	; Player is DEAD
	sbk
	ibt r3,#pldeth_eff	; Make Player Death Sound Effect
	link #4
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop

;
;	* * * * * * *       HANDLE PLAYER'S MOVEMENT       * * * * * * *
;
_RLP30000:
;
;	>>>   DETERMINE MAXIMUM VELOCITY   <<<
;
	lms r0,(PlayerJoy+RLGSUSNESXVarsO&$FFFF)	; Get Joystick Bits
	iwt r1,#pjRUN	; RUNNING?
;	with	r0
	and r1
	ibt r1,#56
	beq _RLP30200	; No
	nop
	ibt r1,#84
_RLP30200:
;
;	>>>   LIMIT X VELOCITY   <<<
;
	if useMULTIPLAYER == 0
	iwt r3,#lo16(PlayerObject+rloVX+1)	; Get Velocity X Integer
	endif
	if useMULTIPLAYER != 0
	ibt r0,#(rloVX+1)	; Get Velocity X Integer
	lms r3,(MPPlayerObject&$FFFF)
	with r3
	add r0
	endif
;
;	to	r0
	ldb (r3)
;	from	r0
	cmp r1
	blt _RLP32000
;	with	r0
	sex
	bpl _RLP31200
	from r1
	to r2
	not
	inc r2
;	with	r0
	sub r2
	bge _RLP32000
	from r2
_RLP31200:
	stb (r3)
;
;	>>>   LIMIT Y VELOCITY   <<<
;
_RLP32000:
	inc r3	; Get Velocity Y Integer
	inc r3
;	to	r0
	ldb (r3)
;	from	r0
	cmp r1
	blt _RLP33000
;	with	r0
	sex
	bpl _RLP32200
	from r1
	to r2
	not
	inc r2
;	with	r0
	sub r2
	bge _RLP33000
	from r2
_RLP32200:
	stb (r3)
;
;	>>>   MOVE PLAYER   <<<
;
_RLP33000:
	iwt r1,#lo16(MVULMask)	; LineFlags Type Mask
	iwt r0,#((rllfTrigger|rllfItem)>>8)
;	from	r0
	stb (r1)
	iwt r1,#lo16(MVIMask)	; ObjectFlags Collision Mask
	ibt r0,#(rlpfSolid|rlpfItem)
;	from	r0
	stb (r1)
	if useMULTIPLAYER == 0
	iwt r12,#lo16(PlayerObject)	; Pointer to Player's RLObject
	endif
	if useMULTIPLAYER != 0
	lms r12,(MPPlayerObject&$FFFF)	; Pointer to Player's RLObject
	endif
	iwt r0,#lo16(_RLMoveXY4)	; MOVE RLOBJECT XY 4 (PLAYER)
	link #4
	iwt r15,#lo16(_RLMoveObject)	; Move Player RLObject
	nop
;
;	>>>   PLAYER FALLING?   <<<
;
	if useMULTIPLAYER == 0
	lm r1,(PlayerObject+rloZ2&$FFFF)	; Get Object's Z2
	iwt r2,#lo16(PlayerObject+rloZ)	; Get Object's Z
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloZ2	; Get Object's Z2
	lms r2,(MPPlayerObject&$FFFF)
;	with	r0
	add r2
	to r1
	ldw (r0)
	ibt r0,#rloZ	; Get Object's Z
	with r2
	add r0
	endif
;
;	to	r0
	ldw (r2)
	inc r2	; Move to VelocityX
	inc r2
	with r1	; ObjectZ > FloorHeight?
	sub r0	; @CMP@
	blt _RLP34000-2	; Yes, No Friction!
;
;	>>>   HANDLE FRICTION   <<<
;
	iwt r6,#$6000	; FRICTION COEFFICIENT (Velocity = 75%)
	to r1	; Get VelocityX
	ldw (r2)
	inc r2
	inc r2
;	to	r0				; Get VelocityY
	ldw (r2)
;	with	r0				; VelocityY *= 0.75
	fmult
;	with	r0
	rol
	sbk
	from r1	; VelocityX *= 0.75
;	to	r0
	fmult
;	with	r0
	rol
	dec r2
	dec r2
;	from	r0
	stw (r2)
;
;	>>>   HANDLE FRICTION WHEN CLOSE TO STOPPING (<1.0 PIXELS)   <<<
;
;	(this port) Only without a move command, as PC DOOM: the speed added
;	per frame is FPSRatio-scaled, the friction (x0.75) is not, so at 4
;	VBlanks per frame a walking player would fall below the threshold and
;	be stopped every frame (the original never ran at under 5 VBlanks a frame).
	lms r0,(PlayerMouseY+RLGSUSNESXVarsO&$FFFF)	; Moving forwards/backwards?
	moves r0,r0
	bne _RLP34000	; Yes, no stop
	nop
	lms r0,(PlayerJoy+RLGSUSNESXVarsO&$FFFF)	; Strafing?
	ibt r1,#(pjSTRAFELEFT|pjSTRAFERIGHT)
	and r1
	bne _RLP34000	; Yes, no stop
	nop
;
;	to	r0
	ldw (r2)	; Get |Velocity X|
	inc r2	; Move to Velocity Y
;	with	r0
	hib
;	with	r0
	sex
	ibt r1,#(2+1)
;	from	r0
	cmp r1
	bge _RLP34000
	inc r2	; Move to Velocity Y
	ibt r1,#-2
;	with	r0
	sub r1
	blt _RLP34000
	nop
;
;	to	r0				; Get |Velocity Y|
	ldw (r2)
;	with	r0
	hib
;	with	r0
	sex
	ibt r1,#(2+1)
;	from	r0
	cmp r1
	bge _RLP34000-1
	ibt r1,#-2
;	with	r0
	sub r1
	blt _RLP34000
;
;	with	r0				; YES!  STOP MOVEMENT!
	sub r0
	sbk
	dec r2
	dec r2
;	from	r0
	stw (r2)
;
;	>>>   PLAYER STANDING ON GROUND?   <<<
;
_RLP34000:
	if useMULTIPLAYER == 0
	iwt r0,#lo16(PlayerObject+rloSector)	; Get Player's Sector
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloSector	; Get Player's Sector
	lms r1,(MPPlayerObject&$FFFF)
;	with	r0
	add r1
	endif
;
;	to	r0
	ldb (r0)
;	with	r0
	%umult_i(rlsdSize)
	iwt r1,#lo16(_RLSectorData+rlsdFloorHeight)
;	with	r0
	add r1
	to r1	; Get FloorHeight
	ldw (r0)
;
	if useMULTIPLAYER == 0
	iwt r0,#lo16(PlayerObject+rloZ)	; Get Object's Z
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloZ	; Get Object's Z
	lms r2,(MPPlayerObject&$FFFF)
;	with	r0
	add r2
	endif
;
;	to	r0
	ldw (r0)
	with r1	; ObjectZ > FloorHeight?
	sub r0	; @CMP@
;	with	r0
	blt _RLP34500	;  0 = NOT ON GROUND!
	sub r0
	dec r0	; -1 = ON GROUND
_RLP34500:
	sms (PlayerOnGround&$FFFF),r0

;
;	>>>   HANDLE PLAYER'S SWAY   <<<
;
_RLP35000:
	if useMULTIPLAYER == 0
	iwt r2,#lo16(PlayerObject+rloVX)	; Player's X Velocity
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloVX	; Player's X Velocity
	lms r2,(MPPlayerObject&$FFFF)
	with r2
	add r0
	endif
;
;	to	r0				; Player's X Velocity
	ldw (r2)
;	with	r0
	hib
;	with	r0
	sex
	bpl _RLP35200
	nop
;	with	r0
	not
_RLP35200:
;	from	r0
	to r1
	mult r0
;
	inc r2	; Player's Y Velocity
	inc r2
;	to	r0
	ldw (r2)
;	with	r0
	hib
;	with	r0
	sex
	bpl _RLP35400
	nop
;	with	r0
	not
_RLP35400:
;	with	r0
	mult r0

;	with	r0				; Get Player's Sway
	add r1
;	with	r0				; Sway >> 4
	lsr
;	with	r0
	lsr
;	with	r0
	lsr
;	with	r0
	bic #1
	ibt r1,#(17<<1)	; Sway > MaxSway?
;	from	r0
	cmp r1
	blt _RLP35600
	move r0,r1
_RLP35600:
	sms (PlayerSway&$FFFF),r0

;
;	* * * * * * *       HANDLE POWERUPS       * * * * * * *
;
_RLP40000:
	lms r2,(FPSCount+RLGSUSNESXVarsO&$FFFF)	; #VBlanks
	lms r3,(RLRGB&$FFFF)	; Current RGB Animation
;
;	>>>   LIGHTING GOGGLES   <<<
;
_RLP41000:
	lms r0,(LightGoggles&$FFFF)	; Lighting Goggles Counter
;	with	r0
	sub r2
	bpl _RLP41200	; Timer Not Expired
	nop
;	with	r0
	sub r0
_RLP41200:
;	from	r0				; Save Updated Counter
	sbk
;
;	>>>   INVISIBILITY   <<<
;
_RLP42000:
	lms r0,(InvisibleCount&$FFFF)	; Invisibility Counter
;	with	r0
	sub r2
	bpl _RLP42200	; Timer Not Expired
	nop
;	with	r0
	sub r0
_RLP42200:
;	from	r0				; Save Updated Counter
	sbk
;
;	>>>   RADIATION SUIT   <<<
;
_RLP43000:
	lms r0,(RadCount&$FFFF)	; Radiation Counter
	dec r0
	bmi _RLP44000	; No Radiation Suit
;	with	r0
	sub r2
	bpl _RLP43200	; Timer Not Expired
	nop
;	with	r0				; Timer Expired!
	sub r0
_RLP43200:
;	from	r0				; Save Updated Counter
	bne _RLP44000
	sbk
	ibt r3,#rgbNormal	; Use Normal RGBAnim
;
;	>>>   BERSERK STRENGTH   <<<
;
_RLP44000:
	lms r0,(BerserkCount&$FFFF)	; Berserk Counter
	dec r0
	bmi _RLP45000	; No Berserk Strength
	inc r0
;	with	r0
	sub r2
	dec r0
	bpl _RLP44200	; Timer Not Expired
	inc r0
;	with	r0				; Timer Expired!
	sub r0
_RLP44200:
;	from	r0				; Save Updated Counter
	bne _RLP45000
	sbk
	ibt r3,#rgbNormal	; Use Normal RGBAnim
;
;	>>>   HANDLE RGB ANIMATION   <<<
;
_RLP45000:
	lms r0,(BerserkCount&$FFFF)	; Any Berserk?
	lms r1,(RadCount&$FFFF)	; Any Radiation Suit?
;	with	r0
	add r1
	bne _RLP46000+1	; Yes, Don't Change RGB!
	lms r0,(RLRGB&$FFFF)	; Current RGB Animation
;	with	r0				; rgbRad?
	asr
	dec r0
	beq _RLP46000
	dec r0	; rgbBerserk?
	beq _RLP46000
	from r3	; Update RGB Animation
	sbk
;
;	>>>   INVULNERABILITY   <<<
;
_RLP46000:
	lms r0,(InvulnerableCount&$FFFF)	; Invulnerability Counter
	dec r0
	bmi _RLP50000	; No Invulnerability
	inc r0
;	with	r0
	sub r2
	dec r0
	bpl _RLP46200	; Timer Not Expired
	inc r0
;	with	r0				; Timer Expired!
	sub r0
_RLP46200:
;	from	r0				; Save Updated Counter
	bne _RLP50000
	sbk
	link #4
	iwt r15,#lo16(_RLCalcFaceAnim)	; ReCalculate Face Animation
	nop

_RLP50000:


	if !DEBUGSCR != 0
;
;	* * * * * * *       DEBUG SCREEN PLAYER PROCESSING       * * * * * * *
;
	lm r0,(DebugScreen&$FFFF)	; Debug Screen On?
	dec r0
	bmi ._0
	nop
;
	lm r0,(PlayerObject+rloX+0&$FFFF)	; Get Player X
	sm (DebugPlayerX&$FFFF),r0
	lm r0,(PlayerObject+rloX+2&$FFFF)
	sm (DebugPlayerX+2&$FFFF),r0
	lm r0,(PlayerObject+rloY+0&$FFFF)	; Get Player Y
	sm (DebugPlayerY&$FFFF),r0
	lm r0,(PlayerObject+rloY+2&$FFFF)
	sm (DebugPlayerY+2&$FFFF),r0
	lm r0,(PlayerObject+rloAngle&$FFFF)	; Get Player Angle
	sm (DebugPlayerA&$FFFF),r0
	lm r0,(PlayerObject+rloZ+0&$FFFF)	; Get Player Z
	sm (DebugPlayerZ&$FFFF),r0
;
	lm r0,(PlayerObject+rloSector&$FFFF)	; Get Player Sector
	sm (DebugPlayerS&$FFFF),r0
._0:
	endif

;
;	* * * * * * *       PLAYER PROCESSING COMPLETE       * * * * * * *
;
	if usePATCH == 0
	iwt r0,#lo16(_RLWeapons)	; HANDLE WEAPONS
	endif
	if usePATCH != 0
	lms r0,(PTRLWeapons&$FFFF)	; HANDLE WEAPONS
	endif
	ibt r8,#bank(_RLWeapons)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop


	if useHIGHDETAIL != 0
;
;	* * * * * * *       LOW/HIGH DETAIL MESSAGES       * * * * * * *
;
LowDetailAMsg:	db "LOW DETAI",0
LowDetailBMsg:	db 'L',0
LowDetailCMsg:	db 0

HighDetailAMsg:	db "HIGH DETA",0
HighDetailBMsg:	db "IL",0
HighDetailCMsg:	db 0
	endif


;
;	* * * * * * *       DAMAGE PLAYER       * * * * * * *
;
;	R4 = #HitPoints Damage
;
_RLDamagePlayer:
;
;	>>>   RUMBLE: 3 STRENGTHS BY THE DAMAGE (this port, as FX3)   <<<
;
	sms (ULReturnAddress&$FFFF),r11
	ibt r1,#reDamage1
	ibt r0,#10	; <= 10?
	cmp r4
	bge _RLDP100
	nop
	inc r1
	ibt r0,#20	; <= 20?
	cmp r4
	bge _RLDP100
	nop
	inc r1
_RLDP100:
	move r0,r1
	link #4
	iwt r15,#lo16(_RLAddRumble)
	nop
	lms r11,(ULReturnAddress&$FFFF)
;
	lms r0,(InvulnerableCount&$FFFF)	; Does Player have Invulnerability?
	dec r0
	bpl _RLDP800	; Yes, No Damage!
	nop
	lms r0,(PlayerDead&$FFFF)	; Is Player Dead?
	dec r0
	beq _RLDP800	; Yes!
	nop
;
;	>>>   ADJUST HITPOINTS BASED ON SKILL LEVEL   <<<
;
_RLDP200:
	lms r0,(SkillLevel&$FFFF)	; Easy Difficulty Setting?
	sms (ULReturnAddress&$FFFF),r11
	dec r0
	bpl _RLDP300+1
	from r4
	to r4	; Yes, Divide Damage by 2
	lsr
_RLDP300:
	from r4	; Armor takes 1/2 Points
;	to	r0
	lsr
	lms r1,(PlayerArmor&$FFFF)	; Any Armor?
	with r1
	sub r0
	bpl _RLDP400+1	; Armor took all it's points
	from r1	; Get #Points Armor couldn't take
;	to	r0
	add r0
	ibt r1,#0
_RLDP400:
	from r1	; Update Armor
	sbk
	with r4	; Get #Health Points to take
	sub r0
	lms r0,(RLRGB&$FFFF)	; Get RGB Animation
	inc r0	; rgbNone?
	bne _RLDP500-1	; No, Can't Change RGB!
	ibt r0,#rgbHit	; Player Hit RGB Animation
	sbk
_RLDP500:
	link #4
	iwt r15,#lo16(_RLSubHealth)
	nop
;
;	>>>   MAKE SOUND EFFECT   <<<
;
	ibt r1,#lo16(PlayerHurt)	; Player Hurt Yet?
	assert (lo16(PlayerHurt))&$FFFF < $80 || (lo16(PlayerHurt))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;	to	r0
	ldb (r1)
	dec r0
	bmi _RLDP700+1	; Yes, don't make multiple sounds!
;	from	r0				; Player now Hurt!
	stb (r1)
	ibt r3,#plpain_eff	; Make Player Hurt Sound Effect
	link #4
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop
_RLDP700:
	lms r11,(ULReturnAddress&$FFFF)
_RLDP800:
	jmp r11	; Return to Caller
	nop


;
;	* * * * * * *       ADD A RUMBLE REQUEST (this port, rumble.asm)       * * * * * * *
;
;	r0 = request (rumble.inc: effect# | recAddLoop / recRemLoop), r11 = return;
;	uses r0, r1.  At most MaxRLRumbles a frame.
;
_RLWeaponRumble:	; the fire effect of the current weapon
	lms r0,(WeaponType&$FFFF)
;	with	r0
	lsr
;	with	r0
	%add_i(reFireFist)
_RLAddRumble:
	sm (RLRumbleTemp&$FFFF),r0
	lm r0,(RLNumRumbles&$FFFF)	; Requests this frame
	ibt r1,#MaxRLRumbles
;	from	r0				; Full?
	cmp r1
	bge _RLAR900
	inc r0	; (delay slot)
	sbk	; (the last RAM address: RLNumRumbles)
	iwt r1,#lo16(RLGSURumbles-1)
;	with	r0
	add r1
	move r1,r0
	lm r0,(RLRumbleTemp&$FFFF)
;	from	r0
	stb (r1)
_RLAR900:
	jmp r11	; Return to Caller
	nop
