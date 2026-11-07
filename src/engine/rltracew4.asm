	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                     ENGINE TRACE WALLS MODULE 4                    *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildTraceWalls4


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD TRACE                      CALCULATE WALL COLOURMAPS  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       CALCULATE WALL COLOURMAPS       * * * * * * *
;
	!rScaleF = r2	; RL->SCN Pixel Scaling Fraction
	!rScale = r3	; RL->SCN Pixel Scaling Integer
	!rSectorLightMin = r5	; Minimum LightingLevel
	!rSectorLightMax = r7	; Maximum LightingLevel
	!rSectorNearData = r8	; Pointer to SectorNearData
	!rWallPlotData = r9	; Pointer within WallPlotData
	!rWallPlotDataEnd = r10	; Pointer to End of WallPlotData
	!rVSeg = r11	; Pointer to Current VisibleSegment
	!rVSegEnd = r12	; Pointer to End of VisibleSegment List
	!rInvulnerableCount = r13	; Invulnerability Count


	%align_pad(15, 16, (_RLBuildTraceWalls4-_TRW4S2200)&$0F)	; align 16,(_RLBuildTraceWalls4-_TRW4S2200)&$0f
_RLBuildTraceWalls4:
	iwt !rVSeg,#lo16(_RLVSegList-rlvSize+rlvXsT)	; START of VSegList
	lms !rVSegEnd,(VSegListEnd&$FFFF)	; END of VSegList
;	move	r0,#rlvXsT
;	with	rVSegEnd
;	add	r0
	lms !rInvulnerableCount,(InvulnerableCount&$FFFF)	; Invulnerability
;
	%CACHEB(_RLBuildTraceWalls4)
;
;	* * * * * * *       PROCESS NEXT VISIBLE SEGMENT       * * * * * * *
;
_TRW4S2200:
	ibt r4,#rlvSize	; Offset to Next VSEG
	ibt r1,#(rlvWallPlotDataEnd-rlvSectorNearData)
	ibt r6,#(rlvWallPlotDataStart-rlvXsT)
	from !rVSeg	; Move to Next VSEG
_TRW4S2400:
	to !rVSeg	; @FROM IN PIPELINE@
	add r4
	from !rVSeg	; At End?
;	to	r0				; @CMP@
	sub !rVSegEnd
	beq _TRW4S9000	; Yes!  No More VisibleSegments!
;
;	>>>   GET STARTING PIXEL/#PIXELS TO TRACE   <<<
;
;	to	r0				; Get Xs1/XsCount
	ldw (!rVSeg)
	inc r0
	beq _TRW4S2400
;
;	>>>   MOVE TO WALLPLOTDATA START   <<<
;
	from !rVSeg
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
	cmp !rWallPlotDataEnd
	beq _TRW4S2400+1	; NO!  Skip this VSEG
	with !rVSeg	; Move to Next VSEG
;
;	>>>   MOVE TO SECTORNEAR_DATA   <<<
;
	with r0
	sub r1
;
;	>>>   GET SECTORNEAR_DATA   <<<
;
	to !rSectorNearData
	ldw (r0)
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
	bpl _TRW4S3100+1
	from !rSectorLightMax	; Minimum Light Level
	ibt !rSectorLightMax,#0
_TRW4S3100:
	from !rSectorLightMax	; Minimum Light Level
	to !rSectorLightMin	;    = (Level+(LowLevel))
	add !rSectorLightMax
;
	from !rSectorLightMin	; Underflow Darkness?
;	to	r0
	hib
	beq _TRW4S3200	; No
	nop
	iwt !rSectorLightMin,#255	; Yes!
_TRW4S3200:
	from !rSectorLightMin	; R6 = Range Light Level - 8 (>= 0)
;	to	r0
	sub !rSectorLightMax
;	from	r0
	to r6
	sub #8
	bpl _TRW4S4000+1
	from !rWallPlotData	; At End?
	ibt r6,#0

;
;	* * * * * * *       PROCESS VSEG'S WALLPLOTDATA       * * * * * * *
;
_TRW4S4000:
	from !rWallPlotData	; At End?
;	to	r0				; @CMP@
	sub !rWallPlotDataEnd
	beq _TRW4S2200	; Yes!  No More WallPlots
;
;	>>>   GET WALLPLOT RL->SCN PIXEL SCALING INTEGER   <<<
;
	with !rWallPlotData	; Get Scale
	%add_i(plwScale)
;
	dec !rInvulnerableCount	; Invulnerability?
	bmi _TRW2S4100	; No
	inc !rInvulnerableCount	; YES!
	ibt r0,#((RAMWALLCMAPS>>8)+32)&$FF	; Invulnerable ColourMap (this port: the walls' RAM copy, GSU RAM $71)
	with !rWallPlotData	; Move to ColourMap
	%sub_i((plwScale-plwColourMap))
	bra _TRW2S4800
;
_TRW2S4100:
	to !rScale
	ldb (!rWallPlotData)
;
	dec !rScale	; Scale >= 1.0?
	bpl _TRW4S4500	; Yes, Maximum Light Level
	inc !rWallPlotData
;
;	>>>   GET WALLPLOT RL->SCN PIXEL SCALING FRACTION   <<<
;
;	to	rScaleF				; Get ScaleF
	ldw (!rWallPlotData)
;
;	>>>   LIGHT_LEVEL = (MINIMUM_LEVEL - (SCALE * RANGE_LEVEL))   <<<
;
;	from	rScaleF				; (Scale * RangeLevel)
;	to	r0
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
	blt _TRW4S4400
	moves r0,!rSectorLightMin
_TRW4S4400:
;	from	r0				; > Maximum Light Level?
	cmp !rSectorLightMax
	bge _TRW4S4600
_TRW4S4500:
	moves r0,!rSectorLightMax
_TRW4S4600:
;
;	>>>   ADJUST LIGHT LEVEL TO COLOURMAP RANGE   <<<
;
;	with	r0				; Adjust to ColourMap Range
	lsr
;	with	r0
	lsr
;	with	r0
	lsr
	ibt r1,#(RAMWALLCMAPS>>8)&$FF	; Add Base of ColourMaps (this port: the walls' RAM copy, GSU RAM $71)
;	with	r0
	add r1
;
;	>>>   SAVE COLOURMAP   <<<
;
	with !rWallPlotData	; Move to ColourMap
	%sub_i((plwScaleF-plwColourMap))
_TRW2S4800:
;	from	r0				; Save Calculated ColourMap
	stb (!rWallPlotData)
;
;	>>>   PROCESS NEXT WALLPLOTDATA   <<<
;
	with !rWallPlotData	; Move to next WallPlotData
	%add_i((plwSize-plwColourMap))
	bra _TRW4S4000+1
	from !rWallPlotData	; At End?

;
;	* * * * * * *       COMPLETED CALCULATING WALL COLOURMAPS       * * * * * * *
;
_TRW4S9000:
	iwt r0,#lo16(_RLBuildTraceWalls5)	; BUILD TRACE WALLS 5
	ibt r8,#bank(_RLBuildTraceWalls5)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

	%CACHEE(_RLBuildTraceWalls4)
