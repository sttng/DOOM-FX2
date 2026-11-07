	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                      ENGINE TRACE WALLS MODULE                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildTraceWalls


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD TRACE          TRACE WALL VSEGMENTS A - CALCULATIONS  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       TRACE WALL VISIBLE SEGMENTS       * * * * * * *
;
	!rVSeg = r4	; Pointer within VisibleSegment
	!rVSegEnd = r5	; Pointer to End of VisibleSegment List
	!rXsT = r6	; Current X/#Pixels Left
;
	!rYInvF = r7	; World Y Distance Inverse Fraction
	!rYInv = r8	; World Y Distance Inverse
	!rYInvStepF = r9	; World Y Distance Inv.Step Fraction
	!rYInvStep = r10	; World Y Distance Inv.Step
	!rY = r11	; World Y Distance
	!rYIndex = r12	; World Y ScaleIndex
;
	!rClipZonePtr = r2	; Pointer within ClipZoneData
	!rClipZonePtr0 = r3	; Pointer to Start of ALL ClipZoneData
;
	!rVSegMaxY = r13	; Maximum VisibleSegment World Y Distance


	%align_pad(11, 16, (_TRWS9000-_TRWS2000)&$0F)	; align 16,(_TRWS9000-_TRWS2000)&$0f
;
;	* * * * * * *       FINISHED TRACING WALL VISIBLE SEGMENTS       * * * * * * *
;
_TRWS9000:
	nop	; @FLUSH ALT1 IN CACHE@
	sms (TRClipZonePtr0&$FFFF),!rClipZonePtr0	; END of ClipZoneData
	sms (VSegMaxY&$FFFF),!rVSegMaxY	; Maximum Visible Segment WorldY
	iwt r0,#lo16(_RLBuildTraceWalls2)	; BUILD TRACE WALLS 2
	ibt r8,#bank(_RLBuildTraceWalls2)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	* * * * * * *       START TRACING WALL VISIBLE SEGMENTS       * * * * * * *
;
_RLBuildTraceWalls:

;
;	* * * * * * *       INITIALIZE VISIBLE SEGMENT YINVERSETABLE       * * * * * * *
;
_TRWS1200:
	ibt !rClipZonePtr0,#lo16(_RLVClipZone)	; Pointer to Start of VSegClipZone
	assert (lo16(_RLVClipZone))&$FFFF < $80 || (lo16(_RLVClipZone))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;
	iwt !rVSeg,#lo16(_RLVSegList-rlvSize+(rlvXsT+1))	; START of VisibleSegmentList
	lms !rVSegEnd,(VSegListEnd&$FFFF)	; END of VisibleSegmentList
	inc !rVSegEnd
;
	ibt !rVSegMaxY,#0	; Maximum VisibleSegment Y


	%CACHEB(_RLBuildTraceWalls)

;
;	* * * * * * *       HANDLE NEXT VISIBLE SEGMENT       * * * * * * *
;
_TRWS2000:
	ibt r1,#rlvSize	; Offset to Next VSEG
_TRWS2200:
	with !rVSeg	; Move to Next VSEG
	add r1
	from !rVSeg	; At End?
;	to	r0				; @CMP@
	sub !rVSegEnd
	beq _TRWS9000	; Yes!  No More Visible Segments!

;
;	* * * * * * *       PROCESS NEXT VISIBLE SEGMENT       * * * * * * *
;
;	>>>   GET #PIXELS TO TRACE   <<<
;
;	to	r0				; Get Xs1/XsCount
	ldb (!rVSeg)
;	from	r0
	to !rXsT
	sex
	bmi _TRWS2200+1	; THIS SEGMENT IS CLIPPED!
;
;	>>>   ALLOCATE SPACE IN CLIPZONE   <<<
;
	with !rVSeg
	%add_i((rlvClipZoneP-(rlvXsT+1)))
	from !rXsT	; Get #Pixels in VSeg
;	to	r0
	%umult_i(rlvczSize)
	with !rClipZonePtr0	; Allocate Space from ClipZoneData
	sub r0
	from !rClipZonePtr0
	stw (!rVSeg)
	move !rClipZonePtr,!rClipZonePtr0	; Pointer to Start of VSEG ClipZone
;
;	>>>   GET WORLD Y INVERSE STEP   <<<
;
	with !rVSeg	; Get WorldYInverseStep
	%add_i((rlvYInvStepF-rlvClipZoneP))
	to !rYInvStepF
	ldw (!rVSeg)
	inc !rVSeg
	inc !rVSeg
	to !rYInvStep
	ldw (!rVSeg)
