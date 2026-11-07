	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                     ENGINE TRACE WALLS MODULE 3                    *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildTraceWalls3


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD TRACE          TRACE WALL VSEGMENTS C - WALL PLOTS 2  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       TRACE WALL VISIBLE SEGMENTS       * * * * * * *
;
	!rYs = r2	; Pixel Y Coordinate
	!rWallZ = r3	; World Z at Bottom of Wall
	!rWorldZF = r5	; World Z FractionCounter

	!rVSegTextureH = r7	; Offset to VisibleSegment TextureHeight
	!rXs = !rVSegTextureH	; Pixel X Coordinate

	!rVSeg = r8	; Pointer within VisibleSegment
	!rScale = !rVSeg	; RL->SCN Pixel Scaling Integer
	!rTextureHeight = !rScale	; Height of Texture in WorldPixels

	!rWallPlotPtr = r9	; Pointer within WallPlotData
	!rPreWallPlotPtr = r10	; Pointer within PreWallPlotData
	!rClipRange = r11	; Current ClipRange

	!rVSegEnd = r12	; Pointer to End of VisibleSegment List
	!rScaleF = r12	; RL->SCN Pixel Scaling Fraction
	!rPixScale = r13	; SCN->RL Pixel Scale

	!rWallPlotPtrP = r14	; Pointer within WallPlotData Previous


	%align_pad(8, 16, (_RLBuildTraceWalls3-_TRW3S1400)&$0F)	; align 16,(_RLBuildTraceWalls3-_TRW3S1400)&$0f
;
;	* * * * * * *       INITIALIZE WALLPLOT INDEX       * * * * * * *
;
_RLBuildTraceWalls3:
	if useHIGHDETAIL != 0
	ibt r12,#(RLViewPixX/3)	; Get Width of Display
	lm r0,(DetailLevel&$FFFF)
	dec r0	; Low/High?
	bmi _TRW3S1200	; High
	nop
	ibt r12,#(RLViewPixX/3/2)	; Get Width of Display
_TRW3S1200:
	endif
	if useHIGHDETAIL == 0
	ibt r12,#(RLViewPixX/3/2)	; Get Width of Display
	endif
	iwt r13,#lo16(_TRW3S1400)
	iwt r1,#lo16(_RLWallPlots)	; Point to Start of WallPlots
;	with	r0				; NO Previous Pointer!
	sub r0

	%CACHEB(_RLBuildTraceWalls3)
_TRW3S1400:
;	from	r0				; Default Previous Pointer
	stw (r1)
	inc r1	; Next WallPlotPtr
	loop
	inc r1	; Next WallPlotPtr

;
;	* * * * * * *       INITIALIZE WALLPLOTDATA POINTER       * * * * * * *
;
	iwt !rWallPlotPtr,#lo16(_RLWalls)	; END of WallPlotData (FREE MEMORY)
	bra _TRW3S2000
	nop

	%CACHEE(_RLBuildTraceWalls3)


	%align_pad(7, 16, (_TRW3S9000-_TRW3S2200)&$0F)	; align 16,(_TRW3S9000-_TRW3S2200)&$0f
;
;	* * * * * * *       FINISHED TRACING WALL VISIBLE SEGMENTS       * * * * * * *
;
_TRW3S9000:
	sms (TRWallPlotPtr&$FFFF),!rWallPlotPtr
	iwt r0,#lo16(_RLBuildTraceObjs)	; BUILD TRACE OBJECTS
	ibt r8,#bank(_RLBuildTraceObjs)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	* * * * * * *       START PROCESSING VISIBLE SEGMENTS       * * * * * * *
;
_TRW3S2000:
	lms !rVSeg,(VSegListEnd&$FFFF)	; END of VSegList

	%CACHEB(_RLAddWallPlot)
;
;	* * * * * * *       PROCESS NEXT VISIBLE SEGMENT       * * * * * * *
;
_TRW3S2200:
	ibt r4,#rlvSize	; Offset to Next VSEG
	ibt r6,#(rlvWallPlotDataEnd-rlvXsT)
	iwt !rVSegEnd,#lo16(_RLVSegList-rlvSize+rlvXsT)	; START of VSegList
	with !rVSeg	; Move to Next VSEG
