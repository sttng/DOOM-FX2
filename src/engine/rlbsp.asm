	arch 65816
	; plist ON
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                          ENGINE BSP MODULE                         *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildBSP


	%section(ENGINE_GSUCODE)
	arch superfx

;
;	* * * * * * *       REALITY_ENGINE BUILD BSP TREE       * * * * * * *
;
;	GO THROUGH BSP TREE AND BUILD AREA/SEGMENT TRAVERSAL LIST
;

	!rSightLeftX = r2	; Left SightLine Delta X
	!rSightLeftY = r3	; Left SightLine Delta Y
	!rSightRightX = r5	; Right SightLine Delta X
	!rSightRightY = r7	; Right SightLine Delta Y
;
	!rBSPPtr = r8	; Pointer to BSP NODE
	!rBSPStack = r9	; BSP Stack Pointer
	!rAreaPtr = r10	; Pointer to AREA/SEGS List
	!rAreaPtrP = r11	; Pointer to Previous AREA/SEGS Entry
;
	!rPt1X = !rBSPPtr	; SightLine Point1 X Coordinate
	!rPt1Y = !rBSPStack	; SightLine Point1 Y Coordinate
	!rPt2X = !rAreaPtr	; SightLine Point2 X Coordinate
	!rPt2Y = !rAreaPtrP	; SightLine Point2 Y Coordinate
;
	!rInSightCode = r12	; Pointer to Code if NODE In Sight
	!rOutSightCode = r13	; Pointer to Code if NODE Out of Sight
	!rBSPTemp = !rOutSightCode
	!rViewY = !rInSightCode



	%align_pad(8, 16, (_RLBuildBSP-_RLBSPNode)&$0F)	; align 16,(_RLBuildBSP-_RLBSPNode)&$0f
;
;	* * * * * * *       BUILD AREA/SEGMENT LIST FROM BSP NODES       * * * * * * *
;
	RLAreaSegLimit = $FE00	; end of the AreaSegList (this port: an area is added only when it fits)
	if not(defined("RLAREACHUNK"))
	!RLAREACHUNK = 1024
	endif
	RLAreaChunk = !RLAREACHUNK	; (this port) AreaSegList bytes per chunk (~73 segments): the
				; segment passes run after each chunk, the walk stops once the
				; view is covered (512, 2048 or doubling chunks: less gain)
	_RLRenderBSPStack = $70FE00	; (this port) the walk's own stack: _RLBSPStack lies under the
;					; VSegs, built between chunks; the plot data reaches here only later
_RLBuildBSP:
	if !RLREJECTPVS != 0
;
;	>>>   VISIBILITY ROW OF THE PLAYER'S SECTOR (this port: FX3-style REJECT = PVS)   <<<
;
	if useMULTIPLAYER == 0
	iwt r2,#lo16(PlayerObject)
	else
	lms r2,(MPPlayerObject&$FFFF)
	endif
	ibt r0,#rloSector
	add r2
	ldb (r0)
	move r1,r0	; r1 = Player's Sector
	lms r0,(EMNUMSECTORS&$FFFF)	; RowBytes = (NumSectors+7)>>3
	%add_i(7)
	lsr
	lsr
	lsr
	umult r1
	lms r1,(EMREJECT&$FFFF)	; (level RAM image in GSU RAM $71, or ROM: EMBSP+3)
	add r1
	sms (PVSRow&$FFFF),r0
	ibt r0,#rloSector	; r1 = Player's Sector again
	add r2
	to r1
	ldb (r0)
	lms r0,(NVSector&$FFFF)	; Visibility bits built for this sector?
	sub r1
	beq _RLBuildBSP050	; Yes
	nop
	sms (NVSector&$FFFF),r1
	iwt r15,#lo16(_RLBuildVisBits)	; No, rebuild them (returns to _RLBuildBSP050)
	nop
_RLBuildBSP050:
	endif
	iwt !rAreaPtr,#lo16(_RLAreaSegList)	; Initialize AREA/SEGMENT Pointer
	iwt r0,#lo16(_RLAreaSegList+RLAreaChunk)	; (this port) End of the first chunk
	sms (TRPreWallPlotPtr0&$FFFF),r0	; (free while walking)