;
;	>>>   GET WORLD Y INVERSE   <<<
;
	with !rVSeg	; Get WorldYInverse
	%sub_i((rlvYInvStep-rlvYInvF))
	to !rYInvF
	ldw (!rVSeg)
	inc !rVSeg
	inc !rVSeg
	to !rYInv
	ldw (!rVSeg)

;
;	* * * * * * *       MASTER TRACE PROCESSING LOOP       * * * * * * *
;
	ibt r0,#bank(InvTable)	; InverseTable Entry ROM Bank
	romb
;
;	>>>   CONVERT (1/DISTANCE) TO INVTABLE INDEX   <<<
;
_TRWS4000:
	from !rYInv	; Convert (1/Distance) From 32Bit
;	to	r0
	lob
;	with	r0
	swap
	from !rYInvF
	to r1
	hib
;	with	r0				; R0 = ((YInv<<8)+YInvF)
	or r1
;	with	r0				; RY = (R0<<2)
	add r0
;	from	r0
	to !rY
	add r0
;
	iwt r1,#lo16(_TRWSInvRangeCode)	; InverseRange Code
	from !rYInv	; Determine Inverse Range
;	to	r0
	add !rYInv
;	with	r0
	add r0
;	with	r0
	hib
	beq _TRWS4400
	nop
_TRWS4200:
;	with	r0
	lsr
	with !rY
	beq _TRWS4300
	ror
	bra _TRWS4200
_TRWS4300:
	dec r1
_TRWS4400:
	from !rY	; rY = ((rY>>2)<<1)
;	to	r0
	lsr
;	with	r0				; Get Word Index
	bic #1
;
;	>>>   GET WORLD Y DISTANCE   <<<
;
	iwt !rYIndex,#lo16(InvTable-2)	; Base of InverseTable
;	from	r0
	to r14
	add !rYIndex
;
;	to	r0				; Get Inverse Value
	getb
	inc r14
;	with	r0
	getbh
	move r15,r1	; Call InverseRangeCode
	nop
;
;	>>>   WARNING!!!   THE CODE BELOW MUST NOT BE MODIFIED!!!   <<<
;
	lsr	; >>8 ($2000-$3FFF)
	lsr	; >>7 ($1000-$1FFF)
	lsr	; >>6 ($800-$FFF)
	lsr	; >>5 ($400-$7FF)
	lsr	; >>4 ($200-$3FF)
	lsr	; >>3 ($100-$1FF)
	lsr	; >>2 ($080-$0FF)
	lsr	; >>1 ($040-$07F)
_TRWSInvRangeCode:
;
;	>>>   WORLD Y DISTANCE   <<<
;
;	from	r0				; WorldY > MaxWorldY?
	cmp !rVSegMaxY
	blt _TRWS5200
	inc !rClipZonePtr	; Move to World Y Distance
	move !rVSegMaxY,r0	; NEW MAXWORLDY!
_TRWS5200:
	inc !rClipZonePtr
;	from	r0				; Save World Y Distance
	stw (!rClipZonePtr)
	with !rClipZonePtr
	%add_i((rlvczSize-rlvczY))

;
;	* * * * * * *       NEXT TRACE STEP       * * * * * * *
;
;	>>>   NEXT Y_INVERSE STEP   <<<
;
	with !rYInvF	; YInv += YInvStep
	add !rYInvStepF
	with !rYInv
	adc !rYInvStep
;
;	>>>   NEXT PIXEL STEP   <<<
;
	dec !rXsT	; PixelCount--
	bne _TRWS4000+1	; Continue Stepping!
	from !rYInv	; Convert (1/Distance) From 32Bit
;
;	* * * * * * *       VISIBLE SEGMENT COMPLETED       * * * * * * *
;
;	>>>   SAVE WORLD Y INVERSE   <<<
;
;	from	rYInv
	stw (!rVSeg)
	dec !rVSeg
	dec !rVSeg
	ibt r0,#(rlvYInvF-(rlvXsT+1))
	from !rYInvF
	stw (!rVSeg)
	with !rVSeg
	sub r0
	iwt r15,#lo16(_TRWS2000)+1
	ibt r1,#rlvSize	; Offset to Next VSEG


	%CACHEE(_RLBuildTraceWalls)
