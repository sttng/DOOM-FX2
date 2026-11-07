	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       OBJECT MOVEMENT MODULE 4                     *
;*                                                                    *
;*                     PLAYER <-> LINE COLLISIONS 2                   *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


	!rX0 = r7	;  Current X Coordinate
	!rY0 = r8	;  Current Y Coordinate
	!rVX = r9	; Velocity X
	!rVY = r10	; Velocity Y
	!rX1 = !rVX	;  Attempt X Coordinate
	!rY1 = !rVY	;  Attempt Y Coordinate
;
	!rObj = r12	; Pointer to RLObject
	!rObjP = r11	; Pointer to RLObject
;
	!rLX1 = r12	; Line Vertex 1 X
	!rLY1 = r13	; Line Vertex 1 Y
	!rPUX = r3	; Line Perpendicular UnitVector X
	!rPUY = r5	; Line Perpendicular UnitVector Y
;
	!rMoveLinesPtr = !rPUY	; MoveLines Entry Pointer
;
	!rTemp = r14	; Temporary Variable
;
	!rSector = r6	; Object's Sector


	%align_pad(6, 16, (_RLMoveXY4-_RM4XY2000)&$0F)	; align 16,(_RLMoveXY4-_RM4XY2000)&$0f
;
;	* * * * * * *       REALITY_ENGINE MOVE RLOBJECT XY       * * * * * * *
;
_RLMoveXY4:
	lms !rObj,(MVRObj&$FFFF)	; Get RLObject Pointer

	if !useTESTMOVEXY != 0
;
;	>>>   SET OBJECT TEST COORDINATES/VELOCITIES   <<<
;
	!otx #= $052A0000	; Object Test Coordinate X
	!oty #= $F3030000	; Object Test Coordinate Y
	!ota #= $0000	; Object Test Angle
	!otv #= $063D0000	; Object Test Velocities X.W / Y.W
;
	ibt r0,#0	; 1=SET COORDINATES/VELOCITIES
	dec r0
	bne ._0
	nop
	from !rObj	; Move to X Coordinate
;	to	r0
	%add_i(rloX)
	iwt r1,#(!otx&$FFFF)	; rX0:r1 = X Coordinate
	from r1
	stw (r0)
	inc r0
	inc r0
	iwt !rX0,#(!otx>>16)
	from !rX0
	stw (r0)
;
	inc r0	; rY0:r2 = Y Coordinate
	inc r0
	iwt r2,#(!oty&$FFFF)
	from r2
	stw (r0)
	inc r0
	inc r0
	iwt !rY0,#(!oty>>16)
	from !rY0
	stw (r0)
;
;	with	r0				; rVX = X Velocity
	%add_i((rloVX-(rloY+2)))
	iwt !rVX,#(!otv>>16)
	from !rVX
	stw (r0)
;
	inc r0	; rVY = Y Velocity
	inc r0
	iwt !rVY,#(!otv&$FFFF)
	from !rVY
	stw (r0)
;
	inc r0	; TEST ANGLE
	inc r0
	iwt r4,#(!ota&$FFFF)
	from r4
	stw (r0)
._0:
	endif

;
;	>>>   GET OBJECT CURRENT COORDINATES/VELOCITIES   <<<
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
	sms (MVRX&$FFFF),!rX0
;
	inc r0	; rY0:r2 = Y Coordinate
	inc r0
	to r2
	ldw (r0)
	inc r0
	inc r0
	to !rY0
	ldw (r0)
	sms (MVRY&$FFFF),!rY0
;
	inc r0	; r4 = Z Coordinate
	inc r0
	to r4
	ldw (r0)
	sms (MVIZ&$FFFF),r4
;
	inc r0	; rVX = X Velocity
	inc r0
	to !rVX
	ldw (r0)
;
	inc r0	; rVY = Y Velocity
	inc r0
	to !rVY
	ldw (r0)
;
	sms (MVVX&$FFFF),!rVX	; Velocity X
