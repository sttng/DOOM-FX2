	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                         INITIALIZATION MODULE                      *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"

	; public RESET
	; public InitSystem
	; public RAGE


	%section(INIT)

;
;	* * * * * * *       RESET       * * * * * * *
;
RESET:
	rep #$20		; mode 'A!'
	lda.w #$1FFF	; Set Initial STACK
	tcs
	lda.w #$0000	; Set Initial DPR
	tcd
	; dpr 0
	sep #$30		; mode 'ax!'
	pha	; Set Initial DBR
	plb
	; dbr 0
;
	jsl.l InitSystem	; Initialize CORE HARDWARE SYSTEM
;
	rep #$20		; mode 'A!'
	lda.w RandSentry	; COLD or WARM/HOT boot?
	cmp.w #$4152
	bne ColdBoot	; COLD
	lda.w RandSentry+2
	cmp.w #$444E
	beq HotBoot	; WARM/HOT
;
;	* * * * * * *       COLD BOOT THE SYSTEM       * * * * * * *
;
;	Code executed upon <POWER_UP> of the MACHINE HARDWARE
;
ColdBoot:
	if (0*!DEBUGSCR) != 0
	jsl.l DebugWarnInfo	; Display DEBUG WARNING PAGE
	endif
	if useSYSINFO != 0
	jsl.l SystemInfo	; Display SYSTEM INFORMATION
	endif
	if useSTARTSCREEN != 0
	jsl.l StartScreen	; Display START SCREEN (loads the MUSIC Driver)
	else
	if useSOUND != 0
	jsl.l _InitMusicDriver	; Load MUSIC Driver
	endif
	endif
WarmBoot:
	if useLOGO != 0
	jsl.l Logo	; Display LOGO PAGE
	endif
	if useLOGO2 != 0
	jsl.l Logo2	; Display LOGO2 PAGE
	endif
	if useSCULPT != 0
	jsl.l SculpturedLightDemo	; Display SCULPTURED PAGE
	endif
	jmp.w HotBoot2
;
;	* * * * * * *       HOT BOOT THE SYSTEM       * * * * * * *
;
;	Code executed upon a <RESET> of the MACHINE HARDWARE
;
HotBoot:
	if useSOUND != 0
	jsl.l _InitMusicDriver	; Load MUSIC Driver
	endif
HotBoot2:
	jsl.l RestoreVars	; Restore Saved Variables
	; mode 'AX'
	inc.w _ResetCount	; Reset Count++
	jsl.l CheckSumVars
;
;	* * * * * * *       SYSTEM RUNNING       * * * * * * *
;
	jml.l RAGE	; Start RAGE!
