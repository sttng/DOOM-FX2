	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       PLAYER HANDLING MODULE 1                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlplayer.inc"
	incsrc "src/include/rlweapons.inc"


	; public _RLInitPlayer


	%section(LEVEL)
;
;	* * * * * * *       REALITY_ENGINE INITIALIZE PLAYER       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitPlayer:
	rep #$30		; mode 'AX!'
;
;	>>>   INITIALIZE MULTIPLAYER VARIABLES   <<<
;
	if useMULTIPLAYER != 0
	lda.w #lo16(PlayerObject)	; Player Object
	sta.l MPPlayerObject
	sta.l MPEnemyTarget	; Enemy Target Object
	endif
;
;	>>>   INITIALIZE JOYSTICK/MOUSE CONTROLLERS   <<<
;
	lda.w #0
	sta.w PlayerJoy
	sta.l PlayerJoyOld
	sta.w PlayerJoy0
	sta.w PlayerMouseX
	sta.w PlayerMouseY
;
;	>>>   INITIALIZE PLAYER'S FACEANIM   <<<
;
	lda.w #-1	; Force ReBuild of PlayerFace
	sta.w PlayerFaceOld
	lda.w #(18*2)	; NORMAL Face
	sta.l PlayerFace
	lda.w #1	; CountDown to next FaceAnim
	sta.l PlayerFaceCount
	lda.w #lo16(_FacesNormalList)	; Address of FaceAnimation
	sta.l PlayerFaceAnim0
	sta.l PlayerFaceAnim
;
;	>>>   INITIALIZE PLAYER INFORMATION/STATS   <<<
;
	lda.w #odhPlayerEye	; Height of Player's Eye
	sta.l PlayerHeight
	lda.w #0	; Player is NOT Dead
	sta.l PlayerDead
	sta.l PlayerDeadOld
	lda.w #-1
	sta.l PlayerOnGround	; Player IS ON Ground
;
	lda.w #0	; No Radiation Suit
	sta.l RadCount
;	lda	#0				; No Berserk Strength
	sta.l BerserkCount
	if useID4 != 0
	sta.l Berserk
	endif
;	lda	#0				; No Invisibility
	sta.l InvisibleCount
;	lda	#0				; No Invulnerability
	sta.l InvulnerableCount
;	lda	#0				; No Computer Map (DEBUG: has it)
	if !DEBUG != 0
	lda.w #1
	endif
	sta.l ComputerMap
;	lda	#0				; No Light Goggles
	sta.l LightGoggles
;
	lda.w _PlayerHealth	; Player's Health
	sta.l PlayerObject+rloHealth
	lda.w _PlayerArmor	; Player's Armor
	sta.l PlayerArmor
	lda.w _PlayerKeys	; Player's Keys/Arms
	sta.l PlayerKeys
	stz.w PlayerKeysOld
	lda.w _PlayerBullets	; Player's Bullets
	sta.l WeaponBullets
	lda.w _PlayerShells	; Player's Shells
	sta.l WeaponShells
	lda.w _PlayerRockets	; Player's Rockets
	sta.l WeaponRockets
	lda.w _PlayerCells	; Player's Cells
	sta.l WeaponCells
	sep #$20		; mode 'a!'
	lda.w _PlayerBackPack	; Player's BackPack
	sta.l BackPack
;
	rts


	%section(ENGINE_RAMCODE)
;
;	* * * * * * *       READ JOYSTICK/MOUSE       * * * * * * *
;
	; dbr 0
	; dpr 0
	; mode 'X'
;
;	__ReadJOY: ReadJOY, then ConvertJOY, then RTL (at _ReadJOY)
;
	_ReadJOY = $5C0A23
	assert (_ReadJOY&$FFFFFF) == ((((snestopc(realbase())&$00FFFFFF)+$400000))&$FFFFFF), "cached constant _ReadJOY is stale (tools/fixup.py)"
	rtl
	__ReadJOY = $5C0A24
	assert (__ReadJOY&$FFFFFF) == ((((snestopc(realbase())&$00FFFFFF)+$400000))&$FFFFFF), "cached constant __ReadJOY is stale (tools/fixup.py)"
	pea.w lo16(_ReadJOY-1)
	pea.w lo16(_ConvertJOY-1)
