	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       AUTOMAP VIEW DRAW MODULE                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"

	; public _RLDrawAutoMapA
	; public _RLDrawAutoMapB
	; public _RLDrawAutoMapC
	; public _RLDrawAutoMap


	%section(ENGINE)
;
;	* * * * * * *       INITIALIZE AUTOMAP       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitAutoMap:
	rep #$20		; mode 'A!'
	lda.w #0	; NOT in AUTOMAP
	sta.l AutoMapMode
	sta.b AutoMapModeOld
	lda.w #$2000	; AUTOMAP Default Scale Factor
	sta.l AutoMapScale
	rtl



	%section(ENGINE_GSUCODE)
	arch superfx

;
;	* * * * * * *       AUTOMAP DEFINITIONS       * * * * * * *
;

;
;	>>>   OBJECT'S TRIANGLE DIMENSIONS   <<<
;
	amObjectHeight = (oddPlayer/2)	; Tip of Triangle
	amObjectBase = (amObjectHeight*3/4)	; Base of Triangle

;
;	>>>   COLOURS FOR AUTOMAP DISPLAY   <<<
;
	amColourRed = $E1	; Solid Walls
	amColourBrown = $86	; Floor Height Change
	amColourYellow = $F2	; Ceiling Height Change
	amColourBlue = $E6	; Secrets
	amColourGray = $06	; ComputerMap
	amColourGreen = $73	; Objects


;
;	* * * * * * *       REALITY_ENGINE AUTOMAP       * * * * * * *
;
	!rLinePtr = r13	; Pointer to current LINE
	!rLineFlagsPtr = r10	; Pointer to Flags for current LINE
;
	!rVBase = r9	; Vertex Base
	!rV1 = r8	; Vertex1
	!rV2 = r7	; Vertex2
	!rVROMB = r5	; LINE/VERTEX ROMBs
;
	!rX1 = r2	; Vertex1 X Coordinate
	!rY1 = r3	; Vertex1 Y Coordinate
	!rX2 = !rV2	; Vertex2 X Coordinate
	!rY2 = !rV1	; Vertex2 Y Coordinate
	!rY1Temp = r11	; Temp for Vertex1 Y Coordinate
;
	!rDX = !rX2	; DeltaX
	!rDY = !rY2	; DeltaY
	!rdXF = !rY1	; DeltaX Fraction
	!rdYF = !rY1	; DeltaY Fraction
;
	!rSin = !rVROMB	; SIN Constant for Object Draw
	!rCos = !rVBase	; COS Constant for Object Draw
;
	!rMObjX = !rLinePtr
	!rMObjY = !rLineFlagsPtr


	%align_pad(12, 16, (_RLDrawAutoMapC-_DAM1000)&$0F)	; align 16,(_RLDrawAutoMapC-_DAM1000)&$0f
;
;	* * * * * * *       REALITY_ENGINE DRAW AUTOMAP       * * * * * * *
;
_RLDrawAutoMapC:
	iwt r2,#lo16(_RLDrawMiscC)	; _RLDrawSpritesC
	iwt r1,#(lo16(AMLevelText)+((RLCharX/3)*2))+2
	bra _RLDrawAutoMap
	nop
_RLDrawAutoMapB:
	iwt r2,#lo16(_RLDrawMiscB)	; _RLDrawSpritesB
	iwt r1,#(lo16(AMLevelText)+((RLCharX/3)*1))+1
	bra _RLDrawAutoMap
	nop
_RLDrawAutoMapA:
	iwt r2,#lo16(_RLDrawMiscA)	; _RLDrawSpritesA
	iwt r1,#(lo16(AMLevelText)+((RLCharX/3)*0))
_RLDrawAutoMap:
	sms (RLNextCode&$FFFF),r2	; Save Address of Next Code Jump
	sms (AMLevelTextPtr&$FFFF),r1	; Save Address of LevelText
;
;	>>>   CLEAR AUTOMAP AREA   <<<
;
	iwt r9,#lo16(_RLGSUChrDef)	; Point to Start of BitMap
	iwt r7,#((20-RLViewCharY)*64)	; Distance in bytes to next strip
	iwt r13,#lo16(_DAM1200)
	iwt r8,#(RLViewCharX/3)	; #Strips to clear


	%CACHEB(_RLDrawAutoMap)
