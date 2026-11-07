	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                         ENGINE FLOORS MODULE                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"


	%section(ENGINE_GSUCODE)
	arch superfx

	!rSector = r6	; Pointer to Sector
	!rFloorStateCode = r7	; Floor StateCode
	!rFloorHeight = r5	; Destination Floor Height
;
	!rTaskData = r8	; Pointer to TaskData
	!rSectorData = r9	; Pointer to SectorData
	!rFloorData = r10	; Pointer to FloorData
;
	!rFPSRatio = r5	; FPS Ratio
	!rFPSCount = r7	; FPS Counter
	!rTaskData = r8	; Pointer to TaskData
	!rTaskPtr = r10	; Pointer to RLTask
	!rTaskCount = r13	; TaskCounter
;
	!rObj = r12	; RLObject


;
;	* * * * * * *       ADD A PLATFORM FLOOR       * * * * * * *
;
;	rSector		= Sector of Floor
;	rFloorStateCode	= Floor StateCode
;	rFloorHeight	= Destination Floor Height
;	rFloorData	= FloorData
;
_RLAddPlatformFloor:
;
;	>>>   GET FLOOR SECTOR'S SECTORDATA   <<<
;
	from !rSector
;	to	r0
	%umult_i(rlsdSize)
	iwt !rSectorData,#lo16(_RLSectorData)
	with !rSectorData
	add r0
;
;	>>>   EXISTING FLOOR?   <<<
;
_RLAddPlatformFloor2:
	link #3	; Find PlatformTask for this SectorData
	iwt r15,#lo16(_RLFindPlatformTask)
	moves !rTaskData,!rTaskData	; Floor Already Running?
	bne _RAPF800	; Yes!
	nop
;
;	* * * * * * *       CREATE A NEW FLOOR       * * * * * * *
;
_RAPF500:
	link #4
	iwt r15,#lo16(_RLAddPlatformTask)	; Allocate a PlatformTask Structure
	nop
;
	from !rFloorStateCode	; FLOOR STATE
	stw (!rTaskData)
;
;	link	#4				; FIND SECTOR'S FLOORDATA
;	iwt	r15,#<_RLFindFloorData
;	nop
;
	from !rTaskData	; Save Floor Parameters
	to r6
	%add_i(rlpftHeight)
	from !rFloorHeight	; FLOOR DESTINATION HEIGHT
	stw (r6)
	inc r6
	inc r6
	from !rFloorData	; FLOORDATA
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
_RAPF800:
	jmp r12	; Return to Caller
	nop


;
;	* * * * * * *       FLOOR SOUND       * * * * * * *
;
_TFloorSound:
;	from	rTaskData			; Get FloorData
;	to	r0
	%add_i(rlpftFloor)
;	to	r0
	ldw (r0)
;	from	r0				; R4 = Pointer to SoundOrigin
	to r4
	%add_i(rlpfsOriginX)
	iwt r3,#lo16(sxStnMove-1)	; Sound Effect#
	iwt r15,#lo16(_TPlatformSound2)
	nop


;
;	* * * * * * *       FLOOR RISING       * * * * * * *
;
_TFloorRising:
	link #3	; Make Floor Sound
	iwt r15,#lo16(_TFloorSound)
;
	from !rTaskData	; Get Destination Height
;	to	r0
	%add_i(rlpftHeight)
	to r2	; Maximum Floor Height
	ldw (r0)
;	with	r0
	%add_i((rlpftSectorData-rlpftHeight))
;	to	r0				; Get SectorData
	ldw (r0)
;	from	r0
	to !rSectorData
	%add_i(rlsdFloorHeight)
;
	ibt r6,#rlpfMovement	; Floor Adjustment
	from !rFPSRatio	; FPS Adjustment
;	to	r0
	lmult
;	with	r0				; Get Whole Levels Only
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0				; R1 = |FloorAdjustment|
	to r1
	or r4
;
	ldw (!rSectorData)	; Get Floor Height
;	from	r0				; R3 = NEW Floor Height
	to r3
	add r1
	from r3	; @CMP@
;	to	r0
	sub r2	; At Top?
	blt _TFR800	; No
	moves r3,r2	; Yes!
_TFR800:
	link #3
	bra _RLCheckFloor
	nop
	iwt r15,#lo16(_TPlatform1)
;	from	r0				; New Floor Height
	stw (!rSectorData)


