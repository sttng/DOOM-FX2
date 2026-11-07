	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                      ENGINE TRACE FLOORS MODULE                    *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildTraceFloors


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD TRACE                  TRACE FLOOR/CEILING VSEGMENTS  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       TRACE FLOOR/CEILING VISIBLE SEGMENTS       * * * * * * *
;
	!rVSeg = r10	; Pointer within VisibleSegment
	!rVSegEnd = r12	; Pointer to End of VisibleSegment List
	!rVSegFlags = r13	; VisibleSegment Flags
;
	!rXs = r4	; Current Pixel X Coordinate
	!rXsT = r6	; PixelStep Counter
;
	!rClipZonePtr = r9	; Pointer within ClipZoneData
	!rClipRange = r8	; Current ClipRange Bottom.B / Top.B
	!rFloorY = r7	; FloorY.W
	!rCeilingY = !rFloorY	; CeilingY.W
;
	!rFloorCeilingPtr = r5	; Pointer to Current Floor/Ceiling
	!rFloorCeilingRange = r14	; Range of Floor/Ceiling Data
	!rCeilingPtr = r2	; Pointer to CeilingData
	!rFloorPtr = r3	; Pointer to FloorData


	%align_pad(9, 16, (_RLBuildTraceFloors-_RLAddFloorAlign)&$0F)	; align 16,(_RLBuildTraceFloors-_RLAddFloorAlign)&$0f
_RLBuildTraceFloors:
;
;	* * * * * * *       INITIALIZE FLOORS/CEILINGS       * * * * * * *
;
	lms r0,(TRObjPlotPtr&$FFFF)	; NO Floors/Ceilings Yet: they start after the
	inc r0	; ObjPlotData (word aligned)
;	with	r0
	lsr
;	with	r0
	add r0
	sms (TRFloorsEnd&$FFFF),r0
	lms r0,(TRClipZonePtr0&$FFFF)	; Last Floor/Ceiling must end below the ClipZones
	iwt r1,#rlfdSize	; (still read while tracing floors)
;	with	r0
	sub r1
	sms (TRFloorsPtr0&$FFFF),r0	; (free until _RLBuildTraceFloors2)
;	with	r0				; NO Starting Floor Yet
	sub r0
	sms (TRFloors&$FFFF),r0

;
;	* * * * * * *       INITIALIZE TRACING FLOOR/CEILING VISIBLE SEGMENTS       * * * * * * *
;
	iwt !rVSeg,#lo16(_RLVSegList-rlvSize+rlvXsT)	; START of VSegList
	lms !rVSegEnd,(VSegListEnd&$FFFF)	; END of VSegList
;	move	r0,#rlvXsT
;	with	rVSegEnd
;	add	r0
;
	iwt r11,#lo16(_TRFS2200)

_RLAddFloor0:
	%CACHEB(_RLAddFloor)
_RLAddFloorAlign:
	jmp r11
;
;	* * * * * * *       ADD FLOOR RANGE       * * * * * * *
;
;	r0	=	BottomY.B / TopY.B
;
;
;	* * * * * * *       ADD CEILING RANGE       * * * * * * *
;
;	r0	=	BottomY.B / TopY.B
;
_RLAddFloor:
_RLAddCeiling:
;
;	* * * * * * *       ADD FLOOR/CEILING RANGE       * * * * * * *
;
	moves !rFloorCeilingPtr,!rFloorCeilingPtr	; Pointer Already Valid?
	with r0	; Set up Floor/Ceiling Range
	bne _RLAF3000	; Yes
	to !rFloorCeilingRange
	iwt !rFloorCeilingPtr,#lo16(TRFloors+2)	; No, Scan from First Floor/Ceiling!
;
;	>>>   SCAN ALL AVAILABLE FLOORS   <<<
;
_RLAF2000:
	lms r1,(TRFloorCeilingKey&$FFFF)	; Get Key
_RLAF2200:
	dec !rFloorCeilingPtr	; Move to Next Floor/Ceiling
	dec !rFloorCeilingPtr
;	to	r0
	ldw (!rFloorCeilingPtr)
	moves r0,r0	; Floor/Ceiling Pointer Valid?
	beq _RLAF4000	; No
;
;	>>>   CORRECT FLOOR/CEILING?   <<<
;
	move !rFloorCeilingPtr,r0
;	with	r0				; Move to Key
	%sub_i((rlfdMinX-rlfdKey))
;	to	r0				; Get Floor/Ceiling Key
	ldw (r0)
;	with	r0				; Key Matches?
	sub r1	; @CMP@
	bne _RLAF2200	; No, Try Next Floor/Ceiling!
