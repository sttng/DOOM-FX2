	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                     ENGINE TRACE OBJECTS MODULE                    *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildTraceObjs


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD TRACE                 TRACE OBJECTS A - CALCULATIONS  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       TRACE VISIBLE OBJECTS       * * * * * * *
;
	!rXs = r12	; Pixel X Coordinate
	!rYs = r14	; Pixel Y Coordinate
	!rNumDrawPixF = r5	; #Screen Pixels FractionCounter
	!rScale = r7	; RL->SCN Pixel Scaling Integer
	!rScaleF = r8	; RL->SCN Pixel Scaling Fraction
;rPixScale	equ	..		; SCN->RL Pixel Scaling Integer
;rPixScaleF	equ	..		; SCN->RL Pixel Scaling Fraction
	!rClipRangePtr = r9	; Pointer to current ClipRange
	!rObjPlotPtr = r10	; Pointer within ObjPlotData
;
	!rVSeg = r2	; Pointer to Current VisibleSegment
	!rVObj = r3	; Pointer to Current VisibleObject
	!rClipRangePtr = r9	; Pointer to Current ClipRange
	!rClipRange = r13	; Current ClipRange
	!rVObjY = !rClipRange	; VisibleObject WorldY
	!rVSegXs1 = r7	; VisibleSegment Xs1
	!rVSegXs2 = r8	; VisibleSegment Xs2
	!rXs2 = r5	; VisibleObject Xs2
	!rXsT = r2	; #Pixels to Scan
	!rVSegEnd = r14	; Pointer to End of VisibleSegmentList
	!rVSegMaxY = r12	; VisibleSegment Maximum WorldY


;
;	* * * * * * *       START TRACING VISIBLE OBJECTS       * * * * * * *
;
_RLBuildTraceObjs:
	if !RLMASKED
	link #4	; Masked middle textures: none drawn yet in this third
	iwt r15,#lo16(_TRMkReset)
	nop
	endif
;
;	* * * * * * *       INITIALIZE OBJPLOTDATA POINTER       * * * * * * *
;
	lms !rObjPlotPtr,(TRWallPlotPtr&$FFFF)	; END of WallPlotData (FREE MEMORY)
;	with	r0				; ObjPlotData End Terminator
	sub r0
;	from	r0
	stw (!rObjPlotPtr)
	inc !rObjPlotPtr
	inc !rObjPlotPtr
;
	iwt !rVObj,#lo16(VObjListStart-2)	; Start of VObjList
;
	iwt r11,#lo16(_TROS2200)
	bra _RLAddObjPlot0
	nop


	%align_pad(9, 16, (_TROS9000-_RLAddObjPlotAlign)&$0F)	; align 16,(_TROS9000-_RLAddObjPlotAlign)&$0f
;
;	* * * * * * *       FINISHED TRACING VISIBLE OBJECTS       * * * * * * *
;
_TROS9000:
	if !RLMASKED
	ibt r3,#0	; Masked middle textures not drawn yet: behind all objects
	link #4
	iwt r15,#lo16(_TRMkScan)
	nop
	endif
	dec !rObjPlotPtr	; Save End of ObjPlotData
	dec !rObjPlotPtr
	sms (TRObjPlotPtr&$FFFF),!rObjPlotPtr
;
	iwt r0,#lo16(_RLBuildTraceObjs2)	; BUILD TRACE OBJS 2
	ibt r8,#bank(_RLBuildTraceObjs2)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop


;
;	* * * * * * *       ADD OBJ PLOT       * * * * * * *
;
;	r6	=	World Z Bottom of Object
;	r1	=	World Height of Object
;	r7/r8 = RL->SCN Scale, r12 = Xs, r13 = ClipRange, r10 = ObjPlotPtr,
;	TRPixScale = SCN->RL Scale, r11 = Return
;
_RLAddObjPlot0:
	%CACHEB(_RLAddObjPlot)
_RLAddObjPlotAlign:
_RLAO9000:
	jmp r11	; Return to Caller
_RLAddObjPlot:
;
;	>>>   CALCULATE PIXEL OFFSET TO BOTTOM OF OBJECT   <<<
;
	from !rScaleF	; Scale * WorldZ
;	to	r0
	lmult	; r0:r4 = Fractionary Result
	from r4
	to !rNumDrawPixF	; Save #Fractionary Pixels to Draw
	add r4
;	from	r0
	to !rYs
	rol
;
	from !rScale	; r0 = Integer result
;	to	r0
	lmult
	with r4	; r4 = #Screen Pixels
	add !rYs
;
	ibt !rYs,#(RLViewPixY-1)/2	; Add Yb, Flip around Center
;	with	r0
	sub r0
;	from	r0
	to !rNumDrawPixF
	sub !rNumDrawPixF
	with !rYs
	sbc r4
;
;	>>>   CLIP ABOVE TOP   <<<
;
_RLAO3000:
	from !rClipRange	; Get ClipRangeTop
;	to	r0
	lob
	from !rYs
;	to	r0				; @CMP@
	sub r0
	blt _RLAO9000	; BOTTOM OF OBJECT IS OFF TOP OF SCREEN!

;
;	>>>   CLIP BELOW BOTTOM   <<<
;
_RLAO3200:
	from !rClipRange	; Get ClipRangeBottom