_DAM1000:
	ibt r12,#RLViewCharY	; #Characters to clear
_DAM1200:
	iwt r0,#$00FF	; FillWord
;	from	r0				; Fill BitMap with Colour $81 (Black)
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;
;	with	r0				; FillWord
	sub r0
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;
	iwt r0,#$FF00	; FillWord
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	inc r9
;	from	r0
	stw (r9)
	inc r9
	loop
	inc r9
;
	with r9	; Move to next strip
	add r7
	dec r8	; Next Strip
	bne _DAM1000
	nop

	if useAUTOMAPROT != 0
;
;	>>>   GET ROTATIONAL SINE/COSINE CONSTANTS   <<<
;
	ibt r0,#bank(SinTable)	; Bank of SinTable
	romb
	lms r0,(ViewAngle&$FFFF)	; Get ViewAngle
	lsr
	lsr
	lsr
	lsr
	lsr	; >>5
	lsr	; Remove lowest bit
	add r0
	iwt r1,#$200
;	with	r0
	sub r1
	iwt r1,#$7FE
;	from	r0
	to r1
	and r1
	iwt r0,#lo16(SinTable)	; Add Base of SinTable
;	from	r0
	to r14
	add r1
	getb	; Get Sine from Table
	inc r14
	getbh
	sms (RLSin&$FFFF),r0
	iwt r0,#lo16(CosTable)	; Add Base of CosTable
;	from	r0
	to r14
	add r1
	getb	; Get CoSine from Table
	inc r14
	ibt r1,#lo16(EMBSP+2)	; Bank of EM Data
	assert (lo16(EMBSP+2))&$FFFF < $80 || (lo16(EMBSP+2))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	to !rVROMB
	ldb (r1)
	getbh
	sms (RLCos&$FFFF),r0
	endif
;
	bra _DAM1900
	nop

	%CACHEE(_RLDrawAutoMap)


	%align_pad(12, 16, (_DAM1900-_DAM2000)&$0F)	; align 16,(_DAM1900-_DAM2000)&$0f

;
;	* * * * * * *       DRAW AUTOMAP LINES       * * * * * * *
;
_DAM1900:
	lms !rVBase,(EMVERTEXES&$FFFF)	; Get Base Address of Vertexes Table
	lms !rLinePtr,(EMLINES&$FFFF)
	iwt !rLineFlagsPtr,#lo16(_RLLineFlags)
	lms r12,(EMNUMLINES&$FFFF)	; Get #Lines

	%CACHEB(_RLDrawAutoMap2)
;
;	>>>   NEXT LINE   <<<
;
_DAM2000:
	from !rVROMB	; Bank of VERTEXES
	romb
	to r6	; Get LINEFLAGS
	ldb (!rLineFlagsPtr)
;
;	>>>   GET LINE VERTEXES / FLAGS (level RAM $71)   <<<
;
	move r1,!rLinePtr
	ibt r0,#1
	ramb
	to !rV1	; Get VERTEX1
	ldw (r1)
	inc r1
	inc r1
	to !rV2	; Get VERTEX2
	ldw (r1)
	inc r1
	inc r1
	to r4	; Get LINEFLAGS (lo) / FLAGS2 (hi)
	ldw (r1)
	ibt r0,#0
	ramb
	ibt r1,#(rllfSolid|rllfMapped)
	with r6
	and r1
;
;	>>>   GET LINE FLAGS   <<<
;
	from r4	; Get LINEFLAGS
	lob
;	from	r0
	to r6
	or r6
	with r4	; R4 = FLAGS2
	hib
;
;	>>>   DON'T DRAW THIS LINE?   <<<
;
	ibt r1,#rllfDontDraw	; DON'T DRAW?
	from r6
;	to	r0
	and r1
	bne _DAM4800	; YES!  DON'T DRAW THIS LINE!
;
;	>>>   IS THIS LINE MAPPED?   <<<
;
	from r6	; MAPPED?
;	to	r0
	%and_i(rllfMapped)
	with r11	; NO COMPUTERMAP
	bne _DAM3000	; YES!  DRAW THIS LINE!
	sub r11
