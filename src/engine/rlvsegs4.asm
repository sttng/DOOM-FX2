	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                        ENGINE VSEGS MODULE 4                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildVSegList4


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD VSEGMENT LIST 4      CALCULATE VSEGMENTS' TEXTURES 2  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       CALCULATE VSEGMENTS' TEXTURES 2       * * * * * * *
;
	!rVAngle = r9	; Vertex Angle
	!rVSeg = r10	; Pointer to VisibleSegment Flags
	!rVSegP = r11	; Pointer within VisibleSegment
	!rVSegEnd = r12	; Pointer to End of VisibleSegmentList
	!rVDistance = r13	; Distance to Vertex


	%align_pad(12, 16, (_BV4L9000-_BV4L2200)&$0F)	; align 16,(_BV4L9000-_BV4L2200)&$0f
;
;	* * * * * * *       FINISHED CALCULATING VSEGMENTS' TEXTURES 2       * * * * * * *
;
_BV4L9000:
	if !RLMASKED
	iwt r15,#lo16(_RLBuildMaskList)	; BUILD MASKED MIDDLE TEXTURE LIST
	nop
_BML9900:
	endif
	iwt r0,#lo16(_RLBuildVObjList1)	; BUILD VISIBLE OBJECT LIST
	ibt r8,#bank(_RLBuildVObjList1)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	* * * * * * *       START CALCULATING VSEGMENTS' TEXTURES 2       * * * * * * *
;
_RLBuildVSegList4:
	iwt !rVSeg,#lo16(_RLVSegList-rlvSize+rlvFlags)	; START of VisibleSegmentList
	lms !rVSegEnd,(VSegListEnd&$FFFF)	; END of VisibleSegmentList
	with !rVSegEnd
	%add_i(rlvFlags)
;
	ibt r0,#bank(SinTable)	; Bank of CosTable
	romb
;
	%CACHEB(_RLBuildVSegList4)
;
;	* * * * * * *       HANDLE NEXT VISIBLE SEGMENT       * * * * * * *
;
_BV4L2200:
	ibt r1,#rlvSize	; Offset to Next VSEG
_BV4L2400:
	with !rVSeg	; Move to Next VSEG
	add r1
	from !rVSeg	; At END of VisibleSegmentList?
;	to	r0				; @CMP@
	sub !rVSegEnd
	beq _BV4L9000	; Yes!  No More VisibleSegments!

;
;	* * * * * * *       PROCESS NEXT VISIBLE SEGMENT       * * * * * * *
;
;	>>>   GET VISIBLESEGMENT FLAGS   <<<
;
;	to	r0				; Get VisibleSegmentFlags
	ldw (!rVSeg)
	if !RLMASKED
	iwt r2,#(rlvfWALL|rlvfMASKED)	; DOING WALL/MASKED MIDDLE TEXTURE?
	and r2
	else
	inc r0	; DOING WALL?
	endif
	if !RLMASKED
	beq _BV4L2400+1	; No!
	else
	bpl _BV4L2400+1	; No!
	endif
	with !rVSeg	; Move to Next VSEG
;
;	>>>   CALCULATE ANGLE TO VERTEX 1   <<<
;
	ibt r0,#(rlvVertex1-rlvFlags)	; Get Vertex1
;	with	r0
	add !rVSeg
;	to	r0
	ldw (r0)
	to r8	; Get Vertex1 Y
	ldw (r0)
	inc r0
	inc r0
	to r7	; Get Vertex1 X
	ldw (r0)
	link #3
	iwt r15,#lo16(_RLGetAngle)
;
;	>>>   CALCULATE VERTEX DISTANCE   <<<
;
	moves !rVAngle,r0	; VERTEX ANGLE
	bpl _BV4L4200	; Octant 4/5/6/7?
	nop
;	with	r0				; Convert to Octant 0/1/2/3
	not
	inc r0
_BV4L4200:
	iwt r1,#$4000	; r1 = 90 degrees
;	from	r0				; Octant 2/3?
	cmp r1
	from r1	; r2 = 45 degrees
	to r2
	blt _BV4L4400
	lsr
	iwt r4,#$8000	; Convert to Octant 0/1
	from r4
;	to	r0
	sub r0
_BV4L4400:
;	from	r0				; Octant 0 or 1?
	cmp r2
	blt _BV4L4600
	with r7	; Octant 0 (0/3/4/7)
	nop
	from r1	; Octant 1 (1/2/5/6)
