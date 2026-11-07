	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                     ENGINE TRACE WALLS MODULE 5                    *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildTraceWalls5


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD TRACE                        CALCULATE WALL TEXTURES  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       CALCULATE WALL TEXTURES       * * * * * * *
;
	!rRSAngle = r2	; Rotated Segment Angle
	!rRSPDistance = r3	; Rotated Segment Perpendicular Distance
	!rVTOffset = r5	; Vertex Texture Offset
	!rFaceOffset = r7	; Offset along Face Integer
	!rTextureModulo = r8	; Texture Width Modulus
	!rWallPlotData = r9	; Pointer within WallPlotData
	!rWallPlotDataEnd = r10	; Pointer to End of WallPlotData
	!rVSeg = r11	; Pointer to Current VisibleSegment
	!rVSegEnd = r12	; Pointer to End of VisibleSegment List
	!rWall = r13	; Pointer to WallData


	%align_pad(7, 16, (_TRW5S9000-_TRW5S2200)&$0F)	; align 16,(_TRW5S9000-_TRW5S2200)&$0f
;
;	* * * * * * *       COMPLETED CALCULATING WALL TEXTURES       * * * * * * *
;
_TRW5S9000:
	iwt r0,#lo16(_RLBuildTraceFloors2)	; BUILD TRACE FLOORS 2
	ibt r8,#bank(_RLBuildTraceFloors2)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	* * * * * * *       START CALCULATING WALL TEXTURES       * * * * * * *
;
_RLBuildTraceWalls5:
	iwt !rVSeg,#lo16(_RLVSegList-rlvSize+rlvXsT)	; START of VSegList
	lms !rVSegEnd,(VSegListEnd&$FFFF)	; END of VSegList
;	move	r0,#rlvXsT
;	with	rVSegEnd
;	add	r0

	%CACHEB(_RLBuildTraceWalls5)
;
;	* * * * * * *       PROCESS NEXT VISIBLE SEGMENT       * * * * * * *
;
_TRW5S2200:
	ibt r4,#rlvSize	; Offset to Next VSEG
	ibt r6,#(rlvWallPlotDataStart-rlvXsT)
	from !rVSeg	; Move to Next VSEG
_TRW5S2400:
	to !rVSeg	; @FROM IN PIPELINE@
	add r4
	from !rVSeg	; At End?
;	to	r0				; @CMP@
	sub !rVSegEnd
	beq _TRW5S9000	; Yes!  No More VisibleSegments!
;
;	>>>   GET STARTING PIXEL/#PIXELS TO TRACE   <<<
;
;	to	r0				; Get Xs1/XsCount
	ldw (!rVSeg)
	inc r0	; Clipped?
	beq _TRW5S2400	; Yes!
	from !rVSeg	; Move to Next VSEG
;
;	>>>   MOVE TO WALLPLOTDATA START   <<<
;
;	to	r0
	add r6
;
;	>>>   GET WALLPLOTDATA START   <<<
;
	to !rWallPlotData	; WallPlotDataStart
	ldw (r0)
	inc r0
	inc r0
	to !rWallPlotDataEnd	; WallPlotDataEnd
	ldw (r0)
;
;	>>>   ANY WALL PLOTS TO PROCESS?   <<<
;
	from !rWallPlotData	; NO WALL PLOT DATA?
;	to	r0				; @CMP@
	sub !rWallPlotDataEnd
	beq _TRW5S2400+1	; NO!  Skip this VSEG
	with !rVSeg	; Move to Next VSEG
;
;	>>>   GET ROTATED SEGMENT ANGLE   <<<
;
	ibt r0,#(rlvRSAngle-rlvXsT)	; Move to RSN
;	with	r0
	add !rVSeg
	to !rRSAngle	; ROTATED SEGMENT ANGLE
	ldw (r0)
;
;	>>>   GET ROTATED SEGMENT PERPENDICULAR DISTANCE   <<<
;
	inc r0	; Move to RSPD
	inc r0
	to !rRSPDistance	; ROTATED SEGMENT PERPENDICULAR DISTANCE
	ldw (r0)