;
	iwt !rBSPStack,#lo16(_RLRenderBSPStack)	; Initialize BSP Stack Pointer
	iwt r0,#lo16(_RLBuildBSP200)	; Final Return Address
	stw (!rBSPStack)
	inc !rBSPStack
	inc !rBSPStack
	lms !rBSPPtr,(EMBSPR&$FFFF)	; BSP Root Node
	sub r0	; (this port, chunks: _RBNFull)
	sms (TRXsT&$FFFF),r0	; 0 = Nothing to resume
	sms (TRClipRangePtr&$FFFF),r0	; 0 = SegList1 not run this frame
	link #4
	iwt r15,#lo16(_RBNSight)
	nop
;
	sub r0	; (this port) Empty list
	sms (SLAreaPtr&$FFFF),r0
	iwt !rAreaPtrP,#lo16(SLAreaPtr)	; "Previous AREA": the list start (its Next = SLAreaPtr)
	iwt r15,#lo16(_RLBSPNode0)
	nop
;
;	>>>   INITIALIZE VIEW SIGHTLINE DELTAS (and the ROM bank of the EM data)   <<<
;
_RBNSight:
	ibt r0,#bank(SightRayTable)	; Bank of SightRayTable
	romb
	lms r0,(ViewAngle&$FFFF)	; Get ViewAngle
	lsr
	lsr
	lsr
	lsr
	lsr	; >>5
	lsr	; Remove lowest bit
	add r0
	add r0
	add r0
	iwt r1,#lo16(SightRayTable)	; Add Base of SightRayTable
	from r1
	to r14
	add r0
	getb	; Get LeftDeltaX
	inc r14
;	from	r0
	to !rSightLeftX
	getbh
	inc r14
	getb	; Get LeftDeltaY
	inc r14
;	from	r0
	to !rSightLeftY
	getbh
	inc r14
	getb	; Get RightDeltaX
	inc r14
;	from	r0
	to !rSightRightX
	getbh
	inc r14
	getb	; Get RightDeltaY
	inc r14
;	from	r0
	to !rSightRightY
	getbh
;
	ibt r0,#lo16(EMBSP+2)	; Bank of EM Data
	assert (lo16(EMBSP+2))&$FFFF < $80 || (lo16(EMBSP+2))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	ldb (r0)
	romb	; Set ROM Bank
	jmp r11
	nop
;
_RLBuildBSP200:
;	(SLAreaPtr: the first, nearest AREA/SEGS Entry, set while walking)

	if !DEBUGSCR != 0
	sm (DebugBSPPtr&$FFFF),!rAreaPtr
	endif
	sub r0	; The walk is done: nothing to resume
	sms (TRXsT&$FFFF),r0
;
;	>>>   BUILD DISPLAY SEGMENT LIST   <<<
;
;	(this port) The segment passes run on each chunk of the AreaSegList:
;	SegList1 (marks the vertexes not rotated) once per frame, then SegList2..4
;	(SegList4 goes on with the walk: _RLBuildBSPResume)
;
_RBNSegs:
	lms r0,(TRClipRangePtr&$FFFF)	; SegList1 run this frame?
	moves r0,r0
	bne _RBNSegs2
	nop
	inc r0	; 1: SegList1 done, SegList4 not started
	sbk
	iwt r0,#lo16(_RLBuildSegList1)	; BUILD SEGMENT LIST
	ibt r8,#bank(_RLBuildSegList1)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop
_RBNSegs2:
	iwt r0,#lo16(_RLBuildSegList2)	; BUILD SEGMENT LIST 2
	ibt r8,#bank(_RLBuildSegList2)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop
;
;	>>>   GO ON WITH THE WALK AFTER A CHUNK (from _RLBuildSegList4)   <<<
;
_RLBuildBSPResume:
	sub r0
	sms (TRXsT&$FFFF),r0
	sms (SLAreaPtr&$FFFF),r0	; Empty list
	iwt !rAreaPtr,#lo16(_RLAreaSegList)
	iwt r0,#lo16(_RLAreaSegList+RLAreaChunk)	; End of the next chunk
	sms (TRPreWallPlotPtr0&$FFFF),r0
	link #4
	iwt r15,#lo16(_RBNSight)
	nop
	lms !rBSPStack,(TRYs0&$FFFF)
	lms !rBSPPtr,(TRCeilingY&$FFFF)	; The AREA that did not fit, again
	iwt !rAreaPtrP,#lo16(SLAreaPtr)	; (the list starts again)
	iwt r15,#lo16(_RLBSPNode0)	; (this port: through CACHE again, the segment passes
	nop	; loaded their own code)


;
;	* * * * * * *       TRAVERSE BSP NODE       * * * * * * *
;
_RLBSPNode0:
	%CACHEB(_RLBSPNode)