;	to	r0				; (Convert to Octant 0)
	sub r0
	with r8
_BV4L4600:
	to r6
;	from	r0				; VertexAngle
	lsr
	lsr
	lsr
	lsr
	lsr	; >>5
	lsr	; Remove lowest bit
;	from	r0
	to r1
	add r0
	iwt r0,#lo16(SecTable)
;	from	r0
	to r14
	add r1
	with r6	; Get |Delta|
	add r6
	bpl _BV4L4800
	nop
	with r6
	not
	inc r6
_BV4L4800:
	getb
	inc r14
	getbh
;	with	r0				; Get Fraction portion of Secant
	fmult
;	from	r0				; VERTEX DISTANCE = 1.0 + SEC(VertexAngle)
	to !rVDistance
	add r6
;
;	>>>   CALCULATE ROTATED SEGMENT ANGLE   <<<
;
	ibt r0,#(rlvVertex2-rlvFlags)	; Get Vertex2
;	with	r0
	add !rVSeg
;	to	r0
	ldw (r0)
	to r1	; R1 = Vertex2 Y
	ldw (r0)
	inc r0
	inc r0
;	to	r0				; R0 = Vertex2 X
	ldw (r0)
	from r1	; DeltaY = (V2Y - V1Y)
	to r8
	sub r8
;	from	r0				; DeltaX = (V2X - V1X)
	to r7
	sub r7
	link #4
	iwt r15,#lo16(_RLGetAngle)
	nop
	ibt !rVSegP,#(rlvRSAngle-rlvFlags)	; ROTATED SEGMENT ANGLE
	with !rVSegP
	add !rVSeg
;	from	r0
	stw (!rVSegP)
	inc !rVSegP
	inc !rVSegP
;
;	>>>   CALCULATE VERTEX ANGLE OFFSET   <<<
;
	from !rVAngle	; VERTEXANGLEOFFSET = (VAngle-RSNAngle)
;	to	r0
	sub r0
	iwt r1,#$4000
;	with	r0
	sub r1
;
;	>>>   CALCULATE ROTATED SEGMENT PERPENDICULAR DISTANCE/VERTEX TEXTURE OFFSET   <<<
;
;	from	r0				; VertexAngleOffset
	lsr
	lsr
	lsr
	lsr
	lsr	; >>5
	lsr	; Remove lowest bit
;	from	r0
	to r4
	add r0
	iwt r0,#lo16(CosTable)
;	from	r0
	to r14
	add r4
	iwt r1,#lo16(SinTable)
	move r6,!rVDistance	; Vertex Distance
	getb
	inc r14
	getbh
	from r1
	to r14
	add r4
;
;	with	r0				; RSPDistance = VDistance*Cos(VAngleOffset)
	fmult
;	from	r0
	to r1
	rol
	from r1	; ROTATED SEGMENT PERPENDICULAR DISTANCE
	stw (!rVSegP)
;
	getb
	inc r14
;
	inc !rVSegP
	inc !rVSegP
;
	getbh
;	with	r0				; VertexTextureOffset = VD*Sin(VAngleOffset)
	fmult
;
	iwt r15,#lo16(_BV4L2200)	; Next VisibleSegment
;	from	r0				; VERTEX TEXTUREOFFSET
	stw (!rVSegP)


;
;	* * * * * * *       GET ANGLE       * * * * * * *
;
;	rDeltaX	= DeltaX
;	rDeltaY	= DeltaY
;
;	r0	= Angle
;
	!rX = r2	; |DeltaX|
	!rY = r3	; |DeltaY|
	!rSwap = r5	; 0=DeltaX/DeltaY NOT Swapped
;
	!rDeltaX = r7	; DeltaX
	!rDeltaY = r8	; DeltaY

;
;	>>>   DELTA X = 0   <<<
;
_RGAE700:
	moves !rDeltaY,!rDeltaY	; Always 90 or 270 degrees
	bpl _RGAE750
	iwt r0,#$C000
	jmp r11
	nop
_RGAE750:
;	move	r0,#$4000
	dw $4000
	jmp r11
	nop
_RLGetAngle:
	moves !rX,!rDeltaX	; DeltaX = 0?
	beq _RGAE700	; Yes, 90 or 270 Degrees
	nop
	bpl _RGAE120
	with !rX	; |DeltaX|
	not
	inc !rX