ReadJOY:
	sep #$20		; mode 'a!'
	%rcall(ReadMouse2)	; Mouse in port 2 (with a joypad in port 1)
;	lda	JOY2L				; Read Joystick Controller II
;	tax
;	and	#%00001111
;	cmp	#%00000001			; MOUSE?
;	beq	RJY2200				; Yes!
	ldx.w JOY1L	; Read Joystick Controller I
	txa
	and.b #%00001111
	bne RJY2100	; NOT a JOYSTICK!
	lda.w $4016	; Input PORT0
	lsr a
	lda.b #$00	; JOYSTICK Connected
	bcc RJY2340	; Nothing Connected!
	bra RJY2900
;
RJY2100:
	cmp.b #%00000001	; MOUSE?
	bne RJY2800	; No, INVALID
RJY2200:
	lda.w JOY1Stat	; MOUSE Previously Connected?
	dec a
	beq RJY2600	; Yes!
;
	ldx.w #4-1	; 4 Maximum Speed Settings
RJY2300:
	lda.b #$01	; Change Speed 1 Step
	sta.w $4016
	bit.w $4016+0
	stz.w $4016
	bit.w $4016+0
;
	sta.w $4016	; Reset Data Counter
	stz.w $4016
	ldy.w #10-1	; 10 Bits to Read
RJY2320:
	bit.w $4016+0
	dey
	bpl RJY2320
	lda.w $4016+0	; SP10
	lsr a
	lda.w $4016+0	; SP11
	rol a	; %SP
	and.b #%11
	cmp.b #%01	; FAST SPEED
	beq RJY2380
	dex
	bpl RJY2300
RJY2340:
;	bra	RJY2800				; Couldn't Set Speed?
RJY2800:
	lda.b #$FF	; Invalid Status
	ldx.w #0
RJY2900:
	sta.w JOY1Stat	; JOY1 STATUS
	stx.w JOY1	; Joystick Controller I
	rep #$20		; mode 'A!'
	rts

	; mode 'a'
RJY2380:
	stz.w MOUSE1X	; Default Displacement is 0
	stz.w MOUSE1Y
	lda.b #$01	; MOUSE Connected
	ldx.w #0
	bra RJY2900
;
RJY2600:
	ldy.w #8-1	; Read Y Displacement
RJY2620:
	lda.w $4016+0
	lsr a
	rol.w MOUSE1Y
	dey
	bpl RJY2620
	ldy.w #8-1	; Read X Displacement
RJY2640:
	lda.w $4016+0
	lsr a
	rol.w MOUSE1X
	dey
	bpl RJY2640
	lda.w MOUSE1X	; Turn by every reading (not only the last one per frame)
	%rcall(MouseAddTurn)
	lda.b #$01	; MOUSE Connected
	bra RJY2900

;
;	* * * * * * *       READ MOUSE IN PORT 2       * * * * * * *
;
;	A joypad in port 1 plus a mouse in port 2 play like keyboard and mouse
;	on the PC: the mouse turns, left button = fire, right button = use.
;
	; mode 'a'
ReadMouse2:
	lda.w JOY2L	; Port 2 signature %0001 = MOUSE
	and.b #%00001111
	cmp.b #%00000001
	beq RM2100
	lda.b #$FF	; No mouse
	sta.w JOY2Stat
	stz.w JOY2
	stz.w JOY2+1
	rts
RM2100:
	lda.w JOY2Stat	; Mouse already set up?
	cmp.b #$01
	beq RM2600
	ldx.w #4-1	; Set the same speed as port 1
RM2300:
	lda.b #$01	; Change Speed 1 Step
	sta.w $4016
	bit.w $4017
	stz.w $4016
	bit.w $4017
	sta.w $4016	; Reset Data Counter
	stz.w $4016
	ldy.w #10-1	; 10 Bits to Read
RM2320:
	bit.w $4017
	dey
	bpl RM2320
	lda.w $4017	; SP10
	lsr a
	lda.w $4017	; SP11
	rol a	; %SP
	and.b #%11
	cmp.b #%01	; FAST SPEED (as port 1)
	beq RM2380
	dex
	bpl RM2300
RM2380:
	lda.b #$01	; MOUSE Connected (read from the next frame on)
	sta.w JOY2Stat
	stz.w JOY2
	stz.w JOY2+1
	rts