;	to	r0
	hib
	from !rYs	; Get #Pixels off Bottom
	to r6
	sub r0
	dec r6
	bmi _RLAO5000	; None are off Bottom!
;	with	r0				; Default to NO PIXELS CLIPPED
	sub r0

;
;	>>>   MOVE THROUGH OBJECT IMAGE TO CORRECT POSITION   <<<
;
_RLAO4000:
	inc r6
	iwt r4,#lo16(TRPixScale+1)	; Get SCN->RL Pixel Scaling Integer
;	to	r0
	ldb (r4)
;	with	r0				; r0 = Integer Result
	lmult
	move !rYs,r4	; RYS = #World Pixels Off Bottom
;
	iwt r0,#lo16(TRPixScale)	; Get SCN->RL Pixel Scaling Fraction
;	to	r0
	ldb (r0)
;	with	r0
	swap
;	with	r0
	lsr
;	with	r0				; r0:r4 = Fraction
	lmult
	with r4
	add r4
;	with	r0
	rol
;
	with !rNumDrawPixF	; Add #Fractionary Pixels Off Bottom
	add r4
;	with	r0				; #Integer Pixels Off Bottom
	adc !rYs
;
	from !rClipRange	; Start Drawing at Bottom of Screen
	to !rYs
	hib

;
;	* * * * * * *       ADD OBJPLOT       * * * * * * *
;
;	R0 = OBJPLOT IMAGE PIXEL OFFSET
;
_RLAO5000:
;
;	>>>   GET NUMBER OF WORLD PIXELS TO PLOT   <<<
;
	from r1	; Adjust Height of this Object Piece
	to r6
	sub r0
	dec r6
	bmi _RLAO9000	; NOTHING TO DRAW!
;
;	>>>   BUILD OBJPLOT (IMAGE OFFSET)   <<<
;
	from r0	; @FROM IN PIPELINE TO AVOID ALT1@
	stb (!rObjPlotPtr)
	inc !rObjPlotPtr
	inc !rObjPlotPtr
;
;	>>>  GET #PIXELS TO PLOT   <<<
;
	from !rScale	; r1 = Integer Result
	to r1
	umult r6
;
;	>>>   BUILD OBJPLOT (XS)   <<<
;
	from !rXs
	stb (!rObjPlotPtr)
;
	from !rScaleF	; r0:r4 = Fractionary Result
;	to	r0
	fmult
;	with	r0
	rol
;
;	with	r0
	add r1
	dec r0
	bmi _RLAO8200	; DONE!
;
;	>>>   CLIP #PIXELS TO PLOT AT TOP OF CLIPRANGE   <<<
;
	from !rClipRange	; R1 = ClipRange Top
	to r1
	lob
;
;	>>>   BUILD OBJPLOT (YS)   <<<
;
	inc !rObjPlotPtr
	from !rYs
	stb (!rObjPlotPtr)
	with !rObjPlotPtr
	%add_i((ploObjF-ploYs))
;
;	>>>   CLIP #PIXELS TO PLOT AT TOP OF CLIPRANGE   <<<
;
	from !rYs	; R1 = #Pixels from Current Y to ClipTop
	to r1
	sub r1
;
;	>>>   BUILD OBJPLOT (WORLD_Z DRAW FRACTION)   <<<
;
	with !rNumDrawPixF	; WorldZ DrawFraction
	hib
	from !rNumDrawPixF
	stb (!rObjPlotPtr)
	inc !rObjPlotPtr
;
;	from	r0				; Trying to plot too many pixels?
	cmp r1
	blt _RLAO6600	; No
	move r0,r1	; Yes, Use Maximum #Pixels Left
_RLAO6600:
;
;	>>>   BUILD OBJPLOT (NUMPIX)   <<<
;
	inc r0	; R0 = #Pixels to Plot
;	from	r0
	stb (!rObjPlotPtr)
	jmp r11	; Return to Caller
	inc !rObjPlotPtr
;
;	* * * * * * *       FINISHED THIS OBJPLOT       * * * * * * *
;
_RLAO8200:
	dec !rObjPlotPtr	; Discard this ObjPlot
	jmp r11
	dec !rObjPlotPtr


;
;	* * * * * * *       DISPLAY THIS VISIBLE OBJECT!       * * * * * * *
;
_TROS8000:
;
;	>>>   GET SCALE_INDEX   <<<
;
	ibt r0,#bank(RLSCNPixScale)	; Bank of RL<->SCN Pixel Scaling Tables
	romb
	to r1	; World Y
	ldw (!rVObj)
	from r1
;	to	r0
	add r1	; R0 = 2*Y = SCN->RL Pixel Scale

;
;	>>>   GET RL->SCN PIXEL SCALE   <<<
;
	iwt r4,#lo16(RLSCNPixScale)	; Add Base of RL->SCN Pixel Scaling Table
	with r1	; 3*Y (3 bytes per entry)
	add r0
	from r4
	to r14
	add r1
;
	if useHIGHDETAIL != 0
	lm r1,(RLMinPixX2&$FFFF)	; Get Offset from Start of Draw
	endif
	if useHIGHDETAIL == 0
	lms r1,(RLMinPixX&$FFFF)	; Get Offset from Start of Draw
	endif