;
;	>>>   COMPUTER MAP?   <<<
;
	ibt r0,#lo16(ComputerMap)	; DOES PLAYER HAVE COMPUTERMAP?
	assert (lo16(ComputerMap))&$FFFF < $80 || (lo16(ComputerMap))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;	to	r0
	ldb (r0)
	dec r0
	bmi _DAM4800	; NO!  DON'T DRAW THIS LINE!
	inc r11	; COMPUTERMAP!
;
;	>>>   DRAW THIS AUTOMAP LINE   <<<
;
_DAM3000:
;
;	>>>   GET VERTEX COORDINATES   <<<
;
	from !rVBase	; VERTEX 1
	to r14
	add !rV1
	getb
	inc r14
	to !rX1
	getbh
	inc r14
	getb
	inc r14
	to !rY1
	getbh
	from !rVBase	; VERTEX 2
	to r14
	add !rV2
	getb
	inc r14
	to !rX2
	getbh
	inc r14
	getb
	inc r14
	to !rY2
	getbh
;
;	>>>   DETERMINE LINE COLOUR   <<<
;
;	>>>   SECRET?   <<<
;
	from r6	; SECRET?
;	to	r0
	%and_i(rllfSecret)
	beq _DAM3400
	from r6
	ibt r0,#((amColourRed<<1)&$FF)	; RED (>>1 by the lsr in the delay slot: amColourRed&$7F)
	bra _DAM4000
;
;	>>>   SOLID?   <<<
;
_DAM3400:
;	to	r0				; SOLID?
	lsr
	bcc _DAM3500-1
	ibt r0,#amColourRed	; RED
	bra _DAM4000
;
;	>>>   FLOOR HEIGHT CHANGE?   <<<
;
_DAM3500:
	from r4	; FLOOR HEIGHT CHANGE?
	to r1
	lsr
	bcc _DAM3600
	ibt r0,#amColourBrown	; BROWN
	bra _DAM4000+1
	dec r11	; COMPUTER MAP?
;
;	>>>   DOOR?   <<<
;
_DAM3600:
;	move	r0,#rllfDoor			; DOOR?
	db rllfDoor
;	with	r0
	and r6
	bne _DAM3800	; YELLOW
;
;	>>>   CEILING HEIGHT CHANGE?   <<<
;
	with r1	; CEILING HEIGHT CHANGE?
	lsr
	bcc _DAM4800-1	; NO!  DON'T DRAW LINE!
_DAM3800:
	ibt r0,#amColourYellow	; YELLOW

;
;	>>>   DRAW LINE   <<<
;
_DAM4000:
	dec r11	; COMPUTER MAP?
	bmi _DAM4200	; NO
	nop
	ibt r0,#amColourGray	; YES!  DRAW IN GRAY!
_DAM4200:
	link #4
	iwt r15,#lo16(_RLDrawAutoMapLine)	; Draw (X1,Y1) -> (X2,Y2)
;	from	r0				; LineColour
	color

;
;	>>>   NEXT LINE   <<<
;
_DAM4800:
	with !rLinePtr	; Next Line
	%add_i(rllSize)
	dec r12
	beq _DAM4900
	inc !rLineFlagsPtr	; Next LineFlags
	iwt r15,#lo16(_DAM2000)
	nop
_DAM4900:
	iwt r15,#lo16(_DAM5000)	; DRAW AUTOMAP OBJECTS
	nop


;
;	* * * * * * *       DRAW AUTOMAP LINE       * * * * * * *
;
;	rX1,rY1		Vertex 1 Coordinates
;	rX2,rY2		Vertex 2 Coordinates
;
_RLDrawAutoMapLine:
	move r14,r11	; Save Return Address!
;
;	>>>   TRANSLATE VERTEXES TO VIEW ORIGIN   <<<
;
	lms r0,(ViewX&$FFFF)	; View X Coordinate
	with !rX1
	sub r0
	with !rX2
	sub r0
	lms r0,(ViewY&$FFFF)	; View Y Coordinate
;	from	r0
	to !rY1
	sub !rY1
;	from	r0
	to !rY2
	sub !rY2

	if useAUTOMAPROT != 0
