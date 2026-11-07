	arch 65816
;**********************************************************************
;*                                                                    *
;*                  P R O J E C T :   REALITY_ENGINE                  *
;*                                                                    *
;*                            RADIUS DAMAGE                           *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlenemies.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


	!rObjX = r3	; Object X Coordinate
	!rObjY = r5	; Object Y Coordinate
	!rTObjX = r7	; Target X Coordinate
	!rTObjY = r8	; Target Y Coordinate
;
	!rEnemyTargets = r10	; Pointer to Enemy Targetting List
	!rTObj = r13	; Pointer to Target RLObject
	!rTObjSectorData = r1	; Target RLObject SectorData (FIXED ONLY)
	!rSectorData = r9	; Object's SectorData
;
	!rBSPStack = r9	; BSP Stack Pointer
;
	!rBSPBase = r12	; Pointer to BSP BASE
	!rRLLineCount = !rTObj	; RLEngine Line Counter
	!rLX1 = !rEnemyTargets	; Line X Coordinate
	!rLY1 = !rBSPStack	; Line Y Coordinate
	!rLTemp = !rRLLineCount	; Line Temporary
	!rSegPtr = !rBSPBase	; Segment Pointer

	!rRadiusDamages = r11	; Pointer to Radius Damages List
	!rObj = r12	; Pointer to RLObject


;
;	* * * * * * *       RADIUS DAMAGES       * * * * * * *
;
	%align_pad(0, 16, (_RLRD10000-_RLRadiusTargetAlign)&$0F)	; align 16,(_RLRD10000-_RLRadiusTargetAlign)&$0f
;
;	>>>   FINISHED RADIUS DAMAGES   <<<
;
_RLRD10000:
	iwt r0,#lo16(_RLEnemiesMove)	; HANDLE ENEMY MOVEMENT
	ibt r8,#bank(_RLEnemiesMove)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	* * * * * * *       NEXT RADIUS DAMAGE       * * * * * * *
;
_RLRD1100:
	lms !rRadiusDamages,(ENRadiusPtr&$FFFF)	; Restore Radius Damages List Index
	bra _RLRD1000
	nop
;
;	* * * * * * *       START RADIUS DAMAGES       * * * * * * *
;
_RLRadiusDamage:
	iwt !rRadiusDamages,#lo16(_RLRadiusDamages)	; Pointer to Radius Damages List
;
;	* * * * * * *       PROCESS NEXT RADIUS DAMAGE       * * * * * * *
;
_RLRD1000:
;	to	r0				; Get Next Radius Damage
	ldw (!rRadiusDamages)
	inc !rRadiusDamages
	dec r0
	bmi _RLRD10000	; No More Radius Damages!
	inc !rRadiusDamages
	to !rObjX	; Object X
	ldw (!rRadiusDamages)
	inc !rRadiusDamages
	inc !rRadiusDamages
	to !rObjY	; Object Y
	ldw (!rRadiusDamages)
	inc !rRadiusDamages
	inc !rRadiusDamages
	sms (ENRadiusPtr&$FFFF),!rRadiusDamages	; Save Radius Damages List Index
	bra _RLRadiusTarget
	nop

;
;	>>>   TARGET ACQUIRED!   <<<
;
_RLRD2500:
	lms !rTObj,(ENTObj&$FFFF)	; Restore Target RLObject
;
;	>>>   DETERMINE TYPE OF RADIUS DAMAGE   <<<
;
	lms r0,(ENRadiusPtr&$FFFF)	; Get Radius Pointer
;	with	r0
	sub #6
	to r4	; Get Damage Amount
	ldw (r0)
	from r4	; BFG?
;	to	r0
	hib
	inc r0
;	with	r0
	swap
	bpl _RLRD2600+1	; No, BARREL/ROCKET
;
;	>>>   BFG   <<<
;
	from !rTObj	; BFG
;	to	r0
	%add_i(rloType)