;
	sms (TRPixScale&$FFFF),r0
;
	getb	; Get RL->SCN Pixel Scale
	inc r14
	to !rScaleF
	getbh
	inc r14
	to !rScale
	getb
;
	from !rXs2	; Get #Pixels to Scan
	to !rXsT
	sub !rXs
	inc !rXsT
	with !rXs	; Offset Starting Pixel
	sub r1
;
;	* * * * * * *       PROCESS NEXT OBJSTRIP       * * * * * * *
;
	iwt !rClipRangePtr,#lo16(_RLClipRange-2)	; Point to Start of ClipRange
_TROS8200:
	inc !rClipRangePtr	; Move to Next ClipRange
	inc !rClipRangePtr
	to !rClipRange	; Get Next ClipRange
	ldw (!rClipRangePtr)
	inc !rClipRange	; View Closed?
	beq _TROS8800	; Yes
	dec !rClipRange
;
	from !rVObj	; Get Object's Z Coordinate
;	to	r0
	%add_i(rlqWZ)
	to r6
	ldw (r0)
;
;	with	r0				; Get Object's Height
	%add_i((rlqHeight-rlqWZ))
	to r1
	ldb (r0)
;
	link #4
	iwt r15,#lo16(_RLAddObjPlot)	; AddObject
	nop
_TROS8800:
	dec !rXsT
	bne _TROS8200
	inc !rXs	; Next Pixel
;
;	>>>   SAVE POINTER TO END OF OBJPLOTDATA   <<<
;
	ibt r0,#rlqObjPlotDataEnd
;	with	r0
	add !rVObj
;	to	r0
	ldw (r0)
;	with	r0				; Any ObjPlots?
	sub !rObjPlotPtr
	beq _TROS2300	; No!
	from !rObjPlotPtr
	sbk
;
;	>>>   SAVE OBJPLOT GROUPHEADER (RL->SCN PIXEL SCALE/SCN->RL PIXEL SCALE)   <<<
;
	from !rScaleF	; RL->SCN Pixel Scale
	stw (!rObjPlotPtr)
	inc !rObjPlotPtr
	inc !rObjPlotPtr
	from !rScale
	stb (!rObjPlotPtr)
	inc !rObjPlotPtr
	inc !rObjPlotPtr
	lms r0,(TRPixScale&$FFFF)	; SCN->RL Pixel Scale
;	from	r0
	stw (!rObjPlotPtr)
	inc !rObjPlotPtr
	inc !rObjPlotPtr

;
;	* * * * * * *       HANDLE NEXT VISIBLE OBJECT       * * * * * * *
;
;	>>>   OBJPLOT GROUP TERMINATOR   <<<
;
_TROS2200:
	inc !rObjPlotPtr	; Mark End of ObjPlot Group
;	with	r0
	sub r0
;	from	r0
	stb (!rObjPlotPtr)
	inc !rObjPlotPtr
_TROS2300:
	if useHIGHDETAIL != 0
	iwt r0,#lo16(RLMinPixX2)	; Get LEFT EDGE
	endif
	if useHIGHDETAIL == 0
	ibt r0,#lo16(RLMinPixX)	; Get LEFT EDGE
	assert (lo16(RLMinPixX))&$FFFF < $80 || (lo16(RLMinPixX))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	endif
	to r4
	ldb (r0)
	if useHIGHDETAIL != 0
	iwt r0,#lo16(RLMaxPixX2)	; Get RIGHT EDGE
	endif
	if useHIGHDETAIL == 0
	ibt r0,#lo16(RLMaxPixX)	; Get RIGHT EDGE
	assert (lo16(RLMaxPixX))&$FFFF < $80 || (lo16(RLMaxPixX))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	endif
	to r6
	ldb (r0)
	lms !rVSegMaxY,(VSegMaxY&$FFFF)	; VisibleSegment Maximum WorldY
_TROS2400:
	inc !rVObj	; Move to VObj.Next
	inc !rVObj
;	to	r0
	ldw (!rVObj)	; Get VObj.Next
	moves !rVObj,r0
	bne _TROS3000	; Process Next VisibleObject
	to !rVObjY	; Get VObj.Y
	iwt r15,#lo16(_TROS9000)	; No More VisibleObjects!
;
;	>>>   GET VISIBLE OBJECT Y   <<<
;
_TROS3000:
;	to	rVObjY				; Get VObj.Y
	ldw (!rVObj)
;
;	>>>   SAVE POINTER TO START OF OBJPLOTDATA   <<<
;
	if !RLMASKED
	link #4	; Masked middle textures in front of this object first
	iwt r15,#lo16(_TRMkScan)	; (returns R0 = VObj.ObjPlotDataStart)
	nop
	else
	ibt r0,#rlqObjPlotDataStart
;	with	r0
	add !rVObj
	endif
	from !rObjPlotPtr
	stw (r0)
	inc r0
	inc r0
;
;	>>>   CLIP VISIBLE OBJECT AGAINST SIGHT DISTANCE   <<<
;
	from !rVObjY	; VObj.Y >= VSegMaxY?
	cmp !rVSegMaxY