;
;	>>>   ROTATE VERTEXES BY (90DEGREES-VIEWANGLE)   <<<
;
;	ROTATED_Y = 	 sin(90deg.-ViewAngle) * (VertexX)
;			+cos(90deg.-ViewAngle) * (VertexY)
;
;	ROTATED_X = 	 cos(90deg.-ViewAngle) * (VertexX)
;			-sin(90deg.-ViewAngle) * (VertexY)
;
	lms r6,(RLSin&$FFFF)	; sin(90deg.-ViewAngle)
	from !rX1	; *Vertex X1
;	to	r0
	fmult
;	from	r0
	to !rY1Temp
	rol
;
	from !rY1	; *Vertex Y1
;	to	r0
	fmult
;	from	r0
	to r1
	rol
;
	lms r6,(RLCos&$FFFF)	; cos(90deg.-ViewAngle)
	from !rY1	; *Vertex Y1
;	to	r0
	fmult
;	with	r0
	rol
	from !rY1Temp	; Rotated Y1
	to !rY1
	add r0
;
	with !rX1	; *Vertex X1
	fmult
	with !rX1
	rol
	with !rX1	; Rotated X1
	sub r1
;
;	>>>   ROTATE VERTEX 2 BY (90DEGREES-VIEWANGLE)   <<<
;
	lms r6,(RLSin&$FFFF)	; sin(90deg.-ViewAngle)
	from !rX2	; *Vertex X2
;	to	r0
	fmult
;	from	r0
	to !rY1Temp
	rol
;
	from !rY2	; *Vertex Y2
;	to	r0
	fmult
;	from	r0
	to r1
	rol
;
	lms r6,(RLCos&$FFFF)	; cos(90deg.-ViewAngle)
	from !rY2	; *Vertex Y2
;	to	r0
	fmult
;	with	r0
	rol
	from !rY1Temp	; Rotated Y2
	to !rY2
	add r0
;
	with !rX2	; *Vertex X2
	fmult
	with !rX2
	rol
	with !rX2	; Rotated X2
	sub r1
	endif
;
	move r11,r14	; Set Return Address
;
;	>>>   SCALE VERTEXES   <<<
;
	lms r6,(AutoMapScale&$FFFF)	; ScaleFactor
	with !rX1	; Scale X1
	fmult
	with !rX1
	rol
	with !rY1	; Scale Y1
	fmult
	with !rY1
	rol
	with !rX2	; Scale X2
	fmult
	with !rX2
	rol
	with !rY2	; Scale Y2
	fmult
	with !rY2
	rol
;
;	>>>   ENSURE (X1,Y1) AT LEFT, (X2,Y2) AT RIGHT   <<<
;
	from !rX1	; Vertex1 LEFT of Vertex2?
;	to	r0				; @CMP@
	sub !rX2
	blt _DAML2000	; Yes
	from !rY1	; Yes, Vertex1 ABOVE Vertex2?
;	to	r0				; @CMP@
	bne _DAML1800	; Vertical Line?
	sub !rY2
	blt _DAML2000	; Yes
_DAML1800:
	move r0,!rX1	; Swap Vertex1 and Vertex2
	move !rX1,!rX2
	move !rX2,r0
	move r0,!rY1
	move !rY1,!rY2
	move !rY2,r0
;
;	>>>   CENTER VERTEXES   <<<
;
_DAML2000:
	ibt r0,#(RLViewPixX/2)	; Center X
	with !rX1
	add r0
	with !rX2
	add r0
	ibt r0,#(RLViewPixY/2)	; Center Y
	with !rY1
	add r0
	with !rY2
	add r0
;
;	>>>   ENSURE LINE VISIBLE   <<<
;
	lms r0,(RLMinPixX&$FFFF)	; PixX Minimum
	if useHIGHDETAIL == 0
;	with	r0
	add r0
	endif
	dec r0
;	with	r0				; X2 OFF LEFT EDGE?
	sub !rX2	; @CMP@
	bge _DAML9000	; Yes!
	nop
	lms r0,(RLMaxPixX&$FFFF)	; PixX Maximum
	if useHIGHDETAIL == 0
;	with	r0
	add r0
	endif
;	with	r0				; X1 OFF RIGHT EDGE?
	sub !rX1	; @CMP@
	dec r0
	bmi _DAML9000	; Yes!
