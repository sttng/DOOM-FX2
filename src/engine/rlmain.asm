	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                          ENGINE MAIN MODULE                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/snesmac.inc"
	incsrc "src/include/music.inc"


	%section(ENGINE_RAMCODE)
;
;	* * * * * * *       REALITY_ENGINE PRE_MAIN       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'A'
_RLMain0:

	if !RAMBPINTEST != 0
	sep #$20		; mode 'a!'
	stz.w TM
	lda.b #$0F	; Enable Display!
	sta.w INIDISP
RBPT200:
	sep #$20		; mode 'a!'
RBPT320:
	bit.w _HVBJOY	; Wait for NOT in VBlank Period
	bmi RBPT320
RBPT340:
	bit.w _HVBJOY	; Wait for IN VBlank Period
	bpl RBPT340
RBPT360:
	bit.w _HVBJOY	; Wait for NOT in VBlank Period
	bmi RBPT360
;
	rep #$30		; mode 'AX!'
	ldx.w #$0070
	lda.w #%111110000000000
	ldy.w JOY1L
	beq RBPT420
	inx
	lda.w #%000001111100000
;
RBPT420:
	sep #$20		; mode 'a!'
RBPT440:
	bit.w _HVBJOY	; Wait for IN VBlank Period
	bpl RBPT440
	stz.w CGADD
	sta.w CGDATA
	xba
	sta.w CGDATA
;
	stx.w sfxR0	; RAM BANK ($70/$71)
	rep #$20		; mode 'A!'
	lda.w #lo16(_RLRAMBPinTest)	; RAMBPINTEST PC
	jsr.w _RLCallGSU
	jmp.w RBPT200
	endif

	jsr.w _RLSwapRLXVars2	; Swap Updated RL Transfer Variables
	jsr.w _RLInitGSU2	; Initialize GSU
	jsr.w _RLSwapRLXVars	; Swap Initial RL Transfer Variables
	jsl.l SaveMessage	; (this port) "GAME SAVED." after a save (the GSU set-up clears messages)

	if !PROFILE != 0
	jmp.w _RLProfileGSU	; Profile the GSU
	endif

;	mode	'A!'
	stz.w PlayerLevelTime	; Start Player's LevelTimer
	sep #$20		; mode 'a!'
	stz.w VBlankTotal	; ReSet VBlank Total Counter
	stz.w VBlankCount	; ReStart FPSCount
	if usePAL != 0
	stz.w VBlankCountF
	endif
	lda.b #2	; Wait for 2 Displays Generated
	sta.b FrameCount
	lda.b #60	; #Ticks until 1 Second
	sta.w PlayerLevelCount
;
	jsr.w _RLInitGSU3	; Start RLEngine Running!

;
;	* * * * * * *       REALITY_ENGINE MAIN       * * * * * * *
;
_RLMain:

;
;	* * * * * * *       WAIT FOR FRAME UPDATE       * * * * * * *
;
_RLMain2000:
;
_RLMain2200:
	rep #$20		; mode 'A!'
	bit.b FrameDone-1	; Wait for Frame Completed
	bmi _RLMain9800	; FRAME COMPLETED!
;
;	* * * * * * *       HANDLE WEAPON       * * * * * * *
;
	jsr.w _RLUpdateWeapon	; Update Weapon
	; mode 'A'
	bit.b FrameDone-1	; Wait for Frame Completed
	bmi _RLMain9800	; UPDATE NOW!
;
;	* * * * * * *       OTHER MULTITASKING STUFF HERE       * * * * * * *
;
	jmp.w _RLMain2200
;
;	* * * * * * *       FRAME UPDATE COMPLETED       * * * * * * *
;
_RLMain9800:
	sep #$20		; mode 'a!'
	stz.b FrameDone	; Frame NOT Completed
;
	bit.b FrameCount	; Already Enabled Display?
	bmi _RLMain12000	; Yes
	dec.b FrameCount	; Ready to Enable Display?
	bpl _RLMain12000	; No
	lda.b #$0F	; Yes!  Enable Display!
	sta.w INIDISP_S