;	to	r0
	ldb (r0)
	dec r0
	bmi _RLRD2000	; PLAYER?  DON'T TAKE DAMAGE!
	nop
	bra _RLRD2800	; NO!  ENEMY!
;
;	>>>   BARREL/ROCKET -- CHECK RADIUS   <<<
;
_RLRD2600:
	from r4	; DAMAGE RADIUS
;	to	r0
	hib
	ibt r1,#40
	with r1	; DAMAGE RADIUS += DAMAGE MULTIPLIER
	add r0
	from !rObjX	; (ObjX - TObjX) within Range?
;	to	r0
	sub !rTObjX
	bpl _RLRD2620
	nop
;	with	r0
	not
;	inc	r0
_RLRD2620:
;	with	r0
	sub r1
	bge _RLRD2000	; No, Outside Range!
	from !rObjY	; (ObjY - TObjY) within Range?
;	to	r0
	sub !rTObjY
	bpl _RLRD2640
	nop
;	with	r0
	not
;	inc	r0
_RLRD2640:
;	with	r0
	sub r1
	bge _RLRD2000	; No, Outside Range!
;
;	>>>   DAMAGE TARGET!   <<<
;
_RLRD2800:
	from !rTObj
;	to	r0
	%add_i(rloFlags)
;	to	r0
	ldb (r0)
;	with	r0				; FIXED/MOVABLE?
	swap
;	with	r0
	add r0
	bmi _RLRD2850	; MOVABLE
	link #4
	iwt r15,#lo16(_RLGetXYSectorData)
	nop
	move !rTObjSectorData,!rSectorData	; Fixed Object's SectorData
	lms !rTObj,(ENTObj&$FFFF)	; Restore Target RLObject
	lms r0,(ENRadiusPtr&$FFFF)	; Get Radius Pointer
;	with	r0
	sub #6
	to r4	; Get Damage Amount
	ldw (r0)
_RLRD2850:
	link #4
	iwt r15,#lo16(_RLDamageObjectMR)
	nop
	lms r0,(ENRadiusPtr&$FFFF)	; Get Radius Pointer
;	with	r0
	sub #4
	to !rObjX	; Object X
	ldw (r0)
	inc r0
	inc r0
	to !rObjY	; Object Y
	bra _RLRD2000
	ldw (r0)

;
;	* * * * * * *       RADIUS TARGETTING       * * * * * * *
;
_RLRadiusTarget:
	iwt r0,#lo16(_RLMObjects)	; Pointer to Movable Objects List
	sms (ENEnemy&$FFFF),r0
;
	iwt !rBSPStack,#lo16(_RLBSPStack)	; Initialize BSP Stack Pointer
	iwt r0,#lo16(_RLRD2500)	; Final Return Address (TARGET ACQUIRED!)
;	from	r0
	stw (!rBSPStack)

	%CACHEB(_RLRadiusTarget)
_RLRadiusTargetAlign:
;
;	>>>   PROCESS NEXT ENEMY   <<<
;
_RLRD2000:
	lms !rEnemyTargets,(ENEnemy&$FFFF)	; Restore Enemy Pointer
	iwt r6,#lo16(_RLObjectsE)
_RLRD2200:
	from !rEnemyTargets	; At End of Fixed Objects?
;	to	r0
	sub r6
	with !rEnemyTargets
	bne _RLRD2220	; No, Check Next Object
	to !rTObj
	iwt r15,#lo16(_RLRD1100)	; Yes!  Finished Radius Damage!
;
;	>>>   ACTIVE TARGET OBJECT?   <<<
;
_RLRD2220:
	from !rTObj	; Get Object Flags
;	to	r0
	%add_i(rloFlags)
	to r1
	ldb (r0)
	from r1
;	to	r0
	swap
;	with	r0
	add r0
	ibt r4,#rloSize	; MOVABLE
	bmi _RLRD2240
	nop
	ibt r4,#rloSize0	; FIXED
