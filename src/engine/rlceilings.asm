	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                        ENGINE CEILINGS MODULE                      *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


	!rSector = r6	; Pointer to Sector
	!rCeilingStateCode = r7	; Ceiling StateCode
	!rCeilingHeight = r5	; Destination Ceiling Height
;
	!rTaskData = r8	; Pointer to TaskData
	!rSectorData = r9	; Pointer to SectorData
	!rCeilingData = r10	; Pointer to CeilingData
;
	!rFPSRatio = r5	; FPS Ratio
	!rFPSCount = r7	; FPS Counter
	!rTaskData = r8	; Pointer to TaskData
	!rTaskPtr = r10	; Pointer to RLTask
	!rTaskCount = r13	; TaskCounter
;
	!rObj = r12	; RLObject


;
;	* * * * * * *       CHECK CEILING       * * * * * * *
;
;	R0 = 0 = BLOCKING, = 1 = CRUSHING
;	R3 = New Ceiling Position
;
;	R0 = 0 = Ceiling OK, = 1 = Ceiling Blocked by RLObject(s)!
;
	!rObj = r12
	!rTObj = r13

	%align_pad(2, 16, (_RLCheckCeiling-_RLCheckCeilingAlign)&$0F)	; align 16,(_RLCheckCeiling-_RLCheckCeilingAlign)&$0f
_RLCheckCeiling:
	iwt r1,#lo16(CeilingCrush)	; CeilingCrush = R0
;	from	r0				; CeilingBlocked = 0 (high byte)
	stw (r1)
;
	move r12,r11	; Save Return Address
	from !rSectorData	; Move to Sector's RLObjects
	to r4
	%add_i(rlsdObjects)
;
	link #4	; Build CheckObjectList
	if usePATCH == 0
	iwt r15,#lo16(_RLBuildCheckObjs)
	endif
	if usePATCH != 0
	lms r15,(PTRLBuildCheckObjs&$FFFF)
	endif
	nop
	move r11,r12	; Restore Return Address
;
	ibt r0,#bank(_ObjData)	; Move to _ObjData Bank
	romb
	iwt r4,#lo16(_RLCheckObjs-1)	; R4 = CheckObjects List
;
	%CACHEB(_RLCheckCeiling)
_RLCheckCeilingAlign:
;
;	>>>   BUILD CHECK OBJECTS LIST   <<<
;
_RLCC1200:
	inc r4	; Next Object
;	to	r0				; Get Next Object
	ldw (r4)
	moves !rObj,r0
	beq _RLCC1900	; No More Objects?!
	inc r4	; Next Object
	from !rObj	; Get Object's Flags/Type
;	to	r0
	%add_i(rloFlags)
;	to	r0
	ldw (r0)
;	from	r0				; Object SOLID?
	to r1
	%and_i(rlpfSolid)
	beq _RLCC1200	; NO!
;
;	>>>   GET RLOBJECT'S HEIGHT   <<<
;
;	with	r0				; Get Object's Type
	hib
;	from	r0				; Get Offset into _ObjData
	to r6
	%umult_i(rlodSize)
	iwt r0,#lo16(_ObjData+rlodHeight)	; Add Base of _ObjData
;	from	r0				; Move to Object Height
	to r14
	add r6
;
	from !rObj	; R1 = OBJECT Z
;	to	r0
	%add_i(rloZ)
	to r1
	ldw (r0)
	getb	; R0 = OBJECT HEIGHT
;	with	r0				; R0 = OBJECT TOP (OBJECT Z + OBJECT HEIGHT)
	add r1
;
;	>>>   OBJECT TOP < CEILING?   <<<
;
;	from	r0				; ObjectTop < Ceiling?
	cmp r3
	blt _RLCC1200	; Yes, Object Fits
;
;	>>>   CAN WE MOVE OBJECT DOWN TO FIT BETWEEN FLOOR AND NEW CEILING?   <<<
;
	from r3	; R0 = (CEILING HEIGHT - OBJECT HEIGHT)
;	to	r0
	sub r0
;	with	r0
	add r1
;
	ibt r1,#rloZ2	; PlayerObject?
	with r1
	add !rObj
	dec r6
	bmi _RLCC1300	; Yes, Use Z2 Coordinate
	from !rSectorData
	to r1
	%add_i(rlsdFloorHeight)
_RLCC1300:
	to r1	; R1 = Floor Height
	ldw (r1)