;
	ibt r0,#rloSector	; Get Object's Sector
;	with	r0
	add !rObj
;	to	r0
	ldb (r0)
;	with	r0
	%umult_i(rlsdSize)
;
	sms (MVVY&$FFFF),!rVY	; Velocity Y
	sms (MVOVX&$FFFF),!rVX	; (this port) The frame's velocity, for the stairstep
	sms (MVOVY&$FFFF),!rVY
;
	iwt r4,#lo16(_RLSectorData+rlsdFloorHeight)
	with r4
	add r0
;	to	r0
	ldw (r4)
	sms (MVIZ2&$FFFF),r0	; Starting Z2
	inc r4
	inc r4
;
	ibt r0,#bank(InvTable)	; Bank of InverseTable
	romb
;
;	to	r0
	ldw (r4)
	sms (MVIC2&$FFFF),r0	; Starting C2
;
;	>>>   SET MAXIMUM NUMBER OF MOVEMENT REMAINDER RESCANS   <<<
;
	sub r0	; (this port) No stairstep tried yet
	sms (MVStair&$FFFF),r0
	inc r0	; ReScan Counter (Allow Deflection)

;
;	* * * * * * *       ATTEMPT TO MOVE OBJECT       * * * * * * *
;
_RM4XY1000:
	sms (MVCount&$FFFF),r0	; Save ReScan Counter
;
;	move	r0,(<MVIZ2S)			; Get Starting Z2
;	move	(<MVIZ2),r0
;	move	r0,(<MVIC2S)			; Get Starting C2
;	move	(<MVIC2),r0
;
;	>>>   CALCULATE OBJECT MOVEMENT DESTINATION COORDINATES   <<<
;
	from !rVX	; X Velocity Fraction
;	to	r0
	lob
;	with	r0
	swap
	with r1	; X Coordinate Fraction
	add r0
;
	from !rVX	; X Velocity Integer
;	to	r0
	hib
;	with	r0
	sex
;	from	r0				; X Coordinate Integer
	to !rX1
	adc !rX0
;
	iwt r0,#$7FFF	; Percentage of Movement Allowed
	sms (MVIPercent&$FFFF),r0
;
	from !rVY	; Y Velocity Fraction
;	to	r0
	lob
;	with	r0
	swap
	with r2	; Y Coordinate Fraction
	add r0
;
	iwt r0,#lo16(_RLMoveLines-rlmlSize)	; Start of MoveLines List
	sms (MVMLPtr&$FFFF),r0
;
	from !rVY	; Y Velocity Integer
;	to	r0
	hib
;	with	r0
	sex
;	from	r0				; Y Coordinate Integer
	to !rY1
	adc !rY0

;
;	* * * * * * *       CHECK MOVEMENT AGAINST LINELIST       * * * * * * *
;
	%CACHEB(_RLMoveXY4)
_RM4XY2000:
;
;	>>>   CHECK NEXT MOVELINE   <<<
;
_RM4XY2200:
	lms !rMoveLinesPtr,(MVMLPtr&$FFFF)	; Get MoveLines Pointer
	ibt r0,#rlmlSize	; Move to next MoveLine
	with !rMoveLinesPtr
	add r0
	from !rMoveLinesPtr
	sbk
	to r2	; Get Next Line#
	ldw (!rMoveLinesPtr)
	inc r2
	bne _RM4XY2220
	inc !rMoveLinesPtr	; Move to Line Vertex 1 X
	iwt r15,#lo16(_RM4XY8200)	; Finished Scanning MoveLines!
;
;	>>>   GET VERTEX 1 COORDINATES   <<<
;
_RM4XY2220:
	inc !rMoveLinesPtr	; Move to Line Vertex 1 X
	to !rLX1
	ldw (!rMoveLinesPtr)
	inc !rMoveLinesPtr
	inc !rMoveLinesPtr
	to !rLY1
	ldw (!rMoveLinesPtr)
