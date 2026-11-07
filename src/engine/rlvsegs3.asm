	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                        ENGINE VSEGS MODULE 3                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildVSegList3


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD VSEGMENT LIST 3        CALCULATE VSEGMENTS' TEXTURES  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       CALCULATE VSEGMENTS' TEXTURES       * * * * * * *
;
	!rRLWallsTable = r3	; Address of RLWallsTable
	!rRLWallsTableB = r4	; Bank of RLWallsTable
	if useTEXTURES != 0
	!rRLTextureTable = r5	; Address of RLTextureTable
	!rRLTextureTableB = r6	; Bank of RLTextureTable
	endif
	!rEMFACESB = r7	; Bank of EMFACES
	!rFaceTexture = r8	; Pointer to VisibleSegmentFaceTexture
	!rVSegTexture = r9	; Pointer to VisibleSegmentTexture
	!rVSeg = r10	; Pointer within VisibleSegment
	!rVSegFlags = r12	; VisibleSegment Flags
	!rVSegEnd = r13	; Pointer to End of VisibleSegmentList


	%align_pad(12, 16, (_BV3L9000-_BV3L2000)&$0F)	; align 16,(_BV3L9000-_BV3L2000)&$0f

;
;	* * * * * * *       FINISHED CALCULATING VSEGMENTS' TEXTURES       * * * * * * *
;
_BV3L9000:
	iwt r0,#lo16(_RLBuildVSegList4)	; BUILD VISIBLE SEGMENT LIST 4
	ibt r8,#bank(_RLBuildVSegList4)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	* * * * * * *       START CALCULATING VSEGMENTS' TEXTURES       * * * * * * *
;
_RLBuildVSegList3:
	iwt !rVSeg,#lo16(_RLVSegList-rlvSize+rlvFlags)	; START of VisibleSegmentList
	lms !rVSegEnd,(VSegListEnd&$FFFF)	; END of VisibleSegmentList
	with !rVSegEnd
	%add_i(rlvFlags)
;
	if useTEXTURES != 0
	iwt !rRLTextureTable,#lo16(RLTextureTable)	; RLTextureTable
	iwt !rRLTextureTableB,#bank(RLTextureTable)
	endif
;
	iwt !rRLWallsTable,#lo16(RLWallsTable)	; RLWallsTable
	ibt !rRLWallsTableB,#bank(RLWallsTable)
;
	ibt r0,#lo16(EMBSP+2)	; Bank of EM FACES Data
	assert (lo16(EMBSP+2))&$FFFF < $80 || (lo16(EMBSP+2))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	to !rEMFACESB
	ldb (r0)
	from !rEMFACESB
	romb

	%CACHEB(_RLBuildVSegList3)
;
;	* * * * * * *       HANDLE NEXT VISIBLE SEGMENT       * * * * * * *
;
_BV3L2000:
	ibt r6,#rlvSize	; Offset to Next VSEG
_BV3L2200:
	from !rVSeg	; Move to Next VSEG
_BV3L2400:
	to !rVSeg	; @FROM IN PIPELINE@
	add r6
	from !rVSeg	; At END of VisibleSegmentList?
;	to	r0				; @CMP@
	sub !rVSegEnd
	beq _BV3L9000	; Yes!  No More VisibleSegments!

;
;	* * * * * * *       PROCESS NEXT VISIBLE SEGMENT       * * * * * * *
;
;	>>>   GET VISIBLESEGMENT FLAGS   <<<
;
;	to	r0				; Get VisibleSegmentFlags
	ldw (!rVSeg)
	moves !rVSegFlags,r0	; DOING WALL?
	bpl _BV3L2400	; No!
;
;	>>>   MOVE TO VISIBLE SEGMENT FACE   <<<
;
	from !rVSeg	; Move to VSeg.Face
;	to	r0
	%add_i((rlvFace-rlvFlags))
	to !rFaceTexture	; Get Face Address
	ldw (r0)

;
;	* * * * * * *       NORMAL WALL       * * * * * * *
;
_BV3L20000:
	from !rVSegFlags	; NORMAL?
;	to	r0
	lsr
	bcc _BV3L30000
	inc !rFaceTexture	; Move to NormalWall/SectorFar
	move r14,!rFaceTexture
	ibt r0,#(rlvNormalWallTexture-rlvFlags)