;
;	>>>   CHECK X COORDINATE RANGE OF FLOOR/CEILING   <<<
;
_RLAF3000:
	to r1	; Get Minimum X Coordinate
	ldb (!rFloorCeilingPtr)
	from !rXs	; X Within Range?
;	to	r0				; @CMP@
	sub r1
	bge _RLAF3200	; Yes
	from !rXs	; No, New Range
	stb (!rFloorCeilingPtr)
	bra _RLAF5000+1
	from !rXs	; Get X Coordinate
_RLAF3200:
	inc !rFloorCeilingPtr	; Get Maximum X Coordinate
	to r1
	ldb (!rFloorCeilingPtr)
	from r1	; X Within Range?
;	to	r0				; @CMP@
	sub !rXs
	bge _RLAF6000	; Yes
	from !rXs	; No, New Range
	stb (!rFloorCeilingPtr)
	bra _RLAF5000
	dec !rFloorCeilingPtr

;
;	>>>   CREATE A NEW FLOOR/CEILING   <<<
;
_RLAF4000:
	lms r0,(TRFloorsEnd&$FFFF)	; Get Pointer to End of FloorsData
;
;	>>>   NO ROOM FOR ANOTHER FLOOR/CEILING?   <<<
;
;	(this port) The Floors/Ceilings may use the room up to the ClipZones
;	(limit in TRFloorsPtr0).  When full, the strip is not drawn and the next
;	pixel scans again.  (Original: no check; a view with more floors/ceilings
;	than the fixed array held wrote over the wall plot data.)
;
	lms r1,(TRFloorsPtr0&$FFFF)
;	from	r0
	cmp r1
	bcs _RLAF4900	; Full!
	nop
;	from	r0				; Save Pointer in Previous Floor/Ceiling
	to r1
	%add_i(rlfdMinX)
	from r1
	stw (!rFloorCeilingPtr)
	move !rFloorCeilingPtr,r0
;
	lms r0,(TRFloorCeilingKey&$FFFF)	; Get Key
;	from	r0
	stw (!rFloorCeilingPtr)
	inc !rFloorCeilingPtr
	inc !rFloorCeilingPtr
;
;	with	r0				; No Next Pointer!
	sub r0
;	from	r0
	stw (!rFloorCeilingPtr)
;
	from !rFloorCeilingPtr	; Move to RangeData
	to r1
	%add_i((rlfdRange-rlfdNext))
;
;	>>>   INITIALIZE FLOOR/CEILING RANGE DATA   <<<
;
	if useHIGHDETAIL == 0
	ibt !rFloorCeilingPtr,#((RLViewPixX/3/2)+1)	; #Range Entries to Initialize
	endif
	if useHIGHDETAIL != 0
	ibt !rFloorCeilingPtr,#((RLViewPixX/3)+1)	; #Range Entries to Initialize
	endif
	ibt r0,#-1	; UnUsed Range Value
_RLAF4800:
	stw (r1)
	inc r1
	dec !rFloorCeilingPtr
	bne _RLAF4800
	inc r1
;
	lms !rFloorCeilingPtr,(TRFloorsEnd&$FFFF)	; Get Pointer to New Floor/Ceiling Data
	ibt r0,#rlfdSize
;	with	r0
	add !rFloorCeilingPtr
;	from	r0				; Save Updated Floors/Ceilings Pointer
	sbk
;
;	>>>   GET HEIGHT OF FLOOR/CEILING   <<<
;
	with !rFloorCeilingPtr	; Move to Floor/Ceiling Height
	%add_i(rlfdHeight)
	lms r0,(TRFloorCeilingKey&$FFFF)	; Get Key
;	from	r0				; Get Pointer to SectorData
	to r1
	lsr
;	with	r0				; Floor (0) or Ceiling (1)?
	and #1
;	with	r0				; Floor (0) or Ceiling (2)
	add r0
	inc r0	; Skip SectorData Flags/LightLevel
	inc r0
;	with	r0
	add r1
;	to	r0				; Get Height of Floor/Ceiling
	ldw (r0)
;
;	>>>   ADJUST HEIGHT TO VIEW   <<<
;
	lms r1,(ViewZ&$FFFF)	; Get View Z Coordinate
;	with	r0
	sub r1
;	from	r0
	stw (!rFloorCeilingPtr)
;
;	>>>   SET MINIMUM/MAXIMUM X COORDINATE RANGE   <<<
;
	from !rXs	; Get X Coordinate
;	to	r0
	swap
;	with	r0
	add !rXs
	dec !rFloorCeilingPtr
	dec !rFloorCeilingPtr