;
;	>>>   GET LINE PERPENDICULAR COMPONENTS   <<<
;
	inc !rMoveLinesPtr
	inc !rMoveLinesPtr
	to r6	; Perpendicular UnitVector X
	ldw (!rMoveLinesPtr)
	from r6	; Adjust LineY Towards Movement
	to !rPUX
	not
	inc !rPUX
	inc !rMoveLinesPtr
	inc !rMoveLinesPtr
	to !rPUY	; Perpendicular UnitVector Y
	ldw (!rMoveLinesPtr)
	ibt r1,#(odrMoveLineXY<<1)	; Line<->Player Collision Radius
	from r1
;	to	r0
	fmult
	sms (MVLRY&$FFFF),r0
	move r6,!rPUY	; Adjust LineX Towards Movement
	from r1
;	to	r0
	fmult
;
;	>>>   DETERMINE DIRECTION LINE IS CROSSED (R->L OR L->R)   <<<
;
	from !rY0	; R1 = (ObjectY0 - LineY)
	to r1
	sub !rLY1
;
	sms (MVLRX&$FFFF),r0	; UnitVector X
;
	from !rX0	; R0 = (ObjectX0 - LineX)
;	to	r0
	sub !rLX1
	link #4
	iwt r15,#lo16(_RM4XY4100)
	with r1
;
;	>>>   GET LINE FLAGS   <<<
;
	lms r2,(MVMLPtr&$FFFF)	; Get Line Flags
	with r2
	%add_i(rlmlFlags)
;	to	r0
	ldw (r2)
;
;	>>>   DETERMINE DIRECTION LINE IS CROSSED (R->L OR L->R)   <<<
;
	moves r1,r1	; Crossed R->L or L->R?
	with r2	; Save MoveLines Pointer
	bmi _RM4XY2500	; Right to Left!
	to !rTemp

_RM4XY2400:
;	from	r0				; SOLID / IMPASSIBLE?
	to r4
;	and	#(rllfSolid|rllfImpassible)	; SOLID / IMPASSIBLE?
	lsr	; SOLID?
	bcs _RM4XY2200	; YES!
;
;	>>>   ITEM?   <<<
;
	inc r0	; ITEM?
	with r1
	bmi _RM4XY2200	; YES!
	from r1
;
;	>>>   EXACTLY ON LINE?   <<<
;
;	moves	r1,r1				; Exactly ON Line?
	beq _RM4XY2600	; (Z is from INC R0 since the MOVES above is out:
;						; never taken, ON counts as LEFT -> RIGHT)
;
;	>>>   LINE IS CROSSED LEFT -> RIGHT   <<<
;
	with !rPUX	; Flip Perpendicular UnitVector X
	not
	inc !rPUX
	with !rPUY	; Flip Perpendicular UnitVector Y
	not
	inc !rPUY
;
;	>>>   GET LINE VERTEX 2   <<<
;
	inc r2
	inc r2
	to !rLX1
	ldw (r2)
	inc r2
	inc r2
	to !rLY1
	ldw (r2)
	inc r2	; Get HighFloor/LowCeiling
	bra _RM4XY2700
	inc r2
;
;	>>>   LINE IS CROSSED RIGHT -> LEFT   <<<
;
_RM4XY2500:
;	from	r0				; SOLID / IMPASSIBLE?
	to r1
	%and_i((rllfSolid|rllfImpassible))
	bne _RM4XY3000	; YES!  CAN'T CROSS IT!
;
;	>>>   ITEM?   <<<
;
	inc r0	; ITEM?
	bmi _RM4XY2200	; YES!
;
;	>>>   GET HIGHFLOOR / LOWCEILING   <<<
;
_RM4XY2600:
	with r2	; Get HighFloor/LowCeiling
	%add_i((rlmlHighFloorHeight-rlmlFlags))
_RM4XY2700:
;
;	>>>   IMPASSIBLE?   <<<   (this port: blocks from the left too; the original only
;	skipped SOLID lines there.  R0 = Flags+1 here, SOLID clear.)
;
	to r4
	%and_i(rllfImpassible)
	bne _RM4XY3000	; YES!  CAN'T CROSS IT!
	nop
	lms r1,(MVIZ&$FFFF)	; R1 = ObjectZ