_TRW3S2400:
;	with	rVSeg				; Move to Next VSEG
	sub r4
	from !rVSeg	; At End?
;	to	r0				; @CMP@
	sub !rVSegEnd
	beq _TRW3S9000	; Yes!  No More VisibleSegments!
;
;	>>>   GET STARTING PIXEL/#PIXELS TO TRACE   <<<
;
;	to	r0				; Get Xs1/XsCount
	ldw (!rVSeg)
	inc r0
	beq _TRW3S2400	; Clipped!
	with !rVSeg
	nop	; @"WITH" IN PIPELINE@
;
;	>>>   GET PREWALLPLOTDATA START/END   <<<
;
	from !rVSeg	; Move to WallPlotDataStart
;	to	r0
	add r6
	to r1	; PreWallPlotDataEnd
	ldw (r0)
	dec r0
	dec r0
	to !rPreWallPlotPtr	; PreWallPlotDataStart
	ldw (r0)
;
;	>>>   ANY PREWALLPLOTS TO PROCESS?   <<<
;
	from r1	; ANY PREWALLPLOT DATA?
;	to	r0				; @CMP@
	sub !rPreWallPlotPtr
	beq _TRW3S2400	; NO!  Skip this VSEG
	with !rVSeg	; Move to Next VSEG
	nop	; @"WITH" IN PIPELINE@
;
	from !rWallPlotPtr	; SAVE WALLPLOTDATA START
	sbk

;
;	* * * * * * *       PROCESS VISIBLE SEGMENT'S PREWALLPLOTS       * * * * * * *
;
	sms (TRPreWallPlotPtr&$FFFF),r1	; Save PreWallPlotDataEnd
	sms (TRVSeg&$FFFF),!rVSeg	; Save VSeg