;
	from !rY1	; Y1 AND Y2 OFF TOP EDGE?
;	to	r0
	and !rY2
	bmi _DAML9000-2	; Yes!
	iwt r0,#(RLViewPixY-1)	; Y1 OFF BOTTOM EDGE?
;	from	r0
	cmp !rY1
	bge _DAML2200	; No
;	with	r0				; Y2 OFF BOTTOM EDGE?
	sub !rY2	; @CMP@
	bge _DAML2200+1	; No
	with !rX2	; rDX!  (ALWAYS POSITIVE)
_DAML9000:
	jmp r11	; Return to Caller

;
;	>>>   GET DELTA X/Y   <<<
;
_DAML2200:
	with !rX2	; rDX!  (ALWAYS POSITIVE)
	sub !rX1
	with !rY2	; rDY!
	sub !rY1
;
;	>>>   INITIALIZE GSU PLOT COORDINATES   <<<
;
	lms r0,(RLMinPixX&$FFFF)	; PixX Minimum
	if useHIGHDETAIL == 0
;	with	r0
	add r0
	endif
	from !rX1	; Adjust X Coordinate
	to r1
	sub r0
	move r2,!rY1	; Y Coordinate
;
;	>>>   DY = 0   <<<
;
	moves !rDY,!rDY	; DY = 0?
	bne _DAML4000
;	with	r0
	sub r0
;	with	r0				; X1 < Left?
	sub r1
	bmi _DAML3200
	with !rDX	; Count -= (Left-X1)
	sub r0
	ibt r1,#0	; X1 = Left
_DAML3200:
	ibt r4,#((RLViewPixX/3)-1)	; PixX Maximum
	from r1	; R0 = X2
;	to	r0
	add !rDX
;	with	r0				; X2 > Right?
	sub r4
	bmi _DAML3800
	with !rDX	; Count -= (X2-Right)
	sub r0
_DAML3800:
	dec !rDX	; Count--
	bpl _DAML3800
	plot	; Plot Pixel
	jmp r11	; Return to Caller

;
;	>>>   DX = 0   <<<
;
_DAML4000:
	moves !rDX,!rDX	; DX = 0?
	bne _DAML5000
;;	with	r0
;	sub	r0
;	with	r0				; Y1 < Top?
	sub r2
	bmi _DAML4200
	with !rDY	; Count -= (Top-Y1)
	sub r0
	ibt r2,#0	; Y1 = Top
_DAML4200:
	iwt r4,#(RLViewPixY-1)	; Y2 > Bottom?
	from r2
;	to	r0
	add !rDY
;	with	r0
	sub r4
	bmi _DAML4800
	with !rDY	; Count -= (Y2-Bottom)
	sub r0
_DAML4800:
	plot	; Plot Pixel
	dec r1
	dec !rDY	; Count--
	bpl _DAML4800
	inc r2	; Y++
	jmp r11	; Return to Caller
;
;	>>>   GET |DX| AND |DY|   <<<
;
_DAML5000:
	moves r4,!rDY	; Get |dY|
	bpl _DAML5100
;	with	r0
	sub r0
;	from	r0
	to r4
	sub r4
;
;	>>>   |DX| > |DY|   <<<
;
_DAML5100:
	from !rDX	; |dX| > |dY| ?
;	to	r0				; @CMP@
	sub r4
	ibt r0,#bank(InvTable)	; Get InverseTable Entry
	romb
	iwt r0,#lo16(InvTable-2)
	bge _DAML5200
	from !rDX	; Get Word Index
	iwt r15,#lo16(_DAML7000)
;
;	>>>   GET (DY/DX)   <<<
;
_DAML5200:
;	from	rdX				; Get Word Index
	to r4
	add !rDX
;	from	r0
	to r14
	add r4
	dec r4
	dec r4
	getb	; Get Inverse Value
	inc r14
	with r4	; Which "gear" of Inverse?
	hib
;	from	r0
	to r6
	getbh
	bne _DAML5400	; "Low Gear"
	with !rDY
;
;	>>>   "HIGH GEAR" OF INVERSE   <<<
;
	lmult
	from r4
	to !rdYF
	add r4
	with !rDY
	bra _DAML5600
	rol
