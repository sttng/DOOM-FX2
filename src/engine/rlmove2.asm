	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       OBJECT MOVEMENT MODULE 2                     *
;*                                                                    *
;*                     OBJECT <-> LINE COLLISIONS 1                   *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


	!rFlags = r3	; Line Flags
	!rAngle = r4	; Line Angle
	!rFace = r5	; Line Face
	!rHighFloor = !rAngle	; Highest Floor Height
	!rLowCeiling = !rFace	; Lowest Ceiling Height
	!rBSPB = r7	; Bank of BSP/VERTEXES/LINES/FACES
	!rMoveLinesPtr = r8	; Pointer to MoveLines List
	!rLineBase = r9	; Base of LINES
	!rVertexBase = r10	; Base of VERTEXES
	!rFaceBase = r12	; Base of FACES
	!rRLCount = r13	; RLEngine Count


;
;	* * * * * * *       REALITY_ENGINE MOVE RLOBJECT XY       * * * * * * *
;
	%align_pad(14, 16, (_RM2XY10000-_RM2XY2000)&$0F)	; align 16,(_RM2XY10000-_RM2XY2000)&$0f
;
;	>>>   FINISHED SCANNING MOVELINES   <<<
;
_RM2XY10000:
	lms r1,(MVSector&$FFFF)	; Terminate MoveSectorsList
	ibt r0,#$80
;	from	r0
	stw (r1)
;
	iwt r0,#lo16(_RLMoveXY3)	; MOVE RLOBJECT XY 3
	ibt r13,#bank(_RLMoveXY3)
	ljmp r13
	nop

;
;	>>>   START SCANNING MOVELINES   <<<
;
_RLMoveXY2:
;
;	>>>   ALWAYS PROCESS CURRENT SECTOR FOR OBJECTS   <<<
;
	lms r1,(MVRObj&$FFFF)	; Get RLObject Pointer
;
	lms !rRLCount,(RLCount&$FFFF)	; RLEngineCount++
	inc !rRLCount
	from !rRLCount
	sbk
;
	ibt r0,#rloSector	; Get RLObject.Sector
;	with	r0
	add r1
;	to	r0
	ldb (r0)
;	with	r0				; Get SectorData
	%umult_i(rlsdSize)
	iwt r1,#lo16(_RLSectorData+rlsdRLCount)
;	with	r0
	add r1
	from !rRLCount	; SectorData.RLEngineCount=RLEngineCount
	stw (r0)
;	with	r0				; Move to SectorData.FloorHeight
	%sub_i((rlsdRLCount-rlsdFloorHeight))
;
	iwt r1,#lo16(_RLMoveSectors)	; START OF MOVESECTORS LIST
;	from	r0				; Save Pointer to SectorData.FloorHeight
	stw (r1)
	inc r1
	inc r1
	sms (MVSector&$FFFF),r1
;
	iwt !rMoveLinesPtr,#lo16(_RLMoveLines)	; START OF MOVELINES LIST
	lms !rLineBase,(EMLINES&$FFFF)	; Base Address of LINES
	with !rLineBase
	%sub_i(rllSize)
	lms !rVertexBase,(EMVERTEXES&$FFFF)	; Base Address of VERTEXES
	lms !rFaceBase,(EMFACES&$FFFF)	; Base Address of FACES
	ibt r6,#rllSize
	ibt r0,#lo16(EMBSP+2)	; Bank of EM Data
	assert (lo16(EMBSP+2))&$FFFF < $80 || (lo16(EMBSP+2))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	to !rBSPB
	ldb (r0)
	iwt r1,#lo16(MVULCount)	; #Lines Matching Trigger
;	with	r0
	sub r0
;	from	r0
	stb (r1)


	%CACHEB(_RLMoveXY2)
;
;	>>>   CHECK NEXT MOVELINE   <<<
;
_RM2XY2000:
	to r2	; Get Next Line#
	ldw (!rMoveLinesPtr)
	inc r2
	beq _RM2XY10000	; No more Lines!
;
;	>>>   MOVE TO LINE   <<<
;
	from !rBSPB	; Bank of EM Data (VERTEXES/FACES are in ROM)
	romb
	from r2	; Move to LineData
;	to	r0
	lmult
	from r4	; R0 = Line (level RAM $71)
	add !rLineBase
	%RAMB71(r1)
	to r1	; R1 = Vertex 1
	ldw (r0)
	inc r0
	inc r0
	to r2	; R2 = Vertex 2
	ldw (r0)
	inc r0
	inc r0
	to !rFlags	; Get Flags
	ldw (r0)
	inc r0
	inc r0
	to !rAngle	; Get Angle
	ldw (r0)
	inc r0
	inc r0
	to !rFace	; Get Face
	ldw (r0)
	from r6	; R6 = rllSize (even): back to GSU RAM $70
	ramb
	with r1
	add !rVertexBase
	with r2
	add !rVertexBase