_RGAE120:
	moves !rY,!rDeltaY	; DeltaY = 0?
	beq _RGAE600	; Yes, 0 or 180 Degrees
	nop
	bpl _RGAE140+1	; Ensure Positive
	from !rY
	to !rY	; |DeltaY|
	not
	inc !rY
;
;	>>>   ENSURE RESULTS ARE FROM 0.0 TO 1.0   <<<
;
_RGAE140:
	from !rY	; |DeltaY| < |DeltaX|?
;	to	r0				; @CMP@
	sub !rX
	bne _RGAE160
	with !rSwap	; Didn't Swap
	iwt r0,#$2000	; |DeltaY| = |DeltaX| (45 Degrees)
	bra _RGAE450
	nop
_RGAE160:
	blt _RGAE180	; Yes
	sub !rSwap
	move r0,!rX	; No, Swap |DeltaY| / |DeltaX|
	move !rX,!rY
	move !rY,r0
	inc !rSwap
;
;	>>>   GET SLOPE |DELTAY| / |DELTAX|   <<<
;
_RGAE180:
	ibt r0,#bank(InvTable)	; Get InverseTable Entry
	romb
	from !rX	; Get |DeltaX|
;	to	r0
	add !rX
	iwt r1,#lo16(InvTable-2)
;	from	r0
	to r14
	add r1
	dec r0
	dec r0
	to r6	; Get Inverse Value
	getb
	inc r14
;	with	r0				; Low/High Gear?
	hib
	with r6
	getbh
	bne _RGAE300	; High
	from !rY	; Low
;	to	r0
	lmult
	with r4
	bra _RGAE350
	to r0
_RGAE300:
;	to	r0				; <<1
	add !rY
;	with	r0
	lmult
	with r4
	hib
;	with	r0
	lob
;	with	r0
	swap
;	with	r0
	add r4
_RGAE350:
;	with	r0				; Get Index into |ArcTan| Table
	lsr
	lsr
	lsr
	lsr
;	from	r0
	to r1
	bic #1
	ibt r0,#bank(PArcTanTable)	; Get |ArcTan| Table Entry
	romb
	iwt r0,#lo16(PArcTanTable)
;	from	r0
	to r14
	add r1
	getb	; Get Angle
	inc r14
	dec !rSwap	; Were DeltaX/DeltaY Swapped?
	alt1
	bne _RGAE450	; No
	getb
;
;	>>>   DETERMINE QUADRANT   <<<
;
_RGAE400:
;	with	r0				; Yes, 90-Angle
	not
	inc r0
	iwt r1,#$4000
;	with	r0
	add r1
_RGAE450:
	moves !rDeltaX,!rDeltaX	; DeltaX >= 0?
	bmi _RGAE500	; Quad1 or Quad2
;
;	>>>   QUAD0 OR QUAD3   <<<
;
	moves !rDeltaY,!rDeltaY	; DeltaY >= 0?
	bpl _RGAE800	; Quad0
	nop
;	with	r0				; Quad3 (360-Angle)
	not
	jmp r11
	inc r0
;
;	>>>   QUAD1 OR QUAD2   <<<
;
_RGAE500:
;	moves	rDeltaY,rDeltaY			; DeltaY >= 0?
	from !rDeltaY
	bmi _RGAE520	; Quad2
	nop
;	with	r0				; 180-Angle
	not
	inc r0
_RGAE520:
	iwt r1,#$8000	; 180+Angle
;	with	r0
	jmp r11
	add r1
;
;	>>>   DELTA Y = 0   <<<
;
_RGAE600:
	moves !rDeltaX,!rDeltaX	; Always 0 or 180 degrees
;	with	r0
	bpl _RGAE800
	sub r0
	iwt r0,#$8000
_RGAE800:
	jmp r11
	nop

	%CACHEE(_RLBuildVSegList4)


	if !RLMASKED
;	******************************************************************
;	**								**
;	**  BUILD MASKED MIDDLE TEXTURE LIST (this port)		**
;	**								**
;	******************************************************************
;
;	For each visible segment with a masked middle texture (rlvfMASKED, from
;	the segment flag rlgfClear): the texture's image (face byte 4: index
;	into RLMaskedTable), its height/width and the world Z of its bottom.
;	PC DOOM: the texture is drawn once (not tiled), its top at the lower
;	ceiling, or with "lower unpegged" its bottom at the higher floor, moved
;	up by the y offset (face byte 5); only inside the opening.
;
	!rVSeg = r10	; Pointer to VisibleSegment Flags
	!rVSegEnd = r12	; Pointer to End of VisibleSegmentList (Flags)
	!rMask = r9	; Pointer within MaskList
	!rEyeZ = r7	; View Z