;
;	>>>   "LOW GEAR" OF INVERSE   <<<
;
_DAML5400:
	lmult
	with r4
	add r4
	with !rDY
	rol
	with r4
	add r4
	with !rDY
	rol
;
	from !rDY
;	to	r0
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0
	to !rdYF
	or r4
;
	from !rDY
;	to	r0
	hib
;	from	r0
	to !rDY
	sex
;
;	>>>   CLIP AT RIGHT   <<<
;
_DAML5600:
	from r1	; R0 = X2
;	to	r0
	add !rDX
	ibt r4,#((RLViewPixX/3)-1)	; PixX Maximum
;	with	r0				; X2 > Right?
	sub r4
	bmi _DAML6600
	with !rDX	; Count -= (X2-Right)
	sub r0
;
;	>>>   DRAW LINE   <<<
;
_DAML6600:
	ibt r6,#0	; Y Fraction Tally
	iwt r4,#RLViewPixY	; PixY Maximum
_DAML6700:
	from r2	; Y Coordinate > Bottom?
;	to	r0				; @CMP@
	sub r4
	with r6	; Y += dY
	bge _DAML6800
	add !rdYF
	from r1	; Either Coordinate Negative?
;	to	r0
	or r2
	bmi _DAML6800+1
	with r2
	plot
	dec r1
_DAML6800:
	with r2
	adc !rDY
	dec !rDX	; Count--
	bpl _DAML6700
	inc r1
_DAML6900:
	jmp r11	; Return to Caller

;
;	>>>   |DY| > |DX|   <<<
;
_DAML7000:
;
;	>>>   GET (DX/DY)   <<<
;
	with r4	; Get Word Index
	add r4
;	from	r0
	to r14
	add r4
	dec r4
	dec r4
	getb	; Get Inverse Value
	inc r14
	with r4	; Which "gear" of Inverse?
	hib
;	from	r0
	to r6
	getbh
	bne _DAML7400	; "Low Gear"
	with !rDX
;
;	>>>   "HIGH GEAR" OF INVERSE   <<<
;
	lmult
	from r4
	to !rdXF
	add r4
	with !rDX
	bra _DAML7600
	rol
;
;	>>>   "LOW GEAR" OF INVERSE   <<<
;
_DAML7400:
	lmult
	with r4
	add r4
	with !rDX
	rol
	with r4
	add r4
	with !rDX
	rol
;
	from !rDX
;	to	r0
	lob
;	with	r0
	swap
	with r4
	hib
;	from	r0
	to !rdXF
	or r4
;
	from !rDX
;	to	r0
	hib
;	from	r0
	to !rDX
	sex
;
;	>>>   LINE GOES DOWN   <<<
;
_DAML7600:
	iwt r4,#(RLViewPixY-1)	; PixY Maximum
	ibt r6,#0	; Y Fraction Tally
	moves !rDY,!rDY	; Line Goes UP or DOWN?
	from r2	; R0 = Y2
;	to	r0
	bmi _DAML9200	; UP!
	add !rDY
;
;	>>>   CLIP AT BOTTOM   <<<
;
;	with	r0				; Y2 > Bottom?
	sub r4
	bmi _DAML8600
	with !rDY	; Count -= (Y2-Bottom)
	sub r0
;
;	>>>   DRAW LINE   <<<
;
_DAML8600:
	ibt r4,#(RLViewPixX/3)	; PixX Maximum
_DAML8700:
	from r1	; X Coordinate > Right?
;	to	r0				; @CMP@
	sub r4
	bge _DAML8900
	from r1	; Either Coordinate Negative?
;	to	r0
	or r2
	with r6	; X += dX
	bmi _DAML8800
	add !rdXF
	plot
	dec r1
_DAML8800:
	with r1
	adc !rDX
	dec !rDY	; Count--
	bpl _DAML8700
	inc r2
_DAML8900:
	jmp r11	; Return to Caller
	nop

;
;	>>>   LINE GOES UP   <<<
;
_DAML9200:
;
;	>>>   CLIP AT TOP   <<<
;
	bpl _DAML9600
	dec !rDY
	with !rDY	; Count -= (Top-Y2)
	sub r0
;
;	>>>   DRAW LINE   <<<
;
_DAML9600:
	ibt r0,#(RLViewPixX/3)-1	; PixX Maximum