;
;	* * * * * * *       HANDLE RGB PALETTE ANIMATION       * * * * * * *
;
_RLMain12000:
	rep #$30		; mode 'AX!'
	lda.w RLRGB+!RLSNESGSUXVarsO	; Any Palette Animation Request?
	bmi _RLMain15000	; No
	dec.w RLRGBLock	; Lock RGB Palettes
	cmp.w #rgbPick	; Change Base?
	bcs _RLMain12200
	tax	; Get New Base Animation
	lda.l RLRGBBaseAnimTable,x
	sta.w RLRGBAnim0
	stz.w RLRGBPickCount	; ReStart Pick Counter
	stz.w RLRGBHitCount	; ReStart Hit Counter
	jmp.w _RLMain12900
;
;	>>>   HANDLE PICK RGB ANIMATION   <<<
;
_RLMain12200:
	bne _RLMain12400
	lda.w RLRGBPickCount	; Already Picked Up 4 Items?
	cmp.w #4
	beq _RLMain12300	; Yes
	inc a
	sta.w RLRGBPickCount
_RLMain12300:
	asl a	; Add Base Pick Up Animation
	clc
	adc.w #(RLRGBPickAnimTable-RLRGBAnimTable-2)
	jmp.w _RLMain12800
;
;	>>>   HANDLE HIT RGB ANIMATION   <<<
;
_RLMain12400:
	lda.w RLRGBHitCount	; Already Hit 8 Times?
	cmp.w #8
	beq _RLMain12500	; Yes
	inc a
	sta.w RLRGBHitCount
_RLMain12500:
	asl a	; Add Base Hit Animation
	clc
	adc.w #(RLRGBHitAnimTable-RLRGBAnimTable-2)
_RLMain12800:
	tax	; Get New Animation Table
_RLMain12900:
	lda.l RLRGBAnimTable,x
	sta.w RLRGBAnim
	stz.w RLRGBCount	; Change Animation Immediately
	inc.w RLRGBLock	; UnLock RGB Palettes

;
;	* * * * * * *       HANDLE WEAPON       * * * * * * *
;
_RLMain15000:
	jsr.w _RLUpdateWeapon	; Update Weapon

;
;	* * * * * * *       HANDLE STATUS BAR       * * * * * * *
;
_RLMain17000:
	jsr.w _RLUpdateStatusBar	; Update Status Bar

	if !DEBUGSCR != 0
;
;	* * * * * * *       HANDLE DEBUGGING SCREEN       * * * * * * *
;
_RLMain18000:
	jsr.w _RLUpdateDebug	; Update Debugging Screen
	endif

;
;	* * * * * * *       PAUSE MODE       * * * * * * *
;
_RLMain20000:
	rep #$20		; mode 'A!'
	lda.w #rlfHalt	; RLEngine Halted? (PAUSED)
	bit.b RLFlags
	bne _RLMain30000	; No, Keep Running
;
;	>>>   WAIT FOR RLENGINE HALTED   <<<
;
	dec.w RLRGBLock	; Lock RGB Palettes
_RLMain20200:
	lda.b IRQBPhase	; RLEngine Cycle Completed?
	ora.b IRQTPhase
	bne _RLMain20200	; No, Still Running
;
	jsl.l _RLMenus	; HANDLE MENUS
	; mode 'Ax'
