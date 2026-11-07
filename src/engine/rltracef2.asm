	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                    ENGINE TRACE FLOORS MODULE 2                    *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildTraceFloors2


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD TRACE                 CALCULATE FLOOR/CEILING RANGES  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       CALCULATE FLOOR/CEILING RANGES       * * * * * * *
;
	!rFloorStart = r14	; Pointer to Floor/Ceiling Range Data
	!rFloorsPtr = r9	; Pointer in Current Floor/Ceiling
	!rFloorsPtr0 = r8	; Pointer to Current Floor/Ceiling
	!rFloorPlotPtr = r10	; Pointer to FloorPlotData
;
	!rXs = r2	; Pixel X Coordinate
	!rYMin = r3	; Minimum Y Coordinate
	!rYMinCount = r4	; Minimum Y Update Count
	!rYMinFloorStart = r5	; Pointer to FloorStart[YMin]
	!rYMax = r6	; Maximum Y Coordinate
	!rYMaxCount = r13	; Maximum Y Update Count
	!rYMaxFloorStart = r7	; Pointer to FloorStart[YMax]
;
	!rSectorData = !rFloorsPtr0	; Pointer to VSeg.SectorData_Near



	%align_pad(11, 16, (_TRF2S9000-_TRF2S2200)&$0F)	; align 16,(_TRF2S9000-_TRF2S2200)&$0f
;
;	* * * * * * *       COMPLETED CALCULATING FLOOR/CEILING RANGES       * * * * * * *
;
_TRF2S9000:
	nop	; @FLUSH ALT2 IN CACHE@
;	with	r0					; FloorPlotData End Terminator
	sub r0
;	from	r0
	stb (!rFloorPlotPtr)
	sms (TRFloorPlotPtr&$FFFF),!rFloorPlotPtr	; Save End of FloorPlotData
	iwt r0,#lo16(_RLBuildTraceFloors3)	; BUILD TRACE FLOORS 3
	ibt r8,#bank(_RLBuildTraceFloors3)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop


;
;	* * * * * * *       START CALCULATING FLOOR/CEILING RANGES       * * * * * * *
;
_RLBuildTraceFloors2:
	lms r0,(TRObjPlotPtr&$FFFF)	; Start of Floors/Ceilings: after the ObjPlotData
	inc r0	; (word aligned, _RLBuildTraceFloors)
;	with	r0
	lsr
;	with	r0
	add r0
	iwt r1,#rlfdSize
	to !rFloorsPtr0
	sub r1
	iwt !rFloorStart,#lo16(_RLFloorStart)	; Start of FloorStart[Y]
	lms !rFloorPlotPtr,(TRFloorsEnd&$FFFF)	; Start of FloorPlotData: after the Floors

	%CACHEB(_RLBuildTraceFloors2)
;
;	* * * * * * *       PROCESS NEXT FLOOR/CEILING       * * * * * * *
;
_TRF2S2200:
	ibt r0,#rlfdSize	; Move to Next Floor/Ceiling
	with !rFloorsPtr0
	add r0
	lms r0,(TRFloorsEnd&$FFFF)	; End of Floors/Ceilings
;	with	r0				; At End?
	sub !rFloorsPtr0	; @CMP@
	beq _TRF2S9000	; Yes!  No More Floors/Ceilings!
;
;	* * * * * * *       PROCESS FIRST STRIP OF FLOOR/CEILING       * * * * * * *
;
	sms (TRFloorsPtr0&$FFFF),!rFloorsPtr0	; Save Current Floor/Ceiling
	from !rFloorsPtr0	; Move to Current Floor/Ceiling
	to !rFloorsPtr
	%add_i(rlfdMinX)
;
	to !rSectorData	; Get SectorData Pointer
	ldw (!rFloorsPtr0)
;
;	to	r0				; Get MinX/MaxX
	ldw (!rFloorsPtr)
;	from	r0
	to !rXs
	lob
;
;	>>>   SAVE STARTING POINTER TO FLOORPLOTDATA   <<<
;
	with !rFloorsPtr
	%add_i((rlfdFloorPlotDataStart-rlfdMinX))
	from !rFloorPlotPtr
	stw (!rFloorsPtr)
;
;	with	r0				; Get Count (MaxX-MinX+1)
	hib
;	from	r0
	to r12
	sub !rXs
	inc r12
;
	from !rXs	; Move to RangeData[MinX]