;
;	>>>   FLAGS   <<<
;
	with !rMoveLinesPtr	; Move to Flags
	%add_i(rlmlFlags)
	from !rFlags
	stw (!rMoveLinesPtr)
	inc !rMoveLinesPtr
;
;	>>>   ANGLE   <<<
;
	with !rAngle	; Line Angle
	lsr
	with !rAngle
	lsr
	with !rAngle
	lsr
	with !rAngle
	lsr
	with !rAngle
	lsr	; >>5
	with !rAngle
	bic #1	; Remove lowest bit
;
;	>>>   GET VERTEX 1 COORDINATES   <<<
;
	move r14,r1	; Get Vertex1 X
	with !rMoveLinesPtr
	%sub_i(((rlmlFlags+1)-rlmlLX1))
	getb
	inc r14
;	from	r0
	stb (!rMoveLinesPtr)
	inc !rMoveLinesPtr
	getb
	inc r14
;	from	r0
	stb (!rMoveLinesPtr)
	inc !rMoveLinesPtr
	getb	; Get Vertex1 Y
	inc r14
;	from	r0
	stb (!rMoveLinesPtr)
	inc !rMoveLinesPtr
	getb
	move r14,r2
;	from	r0
	stb (!rMoveLinesPtr)
	with !rMoveLinesPtr
	%add_i((rlmlLX2-(rlmlLY1+1)))
;
;	>>>   GET VERTEX 2 COORDINATES   <<<
;
	getb	; Get Vertex2 X
	inc r14
;	from	r0
	stb (!rMoveLinesPtr)
	inc !rMoveLinesPtr
	getb
	inc r14
;	from	r0
	stb (!rMoveLinesPtr)
	inc !rMoveLinesPtr
	getb	; Get Vertex2 Y
	inc r14
;	from	r0
	stb (!rMoveLinesPtr)
	inc !rMoveLinesPtr
	iwt r2,#lo16(SinTable)	; Base Address of Sine Table
	ibt r1,#bank(SinTable)
	getb
;
;	>>>   GET LINE PERPENDICULAR COMPONENTS   <<<
;
	from r1	; Bank of Sin/Cos Data
	romb
	from !rAngle	; Perpendicular UnitVector X
	to r14
	add r2
;
;	from	r0				; Vertex2 Y
	stb (!rMoveLinesPtr)
	with !rMoveLinesPtr
	%sub_i(((rlmlLY2+1)-rlmlPUX))
	iwt r2,#lo16(CosTable)	; Base Address of CoSine Table
;
	getb	; Perpendicular UnitVector X
	inc r14
;	from	r0
	stb (!rMoveLinesPtr)
	inc !rMoveLinesPtr
	getb
;
	from !rAngle	; Perpendicular UnitVector Y
	to r14
	add r2
;
;	from	r0				; Perpendicular UnitVector X
	stb (!rMoveLinesPtr)
	inc !rMoveLinesPtr
;
	getb	; Perpendicular UnitVector Y
	inc r14
;	from	r0
	stb (!rMoveLinesPtr)
	inc !rMoveLinesPtr
;
	from !rBSPB	; Move to Line Face
	romb
;
	getb
;
	from !rFace	; Move to Line Face
	to r14
	add !rFaceBase
;
;	from	r0				; Perpendicular UnitVector Y
	stb (!rMoveLinesPtr)

;
;	>>>   SOLID?   <<<
;
	from !rFlags	; Solid Wall?
;	to	r0
	lsr	; C = rllfSolid (bit 0)
	bcs _RM2XY9000	; YES, AUTOMATIC BLOCKING!

;
;	* * * * * * *       TRANSPARENT       * * * * * * *
;
;	>>>   UPDATE TRIGGER LINE COUNT   <<<
;
	with !rMoveLinesPtr
	%add_i((rlmlHighFloorHeight-(rlmlPUY+1)))
;
	iwt r0,#lo16(MVULMask)	; LineFlags Type Mask
	to r1
	ldb (r0)
;
	with !rFlags	; Trigger Line?
	swap
	with !rFlags
	and r1
	iwt r2,#lo16(MVULCount)	; #Lines Matching Trigger Flags
	dec !rFlags	; New Trigger Line?
	to r1	; Get #TriggerLines
	alt1
	bmi _RM2XY6200	; No
	ldw (r2)	; (with the ALT1 above: ldb (r2))
	inc r1	; #TriggerLines++