RM2600:
	lda.w JOY2L	; Buttons
	sta.w JOY2
	stz.w JOY2+1
	ldy.w #8-1	; Read Y Displacement
RM2620:
	lda.w $4017
	lsr a
	rol.w MOUSE2Y
	dey
	bpl RM2620
	ldy.w #8-1	; Read X Displacement
RM2640:
	lda.w $4017
	lsr a
	rol.w MOUSE2X
	dey
	bpl RM2640
	lda.w MOUSE2X
;
;	>>>   ADD A MOUSE X DISPLACEMENT TO THE TURN   <<<
;
;	.A (8 bits) = bit 7 left, bits 6-0 counts.  Left turns left (positive),
;	21 angle units per count (as the original mouse velocity 64*count at
;	one count per VBlank).
;
MouseAddTurn:
	rep #$20		; mode 'A!'
	and.w #$00FF
	bit.w #$0080
	php
	and.w #$007F
	sta.w MouseTmp
	asl a	; *4
	asl a
	clc
	adc.w MouseTmp	; *5
	asl a	; *20
	asl a
	clc
	adc.w MouseTmp	; *21
	plp
	bne MAT200	; Left: positive
	eor.w #$FFFF	; Right: negative
	inc a
MAT200:
	clc
	adc.w PlayerMouseTurn
	bvc MAT300	; Saturate
	lda.w PlayerMouseTurn
	bmi MAT250
	lda.w #$7FFF
	bra MAT300
MAT250:
	lda.w #$8001
MAT300:
	sta.w PlayerMouseTurn
	sep #$20		; mode 'a!'
	rts


;
;	* * * * * * *       CONVERT JOYSTICK       * * * * * * *
;
;	CONVERT JOYSTICK MOVEMENT TO MOUSE VELOCITIES
;
	; dbr 0
	; dpr 0
	; mode 'AX'
;
;	>>>   MOUSE   <<<
;
	; mode 'A'
CJY5000:
	dec a	; MOUSE?
	bne CJY8000	; No, Invalid!
;
;	>>>   MOUSE VELOCITY X   <<<
;
	stz.w PlayerMouseX	; (turning: PlayerMouseTurn, from every reading)
;
;	>>>   MOUSE VELOCITY Y   <<<
;
	sep #$20		; mode 'a!'
	lda.w MOUSE1Y
	asl a
	rep #$20		; mode 'A!'
	and.w #$00FF
	beq CJY5500
	bcs CJY5400
	xba
	lsr a
	lsr a
	eor.w #$FFFF
	inc a
	bra CJY5500
CJY5400:
	xba
	lsr a
	lsr a
CJY5500:
	sta.w PlayerMouseY
	tax	; .X = MouseY
;
;	>>>   MOUSE BUTTONS   <<<
;
	lda.w JOY1	; MOUSE BUTTONS
	sep #$20		; mode 'a!'
	tay

	if useID8 == 0
	and.b #joyA	; RIGHT -> B (USE)
	xba
	tya	; LEFT -> X (FIRE)
	and.b #joyX
	endif
	if useID8 != 0
	and.b #joyX	; LEFT -> Y (FIRE)
	xba
	tya	; RIGHT -> A (USE)
	and.b #joyA
	endif

	rep #$20		; mode 'A!'
	cmp.w #(pjUSE|pjFIRE)	; BOTH Buttons?
	bne CJY5600
	lda.w #pjPAUSE	; Yes, PAUSE!
CJY5600:
	cmp.w #pjUSE	; USE BUTTON?
	bne CJY5800
	txy	; GOING AWAY?
	bpl CJY5800
	cpx.w #-($0F00>>1)
	bcs CJY5800
	lda.w #pjWEAPON	; Yes, SWITCH WEAPONS!
CJY5800:
	sta.w PlayerJoy
	rts
;
;	>>>   INVALID   <<<
;
	; mode 'A'
CJY8000:
	stz.w PlayerJoy
	stz.w PlayerMouseX
	stz.w PlayerMouseY
	rts

	; dbr 0
	; dpr 0
	; mode 'AX'
	_ConvertJOY = $5C0BD4
	assert (_ConvertJOY&$FFFFFF) == ((((snestopc(realbase())&$00FFFFFF)+$400000))&$FFFFFF), "cached constant _ConvertJOY is stale (tools/fixup.py)"
ConvertJOY:
	lda.w JOY1Stat	; JOY1Status
	and.w #$00FF
	bne CJY5000	; MOUSE?