;
;	>>>   SAVE POINTER TO END OF OBJPLOTDATA   <<<
;
	from !rObjPlotPtr
	bge _TROS2400	; Yes, Clip to AHEAD
	stw (r0)
;
;	>>>   CLIP VISIBLE OBJECT AGAINST SCREEN   <<<
;
	from !rVObj	; Get Xs1
	to r1
	%add_i(rlqXs1)
;
;	>>>   GET VISIBLE OBJECT X1/X2   <<<
;
;	to	r0
	ldw (r1)
	inc r0
;	with	r0
	asr
;	from	r0				; X1 Off Right?
	cmp r6
	bge _TROS2400	; Yes
	inc r1	; Get Xs2
	inc r1
	to !rXs2
	ldw (r1)
	from !rXs2	; X2 Off Left?
	cmp r4
	blt _TROS2400	; Yes
	from !rXs2	; X2 Off Right?
	cmp r6
	blt _TROS3300	; No
	dec r6
	move !rXs2,r6	; Yes, Clip to RIGHT
_TROS3300:
;	from	r0				; X1 Off Left?
	cmp r4
	bge _TROS3400	; No
	with r0
	with r4	; Yes, Clip to LEFT
_TROS3400:
	to !rXs	; @WITH IN PIPELINE@
;
;	>>>   INITIALIZE CLIPRANGE   <<<
;
	iwt r1,#lo16(_RLClipRange)	; Point to Start of ClipRange
	iwt r0,#(((RLViewPixY-1)<<8)|$00)	; Bottom.B / Top.B
	from !rXs2	; Get #ClipRanges to Initialize
	to r4
	sub !rXs
	inc r4
_TROS3800:
;	from	r0				; Default ClipRange
	stw (r1)
	inc r1	; Next ClipRangeEntry
	dec r4
	bne _TROS3800
	inc r1	; Next ClipRangeEntry
;
;	* * * * * * *       PROCESS NEXT VISIBLE SEGMENT       * * * * * * *
;
	iwt !rVSeg,#lo16(_RLVSegList-rlvSize+rlvXsT)	; START of VisibleSegmentList
	lms !rVSegEnd,(VSegListEnd&$FFFF)	; Get END of VisibleSegmentList
_TROS4200:
	ibt r4,#rlvSize	; Offset to Next VSEG
_TROS4400:
	with !rVSeg	; Move to Next VSEG
	add r4
	from !rVSeg	; At End?
;	to	r0				; @CMP@
	sub !rVSegEnd
	bne _TROS4600
;	to	r0				; Get Xs1/XsCount
	ldw (!rVSeg)
;
	iwt r15,#lo16(_TROS8000)	; No More VisibleSegments!
;
;	>>>   GET STARTING PIXEL/#PIXELS TO TRACE   <<<
;
_TROS4600:
;;	to	r0				; Get Xs1/XsCount
;	ldw	(rVSeg)
	moves r6,r0
	bmi _TROS4400	; THIS SEGMENT IS CLIPPED!
;
;	>>>   GET VISIBLE SEGMENT FLAGS   <<<
;
	from !rVSeg
;	to	r0
	%add_i((rlvFlags-rlvXsT))
;	to	r0
	ldw (r0)
;
;	>>>   IS THIS VISIBLE SEGMENT A CLIPPING SEGMENT?   <<<
;
	iwt r1,#(rlvfWALL|rlvfUPPERCLIP|rlvfLOWERCLIP)
;	from	r0
	to r1
	and r1
	beq _TROS4400	; NO!
;
;	>>>   DOES THIS VISIBLE SEGMENT OVERLAP THE OBJECT?   <<<
;
	from r6	; Get VSeg.Xs1
	to !rVSegXs1
	lob
	from r6	; R0 = VSeg.XsT
;	to	r0
	hib
;	from	r0				; Get VSeg.Xs2
	to !rVSegXs2
	add !rVSegXs1
	dec !rVSegXs2
	from !rVSegXs2	; VSeg.Xs2 < VObj.Xs1?
;	to	r0				; @CMP@
	sub !rXs
	blt _TROS4400	; Yes!
	from !rXs2	; VObj.Xs2 < VSeg.Xs1?
;	to	r0				; @CMP@
	sub !rVSegXs1
	blt _TROS4400	; Yes!
;
;	>>>   IS THIS VISIBLE SEGMENT BEHIND THE OBJECT?   <<<
;
	from !rVSeg	; Get VSeg.Y1
	to r1
	%add_i((rlvY1-rlvXsT))
;	to	r0
	ldw (r1)
	inc r1	; Move to VSeg.Y2
	inc r1
;
;	with	r0				; VSeg.Y1 > VObj.Y?
	sub !rVObjY	; @CMP@
;	to	r0				; Get VSeg.Y2
	ldw (r1)
;	with	r0				; VSeg.Y2 > VObj.Y?
	blt _TROS5200
	sub !rVObjY	; @CMP@
;
	bge _TROS4400+1	; Both behind: Next VSEG
	with !rVSeg	; Move to Next VSEG
	bra _TROS5400	; Y1>=VY, Y2<VY
	nop