;	to	r0
	add !rXs
;	with	r0				; Move to RangeData
	%add_i((rlfdRange-rlfdFloorPlotDataStart))
	with !rFloorsPtr
	add r0
;
	from !rFloorsPtr	; Move to RangeData[MaxX+1]
;	to	r0
	add r12
;	with	r0
	add r12
;	move	r1,#((RLViewPixY<<8)|RLViewPixY) ; Close the View after MaxX
	ibt r1,#-1
	from r1
	stw (r0)
;
;	to	r0				; Get YMin/YMax
	ldw (!rFloorsPtr)

	if !useCHECKFLOORPLOTDATA != 0
	inc r0	; UNUSED RANGE?
	bne _TRF2S3200	; No, Used
	dec r0
;	move	r0,#-1
;	move	r0,#((RLViewPixY<<8)|RLViewPixY) ; Close the View after MaxX
;	HALTGSU	#$30				; ERROR!
	endif

;
;	>>>   INITIALIZE FIRST STRIP   <<<
;
_TRF2S3200:
;	from	r0				; Get First YMin
	to !rYMin
	lob
;	from	r0				; Get First YMax
	to !rYMax
	hib
;
	from !rYMin	; Get Pointer to FloorStart[YMin]
;	to	r0
	add !rFloorStart
;
	from !rYMax	; Get #FloorStarts
	to r1
	sub !rYMin
	inc r1
_TRF2S3400:
	from !rXs	; FloorStart[Y] = XMin
	stb (r0)
	dec r1
	bne _TRF2S3400
	inc r0	; Next FloorStart
;
	inc !rFloorsPtr	; Next YMin/YMax
	inc !rFloorsPtr
	inc !rXs	; Next PixelX

;
;	* * * * * * *       PROCESS REMAINING STRIPS OF FLOOR/CEILING       * * * * * * *
;
_TRF2S4200:
	from !rYMin	; Get Pointer to FloorStart[YMinOld]
	to !rYMinFloorStart
	add !rFloorStart
;
	from !rYMax	; Get Pointer to FloorStart[YMaxOld]
	to !rYMaxFloorStart
	add !rFloorStart
;
;	to	r0				; Get New YMin/YMax [Xs]
	ldw (!rFloorsPtr)
	inc r0	; UNUSED RANGE?
	bne _TRF2S4300	; No, Used
	dec r0
	iwt r0,#((RLViewPixY<<8)|RLViewPixY)	; Close the View after MaxX
_TRF2S4300:
;	from	r0				; r1 = YMax[Xs]
	to r1
	hib
;	with	r0				; r0 = YMin[Xs]
	lob
;
;	>>>   DOES NEW RANGE OVERLAP OLD RANGE?   <<<
;
	from r1	; YMaxNew < YMinOld?
	cmp !rYMin
	blt _TRF2S4400
	from !rYMax	; YMinNew > YMaxOld?
	cmp r0
	bge _TRF2S4600
;
;	>>>   NEW RANGE DOES NOT OVERLAP OLD RANGE   <<<
;
_TRF2S4400:
	from !rYMin	; YMaxCount = -((YMaxOld-YMinOld)+1)
	to !rYMaxCount
	sub !rYMax
	dec !rYMaxCount
;
	move !rYMin,r1	; YMinOld = YMaxNew+1
	inc !rYMin
;
	from !rYMin	; Get Pointer to FloorStart[YMinNew]
	to !rYMinFloorStart
	bra _TRF2S4800
	add !rFloorStart
;
;	>>>   NEW RANGE OVERLAPS OLD RANGE   <<<
;
_TRF2S4600:
	from r1	; YMaxCount = YMaxNew-YMaxOld
	to !rYMaxCount
	sub !rYMax
;
_TRF2S4800:
	from !rYMin	; YMinCount = YMinOld-YMinNew
	to !rYMinCount
	sub r0

;
;	* * * * * * *       UPDATE Y_MIN       * * * * * * *
;
_TRF2S5200:
	beq _TRF2S6000	; YMinCount = 0
	nop
	bmi _TRF2S5500	; YMinCount < 0, AddFloorPlots
	nop
;
;	>>>   START Y_MIN FLOORPLOTS   <<<
;
	dec !rYMin	; YMin--
	dec !rYMinFloorStart
	from !rXs	; FloorStart[YMin] = Xs
	stb (!rYMinFloorStart)
	bra _TRF2S5200
	dec !rYMinCount	; YMinCount--