;
;	>>>   JOYSTICK   <<<
;
	if RECORDDEMO != 0
	ldx.w DemoIndex
	lda.w #1	; 0=PLAY,1=RECORD
	beq CJY1800
;
;	>>>   RECORD   <<<
;
	ldy.w JOY1	; JOY1 ORIGINAL
	cpy.w DemoJOY	; Same Joystick Data?
	beq CJY1200	; Yes
	lda.w #0	; New Count
	sta.l DemoData,x
	tya	; New JOYData
	sta.l DemoData+2,x
	inx
	inx
	inx
	inx
	stx.w DemoIndex
	sty.w DemoJOY
CJY1200:
	ldx.w DemoIndex	; Count++
	lda.l DemoData-4,x
	inc a
	sta.l DemoData-4,x
	bra CJY2000
;
;	>>>   PLAY   <<<
;
CJY1800:
	dec.w DemoCount	; DemoJOY Still Valid?
	bne CJY1900	; Yes
	lda.l DemoData,x	; No, Get Next Event!
	sta.l DemoCount
	lda.l DemoData+2,x
	sta.l DemoJOY
	inx	; Move to Next Event
	inx
	inx
	inx
	stx.w DemoIndex
CJY1900:
	lda.l DemoJOY	; Recorded JOY Bits
	sta.w JOY1
	endif

CJY2000:
	lda.w JOY1	; JOY1 ORIGINAL
	and.w #~(pjFORWARD|pjREVERSE|pjROTATELEFT|pjROTATERIGHT)
	sta.w PlayerJoy	; GSU JoyStick Bits
	if useFX3CONTROLS != 0
;
;	>>>   THE ULTIMATE DOOM (FX3) CONTROLS   <<<
;
;	As the FX3 cartridge: <LEFT>/<RIGHT> turn while <L>/<R> strafe (the
;	GSU strafes at a fixed speed), walking is half of running, and turning
;	is quicker.  FX3's speeds are *1.5 here: its FPSRatio table is 30/60
;	per VBlank, this engine's (the original one) 20/60.
;	FX3 (its units)	walk $3C0, run $780 (forward and strafe)
;			turn: walk +$280 per frame up to $3C0, run $500 at once
;
	sep #$20		; mode 'a!'
	lda.w JOY1+1
	ldy.w #0
	lsr a	; RIGHT
	bcc .noright
	ldy.w #-$05A0	; Maximum turn
	sty.b ITemp
	ldy.w #-$03C0	; Turn acceleration
.noright:
	lsr a	; LEFT
	bcc .noleft
	ldy.w #$05A0
	sty.b ITemp
	ldy.w #$03C0
.noleft:
	phy
	ldy.w #0
	lsr a	; DOWN
	bcc .nodown
	ldy.w #-$05A0
.nodown:
	lsr a	; UP
	bcc .noup
	ldy.w #$05A0
.noup:
	sty.w PlayerMouseY
	rep #$20		; mode 'A!'
	lda.w JOY1	; RUNNING?
	and.w #pjRUN
	beq CJY2700	; No: accelerate the turn
	tya	; Yes, VELOCITY Y *= 2
	asl a
	sta.w PlayerMouseY
	lda.w PlayerJoy	; Strafing?
	and.w #(pjSTRAFELEFT|pjSTRAFERIGHT)
	beq .runturn
	pla	; Yes, turn at 2*acceleration at once
	asl a
	bra CJY2950
.runturn:
	ldy.w #$0780	; Maximum turn (= 2*acceleration: at once)
	pla
	asl a
	bpl .runturn2
	ldy.w #-$0780
.runturn2:
	sty.b ITemp
	bra CJY2720
	endif
	if useFX3CONTROLS == 0
	sep #$20		; mode 'a!'
	and.b #(pjSTRAFELEFT|pjSTRAFERIGHT)	; STRAFE?
	beq CJY2200	; No
	ldy.w #($03C0<<1)	; Yes, Set Strafing Velocity
	sty.b ITemp
	lda.w JOY1+1
	lsr a
	lsr a
	rep #$20		; mode 'A!'
	stz.w PlayerMouseX
	bra CJY2400
	; mode 'a'