;
;	>>>   IS THIS VISIBLE SEGMENT INFRONT OF THE OBJECT?   <<<
;
_TROS5200:
;	with	r0				; VSeg.Y2 < VObj.Y?
;	sub	rVObjY				; @CMP@
	bge _TROS5400	; No, It MAY Clip

;
;	* * * * * * *       THIS VISIBLE SEGMENT CLIPS THE OBJECT       * * * * * * *
;
_TROS7000:
	from !rVSeg	; Get Pointer to ClipZone
;	to	r0
	%add_i((rlvClipZoneP-rlvXsT))
	to r4
	ldw (r0)
;
;	>>>   IS THIS VISIBLE SEGMENT A SPRITE CLIPPING SEGMENT?   <<<
;
	from !rVSeg	; Get Flags
;	to	r0
	%add_i((rlvFlags-rlvXsT))
;	to	r0
	ldw (r0)
	iwt r1,#(rlvfNORMALSPRCLIP|rlvfUPPERSPRCLIP|rlvfLOWERSPRCLIP)
;	with	r0
	and r1
;
	from !rXs2	; Get #ClipRanges to Copy
	to r1
	beq _TROS7100
	sub !rXs
	with r4	; Move to ClipZone.ClipRangePostVSeg
	%add_i(rlvczClipRange2)
_TROS7100:
	iwt r6,#lo16(_RLClipRange)	; Destination ClipRange Area
	ibt r11,#rlvczSize
	from !rVSegXs1	; VObj Starts Before VSeg?
;	to	r0
	sub !rXs
	dec r0
	bmi _TROS7200
	inc r0
	with r1	; Width -= (VSeg-VObj)
	sub r0
;	with	r0				; ClipRange += (VSeg-VObj)
	add r0
	with r6
	bra _TROS7400
	add r0
_TROS7200:
	beq _TROS7400	; VObj Starts AT VSeg!
;	with	r0
	not
	inc r0
;	with	r0				; ClipZone += (VObj-VSeg)
	umult r11
	with r4
	add r0
_TROS7400:
	from !rXs2	; VObj Ends After VSeg?
;	to	r0
	sub !rVSegXs2
	dec r0
	bmi _TROS7800
	inc r0
	with r1	; Width -= (VObj-VSeg)
	sub r0
;
;	>>>   COPY CLIPPING RANGE FROM VISIBLE SEGMENT   <<<
;
_TROS7800:
	ldw (r4)	; Copy Next ClipRange
	stw (r6)
	inc r6
	with r4
	add r11
	dec r1
	bpl _TROS7800
	inc r6


;
;	>>>   PROCESS NEXT VISIBLE SEGMENT   <<<
;
_TROS7900:
	iwt r15,#lo16(_TROS4200)-1

;
;	>>>   IS THE SEGMENT INFRONT OF THE OBJECT?   <<<
;
_TROS5400:
;
;	>>>   CALCULATE CROSS PRODUCT OF <PARTITION> AND <OBJECT>   <<<
;
;			   (Xa * Yb) - (Ya * Xb)
;
;	= (DeltaX * (ObjectY-LineY)) - (DeltaY * (ObjectX-LineX))
;
	ibt r0,#(rlvVertex1-rlvXsT)	; Get Vertex1
;	with	r0
	add !rVSeg
	to r1
	ldw (r0)
	inc r0	; Get Vertex2
	inc r0
	to r11
	ldw (r0)
;
;	to	r0				; Get Vertex1 Y
	ldw (r1)
	inc r1
	inc r1
	to r6	; Get Vertex1 X
	ldw (r1)
;
	inc r11
	inc r11
	to r1	; Get Vertex2 X
	ldw (r11)
	from r1	; Get Delta X
	to r6
	sub r6
;
;	>>>   (Xa * Yb)   <<<
;
	to r1	; Get VObj.WorldY
	ldw (!rVObj)
;
	with r1	; (ObjectY - LineY)
	sub r0
	with r1	; Result in R1:R4
	lmult
;
	dec r11	; Get Vertex2 Y
	dec r11
	to r6
	ldw (r11)
	with r6	; Get DeltaY
	sub r0
;
	ibt r0,#(rlvVertex1-rlvXsT)	; Get Vertex1
;	with	r0
	add !rVSeg
;	to	r0
	ldw (r0)
;
	move r11,r4	; Result in R1:R11
;
	inc r0	; Get Vertex1X
	inc r0
;	to	r0
	ldw (r0)
;
	from !rVObj	; Get VObj.WorldX
	to r4
	%add_i(rlqWX)
	to r4	; R4 = ObjectX
	ldw (r4)
;
;	>>>   (Ya * Xb)   <<<
;
	from r4	; (ObjectX - LineX)
;	to	r0
	sub r0
;	with	r0				; Result in R0:R4
	lmult
;
;	>>>   DETERMINE DIRECTION OF NODE   <<<
;
;	IF RESULT >= 0, OBJECT IS TO THE LEFT OF THE NODE
;	IF RESULT <  0, OBJECT IS TO THE RIGHT OF THE NODE
;
	with r11	; Xa*Yb - Ya*Xb
	sub r4
	with r1
	sbc r0
