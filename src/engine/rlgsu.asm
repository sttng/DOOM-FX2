	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                           ENGINE GSU MODULE                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/rlplayer.inc"

	; public _RLInitGSU
	; public _RLInitGSU2


	%section(ENGINE)
;
;	* * * * * * *       INITIALIZE GSU HARDWARE       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitGSU:
	sei
	rep #$20		; mode 'A!'
;
	if usePATCH != 0
	lda.w #lo16(_RLDoTasks)	; DO TASKS
	sta.l PTRLDoTasks
	lda.w #lo16(_RLMSObjects)	; HANDLE MOVABLE OBJECTS STATES
	sta.l PTRLMSObjects
	lda.w #lo16(_RLMAObjects)	; HANDLE MOVABLE OBJECTS ANIMATIONS
	sta.l PTRLMAObjects
	lda.w #lo16(_RLEnemiesTarget)	; HANDLE ENEMY TARGETTING
	sta.l PTRLEnemiesTarget
	lda.w #lo16(_RLPlayer)	; HANDLE PLAYER
	sta.l PTRLPlayer
	lda.w #lo16(_RLWeapons)	; HANDLE WEAPONS
	sta.l PTRLWeapons
	lda.w #lo16(_RLDoSectors)	; HANDLE SECTORS
	sta.l PTRLDoSectors
	lda.w #lo16(_RLMisc2)	; DO MISCELLANEOUS TASKS 2
	sta.l PTRLMisc2
	lda.w #lo16(_RLBuildBSP)	; BUILD BSP TREE
	sta.l PTRLBuildBSP
	lda.w #lo16(_RLBuildDone)	; BUILD COMPLETED
	sta.l PTRLBuildDone
;
	lda.w #lo16(_RLBuildCheckObjs)	; BUILD CHECKOBJECTS
	sta.l PTRLBuildCheckObjs
	lda.w #lo16(_RLFireTarget)	; BUILD PLAYER TARGETTING LIST
	sta.l PTRLFireTarget
	lda.w #lo16(_RLFireTarget2)	; BUILD PLAYER TARGETTING LIST 2
	sta.l PTRLFireTarget2
	lda.w #lo16(_RLDamageObject0)	; DAMAGE OBJECT
	sta.l PTRLDamageObject
;
	lda.w #lo16(_RLMAPlayerDie)	; PLAYER DIE
	sta.l PTRLMAPlayerDie
	endif
;
	stz.b GSUPhase	; Initialize Phase
	lda.w #rlfPhasePending	; Phase Pending
	tsb.b RLFlags
	if !DEBUG != 0
	lda.w #0	; NO GSU ERROR
	sta.l GSUERROR
	endif
	stz.w sfxSFR	; Clear GO bit (Clear Cache)
	sep #$20		; mode 'a!'
	if GSUFAST != 0
	lda.b #%00000001	; 21.48 MHz Mode
	sta.w sfxCLK
	endif
	lda.b #%10100000	; GSU IRQs DISABLED, HighSpeed Multiply
	sta.w sfxCONFIG
	lda.b #%00011111	; 160 Pixels, GSU has ROM/RAM, 256 Colour
	if !DEBUG != 0
	sta.l SCR_XS	; XSLV Shadow
	endif
	sta.w sfxSCR
	lda.b #lo16(_RLGSUChrDef>>10)	; ScreenBase
	sta.w sfxSCBR
	stz.w sfxPCB	; ALWAYS PCBank $00
;
	rep #$20		; mode 'A!'
	lda.w #lo16(_RLGSUInit)	; Get Starting PC
	jsl.l __RLCallGSU
	rts


	%section(ENGINE_RAMCODE)
;
;	* * * * * * *       INITIALIZE GSU SOFTWARE       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'A'
_RLInitGSU2:
	lda.w #lo16(_RLGSUInit2)	; Get Starting PC
	jmp.w _RLCallGSU

	; dbr ?
	; dpr 0
	; mode 'A'
_RLInitGSU3:
	sep #$20		; mode 'a!'
	lda.b #%00100000	; GSU IRQs ENABLED, HighSpeed Multiply
	sta.w sfxCONFIG
_RLInitGSU3A:
	bit.w _HVBJOY	; Wait for NOT in VBlank Period
	bmi _RLInitGSU3A
_RLInitGSU3B:
	bit.w _HVBJOY	; Wait for IN VBlank Period
	bpl _RLInitGSU3B
_RLInitGSU3C:
	bit.w _HVBJOY	; Wait for NOT in VBlank Period
	bmi _RLInitGSU3C
	lda.w _RDNMI	; Clear NMI Flag
	lda.w _TIMEUP	; Clear IRQ Flag
	if (!DEBUG*WIRE) != 0
	lda.b #$B1	; ENABLE NMI+VEN+HEN+JOYREAD
	sta.l NMITIMEN_XS
	endif
	if (!DEBUG*WIRE) == 0
	lda.b #$31	; ENABLE VEN+HEN+JOYREAD
	endif
	sta.w NMITIMEN
	lda.w _RDNMI	; Clear NMI Flag
	lda.w _TIMEUP	; Clear IRQ Flag
	cli	; Enable IRQs!
	rts

;
;	* * * * * * *       CALL GSU SUBROUTINE       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'A'
__RLCallGSU:
	jsr.w _RLCallGSU
	rtl