;
;	>>>   FINISH Y_MIN FLOORPLOTS   <<<
;
_TRF2S5500:
;	to	r0				; Get FloorStart[YMin]
	ldb (!rYMinFloorStart)
	link #4	; AddFloorPlot
	iwt r15,#lo16(_RLAddFloorPlot)
	from !rYMin	; Get Y Coordinate
;
	inc !rYMin	; YMin++
	inc !rYMinFloorStart
	bra _TRF2S5200
	inc !rYMinCount	; YMinCount++


;
;	* * * * * * *       UPDATE Y_MAX       * * * * * * *
;
_TRF2S6000:
	moves !rYMaxCount,!rYMaxCount
_TRF2S6200:
	beq _TRF2S7000	; YMaxCount = 0
	nop
	bmi _TRF2S6500	; YMaxCount < 0, AddFloorPlots
	nop
;
;	>>>   START Y_MAX FLOORPLOTS   <<<
;
	inc !rYMax	; YMax++
	inc !rYMaxFloorStart
	from !rXs	; FloorStart[YMax] = Xs
	stb (!rYMaxFloorStart)
	bra _TRF2S6200
	dec !rYMaxCount	; YMaxCount--
;
;	>>>   FINISH Y_MAX FLOORPLOTS   <<<
;
_TRF2S6500:
;	to	r0				; Get FloorStart[YMax]
	ldb (!rYMaxFloorStart)
	link #4	; AddFloorPlot
	iwt r15,#lo16(_RLAddFloorPlot)
	from !rYMax	; Get Y Coordinate
;
	dec !rYMax	; YMax--
	dec !rYMaxFloorStart
	bra _TRF2S6200
	inc !rYMaxCount	; YMaxCount++

;
;	* * * * * * *       PROCESS THE NEXT FLOOR/CEILING STRIP       * * * * * * *
;
_TRF2S7000:
	dec r12	; Next Strip
	beq _TRF2S8000	; No More to do!
	inc !rXs	; Next PixelX
;	to	r0				; Get YMinNew/YMaxNew
	ldw (!rFloorsPtr)
	inc r0	; UNUSED RANGE?
	beq _TRF2S7500	; Yes!
	inc !rFloorsPtr	; Move to Next YMin/YMax
;
;	>>>   PROCESS NEXT STRIP!   <<<
;
	dec r0
;	from	r0				; Get Current YMin/YMax
	to !rYMax
	hib
;	from	r0
	to !rYMin
	lob
	bra _TRF2S4200
	inc !rFloorsPtr
;
;	>>>   LOCATE NEXT USED STRIP!   <<<
;
_TRF2S7400:
	inc !rXs	; Next PixelX
	inc !rFloorsPtr	; Next YMin/YMax
_TRF2S7500:
	dec r12	; Next Strip
	beq _TRF2S8000	; No More to do!
	inc !rFloorsPtr
;	to	r0				; Get YMinNew/YMaxNew
	ldw (!rFloorsPtr)
	inc r0	; UNUSED RANGE?
	beq _TRF2S7400	; Yes!
	dec r0
	iwt r15,#lo16(_TRF2S3200)+1	; START AS FIRST STRIP AGAIN!
	to !rYMin


;
;	* * * * * * *       PROCESS NEXT FLOOR/CEILING       * * * * * * *
;

;
;	>>>   SAVE ENDING POINTER TO FLOORPLOTDATA   <<<
;
_TRF2S8000:
	lms !rFloorsPtr0,(TRFloorsPtr0&$FFFF)	; Restore Current Floor/Ceiling
	from !rFloorsPtr0
;	to	r0
	%add_i(rlfdFloorPlotDataEnd)
	from !rFloorPlotPtr
	stw (r0)
;
	iwt r15,#lo16(_TRF2S2200)	; Process Next Floor/Ceiling


;
;	* * * * * * *       ADD FLOOR PLOT       * * * * * * *
;
;	r0		=	Starting Pixel X Coordinate
;	rXs		=	Ending Pixel X Coordinate
;	r(SOURCE)	=	Pixel Y Coordinate
;
_RLAddFloorPlot:
	if useFLOORS == 0