;
;	from	r0				; Object New Z < Floor?
	cmp r1
	blt _RLCC1500	; YES!  CAN'T FIT OBJECT NOW!
	from !rObj	; R1 = OBJECT Z
	to r6
	%add_i(rloZ)
;	from	r0				; No, Move Object Down to Fit!
	stw (r6)
	bra _RLCC1200+1	; Check Next Object
	inc r4	; Next Object
;
;	>>>   CAN'T MOVE CEILING TO THIS POSITION!   <<<
;
_RLCC1500:
;
;	>>>   BLOCK OR CRUSH?   <<<
;
	iwt r0,#lo16(CeilingCrush)	; Get CRUSH Status (0=BLOCK,1=CRUSH)
;	to	r0
	ldb (r0)
	dec r0	; BLOCK or CRUSH?
	bmi _RLCC1800	; BLOCK
;
;	>>>   CRUSH   <<<
;
	inc r6	; PlayerObject?
	bne _RLCC1600	; No
	from !rSectorData	; SectorData Ceiling Height
;	to	r0
	%add_i(rlsdCeilingHeight)
;	to	r0				; R0 = OLD Ceiling Height
	ldw (r0)
	ibt r6,#odhPlayer	; R1 = (PlayerFloor+PlayerHeight)
	with r1
	add r6
;	with	r0				; OLD Ceiling < Current Player Top?
	sub r1	; @CMP@
	blt _RLCC1200	; Yes!  Not really intersecting!
;
;	>>>   INFLICT DAMAGE   <<<
;
_RLCC1600:
	move r6,r11	; Save Return Address
	move r7,!rTaskCount	; Save TaskCount
;
	move !rTObj,!rObj	; TargetObject to Damage
	move !rObj,r4	; Save CheckObject Pointer
;
	ibt r4,#10	; 10 HitPoints per Crush
	link #3
	iwt r15,#lo16(_RLDamageObject)
;
	move r4,!rObj	; Restore CheckObject Pointer
	move !rTaskCount,r7	; Restore TaskCount
	move r11,r6	; Restore Return Address
;
;	>>>   CEILING MOVEMENT IS BLOCKED   <<<
;
_RLCC1800:
	iwt r1,#lo16(CeilingBlocked)	; Ceiling is BLOCKED
	ibt r0,#1
;	from	r0
	stb (r1)
	bra _RLCC1200+1	; Check Next Object
	inc r4	; Next Object
;
;	>>>   RETURN BLOCKED STATUS   <<<
;
_RLCC1900:
	iwt r0,#lo16(CeilingBlocked)	; Is Ceiling BLOCKED by RLObject(s)?
;	to	r0
	ldb (r0)
	jmp r11	; Return to Caller
	nop

	%CACHEE(_RLCheckCeiling)


;
;	* * * * * * *       ADD A PLATFORM CEILING       * * * * * * *
;
;	rSector			= Sector of Ceiling
;	rCeilingStateCode	= Ceiling StateCode
;	rCeilingHeight		= Destination Ceiling Height
;
_RLAddPlatformCeiling:
;
;	>>>   GET CEILING SECTOR'S SECTORDATA   <<<
;
	from !rSector
;	to	r0
	%umult_i(rlsdSize)
	iwt !rSectorData,#lo16(_RLSectorData)
	with !rSectorData
	add r0
;
;	>>>   EXISTING CEILING?   <<<
;
	link #3	; Find PlatformTask for this SectorData
	iwt r15,#lo16(_RLFindPlatformTask)
;
;	>>>   KILLING CRUSHING CEILINGS?   <<<
;
	moves !rCeilingStateCode,!rCeilingStateCode	; -1 = Kill Crushing Ceiling?
	bpl _RAPC400	; No, Creating Ceiling/Crushing Ceiling
	moves !rTaskData,!rTaskData	; Yes, Crushing Ceiling Running?
	beq _RAPC800	; No, Can't Remove It!
	nop
	ibt r0,#(_TPCKillCrushingCeiling-_TPlatformCode)
	jmp r12	; Return to Caller
;	from	r0
	stw (!rTaskData)
;
;	>>>   EXISTING CEILING?   <<<
;
_RAPC400:
	moves !rTaskData,!rTaskData	; Ceiling Already Running?
	bne _RAPC800	; Yes!
;
;	* * * * * * *       CREATE A NEW CEILING       * * * * * * *
;
_RAPC500:
	link #4
	iwt r15,#lo16(_RLAddPlatformTask)	; Allocate a PlatformTask Structure
	nop