_RLRD2240:
	with !rEnemyTargets	; Move to Next Object
	bcc _RLRD2200	; NOT ACTIVE
	add r4
;	with	r0				; TARGET?
	add r0
	bpl _RLRD2200	; NOT TARGET
	nop
;
;	>>>   ENSURE LINE-OF-SIGHT   <<<
;
	sms (ENEnemy&$FFFF),!rEnemyTargets	; Save Enemy Pointer
	bcc _RLRD2300	; FIXED
	nop
;
;	>>>   MOVABLE   <<<
;
	ibt r0,#(rloX+2)	; Get Target X Coordinate
;	with	r0
	add !rTObj
	to !rTObjX
	ldw (r0)
;	with	r0				; Get Target Y Coordinate
	%add_i(((rloY+2)-(rloX+2)))
	to !rTObjY
	bra _RLRD2400
	ldw (r0)
;
;	>>>   FIXED   <<<
;
_RLRD2300:
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb	; Set ROM Bank
	from !rTObj	; Get LevelObject
;	to	r0
	%add_i(rloLObj)
	to r4	; (in the level RAM image, GSU RAM $71)
	ldw (r0)
	ibt r0,#1
	ramb
	to !rTObjX
	ldw (r4)
	inc r4
	inc r4
	to !rTObjY
	ldw (r4)
	ibt r0,#0	; back to GSU RAM $70
	ramb
;
;	>>>   ENSURE LINE-OF-SIGHT   <<<
;
_RLRD2400:
	ibt r0,#lo16(EMBSP+2)	; Bank of EM Data
	assert (lo16(EMBSP+2))&$FFFF < $80 || (lo16(EMBSP+2))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	ldb (r0)
	romb	; Set ROM Bank
	iwt !rBSPStack,#lo16(_RLBSPStack+2)	; Initialize BSP Stack Pointer
	lms !rBSPBase,(EMBSP&$FFFF)	; BSP Base
	lms r1,(EMBSPR&$FFFF)	; BSP Root Node
	sms (ENTObj&$FFFF),!rTObj	; Save Target RLObject
	lms !rRLLineCount,(RLLineCount&$FFFF)	; RLEngineLineCount++
	inc !rRLLineCount
	from !rRLLineCount
	sbk
	iwt r15,#lo16(_RLRD7000)
	from r1	; Move to NODE

;
;	* * * * * * *       PROCESS THIS AREA       * * * * * * *
;
_RLRD3000:
	lms r1,(EMAREAS&$FFFF)	; AREA Base
;	from	r0
	to r14
	add r1
	lms !rSegPtr,(EMSEGS2&$FFFF)	; Add Base of SEGS (ADJUSTED!)
	to r6	; Get Number of SEGS in this AREA
	getb
	inc r14
	dec !rBSPStack	; Pop Stack
	dec !rBSPStack
	sms (BBBSPStack&$FFFF),!rBSPStack	; Save StackPointer
	getb	; Get Starting Segment
	inc r14
	getbh
	with !rSegPtr	; Move to Starting Segment
	add r0
	iwt r15,#lo16(_RLRD3250)
;
;	* * * * * * *       TRAVERSE BSP NODE       * * * * * * *
;
_RLRDNode:
;	alt1					; @ALT1 IN PIPELINE@
	getb	; Get NODE
	moves r0,r0	; Is this NODE an AREA?
	bmi _RLRD3000	; Yes
;
;	* * * * * * *       PROCESS NEXT NODE       * * * * * * *
;
_RLRD7000:
;	from	r0				; Move to NODE
	to r14
	add !rBSPBase
;
;	>>>   PUSH BSP POINTER   <<<
;
	from r14	; Push BSP Pointer
	stw (!rBSPStack)
	inc !rBSPStack
;
;	>>>   DETERMINE SIDE OF OBJECT <-> NODE   <<<
;
	move r1,!rObjY	; Y Coordinate
	link #3
	bra _RLRDSide
	with !rObjX	; X Coordinate
	bpl _RLRD9000	; >= 0 = LEFT
	inc !rBSPStack