;	from	r0
	stw (!rFloorCeilingPtr)

;
;	>>>   ADD THIS RANGE TO THE FLOOR/CEILING   <<<
;
_RLAF5000:
	from !rXs	; Get X Coordinate
;	to	r0
	add !rXs
;	with	r0
	add !rFloorCeilingPtr
;	with	r0				; Skip Min/Max X Coordinates
	%add_i((rlfdRange-rlfdMinX))
	from !rFloorCeilingRange	; Get Floor/Ceiling Range
	stw (r0)
	jmp r11	; Return to Caller!
	nop

;
;	>>>   DOES THIS FLOOR ALREADY HAVE A RANGE?   <<<
;
_RLAF6000:
;	from	rXs
;	to	r0
	add !rXs
	dec !rFloorCeilingPtr
;	with	r0
	add !rFloorCeilingPtr
;	with	r0				; Skip Min/Max X Coordinates
	%add_i((rlfdRange-rlfdMinX))
;
;	>>>   IS THIS FLOOR/CEILING RANGE AVAILABLE?   <<<
;
	to r1	; Get Floor/Ceiling Range
	ldw (r0)
	inc r1
	beq _RLAF7000
	nop
	iwt r15,#lo16(_RLAF2000)	; Used!

;
;	>>>   ADD THIS RANGE TO THE FLOOR/CEILING   <<<
;
_RLAF7000:
	from !rFloorCeilingRange	; Get Floor/Ceiling Range
	sbk
	jmp r11	; Return to Caller!
	nop

;
;	>>>   FLOORS/CEILINGS FULL, DROP THIS STRIP   <<<
;
_RLAF4900:
	ibt !rFloorCeilingPtr,#0	; No Current Floor/Ceiling
	jmp r11	; Return to Caller!
	nop


;
;	* * * * * * *       FINISHED TRACING FLOOR/CEILING VISIBLE SEGMENTS       * * * * * * *
;
_TRFS9000:
	iwt r0,#lo16(_RLBuildTraceWalls4)	; BUILD TRACE WALLS 4
	ibt r8,#bank(_RLBuildTraceWalls4)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop


;
;	* * * * * * *       PROCESS NEXT VISIBLE SEGMENT       * * * * * * *
;
_TRFS2200:
	ibt r4,#rlvSize	; Offset to Next VSEG
_TRFS2400:
	with !rVSeg	; Move to Next VSEG
	add r4
	from !rVSeg	; At End?
;	to	r0				; @CMP@
	sub !rVSegEnd
	beq _TRFS9000	; Yes!  No More VisibleSegments!
;
;	>>>   GET STARTING PIXEL/#PIXELS TO TRACE   <<<
;
;	to	r0				; Get Xs1/XsCount
	ldw (!rVSeg)
	moves !rXsT,r0
	bmi _TRFS2400	; THIS SEGMENT IS CLIPPED!
;	from	r0				; Get Xs1
	to !rXs
	lob
	with !rXsT	; Get XsCount
	hib
	if useHIGHDETAIL != 0
	lm r0,(RLMinPixX2&$FFFF)	; Get Offset from Start of Draw
	endif
	if useHIGHDETAIL == 0
	lms r0,(RLMinPixX&$FFFF)	; Get Offset from Start of Draw
	endif
	with !rXs
	sub r0
;
;	>>>   GET VISIBLE SEGMENT FLAGS   <<<
;
	ibt r0,#rlvFlags	; Get VSegFlags
;	with	r0
	add !rVSeg
	to !rVSegFlags
	ldw (r0)
;
;	>>>   GET SECTORNEAR_DATA   <<<
;
	ibt r0,#rlvSectorNearData	; Get SectorNearData
;	with	r0
	add !rVSeg
;	to	r0
	ldw (r0)
;
;	>>>   CREATE FLOOR/CEILING KEYS   <<<
;
;	from	r0				; Get (SectorData << 1)
	to r1
	add r0
	sms (TRFloorKey&$FFFF),r1	; FLOOR KEY
	inc r1	; CEILING KEY
;
;	>>>   GET CLIPZONE POINTER   <<<
;
	ibt r0,#rlvClipZoneP	; Get ClipZoneP
;	with	r0
	add !rVSeg
	ibt !rFloorPtr,#0	; NO Current FLOOR
	to !rClipZonePtr
	ldw (r0)
;
;	>>>   SETUP FOR ADDFLOOR/ADDCEILING   <<<
;
	sms (TRCeilingKey&$FFFF),r1	; CEILING KEY
	with !rFloorPtr	; NO Current CEILING
	bra _TRFS10000
	to !rCeilingPtr


