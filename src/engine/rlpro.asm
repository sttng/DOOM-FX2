	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       ENGINE PROFILING MODULE                      *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/snesmac.inc"

	if !PROFILE != 0
	; public _RLProfileGSU


	%section(ENGINE_RAMCODE)
;
;	* * * * * * *       REALITY_ENGINE PROFILE GSU       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
_RLProfileGSU:
;
;	>>>   INITIALIZE PROFILER HARDWARE/SOFTWARE   <<<
;
	lda.w #lo16(RLProfileData)	; Initialize ProfileDataPointer
	sta.b Temp
	lda.w #bank(RLProfileData)
	sta.b Temp+2
	lda.w #0	; Clear ProfileDataArea
	tay
_RLPRO200:
	sta.b [Temp],y
	iny
	iny
	bpl _RLPRO200
;
	sep #$20		; mode 'a!'
	lda.b #$0F	; ENABLE DISPLAY
	sta.w INIDISP
	lda.b #$01	; DISABLE NMIs
	sta.w NMITIMEN
	ldx.w #lo16(_RLIRQProfileGSU)	; ProfileGSU IRQ
	lda.b #bank(_RLIRQProfileGSU)
	jsl.l InitIRQ	; Initialize IRQs
	; mode 'A'
;
	stz.b Temp2	; (TEMP2) = GROUP TIME
	stz.b Temp2+2
	stz.b Temp3	; (TEMP3) = TOTAL TIME
	stz.b Temp3+2
;
	ldx.w #0	; Start at Phase0
;
;	>>>   TIME GSU PHASE   <<<
;
_RLPRO3000:
	stx.b GSUPhase	; Save GSUPhase
	lda.w #$1FFF	; Reset SP
	tcs
	cli	; Enable IRQs
	lda.l ProfileGSUPhaseR15,x	; Get Starting PC
	bpl _RLPRO3200	; Command
	jmp.w _RLPRO3800	; Normal PC
_RLPRO3200:
	txy
	pea.w lo16(_RLPRO6000-1)
	tax
	lda.l ProfileGSUCmdJumps,x
	pha
	tyx
	rts
;
;	>>>   PROFILER COMMAND CODES   <<<
;
ProfileGSUCmdJumps:
	dw lo16(_RLPROSeperator-1)	; 0 ADD SEPERATOR
	dw lo16(_RLPROHalt-1)	; 2 HALT
	dw lo16(_RLPROGroupStart-1)	; 4 GROUP START TIMECOUNT
	dw lo16(_RLPROGroupTime-1)	; 6 GROUP RECORD TIMECOUNT
	dw lo16(_RLPRONOP-1)	; 8 NOP

;
;	>>>   GROUP RECORD TIMECOUNT   <<<
;
_RLPROGroupTime:
	lda.b Temp2+2	; RECORD GROUP TIMECOUNT
	xba
	sta.b [Temp]
	lda.b Temp2
	xba
	ldy.w #2
	sta.b [Temp],y
	lda.b Temp
	clc
	adc.w #16
	sta.b Temp
_RLPRONOP:
	rts

;
;	>>>   GROUP START TIMECOUNT   <<<
;
_RLPROGroupStart:
	stz.b Temp2	; RESET GROUP TIMECOUNT
	stz.b Temp2+2
	rts

;
;	>>>   HALT   <<<
;
_RLPROHalt:
	cop #0
	rts

;
;	>>>   SEPERATOR VALUE   <<<
;
_RLPROSeperator:
	inx	; Get SEPERATOR VALUE
	inx
	lda.l ProfileGSUPhaseR15,x
	xba
	sta.b [Temp]
	ldy.w #2
	sta.b [Temp],y
	lda.b Temp
	clc
	adc.w #16
	sta.b Temp
	inx	; Get SCREEN COLOUR
	inx
	lda.l ProfileGSUPhaseR15,x
	sep #$20		; mode 'a!'
	stz.w CGADD
	sta.w CGDATA
	xba
	sta.w CGDATA
	rep #$20		; mode 'A!'
	rts

;
;	>>>   GSU PHASE PC   <<<
;
	; mode 'A'
_RLPRO3800:
	ldx.w #0	; .Y/.X = TIMECOUNTER
	txy
	sta.w sfxR15	; Start GSU Executing
