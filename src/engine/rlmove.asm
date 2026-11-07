	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       OBJECT MOVEMENT MODULE 1                     *
;*                                                                    *
;*                       DETERMINE MOVELINES LIST                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


	!rRLLineCount = r2	; RLEngine Line Counter

	!rNumX = r3	; Number of BlockMap X Repetitions
	!rNumY = r4	; Number of BlockMap Y Repetitions
	!rDeltaX = r5	; Coordinates/BlockMap Delta X
	!rDeltaY = r6	; Coordinates/BlockMap Delta Y

	!rX0 = r7	;  Current X Coordinate
	!rY0 = r8	;  Current Y Coordinate
	!rVX = r9	; Velocity X
	!rVY = r10	; Velocity Y
	!rX1 = !rVX	;      New X Coordinate
	!rY1 = !rVY	;      New Y Coordinate

	!rObj = r12	; Pointer to Object's Data

	!rTemp = !rObj	; Temporary Variable
	!rLine = !rX0	; Line Number
	!rBlockMapPtr = r13	; Pointer to Current BlockMapBlock

	!rMoveLinesPtr = !rY1	; Pointer to MoveLines List
	!rLineRLCountsP = !rX1	; Base of LineRLCounts Table


	%align_pad(1, 16, (_RLMoveXYP-_RMXY5000)&$0F)	; align 16,(_RLMoveXYP-_RMXY5000)&$0f
;
;	* * * * * * *       REALITY_ENGINE MOVE RLOBJECT XY       * * * * * * *
;
;	r0	=	Code for OBJECT<->LINE COLLISIONS 2
;	rObj	=	Pointer to RLObject
;
_RLMoveXYP:
	iwt r0,#lo16(_RLMoveXY6)	; MOVE RLOBJECT XY 6 (PROJECTILES)
_RLMoveXY:
	sms (MVCode&$FFFF),r0	; Save Code Address for LINE COLLISIONS 2
;
;	>>>   GET OBJECT DIAMETER   <<<
;
	ibt r0,#bank(_ObjData)	; Move to _ObjData Bank
	romb
	from !rObj	; Move to RLObject Type
;	to	r0
	%add_i(rloType)
;	to	r0				; Get RLObject Type
	ldb (r0)
;	with	r0				; Get Offset into _ObjData
	%umult_i(rlodSize)
	iwt r1,#lo16(_ObjData+rlodDiameter)	; Add Base of _ObjData
;	from	r0				; Move to Object Diameter
	to r14
	add r1
	getb
	sms (MVObjD&$FFFF),r0	; Save Object Diameter
;
;	>>>   GET CURRENT OBJECT COORDINATES   <<<
;
	from !rObj	; Move to X Coordinate
;	to	r0
	%add_i(rloX)
	to r1	; rX0:r1 = X Coordinate
	ldw (r0)
	inc r0
	inc r0
	to !rX0
	ldw (r0)
;
	inc r0	; rY0:r2 = Y Coordinate
	inc r0
	to r2
	ldw (r0)
	inc r0
	inc r0
	to !rY0
	ldw (r0)
;
;	>>>   GET CURRENT OBJECT VELOCITIES   <<<
;
;	with	r0				; rVX = X Velocity
	%add_i((rloVX-(rloY+2)))
	to !rVX
	ldw (r0)
;
	inc r0	; rVY = Y Velocity
	inc r0
	to !rVY
	ldw (r0)
;
;	>>>   INCREMENT RLENGINE_LINE_COUNT   <<<
;
_RMXY1200:
	lms r0,(RLLineCount&$FFFF)	; RLEngineLineCount++
	inc r0
	sbk
;
;	>>>   CALCULATE NEW OBJECT COORDINATES   <<<
;
	from !rVX	; X Velocity Fraction
;	to	r0
	lob
;	with	r0
	swap
	with r1	; X Coordinate Fraction
	add r0
	from !rVX	; X Velocity Integer
;	to	r0
	hib
;	from	r0				; DeltaX
	to !rDeltaX
	sex
	from !rX0	; X Coordinate Integer
	to !rX1
	adc !rDeltaX
;
	sms (MVRObj&$FFFF),!rObj	; Save RLObject Pointer
;
	from !rVY	; Y Velocity Fraction
;	to	r0
	lob
;	with	r0
	swap
	with r2	; Y Coordinate Fraction
	add r0
	from !rVY	; Y Velocity Integer
;	to	r0
	hib
;	from	r0				; DeltaY
	to !rDeltaY
	sex
	from !rY0	; Y Coordinate Integer
	to !rY1
	adc !rDeltaY