;
	from !rCeilingStateCode	; CEILING STATE
	stw (!rTaskData)
;
	from !rTaskData	; Save Ceiling Parameters
	to r6
	%add_i(rlpctHeight)
	from !rCeilingHeight	; CEILING DESTINATION HEIGHT
	stw (r6)
	inc r6
	inc r6
	from !rCeilingData	; CEILINGDATA
	stw (r6)
	inc r6
	inc r6
	from !rSectorData	; SECTORDATA
	stw (r6)
;
	iwt r9,#lo16(_TPlatform-1)	; TaskCode-1
	move r11,r12	; Return to Caller when done
	iwt r15,#lo16(_RLAddTask)	; Allocate a Task
	nop
_RAPC800:
	jmp r12	; Return to Caller
	nop


;
;	* * * * * * *       CEILING SOUND       * * * * * * *
;
_TCeilingSound:
;	from	rTaskData			; Get CeilingData
;	to	r0
	%add_i(rlpctCeiling)
;	to	r0
	ldw (r0)
;	from	r0				; R4 = Pointer to SoundOrigin
	to r4
	%add_i(rlpcsOriginX)
	iwt r3,#lo16(sxStnMove-1)	; Sound Effect#
	iwt r15,#lo16(_TPlatformSound2)
	nop


;
;	* * * * * * *       CEILING LOWERING       * * * * * * *
;
_TCeilingLowering:
	link #3	; Make Ceiling Sound
	iwt r15,#lo16(_TCeilingSound)
;
	from !rTaskData	; Get Destination Height
;	to	r0
	%add_i(rlpctHeight)
	to r2	; Minimum Ceiling Height
	ldw (r0)
;	with	r0
	%add_i((rlpctSectorData-rlpctHeight))
;	to	r0				; Get SectorData
	ldw (r0)
;	from	r0
	to !rSectorData
	%add_i(rlsdCeilingHeight)
;
	ibt r6,#rlpcMovement	; Ceiling Adjustment
	from !rFPSRatio	; FPS Adjustment
;	to	r0
	lmult
;	with	r0				; Get Whole Levels Only
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0				; R1 = |CeilingAdjustment|
	to r1
	or r4
	ldw (!rSectorData)	; Get Ceiling Height
;	with	r0
	sub r1
;	from	r0
	cmp r2	; At Bottom?
	bge _TCL800	; No
	moves r0,r2	; Yes!
_TCL800:
	jmp r11	; Return to _TPlatform
;	from	r0
	sbk


;
;	* * * * * * *       CRUSHING CEILING LOWERING       * * * * * * *
;
_TCrushingCeilingLowering:
	link #3	; Make Ceiling Sound
	iwt r15,#lo16(_TCeilingSound)
;
	from !rTaskData	; Get SectorData
;	to	r0
	%add_i(rlpctSectorData)
	to !rSectorData
	ldw (r0)
;
	ibt r6,#rlpcMovement	; Ceiling Adjustment
;
	from !rFPSRatio	; FPS Adjustment
;	to	r0
	lmult
;	with	r0				; Get Whole Levels Only
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0				; R1 = |CeilingAdjustment|
	to r1
	or r4
;
	from !rSectorData
;	to	r0
	%add_i(rlsdFloorHeight)
	to r2	; R2 = Destination FloorHeight
	ldw (r0)
	with r2
	add #8
	inc r0	; Get CeilingHeight
	inc r0
;	to	r0
	ldw (r0)
;	from	r0				; R3 = NEW Ceiling Height
	to r3
	sub r1
;
;	>>>   CHECK IF CEILING IS CRUSHING SOMETHING   <<<
;
	ibt r0,#1	; 1=CRUSHING
	link #4
	iwt r15,#lo16(_RLCheckCeiling)
	nop
	dec r0	; R0 = 0 = OK, = 1 = BAD!
	with r3	; @"MOVE R0,R3"
	bmi _TCCL700
	to r0
;
;	>>>   CEILING IS CRUSHING SOMETHING -- HOLD AND CRUSH!   <<<
;
	iwt r15,#lo16(_TPlatform3)
	nop
_TCCL700:
	from !rSectorData	; SectorData Ceiling Height
	to r1
	%add_i(rlsdCeilingHeight)
;	from	r0
	cmp r2	; At Bottom?
	bge _TCCL800	; No
	moves r0,r2	; Yes!
_TCCL800:
	iwt r15,#lo16(_TPlatform1)
;	from	r0
	stw (r1)