;
;	* * * * * * *       CHECK FLOOR 0       * * * * * * *
;
;	R3 = New Floor Height
;
;	R0 = New Floor Height
;
	%align_pad(4, 16, (_RLCheckFloor0-_RLCheckFloorAlign)&$0F)	; align 16,(_RLCheckFloor0-_RLCheckFloorAlign)&$0f
_RLCheckFloor0:
	move r12,r11	; Save Return Address
	from !rSectorData	; Move to Sector's RLObjects
	to r4
	%add_i((rlsdObjects-rlsdFloorHeight))
	link #4	; Build CheckObjectList
	if usePATCH == 0
	iwt r15,#lo16(_RLBuildCheckObjs)
	endif
	if usePATCH != 0
	lms r15,(PTRLBuildCheckObjs&$FFFF)
	endif
	nop
	ibt r0,#bank(_ObjData)	; Move to _ObjData Bank
	romb
	with r12	; Restore Return Address
	bra _RLCF1500
	to r11
;
;	* * * * * * *       CHECK FLOOR       * * * * * * *
;
;	R3 = New Floor Height
;
;	R0 = New Floor Height
;
_RLCheckFloor:
	move r12,r11	; Save Return Address
	from !rSectorData	; Move to Sector's RLObjects
	to r4
	%add_i((rlsdObjects-rlsdFloorHeight))
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
	%CACHEB(_RLCheckFloor)
_RLCheckFloorAlign:
_RLCF1300:
	inc r4	; Next Object
;	to	r0				; Move to Next Object
	ldw (r4)
	moves !rObj,r0
	beq _RLCF1500	; No More Objects?!
	inc r4	; Next Object
	from !rObj	; Get Object's Flags/Type
;	to	r0
	%add_i(rloFlags)
;	to	r0
	ldw (r0)
;	from	r0				; Object SOLID?
	to r1
	%and_i(rlpfSolid)
	beq _RLCF1300	; NO!
;
;	>>>   GET RLOBJECT'S HEIGHT   <<<
;
;	with	r0				; Get RLObject Type
	hib
;	with	r0				; Get Offset into _ObjData
	%umult_i(rlodSize)
	iwt r1,#lo16(_ObjData+rlodHeight)	; Add Base of _ObjData
;	from	r0				; Move to Object Height
	to r14
	add r1
;
;	>>>   GET RLOBJECT'S SECTOR'S CEILING   <<<
;
	ibt r6,#rloC2	; PlayerObject?
	with r6
	add !rObj
	dec r0
	bmi _RLCF1350-1	; Yes, Use C2 Coordinate
	ibt r0,#rloSector	; Get RLObject's SectorData
;	with	r0
	add !rObj
;	to	r0
	ldb (r0)
;	with	r0
	%umult_i(rlsdSize)
	iwt r6,#lo16(_RLSectorData+rlsdCeilingHeight)
	with r6
	add r0
_RLCF1350:
	to r6	; R6 = Ceiling Height
	ldw (r6)
	inc r6
;
;	>>>   OBJECT TOP < CEILING?   <<<
;
	getb	; R0 = OBJECT HEIGHT
;	with	r0				; R0 = OBJECT TOP (FLOOR Z + OBJECT HEIGHT)
	add r3
;	with	r0				; ObjectTop < Ceiling?
	sub r6	; @CMP@
	blt _RLCF1300+1	; Yes, Object Fits
	inc r4	; Next Object
;
;	>>>   CAN'T MOVE FLOOR TO THIS POSITION!   <<<
;
_RLCF1400:
	jmp r11
;	to	r0				; R0 = OLD FloorHeight
	ldw (!rSectorData)

	%CACHEE(_RLCheckFloor)

;
;	>>>   MOVE ALL OBJECTS TO NEW FLOOR POSITION   <<<
;
	%align_pad(3, 16, (_RLCF1500-_RLCF1600)&$0F)	; align 16,(_RLCF1500-_RLCF1600)&$0f
_RLCF1500:
	to r6	; R6 = OLD FloorHeight
	ldw (!rSectorData)
	inc r6
	iwt r4,#lo16(_RLCheckObjs-1)	; R4 = CheckObjects List
;
	%CACHEB(_RLCheckFloor2)
_RLCF1600:
	inc r4	; Next Object
;	to	r0				; Move to Next Object
	ldw (r4)
	moves !rObj,r0
	beq _RLCF1900	; No More Objects?!
;
;	>>>   PLAYER RLOBJECT?   <<<
;
	from !rObj	; Get Object's Type
