	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                        ENGINE PLATFORMS MODULE                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"


	%section(LEVEL)

;
;	* * * * * * *       INITIALIZE PLATFORMS       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitPlats:
	rep #$30		; mode 'AX!'
	ldx.w #0
	ldy.w #MaxRLMPlats-1
_RIPS200:
	lda.w #-1
	sta.l _RLPlatTasks+rlptState,x
	txa
	clc
	adc.w #rlptSize
	tax
	dey
	bpl _RIPS200
	rtl


	%section(ENGINE_GSUCODE)
	arch superfx


	!rTaskData = r8	; Pointer to TaskData
	!rSectorData = r9	; Pointer to SectorData
;
	!rFPSRatio = r5	; FPS Ratio
	!rFPSCount = r7	; FPS Counter
	!rTaskData = r8	; Pointer to TaskData
	!rTaskPtr = r10	; Pointer to RLTask
	!rTaskCount = r13	; TaskCounter


;
;	* * * * * * *       ADD A PLATFORM TASK STRUCTURE       * * * * * * *
;
	%align_pad(8, 16, (_RLAddPlatformTask-_RAPT200)&$0F)
_RLAddPlatformTask:
	iwt !rTaskData,#lo16(_RLPlatTasks)	; Pointer to PlatTaskData

	%CACHEB(_RLAddPlatformTask)
_RAPT200:
;	to	r0				; Get Platform State
	ldw (!rTaskData)
	inc r0	; Free (State = -1)?
	beq _RAPT500	; Yes!
	with !rTaskData	; No, move to next
	%add_i(rlptSize)
	bra _RAPT200+1
;	to	r0				; Get Platform State
	ldw (!rTaskData)
_RAPT500:
	jmp r11	; Return to Caller
	nop

	%CACHEE(_RLAddPlatformTask)


;
;	* * * * * * *       REMOVE A PLATFORM TASK STRUCTURE       * * * * * * *
;
;	rTaskData = Pointer to TaskData
;
_RLRemPlatformTask:
	ibt r0,#-1	; Platform State = -1
	jmp r11	; Return to Caller
;	from	r0
	stw (!rTaskData)


;
;	* * * * * * *       FIND PLATFORM TASKDATA       * * * * * * *
;
;	rSectorData = SectorData of Platform
;
	%align_pad(10, 16, (_RLFindPlatformTask-_RFPT200)&$0F)
_RLFindPlatformTask:
	iwt !rTaskData,#lo16(_RLPlatTasks)	; Pointer to PlatTaskData
	ibt r1,#MaxRLMPlats

	%CACHEB(_RLFindPlatformTask)
_RFPT200:
;	to	r0				; Get Platform State
	ldw (!rTaskData)
	inc r0	; Valid TaskData?
	bne _RFPT500	; Yes
_RFPT300:
	with !rTaskData	; No, move to next
	%add_i(rlptSize)
	dec r1
	bne _RFPT200+1
;	to	r0				; Get Platform State
	ldw (!rTaskData)
	ibt !rTaskData,#0	; No PlatTaskData Matches!
	jmp r11	; Return to Caller
_RFPT500:
	nop	; @"WITH" IN PIPELINE@
	from !rTaskData	; Move to SectorData
;	to	r0
	%add_i(rlptSectorData)
;	to	r0				; Get Platform SectorData
	ldw (r0)
;	with	r0				; Same SectorData?
	sub !rSectorData	; @CMP@
	bne _RFPT300+1
	with !rTaskData	; No, move to next
	jmp r11	; Return to Caller
	nop

	%CACHEE(_RLFindPlatformTask)


;
;	* * * * * * *       PLATFORM STATE CODE       * * * * * * *
;
_TPlatform:
	iwt r12,#lo16(_RLDoTasks2)	; Save Return Address
	from !rTaskPtr	; Get TaskData
;	to	r0
	%add_i(rlmData)
	to !rTaskData
	ldw (r0)
	lms !rFPSCount,(FPSCount+RLGSUSNESXVarsO&$FFFF)	; Get FPSCount
	lms !rFPSRatio,(FPSRatio&$FFFF)	; Get FPSRatio
;
;	>>>   CALL PLATFORM TASK STATE CODE   <<<
;
	ibt r0,#bank(_TPlatformCode)
	romb
	iwt r1,#lo16(_TPlatformCode)	; Base Address of JumpTable
	ldw (!rTaskData)	; Get Platform State
;	from	r0
	to r14
	add r1
	iwt r1,#lo16(EMSECTORS+2)	; R1 = Bank of EM Platform Data
	ldb (r1)
	to r2	; R2 = Platform StateCode
	getb
	inc r14
	with r2
	getbh
	romb	; Set ROM Bank
	link #3
	move r15,r2	; Call Platform StateCode
	nop
;
;	>>>   COMPLETED THIS STATE?   <<<
;
_TPlatform1:
;	with	r0				; At stopping position?
	sub r2
	bne _TPlatform900
	nop
;
;	* * * * * * *       NEXT PLATFORM STATE CODE       * * * * * * *
;
_TPlatform2:
	ibt r0,#bank(_TPlatformCode)
	romb
	ldw (!rTaskData)	; Get Platform State
	inc r0	; Next Platform State
	inc r0
	iwt r1,#lo16(_TPlatformCode+1)	; Base Address of JumpTable
;	from	r0
	to r14
	add r1
	to r1
	getb	; Get PlatformTask Code
	with r1
	sex
	bmi _TPlatform500	; Valid Task State
	nop
	dec r14
	getb	; New Task State
_TPlatform500:
;	from	r0
	sbk
;
_TPlatform3:
_TPlatform900:
	iwt r15,#lo16(_RLDoTasks2)	; Return to TaskDispatcher
	nop