_RLBSPNode:
	moves !rBSPPtr,!rBSPPtr	; Is this NODE an AREA?
	bpl _RBN2000	; No
;
;	>>>   ADD AREA TO AREALIST   <<<
;
	lms r0,(EMAREAS&$FFFF)	; AREA Base
;	from	r0
	to r14
	add !rBSPPtr
	if !RLREJECTPVS != 0
;
;	>>>   CAN THIS AREA'S SECTOR BE SEEN FROM THE PLAYER'S SECTOR?   <<<
;	(this port, PVS: whole hidden rooms are skipped before any segment work)
;
	from !rBSPPtr	; AREA bit = offset/4
	add !rBSPPtr
	lsr
	lsr
	lsr
	iwt r1,#lo16(_RLAreaVisBits)
	iwt r13,#lo16(_RBN0500)	; (continue here if visible)
	bra _RBNVis
	nop
_RBN0500:
	endif
	lms r1,(EMSEGS&$FFFF)	; Base of SEGS (added below)
	to r12	; Get Number of SEGS in this AREA
	getb
	inc r14
;
;	>>>   DOES THE AREA FIT?  (this port)   <<<
;
;	When the chunk is full, the segment passes run on the (nearer) areas it
;	holds, then the walk goes on with an empty list; SegList4 does not resume
;	it once the view is covered.  (Original: no end check.)
;
_RBNFit:
	from r12	; Room for 6 + 14 x #Segs bytes (in this chunk)?
	%umult_i(rluSize)
	%add_i(6)
	add !rAreaPtr
	lms r6,(TRPreWallPlotPtr0&$FFFF)	; (r6: r1 keeps the SEGS base)
	cmp r6
	bcc _RBN0600	; Yes
	nop
	iwt r15,#lo16(_RBNFull)
	nop
_RBN0600:
	sms (TRClipRangePtr0&$FFFF),!rAreaPtr	; (this port) This AREA's entry (linked after the
	sub r0	; previous one below; TRClipRangePtr0 is free while walking)
	stw (!rAreaPtr)	; Next AREA/SEG Entry = none yet
	inc !rAreaPtr
	inc !rAreaPtr
	getb	; Get Starting Segment
	inc r14
	from r14	; Save Pointer to Area-1
	stw (!rAreaPtr)
	inc !rAreaPtr
	inc !rAreaPtr
	getbh
;	with	r0				; R0 = (StartingSegment-1)
	add r1
;
;	>>>   ADD AREA'S SEGMENTS TO AREALIST   <<<
;
	ibt r1,#rluSize	; Size of Each Area/Segment Entry
_RBN1000:
;	with	r0				; Next Segment
	%add_i(rlgSize)
;	from	r0
	stw (!rAreaPtr)	; Save Segment
	dec r12	; One More Segment
	with !rAreaPtr	; Next Area/Segment Entry
	bne _RBN1000
	add r1
;
;	>>>   LINK THE AREA AFTER THE PREVIOUS ONE   <<<
;
;	(this port) The BSP is walked near to far, each entry linked to the next
;	(original: far to near, each entry pointing back to the previous one, the
;	list read from the last, nearest one).  The passes see the same order,
;	so a full chunk holds the near areas.
;
	lms r0,(TRClipRangePtr0&$FFFF)
	stw (!rAreaPtrP)	; Previous.Next = this AREA (the first: SLAreaPtr)
	move !rAreaPtrP,r0

	if !useCHECKBSPDATA != 0
;	moves	rAreaPtr,rAreaPtr		; Error with BSP AreaSegList?
	bmi ._0
	%HALTGSU($60)	; YES!
._0:
	endif
;
;	>>>   TERMINATE AREA LIST   <<<
;
	ibt r0,#$0001	; Terminator Segment
	stw (!rAreaPtr)
	inc !rAreaPtr
	bra _RBNRet	; Return to Caller
	inc !rAreaPtr
;
	if !RLREJECTPVS == 0
;
;	>>>   RETURN TO CALLER (done, or outside sight; data sets without PVS)   <<<
;
_RBNRet:
	dec !rBSPStack	; Pop Stack
	dec !rBSPStack
	to r15	; Return to Caller
	ldw (!rBSPStack)
	nop
	endif
;
;	>>>   PROCESS NEXT NODE   <<<
;
_RBN2000:
;	move	r0,(<EMBSP)			; BSP Base
	db $A0,lo16(EMBSP/2)	; (alt1 from the delay slot of bpl _RBN2000: lms r0,(EMBSP))
	from !rBSPPtr	; Move to NODE
	to r14
	add r0
	if !RLREJECTPVS != 0
