	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                    ENGINE TRACE OBJECTS MODULE 2                   *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildTraceObjs2


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD TRACE                       CALCULATE OBJ COLOURMAPS  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       CALCULATE OBJ COLOURMAPS       * * * * * * *
;
	!rScaleF = r2	; RL->SCN Pixel Scaling Fraction
	!rScale = r3	; RL->SCN Pixel Scaling Integer
	!rSectorLightMin = r5	; Minimum LightingLevel
	!rSectorLightMax = r7	; Maximum LightingLevel
	!rSectorNearData = r8	; Pointer to SectorNearData
	!rObjPlotData = r9	; Pointer within ObjPlotData
	!rObjPlotDataEnd = r10	; Pointer to End of ObjPlotData
	!rVObj = r11	; Pointer to Current VisibleObject
	!rGlowLightLevel = r12	; Glowing LightingLevel
	!rInvulnerableCount = r13	; Invulnerability Count


	%align_pad(14, 16, (_TRO2S9000-_TRO2S2200)&$0F)	; align 16,(_TRO2S9000-_TRO2S2200)&$0f
;
;	* * * * * * *       COMPLETED CALCULATING OBJ COLOURMAPS       * * * * * * *
;
_TRO2S9000:
	iwt r0,#lo16(_RLBuildTraceObjs3)	; BUILD TRACE OBJS 3
	ibt r8,#bank(_RLBuildTraceObjs3)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	* * * * * * *       BEGIN CALCULATING OBJ COLOURMAPS       * * * * * * *
;
_RLBuildTraceObjs2:
	iwt !rVObj,#lo16(VObjListStart-1)	; START of VObjList
;
	ibt r0,#bank(_ObjData)	; Move to _ObjData Bank
	romb
	lms r0,(RLFrame&$FFFF)	; Get Total #Frames
;	with	r0
	add r0
;	with	r0
	add r0
	ibt r2,#$70
;	with	r0				; $00,$10,$20,$30,$40,$50,$60,$70
	and r2
	ibt r1,#$40
;	from	r0				; $00,$10,$20,$30
	cmp r1
	blt _TRO2S1200
	from r2	;		  $30,$20,$10,$00
;	to	r0
	sub r0
_TRO2S1200:
;	from	r0				; $00,$20,$40,$60,$60,$40,$20,$00
	to !rGlowLightLevel
	add r0
;
	lms !rInvulnerableCount,(InvulnerableCount&$FFFF)	; Invulnerability


	%CACHEB(_RLBuildTraceObjs2)
;
;	* * * * * * *       PROCESS NEXT VISIBLE OBJECT       * * * * * * *
;
_TRO2S2200:
	inc !rVObj	; Move to VObj.Next
;	to	r0
	ldw (!rVObj)	; Get VObj.Next
	moves !rVObj,r0
	beq _TRO2S9000	; No More VisibleObjects!
;
;	>>>   GET OBJECT   <<<
;
;	from	r0				; R2 = RLObject
	to r2
	%add_i(rlqObj)
;
;	>>>   GET OBJPLOTDATA START/END   <<<
;
	ibt r1,#rlqObjPlotDataStart
;	with	r0
	add r1
	to !rObjPlotData	; ObjPlotDataStart
	ldw (r0)
	inc r0
	inc r0
	to !rObjPlotDataEnd	; ObjPlotDataEnd
	ldw (r0)
;
;	>>>   ANY OBJ PLOTS TO PROCESS?   <<<
;
	from !rObjPlotData	; ANY OBJ PLOT DATA?
;	to	r0
	sub !rObjPlotDataEnd
	beq _TRO2S2200	; NO!  Skip this VOBJ
	inc !rVObj
;
;	>>>   GET OBJECT TYPE   <<<
;
	to r1	; Get RLObject
	ldw (r2)
	from r1
;	to	r0
	%add_i(rloType)
;	to	r0				; Get RLObject Type
	ldb (r0)