;
;	>>>   GET VERTEX TEXTURE OFFSET   <<<
;
	inc r0	; Move to VTO
	inc r0
	to !rVTOffset	; VERTEX TEXTURE OFFSET
	ldw (r0)
;
;	>>>   GET FACE OFFSET   <<<
;
	ibt r0,#(rlvFaceOffsetX-rlvXsT)	; FaceOffsetX
;	with	r0
	add !rVSeg
	to !rFaceOffset
	ldb (r0)

;
;	* * * * * * *       PROCESS VSEG'S WALLPLOTDATA       * * * * * * *
;
_TRW5S4000:
	from !rWallPlotData	; At End?
;	to	r0				; @CMP@
	sub !rWallPlotDataEnd
	beq _TRW5S2200	; Yes!  No More WallPlots
;
;	>>>   GET WALLPLOT VSEG TEXTUREH OFFSET   <<<
;
	with !rWallPlotData	; Move to VSegTextureH
	%add_i(plwVSegTextureH)
;	to	r0				; Get VSegTextureH
	ldb (!rWallPlotData)
;
;	>>>   GET VSEG TEXTURE ADDRESS   <<<
;
;	with	r0				; Move to VSeg.TextureW
	add !rVSeg
	inc r0
	to !rTextureModulo	; Get TextureWidthModulo
	ldb (r0)
	inc r0
	to !rWall	; Get Address of Wall
	ldw (r0)
	if !RLWALLFMT3 == 0
	inc !rWall	; Move to WallStripPointers
	inc !rWall
	if !RLWALLFMT2
	inc !rWall	; (wall format 2: the header has the column step too)
	endif
	endif
;
;	>>>   CALCULATE ANGLE OF INTERSECTION WITH SEGMENT   <<<
;
	ibt r0,#bank(ScreenXAngleTable)
	romb
	inc !rWallPlotData	; Move to ScreenX Coordinate
;	to	r0
	ldb (!rWallPlotData)
;	with	r0
	add r0
	iwt r1,#lo16(ScreenXAngleTable)	; Get ScreenXAngle Offset
;	from	r0
	to r14
	add r1
	getb
	inc r14
	getbh
;	with	r0				; ANGLE=(VIEWANGLE-ROTATED SEGMENT ANGLE)
	sub !rRSAngle
;
;	>>>   CALCULATE RSP*TAN(ANGLE)   <<<
;
;	from	r0				; Angle
	lsr
	lsr
	lsr
	lsr
	lsr	; >>5
	lsr	; Remove lowest bit
;	from	r0
	to r1
	add r0
	ibt r0,#bank(TanTable)
	romb
	iwt r0,#lo16(TanTable)
;	from	r0
	to r14
	add r1
	getb
	inc r14
	to r6	; SIIIIIII IFFFFFFF
	getbh
;
;	>>>   CALCULATE VIEWANGLE INTERSECTION OFFSET   <<<
;
	from !rRSPDistance	; VXTOFFSET = RSPD*TAN(ANGLE)
;	to	r0
	lmult	; r0:SIIIIIII IIIIIIII r4:IIIIIIII.FFFFFFFF
;	with	r0
	lob
	with r4
	hib
;	with	r0
	swap
	with r4
	add r0
;
	ibt r0,#bank(RLWallsTable)	; Get Address of WallsTable
	romb
;
;	>>>   CALCULATE TEXTURE COLUMN   <<<
;
	from !rVTOffset	; TEXTURE COLUMN=(VTOffset-VxTOffset)
;	to	r0
	sub r4
;
;	>>>   ADD FACE OFFSET   <<<
;
;	with	r0				; Add Face Offset
	add !rFaceOffset
;
;	>>>   WRAP TEXTURE HORIZONTALLY   <<<
;
;	with	r0				; FaceOffset % TextureModulo
	and !rTextureModulo
	if !RLWALLFMT3