;
;	>>>   CAN ANY SECTOR BEHIND THIS NODE BE SEEN FROM THE PLAYER'S SECTOR?   <<<
;
	iwt r6,#2341	; NODE bit = offset/rlbSize (*65536/28, exact below 5461 NODES)
	assert rlbSize == 28
	from !rBSPPtr
	lmult
	iwt r1,#lo16(_RLNodeVisBits)
	iwt r13,#lo16(_RBN2050)	; (continue here if visible)
;
;	>>>   TEST VISIBILITY BIT r0 OF THE BITS AT r1 (bit masks at r1-8)   <<<
;
_RBNVis:
	move r6,r0
	lsr
	lsr
	lsr
	add r1
	to r4
	ldb (r0)
	from r6
	%and_i(7)
	add r1
	%sub_i(8)
	ldb (r0)
	and r4
	bne _RBNVis2	; Visible
	nop
;
;	>>>   RETURN TO CALLER (hidden NODE/AREA, done, or outside sight)   <<<
;
_RBNRet:
	dec !rBSPStack	; Pop Stack
	dec !rBSPStack
	to r15	; Return to Caller
	ldw (!rBSPStack)
	nop
_RBNVis2:
	jmp r13
	nop
_RBN2050:
	endif
;
;	>>>   CALCULATE CROSS PRODUCT OF <PARTITION> AND <VIEW>   <<<
;
;			   (Xa * Yb) - (Ya * Xb)
;
;	= (DeltaX * (ViewY-LineY)) - (DeltaY * (ViewX-LineX))
;
;
;	>>>   (Xa * Yb)   <<<
;
	getb
	inc r14
	lms r1,(ViewY&$FFFF)	; Get View Y
	getbh
	inc r14
	with r1	; (ViewY - LineY)
	sub r0
;
	to r6	; Get Delta X
	getb
	inc r14
	with r6
	getbh
	inc r14
;
	with r1	; Result in R1:R12
	lmult
	move r12,r4
;
;	>>>   (Ya * Xb)   <<<
;
	getb	; Get Line X
	inc r14
	lms r4,(ViewX&$FFFF)	; Get View X
	getbh
	inc r14
	from r4	; (ViewX - LineX)
;	to	r0
	sub r0
;
	to r6	; Get Delta Y
	getb
	inc r14
	with r6
	getbh
	inc r14
;
;	with	r0				; Result in R0:R4
	lmult
;
;	>>>   DETERMINE DIRECTION OF NODE   <<<
;
;	IF RESULT >= 0, VIEW IS TO THE LEFT OF THE NODE
;	IF RESULT <  0, VIEW IS TO THE RIGHT OF THE NODE
;
	with r12	; Xa*Yb - Ya*Xb
	sub r4
	with r1
	sbc r0
	bmi _RBN4000	; < 0 = RIGHT (this port: near child first; original: bpl, far first)

;
;	* * * * * * *       VIEW IS TO THE LEFT OF THE NODE       * * * * * * *
;
_RBN3000:
;
;	>>>   PROCESS LEFT CHILD   <<<
;
	iwt !rInSightCode,#lo16(_RBN3200)	; NODE is WITHIN LineOfSight
	iwt !rOutSightCode,#lo16(_RBN3600)	; NODE is OUTSIDE LineOfSight
	bra _RLBSPSight	; Check LineOfSight
_RBN3200:
	from r14	; Push BSP Pointer
	stw (!rBSPStack)
	to !rBSPPtr
	getb
	inc r14
	inc !rBSPStack
	inc !rBSPStack
	iwt r0,#lo16(_RBN3500)	; Push Return Address
;	from	r0
	stw (!rBSPStack)
	inc !rBSPStack
	with !rBSPPtr
	getbh
	iwt r15,#lo16(_RLBSPNode)	; Recurse
	inc !rBSPStack
;
;	>>>   PROCESS RIGHT CHILD   <<<
;
_RBN3500:
	dec !rBSPStack	; Get BSP Pointer
	dec !rBSPStack
	to r14
	ldw (!rBSPStack)
_RBN3600:
	inc r14	; Move to Right BoundaryBox
	inc r14
	iwt !rOutSightCode,#lo16(_RBNRet)	; NODE is OUTSIDE LineOfSight
	from !rOutSightCode	; Push _RBNRet (the child returns to our caller)
	stw (!rBSPStack)
	iwt !rInSightCode,#lo16(_RBN3700)	; NODE is WITHIN LineOfSight
	bra _RLBSPSight+1
	getb	; Get MaxY