;
;	>>>   STEP TOO FAR UP?   <<<
;
	to r4	; R4 = HighFloor
	ldw (r2)
	from r4	; R0 = (HighFloor - ObjectZ)
;	to	r0
	sub r1
	ibt r6,#(24+1)	; Step Too Far Up?
;	with	r0				; @CMP@
	sub r6
	bge _RM4XY3000	; YES!
;
;	>>>   ABOVE LOWER PASSAGE?   <<<
;
	inc r2	; R0 = LowCeiling
	inc r2
;	to	r0
	ldw (r2)
	ibt r6,#odhPlayer	; Enough Ceiling Clearance?
	with r1	; R1 = ObjectZ+Height
	add r6
;	from	r0				; LowCeiling >= (ObjectZ+Height)?
	cmp r1
	blt _RM4XY3000	; NO!
;
;	>>>   ENOUGH FLOOR->CEILING CLEARANCE?   <<<
;
;	with	r0				; R0 = (LowCeiling-HighFloor)
	sub r4
;	with	r0				; Enough Clearance?
	sub r6	; @CMP@
;
	from r4	; R0 = ((High Floor<<1)|1)
;	to	r0
	blt _RM4XY3000	; NO!
	add r4
;
;	>>>   LINE WILL *NOT* BLOCK MOVEMENT   <<<
;
	inc r0
	with r1	; @WITH IN PIPELINE@
;
;	* * * * * * *       THIS LINE WILL BLOCK MOVEMENT       * * * * * * *
;
_RM4XY3000:
;	with	r0				; 0=BLOCKS MOVEMENT
	sub r0
	sms (MVBlock&$FFFF),r0	; Save Blocking Status
;
;	>>>   ADJUST OBJECT MOVEMENT COORDINATES SO RADIUS INTERSECTS LINE   <<<
;
	ibt r1,#(odrMoveXY<<1)	; Player<->Line Collision Radius
	move r6,!rPUY	; Adjust MovementY
	sms (MVLPUY&$FFFF),!rPUY	; Save Perpendicular UnitVector Y
	from r1
;	to	r0
	fmult
	move r6,!rPUX
;
	with !rY0	; Move Initial Coordinate Away
	sub r0
	sms (MVLPRY&$FFFF),r0
	with !rY1	; Move Final Coordinate Towards
	add r0
	from !rY0	; -Ya
	to !rPUX
	sub !rY1
;
	from r1	; Adjust MovementX
;	to	r0
	fmult
	sms (MVLPRX&$FFFF),r0
;
	with !rX0	; Move Initial Coordinate Away
	sub r0
	with !rX1	; Move Final Coordinate Towards
	add r0
	from !rX1	; +Xa
	to !rPUY
	sub !rX0
	sms (MVLPUX&$FFFF),r6	; Save Perpendicular UnitVector X

;
;	* * * * * * *       DOES LINE CROSS OBJECT?       * * * * * * *
;
;	>>>   GET LINE VERTEX 1   <<<
;
	from !rTemp	; Move to Line Vertex 1 X
	to r2
	%sub_i((rlmlFlags-rlmlLX1))
;	to	r0				; R0 = Vertex1 X
	ldw (r2)
	lms r1,(MVLRX&$FFFF)	; LineX Radius Adjustment
;	with	r0
	sub r1
	inc r2	; Move to Line Vertex 1 Y
	inc r2
	to r1	; R1 = Vertex1 Y
	ldw (r2)
	lms r4,(MVLRY&$FFFF)	; LineY Radius Adjustment
	with r1
	sub r4
	with r1	; R1 = (LineY0 - ObjectY0)
	sub !rY0
	move !rTemp,r2	; Save MoveLines Entry Pointer
	link #3
;	with	r0				; R0 = (LineX0 - ObjectX0)
	bra _RM4XY4000
	sub !rX0