_DAML9700:
;	from	r0				; X Coordinate > Right?
	cmp r1
	blt _DAML9900
	moves r2,r2	; Y Coordinate < Top?
	bmi _DAML9900
	from r4	; Y Coordinate > Bottom?
	cmp r2
	blt _DAML9800+1
	with r6	; X += dX
	moves r1,r1	; X Coordinate Negative?
	bmi _DAML9800+1
	with r6	; X += dX
	plot
	dec r1
_DAML9800:
	with r6	; X += dX
	add !rdXF
	with r1
	adc !rDX
	inc !rDY	; Count--
	bmi _DAML9700
	dec r2
_DAML9900:
	jmp r11	; Return to Caller
	nop

	%CACHEE(_RLDrawAutoMap2)



;
;	* * * * * * *       DRAW AUTOMAP OBJECTS       * * * * * * *
;

;
;	>>>   DONE DRAWING AUTOMAP -- OVERLAY TEXT   <<<
;
_DAM9000:
	ibt r1,#0	; Draw Overlay Text
	iwt r2,#(RLViewCharY-1)*8
	lms r12,(AMLevelTextPtr&$FFFF)
	link #4
	iwt r15,#lo16(_RLText)
	nop
	lms r0,(RLNextCode&$FFFF)	; Begin Execution of Next Code
	ibt r8,#bank(_RLDrawMiscA)	; _RLDrawSpritesA
	ljmp r8
	nop

;
;	>>>   START DRAWING AUTOMAP OBJECTS   <<<
;
_DAM5000:
	ibt r0,#amColourGreen	; GREEN
;	from	r0
	color
	ibt r0,#bank(SinTable)	; Bank of SinTable
	romb
	lms r0,(RLNumMObjs&$FFFF)	; Get #MovableRLObjects
	sms (ENEnemy&$FFFF),r0
	iwt r1,#lo16(_RLMObjs)	; List of RLMovableObjects
	if useMULTIPLAYER == 0
	iwt r0,#lo16(PlayerObject)	; Start with Player RLObject
	endif
	if useMULTIPLAYER != 0
	lms r0,(MPPlayerObject&$FFFF)	; Start with Player RLObject
	endif
	bra _DAM6400
	nop
;
;	>>>   NEXT OBJECT   <<<
;
_DAM6000:
	ibt r0,#bank(SinTable)	; Bank of SinTable
	romb
	lms r1,(AMMObjPtr&$FFFF)
	lms r0,(ENEnemy&$FFFF)
	dec r0
	bra _DAM9000	; (only the player is drawn; bmi drew every MObj)
;	bmi	_DAM9000
;	from	r0
	sbk
_DAM6200:
;	to	r0				; Get Next MObj
	ldw (r1)
	inc r1
	inc r0
	beq _DAM6200	; End of MObjList!
	inc r1
_DAM6400:
	sms (AMMObjPtr&$FFFF),r1
;
;	>>>   DRAW NEXT OBJECT TRIANGLE   <<<
;
;	with	r0
	%add_i((rloX+2))
	to !rMObjX
	ldw (r0)
;	with	r0
	%add_i(((rloY+2)-(rloX+2)))
	to !rMObjY
	ldw (r0)
;	with	r0
	%add_i((rloAngle-(rloY+2)))
;	to	r0				; Get Object Angle
	ldw (r0)
;
;	>>>   GET ROTATIONAL SINE/COSINE CONSTANTS   <<<
;
	lsr
	lsr
	lsr
	lsr
	lsr	; >>5
	lsr	; Remove lowest bit
	add r0
	iwt r1,#$200
;	with	r0
	sub r1
	iwt r1,#$7FE
;	from	r0
	to r1
	and r1
	iwt r0,#lo16(SinTable)	; Add Base of SinTable
;	from	r0
	to r14
	add r1
	getb	; Get Sine from Table
	inc r14
;	from	r0
	to r6
	getbh
	iwt r0,#lo16(CosTable)	; Add Base of CosTable
;	from	r0
	to r14
	add r1
	getb	; Get CoSine from Table
	inc r14
;	from	r0
	to !rCos
	getbh