;	to	r0
	%add_i(rloType)
;	to	r0
	ldb (r0)
;	with	r0				; Player Object?
	lob
	beq _RLCF1600	; YES!  DON'T ADJUST!
	inc r4	; Next Object
;
;	>>>   GET RLOBJECT'S Z   <<<
;
	from !rObj	; R0 = OBJECT Z
;	to	r0
	%add_i(rloZ)
;	to	r0
	ldw (r0)
;
;	>>>   OBJECT Z < FLOOR Z?   <<<
;
;	from	r0				; ObjectZ < Floor?
	cmp r3
	blt _RLCF1700	; Yes, Move Object to Floor
;
;	>>>   OBJECT Z = PREVIOUS FLOOR Z?   <<<
;
;	with	r0				; ObjectZ On Previous Floor?
	sub r6	; @CMP@
	bge _RLCF1600	; No
;
;	>>>   MOVE OBJECT TO FLOOR   <<<
;
_RLCF1700:
	from r3	; Object Z = New Floor Height
	sbk
	bra _RLCF1600+1	; Check Next Object
	inc r4	; Next Object
;
;	>>>   FINISHED ADJUSTING OBJECTS   <<<
;
_RLCF1900:
	move r0,r3	; R0 = NEW FloorHeight
	jmp r11	; Return to Caller
	nop

	%CACHEE(_RLCheckFloor2)


;
;	* * * * * * *       FLOOR LOWERING       * * * * * * *
;
_TFloorLowering:
	link #3	; Make Floor Sound
	iwt r15,#lo16(_TFloorSound)
;
	from !rTaskData	; Get Destination Height
;	to	r0
	%add_i(rlpftHeight)
	to r2	; Minimum Floor Height
	ldw (r0)
;	with	r0
	%add_i((rlpftSectorData-rlpftHeight))
;	to	r0				; Get SectorData
	ldw (r0)
;	from	r0
	to !rSectorData
	%add_i(rlsdFloorHeight)
;
	ibt r6,#rlpfMovement	; Floor Adjustment
	from !rFPSRatio	; FPS Adjustment
;	to	r0
	lmult
;	with	r0				; Get Whole Levels Only
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0				; R1 = |FloorAdjustment|
	to r1
	or r4
	ldw (!rSectorData)	; Get Floor Height
;	from	r0				; R3 = NEW Floor Height
	to r3
	sub r1
	from r3	; @CMP@
;	to	r0
	sub r2	; At Bottom?
	bge _TFL800	; No
	moves r3,r2	; Yes!
_TFL800:
	link #4
	iwt r15,#lo16(_RLCheckFloor0)
	nop
	iwt r15,#lo16(_TPlatform1)
;	from	r0				; New Floor Height
	stw (!rSectorData)


;
;	* * * * * * *       STAIR RISING       * * * * * * *
;
_TStairRising:
	from !rTaskData	; Get FloorData
;	to	r0
	%add_i(rlpftFloor)
;	to	r0
	ldw (r0)
;	from	r0				; R4 = Pointer to SoundOrigin
	to r4
	%sub_i((rlpsHeight-rlpsOriginX))
	iwt r3,#lo16(sxStnMove-1)	; Sound Effect#
	link #3
	iwt r15,#lo16(_TPlatformSound2)
;
	from !rTaskData	; Get Destination Height
;	to	r0
	%add_i(rlpftHeight)
	to r2	; Maximum Floor Height
	ldw (r0)
;	with	r0
	%add_i((rlpftSectorData-rlpftHeight))
;	to	r0				; Get SectorData
	ldw (r0)
;	from	r0
	to !rSectorData
	%add_i(rlsdFloorHeight)
;
	ibt r6,#rlpsMovement	; Floor Adjustment
	from !rFPSRatio	; FPS Adjustment
;	to	r0
	lmult
;	with	r0				; Get Whole Levels Only
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0				; R1 = |FloorAdjustment|
	to r1
	or r4
;
	ldw (!rSectorData)	; Get Floor Height
;	from	r0				; R3 = NEW Floor Height
	to r3
	add r1
	from r3	; @CMP@
;	to	r0
	sub r2	; At Top?
	blt _TSR800	; No
	moves r3,r2	; Yes!
_TSR800:
	link #4
	iwt r15,#lo16(_RLCheckFloor)
	nop
	iwt r15,#lo16(_TPlatform1)
;	from	r0				; New Floor Height
	stw (!rSectorData)