;
;	>>>   GET LINE VERTEX 2   <<<
;
	from !rTemp	; Restore MoveLines Entry Pointer
	to r4
	%add_i((rlmlLX2-rlmlLY1))
;	to	r0				; R0 = Vertex2 X
	ldw (r4)
	lms r1,(MVLRX&$FFFF)	; LineX Radius Adjustment
	inc r4
	inc r4
;	with	r0
	add r1
	to r1	; R1 = Vertex2 Y
	ldw (r4)
	lms r4,(MVLRY&$FFFF)	; LineY Radius Adjustment
	with r1
	add r4
	move !rTemp,r2	; Save SIDE1
	with r1	; R1 = (LineY1 - ObjectY0)
	sub !rY0
	link #3
;	with	r0				; R0 = (LineX1 - ObjectX0)
	bra _RM4XY4000
	sub !rX0
;
	lms r0,(MVLPRX&$FFFF)	; Move Initial Coordinate Towards
;	with	r0
	add r0
	with !rX0
	add r0
;
	lms r0,(MVLPRY&$FFFF)	; Move Initial Coordinate Towards
;	with	r0
	add r0
	with !rY0
	add r0
;
	from r2	; Opposite Sides?
;	to	r0
	xor !rTemp
	bpl _RM4XY3900+1	; No, Line Doesn't Cross Object

;
;	>>>   DOES OBJECT CROSS LINE?   <<<
;
;_RM4XY3500
	lms !rPUX,(MVLPUX&$FFFF)
	lms !rPUY,(MVLPUY&$FFFF)
;
	from !rY1	; R1 = (ObjectY1 - LineY)
	to r1
	sub !rLY1
	link #4
	from !rX1	; R0 = (ObjectX1 - LineX)
;	to	r0
	bra _RM4XY4000
	sub !rLX1
;
	moves r0,r2
	bmi _RM4XY3900+1	; "RIGHT"?
;
;	>>>   OBJECT CROSSES LINE   <<<
;
	lms r0,(MVBlock&$FFFF)	; DOES LINE BLOCK MOVEMENT?
;	with	r0
	asr
;
	bcs _RM4XY3700+1	; NO!  ADJUST PLAYER Z2/C2!
	lms r0,(MVIPercent&$FFFF)	; YES!  Already Blocked?
	dec r0
	bmi _RM4XY3900	; Yes (else MVIPercent = 0)
;	with	r0
	sub r0
;	from	r0
	sbk
	sms (MVIPUX&$FFFF),!rPUX	; Save New Intersection UnitVector X
	sms (MVIPUY&$FFFF),!rPUY	; Save New Intersection UnitVector Y
	bra _RM4XY3900+1

;
;	>>>   ADJUST PLAYER Z2/C2   <<<
;
_RM4XY3700:
	lms r1,(MVIZ2&$FFFF)	; Z2 >= HighFloor
	with r1	; @CMP@
	sub r0
	bge _RM4XY3750	; Yes
	from r0	; NO!  NEW Z2!
	sbk
_RM4XY3750:
	ibt r0,#rlmlLowCeilingHeight	; Get LowCeiling
	lms r1,(MVMLPtr&$FFFF)
;	with	r0
	add r1
;	to	r0
	ldw (r0)
	lms r1,(MVIC2&$FFFF)	; C2 < LowCeiling?
;	from	r0				; @CMP@
	to r1
	sub r1
	bge _RM4XY3900	; Yes
	from r0	; NO!  NEW C2!
	sbk
;
;	>>>   OBJECT DOES NOT CROSS LINE   <<<
;
_RM4XY3900:
	lms r0,(MVLPRY&$FFFF)	; ReAdjust for Perpendicular Radius Offset
	with !rY0
	sub r0
	with !rY1
	sub r0
	lms r0,(MVLPRX&$FFFF)	; ReAdjust for Perpendicular Radius Offset
	with !rX0
	sub r0
	with !rX1
	sub r0
	iwt r15,#lo16(_RM4XY2000)	; No, Same Side