;
;	* * * * * * *       CRUSHING CEILING RISING       * * * * * * *
;
_TCrushingCeilingRising:
	link #3	; Make Ceiling Sound
	iwt r15,#lo16(_TCeilingSound)
;
	from !rTaskData	; Get CeilingHeight
;	to	r0
	%add_i(rlpctHeight)
	to r2
	ldw (r0)
;	with	r0				; Get SectorData
	%add_i((rlpctSectorData-rlpctHeight))
;	to	r0
	ldw (r0)
;	from	r0				; Move to Ceiling Height
	to !rSectorData
	%add_i(rlsdCeilingHeight)
;
	ibt r6,#rlpcMovement	; Ceiling Adjustment
;
	from !rFPSRatio	; FPS Adjustment
;	to	r0
	lmult
;	with	r0				; Get Whole Levels Only
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0				; R1 = |CeilingAdjustment|
	to r1
	or r4
;
	ldw (!rSectorData)	; Get Ceiling Height
;	with	r0
	add r1
;	from	r0
	cmp r2	; At Top?
	blt _TCCR800	; No
	moves r0,r2	; Yes!
_TCCR800:
	iwt r15,#lo16(_TPlatform1)
;	from	r0
	sbk


;
;	* * * * * * *       BUILD LIST OF CHECK OBJECTS       * * * * * * *
;
;	R4 = SectorData.Objects
;
	%align_pad(8, 16, (_RLBuildCheckObjs-_RLBuildCheckObjsAlign)&$0F)	; align 16,(_RLBuildCheckObjs-_RLBuildCheckObjsAlign)&$0f
_RLBuildCheckObjs:
	iwt r6,#lo16(_RLCheckObjs)	; R6 = CheckObjects List
	from r4	; Move to SectorData
;	to	r0
	%sub_i(rlsdObjects)
	sms (ULSector&$FFFF),r0
;
	%CACHEB(_RLBuildCheckObjs)
_RLBuildCheckObjsAlign:
;
;	>>>   ADD SECTOR OBJECTS TO CHECKOBJECTS LIST   <<<
;
_RLBCO200:
;	to	r0				; Move to Next Object
	ldw (r4)
	moves r4,r0
	beq _RLBCO1000	; No More Objects!
	from r4	; Get Object's Flags/Type
;	to	r0
	%add_i((rloFlags+1))
;	to	r0				; @RAM FETCH INVERTED@
	ldw (r0)
;	with	r0				; MOVABLE?
	add r0
	bpl _RLBCO200	; No
;
;	>>>   PLAYER OBJECT?   <<<
;
;	with	r0				; Player Object?
	lob
	beq _RLBCO200	; Yes, Don't add Player Yet!
;
;	>>>   ADD OBJECT TO CHECKOBJECTS LIST   <<<
;
	from r4	; Add SectorObject
	stw (r6)
	inc r6
	bra _RLBCO200
	inc r6
;
;	>>>   ADD PLAYER OBJECT IF IN SAME SECTOR   <<<
;
_RLBCO1000:
	if useMULTIPLAYER == 0
	iwt r7,#lo16(PlayerObject)	; Player Object in Sector?
	endif
	if useMULTIPLAYER != 0
	lms r7,(MPPlayerObject&$FFFF)	; Player Object in Sector?
	endif
	ibt r0,#rloSector
;	with	r0
	add r7
;	to	r0
	ldb (r0)
;	with	r0
	%umult_i(rlsdSize)
	iwt r4,#lo16(_RLSectorData)
;	with	r0
	add r4
	lms r4,(ULSector&$FFFF)
;	with	r0
	sub r4	; Same Sector?
	bne _RLBCO2000	; No, Check Radius Intersections
	nop
	iwt r15,#lo16(_RLBCO6800)	; Yes!
	from r7
;
;	>>>   ADD PLAYER OBJECT IF WITHIN PLAYER RADIUS OF SECTOR CENTER   <<<
;
_RLBCO2000:
	sms (MVReturnAddress&$FFFF),r12	; Caller's Return Address
	sms (ULReturnAddress&$FFFF),r11	; Return Address
	sms (CCDestHeight&$FFFF),r2	; Destination Height
	sms (MVRObj&$FFFF),r7	; RLObject Pointer
	sms (MVSector&$FFFF),r9	; SectorData
	sms (MVCode&$FFFF),r8	; TaskCode
	sms (MVCount&$FFFF),r13	; TaskCount
	sms (MVMLPtr&$FFFF),r6	; CheckObjects List
	ibt r1,#odrPlayer	; JUST Outside of Player Radius
	link #3
	bra _RLBCO3000
	nop
	ibt r1,#(odrPlayer/2)	; WITHIN Player Radius Up To 8 Units
	iwt r11,#lo16(_RLBCO6200)	; Player NOT within Range!
