	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                        TOGGLES HANDLING MODULE                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"


	%section(LEVEL)
;
;	* * * * * * *       INITIALIZE TOGGLES       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitToggles:
	rep #$30		; mode 'AX!'
	lda.w #-1	; NO TOGGLES RUNNING!
	ldx.w #((MaxRLToggles-1)*rlttSize)
_RITT200:
	sta.l _RLToggleTasks+rlttCount,x
	dex	; Next Toggle
	dex
	dex
	dex
	bpl _RITT200
	rtl


	%section(ENGINE_GSUCODE)
	arch superfx


	!rTaskData = r8	; Pointer to TaskData
	!rTaskPtr = r10	; Pointer to RLTask Structure
	!rTaskCount = r13	; TaskCounter


;
;	* * * * * * *       ADD A TOGGLE       * * * * * * *
;
;	R3 = LineFlag Address
;
_RLAddToggle:
	iwt !rTaskData,#lo16(_RLToggleTasks+1)	; Pointer to ToggleTaskData
_RATT200:
;	to	r0				; Get Toggle CountDown
	ldb (!rTaskData)
;	with	r0				; ToggleTask Active?
	sex
	bmi _RATT500	; No!
	with !rTaskData	; Yes, Move to Next ToggleTask
	%add_i(rlttSize)
	bra _RATT200+1
	alt1
_RATT500:
	to r1	; @WITH IN PIPELINE@
	dec !rTaskData
	ibt r0,#rlttCountTime	; TOGGLE TIME
;	from	r0
	stw (!rTaskData)
	inc r1	; LINEFLAGS
	from r3
	stw (r1)
	iwt r9,#lo16(_TToggle-1)	; TaskCode-1
	iwt r15,#lo16(_RLAddTask)	; Allocate a Task
	nop

;
;	* * * * * * *       TOGGLE TASK CODE       * * * * * * *
;
_TToggle:
	from !rTaskPtr	; Get TaskData
;	to	r0
	%add_i(rlmData)
	to !rTaskData
	ldw (r0)
	lms r1,(FPSCount+RLGSUSNESXVarsO&$FFFF)	; Get FPSCount
;
;	>>>   TOGGLE COUNT EXPIRED?   <<<
;
;	to	r0				; Get Toggle CountDown
	ldw (!rTaskData)
;	with	r0				; Toggle CountDown -= FPSCounter
	sub r1
	bmi _TToggle2	; Time Up!  Switch the Toggle!
;	from	r0
	sbk
	jmp r11	; Return to Caller
_TToggle2:
	inc !rTaskData	; Get Toggle LineFlag Address
	inc !rTaskData
	to r1
	ldw (!rTaskData)
;	to	r0				; Get LineFlags
	ldb (r1)
;	with	r0				; NOT USED!
	%bic_i(rllfUsed)
;	from	r0
	stb (r1)
	iwt r15,#lo16(_RLRemTask)	; Remove the Task
	nop