;
;	* * * * * * *       GET SIDE OF COORDINATE RELATIVE TO LINE       * * * * * * *
;
;	R0	=	(Coordinate X - Line X0)
;	R1	=	(Coordinate Y - Line Y0)
;	RPUX	=	(Line Perpendicular UnitVector X)
;	RPUY	=	(Line Perpendicular UnitVector Y)
;
;	R1	=	"ON"	= 0	(WITHIN 1 UnitVector Distance from Line)
;			"LEFT"	> 0	(Greater than 1 UnitVector to LEFT of Line)
;			"RIGHT"	< 0	(Greater than 1 UnitVector to RIGHT of Line)
;
;	* * * * * * *       GET DIRECTION OF COORDINATE RELATIVE TO LINE       * * * * * * *
;
;	R0	=	(Coordinate X - Line X0)
;	R1	=	(Coordinate Y - Line Y0)
;	RPUX	=	(Line Vector X)
;	RPUY	=	(Line Vector Y)
;
;	R2	=	"LEFT" >= 0	(ON or to LEFT of Line)
;			"RIGHT"	< 0	(RIGHT of Line)
;
_RM4XY4000:
	move r6,!rPUY
	with r1	; Result in R1:R2
_RM4XY4100:
	lmult
	move r2,r4
	move r6,!rPUX
;	with	r0				; Result in R0:R4
	lmult
	with r2
	add r4
	with r1	; R1:R2 = SIDE
	adc r0
	with r1
	bpl _RM4XY4200	; "LEFT" or "ON"
	to r2
	inc r1	; "RIGHT" or "ON" (-1 -> 0)
_RM4XY4200:
	jmp r11
	nop

;
;	* * * * * * *       MOVE OBJECT       * * * * * * *
;
;	>>>   CALCULATE OBJECT NEW COORDINATES   <<<
;
_RM4XY8200:
	lms r6,(MVIPercent&$FFFF)	; Percentage of Movement Without Collision
	lms !rVX,(MVVX&$FFFF)	; Velocity X
	lms !rVY,(MVVY&$FFFF)	; Velocity Y
	lms !rObjP,(MVRObj&$FFFF)
	with !rObjP
	%add_i(rloX)
;
;	>>>   UPDATE X COORDINATE   <<<
;
	from !rVX	; R3:R1 = X Velocity * Percentage
;	to	r0
	fmult
;	with	r0
	rol
	with !rVX	; Update X Velocity
	sub r0
;	from	r0
	to r1
	lob
	with r1
	swap
;	with	r0
	hib
;	from	r0
	to r3
	sex
;
;	to	r0				; R1 = X Coordinate Fraction
	ldw (!rObjP)
	with r1
	add r0
	from r1
	sbk
	inc !rObjP
	inc !rObjP
;	to	r0				; RX0 = X Coordinate Integer
	ldw (!rObjP)
;	from	r0
	to !rX0
	adc r3
	from !rX0
	sbk
	inc !rObjP
	inc !rObjP
;
;	>>>   UPDATE Y COORDINATE   <<<
;
	from !rVY	; R3:R2 = Y Velocity * Percentage
;	to	r0
	fmult
;	with	r0
	rol
	with !rVY	; Update Y Velocity
	sub r0
;	from	r0
	to r2
	lob
	with r2
	swap
;	with	r0
	hib
;	from	r0
	to r3
	sex
;
;	to	r0				; R2 = Y Coordinate Fraction
	ldw (!rObjP)
	with r2
	add r0
	from r2
	sbk
	inc !rObjP
	inc !rObjP
;	to	r0				; RY0 = Y Coordinate Integer
	ldw (!rObjP)
;	from	r0
	to !rY0
	adc r3
	from !rY0
	sbk
;
;	>>>   COMPLETED ENTIRE MOVEMENT?   <<<
;
	inc r6	; Completed Entire Movement?
	ibt r6,#(rloZ2-(rloY+2))	; Set Z2/C2 Coordinates
	bmi _RM4XY9600+1	; Yes!

