	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                        ENGINE VSEGS MODULE 2                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildVSegList2


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD VSEGMENT LIST 2        CALC VSEGMENTS' FLAGS/HEIGHTS  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       CALCULATE VSEGMENTS' FLAGS/HEIGHTS       * * * * * * *
;
	!rFloorNearHeight = r3	; Height of Floor.SectorNear
	!rFloorFarHeight = r4	; Height of Floor.SectorFar
	!rCeilingNearHeight = r5	; Height of Ceiling.SectorNear
	!rCeilingFarHeight = r6	; Height of Ceiling.SectorFar
;
	!rEyeZ = r7	; Height of Eye
	!rSectorNearData = r8	; Pointer to SectorNearData
	!rSectorFarData = !rSectorNearData	; Pointer to SectorFarData
	!rTemp = !rSectorNearData	; Temporary Variable
	!rSegFlags = r11	; Segment Flags
	!rVSegFlags = r12	; VisibleSegment Flags
	!rVSeg = r10	; Pointer within VisibleSegment
	!rVSeg0 = r14	; Base of VisibleSegment
	!rVSegEnd = r13	; Pointer to End of VisibleSegmentList


	%align_pad(13, 16, (_BV2L9000-_BV2L2200)&$0F)	; align 16,(_BV2L9000-_BV2L2200)&$0f

;
;	* * * * * * *       FINISHED VSEGMENTS' FLAGS/HEIGHTS       * * * * * * *
;
_BV2L9000:
	iwt r0,#lo16(_RLBuildVSegList3)	; BUILD VISIBLE SEGMENT LIST 3
	ibt r8,#bank(_RLBuildVSegList3)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop
;
;	* * * * * * *       START CALCULATING VSEGMENTS' FLAGS/HEIGHTS       * * * * * * *
;
_RLBuildVSegList2:
	iwt !rVSeg,#lo16(_RLVSegList-(rlvSize-rlvFlags))	; START of VisibleSegmentList
	lms !rVSegEnd,(VSegListEnd&$FFFF)	; END of VisibleSegmentList
	with !rVSegEnd
	%add_i(rlvSegFlags)
;
	lms !rEyeZ,(ViewZ&$FFFF)	; Get View Z Coordinate
;
	%CACHEB(_RLBuildVSegList2)
;
;	* * * * * * *       HANDLE NEXT VISIBLE SEGMENT       * * * * * * *
;
_BV2L2200:
	ibt r0,#(rlvSize-rlvFlags+rlvSegFlags)	; Offset to Next VSEG
	with !rVSeg	; Move to Next VSEG
	add r0
	from !rVSeg	; At END of VisibleSegmentList?
;	to	r0				; @CMP@
	sub !rVSegEnd
	beq _BV2L9000	; Yes!  No More VisibleSegments!

;
;	* * * * * * *       PROCESS NEXT VISIBLE SEGMENT       * * * * * * *
;
_BV2L3000:
;
;	>>>   GET SEGMENTFLAGS   <<<
;
	to !rSegFlags	; Get SegmentFlagsLow
	ldb (!rVSeg)
;
;	>>>   GET SECTORNEAR_DATA   <<<
;
	ibt r0,#(rlvSectorNearData-rlvSegFlags)
	with !rVSeg
	add r0
	to !rSectorNearData	; Get SectorNearData
	ldw (!rVSeg)
	inc !rVSeg	; Move to SectorFarData
	inc !rVSeg

;
;	* * * * * * *       SOLID WALL       * * * * * * *
;
_BV2L10000:
	inc !rSectorNearData	; Move to FloorHeight
	from !rSegFlags	; SOLID?
	to r2
	lsr
	bcc _BV2L20000	; No
	inc !rSectorNearData	; Move to FloorHeight
;
;	>>>   GET FLOORNEAR_HEIGHT   <<<
;
;	to	r0
	ldw (!rSectorNearData)
;	from	r0				; Adjust FloorHeight to Eye
	to !rFloorNearHeight
	sub !rEyeZ
;
;	>>>   GET CEILINGNEAR_HEIGHT   <<<
;
	inc !rSectorNearData	; Move to CeilingHeight
	inc !rSectorNearData
	to !rCeilingNearHeight
	ldw (!rSectorNearData)
