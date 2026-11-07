	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                         ENGINE SEGS MODULE 2                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildSegList2


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD SEGMENT LIST 2             ROTATE SEGMENTS' VERTEXES  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       ROTATE SEGMENTS' VERTEXES       * * * * * * *
;
	!rVBase = r2	; Pointer to ROM Vertexes Base
	!rViewY = r3	; View Y
	!rCos = r5	; CoSine Constant
;
	!rV1 = r7	; Pointer to Vertex 1
	!rV2 = r8	; Pointer to Vertex 2
	!rYTemp = r9	; Vertex Y Rotated
	!rAreaListPtr = r10	; Pointer within AreaList
	!rY1 = r11	; Vertex 1 Y
	!rY2 = r12	; Vertex 2 Y
	!rX = r13	; Vertex X


	%align_pad(6, 16, (_RLBuildSegList2-_BS2L2200)&$0F)	; align 16,(_RLBuildSegList2-_BS2L2200)&$0f
;
;	* * * * * * *       START ROTATING SEGMENTS' VERTEXES       * * * * * * *
;
_RLBuildSegList2:
	ibt r0,#bank(SinTable)	; Bank of SinTable
	romb
	lms !rVBase,(EMVERTEXES&$FFFF)	; Get Base Address of ROM Vertexes Table
	lms r0,(ViewAngle&$FFFF)	; Get ViewAngle
	lms !rViewY,(ViewY&$FFFF)	; View Y
	iwt r1,#lo16(SLAreaPtr)	; LAST VALID AREA'S NEXT POINTER
	sms (SLAreaPtrP&$FFFF),r1
;
;	>>>   GET ROTATIONAL SINE/COSINE CONSTANTS   <<<
;
	lsr
	lsr
	lsr
	lsr
	lsr	; >>5
	lsr	; Remove lowest bit
	add r0
	sms (SLAreaPtrV&$FFFF),r1
	iwt r1,#$200
	from r1
;	to	r0
	sub r0
	iwt r1,#$7FE
;	from	r0
	to r1
	and r1
	iwt r0,#lo16(SinTable)	; Add Base of SinTable
;	from	r0
	to r14
	add r1
	getb	; Get Sine from Table
	inc r14
	getbh
	sms (RLSin&$FFFF),r0
	iwt r0,#lo16(CosTable)	; Add Base of CosTable
;	from	r0
	to r14
	add r1
	getb	; Get CoSine from Table
	inc r14
;	from	r0
	to !rCos
	getbh
;
	ibt r0,#lo16(EMBSP+2)	; Bank of EM VERTEXES/SEGMENTS Data
	assert (lo16(EMBSP+2))&$FFFF < $80 || (lo16(EMBSP+2))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	ldb (r0)
	romb
;
	sms (RLCos&$FFFF),!rCos	; COSINE CONSTANT
;
	iwt r1,#lo16(SLAreaSegCount)	; AreaSegCount=0
;	with	r0
	sub r0
;	from	r0
	alt1
	bra _BS2L2000
;	stb	(r1)
	stw (r1)

;
;	* * * * * * *       FINISHED ROTATING SEGMENTS' VERTEXES       * * * * * * *
;
_BS2L9000:
	lms r1,(SLAreaPtrV&$FFFF)	; LastValidArea.Next = 0
;	with	r0
	sub r0
;	from	r0
	stw (r1)
;
	iwt r0,#lo16(_RLBuildSegList3)	; BUILD SEGMENT LIST 3
	ibt r8,#bank(_RLBuildSegList3)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	* * * * * * *       HANDLE NEXT AREA       * * * * * * *
;
_BS2L2000:
	%CACHEB(_RLBuildSegList2)
_BS2L2200:
	lms !rAreaListPtr,(SLAreaPtrP&$FFFF)	; Get Pointer to Current Area
	iwt r1,#lo16(SLAreaSegCount)	; Get AreaSegCount (then set it to 0)
;	to	r0
	ldb (r1)
	dec r0	; #ValidSegments = 0?
	bmi _BS2L2250	; Yes, Discard Area!