;
;	* * * * * * *       PROJECT REMAINDER ALONG LINE VECTOR       * * * * * * *
;
;	>>>   PROJECT VELOCITIES ALONG INTERCEPTION LINE   <<<
;
;_RM4XY9000
	lms r6,(MVIPUX&$FFFF)	; Calculate Magnitude of Projection
	from !rVY	;  Velocity Y *-Perpendicular UnitVector X
;	to	r0				; =Velocity Y * Line Vector Y
	fmult
;	with	r0
	rol
	from r6
	to !rVY
	not
	inc !rVY
;
;	from	r0				; R5:R3 = Magnitude Component Y
	to r3
	lob
	with r3
	swap
;	with	r0
	hib
;	from	r0
	to r5
	sex
;
	lms r6,(MVIPUY&$FFFF)
	from !rVX	;  Velocity X * Perpendicular UnitVector Y
;	to	r0				; =Velocity X * Line Vector X
	fmult
;	with	r0
	rol
	move !rVX,r6
;	from	r0				; R6:R0 = Magnitude Component X
	to r6
	hib
	with r6
	sex
;	with	r0
	lob
;	with	r0
	swap
;
;	with	r0				; R6:R0 = Magnitude of Projection
	sub r3
	with r6
	sbc r5
;	with	r0
	hib
	with r6
	lob
	with r6
	swap
	with r6
	add r0
;
;	>>>   CALCULATE OBJECT NEW VELOCITY X   <<<
;
	with !rVX	; Velocity X = (Magnitude * Line Vector X)
	fmult
	with !rVX
	rol
	lms r3,(MVRObj&$FFFF)
	sms (MVVX&$FFFF),!rVX
	ibt r0,#rloVX
	with r3
	add r0
	from !rVX
	stw (r3)
;
;	>>>   CALCULATE OBJECT NEW VELOCITY Y   <<<
;
	with !rVY	; Velocity Y = (Magnitude * Line Vector Y)
	fmult
	with !rVY
	rol
;
	lms r0,(MVCount&$FFFF)	; Movement Remainder ReScan Counter
;
	sms (MVVY&$FFFF),!rVY
	inc r3
	inc r3
;
	dec r0
	from !rVY
	bmi _RM4XY9500	; Don't ReScan Remaining Movement!
	stw (r3)
	iwt r15,#lo16(_RM4XY1000)	; ReScan Remaining Movement

	%CACHEE(_RLMoveXY4)

;
;	>>>   MOVEMENT CANNOT PROCEED   <<<
;
;	(this port) "Stairstep": see _RM4XY9700
;
_RM4XY9500:
	sub r0	; (also the delay slot of the ReScan jump above: ReScan Counter 0)
	iwt r15,#lo16(_RM4XY9700)
	nop
;
_RM4XY9550:
;	with	r0				; VelocityX/Y = 0
	sub r0
	ibt r6,#(rloVX+1)
	lms !rObjP,(MVRObj&$FFFF)
	with !rObjP
	add r6
;	from	r0				; VelocityX = 0
	stw (!rObjP)	; @RAM WRITE INVERTED@
	inc !rObjP
	ibt r6,#(rloZ2-rloVY)	; Set Z2/C2 Coordinates
;	from	r0				; VelocityY = 0
	stw (!rObjP)
_RM4XY9600:
	lms r0,(MVIZ2&$FFFF)	; Yes!
	with !rObjP	; Set Z2/C2 Coordinates
	add r6	; @WITH IN PIPELINE@
;	from	r0
	stw (!rObjP)
	inc !rObjP
	inc !rObjP
	lms r0,(MVIC2&$FFFF)
;	from	r0
	stw (!rObjP)

