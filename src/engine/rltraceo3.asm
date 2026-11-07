	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                    ENGINE TRACE OBJECTS MODULE 3                   *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildTraceObjs3


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD TRACE                           CALCULATE OBJ IMAGES  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       CALCULATE OBJ IMAGES       * * * * * * *
;
	!rPixScaleF = r7	; SCN->RL Pixel Scaling Fraction
	!rPixScale = r8	; SCN->RL Pixel Scaling Integer
	!rObjPlotData = r9	; Pointer within ObjPlotData
	!rObjPlotDataEnd = r10	; Pointer to End of ObjPlotData
	!rVObj = r11	; Pointer to Current VisibleObject
	!rXs1 = r13	; Starting X Coordinate for VObj (Xs1)
	!rRLImageData = r5	; Base of RLImageData
	!rDetailLevel = r12	; Low/High Detail Level
	!rFlipWidth = r3	; WorldWidth of Image (=0 if NOT Flipped)


;
;	* * * * * * *       COMPLETED CALCULATING OBJ IMAGES       * * * * * * *
;
_TRO3S9000:
	iwt r0,#lo16(_RLBuildTraceFloors)	; BUILD TRACE FLOORS
	ibt r8,#bank(_RLBuildTraceFloors)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop


	%align_pad(14, 16, (_RLBuildTraceObjs3-_TRO3S2200)&$0F)	; align 16,(_RLBuildTraceObjs3-_TRO3S2200)&$0f
_RLBuildTraceObjs3:
	iwt !rVObj,#lo16(VObjListStart-2)	; START of VObjList
;
	ibt r0,#bank(RLImagesTable)
	romb
;
	if useHIGHDETAIL != 0
	lm !rDetailLevel,(DetailLevel&$FFFF)	; Get Detail Level
	endif
;
	%CACHEB(_RLBuildTraceObjs3)

;
;	* * * * * * *       PROCESS NEXT VISIBLE OBJECT       * * * * * * *
;
_TRO3S2200:
	inc !rVObj	; Move to VObj.Next
	inc !rVObj
;	to	r0
	ldw (!rVObj)	; Get VObj.Next
	moves !rVObj,r0
	beq _TRO3S9000-1	; No More VisibleObjects!
;
;	>>>   GET OBJPLOTDATA START/END   <<<
;
	ibt r1,#rlqObjPlotDataEnd
;	with	r0
	add r1
	to !rObjPlotDataEnd	; ObjPlotDataEnd
	ldw (r0)
	dec r0
	dec r0
	to !rObjPlotData	; ObjPlotDataStart
	ldw (r0)
;
;	>>>   ANY OBJ PLOTS TO PROCESS?   <<<
;
	from !rObjPlotData	; NO OBJ PLOT DATA?
	cmp !rObjPlotDataEnd
	beq _TRO3S2200	; NO!  Skip this VOBJ
	nop
;
;	>>>   GET IMAGERY POINTER   <<<
;
;	with	r0				; Image
	%sub_i((rlqObjPlotDataStart-rlqImage))
;	to	r0
	ldw (r0)
;	from	r0
	to !rRLImageData
	%add_i((rliData-rliHeight))
;
;	>>>   GET ASPECT ADJUSTED SCALE_INDEX   <<<
;
	to !rPixScale	; World Y
	ldw (!rVObj)
	iwt r6,#lo16(RLAspectRatio)	; Compensate for SNES<->PC Aspect Ratio
	from !rPixScale
;	to	r0
	fmult
;	with	r0
	add !rPixScale
;	with	r0
	add r0
;
;	from	r0				; Get SCN->RL Pixel Scaling Integer
	to !rPixScale
	hib
;	with	r0				; Get SCN->RL Pixel Scaling Fraction
	lob
;	with	r0
	swap
;	from	r0
	to !rPixScaleF
	lsr
;
;	>>>   GET SCREEN_XS1   <<<
;
	from !rVObj
;	to	r0
	%add_i(rlqXs1)
	to !rXs1
	ldw (r0)
;
;	>>>   GET IMAGE FLIP WIDTH   <<<
;
	ibt r0,#rlqFlipWidth
;	with	r0
	add !rVObj
	to !rFlipWidth
	ldb (r0)
;
	if useHIGHDETAIL != 0
	lm r0,(RLMinPixX2&$FFFF)	; Get Offset from Start of Draw
	endif
	if useHIGHDETAIL == 0
	lms r0,(RLMinPixX&$FFFF)	; Get Offset from Start of Draw
;	with	r0				; (low detail: X * 2)
	add r0
	endif
	with !rXs1
	sub r0
;
_TRO3S2600:

;
;	* * * * * * *       PROCESS VOBJ'S OBJPLOTDATA       * * * * * * *
;
_TRO3S4000:
	from !rObjPlotData	; At End?
;	to	r0				; @CMP@
	sub !rObjPlotDataEnd
	beq _TRO3S2200	; Yes!  No More ObjPlots
;
;	>>>   CALCULATE #PIXELSTEPS FROM START OF VOBJ   <<<
;
	inc !rObjPlotData	; Move to ScreenX Coordinate
	inc !rObjPlotData
;	to	r0
	ldb (!rObjPlotData)
	if useHIGHDETAIL == 0
;	with	r0
	add r0
	endif
;	from	r0				; R6 = #Pixels Offset from VObjStart
	to r6
	sub !rXs1
;
;	>>>   CALCULATE COLUMN OFFSET FROM START OF VOBJ   <<<
;
	from !rPixScaleF	; Fraction Columns Offset
;	to	r0
	fmult
;	with	r0
	rol
	from !rPixScale	; Integer Columns Offset
	to r1
	lmult
;	with	r0				; R0 = COLUMN OFFSET
	add r4
;
;	>>>   HANDLE IMAGE FLIPPING   <<<
;
	dec !rFlipWidth	; Flip Image?
	bmi _TRO3S5000	; No
	inc !rFlipWidth	; YES!
	from !rFlipWidth	; ImageStrip = (ImageWidth-ImageStrip)-1
;	to	r0
	sub r0
;
;	>>>   GET OFFSET TO IMAGE STRIP   <<<
;
_TRO3S5000:
;	with	r0				; Get Offset to Pointer to PixelStrip
	umult #3
	from !rRLImageData	; Move to correct pointer
	to r14
	add r0
;
;	>>>   GET POINTER TO IMAGE STRIP   <<<
;
	inc !rObjPlotData	; Move to ImageData
	inc !rObjPlotData
	from !rObjPlotData
	to r1
	%add_i((ploBank-ploData))
	getb
	inc r14
;	from	r0
	stb (!rObjPlotData)
	inc !rObjPlotData
	getb
	inc r14
;	from	r0
	stb (!rObjPlotData)
	with !rObjPlotData	; Move to next ObjPlotData
	%add_i((ploSize-(ploData+1)))
	getb
;
;	>>>   PROCESS NEXT OBJPLOTDATA   <<<
;
;	from	r0
;	stb	(r1)
	alt1
	bra _TRO3S4000
	stw (r1)

	%CACHEE(_RLBuildTraceObjs3)