;	with	r0				; Get Offset into _ObjData
	%umult_i(rlodSize)
;
;	>>>   GET OBJECT FLAGS   <<<
;
	iwt r1,#lo16(_ObjData+rlodFlags+1)	; Add Base of _ObjData
;	from	r0				; Move to Object Flags
	to r14
	add r1
;
;	>>>   PLAYER OBJECT?   <<<
;
	dec r0	; Player Object?
	with r1
	bpl _TRO2S2400	; No, FlipWidth = 0!
	sub r1
	lms r15,(PTTRO2SPlayer&$FFFF)	; Yes, Determine FlipWidth
	nop
;
;	>>>   VISIBLE OBJECT IS DRAWN!   <<<
;
_TRO2S2400:
	if !RLSPECTRE != 0
	ibt r0,#((rlodfGlow|rlodfShine|rlodfShadow)>>8)	; Glow/Shine/Shadow Flags
	else
	ibt r0,#((rlodfGlow|rlodfShine)>>8)	; Glow/Shine Flags
	endif
	with r1	; Add Flags
	add r0
	ibt r0,#(rlqDrawn-rlqObj)	; Move to VObj.Drawn/FlipWidth
;	with	r0
	add r2
	from r1	; Mark VObj Drawn/FlipWidth!
	stw (r0)
	if !RLSPECTRE != 0
	ibt r0,#0	; Not a Shadow (yet)
	sms (TRObjFuzz&$FFFF),r0
	endif
;
;	>>>   NORMAL/GLOWING OBJECT?   <<<
;
	getb	; Get RLObject.Flags
;	with	r0				; Does RLObject Glow/Shine?
	and r1
	beq _TRO2S3000	; No, Normal Object
	from r2	; Move to SectorDataNear
;
;	>>>   GLOWING OBJECT   <<<
;
	if !RLSPECTRE != 0
	ibt r4,#(rlodfShadow>>8)	; SHADOW (Spectre, this port)?
	to r4
	and r4
	beq _TRO2S2450	; No, Glowing/Shining
	nop
	ibt r4,#1	; Yes: normal sector lighting, drawn as a shadow
	sms (TRObjFuzz&$FFFF),r4
	iwt r15,#lo16(_TRO2S3000)
	from r2	; Move to SectorDataNear
_TRO2S2450:
	endif
	with r0	; GLOWING/SHINING?
	%bic_i((rlodfGlow>>8))
	with !rSectorLightMin
	bne _TRO2S2500	; SHINING
	sub !rSectorLightMin
	move !rSectorLightMin,!rGlowLightLevel	; GLOWING
_TRO2S2500:
	with !rSectorLightMin
	bra _TRO2S4000
	to !rSectorLightMax

;
;	>>>   NORMAL OBJECT   <<<
;
_TRO2S3000:
;
;	>>>   GET SECTORNEAR_DATA   <<<
;
;	from	r2				; Move to SectorDataNear
;	to	r0
	%add_i((rlqSectorData-rlqObj))
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
	bpl _TRO2S3200+1
	from !rSectorLightMax	; Minimum Light Level
	ibt !rSectorLightMax,#0
_TRO2S3200:
	from !rSectorLightMax	; Get Level*3/4
;	to	r0
	lsr
;	from	r0
	to r4
	lsr
;	with	r0
	add r4
;	from	r0				; Minimum Light Level
	to !rSectorLightMin	;    = (Level+(LowLevel))
	add !rSectorLightMax
;
	from !rSectorLightMin	; Underflow Darkness?
;	to	r0
	hib
	beq _TRO2S3400	; No
	nop
	iwt !rSectorLightMin,#255	; Yes!
_TRO2S3400:
	from !rSectorLightMin	; R6 = Range Light Level
	to r6
	sub !rSectorLightMax
