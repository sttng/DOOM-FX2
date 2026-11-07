	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                     ENGINE TRACE FLOORS MODULE 3                   *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildTraceFloors3


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD TRACE             CALCULATE FLOOR/CEILING COLOURMAPS  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       CALCULATE FLOOR/CEILING COLOURMAPS       * * * * * * *
;
	!rSectorLightMin = r5	; Minimum LightingLevel
	!rSectorLightMax = r7	; Maximum LightingLevel
	!rSectorNearData = r8	; Pointer to SectorNearData
	!rSectorNearFlags = !rSectorNearData	; SectorNearData Flags
	!rFloorPlotData = r9	; Pointer within FloorPlotData
	!rFloorPlotDataEnd = r10	; Pointer to End of FloorPlotData
	!rFloorsPtr = r11	; Pointer to Current FloorData
	!rFloorsPtrEnd = r12	; Pointer to End of FloorsData
	!rFloorHeight = r2	; Height of Floor/Ceiling
	!rInvulnerableCount = r3	; Invulnerability Count


	%align_pad(7, 16, (_RLBuildTraceFloors3-_TRF3S2200)&$0F)	; align 16,(_RLBuildTraceFloors3-_TRF3S2200)&$0f
_RLBuildTraceFloors3:
	lms r0,(TRObjPlotPtr&$FFFF)	; Start of Floors/Ceilings: after the ObjPlotData
	inc r0	; (word aligned, _RLBuildTraceFloors)
;	with	r0
	lsr
;	with	r0
	add r0
	iwt r1,#rlfdSize
	to !rFloorsPtr
	sub r1
	lms !rFloorsPtrEnd,(TRFloorsEnd&$FFFF)	; End of Floors/Ceilings
	lms !rInvulnerableCount,(InvulnerableCount&$FFFF)	; Invulnerability
;
	ibt r0,#bank(RLSCNPixScale)	; RL->SCN Pixel Scaling Table
	romb
;
	bra _TRF3S2000
	nop


;
;	* * * * * * *       COMPLETED FLOOR/CEILING COLOURMAPS       * * * * * * *
;
_TRF3S9000:
	lms !rFloorPlotData,(TRFloorsEnd&$FFFF)	; FLOOR PLOT DATA START
	lms !rFloorPlotDataEnd,(TRFloorPlotPtr&$FFFF)
	if !DEBUG != 0
	ibt r0,#0	; NO ERROR!
	sm (GSUERROR&$FFFF),r0
	endif
	if usePATCH != 0
	lms r0,(PTRLBuildDone&$FFFF)	; BUILD COMPLETED
	ibt r8,#bank(_RLBuildBSP)
	ljmp r8
	endif
	if usePATCH == 0
	stop
	endif
	nop


;
;	* * * * * * *       PROCESS NEXT FLOOR/CEILING       * * * * * * *
;
_TRF3S2000:
	%CACHEB(_RLBuildTraceFloors3)
_TRF3S2200:
	ibt r4,#rlfdSize	; Offset to Next Floor/Ceiling
_TRF3S2400:
	with !rFloorsPtr	; Move to Next Floor/Ceiling
	add r4
	from !rFloorsPtr	; At End?
;	to	r0				; @CMP@
	sub !rFloorsPtrEnd
	beq _TRF3S9000	; Yes!  No More Floors/Ceilings!
;
;	>>>   GET FLOORPLOTDATA START/END   <<<
;
	from !rFloorsPtr	; Move to FloorPlotDataEnd
;	to	r0
	%add_i(rlfdFloorPlotDataEnd)
	to !rFloorPlotDataEnd	; FloorPlotDataEnd
	ldw (r0)
	dec r0
	dec r0
	to !rFloorPlotData	; FloorPlotDataStart
	ldw (r0)

;
;	>>>   GET FLOOR/CEILING HEIGHT   <<<
;
	dec r0
	dec r0
	to !rFloorHeight
	ldw (r0)
;
;	>>>   GET SECTORNEAR_DATA   <<<
;
	to r6
	ldw (!rFloorsPtr)
	from r6	; Remove Floor/Ceiling KeyBit
	to !rSectorNearData
	lsr
;
;	>>>   CALCULATE LIGHT LEVEL RANGE   <<<
;
	inc !rSectorNearData	; Move to LightLevel
	to !rSectorLightMax	; Get Maximum LightLevel
	ldb (!rSectorNearData)
;
;	>>>   LIGHT CREATED BY WEAPON   <<<
;
	ibt r0,#lo16(LightAdjust)	; Get Light Adjustment
	assert (lo16(LightAdjust))&$FFFF < $80 || (lo16(LightAdjust))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;	to	r0
	ldb (r0)
	with !rSectorLightMax
	sub r0
	bpl _TRF3S3100+1
	from !rSectorLightMax	; Minimum Light Level
	ibt !rSectorLightMax,#0
_TRF3S3100:
	from !rSectorLightMax	; LightMin = (LightMax*2)+8
	to !rSectorLightMin	; (higher = darker)
	add !rSectorLightMax
	with !rSectorLightMin
	add #8
;
	if useFLOORS != 0
	iwt r0,#$00FF	; Underflow Darkness?
	endif
	if useFLOORS == 0
	iwt r0,#$00F7	; Underflow Darkness?
	endif
;	from	r0
	cmp !rSectorLightMin	; Underflow Darkness?
	bge _TRF3S3200	; No
	move !rSectorLightMin,r0	; Yes!
_TRF3S3200:
;
;	>>>   GET SECTORDATA_NEAR FLAGS   <<<
;
	dec !rSectorNearData	; Move to Flags