;
;	>>>   TIME EXECUTION OF GSU PHASE   <<<
;
_RLPRO4000:
	inx	; Increment TIMECOUNT
	bne _RLPRO4000
	iny
	bne _RLPRO4000
	cop #1	; ERROR DURING PROFILE!

;
;	>>>   RECORD TIMECOUNT   <<<
;
_RLIRQProfileGSU:
_RLPRO5000:
	sep #$20		; mode 'a!'
	lda.w _TIMEUP	; Clear IRQ Flag
	rep #$20		; mode 'A!'
	lda.w sfxSFR	; Clear GSU IRQ Flag
;
	txa	; Update GROUP TIMECOUNT
	clc
	adc.b Temp2
	sta.b Temp2
	tya
	adc.b Temp2+2
	sta.b Temp2+2
;
	txa	; Update TOTAL TIMECOUNT
	clc
	adc.b Temp3
	sta.b Temp3
	tya
	adc.b Temp3+2
	sta.b Temp3+2
;
	tya	; .Y = TIMECOUNT HIGH
	xba
	sta.b [Temp]
	ldy.w #2	; .X = TIMECOUNT LOW
	txa
	xba
	sta.b [Temp],y
	lda.b Temp	; Move to next ProfileData
	clc
	adc.w #16
	sta.b Temp
;
	ldx.b GSUPhase	; Next GSU Phase
_RLPRO6000:
	inx
	inx
	cpx.w #MaxProfileGSUPhase	; Done ALL GSU Phases?
	beq _RLPRO8000	; Yes
	jmp.w _RLPRO3000	; No

;
;	>>>   PROFILING COMPLETE   <<<
;
_RLPRO8000:
	lda.w #$FFFF	; Put ProfileData Terminator
	sta.b [Temp]
	ldy.w #2
	sta.b [Temp],y
;
	lda.b Temp3+2	; Put ProfileData TOTAL TIME
	xba
	ldy.w #16
	sta.b [Temp],y
	lda.b Temp3
	xba
	ldy.w #16+2
	sta.b [Temp],y
;
;	>>>   PROFILING COMPLETE   <<<
;
	sep #$20		; mode 'a!'
	if WIRE != 0
	lda.b #$81	; ENABLE NMI+JOYREAD
	sta.l NMITIMEN_XS
	sta.w NMITIMEN
	endif
	cop #0


;
;	* * * * * * *       PROFILE GSU PHASE R15 TABLE       * * * * * * *
;
;	DC.W	GSUPC					GSU PHASE PC
;	DC.W	0,SeperatorValue.W,ColourValue.W	ADD SEPERATOR BAR
;	DC.W	2					HALT PROFILING
;	DC.W	4					GROUP START TIMECOUNT
;	DC.W	6					GROUP RECORD TIMECOUNT
;	DC.W	8					NOP
;
ProfileGSUPhaseR15:
	dw 4	; >GROUPSTART<
	dw 0,$1111,%000000000010000
	dw lo16(_RLMisc)	; Misc
	dw lo16(_RLPlayer)	; Player
	dw lo16(_RLWeapons)	; Weapons
	dw lo16(_RLDoSectors)	; Sectors
	dw lo16(_RLDoTasks)	; Tasks
	dw lo16(_RLMSObjects)	; Movable Objects StateMachine
	dw lo16(_RLMAObjects)	; Movable Objects AnimMachine
	dw lo16(_RLEnemiesTarget)	; Enemies' Targetting
	dw lo16(_RLEnemiesTarget2)	; Enemies' Targetting 2
	dw lo16(_RLEnemiesMove)	; Enemies' Movement
	dw lo16(_RLEnemiesAttack)	; Enemies' Attacking
	dw lo16(_RLEnemiesBirth)	; Enemies' Birthing
	dw lo16(_RLMisc2)	; Misc2
	dw 6	; >GROUPTOTAL<

	dw 4	; >GROUPSTART<
	dw 0,$2211,%000000000011100
	dw lo16(_RLBuildBSP)	; BSP
	dw 6	; >GROUPTOTAL<

	dw 4	; >GROUPSTART<
	dw 0,$3311,%000000000011111
	dw lo16(_RLBuildSegList1)	; Build
	dw lo16(_RLBuildSegList2)
	dw lo16(_RLBuildSegList3)
	dw lo16(_RLBuildSegList4)
	dw lo16(_RLBuildVSegList1)
	dw lo16(_RLBuildVSegList2)
	dw lo16(_RLBuildVSegList3)
	dw lo16(_RLBuildVSegList4)
	dw lo16(_RLBuildVObjList1)
	dw 6	; >GROUPTOTAL<

	dw 4	; >GROUPSTART<
	dw 0,$AABB,%000001111100000
	dw lo16(_RLBuildA)	; BuildA
	dw lo16(_RLBuildTrace)
	dw lo16(_RLBuildTraceWalls)
	dw lo16(_RLBuildTraceWalls2)
	dw lo16(_RLBuildTraceWalls3)
	dw lo16(_RLBuildTraceObjs)
	dw lo16(_RLBuildTraceObjs2)
	dw lo16(_RLBuildTraceObjs3)
	dw lo16(_RLBuildTraceFloors)
	dw lo16(_RLBuildTraceWalls4)
	dw lo16(_RLBuildTraceWalls5)
	dw lo16(_RLBuildTraceFloors2)
	dw lo16(_RLBuildTraceFloors3)
	dw 6	; >GROUPTOTAL<

	dw 4	; >GROUPSTART<
	dw 0,$AADD,%000001111111111
	dw lo16(_RLDrawA)	; Draw A
	dw lo16(_RLDrawWallsA)
	dw lo16(_RLDrawFloorsA)
	dw lo16(_RLDrawObjsA)
	dw lo16(_RLDrawSpritesA)
	dw lo16(_RLDrawMiscA)
	dw 6	; >GROUPTOTAL<