_RBN3700:
	to !rBSPPtr
	getb
	inc r14
	inc !rBSPStack
	inc !rBSPStack
	with !rBSPPtr
	getbh
	iwt r15,#lo16(_RLBSPNode)+1	; Recurse
	with !rBSPPtr	; Is this NODE an AREA?
;
;	>>>   RECURSE   <<<
;

;
;	* * * * * * *       VIEW IS TO THE RIGHT OF THE NODE       * * * * * * *
;
_RBN4000:
;
;	>>>   PROCESS RIGHT CHILD   <<<
;
;	iwt	rInSightCode,#<_RBN4200		; NODE is WITHIN LineOfSight
	dw lo16(_RBN4200)	; (the iwt opcode is the bmi delay slot)
	iwt !rOutSightCode,#lo16(_RBN4600)	; NODE is OUTSIDE LineOfSight
	with r14	; Move to Right BoundaryBox
	%add_i((rlbRightYMax-rlbLeftYMax))
	bra _RLBSPSight	; Check LineOfSight
_RBN4200:
	from r14	; Push BSP Pointer
	stw (!rBSPStack)
	to !rBSPPtr
	getb
	inc r14
	inc !rBSPStack
	inc !rBSPStack
	iwt r0,#lo16(_RBN4500)	; Push Return Address
;	from	r0
	stw (!rBSPStack)
	inc !rBSPStack
	with !rBSPPtr
	getbh
	iwt r15,#lo16(_RLBSPNode)	; Recurse
	inc !rBSPStack
;
;	>>>   PROCESS LEFT CHILD   <<<
;
_RBN4500:
	dec !rBSPStack	; Get BSP Pointer
	dec !rBSPStack
	to r14
	ldw (!rBSPStack)
_RBN4600:
	ibt r0,#(rlbRightChild-rlbLeftYMax)	; Move to Left BoundaryBox
	with r14
	sub r0
	iwt !rOutSightCode,#lo16(_RBNRet)	; NODE is OUTSIDE LineOfSight
	from !rOutSightCode	; Push _RBNRet (the child returns to our caller)
	stw (!rBSPStack)
	iwt !rInSightCode,#lo16(_RBN3700)	; NODE is WITHIN LineOfSight (shared with _RBN3600)
	bra _RLBSPSight+1
	getb	; Get MaxY
;
;	>>>   RECURSE   <<<
;

;
;	* * * * * * *       TEST LINE-OF-SIGHT BOUNDARIES       * * * * * * *
;
;	Entry:	(r14) Points to BoundaryBox MaxY,MinY,MinX,MaxX,ChildPtr
;		(_RLBSPSight+1: MaxY low byte read in the delay slot)
;
;	Exit:	(r14) Points to ChildPtr
;
_RLBSPSight:
;
;	>>>   DETERMINE WHICH TWO POINTS TO USE   <<<
;
;	   A		B	    C
;
;	(X1,Y1) *----------------
;		!               !
;		!               !
;	   D	!       E       !   F
;		!               !
;		!               !
;		----------------* (X2,Y2)
;
;	   G		H	    I
;
;
	getb	; Get MaxY
	inc r14
	sms (BBBSPStack&$FFFF),!rBSPStack	; Save BSP Stack Pointer
;	from	r0
	to !rPt1Y
	getbh
	inc r14
	sms (BBOutSightCode&$FFFF),!rOutSightCode	; Save OUTOFSIGHT Code Address
;
	getb	; Get MinY
	inc r14
	sms (BBAreaPtrP&$FFFF),!rAreaPtrP	; Save AREA Pointer Previous
;	from	r0
	to !rPt2Y
	getbh
	inc r14
	sms (BBInSightCode&$FFFF),!rInSightCode	; Save INSIGHT Code Address
;
	getb	; Get MinX
	inc r14
	sms (BBBSPPtr&$FFFF),!rBSPPtr	; Save BSP NODES Pointer
;	from	r0
	to !rPt1X
	getbh
	inc r14
;
	getb	; Get MaxX
	inc r14
	lms !rViewY,(ViewY&$FFFF)	; Get ViewY
	sms (BBAreaPtr&$FFFF),!rAreaPtr	; Save AREA Pointer
;
;	from	r0
	to !rPt2X
	getbh
	inc r14
;
	from !rPt2Y	; @CMP@
;	to	r0
	sub !rViewY
	bge _RBSGHI
	from !rPt1Y	; @CMP@