;	to	r0				; Get SectorFlags
	ldb (!rSectorNearData)
;	with	r0				; Move SKY Bit to $100
	add r0
;	with	r0				; $00=NORMAL,$01=SKY
	hib
;	from	r0				; FLOOR/CEILING MASK
	to !rSectorNearFlags
	and r6

;
;	* * * * * * *       PROCESS FLOOR/CEILING FLOORPLOTDATA       * * * * * * *
;
_TRF3S4000:
	from !rFloorPlotData	; At End?
;	to	r0				; @CMP@
	sub !rFloorPlotDataEnd
	beq _TRF3S2200	; Yes!  No More FloorPlots
;
;	>>>   REGULAR FLOOR/CEILING OR SKY?   <<<
;
	from !rSectorNearFlags
;	to	r0
	lsr
	bcc _TRF3S5200	; No
;
;	>>>   SKY   <<<
;
	with !rFloorPlotData	; ColourMap = 0 = SKY!
	%add_i(plfColourMap)
;	with	r0
	sub r0
	stb (!rFloorPlotData)
;
	with !rFloorPlotData	; Move to next FloorPlotData
	%add_i((plfSize-plfColourMap))
	bra _TRF3S4000+1
	from !rFloorPlotData	; R0 = Pixel Y Coordinate

;
;	>>>   NORMAL FLOOR/CEILING   <<<
;
_TRF3S5200:
	dec !rInvulnerableCount	; Invulnerability?
	bmi _TRF3S5300	; No
	inc !rInvulnerableCount	; YES!
	ibt r0,#lo16(hi16(RLColourMaps)+32)	; Invulnerable ColourMap
	bra _TRF3S7800

;
;	>>>   GET Y COORDINATE OF FLOORPLOTDATA   <<<
;
_TRF3S5300:
	from !rFloorPlotData	; R0 = Pixel Y Coordinate
;	to	r0
	%add_i(plfPixY)
;	to	r0
	ldb (r0)
;
;	>>>   GET SLOPE Y INVERSE TABLE ENTRY   <<<
;
;	with	r0				; Get Word Offset
	add r0
	iwt r1,#lo16(_RLSlopeYInvTable)	; Get Entry in SlopeYInvTable
;	with	r0
	add r1
	to r6	; R6 = SlopeYInverse[ScanLineY]
	ldw (r0)
;
;	>>>   GET HEIGHT OF FLOOR/CEILING   <<<
;
	moves r0,!rFloorHeight	; Get Height of Floor/Ceiling
	bpl _TRF3S5400
	nop
;	with	r0
	not
	inc r0
_TRF3S5400:
;	with	r0				; R0 = Distance
	lmult
;	with	r0
	lsr
	with r4
	ror
;	with	r0
	lob
	with r4
	hib
;	with	r0
	swap
;	with	r0
	or r4
;
	iwt r1,#RLMaxViewDistance	; Maximum Distance Away
;	from	r0
	cmp r1	; Distance > Max Distance?
	blt _TRF3S5600	; No
	nop
	move r0,r1	; Yes, use Maximum Distance
_TRF3S5600:
;
;	>>>   GET PIXEL SCALING RATIO   <<<
;
;	from	r0				; Get Long Index
	to r1
	add r0
;	with	r0
	add r1
	iwt r1,#lo16(RLSCNPixScale+2)	; Add Base of RL->SCN Pixel Scaling Table
;	from	r0
	to r14
	add r1
;
;	>>>   GET FLOORPLOT RL->SCN PIXEL SCALE INTEGER   <<<
;
;	to	r0				; Get Scale Whole
	getb
	dec r14
	dec r0
	bpl _TRF3S7500
;
	from !rSectorLightMin	; R6 = Range Light Level
	to r6
	sub !rSectorLightMax
;
	getbh	; Get Scale Fraction
	dec r14
	getbl
;
;	>>>   LIGHT_LEVEL = (MINIMUM_LEVEL - (SCALE * RANGE_LEVEL))   <<<
;
;	with	r0				; (Scale * RangeLevel)
	fmult	; r0 = Integer Result
;	with	r0
	rol
;
	from !rSectorLightMin	; (Minimum Level - (Scale*RangeLevel))
;	to	r0
	sub r0
;
;	>>>   ENSURE LIGHTING WITHIN RANGE   <<<
;
;	from	r0				; < Minimum Light Level?
	cmp !rSectorLightMin
	blt _TRF3S7400
	moves r0,!rSectorLightMin
_TRF3S7400:
;	from	r0				; > Maximum Light Level?
	cmp !rSectorLightMax
	bge _TRF3S7600
_TRF3S7500:
	moves r0,!rSectorLightMax
;
;	>>>   ADJUST LIGHT LEVEL TO COLOURMAP RANGE   <<<
;
_TRF3S7600:
;	with	r0				; Adjust to ColourMap Range
	lsr
;	with	r0
	lsr
;	with	r0
	lsr
	ibt r1,#lo16(hi16(RLColourMaps))	; Add Base of ColourMaps
;	with	r0
	add r1
;
;	>>>   SAVE COLOURMAP   <<<
;
_TRF3S7800:
	with !rFloorPlotData	; Move to ColourMap
	%add_i(plfColourMap)
;	from	r0				; Save Calculated ColourMap
	stb (!rFloorPlotData)

;
;	>>>   PROCESS NEXT FLOORPLOTDATA   <<<
;
	with !rFloorPlotData	; Move to next FloorPlotData
	%add_i((plfSize-plfColourMap))
;
	iwt r15,#lo16(_TRF3S4000)+1
	from !rFloorPlotData	; At End?

	%CACHEE(_RLBuildTraceFloors3)


	; plist OFF