;
;	* * * * * * *       OBJECT IS TO THE RIGHT OF THE NODE       * * * * * * *
;
_RLRD8000:
;
;	>>>   PROCESS RIGHT CHILD   <<<
;
	ibt r0,#(rlbRightChild-(rlbDeltaY+1))	; Get Right Child
	with r14
	add r0
	iwt r0,#lo16(_RLRD8500)	; Push Return Address
;	from	r0
	stw (!rBSPStack)
	inc !rBSPStack
	inc !rBSPStack
	getb
	inc r14
	iwt r15,#lo16(_RLRDNode)	; Recurse
	alt1
;
;	>>>   DETERMINE SIDE OF TARGET <-> NODE   <<<
;
_RLRD8500:
	dec !rBSPStack	; Get BSP Pointer
	dec !rBSPStack
	to r14
	ldw (!rBSPStack)
	move r1,!rTObjY	; Y Coordinate
	link #3
	bra _RLRDSide
	with !rTObjX	; X Coordinate
	bmi _RLRD8900	; < 0 = RIGHT
;
;	>>>   PROCESS LEFT CHILD   <<<
;
	with r14	; Get Left Child
	%add_i((rlbLeftChild-(rlbDeltaY+1)))
	getb
	inc r14
	iwt r15,#lo16(_RLRDNode)	; Recurse
	alt1
;
;	>>>   RECURSE   <<<
;
_RLRD8900:
	dec !rBSPStack	; Pop Stack
	dec !rBSPStack
	to r15	; Return to Caller
	ldw (!rBSPStack)

;
;	* * * * * * *       GET SIDE OF COORDINATE RELATIVE TO NODE       * * * * * * *
;
;	R(SOURCE) = X Coordinate
;	R1	  = Y Coordinate
;
;	R1 = SIDE
;
_RLRDSide:
	to r2	; @WITH IN PIPELINE@
;
;	>>>   (Xa * Yb)   <<<
;
	getb	; Get Line Y
	inc r14
	getbh
	inc r14
	with r1	; (Y - LineY)
	sub r0
;
	to r6	; Get Delta X
	getb
	inc r14
	with r6
	getbh
	inc r14
;
	with r1	; Result in R1:R2
	lmult
;
;	>>>   (Ya * Xb)   <<<
;
	getb	; Get Line X
	inc r14
	getbh
	inc r14
	from r2	; (X - LineX)
;	to	r0
	sub r0
;
	move r2,r4
;
	to r6	; Get Delta Y
	getb
	inc r14
	with r6
	getbh
;
_RLRDSide2:
;	with	r0				; Result in R0:R4
	lmult
;
;	>>>   DETERMINE DIRECTION OF NODE   <<<
;
;	IF RESULT >= 0, OBJECT IS TO THE LEFT OF THE NODE
;	IF RESULT <  0, OBJECT IS TO THE RIGHT OF THE NODE
;
	with r2	; Xa*Yb - Ya*Xb
	sub r4
	with r1
	sbc r0
	jmp r11	; @BELOW@
;
;	* * * * * * *       OBJECT IS TO THE LEFT OF THE NODE       * * * * * * *
;
_RLRD9000:
;
;	>>>   PROCESS LEFT CHILD   <<<
;
	with r14	; Get Left Child
	%add_i((rlbLeftChild-(rlbDeltaY+1)))
	iwt r0,#lo16(_RLRD9500)	; Push Return Address
;	from	r0
	stw (!rBSPStack)
	inc !rBSPStack
	inc !rBSPStack
	getb
	inc r14
	iwt r15,#lo16(_RLRDNode)	; Recurse
	alt1
;
;	>>>   DETERMINE SIDE OF TARGET <-> NODE   <<<
;
_RLRD9500:
	dec !rBSPStack	; Get BSP Pointer
	dec !rBSPStack
	to r14
	ldw (!rBSPStack)
	move r1,!rTObjY	; Y Coordinate
	link #3
	bra _RLRDSide
	with !rTObjX	; X Coordinate
	bpl _RLRD8900-1	; >= 0 = LEFT
;
;	>>>   PROCESS RIGHT CHILD   <<<
;
	ibt r0,#(rlbRightChild-(rlbDeltaY+1))	; Get Right Child
	with r14
	add r0
	getb
	inc r14
	iwt r15,#lo16(_RLRDNode)	; Recurse
	alt1

;
;	* * * * * * *       PROCESS THIS AREA       * * * * * * *
;
;	>>>   NO BLOCKING INTERSECTIONS WITH THIS AREA'S SEGMENTS!   <<<
;
_RLRD3100:
	lms !rBSPBase,(EMBSP&$FFFF)	; BSP Base
	lms !rBSPStack,(BBBSPStack&$FFFF)	; Restore StackPointer
	to r15	; Return to Caller
	ldw (!rBSPStack)
;
;	* * * * * * *       GET SIDE OF VERTEX RELATIVE TO SIGHT       * * * * * * *
;
;	 R14 = Address of (Vertex X, Vertex Y)
;
;	RLX1 = Vertex X
;	RLY1 = Vertex Y
;	  R2 = Side
;
_RLRDVSide:
	getb	; Get Vertex X Coordinate
	inc r14
	from !rTObjY
	to r6
	sub !rObjY
	to !rLX1
	getbh
	inc r14
	from !rLX1	; -(LX1-ObjX) * (TObjY-ObjY)
;	to	r0
	sub !rObjX
;	from	r0				; r1:r2
	to r1
	lmult
	getb	; Get Vertex Y Coordinate
	inc r14
	from !rTObjX
	to r6
	sub !rObjX
	move r2,r4
	to !rLY1
	getbh
	from !rLY1	; (LY1-ObjY) * (TObjX-ObjX)
;	to	r0
	bra _RLRDSide2
	sub !rObjY

;
;	* * * * * * *       PROCESS NEXT SEGMENT       * * * * * * *
;
_RLRD3200:
	lms r6,(BBSegCount&$FFFF)	; Get Segment Counter
	lms !rRLLineCount,(RLLineCount&$FFFF)	; Get RLEngineLineCount
_RLRD3250:
	iwt r2,#lo16(_RLLineRLCounts)	; RLEngine Generation LineCounter
	from !rSegPtr
	to r14	; Move to Next Segment
_RLRD3300:
	%add_i((rlgSize-(rlgLine+1)+rlgLine))
	dec r6	; One More Segment Processed
	bmi _RLRD3100	; No More Segments!
	getb	; Get Segment.Line
	inc r14
	getbh
;	from	r0				; Line*2
	to r4
	add r0
	from r2	; Get LineCounter
	to r1
	add r4
;	to	r0
	ldw (r1)
;	with	r0				; Already processed this Line?
	sub !rRLLineCount	; @CMP@
	beq _RLRD3300	; Yes!
	with r14	; Move to Next Segment
;
;	>>>   DOES SEGMENT INTERSECT OBJECT->TARGET RAY?   <<<
;
	to !rSegPtr	; Save Segment Pointer
	sms (ENRadiusLine&$FFFF),r4	; Save Line*2
	with r4	; Line*4
	add r4
	from r4	; Line*8
;	to	r0
	add r4
;	with	r0				; Line*12
	add r4
	lms r2,(EMLINES&$FFFF)	; Get Base Address of Lines Table (level RAM $71)
;	with	r0				; Move to LINE VERTEXES
	add r2
;
	from !rRLLineCount	; Update RLEngine Generation LineCounter
	stw (r1)
	sms (BBSegCount&$FFFF),r6	; Save Segment Counter
	lms r2,(EMVERTEXES&$FFFF)	; Get Base Address of ROM Vertexes Table
	%RAMB71(r1)
	to !rLTemp	; Get VERTEX1
	ldw (r0)
	inc r0
	inc r0
	to r1	; Get VERTEX2
	ldw (r0)
	%RAMB70(r0)
	with !rLTemp	; Move to VERTEX1
	add r2
	from r1	; Move to VERTEX2
	to r14
	add r2
;
	sms (BBAreaPtr&$FFFF),r14	; Save VERTEX2
	link #3	; GET SIDE OF VERTEX2
	bra _RLRDVSide+1
	getb	; Get Vertex X Coordinate
	from !rLTemp	; @WITH IN PIPELINE@
;
	link #4	; GET SIDE OF VERTEX1
	with r1	; RLTEMP = VERTEX 2 SIDE
	bra _RLRDVSide
	to !rLTemp
;
	with r1	; @WITH IN PIPELINE@
	xor !rLTemp	; Same Side?
	bpl _RLRD3200+1	; Yes, No Intersection
;
;	* * * * * * *       PROJECT ONTO LINE PERPENDICULAR       * * * * * * *
;
_RLRD4000:
	lms r14,(BBAreaPtr&$FFFF)	; Restore VERTEX2
;
	getb	; Line Vertex 2 X
	inc r14
	getbh
	inc r14
	from !rLX1	; Perpendicular Vector Y (LX1-LX2)
	to r6
	sub r0
	from !rObjY	;  L1 = (OY-LY) * Perpendicular Vector Y
;	to	r0				; (r2:rLTemp)
	sub !rLY1
;	from	r0
	to r2
	lmult
;
	getb	; Line Vertex 2 Y
	inc r14
	move !rLTemp,r4
	from !rTObjY	;  L2 = (TY-LY) * Perpendicular Vector Y
	to r1	; (r1:r14)
	sub !rLY1
	with r1
	lmult
;	with	r0				; Line Vertex 2 Y
	getbh
;	from	r0				; Perpendicular Vector X  (LY2-LY1)
	to r6
	sub !rLY1
	move r14,r4
;
	from !rObjX	;  L1 += (0X-LX) * Perpendicular Vector X
;	to	r0				; (r2:rLTemp)
	sub !rLX1
;	with	r0
	lmult
	with !rLTemp
	add r4
	with r2
	adc r0
;
	from !rTObjX	;  L2 += (TX-LX) * Perpendicular Vector X
;	to	r0				; (r1:r4)
	sub !rLX1
;	with	r0
	lmult
	with r4
	add r14
	with r1
	adc r0
	from r1	; Same Side?
;	to	r0
	xor r2
	bpl _RLRD4900	; Yes, No Intersection!
;
;	>>>   OBJECT->TARGET RAY INTERSECTS SEGMENT!   <<<
;
	from !rSegPtr	; Get Segment.Flags
	to r14
	%sub_i(((rlgLine+1)-rlgFlags))
	getb
;	with	r0				; TRANSPARENT?
	lsr
	bcs _RLRD4500	; NO!  SOLID!
	nop
;
;	>>>   CHECK FOR CLOSED DOOR   <<<
;
	lms r0,(ENRadiusLine&$FFFF)	; Get Line*2
;	with	r0				; Get Line#
	lsr
	iwt r1,#lo16(_RLLineFlags)	; Get LINE FLAGS
;	with	r0
	add r1
;	to	r0
	ldb (r0)
;	with	r0				; TRANSPARENT?
	lsr
	bcc _RLRD4900+1	; YES!
;
;	>>>   TARGET NOT ACQUIRED!   <<<
;
_RLRD4500:
	iwt r15,#lo16(_RLRD2000)	; SOLID!  TARGET NOT ACQUIRED!
	nop
;
;	>>>   NO INTERSECTION   <<<
;
_RLRD4900:
	iwt r15,#lo16(_RLRD3200)	; Next Segment
	nop

	%CACHEE(_RLRadiusTarget)