;	to	r0
	sub !rViewY
	bge _RBSDEF
_RBSABC:
	lms r0,(ViewX&$FFFF)	; Get ViewX
;	from	r0
	cmp !rPt1X
	blt _RBSA	; <A>
	nop
_RBSBC:
;	from	r0
	cmp !rPt2X
	bge _RBSC
	with !rPt1Y	; <B>
	bra _RBS2000
	to !rPt2Y
_RBSDEF:
;	move	r0,(<ViewX)			; Get ViewX
	db $F0
	dw lo16(ViewX)
;
;	from	r0
	cmp !rPt1X
	bge _RBSEF
	nop
	with !rPt1X	; <D>
	bra _RBS2000
	to !rPt2X
_RBSEF:
;	from	r0
	cmp !rPt2X
	bge _RBSF	; <F>
	nop
	iwt r15,#lo16(_RBS8000)	; <E>
_RBSF:
	with !rPt2X
	bra _RBS2000
	to !rPt1X
_RBSGHI:
	lms r0,(ViewX&$FFFF)	; Get ViewX
;	from	r0
	cmp !rPt1X
	blt _RBSG	; <G>
	nop
;	from	r0
	cmp !rPt2X
	bge _RBSI
	with !rPt2Y	; <H>
	bra _RBS2000
	to !rPt1Y
_RBSI:
_RBSA:
	move r4,!rPt1Y	; <A>, <I>: swap Pt1Y/Pt2Y
	move !rPt1Y,!rPt2Y
	move !rPt2Y,r4
;
;	>>>   CHECK LEFT SIGHTLINE   <<<
;
_RBSC:
_RBSG:
_RBS2000:
;
;	>>>   (Xa * Yb)   <<<
;
	move r6,!rSightLeftX	; Get Delta X (Xa)
	from !rPt1Y	; (Pt1Y - ViewY)
	to r1
	sub !rViewY
	with r1	; Result in R1:RBSPTemp
	lmult
	move !rBSPTemp,r4
;
;	>>>   (Ya * Xb)   <<<
;
	move r6,!rSightLeftY	; Get Delta Y (Ya)
	from !rPt1X	; (Pt1X - ViewX)
;	to	r0
	sub r0
;	with	r0				; Result in R0:R4
	lmult
;
	with !rBSPTemp	; Xa*Yb - Ya*Xb
	sub r4
	with r1
	sbc r0
	bmi _RBS4000	; < 0 = RIGHT
	with !rSightRightX	; (delay slot, no effect)
;
;	>>>   (Ya * Xb)   <<<
;
	lms r1,(ViewX&$FFFF)
	from !rPt2X	; (Pt2X - ViewX)
;	to	r0
	sub r1
;	from	r0				; Result in R1:RBSPTemp
	to r1
	lmult
	move !rBSPTemp,r4
;
;	>>>   (Xa * Yb)   <<<
;
	move r6,!rSightLeftX	; Get Delta X (Xa)
	from !rPt2Y	; (Pt2Y - ViewY)
;	to	r0
	sub !rViewY
;	with	r0				; Result in R0:R4
	lmult
;
	with r4	; Xa*Yb - Ya*Xb
	sub !rBSPTemp
;	with	r0
	sbc r1
	bpl _RBS9000	; >= 0 = LEFT
;
;	>>>   CHECK RIGHT SIGHTLINE   <<<
;
_RBS4000:
;
;	>>>   (Xa * Yb)   <<<
;
	move r6,!rSightRightX	; Get Delta X (Xa)
	from !rPt1Y	; (Pt1Y - ViewY)
;	to	r0
	sub !rViewY
;	from	r0				; Result in RPt1Y:RBSPTemp
	to !rPt1Y
	lmult
	move !rBSPTemp,r4
;
;	>>>   (Ya * Xb)   <<<
;
	move r6,!rSightRightY	; Get Delta Y (Ya)
	lms r0,(ViewX&$FFFF)
	with !rPt1X	; (Pt1X - ViewX)
	sub r0
	with !rPt1X	; Result in RPt1X:R4
	lmult
;
	with !rBSPTemp	; Xa*Yb - Ya*Xb
	sub r4
	with !rPt1Y
	sbc !rPt1X
	bpl _RBS6000	; >= 0 = LEFT
;
;	>>>   (Ya * Xb)   <<<
;
	from !rPt2X	; (Pt2X - ViewX)
;	to	r0
	sub r0