;
;
;	* * * * * * *       DETERMINE ENDPOINT BLOCKMAP LOCATIONS       * * * * * * *
;
	lms r0,(MVObjD&$FFFF)	; Object<->Line Collision Diameter
	sms (MVReturnAddress&$FFFF),r11	; Save Return Address
;	with	r0
	lsr
	inc r0	; Object<->Line Collision Radius+1
	moves !rDeltaX,!rDeltaX
	ibt !rDeltaX,#-2
	with r0	; R11 = Object<->Line Collision Radius+1
	bmi _RMXY3220
	to r11
;	with	r0
	not
	inc r0
	ibt !rDeltaX,#2
_RMXY3220:
;	from	r0				; R1 = X0 +/- CollisionRadiusX
	to r1
	add !rX0
	from !rX1	; R3 = X1 -/+ CollisionRadiusX
	to r3
	sub r0
;
	lms r0,(EMBLOCKMAPORIGIN&$FFFF)	; Adjust to MapOriginX
	with r1
	sub r0
	bpl _RMXY3240+1
	with r1
	sub r1
_RMXY3240:
	with r1	; X Coordinate / 128
	add r1
	with r1
	hib
;
	with r3
	sub r0
	bpl _RMXY3260+1
	with r3
	sub r3
_RMXY3260:
	with r3	; X Coordinate / 128
	add r3
	with r3
	hib
;
_RMXY3400:
	moves !rDeltaY,!rDeltaY
	with r11	; R0 = Object<->Line Collision Radius+1
	bmi _RMXY3420
	to r0
;	with	r0
	not
	inc r0
_RMXY3420:
;	from	r0				; R2 = Y0 +/- CollisionRadiusY
	to r2
	add !rY0
	from !rY1	; R4 = Y1 -/+ CollisionRadiusY
	to r4
	sub r0
;
	lms r0,(EMBLOCKMAPORIGIN+2&$FFFF)	; Adjust to MapOriginY
	with r2
	sub r0
	bpl _RMXY3440+1
	with r2
	sub r2
_RMXY3440:
	with r2	; Y Coordinate / 128
	add r2
	with r2
	hib
;
	with r4
	sub r0
	bpl _RMXY3460+1
	with r4
	sub r4
_RMXY3460:
	with r4	; Y Coordinate / 128
	add r4
	with r4
	hib
;
;	>>>   ENSURE WITHIN BLOCKMAP BOUNDARIES   <<<
;
	lms !rTemp,(EMBLOCKMAPDIM&$FFFF)	; Get Dimensions of BlockMap
;
	from !rTemp	; Get Y Dimension
;	to	r0
	hib
	dec r0
;	from	r0				; Ensure within boundary of BlockMap
	cmp r2
	bge _RMXY3620
	move r2,r0
_RMXY3620:
;	from	r0
	cmp r4
	bge _RMXY3640
	move r4,r0
_RMXY3640:
	dec !rTemp
	from !rTemp	; Get X Dimension
;	to	r0
	lob
;	from	r0				; Ensure within boundary of BlockMap
	cmp r1
	bge _RMXY3660
	move r1,r0
_RMXY3660:
;	from	r0
	cmp r3
	bge _RMXY3680
	move r3,r0
_RMXY3680:
;
;	>>>   GET #BYTES PER BLOCKMAP LINE   <<<
;
	inc r0	; RTEMP = #Bytes per BlockMap Line
;	from	r0
	to !rTemp
	add r0
;
;	>>>   CALCULATE NUMBER OF BLOCKMAP ITERATIONS   <<<
;
	from r3	; Get #BlockMap X Iterations
	to !rNumX
	sub r1
	bpl _RMXY4200
	with !rNumX
	not
	inc !rNumX
_RMXY4200:
	inc !rNumX
;
	from r4	; Get #BlockMap Y Iterations
	to !rNumY
	sub r2
	bpl _RMXY4400
	with !rNumY
	not
	inc !rNumY
_RMXY4400:
	inc !rNumY
;
;	>>>   CALCULATE #BYTES BETWEEN BLOCKMAP LINES   <<<
;
	moves !rDeltaY,!rDeltaY	; #Bytes to next BlockMap Line
	with !rTemp
	bpl _RMXY4600
	to !rDeltaY
	with !rDeltaY
	not
	inc !rDeltaY
_RMXY4600:
	from !rNumX	; #Bytes per BlockMap Line USED
;	to	r0
	mult !rDeltaX
	with !rDeltaY	; #Bytes per BlockMap Line UNUSED
	sub r0
;
;	>>>   CALCULATE STARTING ADDRESS WITHIN BLOCKMAP OFFSETS   <<<
;
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb	; Set ROM Bank
;
	from !rTemp	; Get (WidthOfBlockMap * Y0)