;
	dw 4	; >GROUPSTART<
	dw 0,$BBBB,%111110000000000
	dw lo16(_RLBuildB)	; Build B
	dw lo16(_RLBuildTrace)
	dw lo16(_RLBuildTraceWalls)
	dw lo16(_RLBuildTraceWalls2)
	dw lo16(_RLBuildTraceWalls3)
	dw lo16(_RLBuildTraceObjs)
	dw lo16(_RLBuildTraceObjs2)
	dw lo16(_RLBuildTraceObjs3)
	dw lo16(_RLBuildTraceFloors)
	dw lo16(_RLBuildTraceWalls4)
	dw lo16(_RLBuildTraceWalls5)
	dw lo16(_RLBuildTraceFloors2)
	dw lo16(_RLBuildTraceFloors3)
	dw 6	; >GROUPTOTAL<
;
	dw 4	; >GROUPSTART<
	dw 0,$BBDD,%111110000011111
	dw lo16(_RLDrawB)	; Draw B
	dw lo16(_RLDrawWallsB)
	dw lo16(_RLDrawFloorsB)
	dw lo16(_RLDrawObjsB)
	dw lo16(_RLDrawSpritesB)
	dw lo16(_RLDrawMiscB)
	dw 6	; >GROUPTOTAL<
;
	dw 4	; >GROUPSTART<
	dw 0,$CCBB,%111111111100000
	dw lo16(_RLBuildC)	; Build C
	dw lo16(_RLBuildTrace)
	dw lo16(_RLBuildTraceWalls)
	dw lo16(_RLBuildTraceWalls2)
	dw lo16(_RLBuildTraceWalls3)
	dw lo16(_RLBuildTraceObjs)
	dw lo16(_RLBuildTraceObjs2)
	dw lo16(_RLBuildTraceObjs3)
	dw lo16(_RLBuildTraceFloors)
	dw lo16(_RLBuildTraceWalls4)
	dw lo16(_RLBuildTraceWalls5)
	dw lo16(_RLBuildTraceFloors2)
	dw lo16(_RLBuildTraceFloors3)
	dw 6	; >GROUPTOTAL<
;
	dw 4	; >GROUPSTART<
	dw 0,$CCDD,%111111111111111
	dw lo16(_RLDrawC)	; Draw C
	dw lo16(_RLDrawWallsC)
	dw lo16(_RLDrawFloorsC)
	dw lo16(_RLDrawObjsC)
	dw lo16(_RLDrawSpritesC)
	dw lo16(_RLDrawMiscC)
	dw 6	; >GROUPTOTAL<
	MaxProfileGSUPhase = (pc()-ProfileGSUPhaseR15)	; Table size (bytes)
	endif