;	from	r0				; Result in RPt2X:RBSPTemp
	to !rPt2X
	lmult
	move !rBSPTemp,r4
;
;	>>>   (Xa * Yb)   <<<
;
	move r6,!rSightRightX	; Get Delta X (Xa)
	from !rPt2Y	; (Pt2Y - ViewY)
;	to	r0
	sub !rViewY
;	with	r0				; Result in R0:R4
	lmult
;
	with r4	; Xa*Yb - Ya*Xb
	sub !rBSPTemp
;	with	r0
	sbc !rPt2X
	bmi _RBS9000+1	; < 0 = RIGHT

;
;	>>>   CHECK BEHIND SIGHTLINE   <<<
;
_RBS6000:

;
;	>>>   INCLUDE NODE (WITHIN LINE OF SIGHT)   <<<
;
_RBS8000:
	lms r13,(BBInSightCode&$FFFF)
	bra _RBS9100
	nop
;
;	>>>   EXCLUDE NODE (OUTSIDE LINE OF SIGHT)   <<<
;
_RBS9000:
	lms r13,(BBOutSightCode&$FFFF)	; (bmi _RBS9000+1 enters here after its alt1 delay byte)
_RBS9100:
	lms !rBSPPtr,(BBBSPPtr&$FFFF)	; Restore BSP NODES Pointer
	lms !rBSPStack,(BBBSPStack&$FFFF)	; Restore BSP Stack Pointer
	lms !rAreaPtr,(BBAreaPtr&$FFFF)	; Restore AREA Pointer
	lms !rAreaPtrP,(BBAreaPtrP&$FFFF)	; Restore AREA Pointer Previous
	jmp r13	; WITHIN / OUTSIDE Line Of Sight!
	nop
	%CACHEE(_RLBSPNode)
;
;	>>>   LIST FULL: RUN THE SEGMENT PASSES ON IT, THEN GO ON (_RLBuildBSPResume)   <<<
;
_RBNFull:
	iwt r0,#lo16(_RLAreaSegList)	; An empty chunk: the AREA alone is larger than a chunk
	cmp !rAreaPtr
	bne _RBNFull2
	nop
	iwt r0,#RLAreaSegLimit	; Then the whole list is the chunk
	sms (TRPreWallPlotPtr0&$FFFF),r0
	iwt r15,#lo16(_RBNFit)
	nop
_RBNFull2:
	sms (TRCeilingY&$FFFF),!rBSPPtr	; (this AREA again then)
	sms (TRYs0&$FFFF),!rBSPStack
	ibt r0,#1
	sms (TRXsT&$FFFF),r0	; Walk to resume
	iwt r15,#lo16(_RBNSegs)
	nop



	if !RLREJECTPVS != 0
;
;	* * * * * * *       BUILD BSP VISIBILITY BITS (this port)       * * * * * * *
;
;	For the player's sector (PVSRow): AREA a is visible if its sector's PVS bit
;	is set; a NODE is visible if one of its children is.  Children always come
;	before their parent in the BSP data (the root is the last NODE), so one
;	pass over the NODES in order fills every bit.  Runs only when the player
;	enters another sector.
;
	!vNode = r8	; Address of NODE
	!vIdx = r9	; NODE number
	!vRoot = r10	; Address of the root NODE
	!vAreas = r12	; AREAS base (EMAREAS)
	!vPVS = r13	; PVS row of the player's sector (PVSRowBuf)
	!vAny = r5	; Visibility of the current NODE

macro VISSETBIT(base)
;	r0 = bit number, r3 = 0 to clear / else set
	move r6,r0
	lsr
	lsr
	lsr
	iwt r1,#lo16(<base>)
	add r1
	move r7,r0	; r7 = byte address
	from r6
	%and_i(7)
	add r1
	%sub_i(8)
	to r2	; r2 = bit mask (masks at <base>-8)
	ldb (r0)
	ldb (r7)	; r0 = byte
	moves r3,r3
	beq ?clear
	nop
	bra ?store
	or r2
?clear:
	bic r2
?store:
	stb (r7)
endmacro

macro VISCHILD()
;	r0 = child (>= $8000 = AREA); vAny |= visibility of the child
	moves r7,r0
	bmi ?area
	nop
	iwt r6,#2341	; NODE: its bit is built already (NODE offset/28)
	from r7
	lmult
	move r6,r0
	lsr
	lsr
	lsr
	iwt r1,#lo16(_RLNodeVisBits)
	add r1
	to r4
	ldb (r0)
	from r6
	%and_i(7)
	add r1
	%sub_i(8)
	ldb (r0)
	and r4
	from r0
	to !vAny
	or !vAny
	iwt r15,#lo16(?done)
	nop