;	to	r0
	umult r2	; (unsigned: MULT is signed 8x8, so a BLOCKMAP more than 63
;				   blocks wide (DOOM II MAP31: 69) pointed before its start)
	lms !rTemp,(EMBLOCKMAP&$FFFF)	; Get Base of BlockMap (level RAM $71)
;	with	r0				; Get (X0 * 2)
	add r1
;	with	r0
	add r1
;	from	r0
	to r11	; R11 = BlockMap pointer
	add !rTemp
;
	iwt !rMoveLinesPtr,#lo16(_RLMoveLines-rlmlSize)	; START OF MOVELINES LIST
	iwt !rLineRLCountsP,#lo16(_RLLineRLCounts-2)	; Base of RLLineCounts
	lms !rRLLineCount,(RLLineCount&$FFFF)	; Get RLEngineLineCount
	ibt !rTemp,#rlmlSize	; Size of MoveLine Entry
	ibt r8,#1	; R8 = 1: "from r8 / ramb" selects GSU RAM $71
;				  ("from rLineRLCountsP / ramb" = $70, it is even)

	%CACHEB(_RLMoveXY)
;
;	* * * * * * *       GENERATE MOVE BLOCKLIST OF LINES       * * * * * * *
;
;	>>>   NEXT BLOCKMAP LINE   <<<
;
_RMXY5000:
	from !rNumX	; #Blocks on this Line
;	to	r0
	swap
	with !rNumX
	add r0
;
;	>>>   NEXT BLOCKMAP BLOCK   <<<
;
_RMXY5200:
	move !rBlockMapPtr,r11	; Save Current BlockMap Pointer
	from r8	; BLOCKMAP is in GSU RAM $71
	ramb
	ldw (r11)	; Get Offset to LineList
	inc r11	; (the offset is relative to the offset's 2nd byte)
	with r11	; Move to LineList
	add r0
;
;	>>>   FIRST LINE   <<<
;
_RMXY5400:
	to r1	; Get FIRST LINE#
	ldw (r11)
	inc r11
	inc r11
_RMXY5500:
	from r8	; (back to GSU RAM $71)
	ramb
	move !rLine,r1	; Get Next Line
	inc !rLine	; End of LineList?
	beq _RMXY7200	; Yes!
	nop
;
;	>>>   LINE ALREADY ADDED?   <<<
;
_RMXY5600:
	from r8	; GSU RAM $71
	ramb
	from !rLine	; R0 = Line#*2
;	to	r0
	add !rLine
;	with	r0				; Get RLLineCount
	add !rLineRLCountsP
	to r1	; Get Next Line#
	ldw (r11)
	inc r11
	inc r11
	from !rLineRLCountsP	; GSU RAM $70
	ramb
;	to	r0
	ldw (r0)
;	with	r0				; Already included?
	sub !rRLLineCount	; @CMP@
	from !rRLLineCount	; NO!  INCLUDE IT!
	beq _RMXY5500	; Yes!
	sbk
;
;	>>>   ADD THIS LINE   <<<
;
	with !rMoveLinesPtr	; Move to next MoveLine Entry
	add !rTemp
	dec !rLine	; SAVE LINE# (rLine = Line#+1)
	inc r1	; End of LineList?
	from !rLine
	stw (!rMoveLinesPtr)
	with r1
	bne _RMXY5600	; No, Check Next Line!
	to !rLine

;
;	>>>   NEXT BLOCKMAP X ITERATION   <<<
;
_RMXY7200:
	dec !rNumX	; NumX--
	from !rNumX
;	to	r0
	lob
	from !rBlockMapPtr	; Move to next BlockMap Block
	to r11
	bne _RMXY5200	; Not Finished this BlockMap Line!
	add !rDeltaX
;
;	>>>   NEXT BLOCKMAP Y ITERATION   <<<
;
_RMXY8200:
	dec !rNumY	; NumY--
	beq _RMXY9000	; Finished BlockMap!
	with r11	; Move to next BlockMap Line
	bra _RMXY5000
	add !rDeltaY

;
;	* * * * * * *       MOVE BLOCKLIST IS COMPLETED!       * * * * * * *
;
_RMXY9000:
	from !rLineRLCountsP	; GSU RAM $70
	ramb
	with !rMoveLinesPtr	; Move to next Line
	add !rTemp
	ibt r0,#-1	; MoveLines List Terminator
;	from	r0
	stw (!rMoveLinesPtr)
;
	iwt r0,#lo16(_RLMoveXY2)	; MOVE RLOBJECT XY 2
	ibt r8,#bank(_RLMoveXY2)
	ljmp r8
	nop

	%CACHEE(_RLMoveXY)