;
;	* * * * * * *       MOVEMENT COLLISIONS COMPLETED!       * * * * * * *
;
;_RM4XY10000
;
;	>>>   REMOVE RLOBJECT FROM OLD SECTOR   <<<
;
	lms !rObj,(MVRObj&$FFFF)	; Get Object's Old SectorData
	link #4	; Remove RLObject from Sector's ObjectList
	iwt r15,#lo16(_RLRemSectorObject)
	nop
;
;	>>>   UPDATE OBJECT'S SECTOR/SECTORDATA   <<<
;
	link #4	; Get Object's Sector
	iwt r15,#lo16(_RLGetXYSector)
	nop
	ibt r0,#rloSector
;	with	r0
	add !rObj
	from !rSector
	stb (r0)
;
;	>>>   ADD RLOBJECT TO NEW SECTOR   <<<
;
	iwt r11,#lo16(_RLMoveXY7A)	; Add RLObject to Sector's ObjectList
	iwt r15,#lo16(_RLAddSectorObject)
	nop

;
;	* * * * * * *       STAIRSTEP (this port)       * * * * * * *
;
;	"Stairstep", as the PC's P_SlideMove: when the move and its
;	slide along the wall are both blocked, try the frame's velocity along X
;	only and along Y only (the larger component first).  The original code
;	stopped the player here: snagged on a door frame, a step or the corner
;	of a wall made of several lines.  The axis moves stay inside the
;	movement's block list, and each one is checked like any move.
;
_RM4XY9700:
	lms r0,(MVStair&$FFFF)	; Next stage (1, 2; 3 = give up)
	inc r0
	sbk
	move r12,r0
	ibt r0,#3
	from r12
	cmp r0
	blt _RM4XY9705
	nop
	iwt r15,#lo16(_RM4XY9550)	; Both tried: stop
	nop
_RM4XY9705:
	lms !rVX,(MVOVX&$FFFF)	; The frame's velocity
	lms !rVY,(MVOVY&$FFFF)
	move r3,!rVX	; R3 = |VX|
	moves r3,r3
	bpl _RM4XY9710
	nop
	with r3
	not
	inc r3
_RM4XY9710:
	move r4,!rVY	; R4 = |VY|
	moves r4,r4
	bpl _RM4XY9715
	nop
	with r4
	not
	inc r4
_RM4XY9715:
	ibt r5,#1	; R5 = the stage that keeps X: 1 if |VX| > |VY|, else 2
	from r4
	cmp r3
	blt _RM4XY9720
	nop
	inc r5
_RM4XY9720:
	from r12	; This stage keeps X?
	cmp r5
	bne _RM4XY9730	; No: Y
	nop
	ibt !rVY,#0	; X only
	moves !rVX,!rVX
	bra _RM4XY9740
	nop
_RM4XY9730:
	ibt !rVX,#0	; Y only
	moves !rVY,!rVY
_RM4XY9740:
	bne _RM4XY9745
	nop
	iwt r15,#lo16(_RM4XY9700)	; (no velocity on that axis: next stage)
	nop
_RM4XY9745:
	sms (MVVX&$FFFF),!rVX	; The stage's velocity
	sms (MVVY&$FFFF),!rVY
	lms r3,(MVRObj&$FFFF)
	ibt r0,#rloVX
	with r3
	add r0
	from !rVX
	stw (r3)
	inc r3
	inc r3
	from !rVY
	stw (r3)
	lms r3,(MVRObj&$FFFF)	; Z2/C2 of the object's sector again (a blocked
	ibt r0,#rloSector	; try may have crossed a step line)
;	with	r0
	add r3
;	to	r0
	ldb (r0)
;	with	r0
	%umult_i(rlsdSize)
	iwt r4,#lo16(_RLSectorData+rlsdFloorHeight)
	with r4
	add r0
;	to	r0
	ldw (r4)
	sms (MVIZ2&$FFFF),r0
	inc r4
	inc r4
;	to	r0
	ldw (r4)
	sms (MVIC2&$FFFF),r0
	iwt r15,#lo16(_RM4XY1000)	; Try it (no slide: ReScan Counter 0)
	sub r0