_RLCallGSU:
	sta.l sfxR15	; Start GSU Running!
_RLCallGSU2:
	lda.l sfxSFR	; GSU Halted?
	and.w #%0000000000100000
	bne _RLCallGSU2
	rts



	%section(ENGINE_GSUCODE)
	arch superfx
;
;	* * * * * * *       REALITY_ENGINE GSU INIT CODE       * * * * * * *
;
_RLGSUInit:
;
;	>>>   INITIALIZE GSU   <<<
;
	ibt r0,#$70	; RAM in Bank $70
	if !RAMBPINTEST != 0
_RLRAMBPinTest:
	endif
	ramb
	stop
;	nop					; @NOP BELOW@
;
;	* * * * * * *       REALITY_ENGINE GSU INIT CODE 2       * * * * * * *
;
_RLGSUInit2:
	nop	; @FLUSH PIPELINE@
;
;	>>>   INITIALIZE TEXT MESSAGES   <<<
;
;	with	r0				; NO Current Message
	sub r0
	sms (MsgCount&$FFFF),r0
;
;	>>>   INITIALIZE VOBJLIST POINTER (WEAPONS TARGETTING)   <<<
;
	sms (VObjListStart&$FFFF),r0	; NO VISIBLE OBJECTS!
;
;	>>>   RAISE PLAYER'S WEAPON   <<<
;
	link #4	; Pick Up Weapon
	iwt r15,#lo16(_RLPickWeapon)
	nop
;
;	>>>   INITIALIZE PLAYER'S FACE ANIMATION   <<<
;
	link #4	; ReCalculate Face Animation
	iwt r15,#lo16(_RLCalcFaceAnim)
	nop
;
;	>>>   FINISHED INITIALIZING   <<<
;
	stop
	nop



	%section(ENGINE_RAMCODE)
	arch 65816
;
;	* * * * * * *       GSU PHASE R15 TABLE       * * * * * * *
;
GSUPhaseR15:
	dw lo16(_RLMisc)	; Handle Tasks
	dw lo16(_RLDrawA)	; Draw A
	dw lo16(_RLBuildB)	; Build B
	dw lo16(_RLDrawB)	; Draw B
	dw lo16(_RLBuildC)	; Build C
	dw lo16(_RLDrawC)	; Draw C
	MaxGSUPhase = 12
	assert (MaxGSUPhase&$FFFFFF) == (((pc()-GSUPhaseR15))&$FFFFFF), "cached constant MaxGSUPhase is stale (tools/fixup.py)"


;
;	* * * * * * *       GSU PHASE REQUIREMENTS CODE JUMPS TABLE       * * * * * * *
;
GSUPhaseReqCode:
	dw lo16(_RLGSUReqMisc)	; Handle Tasks
	dw lo16(_RLGSUReqDrawA)	; Draw A
	dw lo16(_RLGSUReqNull)	; Build B
	dw lo16(_RLGSUReqDrawB)	; Draw B
	dw lo16(_RLGSUReqNull)	; Build C
	dw lo16(_RLGSUReqDrawC)	; Draw C


;
;	* * * * * * *       GSU PHASE POST-EXECUTION CODE JUMPS TABLE       * * * * * * *
;
GSUPhasePostCode:
	dw lo16(_RLGSUPostNull)	; Handle Tasks
	dw lo16(_RLGSUPostDrawA)	; Draw A
	dw lo16(_RLGSUPostNull)	; Build B
	dw lo16(_RLGSUPostDrawB)	; Draw B
	dw lo16(_RLGSUPostNull)	; Build C
	dw lo16(_RLGSUPostDrawC)	; Draw C


;
;	* * * * * * *       GSU PHASE REQUIREMENTS CODE       * * * * * * *
;
	; mode 'A'
_RLGSUReqNull:
	lda.w #$524C	; ALWAYS READY
	rts

	; mode 'A'
_RLGSUReqMisc:
	lda.w TQMiscTokens	; (this port) the screen thirds pipeline lets the
	beq ._0	; GSU run ahead: a frame's tasks start only after
	lda.b RLFlags	; the vars swap of the frame before the last, as
	and.w #rlfHalt	; in the original engine (each FPSCount used once)
._0:
	rts	; (Z: no token, or RLEngine Halted)

	; mode 'A'
_RLGSUReqDrawA:
_RLGSUReqDrawB:
_RLGSUReqDrawC:
	lda.b RLFlags	; DRAW AVAILABLE?
	and.w #rlfDraw
	rts


;
;	* * * * * * *       GSU PHASE POST-EXECUTION CODE       * * * * * * *
;
	; mode 'AX'
_RLGSUPostDrawC:
;
;	>>>   PAUSE MODE   <<<
;
	lda.w PlayerJoy	; PAUSE?
	and.w #pjPAUSE
	beq _RLGSUPostDrawC2	; No
	bit.b FrameCount-1	; Already Enabled Display?
	bpl _RLGSUPostDrawC2	; No!
	lda.w #rlfHalt	; RLEngine Halted
	trb.b RLFlags
;	stz	PlayerJoy
;	stz	PlayerMouseX
;	stz	PlayerMouseY
	; mode 'AX'
_RLGSUPostDrawC2:
_RLGSUPostDrawA:
_RLGSUPostDrawB:
	lda.w #rlfDraw	; Draw Built
	trb.b RLFlags
	; mode 'AX'
_RLGSUPostNull:
	rts