;	from	r0
	to !rVSegTexture
	add !rVSeg
	iwt r2,#rlvfNORMALPEGGED	; PEGGED?
	with r2
	and !rVSegFlags
	iwt r11,#lo16(_BV3L2200)
	iwt r15,#lo16(_RLAddWallTexture)

;
;	* * * * * * *       UPPER WALL       * * * * * * *
;
_BV3L30000:
;	with	r0				; UPPER?
	lsr
	bcc _BV3L40000
	inc !rFaceTexture	; Move to UpperWall
	move r14,!rFaceTexture
	ibt r0,#(rlvUpperWallTexture-rlvFlags)
;	from	r0
	to !rVSegTexture
	add !rVSeg
	iwt r2,#rlvfUPPERPEGGED	; PEGGED?
	with r2
	and !rVSegFlags
	link #3
	iwt r15,#lo16(_RLAddWallTexture)
;
;	* * * * * * *       LOWER WALL       * * * * * * *
;
_BV3L40000:
	from !rVSegFlags	; LOWER?
;	to	r0
	%and_i(rlvfLOWERWALL)
	beq _BV3L2200
	inc !rFaceTexture	; Move to LowerWall
	move r14,!rFaceTexture
	ibt r0,#(rlvLowerWallTexture-rlvFlags)
;	from	r0
	to !rVSegTexture
	add !rVSeg
	iwt r2,#rlvfLOWERPEGGED	; PEGGED?
	with r2
	and !rVSegFlags
	iwt r11,#lo16(_BV3L2200)
;	iwt	r15,#<_RLAddWallTexture+1
;
;	* * * * * * *       ADD WALL TEXTURE       * * * * * * *
;
;	r14 (rFaceTexture)	=	Pointer to Face Texture
;	rVSegTexture		=	Pointer to VisibleSegment WallTexture
;	r2			=	0=NOT Pegged, != 0 = PEGGED
;
_RLAddWallTexture:
;
;	>>>   GET TEXTURE   <<<
;
	iwt r0,#rlvfALTTEXTURE	; ALTERNATE TEXTURE?
;	with	r0
	and !rVSegFlags
	beq _RLAWT200	; No
	getb
;
;	>>>   TRANSLATE TEXTURE -> ALTERNATE TEXTURE   <<<
;
	iwt r1,#lo16(_RLTextureXLatTable)	; YES!  GET ALTERNATE TEXTURE#
	if !RLWALLFMT2
	add r0	; (wall format 2: index -> word offset)
	endif
;	with	r0
	add r1
;	to	r0
	ldb (r0)
_RLAWT200:
	if !RLWALLFMT2
	add r0	; wall format 2: wall index -> WallsTable offset
	endif

	if useTEXTURES != 0
;
;	>>>   GET POINTER TO TEXTURE   <<<
;
	from !rRLTextureTableB
	romb
;	from	r0
	to r14
	add !rRLTextureTable
	iwt r1,#lo16(RLTextureData+rltPatches+rlhWall)	; Point to First Patch
	getb	; Get Offset within TextureDataTable
	inc r14
	getbh
;	from	r0
	to r14
	add r1
	getb
	inc r14
	getbh
	endif

	from !rRLWallsTableB	; Get Address of WallsTable
	romb
;	from	r0
	to r14
	add !rRLWallsTable
;
	iwt r1,#lo16(RLWallsData+rliHeight)	; Add Base of WallsData (iwt: the FX3 wall table is > $80 bytes)
	getb	; Get Offset within WallsDataTable
	inc r14
	getbh
;	from	r0
	to r14
	add r1
;
;	>>>   SAVE POINTER TO TEXTUREDATA   <<<
;
	from r14
	stw (!rVSegTexture)
	dec !rVSegTexture	; Move to VSegTextureH
	dec !rVSegTexture
;
;	>>>   GET DIMENSIONS OF WALL PATCH   <<<
;
;	to	r0				; Get Height of Wall Texture
	getb
	inc r14
	moves r2,r2	; PEGGED Texture?
	beq _RLAWT800	; No
	nop
	inc r0	; YES!
_RLAWT800:
;	with	r0				; Get Width-1 of Wall Texture
	getbh
;
	from !rEMFACESB
	romb
;
;	>>>   SAVE DIMENSIONS OF WALL PATCH   <<<
;
	jmp r11	; Return to Caller
;	from	r0
	stw (!rVSegTexture)

	%CACHEE(_RLBuildVSegList3)
