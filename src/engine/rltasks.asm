	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                        TASKS HANDLING MODULE                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"


	%section(LEVEL)

;
;	* * * * * * *       INITIALIZE TASKS       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitTasks:
	rep #$30		; mode 'AX!'
	lda.w #0	; NO TASKS RUNNING!
	sta.l RLNumTasks
	tax
	ldy.w #MaxRLTasks-1
_RITS200:
	lda.w #-1
	sta.l _RLTasks,x
	txa
	clc
	adc.w #rlmSize
	tax
	dey
	bpl _RITS200
	rtl



	%section(ENGINE_RAMCODE)

;
;	* * * * * * *       ADD A TASK       * * * * * * *
;
;	ADD NEW TASK TO TASKLIST
;
;	.Y = TaskCode
;	.X = TaskData
;
	; dbr ?
	; dpr 0
	; mode 'AX'
__RLAddTaskSNES:
	jsr.w _RLAddTaskSNES
	rtl
_RLAddTaskSNES:
	lda.l RLNumTasks	; (this port) table full: no task
	cmp.w #MaxRLTasks
	bcc _RLATS100
	rts
_RLATS100:
	phx	; Save TaskData
	phy	; Save TaskCode
	ldx.w #0	; Offset to TaskData
_RLATS200:
	lda.l _RLTasks,x	; Get TaskCode Address
	inc a	; Any CODE Here?
	beq _RLATS500	; No!  ReUse this Slot!
	txa
	clc
	adc.w #rlmSize
	tax
	jmp.w _RLATS200
_RLATS500:
	lda.l RLNumTasks	; Increment Number of Tasks Running
	inc a
	sta.l RLNumTasks
	pla	; Save Address of TaskCode
	sta.l _RLTasks+rlmCode,x
	pla	; Save Address of TaskData
	sta.l _RLTasks+rlmData,x
	rts



	%section(ENGINE_GSUCODE)
	arch superfx


	!rTaskPtr = r10	; Pointer to RLTask Structure
	!rTaskCount = r13	; TaskCounter


;
;	* * * * * * *       ADD A TASK       * * * * * * *
;
;	ADD NEW TASK TO TASKLIST
;
;	R9	= TaskCode Address-1
;	R8	= TaskData Address
;	R11     = Return Address
;
;	rTaskPointer = Pointer to TaskStructure.TaskData
;
_RLAddTask:
	lms r0,(RLNumTasks&$FFFF)	; Get Number of Tasks Running
	inc r0
;
;	(this port) table full: the task goes to the spare entry after the table,
;	which is never run (TNT MAP08 has more moving/blinking sectors than slots)
;
	ibt r1,#(MaxRLTasks+1)
;	from	r0
	cmp r1
	bne _RLAT100
	nop
	iwt !rTaskPtr,#lo16(_RLTasks+(MaxRLTasks*rlmSize))
	bra _RLAT500
	nop
_RLAT100:
;
	if !DEBUG != 0
	ibt r1,#MaxRLTasks	; Too many tasks?
;	from	r0
	cmp r1
	bne ._0	; No, Add this one
	%HALTGSU($80)
._0:
	endif

;	from	r0
	sbk
	iwt !rTaskPtr,#lo16(_RLTasks)	; Pointer to TaskData
_RLAT200:
;	to	r0				; Get TaskCode Address
	ldw (!rTaskPtr)
	inc r0	; Any CODE Here?
	beq _RLAT500	; No!  ReUse this Slot!
	with !rTaskPtr
	%add_i(rlmSize)
	bra _RLAT200
	nop
_RLAT500:
	move r0,r8	; Save Address of TaskData
	from r9	; Save Address of TaskCode
	stw (!rTaskPtr)
	inc !rTaskPtr
	inc !rTaskPtr
	jmp r11	; Return to Caller
;	from	r0
	stw (!rTaskPtr)


;
;	* * * * * * *       REMOVE A TASK       * * * * * * *
;
;	REMOVE EXISTING TASK FROM TASKLIST
;
;	R10	= Pointer to TaskStructure
;	R11     = Return Address
;
_RLRemTask:
	lms r0,(RLNumTasks&$FFFF)	; Get Number of Tasks Running
	dec r0
;	from	r0
	sbk
	ibt r0,#-1	; Disable this Task
	jmp r11	; Return to Caller
;	from	r0
	stw (!rTaskPtr)


;
;	* * * * * * *       DO TASKS       * * * * * * *
;
;	EXECUTE TASKS IN TASKLIST
;
_RLDoTasks:
	lms !rTaskCount,(RLNumTasks&$FFFF)	; Get Number of Tasks Running
	dec !rTaskCount	; Any Running Tasks?
	bmi _RLDT900
	inc !rTaskCount
	iwt !rTaskPtr,#lo16(_RLTasks)	; Pointer to TaskData
;
;	>>>   HANDLE NEXT TASK   <<<
;
_RLDT200:
	to r9	; Get TaskCode Address
	ldw (!rTaskPtr)
	inc r9	; Any CODE Here?
	beq _RLDT800	; No!
;
;	>>>   CALL TASK CODE   <<<
;
	link #2	; Set Return Address
	jmp r9	; Execute TaskCode
	nop
_RLDoTasks2:
	dec !rTaskCount	; One More Task Completed
	beq _RLDT900	; No More Tasks to Run!
;
;	>>>   MOVE TO NEXT TASK   <<<
;
_RLDT800:
	with !rTaskPtr	; Move to Next TaskData
	%add_i(rlmSize)
	bra _RLDT200+1
	to r9	; One More Task Completed
;
;	>>>   FINISHED HANDLING ALL TASKS   <<<
;
_RLDT900:
	if usePATCH == 0
	iwt r0,#lo16(_RLMSObjects)	; HANDLE MOVABLE OBJECTS STATES
	endif
	if usePATCH != 0
	lms r0,(PTRLMSObjects&$FFFF)	; HANDLE MOVABLE OBJECTS STATES
	endif
	ibt r8,#bank(_RLMSObjects)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop
