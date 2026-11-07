	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       OBJECT MOVEMENT MODULE 5                     *
;*                                                                    *
;*                      ENEMY <-> LINE COLLISIONS 2                   *
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


	%align_pad(7, 16, (_RLMoveXY5-_RM5XY2000)&$0F)	; align 16,(_RLMoveXY5-_RM5XY2000)&$0f
;
;	* * * * * * *       REALITY_ENGINE MOVE RLOBJECT XY       * * * * * * *
;
_RLMoveXY5:
;
;	>>>   GET OBJECT CURRENT COORDINATES/VELOCITIES   <<<
;
	lms !rObj,(MVRObj&$FFFF)	; Get RLObject Pointer
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
	ibt r0,#bank(InvTable)	; Bank of InverseTable
	romb
;
	sms (MVVY&$FFFF),!rVY	; Velocity Y

;
;	* * * * * * *       ATTEMPT TO MOVE OBJECT       * * * * * * *
;
_RM5XY1000:
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
	%CACHEB(_RLMoveXY5)
_RM5XY2000:
;
;	>>>   CHECK NEXT MOVELINE   <<<
;
_RM5XY2200:
	lms !rMoveLinesPtr,(MVMLPtr&$FFFF)	; Get MoveLines Pointer
	ibt r0,#rlmlSize	; Move to next MoveLine
	with !rMoveLinesPtr
	add r0
	from !rMoveLinesPtr
	sbk
	to r2	; Get Next Line#
	ldw (!rMoveLinesPtr)
	inc r2
	bne _RM5XY2220
	inc !rMoveLinesPtr	; Move to Line Vertex 1 X
	iwt r15,#lo16(_RM5XY9000)	; Finished Scanning MoveLines!
;
;	>>>   GET VERTEX 1 COORDINATES   <<<
;
_RM5XY2220:
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
	lms r1,(MVObjD&$FFFF)	; Object<->Line Collision Radius
	from r1
;	to	r0
	fmult
	sms (MVLRY&$FFFF),r0
	move r6,!rPUY	; Adjust LineX Towards Movement
	from r1
;	to	r0
	fmult
	sms (MVLRX&$FFFF),r0	; UnitVector X
;
;	>>>   DETERMINE DIRECTION LINE IS CROSSED (R->L OR L->R)   <<<
;
	from !rY0	; R1 = (ObjectY0 - LineY)
	to r1
	sub !rLY1
	from !rX0	; R0 = (ObjectX0 - LineX)
;	to	r0
	sub !rLX1
	link #4
	iwt r15,#lo16(_RM5XY4100)
	with r1
;
;	>>>   GET LINE FLAGS   <<<
;
	lms r2,(MVMLPtr&$FFFF)	; Get Line Flags
	with r2
	%add_i(rlmlFlags)
;	to	r0
	ldb (r2)
;
;	>>>   DETERMINE DIRECTION LINE IS CROSSED (R->L OR L->R)   <<<
;
	moves r1,r1	; Crossed R->L or L->R?
	with r2	; Save MoveLines Pointer
	bmi _RM5XY2500	; Right to Left!
	to !rTemp

_RM5XY2400:
;
;	>>>   SOLID / IMPASSIBLE?   <<<   (this port: a SOLID line seen from behind
;	and any passable line are skipped; an IMPASSIBLE one blocks, through the L->R
;	code below, which flips the perpendicular.  The original skipped every L->R line.)
;
	to r4
	%and_i(rllfSolid)	; SOLID?
	bne _RM5XY2200	; YES!  (from behind)
	nop
	%and_i(rllfImpassible)	; IMPASSIBLE?
	beq _RM5XY2200	; NO!
	nop
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
	bra _RM5XY3000	; (this port: only IMPASSIBLE lines get here: CAN'T CROSS IT!)
	inc r2
;
;	>>>   LINE IS CROSSED RIGHT -> LEFT   <<<
;
_RM5XY2500:
;	with	r0				; SOLID / IMPASSIBLE?
	%and_i((rllfSolid|rllfImpassible))
	bne _RM5XY3000	; YES!  CAN'T CROSS IT!
;
;	>>>   GET HIGHFLOOR / LOWCEILING   <<<
;
	with r2	; Get HighFloor/LowCeiling
	%add_i((rlmlHighFloorHeight-rlmlFlags))
_RM5XY2600:
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
	bge _RM5XY3000	; YES!
;
;	>>>   ABOVE LOWER PASSAGE?   <<<
;
	inc r2	; R0 = LowCeiling
	inc r2
;	to	r0
	ldw (r2)
	ibt r11,#56	; Enough Ceiling Clearance?
	with r1	; R1 = ObjectZ+Height
	add r11
;	from	r0				; LowCeiling >= (ObjectZ+Height)?
	cmp r1
	blt _RM5XY3000	; NO!
;
;	>>>   ENOUGH FLOOR->CEILING CLEARANCE?   <<<
;
;	with	r0				; R0 = (LowCeiling-HighFloor)
	sub r4
;	with	r0				; Enough Clearance?
	sub r11	; @CMP@
	blt _RM5XY3000	; NO!
;
;	>>>   MONSTERS WILL NOT WALK OFF CLIFFS!   <<<
;
	inc r2	; R0 = LowFloor
	inc r2
;	to	r0
	ldw (r2)
	from r4	; R0 = (HighFloor-LowFloor)
;	to	r0
	sub r0
;	with	r0				; Large Cliff?
	sub r6	; @CMP@
	bge _RM5XY3000	; YES!
	nop
;
;	>>>   THIS LINE WILL NOT BLOCK MOVEMENT!   <<<
;
	iwt r15,#lo16(_RM5XY2200)+1	; Yes, Check Next MoveLine

;
;	* * * * * * *       THIS LINE WILL BLOCK MOVEMENT       * * * * * * *
;
_RM5XY3000:
;
;	>>>   ADJUST OBJECT MOVEMENT COORDINATES SO RADIUS INTERSECTS LINE   <<<
;
	lms r1,(MVObjD&$FFFF)	; Object<->Line Collision Radius
	sms (MVLPUY&$FFFF),!rPUY	; Save Perpendicular UnitVector Y
;
	move r6,!rPUY	; Adjust MovementY
	from r1
;	to	r0
	fmult
	move r6,!rPUX
	sms (MVLPRY&$FFFF),r0
;
	with !rY0	; Move Initial Coordinate Away
	sub r0
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
	bra _RM5XY4000
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
	bra _RM5XY4000
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
	bpl _RM5XY3900+1	; No, Line Doesn't Cross Object

;
;	>>>   DOES OBJECT CROSS LINE?   <<<
;
;_RM5XY3500
	lms !rPUX,(MVLPUX&$FFFF)
	lms !rPUY,(MVLPUY&$FFFF)
	from !rY1	; R1 = (ObjectY1 - LineY)
	to r1
	sub !rLY1
	link #4
	from !rX1	; R0 = (ObjectX1 - LineX)
;	to	r0
	bra _RM5XY4000
	sub !rLX1
;
	moves r0,r2
	bpl _RM5XY8000+1	; "LEFT" or "ON"?  Crosses Line: Blocked!
;
;	>>>   OBJECT DOES NOT CROSS LINE   <<<
;
_RM5XY3900:
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
	iwt r15,#lo16(_RM5XY2000)	; No, Same Side

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
_RM5XY4000:
	move r6,!rPUY
	with r1	; Result in R1:R2
_RM5XY4100:
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
	bpl _RM5XY4200	; "LEFT" or "ON"
	to r2
	inc r1	; "RIGHT" or "ON" (-1 -> 0)
_RM5XY4200:
	jmp r11
	nop


	%CACHEE(_RLMoveXY5)

;
;	* * * * * * *       OBJECT BLOCKED!       * * * * * * *
;
_RM5XY8000:
	lms !rObj,(MVRObj&$FFFF)
;	with	r0				; NO Movement Allowed!
	sub r0
	sms (MVIPercent&$FFFF),r0
	lms r15,(MVReturnAddress&$FFFF)	; Return to Caller
	nop

;
;	* * * * * * *       MOVE OBJECT       * * * * * * *
;
_RM5XY9000:
	lms !rVX,(MVVX&$FFFF)	; Velocity X
	lms !rVY,(MVVY&$FFFF)	; Velocity Y
	lms !rObj,(MVRObj&$FFFF)
	iwt r6,#$7FFF
	sms (MVIPercent&$FFFF),r6	; Save Percentage of Movement
	from !rObj
	to !rObjP
	%add_i(rloX)
;
;	>>>   UPDATE X COORDINATE   <<<
;
	from !rVX	; R3:R1 = X Velocity * Percentage
;	to	r0
	fmult
;	with	r0
	rol
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
;	with	r0
	add r1
;	from	r0
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
;	with	r0
	add r2
;	from	r0
	sbk
	inc !rObjP
	inc !rObjP
;	to	r0				; RY0 = Y Coordinate Integer
	ldw (!rObjP)
;	with	r0
	adc r3
;
;	* * * * * * *       MOVEMENT COLLISIONS COMPLETED!       * * * * * * *
;
;	>>>   REMOVE RLOBJECT FROM OLD SECTOR   <<<
;
	link #4	; Remove RLObject from Sector's ObjectList
	iwt r15,#lo16(_RLRemSectorObject)
;	from	r0
	sbk

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
	iwt r11,#lo16(_RLMoveXY7)	; Add RLObject to Sector's ObjectList
	iwt r15,#lo16(_RLAddSectorObject)
	nop