;
;	* * * * * * *       ADD DITHERED FLOORPLOT       * * * * * * *
;
;	>>>   GET STARTING X COORDINATE / STARTING Y COORDINATE   <<<
;
	to r1	; Starting Y Coordinate
	swap
	with r1	; Starting X Coordinate
	add r0
;
;	>>>  GET #PIXELS TO PLOT   <<<
;
	from !rXs	; #Pixels to Plot
;	to	r0
	sub r0
;
;	>>>   #PIXELS TO PLOT   <<<
;
;	from	r0				; Save #Pixels to Plot
	stb (!rFloorPlotPtr)
	inc !rFloorPlotPtr
	inc !rFloorPlotPtr
;
;	>>>   STARTING X COORDINATE / STARTING Y COORDINATE   <<<
;
	from r1
	stw (!rFloorPlotPtr)
	inc !rFloorPlotPtr
	inc !rFloorPlotPtr
;
;	>>>   FLOOR/CEILING TEXTURE   <<<
;
	from !rSectorData	; Get Floor/Ceiling Bit
;	to	r0
	lsr
;	with	r0				; Move to Correct Texture (Colour)
	%adc_i(rlsdFloorTexture)
;	from	r0
	stw (!rFloorPlotPtr)
	inc !rFloorPlotPtr
	inc !rFloorPlotPtr
;
;	>>>   THE FLOORPLOTDATA MUST END BELOW _RLPlotDataEnd   <<<
;
;	(this port) A plot that would reach the limit is taken back (that row of
;	the floor is not drawn).  Without the check, views with many floor/ceiling
;	rows (DOOM II MAP01, MAP14) run the data past $FFFF into the variables at
;	$70:0000.
;
	iwt r0,#lo16(_RLPlotDataEnd-1)	; (-1: the $00 end terminator)
	from !rFloorPlotPtr
	cmp r0
	bcc _RLAFP900	; Below the limit
	nop
	with !rFloorPlotPtr
	sub #6	; Take the plot back (6 bytes)
;
;	>>>   FINISHED THIS FLOORSTRIP   <<<
;
_RLAFP900:
	jmp r11	; Return to Caller
	nop
	endif

	if useFLOORS != 0
;
;	* * * * * * *       ADD TEXTURE MAPPED FLOORPLOT       * * * * * * *
;
;	>>>   GET STARTING X COORDINATE / STARTING Y COORDINATE   <<<
;
	to r1	; Starting Y Coordinate
	swap
	with r1	; Starting X Coordinate
	add r0
;
;	>>>  GET #PIXELS TO PLOT   <<<
;
	from !rXs	; #Pixels to Plot
;	to	r0
	sub r0
;
;	>>>   #PIXELS TO PLOT   <<<
;
;	from	r0				; Save #Pixels to Plot
	stb (!rFloorPlotPtr)
	inc !rFloorPlotPtr
	inc !rFloorPlotPtr
;
;	>>>   SCN->RL X PIXEL SCALE   <<<
;
	iwt r0,#$0100	; X PixelScale
	stw (!rFloorPlotPtr)
	inc !rFloorPlotPtr
	inc !rFloorPlotPtr
;
;	>>>   SCN->RL Y PIXEL SCALE   <<<
;
	iwt r0,#$0000	; Y PixelScale
	stw (!rFloorPlotPtr)
	inc !rFloorPlotPtr
	inc !rFloorPlotPtr
;
;	>>>   FLOOR/CEILING TEXTURE   <<<
;
	from !rSectorData	; Get Floor/Ceiling Bit
;	to	r0
	lsr
;	with	r0				; Move to Correct Texture (Colour)
	%adc_i(rlsdFloorTexture)
;	from	r0
	stw (!rFloorPlotPtr)
	inc !rFloorPlotPtr
	inc !rFloorPlotPtr
;
;	>>>   SCN->RL XY FRACTIONS   <<<
;
	iwt r0,#$0000	; X/Y Fractions
	stw (!rFloorPlotPtr)
	inc !rFloorPlotPtr
	inc !rFloorPlotPtr
;
;	>>>   STARTING X COORDINATE / STARTING Y COORDINATE   <<<
;
	from r1
	stw (!rFloorPlotPtr)
	inc !rFloorPlotPtr
;
;	>>>   FINISHED THIS FLOORSTRIP   <<<
;
	jmp r11	; Return to Caller
	inc !rFloorPlotPtr
	endif


	%CACHEE(_RLBuildTraceFloors2)