;
;	>>>   CALCULATE OBJECT'S TRIANGLE COORDINATES   <<<
;
	ibt !rY1,#(amObjectHeight/2)
	from !rY1	; *Vertex Y1
;	to	r0				; sin(90deg.-ViewAngle)
	fmult
;	with	r0
	rol
;	with	r0
	not
	inc r0
	move !rX1,r0
	move !rSin,r6
	move r6,!rCos	; cos(90deg.-ViewAngle)
	with !rY1	; *Vertex Y1
	fmult
	with !rY1
	rol
;
	from !rMObjX	; Object Vertex X1
;	to	r0
	add !rX1
	sms (AMObjX1&$FFFF),r0
	from !rMObjY	; Object Vertex Y1
;	to	r0
	add !rY1
	sms (AMObjY1&$FFFF),r0
;
	ibt !rX1,#-(amObjectBase/2)
	ibt !rY1,#-(amObjectHeight/2)
	move r6,!rSin	; sin(90deg.-ViewAngle)
	from !rX1	; *Vertex X1
;	to	r0
	fmult
;	from	r0
	to !rY1Temp
	rol
;
	from !rY1	; *Vertex Y1
;	to	r0
	fmult
;	from	r0
	to r1
	rol
;
	move r6,!rCos	; cos(90deg.-ViewAngle)
	from !rY1	; *Vertex Y1
;	to	r0
	fmult
;	with	r0
	rol
	from !rY1Temp	; Rotated Y1
	to !rY2
	add r0
;
	with !rX1	; *Vertex X1
	fmult
	from !rX1
;	to	r0
	rol
;	from	r0				; Rotated X1
	to !rX2
	sub r1
;
	with !rX2	; Object Vertex X2
	add !rMObjX
	sms (AMObjX2&$FFFF),!rX2
	with !rY2	; Object Vertex Y2
	add !rMObjY
	sms (AMObjY2&$FFFF),!rY2
;
	ibt !rX1,#(amObjectBase/2)
	ibt !rY1,#-(amObjectHeight/2)
	move r6,!rSin	; sin(90deg.-ViewAngle)
	from !rX1	; *Vertex X1
;	to	r0
	fmult
;	from	r0
	to !rY1Temp
	rol
;
	from !rY1	; *Vertex Y1
;	to	r0
	fmult
;	from	r0
	to r1
	rol
;
	move r6,!rCos	; cos(90deg.-ViewAngle)
	from !rY1	; *Vertex Y1
;	to	r0
	fmult
;	with	r0
	rol
	from !rY1Temp	; Rotated Y1
	to !rY1
	add r0
;
	with !rX1	; *Vertex X1
	fmult
	with !rX1
	rol
	with !rX1	; Rotated X1
	sub r1
;
	with !rX1	; Object Vertex X3
	add !rMObjX
	sms (AMObjX3&$FFFF),!rX1
	with !rY1	; Object Vertex Y3
	add !rMObjY
	sms (AMObjY3&$FFFF),!rY1
;
;	>>>   LINE-DRAW OBJECT'S TRIANGLE   <<<
;
;	move	rX1,(<AMObjX3)			; Draw Base of Triangle
;	move	rY1,(<AMObjY3)
;	move	rX2,(<AMObjX2)
;	move	rY2,(<AMObjY2)
	link #4
	iwt r15,#lo16(_RLDrawAutoMapLine)	; Draw (X1,Y1) -> (X2,Y2)
	nop
	lms !rX1,(AMObjX3&$FFFF)	; Draw Left-Edge of Triangle
	lms !rY1,(AMObjY3&$FFFF)
	lms !rX2,(AMObjX1&$FFFF)
	lms !rY2,(AMObjY1&$FFFF)
	link #4
	iwt r15,#lo16(_RLDrawAutoMapLine)	; Draw (X1,Y1) -> (X2,Y2)
	nop
	lms !rX1,(AMObjX1&$FFFF)	; Draw Right-Edge of Triangle
	lms !rY1,(AMObjY1&$FFFF)
	lms !rX2,(AMObjX2&$FFFF)
	lms !rY2,(AMObjY2&$FFFF)
	iwt r11,#lo16(_DAM6000)
	iwt r15,#lo16(_RLDrawAutoMapLine)	; Draw (X1,Y1) -> (X2,Y2)
	nop