;
;	>>>   RESTART RLENGINE RUNNING   <<<
;
	ldx.b #0
	stx.b FrameDone	; Frame NOT Completed
	if usePAL != 0
	stx.w VBlankCountF
	endif
	inx
	stx.w VBlankCount	; ReStart FPSCount
	stz.w PlayerJoy	; Clear Player Joystick/Mouse Variables
	stz.w PlayerMouseTurn
	stz.w PlayerMouseX
	stz.w PlayerMouseY
	stz.b IRQBPhase	; Phase of BOTTOM IRQ Operations
	stz.b IRQTPhase	; Phase of TOP IRQ Operations
	stz.w TQCount	; (this port) drop screen thirds still queued in WRAM
	stz.w TQHead	; (the save code uses that WRAM) and the third
	stz.w TQStrip	; partly copied from the GSU buffer
	lda.w #2	; Frames the GSU may start (_RLGSUReqMisc)
	sta.w TQMiscTokens
	lda.w #rlfDraw
	tsb.b RLFlags
	lda.w #rlfHalt	; RLEngine Running! (UNPAUSED)
	tsb.b RLFlags
	inc.w RLRGBLock	; UnLock RGB Palettes

;
;	* * * * * * *       LEVEL COMPLETED?       * * * * * * *
;
_RLMain30000:
	lda.w ExitLevel+!RLSNESGSUXVarsO	; Level Completed?
	bne _RLMain80000	; Yes!


;
;	* * * * * * *       IDLE TIMEOUT RESET?       * * * * * * *
;
	if IDLERESET != 0
_RLMain40000:
	lda.l IdleCount	; Idling for Approx. 30 Seconds?
	cmp.w #((60/4)*30)
	bcs _RLMain80000	; YES!  RESET!
	endif

;
;	* * * * * * *       NEXT FRAME UPDATE       * * * * * * *
;
_RLMain50000:

	if (0*!DEBUG) != 0
	lda.w JOY2L	; JOY2 Pressed?
	beq ._3
	lda.w #rlfHalt	; RLEngine Halted! (PAUSED)
	trb.b RLFlags
._0:
	wai
	lda.w JOY2L
	bne ._0
._1:
	wai
	lda.w JOY2L
	beq ._1
._2:
	wai
	lda.w JOY2L
	bne ._2
._3:
	lda.w #rlfHalt	; RLEngine Running! (UNPAUSED)
	tsb.b RLFlags
	endif

	jmp.w _RLMain2000



;
;	* * * * * * *       EXIT GAME       * * * * * * *
;
	; mode 'A'
_RLMain80000:
	lda.w #rlfHalt	; RLEngine Halted
	trb.b RLFlags
_RLMain80100:
	lda.b IRQTPhase	; RLEngine Cycle Completed?
	ora.b IRQBPhase
	bne _RLMain80100	; No, Still Running
;
	if useSOUND != 0
	rep #$10		; mode 'X!'
	lda.w #DCOM_FADE_AND_STOP	; Fade out Music
	ldy.w #$0401
	jsl.l _SendDriverCommandL
	endif
;
	sep #$30		; mode 'ax!'
	ldx.b #16-1	; 15 Steps to FadeOut ($0F..$01)
	lda.b #$0F
_RLMain80200:
	stz.b FrameDone	; Frame NOT Completed
	ldy.w VBlankCount	; Wait for VBlank
_RLMain80300:
	cpy.w VBlankCount
	beq _RLMain80300
	sta.w INIDISP_S	; Fade Value
	dec a	; Next Fade Value
	dex
	bne _RLMain80200
;
	if (!DEBUGSCR|ROM) == 0
HALTERROR:
	sep #$30		; mode 'ax!'
	endif
;
	lda.b #$80	; Disable Display
	sta.w INIDISP_S
	sta.w INIDISP
	sei	; Disable Interrupts
	lda.b #$01	; DISABLE NMI,VIRQ,HIRQ
	if (!DEBUG*WIRE) != 0
	sta.l NMITIMEN_XS
	lda.b #$81
	endif
	sta.w NMITIMEN
	bit.w _TIMEUP	; Clear IRQ Flag
;
	rep #$30		; mode 'AX!'
	stz.w sfxSFR	; Clear GO bit (Halt GSU)
_RLMain80400:
	lda.w sfxSFR	; GSU Halted?
	and.w #%0000000000100000
	bne _RLMain80400	; No, keep waiting
;
	rtl