_RLBuildMaskList:
	iwt !rVSeg,#lo16(_RLVSegList-rlvSize+rlvFlags)	; START of VisibleSegmentList
	lms !rVSegEnd,(VSegListEnd&$FFFF)	; END of VisibleSegmentList
	with !rVSegEnd
	%add_i(rlvFlags)
	iwt !rMask,#lo16(_RLMaskList)
	lms !rEyeZ,(ViewZ&$FFFF)
_BML2000:
	ibt r0,#rlvSize	; Move to Next VSEG
	with !rVSeg
	add r0
	from !rVSeg	; At END of VisibleSegmentList?
	cmp !rVSegEnd
	bne _BML2100
	nop
	iwt r15,#lo16(_BML8000)
	nop
_BML2100:
	ldw (!rVSeg)	; MASKED MIDDLE TEXTURE?
	iwt r1,#rlvfMASKED
	and r1
	beq _BML2000
	nop
	iwt r0,#lo16(_RLMaskListE)	; List full?
	from !rMask
	cmp r0
	bcs _BML2000	; Yes, left out
	nop
;	>>>   VSEG   <<<
	from !rVSeg
	%sub_i(rlvFlags)
	stw (!rMask)
	inc !rMask
	inc !rMask
;	>>>   FACE: MASKED TEXTURE INDEX / Y OFFSET   <<<
	ibt r0,#lo16(EMBSP+2)	; Bank of EM FACES Data
	ldb (r0)
	romb
	ibt r0,#(rlvFace-rlvFlags)
	add !rVSeg
	ldw (r0)
	to r14	; Face byte 4
	%add_i(4)
	getb	; MaskedTable index
	inc r14
	to r6	; R6 = Index * 2
	add r0
	to r5	; R5 = Y Offset (signed)
	getb
	with r5
	sex
;	>>>   IMAGE   <<<
	ibt r0,#bank(RLMaskedTable)
	romb
	iwt r0,#lo16(RLMaskedTable)
	to r14
	add r6
	getb
	inc r14
	getbh
	iwt r1,#lo16(RLImagesData+rliHeight)	; Add Base of ImageData
	to r6	; R6 = Image
	add r1
	ibt r0,#bank(RLImagesTable)
	romb
	move r14,r6
	from r6
	stw (!rMask)
	inc !rMask
	inc !rMask
	to r8	; R8 = Height
	getb
	inc r14
;	>>>   TOP: LOWER CEILING, OR (LOWER UNPEGGED) HIGHER FLOOR + HEIGHT   <<<
	ibt r0,#(rlvSectorFarData-rlvFlags)	; R6 = SectorFarData
	add !rVSeg
	to r6
	ldw (r0)
	ldw (!rVSeg)	; Lower unpegged?
	iwt r1,#rlvfLOWERPEGGED
	and r1
	bne _BML4000
	nop
	ibt r0,#(rlvCeilingHeight-rlvFlags)	; NearCeiling
	add !rVSeg
	to r1
	ldw (r0)
	from r6	; FarCeiling
	%add_i(4)
	ldw (r0)
	sub !rEyeZ
	cmp r1	; Lower?
	bge _BML4800
	nop
	move r1,r0
	bra _BML4800
	nop
_BML4000:
	ibt r0,#(rlvFloorHeight-rlvFlags)	; NearFloor
	add !rVSeg
	to r1
	ldw (r0)
	from r6	; FarFloor
	%add_i(2)
	ldw (r0)
	sub !rEyeZ
	cmp r1	; Higher?
	blt _BML4400
	nop
	move r1,r0
_BML4400:
	with r1	; + Height
	add r8
_BML4800:
	from r1	; + Y Offset - Height = Bottom
	add r5
	sub r8
	stw (!rMask)
	inc !rMask
	inc !rMask
;	>>>   HEIGHT / WIDTH-1   <<<
	getb	; Width (0 = 256)
	dec r0
	lob
	swap
	or r8
	stw (!rMask)
	inc !rMask
	iwt r15,#lo16(_BML2000)
	inc !rMask
;	>>>   DONE   <<<
_BML8000:
	sm (TRMaskEnd&$FFFF),!rMask
	iwt r15,#lo16(_BML9900)
	nop
	endif