_RM2XY6200:
	from r1	; Update #TriggerLines
	stb (r2)
;
;	>>>   GET NEAR SECTORDATA   <<<
;
	getb	; Get Near Sector
	link #3
	bra _RLMoveXYAddMSector	; Add Sector to MoveSectors
	inc r14
;
;	>>>   GET NEAR FLOOR/CEILING HEIGHT   <<<
;
	to !rHighFloor	; Near Floor Height
	ldw (r2)
	inc r2
	inc r2
	to !rLowCeiling	; Near Ceiling Height
	ldw (r2)
	from !rHighFloor	; Highest Floor Height
	stw (!rMoveLinesPtr)

;
;	>>>   GET FAR SECTORDATA   <<<
;
	link #3
	bra _RLMoveXYAddMSector	; Add Sector to MoveSectors
	getb
;
;	>>>   GET FAR FLOOR/CEILING HEIGHT   <<<
;
;	to	r0				; Far Floor Height
	ldw (r2)
	inc r2
	inc r2
	to r1	; Far Ceiling Height
	ldw (r2)
;
;	>>>   GET HIGHEST FLOOR   <<<
;
;	from	r0				; FarFloor > NearFloor?
	cmp !rHighFloor
	blt _RM2XY8200	; No -- Cliff!
	nop
;	from	r0				; Yes!
	stw (!rMoveLinesPtr)
	move r0,!rHighFloor
;
;	>>>   GET LOWEST CEILING   <<<
;
_RM2XY8200:
	from r1	; FarCeiling < NearCeiling?
	cmp !rLowCeiling
	bge _RM2XY8400	; No
	move !rLowCeiling,r1	; Yes!
;
;	>>>   HIGHEST FLOOR   <<<
;
_RM2XY8400:
	inc !rMoveLinesPtr
	inc !rMoveLinesPtr
;
;	>>>   LOWEST CEILING   <<<
;
	from !rLowCeiling	; Lowest Ceiling Height
	stw (!rMoveLinesPtr)
	inc !rMoveLinesPtr
	inc !rMoveLinesPtr
;
;	>>>   LOWEST FLOOR   <<<
;
;	from	r0				; Lowest Floor Height
	stw (!rMoveLinesPtr)
	inc !rMoveLinesPtr
;
;	>>>   PROCESS NEXT LINE   <<<
;
	iwt r15,#lo16(_RM2XY2000)
	inc !rMoveLinesPtr


;
;	* * * * * * *       ADD SECTOR TO MOVESECTORS       * * * * * * *
;
;	R0 = Sector#
;
;	R2 = SectorData.FloorHeight
;
_RLMoveXYAddMSector:
;
;	>>>   GET SECTORDATA   <<<
;
;	with	r0				; Get SectorData
	%umult_i(rlsdSize)
	iwt r2,#lo16(_RLSectorData+rlsdRLCount)
	with r2
	add r0
;
;	>>>   SECTOR ALREADY TAGGED FOR OBJECT PROCESSING?   <<<
;
;	to	r0				; Get SectorData.RLEngineCount
	ldw (r2)
;
	with r2	; Move to SectorData.FloorHeight
	%sub_i((rlsdRLCount-rlsdFloorHeight))
;
;	with	r0				; Already Handled?
	sub !rRLCount
	beq _RMXYAMS800	; Yes!
;
;	>>>   ADD SECTOR TO MOVEMENT SECTOR LIST   <<<
;
	from !rRLCount	; SectorData.RLEngineCount=RLEngineCount
	sbk
	iwt r1,#lo16(MVSector)	; Pointer to MoveSectorsList
;	to	r0
	ldw (r1)
	from r2	; Save Pointer to SectorData.FloorHeight
	stw (r0)
	inc r0
	inc r0
;	from	r0				; Save Pointer to MoveSectorsList
	stw (r1)
_RMXYAMS800:
	jmp r11	; (the LINK #3 below runs in the delay slot)


;
;	* * * * * * *       SOLID       * * * * * * *
;
_RM2XY9000:
;
;	>>>   GET NEAR SECTORDATA   <<<
;
	link #3
	bra _RLMoveXYAddMSector	; Add Sector to MoveSectors
	getb
;
;	>>>   PROCESS NEXT LINE   <<<
;
	with !rMoveLinesPtr	; Move to Next MoveLine Entry
	%add_i((rlmlSize-(rlmlPUY+1)))
	iwt r15,#lo16(_RM2XY2000)
	to r2	; Get Next Line#


	%CACHEE(_RLMoveXY2)