CJY2200:
	lda.w PlayerJoy0	; Previously STRAFING?
	and.b #(pjSTRAFELEFT|pjSTRAFERIGHT)
	beq CJY2220	; No
	rep #$20		; mode 'A!'
	; Yes, Clear Strafing Velocity
	stz.w PlayerMouseX
CJY2220:
	lda.w JOY1+1
	ldy.w #0
	lsr a	; RIGHT
	bcc CJY2300
	ldy.w #-($0200<<1)
	sty.b ITemp
	ldy.w #-($00A0<<1)
CJY2300:
	lsr a	; LEFT
	bcc CJY2400
	ldy.w #($0200<<1)
	sty.b ITemp
	ldy.w #($00A0<<1)
CJY2400:
	phy
	ldy.w #0
	lsr a	; DOWN
	bcc CJY2500
	ldy.w #-($03C0<<1)
CJY2500:
	lsr a	; UP
	bcc CJY2600
	ldy.w #($03C0<<1)
CJY2600:
	sty.w PlayerMouseY
;
;	>>>   RUNNING?   <<<
;
	rep #$20		; mode 'A!'
	lda.w JOY1	; RUNNING?
	and.w #pjRUN
	beq CJY2700	; No
	tya	; VELOCITY Y *= 1.50
	cmp.w #$8000
	ror a
	clc
	adc.w PlayerMouseY
	sta.w PlayerMouseY
	lda.w PlayerJoy	; GSU JoyStick Bits
	and.w #(pjSTRAFELEFT|pjSTRAFERIGHT)	; STRAFING While RUNNING?
	beq CJY2650	; No
;
;	>>>   RUN AND STRAFE   <<<
;
	pla	; VELOCITY X *= 1.50
	sta.w PlayerMouseX
	cmp.w #$8000
	ror a
	clc
	adc.w PlayerMouseX
	bra CJY2950
;
;	>>>   RUN AND TURN   <<<
;
CJY2650:
	ldy.w #($0280<<1)
	pla	; VELOCITY X *= 1.25
	sta.b ITemp+2
	cmp.w #$8000
	ror a
	cmp.w #$8000
	ror a
;	cmp	#$8000
;	ror
	clc
	adc.b ITemp+2
	bpl CJY2670
	ldy.w #-($0280<<1)
CJY2670:
	sty.b ITemp
	bra CJY2720
	endif
;
;	>>>   NORMAL MOVEMENT   <<<
;
CJY2700:
	pla	; TURNING?
CJY2720:
	beq CJY2950	; No, Stop Immediately
	bmi CJY2750
	bit.w PlayerMouseX	; Turning in same direction?
	bpl CJY2800
	bra CJY2950
CJY2750:
	bit.w PlayerMouseX	; Turning in same direction?
	bpl CJY2950
CJY2800:
	clc	; Yes, accelerate turn
	adc.w PlayerMouseX
	bpl CJY2850
	cmp.b ITemp	; Ensure within Maximum Velocity
	bcs CJY2950
	lda.b ITemp
	bra CJY2950
CJY2850:
	cmp.b ITemp	; Ensure within Maximum Velocity
	bcc CJY2950
	lda.b ITemp
CJY2950:
	sta.w PlayerMouseX

	if IDLERESET != 0
;
;	>>>   IDLING FOR LONG TIME?   <<<
;
CJY3000:
	lda.w JOY1	; Idling?
	bne CJY3100	; No
	inc.w IdleCount	; Yes!
	bra CJY3200
CJY3100:
	stz.w IdleCount	; NOT Idling!
CJY3200:
	endif

;
;	>>>   MOUSE IN PORT 2: LEFT = FIRE, RIGHT = USE   <<<
;
	lda.w JOY2Stat
	and.w #$00FF
	cmp.w #$0001
	bne CJY3800
	lda.w JOY2
	and.w #$0040	; Left button
	beq CJY3700
	lda.w PlayerJoy
	ora.w #pjFIRE
	sta.w PlayerJoy
CJY3700:
	lda.w JOY2
	and.w #$0080	; Right button
	beq CJY3800
	lda.w PlayerJoy
	ora.w #pjUSE
	sta.w PlayerJoy
CJY3800:
;
;	>>>   COMPLETED JOYSTICK->MOUSE CONVERSION   <<<
;
	lda.w PlayerJoy	; Save Old GSU JoyStick Bits
	sta.w PlayerJoy0
	rts