;	with	r0
	sub r0
;	from	r0
	stb (r1)
	lms r0,(SLAreaPtrV&$FFFF)	; LastValidArea = Current
	from !rAreaListPtr
	sbk
	from !rAreaListPtr	; LastValidArea.Next = Current
	stw (r0)
_BS2L2250:
;	to	r0
	ldw (!rAreaListPtr)	; Get Pointer to Next Area
	moves !rAreaListPtr,r0
	beq _BS2L9000	; No more Areas!
	with !rAreaListPtr
	%sub_i((rluSize-rlasSegs))
	sms (SLAreaPtrP&$FFFF),r0
;
;	* * * * * * *       HANDLE NEXT SEGMENT       * * * * * * *
;
_BS2L2300:
	with !rAreaListPtr	; Move to Next Segment
	%add_i(rluSize)
	to r14	; Get next Segment Address
	ldw (!rAreaListPtr)
_BS2L2320:
	move r0,r14
	dec r0	; $0001 END OF AREA
	beq _BS2L2200
;
;	>>>   GET VERTEX INFORMATION   <<<
;
	getb	; Get Address of VERTEX1
	inc r14
;	from	r0
	to !rV1
	getbh
	inc r14
;
	to !rY1	; Is Vertex1 Rotated Yet?
	ldw (!rV1)
;
	to !rV2
	getb	; Get Address of VERTEX2
	inc r14
	from !rY1
;	to	r0
	hib
;	with	r0
	sex
	ibt r1,#$80	; Vertex NOT Rotated Value
	with !rV2
	getbh
;
;	* * * * * * *       GET VERTEX 1       * * * * * * *
;
;	with	r0				; @CMP@
	sub r1
	bne _BS2L2500	; Yes!
;
;	>>>   GET UNROTATED VERTEX 1 AND TRANSLATE TO VIEW COORDINATE SYSTEM   <<<
;
;	>>>   ROTATE VERTEX1 BY (90DEGREES-VIEWANGLE)   <<<
;
;	ROTATED_Y = 	 sin(90deg.-ViewAngle) * (VertexX)
;			+cos(90deg.-ViewAngle) * (VertexY)
;
;	ROTATED_X = 	 cos(90deg.-ViewAngle) * (VertexX)
;			-sin(90deg.-ViewAngle) * (VertexY)
;
	from !rV1	; VERTEX 1
	to r14
	add !rVBase
;
	lms r0,(ViewX&$FFFF)	; ViewX
	to !rX
	getb	; Vertex 1 X
	inc r14
	lms r6,(RLSin&$FFFF)	; sin(90deg.-ViewAngle)
	with !rX
	getbh
	inc r14
	with !rX	; Vertex1X
	sub r0
;
	from !rX	; *Vertex X1
;	to	r0
	fmult
;	from	r0
	to !rY1
	rol
;
;	to	r0
	getb	; Vertex 1 Y
	inc r14
;	with	r0
	getbh
;	from	r0
	to !rYTemp	; Vertex1Y
	sub !rViewY
;
	from !rYTemp	; *Vertex Y1
;	to	r0
	fmult
;	from	r0
	to r1
	rol
;
	move r6,!rCos	; cos(90deg.-ViewAngle)
	from !rYTemp	; *Vertex Y1
;	to	r0
	fmult
;	with	r0
	rol
	with !rY1	; Rotated Y1
	add r0
	with !rY1	; Adjust Y1
	%sub_i(RLScreenPlane)
;
;	>>>   SAVE ROTATED VERTEX 1 Y   <<<
;
	from !rY1
	stw (!rV1)
	inc !rV1
	inc !rV1
;
	from !rX	; *Vertex X1
;	to	r0
	fmult
;	with	r0
	rol
;	with	r0				; Rotated X1
	sub r1
;
;	>>>   SAVE ROTATED VERTEX 1 X   <<<
;
;	from	r0
	stw (!rV1)
	dec !rV1
	dec !rV1