?area:
	from !vAreas	; AREA: PVS bit of its sector
	add r7
	%add_i(rlaSector)
	move r14,r0
	getb	; Sector
	move r6,r0
	lsr
	lsr
	lsr
	add !vPVS	; (the row copied to PVSRowBuf)
	to r4
	ldb (r0)
	from r6
	%and_i(7)
	iwt r1,#lo16(SingleBitArray)
	add r1
	ldb (r0)
	to r3	; r3 = visible? (bit mask or 0)
	and r4
	from r3
	to !vAny
	or !vAny
	from r7	; AREA bit = offset/4
	add r7
	lsr
	lsr
	lsr
	%VISSETBIT(_RLAreaVisBits)
?done:
endmacro

	%align_pad(11, 16, (_RLBuildVisBits-_RLBVB1000)&$0F)
_RLBuildVisBits:
;	>>>   COPY THE PLAYER'S VISIBILITY ROW TO PVSRowBuf   <<<
;	(from the level RAM image, or from the GamePak ROM: bank in EMBSP+3)
	lms r1,(PVSRow&$FFFF)	; Source
	iwt r2,#lo16(PVSRowBuf)	; Destination
	lms r12,(EMNUMSECTORS&$FFFF)	; RowBytes = (NumSectors+7)>>3
	with r12
	%add_i(7)
	with r12
	lsr
	with r12
	lsr
	with r12
	lsr
	assert (lo16(EMBSP+3))&$FFFF < $80, "ibt: value does not fit a signed byte"
	ibt r0,#lo16(EMBSP+3)	; Visibility table in ROM?
	ldb (r0)
	moves r0,r0
	bne _RLBVB0030	; Yes
	nop
_RLBVB0010:
	%RAMB71(r3)	; No: level RAM image (GSU RAM $71)
	ldb (r1)
	%RAMB70(r3)
	stb (r2)
	inc r1
	dec r12
	bne _RLBVB0010
	inc r2
	bra _RLBVB0040
	nop
_RLBVB0030:
	romb
	move r14,r1
_RLBVB0035:
	getb
	inc r14
	stb (r2)
	dec r12
	bne _RLBVB0035
	inc r2
_RLBVB0040:
	ibt r0,#lo16(EMBSP+2)	; Bank of the BSP/AREAS data
	assert (lo16(EMBSP+2))&$FFFF < $80, "ibt: value does not fit a signed byte"
	ldb (r0)
	romb
	iwt r1,#lo16(SingleBitArray)	; Bit masks before the NODE and the AREA bits
	iwt r2,#lo16(_RLSBA1)
	iwt r3,#lo16(_RLSBA2)
	ibt r12,#8
_RLBVB0050:
	ldb (r1)
	stb (r2)
	stb (r3)
	inc r1
	inc r2
	dec r12
	bne _RLBVB0050
	inc r3
	lms !vAreas,(EMAREAS&$FFFF)
	iwt !vPVS,#lo16(PVSRowBuf)
	lms !vNode,(EMBSP&$FFFF)	; First NODE
	lms !vRoot,(EMBSPR&$FFFF)
	moves !vRoot,!vRoot	; Root is an AREA? (no map has that)
	bpl _RLBVB0100
	nop
	iwt r15,#lo16(_RLBVB9000)
	nop
_RLBVB0100:
	with !vRoot
	add !vNode
	ibt !vIdx,#0
	%CACHEB(_RLBuildVisBits)
_RLBVB1000:
	ibt !vAny,#0
	ibt r0,#rlbLeftChild	; Left child
	from !vNode
	to r14
	add r0
	getb
	inc r14
	getbh
	%VISCHILD()
	ibt r0,#rlbRightChild	; Right child
	from !vNode
	to r14
	add r0
	getb
	inc r14
	getbh
	%VISCHILD()
	move r3,!vAny	; NODE bit
	move r0,!vIdx
	%VISSETBIT(_RLNodeVisBits)
	inc !vIdx
	ibt r0,#rlbSize	; Next NODE
	with !vNode
	add r0
	from !vRoot	; Past the root?
	cmp !vNode
	bcc _RLBVB9000
	nop
	iwt r15,#lo16(_RLBVB1000)
	nop
	%CACHEE(_RLBuildVisBits)
_RLBVB9000:
	iwt r15,#lo16(_RLBuildBSP050)	; Back to the BSP walk
	nop
	endif