;
;	* * * * * * *       KILL PLATFORM TASK       * * * * * * *
;
_TPlatformKill:
	link #4	; Remove PlatformTask
	iwt r15,#lo16(_RLRemPlatformTask)
	nop
	iwt r11,#lo16(_RLDoTasks2)	; Return to Task Dispatcher
	iwt r15,#lo16(_RLRemTask)	; Remove the Task
	nop


;
;	* * * * * * *       START PLATFORM SOUND EFFECT       * * * * * * *
;
;	R3 = Sound Effect#
;	R4 = Pointer to Sound Origin Coordinates
;
_TPlatformSound:
	iwt r11,#lo16(_TPlatform2)	; RETURN TO _TPLATFORM2
_TPlatformSound2:
	move r14,r4	; Get Platform Sound Origin
	getb	; SOUND ORIGIN X
	inc r14
	to r4
	getbh
	inc r14
	getb	; SOUND ORIGIN Y
	inc r14
	to r6
	getbh
	iwt r15,#lo16(_RLSoundEffect)	; START SOUND EFFECT!
	nop


;
;	* * * * * * *       PLATFORM TASK CODE JUMP TABLE       * * * * * * *
;
_TPlatformCode:
;
;	>>>   OPEN/CLOSE DOOR   <<<
;
_TPCDoorOpenClose:
	dw lo16(_TDoorOpen)	; Door Open
	dw lo16(_TDoorOpening)	; Door Opening
	dw lo16(_TDoorHold4Sec)	; Door Hold 4 seconds
	dw lo16(_TDoorHold)	; Door Hold
	dw lo16(_TDoorClose)	; Door Close
	dw lo16(_TDoorClosing)	; Door Closing
	dw lo16(_TDoorClosed)	; Door Closed
	dw lo16(_TPlatformKill)	; Remove Door
_TPCDoorOpenCloseE:
;
;	>>>   OPEN DOOR   <<<
;
_TPCDoorOpen:
	dw lo16(_TDoorOpen)	; Door Open
	dw lo16(_TDoorOpening)	; Door Opening
	dw lo16(_TPlatformKill)	; Remove Door
;
;	>>>   CLOSE DOOR   <<<
;
_TPCDoorClose:
	dw lo16(_TDoorClose)	; Door Close
	dw lo16(_TDoorClosing)	; Door Closing
	dw lo16(_TDoorClosed)	; Door Closed
	dw lo16(_TPlatformKill)	; Remove Door
;
;	>>>   CLOSE,OPEN DOOR   <<<
;
_TPCDoorCloseOpen:
	dw lo16(_TDoorClose)	; Door Close
	dw lo16(_TDoorClosing)	; Door Closing
	dw lo16(_TDoorClosed)	; Door Closed
	dw lo16(_TDoorHold30Sec)	; Door Hold 30 seconds
	dw lo16(_TDoorHold)	; Door Hold
	dw lo16(_TDoorOpen)	; Door Open
	dw lo16(_TDoorOpening)	; Door Opening
	dw lo16(_TPlatformKill)	; Remove Door
;
;	>>>   FLOOR RISE   <<<
;
_TPCFloorRise:
	dw lo16(_TFloorRising)	; Floor Rising
	dw lo16(_TPlatformKill)	; Remove Floor
;
;	>>>   FLOOR LOWER   <<<
;
_TPCFloorLower:
	dw lo16(_TFloorLowering)	; Floor Lowering
	dw lo16(_TPlatformKill)	; Remove Floor
;
;	>>>   STAIR RISE   <<<
;
_TPCStairRise:
	dw lo16(_TStairRising)	; Stair Rising
	dw lo16(_TPlatformKill)	; Remove Floor
;
;	>>>   CEILING LOWER   <<<
;
_TPCCeilingLower:
	dw lo16(_TCeilingLowering)	; Ceiling Lowering
	dw lo16(_TPlatformKill)	; Remove Ceiling
;
;	>>>   LIFT   <<<
;
_TPCLift:
	dw lo16(_TLiftStart)	; Lift Start
	dw lo16(_TLiftLowering)	; Lift Lowering
	dw lo16(_TLiftStop)	; Lift Stop
	dw lo16(_TLiftHold3Sec)	; Lift Hold 3 seconds
	dw lo16(_TLiftHold)	; Lift Hold
	dw lo16(_TLiftStart)	; Lift Start
	dw lo16(_TLiftRising)	; Lift Rising
	dw lo16(_TLiftStop)	; Lift Stop
	dw lo16(_TPlatformKill)	; Remove Lift
;	dc.w	(_TPCLift-_TPlatformCode)	; Restart at _TPCLift
;
;	>>>   MOVING FLOOR   <<<
;
_TPCMovingFloor:
	dw lo16(_TMovingFloorLowering)	; Moving Floor Lowering
	dw lo16(_TMovingFloorRising)	; Moving Floor Rising
	dw (_TPCMovingFloor-_TPlatformCode)	; Repeat
;
;	>>>   KILL MOVING FLOOR   <<<
;
_TPCKillMovingFloor:
	dw lo16(_TPlatformKill)	; Remove Lift
;
;	>>>   CRUSHING CEILING   <<<
;
_TPCCrushingCeiling:
	dw lo16(_TCrushingCeilingLowering)	; Crushing Ceiling Lowering
	dw lo16(_TCrushingCeilingRising)	; Crushing Ceiling Rising
	dw (_TPCCrushingCeiling-_TPlatformCode)	; Repeat
;
;	>>>   KILL CRUSHING CEILING   <<<
;
_TPCKillCrushingCeiling:
	dw lo16(_TPlatformKill)	; Remove Crushing Ceiling