;
;	>>>   TOP LEFT   <<<
;
_RLBCO3000:
	sms (CCRadius&$FFFF),r1	; Save Radius Adjustment
	sms (CCReturnAddress&$FFFF),r11	; Save Return Address
	from r7	; RLObject Pointer
;	to	r0
	%add_i((rloX+2))
	to r7
	ldw (r0)
;	with	r0
	%add_i(((rloY+2)-(rloX+2)))
	to r8
	ldw (r0)
	with r7
	sub r1
	with r8
	add r1
	link #4
	iwt r15,#lo16(_RLGetXYSectorData)	; Get SectorData
	nop
	lms r0,(ULSector&$FFFF)	; Same SectorData?
;	with	r0
	sub !rSectorData
	beq _RLBCO6000+1	; Yes!
;
;	>>>   TOP RIGHT   <<<
;
	lms r0,(MVRObj&$FFFF)	; RLObject Pointer
;	with	r0
	%add_i((rloX+2))
	to r7
	ldw (r0)
;	with	r0
	%add_i(((rloY+2)-(rloX+2)))
	to r8
	ldw (r0)
	lms r0,(CCRadius&$FFFF)
	with r7
	add r0
	with r8
	add r0
	link #4
	iwt r15,#lo16(_RLGetXYSectorData)	; Get SectorData
	nop
	lms r0,(ULSector&$FFFF)	; Same SectorData?
;	with	r0
	sub !rSectorData
	beq _RLBCO6000+1	; Yes!
;
;	>>>   BOTTOM LEFT   <<<
;
	lms r0,(MVRObj&$FFFF)	; RLObject Pointer
;	with	r0
	%add_i((rloX+2))
	to r7
	ldw (r0)
;	with	r0
	%add_i(((rloY+2)-(rloX+2)))
	to r8
	ldw (r0)
	lms r0,(CCRadius&$FFFF)
	with r7
	sub r0
	with r8
	sub r0
	link #4
	iwt r15,#lo16(_RLGetXYSectorData)	; Get SectorData
	nop
	lms r0,(ULSector&$FFFF)	; Same SectorData?
;	with	r0
	sub !rSectorData
	beq _RLBCO6000+1	; Yes!
;
;	>>>   BOTTOM RIGHT   <<<
;
	lms r0,(MVRObj&$FFFF)	; RLObject Pointer
;	with	r0
	%add_i((rloX+2))
	to r7
	ldw (r0)
;	with	r0
	%add_i(((rloY+2)-(rloX+2)))
	to r8
	ldw (r0)
	lms r0,(CCRadius&$FFFF)
	with r7
	add r0
	with r8
	sub r0
	link #4
	iwt r15,#lo16(_RLGetXYSectorData)	; Get SectorData
	nop
	lms r0,(ULSector&$FFFF)	; Same SectorData?
;	with	r0
	sub !rSectorData
	beq _RLBCO6000+1	; Yes!
	lms r15,(CCReturnAddress&$FFFF)	; Player NOT Within Range!
;	with	r0
	sub r0
;
;	>>>   ADD PLAYER OBJECT   <<<
;
_RLBCO6000:
	lms r0,(MVRObj&$FFFF)	; RLObject Pointer
_RLBCO6200:
	lms r6,(MVMLPtr&$FFFF)	; CheckObject List
	lms r12,(MVReturnAddress&$FFFF)	; Caller's Return Address
	lms r11,(ULReturnAddress&$FFFF)	; Return Address
	lms r2,(CCDestHeight&$FFFF)	; Destination Height
	lms r9,(MVSector&$FFFF)	; SectorData
	lms r8,(MVCode&$FFFF)	; TaskCode
	lms r13,(MVCount&$FFFF)	; TaskCount
_RLBCO6800:
;	from	r0				; Add Player Object!
	stw (r6)
	inc r6
	inc r6
;
;	>>>   CHECKOBJECT LIST COMPLETE   <<<
;
_RLBCO8000:
;	with	r0				; Terminate CheckObjects List
	sub r0
	jmp r11	; Return to Caller
;	from	r0
	stw (r6)

	%CACHEE(_RLBuildCheckObjs)