;
;	* * * * * * *       NEXT TRACE STEP       * * * * * * *
;
_TRFS90000:
	dec !rXsT	; PixelCount--
	beq _TRFS2200	; NO!  Finished this Segment!!
	inc !rXs	; Move to next Pixel
	with !rClipZonePtr	; Move to next ClipZone
	%add_i(rlvczSize)

;
;	* * * * * * *       MASTER TRACE PROCESSING LOOP       * * * * * * *
;
_TRFS10000:
	to !rClipRange	; Get Current ClipRange
	ldw (!rClipZonePtr)
	inc !rClipRange
	beq _TRFS90000	; View Closed!  Next Step!
	dec !rClipRange

;
;	* * * * * * *       TRACE CEILINGS/FLOORS       * * * * * * *
;
_TRFS20000:

;
;	* * * * * * *       TRACE CEILING       * * * * * * *
;
_TRFS30000:
	ibt r1,#rlvfADDCEILING
	from !rVSegFlags	; Adding Ceiling?
;	to	r0
	and r1
	beq _TRFS40000
;
;	>>>   GET CEILING SCREEN Y   <<<
;
	from !rClipZonePtr
;	to	r0
	%add_i(rlvczCeilingY)
	to !rCeilingY	; Get CeilingY.W
	ldw (r0)
;
;	>>>   CLIP CEILING TO VIEW BOTTOM   <<<
;
	from !rClipRange	; Get Bottom of View
;	to	r0
	hib
;	from	r0				; Bottom of View >= Top of Wall?
	cmp !rCeilingY
	bge _TRFS32000	; Yes
	move !rCeilingY,r0	; No!  Clip Against Bottom of View!
;
;	>>>   CLIP CEILING TO VIEW TOP   <<<
;
_TRFS32000:
	from !rClipRange	; Get Top of View
;	to	r0
	lob
	from !rCeilingY	; Top of View <= Top of Wall?
	cmp r0
	blt _TRFS40000	; No!  Clipped!
;
;	>>>   DETERMINE CEILING RANGE   <<<
;
	from !rCeilingY	; R1 = (Bottom.B << 8)
	to r1
	swap
;
;	>>>   SETUP FOR CEILING   <<<
;
	move !rFloorCeilingPtr,!rCeilingPtr
	lms r11,(TRCeilingKey&$FFFF)
	sms (TRFloorCeilingKey&$FFFF),r11
;
	link #4
	iwt r15,#lo16(_RLAddCeiling)	; AddCeiling
;	with	r0				; R0 = ((BottomY << 8) | TopY)
	or r1
;
	move !rCeilingPtr,!rFloorCeilingPtr


;
;	* * * * * * *       TRACE FLOOR       * * * * * * *
;
_TRFS40000:
	ibt r1,#rlvfADDFLOOR
	from !rVSegFlags	; Adding Floor?
;	to	r0
	and r1
	beq _TRFS90000
;
;	>>>   GET FLOOR SCREEN Y   <<<
;
	from !rClipZonePtr	; Get FloorY.W
;	to	r0
	%add_i(rlvczFloorY)
	to !rFloorY
	ldw (r0)
;
;	>>>   CLIP FLOOR TO VIEW TOP   <<<
;
	from !rClipRange	; Get Top of View
;	to	r0
	lob
	from !rFloorY	; Bottom of Wall >= Top of View?
	cmp r0
	bge _TRFS42000	; Yes
	move !rFloorY,r0	; No!  Clip Against Top of View!
;
;	>>>   CLIP FLOOR TO VIEW BOTTOM   <<<
;
_TRFS42000:
	from !rClipRange	; Get Bottom of View
;	to	r0
	hib
;	from	r0				; Bottom of Wall <= Bottom of View?
	cmp !rFloorY
	blt _TRFS90000	; No!  Clipped!
;
;	>>>   DETERMINE FLOOR RANGE   <<<
;
;	from	r0				; R1 = (Bottom.B << 8)
	to r1
	swap
	move r0,!rFloorY
;
;	>>>   SETUP FOR FLOOR   <<<
;
	move !rFloorCeilingPtr,!rFloorPtr
	lms r11,(TRFloorKey&$FFFF)
	sms (TRFloorCeilingKey&$FFFF),r11
;
	link #4
	iwt r15,#lo16(_RLAddFloor)	; AddFloor
;	with	r0				; R0 = ((BottomY << 8) | TopY)
	or r1
;
	move !rFloorPtr,!rFloorCeilingPtr
	iwt r15,#lo16(_TRFS90000)+1
	dec !rXsT	; PixelCount--


	%CACHEE(_RLAddFloor)