;
;	>>>   GET OBJPLOT RL->SCN PIXEL SCALE   <<<
;
	to !rScaleF
	ldw (!rObjPlotDataEnd)
	inc !rObjPlotDataEnd
	inc !rObjPlotDataEnd
	to !rScale
	ldb (!rObjPlotDataEnd)
	dec !rObjPlotDataEnd
	dec !rObjPlotDataEnd

;
;	* * * * * * *       PROCESS VOBJ'S OBJPLOTDATA       * * * * * * *
;
_TRO2S4000:
	from !rObjPlotData	; At End?
;	to	r0
	sub !rObjPlotDataEnd
	bne _TRO2S4050	; (long jump: the target is out of branch range)
	nop
	iwt r15,#lo16(_TRO2S2200-1)	; Yes!  No More ObjPlots
	nop
_TRO2S4050:
	with !rObjPlotData	; Move to ColourMap
	%add_i(ploColourMap)
;
;	>>>   INVULNERABILITY?   <<<
;
	dec !rInvulnerableCount	; Invulnerability?
	bmi _TRO2S4100	; No
	inc !rInvulnerableCount	; YES!
	ibt r0,#lo16(hi16(RLColourMaps)+32)	; Invulnerable ColourMap
	bra _TRO2S4800+1
	alt1

;
;	>>>   LIGHT_LEVEL = (MINIMUM_LEVEL - (SCALE * RANGE_LEVEL)) + (RANGE_LEVEL/4)   <<<
;
_TRO2S4100:
	from !rScaleF	; (Scale * RangeLevel)
;	to	r0
	fmult	; r0 = Fractionary Result
;	with	r0
	rol
	from !rScale
	to r4
	umult r6	; r4 = Integer Result
;	with	r0
	add r4
;
	from !rSectorLightMin	; (Minimum Level - (Scale*RangeLevel))
;	to	r0
	sub r0
;
	from r6	; +(RangeLevel/4)
	to r1
	lsr
	with r1
	lsr
;	with	r0
	add r1
;
;	>>>   ENSURE LIGHTING WITHIN RANGE   <<<
;
;	from	r0				; < Minimum Light Level?
	cmp !rSectorLightMin
	blt _TRO2S4400
	moves r0,!rSectorLightMin
_TRO2S4400:
;	from	r0				; > Maximum Light Level?
	cmp !rSectorLightMax
	bge _TRO2S4600
	moves r0,!rSectorLightMax
_TRO2S4600:
;
;	>>>   ADJUST LIGHT LEVEL TO COLOURMAP RANGE   <<<
;
;	with	r0				; Adjust to ColourMap Range
	lsr
;	with	r0
	lsr
;	with	r0
	lsr
	if !RLSPECTRE != 0
	lms r1,(TRObjFuzz&$FFFF)	; SHADOW?
	dec r1
	bmi _TRO2S4700	; No
	nop
	%add_i(6)	; Yes: 6 levels darker (PC DOOM's fuzz uses colourmap 6),
	ibt r1,#31	; at most the darkest map
	cmp r1
	blt _TRO2S4650
	nop
	move r0,r1
_TRO2S4650:
	ibt r1,#(lo16(hi16(RLColourMaps))&$7F)	; ColourMap page with bit 7 CLEAR
	bra _TRO2S4800	; = "draw as a shadow" for rldrawo
	add r1
_TRO2S4700:
	endif
	ibt r1,#lo16(hi16(RLColourMaps))	; Add Base of ColourMaps
;	with	r0
	add r1
;
;	>>>   SAVE COLOURMAP   <<<
;
_TRO2S4800:
;	from	r0				; Save Calculated ColourMap
	stb (!rObjPlotData)
;
;	>>>   PROCESS NEXT OBJPLOTDATA   <<<
;
	with !rObjPlotData	; Move to next ObjPlotData
	%add_i((ploSize-ploColourMap))
	bra _TRO2S4000+1
	from !rObjPlotData	; At End?


	%CACHEE(_RLBuildTraceObjs2)