;
;	* * * * * * *       GET VERTEX 2       * * * * * * *
;
_BS2L2500:
	ibt r1,#$80	; Vertex NOT Rotated Value
	to !rY2	; Is Vertex2 Rotated Yet?
	ldw (!rV2)
	from !rY2
;	to	r0
	hib
;	with	r0
	sex
;	with	r0				; @CMP@
	sub r1
	bne _BS2L2700	; Yes!
;
;	>>>   GET UNROTATED VERTEX 2 AND TRANSLATE TO VIEW COORDINATE SYSTEM   <<<
;
;	>>>   ROTATE VERTEX2 BY (90DEGREES-VIEWANGLE)   <<<
;
;	ROTATED_Y = 	 sin(90deg.-ViewAngle) * (VertexX)
;			+cos(90deg.-ViewAngle) * (VertexY)
;
;	ROTATED_X = 	 cos(90deg.-ViewAngle) * (VertexX)
;			-sin(90deg.-ViewAngle) * (VertexY)
;
	from !rV2	; VERTEX 2
	to r14
	add !rVBase
;
	lms r0,(ViewX&$FFFF)	; ViewX
	to !rX
	getb	; Vertex 2 X
	inc r14
	lms r6,(RLSin&$FFFF)	; sin(90deg.-ViewAngle)
	with !rX
	getbh
	inc r14
	with !rX	; Vertex2X
	sub r0
;
	from !rX	; *Vertex X2
;	to	r0
	fmult
;	from	r0
	to !rY2
	rol
;
;	to	r0
	getb	; Vertex 2 Y
	inc r14
;	with	r0
	getbh
;	from	r0				; Vertex2Y
	to !rYTemp
	sub !rViewY
;
	from !rYTemp	; *Vertex Y2
;	to	r0
	fmult
;	from	r0
	to r1
	rol
;
	move r6,!rCos	; cos(90deg.-ViewAngle)
	from !rYTemp	; *Vertex Y2
;	to	r0
	fmult
;	with	r0
	rol
	with !rY2	; Rotated Y2
	add r0
	with !rY2	; Adjust Y2
	%sub_i(RLScreenPlane)
;
;	>>>   SAVE ROTATED VERTEX 2 Y   <<<
;
	from !rY2
	stw (!rV2)
	inc !rV2
	inc !rV2
;
	from !rX	; *Vertex X2
;	to	r0
	fmult
;	with	r0
	rol
;	with	r0				; Rotated X2
	sub r1
;
;	>>>   SAVE ROTATED VERTEX 2 X   <<<
;
;	from	r0
	stw (!rV2)
	dec !rV2
	dec !rV2

;
;	>>>   IF BOTH ROTATED_Y1/Y2 < SCREEN_PLANE, DISCARD SEGMENT   <<<
;
_BS2L2700:
	from !rY1	; Both Behind Screen_Plane?
;	to	r0
	and !rY2
	bpl _BS2L3000	; No!
;	with	r0
	sub r0	; Yes!  Discard this SEGMENT!
	move r1,!rAreaListPtr
	with !rAreaListPtr	; Move to Next Segment
	%add_i(rluSize)
	to r14
	ldw (!rAreaListPtr)	; Get next Segment Address
;	from	r0
	stw (r1)	; Change to SKIP SEGMENT
	iwt r15,#lo16(_BS2L2320)+1
	with r14

;
;	* * * * * * *       POTENTIAL BSP SEGMENT!       * * * * * * *
;
_BS2L3000:
	iwt r1,#lo16(SLAreaSegCount)	; AreaSegCount++
;	to	r0
	ldb (r1)
	inc r0
;	from	r0
	stb (r1)
	from !rAreaListPtr	; Move to V1
;	to	r0
	%add_i(rluV1)
	with !rAreaListPtr	; Move to Next Segment
	%add_i(rluSize)
	to r14	; Get next Segment Address
	ldw (!rAreaListPtr)
	from !rV1	; Save V1
	stw (r0)
	inc r0
	inc r0
	from !rV2	; Save V2
	stw (r0)
	iwt r15,#lo16(_BS2L2320)+1
	with r14


	%CACHEE(_RLBuildSegList2)