;	dec	r1
	bmi _TROS7900+1	; < 0 RIGHT
	iwt r15,#lo16(_TROS7000)+1	; >= 0 = LEFT
	from !rVSeg	; Get Pointer to ClipZone



	%CACHEE(_RLAddObjPlot)


	if !RLMASKED
	assert useHIGHDETAIL == 0, "masked middle textures: low detail only"
;	******************************************************************
;	**								**
;	**  MASKED MIDDLE TEXTURES (this port)				**
;	**								**
;	******************************************************************
;
;	A masked middle texture (_RLMaskList entry, rlvsegs4.asm _RLBuildMaskList)
;	is drawn like an object: one ObjPlot group per screen column (own scale),
;	clipped to the VSeg's ClipZone range after the VSeg (the opening), with
;	the strip from the texture's image.  ObjPlot groups are drawn last first,
;	so an entry goes before (= is drawn after) the first object it is in
;	front of.  Bit 0 of rlmkVSeg = drawn in this third.
;
;	_TRMkReset:	mark all entries not drawn, TRMaskN = #entries; r11 = return
;			(at the start of each third: the VSegs and their ClipZones
;			are traced again for each third of the screen)
;	_TRMkScan:	r3 = VObj: draw the entries not drawn yet that overlap it
;			and are in front of it;  r3 = 0: draw all not drawn yet
;			r10 = ObjPlotPtr (updated), r11 = return
;	Returns with r13 = VObj.Y, r4/r6 = left/right edge, r12 = VSegMaxY
;	(the object loop's registers), r3 kept, r0 = r3 + rlqObjPlotDataStart.
;
_TRMkReset:
	iwt r1,#lo16(_RLMaskList)
	lm r2,(TRMaskEnd&$FFFF)
	ibt r3,#0	; #Entries
_TMR100:
	from r1
	cmp r2
	bcs _TMR900
	nop
	ldw (r1)	; VSeg, not drawn
	%bic_i(1)
	stw (r1)
	inc r3
	with r1
	%add_i(rlmkSize)
	bra _TMR100
	nop
_TMR900:
	sm (TRMaskN&$FFFF),r3
	jmp r11
	nop

_TRMkScan:
	lm r0,(TRMaskN&$FFFF)	; Any not drawn yet?
	dec r0
	bpl _TMS050
	nop
	ibt r0,#rlqObjPlotDataStart	; No: nothing changed
	add r3
	jmp r11
	nop
_TMS050:
	sm (TRMkRet&$FFFF),r11
	sm (TRMkVObj&$FFFF),r3
	iwt r0,#lo16(_RLMaskList)
	sm (TRMkE&$FFFF),r0
;	>>>   NEXT ENTRY   <<<
_TMS100:
	lm r0,(TRMkE&$FFFF)
	lm r1,(TRMaskEnd&$FFFF)
	cmp r1	; At End?
	bcc _TMS110
	nop
	iwt r15,#lo16(_TMS900)
	nop
_TMS110:
	move r9,r0	; R9 = Entry
	%add_i(rlmkSize)
	sm (TRMkE&$FFFF),r0
	to r2	; R2 = VSeg (+1 = drawn in this third)
	ldw (r9)
	from r2	; Drawn already?
	%and_i(1)
	bne _TMS100
	nop
	lm r3,(TRMkVObj&$FFFF)	; Drawing all?
	moves r3,r3
	bne _TMS200
	nop
	iwt r15,#lo16(_TMS500)
	nop
;	>>>   DOES THE VSEG OVERLAP THE OBJECT?   <<<
_TMS200:
	ibt r1,#rlqXs1
	with r1
	add r3
	to r6	; R6 = VObj.Xs1
	ldw (r1)
	inc r6
	with r6
	asr
	inc r1
	inc r1
	to r4	; R4 = VObj.Xs2
	ldw (r1)
	to r1	; R1 = VSeg.Xs1/XsCount
	ldw (r2)
	moves r1,r1	; VSeg clipped?
	bpl _TMS210
	nop
	iwt r15,#lo16(_TMS500)	; Yes: only mark it drawn
	nop
_TMS210:
	from r1	; R5 = VSeg.Xs1
	to r5
	lob
	from r4	; VObj.Xs2 < VSeg.Xs1?
	cmp r5
	blt _TMS100
	nop
	from r1	; VSeg.Xs2
	hib
	add r5
	dec r0
	cmp r6	; VSeg.Xs2 < VObj.Xs1?
	blt _TMS100
	nop
;	>>>   IS THE VSEG IN FRONT OF THE OBJECT? (as _TROS5400)   <<<
	ibt r0,#rlvVertex1	; Vertex1/Vertex2
	add r2
	to r1
	ldw (r0)
	inc r0
	inc r0
	to r11
	ldw (r0)
	ldw (r1)	; R0 = Vertex1 Y
	inc r1
	inc r1
	to r6	; R6 = Vertex1 X
	ldw (r1)
	inc r11
	inc r11
	to r1	; Vertex2 X
	ldw (r11)
	from r1	; R6 = DeltaX
	to r6
	sub r6
	to r1	; (ObjectY - LineY)
	ldw (r3)
	with r1
	sub r0
	with r1	; R1:R4 = DeltaX * (ObjectY - LineY)
	lmult
	dec r11	; Vertex2 Y
	dec r11
	to r6
	ldw (r11)
	with r6	; R6 = DeltaY
	sub r0
	ibt r0,#rlvVertex1
	add r2
	ldw (r0)
	move r11,r4
	inc r0	; Vertex1 X
	inc r0
	ldw (r0)
	ibt r4,#rlqWX	; ObjectX
	with r4
	add r3
	to r4
	ldw (r4)
	from r4	; (ObjectX - LineX)
	sub r0
	lmult	; R0:R4 = DeltaY * (ObjectX - LineX)
	with r11
	sub r4
	with r1
	sbc r0
	bpl _TMS500	; >= 0: the VSeg is in front of the object
	nop
	iwt r15,#lo16(_TMS100)
	nop

;	* * * * * * *       DRAW ENTRY R9 (VSEG R2)       * * * * * * *
_TMS500:
	from r2	; Mark drawn
	%or_i(1)
	stw (r9)
	lm r0,(TRMaskN&$FFFF)
	dec r0
	sm (TRMaskN&$FFFF),r0
	inc r9
	inc r9
	ldw (r9)	; Image
	sm (TRMkImg&$FFFF),r0
	inc r9
	inc r9
	ldw (r9)	; World Z Bottom
	sm (TRMkZ&$FFFF),r0
	inc r9
	inc r9
	ldw (r9)	; Height/Width-1
	sm (TRMkHW&$FFFF),r0
;	>>>   VSEG   <<<
	to r1	; Xs1/XsCount
	ldw (r2)
	from r1	; Clipped, or no columns in this third?
	hib
	beq _TMS505
	nop
	bpl _TMS510
	nop
_TMS505:
	iwt r15,#lo16(_TMS100)
	nop
_TMS510:
	ibt r0,#rlvClipZoneP	; R9 = ClipZone
	add r2
	to r9
	ldw (r0)
	ibt r0,#rlvRSAngle
	add r2
	to r4
	ldw (r0)
	sm (TRMkAng&$FFFF),r4
	inc r0
	inc r0
	to r4
	ldw (r0)
	sm (TRMkRSPD&$FFFF),r4
	inc r0
	inc r0
	to r4
	ldw (r0)
	sm (TRMkVTO&$FFFF),r4
	ibt r0,#rlvFaceOffsetX
	add r2
	to r4
	ldb (r0)
	sm (TRMkFOX&$FFFF),r4
;	>>>   LIGHT LEVEL RANGE (as _RLBuildTraceObjs2)   <<<
	ibt r0,#rlvSectorNearData
	add r2
	ldw (r0)
	inc r0	; Light Level
	to r5	; R5 = Maximum Level
	ldb (r0)
	ibt r0,#lo16(LightAdjust)	; Light created by the weapon
	ldb (r0)
	with r5
	sub r0
	bpl _TMS520
	nop
	ibt r5,#0
_TMS520:
	sm (TRMkLMax&$FFFF),r5
	from r5	; Minimum = Maximum + (Maximum*3/4)
	lsr
	to r4
	lsr
	add r4
	add r5
	move r4,r0
	hib	; Underflow darkness?
	beq _TMS530
	nop
	iwt r4,#255
_TMS530:
	sm (TRMkLMin&$FFFF),r4
	from r4	; Range
	sub r5
	sm (TRMkLRng&$FFFF),r0
;	>>>   COLUMNS   <<<
	from r1	; R2 = #Columns
	to r2
	hib
	from r1	; R3 = Xs
	to r3
	lob

;	* * * * * * *       NEXT COLUMN       * * * * * * *
_TMS600:
;	>>>   ROOM FOR IT? (keep $800 bytes below the ClipZones for the floors)   <<<
	lms r0,(TRClipZonePtr0&$FFFF)
	iwt r1,#$0800
	sub r1
	from !rObjPlotPtr
	cmp r0
	bcc _TMS610
	nop
	sub r0	; No: no more masked middle textures in this third
	sm (TRMaskN&$FFFF),r0
	iwt r15,#lo16(_TMS900)
	nop
_TMS610:
;	>>>   CLIP RANGE AFTER THE VSEG (THE OPENING)   <<<
	from r9
	%add_i(rlvczClipRange2)
	to !rClipRange
	ldw (r0)
	inc !rClipRange	; View Closed?
	bne _TMS620
	dec !rClipRange
	iwt r15,#lo16(_TMS680)
	nop
_TMS620:
;	>>>   SCALE   <<<
	from r9	; World Y
	%add_i(rlvczY)
	ldw (r0)
	to r1	; SCN->RL Pixel Scale = 2*Y
	add r0
	sms (TRPixScale&$FFFF),r1
	with r1	; 3*Y
	add r0
	ibt r0,#bank(RLSCNPixScale)
	romb
	iwt r14,#lo16(RLSCNPixScale)
	with r14
	add r1
	getb
	inc r14
	to !rScaleF
	getbh
	inc r14
	to !rScale
	getb
;	>>>   SCREEN X / WORLD Z / HEIGHT   <<<
	lms r0,(RLMinPixX&$FFFF)
	from r3
	to !rXs
	sub r0
	lm r6,(TRMkZ&$FFFF)
	lm r1,(TRMkHW&$FFFF)
	with r1
	lob
	sm (TRMkOld&$FFFF),!rObjPlotPtr
	link #4
	iwt r15,#lo16(_RLAddObjPlot)
	nop
	lm r0,(TRMkOld&$FFFF)	; ObjPlot added?
	cmp !rObjPlotPtr
	bne _TMS630
	nop
	iwt r15,#lo16(_TMS680)
	nop
_TMS630:
;	>>>   TEXTURE COLUMN (as _RLBuildTraceWalls5)   <<<
	ibt r0,#bank(ScreenXAngleTable)
	romb
	from r3
	add r3
	iwt r1,#lo16(ScreenXAngleTable)
	to r14
	add r1
	getb
	inc r14
	getbh
	lm r1,(TRMkAng&$FFFF)	; ANGLE=(VIEWANGLE-ROTATED SEGMENT ANGLE)
	sub r1
	lsr
	lsr
	lsr
	lsr
	lsr
	lsr
	to r1
	add r0
	ibt r0,#bank(TanTable)
	romb
	iwt r0,#lo16(TanTable)
	to r14
	add r1
	getb
	inc r14
	to r6
	getbh
	lm r0,(TRMkRSPD&$FFFF)	; RSPD*TAN(ANGLE)
	lmult
	lob
	with r4
	hib
	swap
	with r4
	add r0
	lm r0,(TRMkVTO&$FFFF)	; TEXTURE COLUMN=(VTOffset-VxTOffset)+FaceOffset
	sub r4
	lm r1,(TRMkFOX&$FFFF)
	add r1
	lm r1,(TRMkHW&$FFFF)
	with r1
	hib
	and r1
;	>>>   IMAGE STRIP   <<<
	umult #3
	lm r1,(TRMkImg&$FFFF)
	add r1
	to r1
	%add_i((rliData-rliHeight))
	ibt r0,#bank(RLImagesTable)
	romb
	move r14,r1
	from !rObjPlotPtr	; R1 = ObjPlot.Data
	to r1
	%sub_i((ploSize-ploData))
	getb
	inc r14
	getbh
	inc r14
	stw (r1)
	inc r1
	inc r1
	getb	; ObjPlot.Bank
	stb (r1)
	inc r1
;	>>>   COLOURMAP (as _RLBuildTraceObjs2)   <<<
	lms r0,(InvulnerableCount&$FFFF)	; Invulnerability?
	dec r0
	bmi _TMS640
	nop
	ibt r0,#lo16(hi16(RLColourMaps)+32)	; Invulnerable ColourMap
	bra _TMS670
	nop
_TMS640:
	lm r6,(TRMkLRng&$FFFF)	; LEVEL = (MINIMUM - (SCALE*RANGE)) + (RANGE/4)
	from !rScaleF
	fmult
	rol
	from !rScale
	to r4
	umult r6
	add r4
	lm r4,(TRMkLMin&$FFFF)
	from r4
	sub r0
	from r6
	to r5
	lsr
	with r5
	lsr
	add r5
	cmp r4	; > Minimum?
	blt _TMS650
	nop
	move r0,r4
_TMS650:
	lm r4,(TRMkLMax&$FFFF)	; < Maximum?
	cmp r4
	bge _TMS660
	nop
	move r0,r4
_TMS660:
	lsr
	lsr
	lsr
	ibt r4,#lo16(hi16(RLColourMaps))
	add r4
_TMS670:
	stb (r1)	; ObjPlot.ColourMap
;	>>>   OBJPLOT GROUPHEADER (RL->SCN PIXEL SCALE/SCN->RL PIXEL SCALE)   <<<
	from !rScaleF
	stw (!rObjPlotPtr)
	inc !rObjPlotPtr
	inc !rObjPlotPtr
	from !rScale
	stb (!rObjPlotPtr)
	inc !rObjPlotPtr
	inc !rObjPlotPtr
	lms r0,(TRPixScale&$FFFF)
	stw (!rObjPlotPtr)
	inc !rObjPlotPtr
	inc !rObjPlotPtr
;	>>>   OBJPLOT GROUP TERMINATOR   <<<
	inc !rObjPlotPtr
	sub r0
	stb (!rObjPlotPtr)
	inc !rObjPlotPtr
;	>>>   NEXT COLUMN   <<<
_TMS680:
	with r9
	%add_i(rlvczSize)
	inc r3
	dec r2
	beq _TMS690
	nop
	iwt r15,#lo16(_TMS600)
	nop
_TMS690:
	iwt r15,#lo16(_TMS100)
	nop

;	* * * * * * *       DONE: THE OBJECT LOOP'S REGISTERS   * * * * * * *
_TMS900:
	lm r3,(TRMkVObj&$FFFF)
	to !rVObjY
	ldw (r3)
	ibt r0,#lo16(RLMinPixX)	; LEFT EDGE
	to r4
	ldb (r0)
	ibt r0,#lo16(RLMaxPixX)	; RIGHT EDGE
	to r6
	ldb (r0)
	lms !rVSegMaxY,(VSegMaxY&$FFFF)
	lm r11,(TRMkRet&$FFFF)
	ibt r0,#rlqObjPlotDataStart	; R0 = VObj.ObjPlotDataStart
	add r3
	jmp r11
	nop
	endif