;
;	>>>   ADD SOLID WALL   <<<
;
	inc !rVSeg	; Move to NormalWallBottom(Floor)Height
	inc !rVSeg
	from !rFloorNearHeight
	stw (!rVSeg)
	inc !rVSeg	; Move to NormalWallTop(Ceiling)Height
	inc !rVSeg
	with !rCeilingNearHeight	; Adjust CeilingHeight to Eye
	sub !rEyeZ
	ibt r1,#(rlvCeilingHeight-rlvFlags)	; Move to VFlags
	from !rCeilingNearHeight
	stw (!rVSeg)
	with !rVSeg	; Move to VFlags
	sub r1
;
	ibt r1,#(rlgfNORMALPEGGED|rlgfALTTEXTURE)	; PEGGED/ALTTEXTURE?
	with !rSegFlags
	and r1
	with !rSegFlags
	swap
_BV2L15000:
	iwt r0,#(rlvfWALL|rlvfNORMALWALL|rlvfNORMALSPRCLIP)
	with r2	; SKY?
	lsr
	bcs _BV2L15500
	moves r1,!rCeilingNearHeight	; CEILING VISIBLE?
	bmi _BV2L16000	; NO
	nop
_BV2L15500:
	ibt r1,#rlvfADDCEILING
;	with	r0
	or r1
_BV2L16000:
	moves r1,!rFloorNearHeight	; FLOOR VISIBLE?
	bpl _BV2L18000	; NO
	nop
	ibt r1,#rlvfADDFLOOR
;	with	r0
	or r1
_BV2L18000:
;	with	r0
	add !rSegFlags
;	from	r0
	bra _BV2L2200	; Process Next VisibleSegment
	stw (!rVSeg)

;
;	* * * * * * *       TRANSPARENT WALL       * * * * * * *
;
_BV2L20000:
;
;	>>>   GET FLOORNEAR_HEIGHT   <<<
;
;	to	r0
	ldw (!rSectorNearData)
;	from	r0
	to !rFloorNearHeight
	sub !rEyeZ
;
;	>>>   GET CEILINGNEAR_HEIGHT   <<<
;
	inc !rSectorNearData	; Move to CeilingHeight
	inc !rSectorNearData
	to !rCeilingNearHeight
	ldw (!rSectorNearData)
;
;	>>>   GET SECTORFAR_DATA   <<<
;
	to !rSectorFarData
	ldw (!rVSeg)
;
;	>>>   GET FLOORFAR_HEIGHT   <<<
;
	inc !rSectorFarData	; Move to FloorHeight
	inc !rSectorFarData
;	to	r0
	ldw (!rSectorFarData)
;	from	r0
	to !rFloorFarHeight
	sub !rEyeZ
;
;	>>>   GET CEILINGFAR_HEIGHT   <<<
;
	inc !rSectorFarData	; Move to CeilingHeight
	inc !rSectorFarData
;	to	r0
	ldw (!rSectorFarData)
;
;	>>>   SAVE FLOOR_HEIGHT   <<<
;
	inc !rVSeg	; Move to NormalWallBottom(Floor)Height
	inc !rVSeg
	from !rFloorNearHeight
	stw (!rVSeg)
;
;	>>>   GET CEILINGFAR_HEIGHT   <<<
;
;	from	r0				; Adjust CeilingFarHeight to Eye
	to !rCeilingFarHeight
	sub !rEyeZ
;
;	>>>   SAVE CEILING_HEIGHT   <<<
;
	inc !rVSeg	; Move to NormalWallTop(Ceiling)Height
	inc !rVSeg
	with !rCeilingNearHeight	; Adjust CeilingHeight to Eye
	sub !rEyeZ
	from !rCeilingNearHeight
	stw (!rVSeg)
	inc !rVSeg	; Move to Upper Wall Bottom
	inc !rVSeg

;
;	* * * * * * *       UPPER WALL       * * * * * * *
;
_BV2L40000:
	ibt r0,#(rlgfLOWERPEGGED|rlgfUPPERPEGGED|rlgfALTTEXTURE|(rlgfClear*!RLMASKED))	; PEGGED/ALTTEXTURE/MASKED?
;	with	r0
	and !rSegFlags
;	from	r0
	to !rVSegFlags
	swap
;
;	* * * * * * *       SKY       * * * * * * *
;
	with r2	; SKY?
	lsr
	bcs _BV2L50000	; Yes