;
;	* * * * * * *       PROCESS NEXT PREWALLPLOT       * * * * * * *
;
_TRW3S3000:
;
;	>>>   THE WALLPLOTDATA MUST STAY BELOW THE UNREAD PREWALLPLOTS   <<<
;
;	(this port) The WallPlots grow up from _RLWalls towards the PreWallPlots,
;	which grow down from the ClipZones.  The VSegs are done from the last
;	(lowest PreWallPlots) up, so nothing below the end of this VSeg's
;	PreWallPlots (TRPreWallPlotPtr) is still needed.  When a WallPlot would
;	reach it the remaining strips are skipped (DOOM II MAP01/MAP29 views get there).
;
	lms r0,(TRPreWallPlotPtr&$FFFF)	; (end of this VSeg's PreWallPlots: none below is unread)
	%sub_i(plwSize)	; (room for the WallPlot being built)
	%sub_i(plwSize)
	from !rWallPlotPtr
	cmp r0
	bcc _TRW3S3010	; Below the limit
	nop
	with !rPreWallPlotPtr	; Skip this PreWallPlot (7 words)
	sub #14
	lms r4,(TRPreWallPlotPtr&$FFFF)	; (R4 = end, for _TRW3S8000: also when no WallPlot was made yet)
	iwt r15,#lo16(_TRW3S8000)
	nop
_TRW3S3010:
	dec !rPreWallPlotPtr
	dec !rPreWallPlotPtr
;
;	>>>   GET NEAR CEILING Z   <<<
;
	ibt r0,#rlvCeilingHeight	; NearCeiling Z
;	with	r0
	add !rVSeg
	to !rWallZ
	ldw (r0)
;
;	>>>   GET WORLD Z AT BOTTOM   <<<
;
	to r6	; World Z at Bottom
	ldw (!rPreWallPlotPtr)
;
;	>>>   GET VSEG_TEXTURE_H / RL->SCN PIXEL SCALING INTEGER   <<<
;
	dec !rPreWallPlotPtr
	dec !rPreWallPlotPtr
;	to	r0				; VSegTextureH/Scale
	ldw (!rPreWallPlotPtr)
;	from	r0
	to !rScaleF
	hib
;
;	>>>   GET TEXTURE HEIGHT   <<<
;
;	from	r0				; VSegTextureH
	to !rVSegTextureH
	lob
	from !rVSegTextureH	; Move to VisibleSegment Texture
;	to	r0
	add !rVSeg
;
;	>>>   GET FACE OFFSET Y   <<<
;
	ibt r1,#rlvFaceOffsetY	; R1 = FACE OFFSET Y
	with r1
	add !rVSeg
	to r1
	ldb (r1)
;
;	>>>   GET HEIGHT OF TEXTURE   <<<
;
;	to	r0				; Get TextureHeight
	ldb (r0)
	iwt r4,#lo16(TRTextureHeight)	; Save Height of Texture
;	from	r0
	stb (r4)
;	with	r0
	swap
	from !rScaleF	; R8 = TextureHeight.B / Scale.B
	to !rTextureHeight
	add r0
;
;	>>>   GET RL->SCN PIXEL SCALING FRACTION   <<<
;
	dec !rPreWallPlotPtr
	dec !rPreWallPlotPtr
	to !rScaleF
	ldw (!rPreWallPlotPtr)
;
;	>>>   GET SCREEN XS   <<<
;
	dec !rPreWallPlotPtr
	dec !rPreWallPlotPtr
;	to	r0
	ldb (!rPreWallPlotPtr)
;	from	r0
	to r4
	swap
	with !rVSegTextureH
	or r4
;
;	>>>   GET OFFSET TO WALLPLOTS   <<<
;
	if useHIGHDETAIL != 0
	lm r4,(RLMinPixX2&$FFFF)	; Get Offset from Start of Draw
	endif
	if useHIGHDETAIL == 0
	lms r4,(RLMinPixX&$FFFF)	; Get Offset from Start of Draw
	endif
;	with	r0
	sub r4
;	with	r0				; Get Word Offset
	add r0
	iwt r4,#lo16(_RLWallPlots)	; Add Base of WallPlots
	with r4
	add r0
;
;	>>>   GET CLIPPING RANGE   <<<
;
	dec !rPreWallPlotPtr
	dec !rPreWallPlotPtr
	to !rClipRange
	ldw (!rPreWallPlotPtr)
;
;	>>>   GET WORLD Y DISTANCE   <<<
;
	dec !rPreWallPlotPtr
	dec !rPreWallPlotPtr
;	to	r0				; R0 = World Y Distance
	ldw (!rPreWallPlotPtr)
;
	sms (TRWallPlot&$FFFF),r4	; Save Pointer to WallPlot Index
;
;	>>>   MOVE TO WORLD Z AT TOP   <<<
;
	dec !rPreWallPlotPtr
	dec !rPreWallPlotPtr
;
;	>>>   GET SCN->RL PIXEL SCALING FACTOR   <<<
;
;	from	r0				; SCN->RL Pixel Scale = 2*Y
	to !rPixScale
	add r0
;
;	* * * * * * *       ADD WALL PLOT       * * * * * * *
;
_RLAddWallPlot:
	to !rWallPlotPtrP	; Get Last WallPlot as WallPlotPrevious
	ldw (r4)
;
;	>>>   CALCULATE SCREEN COORDINATE AT BOTTOM OF WALL   <<<
;
	from !rScaleF	; PixelRatio * WorldZ
;	to	r0
	lmult	; r0:r4 = Fractionary Result
	from r4
	to !rWorldZF	; Save #Fractionary World Pixels
	add r4
;	from	r0
	to !rYs
	rol
	from !rScale	; r0 = Integer Result
;	to	r0
	lob
;	with	r0
	lmult
	with r4	; r4 = #Screen Pixels
	add !rYs
;
	ibt r6,#(RLViewPixY-1)/2	; Add Yb, Flip around Center
;	with	r0
	sub r0
;	with	r0
	sub !rWorldZF
	from r6
	to !rYs
	sbc r4
;
;	>>>   CLIP SCREEN COORDINATE BELOW BOTTOM   <<<
;
	from !rClipRange	; Get ClipRangeBottom
	to r4
	hib
	from !rYs	; Get #Pixels off Bottom
;	to	r0				; @CMP@
	sub r4
	blt _RLAWP4000	; None are off Bottom!
	with r4
	to !rYs
;
;	>>>   CALCULATE WORLDPIXEL COORDINATE AT BOTTOM OF VISIBLE WALL   <<<
;
_RLAWP4000:
	with r6	; [(Yb-Ys)*PixScale]
	sub !rYs
	from !rPixScale	; Get SCN->RL Scale Fraction
;	to	r0
	lob
;	with	r0
	swap
;	with	r0
	lsr
;	with	r0
	lmult	; r0:r4 = Fractionary Result
	from r4
	to !rWorldZF
	add r4
;	with	r0
	rol
;
;	>>>   FACE OFFSET Y   <<<
;
;	with	r0				; Add FaceOffset Y
	sub r1
;
	from !rPixScale	; Get SCN->RL Scale Integer
	to r1
	hib
	with r1
	lmult
;
;	with	r0				; World Z at Bottom of Visible Wall
	add r4

;
;	* * * * * * *       "PEG" WALL TEXTURE TO WORLD Z / WALL Z       * * * * * * *
;
_RLAWP5000:
	from !rScale	; R6 = TextureHeight
	to r6
	hib
	with !rScale	; Remove rTextureHeight
	lob
	with r6	; PEGGED TO WORLD Z/WALL Z?
	lsr
	with r6
	bcs _RLAWP5500	; WORLD Z
	add r6
;
;	>>>   "PEG" WALL TEXTURE TO WALL Z   <<<
;
	to !rWallZ	; -Wall Z Adjust
	ldw (!rPreWallPlotPtr)
;
;	>>>   "PEG" WALL TEXTURE VERTICALLY   <<<
;
_RLAWP5500:
;	with	r0				; Z - AdjustZ
	sub !rWallZ
;
;	>>>   WRAP WALL TEXTURE VERTICALLY   <<<
;
_RLAWP5800:
	dec r6	; Get WallTexture Modulo
;	with	r0				; R0 = #Pixels Offset
	and r6
	inc r6	; Get WallTexture Height
	with r6	; R6 = #Remaining Pixels
	sub r0

;
;	* * * * * * *       ADD WALLPLOT       * * * * * * *
;
;	>>>   BUILD WALLPLOT (TEXTURE OFFSET)   <<<
;
_RLAWP6200:
	from !rWallPlotPtr	; R4 = WallPlotData.TextureOffset
	to r4
	%add_i(plwWallF)
;	with	r0				; R0 = #PixelsOffset.B / $00.B
	swap
	from !rWorldZF	; Get WallFraction
	to r1
	hib
;	with	r0
	add r1
;	from	r0
	stw (r4)
	inc r4	; Move to WallPlot.VSeg.TextureH/Xs
	inc r4
;
;	>>>  GET #PIXELS TO PLOT   <<<
;
	from !rScale	; r1 = Integer #Pixels
	to r1
	umult r6
;
;	>>>   BUILD WALLPLOT (VSEG.TEXTUREH/XS)   <<<
;
	from !rVSegTextureH	; VSegTextureH.B / Xs.B
	stw (r4)
;
	from !rScaleF	; r0:r4 = Fraction
;	to	r0
	fmult
;	with	r0
	rol
;	with	r0
	add r1
;
	bne _RLAWP6400+1	; Drawing at least 1 pixel?
	from !rWallPlotPtr	; Yes
	inc r0	; NO, MUST DRAW AT LEAST 1!
_RLAWP6400:
;
;	>>>   BUILD WALLPLOT (PIXSCALE)   <<<
;
	from !rWallPlotPtr	; Move to PixScale
	to r4
	%add_i(plwPixScale)
	from !rPixScale	; SCN->RL Pixel Scale
	stw (r4)
;
;	>>>   CLIP #PIXELS TO PLOT AT TOP OF CLIPRANGE   <<<
;
	from !rClipRange	; R1 = ClipRange Top
	to r1
	lob
	from !rYs	; R1 = #Pixels from Current Y to ClipTop
	to r1
	sub r1
	inc r1
;
;	from	r0				; Trying to plot too many pixels?
	cmp r1
	blt _RLAWP6800	; No
	moves r0,r1	; Yes, Use Maximum #Pixels Left
_RLAWP6800:
;
;	>>>   BUILD WALLPLOT (NUMPIX)   <<<
;
;	from	r0
	stb (!rWallPlotPtr)
	with !rWallPlotPtr	; Move to Ys
	%add_i(plwPixY)
;
;	>>>   BUILD WALLPLOT (PIXY/RL->SCN PIXEL SCALING INTEGER)   <<<
;
	from !rScale	; RL->SCN Pixel Scaling Integer
	to r1
	swap
	with r1	; Get Ys
	or !rYs
	from r1	; Save Starting Y Coordinate / Scale
	stw (!rWallPlotPtr)
	inc !rWallPlotPtr	; Move to ScaleF
	inc !rWallPlotPtr
;
	with !rYs	; Ys -= #Pixels Plotted
	sub r0
	from !rClipRange	; R1 = ClipRange Top
	to r1
	lob
;
	from !rScaleF	; Save RL->SCN Pixel Scale Fraction
	stw (!rWallPlotPtr)
;
	with !rWallPlotPtr	; Move to Next WallPlot Pointer
	%add_i((plwNext-plwScaleF))
;
;	>>>   ANY MORE PIXELS TO PLOT FOR THIS WALLSTRIP?   <<<
;
	from !rYs	; Y Coordinate Off Top?
	cmp r1
;
;	>>>   LINK TO PREVIOUS WALL PLOT   <<<
;
	from !rWallPlotPtrP
	blt _RLAWP8000	; Y COORDINATE CLIPPED OFF TOP!
	stw (!rWallPlotPtr)
;
;	>>>   END THE STRIP HERE WHEN THE WALLPLOTDATA IS NEARLY FULL   <<<
;
;	(this port: a strip of a short texture close by makes up to one WallPlot
;	 per screen row; DOOM II MAP29 views could run past $FFFF.  Same as
;	 clipped off the top.)
;
	lms r1,(TRPreWallPlotPtr&$FFFF)
	with r1
	%sub_i(plwSize)
	with r1
	%sub_i(plwSize)
	from !rWallPlotPtr
	cmp r1
	bcs _RLAWP8000
	nop
;
;	>>>   ADD NEXT WALL PLOT   <<<
;
	inc !rWallPlotPtr
	from !rWallPlotPtr	; New Previous WallPlotDataPtr
	to !rWallPlotPtrP
	%sub_i((plwSize-1))
;
;	with	r0				; Get #Fractionary WorldPixels Plotted
	umult !rPixScale
;	with	r0
	lob
;	with	r0
	swap
	with !rWorldZF	; Add #Fractionary Pixels
	add r0
;
	iwt r0,#lo16(TRTextureHeight)	; Get Height of Texture
;	to	r0
	ldb (r0)
;	from	r0				; Remove PEGGED Bit
	to r6
	bic #1
	ibt r0,#0	; R0 = 0/1 Pixels Overflow
;	with	r0
	adc #0
	with r6	; Adjust Height of Texture
	sub r0
	bra _RLAWP6200
;
;	* * * * * * *       FINISHED THIS WALLPLOT       * * * * * * *
;
_RLAWP8000:
	inc !rWallPlotPtr
	inc !rWallPlotPtr
;
;	>>>   RESTORE OVERLAID REGISTERS   <<<
;
	lms r4,(TRPreWallPlotPtr&$FFFF)	; Restore PreWallPlotDataEnd
	lms !rVSeg,(TRVSeg&$FFFF)	; Restore VSeg
;
;	>>>   SAVE LAST WALLPLOT AS WALLPLOTSTART   <<<
;
	lms r1,(TRWallPlot&$FFFF)	; Get Address of WallPlot Index
	ibt r0,#-plwSize	; Move to START of LAST WallPlotData
;	with	r0
	add !rWallPlotPtr
;	from	r0				; Update the WallPlotIndex
	stw (r1)

;
;	* * * * * * *       FINISHED THIS PREWALLPLOT       * * * * * * *
;
_TRW3S8000:
	from r4	; At End?
;	to	r0				; @CMP@
	sub !rPreWallPlotPtr
	beq _TRW3S8800	; Yes!  No More PreWallPlots
	nop
	iwt r15,#lo16(_TRW3S3000)	; Process Next PreWallPlot
	nop
_TRW3S8800:
	ibt r0,#(rlvWallPlotDataEnd-rlvXsT)	; SAVE WALLPLOTDATA END
;	with	r0
	add !rVSeg
	from !rWallPlotPtr
	stw (r0)
;
	iwt r15,#lo16(_TRW3S2200)	; No More PreWallPlots
	nop

	%CACHEE(_RLAddWallPlot)