;
;	>>>   WALL FORMAT 3: BLOCKS FROM A CODEBOOK   <<<
;
;	(this port: header = height, modulo, flags ($80 half size), bank,
;	codebook, indices, index bytes per block column.  WallPlot.Data = the
;	indices of the column's block column, WallPlot.VSegTextureH/Xs (not
;	needed after this module) = codebook + 1024 * (stored column AND 1))
;
	move r6,r0	; R6 = Column
	from !rWall	; Header byte 2: flags
	to r14
	%add_i(2)
	from !rWallPlotData	; R1 = WallPlot.Data
	to r1
	%sub_i((plwXs-plwData))
	getb
	inc r14
	sex	; Half size?
	bpl _TRW5S4600
	nop
	with r6	; Yes: every 2nd column stored
	lsr
	from r1	; WallPlot.PixScale / 2
	to r4
	%sub_i((plwData-plwPixScale))
	ldw (r4)
	lsr
	stw (r4)
	from r1	; WallPlot.WallF/TextureOffset / 2
	to r4
	%add_i((plwWallF-plwData))
	ldw (r4)
	lsr
	stw (r4)
_TRW5S4600:
	getb	; Bank -> WallPlot.Bank
	inc r14
	dec r1
	stb (r1)
	inc r1
	getb	; Codebook
	inc r14
	getbh
	inc r14
	move r4,r0
	from r6	; + 1024 * (Column AND 1): the column's 4 codebook planes
	%and_i(1)
	swap
	add r0
	add r0
	with r4
	add r0
	from r1
	%add_i((plwVSegTextureH-plwData))
	from r4
	stw (r0)
	getb	; Indices
	inc r14
	to r4
	getbh
	inc r14
	with r6	; Block column
	lsr
	getb	; Index bytes per block column
	umult r6
	add r4
	stw (r1)	; WallPlot.Data
	with !rWallPlotData	; Move to Next WallPlot
	%add_i((plwSize-plwXs))
	iwt r15,#lo16(_TRW5S4000)
	nop
	else
;
;	>>>   GET POINTER TO WALL TEXTURE STRIP   <<<
;
	if !RLWALLFMT2
;	wall format 2: offset = (column * step) >> 2, step = 12/6/3 (every
;	column/every 2nd/every 4th stored: the modulo has those low bits clear)
	from !rWall	; Column step: the header byte before the pointers
	to r14
	%sub_i(1)
	to r4	; R4 = Column step, + $80 for half height
	getb
	from r4
	to r6
	%and_i(15)
	umult r6
	lsr
	lsr
	else
;	with	r0				; Get Offset to Pointer to PixelStrip
	umult #3
	endif
;	from	r0				; Move to correct pointer
	to r14
	add !rWall
;
;	>>>   GET POINTER TO WALLTEXTURESTRIP   <<<
;
	from !rWallPlotData	; Move to TextureData
	to r1
	%sub_i((plwXs-plwData))
	getb
	inc r14
;	from	r0
	stb (r1)
	inc r1
	getb
	inc r14
;	from	r0
	stb (r1)
	dec r1
	dec r1
;
;	>>>   HALF HEIGHT WALL?   <<<
;
	if !RLWALLFMT2
	from r4	; Flag $80
	sex
	bmi _TRW5S4700
	nop
_TRW5S4750:
	endif
;
;	>>>   PROCESS NEXT WALLPLOTDATA   <<<
;
	with !rWallPlotData	; Move to Next WallPlot
	%add_i((plwSize-plwXs))
	getb
;	from	r0
;	stb	(r1)
	alt1
	bra _TRW5S4000
	stw (r1)
	endif

;
;	>>>   HALF HEIGHT WALL   <<<
;
;	(this port, wall format 2: the strips hold every texel row pair once;
;	the texel offset and the texels per screen pixel are halved)
;
	if !RLWALLFMT2-!RLWALLFMT3	; (wall format 2 only)
_TRW5S4700:
	from r1	; R6 = WallPlot.PixScale
	to r6
	%sub_i((plwData-1)-plwPixScale)
	ldw (r6)
	lsr
	stw (r6)
	from r1	; R6 = WallPlot.WallF/TextureOffset
	to r6
	%add_i(plwWallF-(plwData-1))
	ldw (r6)
	lsr
	bra _TRW5S4750
	stw (r6)
	endif

	%CACHEE(_RLBuildTraceWalls5)