;
	from !rCeilingNearHeight	; CeilingNearHeight >= CeilingFarHeight?
;	to	r0				; @CMP@
	sub !rCeilingFarHeight
	blt _BV2L42000	; NO UPPER!
	ibt r1,#0	; New Flags to Add
	beq _BV2L45000+1	; SAME HEIGHT?
	with r0
;
;	>>>   ADD UPPER WALL   <<<
;
	iwt r1,#(rlvfWALL|rlvfUPPERWALL|rlvfUPPERSPRCLIP|rlvfADDCEILING)
;
	from !rCeilingFarHeight	; CeilingFar >= FloorNear?
;	to	r0				; @CMP@
	sub !rFloorNearHeight	; (Door Closes to Lower Floor)
	bge _BV2L41000	; Yes, FarCeiling is above NearFloor
	from !rCeilingFarHeight	; Height of Bottom of UpperWall
	from !rFloorNearHeight	; Height of Bottom of UpperWall
_BV2L41000:
	bra _BV2L48000
	stw (!rVSeg)
;
;	>>>   ADD UPPER CLIP   <<<
;
_BV2L42000:
;	move	r1,#((rlvfUPPERCLIP|rlvfUPPERSPRCLIP)>>8)
	db ((rlvfUPPERCLIP|rlvfUPPERSPRCLIP)>>8)
	with r1
	swap
;	from	rCeilingNearHeight		; Height of Bottom of UpperWall
;	stw	(rVSeg)

;
;	* * * * * * *       CEILING       * * * * * * *
;
_BV2L45000:
	moves r0,!rCeilingNearHeight	; CEILING VISIBLE?
	bmi _BV2L48000	; NO
	nop
;
;	>>>   ADD CEILING   <<<
;
	iwt !rTemp,#(rlvfADDCEILING|rlvfUPPERCLIP)	; ADD CEILING
	with r1
	or !rTemp
;
;	>>>   UPDATE VISIBLE SEGMENT FLAGS   <<<
;
_BV2L48000:
	with !rVSegFlags	; Add Additional VisibleSegmentFlags
	or r1

;
;	* * * * * * *       LOWER WALL       * * * * * * *
;
_BV2L50000:
	inc !rVSeg	; Move to Lower Wall Top
	inc !rVSeg
	from !rFloorFarHeight	; FloorFarHeight >= FloorNearHeight?
;	to	r0				; @CMP@
	sub !rFloorNearHeight
	blt _BV2L52000	; NO LOWER!
	ibt r1,#0	; New Flags to Add
	beq _BV2L55000+1	; SAME HEIGHT?
	with r0
;
;	>>>   ADD LOWER WALL   <<<
;
	iwt r1,#(rlvfWALL|rlvfLOWERWALL|rlvfLOWERSPRCLIP)
	from !rFloorFarHeight	; Height of Top of BottomWall
	bra _BV2L55000
	stw (!rVSeg)
;
;	>>>   ADD LOWER CLIP   <<<
;
_BV2L52000:
;	move	r1,#(rlvfLOWERCLIP|rlvfLOWERSPRCLIP)
	db rlvfLOWERCLIP|rlvfLOWERSPRCLIP
	with r1
	lob
;	from	rFloorNearHeight		; Height of Top of BottomWall
;	stw	(rVSeg)

;
;	* * * * * * *       FLOOR       * * * * * * *
;
_BV2L55000:
	moves r0,!rFloorNearHeight	; FLOOR VISIBLE?
	bpl _BV2L60000	; NO
	nop
;
;	>>>   ADD FLOOR   <<<
;
	iwt !rTemp,#(rlvfADDFLOOR|rlvfLOWERCLIP)	; ADD FLOOR
	with r1
	or !rTemp

;
;	* * * * * * *       UPDATE VISIBLE SEGMENT FLAGS       * * * * * * *
;
_BV2L60000:
	from !rVSegFlags	; Add Additional VisibleSegmentFlags
;	to	r0
	or r1
;
	ibt r1,#(rlvLowerWallTopHeight-rlvFlags)
	with !rVSeg	; Move to VFlags
	sub r1
;
;	from	r0				; Save VFlags
	iwt r15,#lo16(_BV2L2200)	; Process Next VisibleSegment
	stw (!rVSeg)

	%CACHEE(_RLBuildVSegList2)
