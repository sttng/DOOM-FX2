	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                        ENGINE TRACE MODULE 1                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildTrace


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD TRACE                 INIT RLENGINE TRACE PROCESSING  **
;	**								**
;	******************************************************************
;	******************************************************************


;
;	* * * * * * *       CLIP VISIBLE SEGMENTS       * * * * * * *
;
	!rVSeg = r11	; Pointer within VisibleSegment
	!rVSegEnd = r12	; Pointer to End of VisibleSegmentList
	!rMinPixX = r9	; Minimum X Coordinate
	!rMaxPixX = r10	; Maximum X Coordinate
	!rXs = r7	; Xs1/Xs2
	!rXsT = r8	; Clipped X/#Pixels Left
	!rClipRangePtr = r5	; Pointer within ClipRange


	%align_pad(11, 16, (_RLBuildTrace-_TRS3200)&$0F)	; align 16,(_RLBuildTrace-_TRS3200)&$0f
_RLBuildTrace:
	iwt !rVSeg,#lo16(_RLVSegList-rlvSize+rlvXsT)	; START of VisibleSegmentList
	lms !rVSegEnd,(VSegListEnd&$FFFF)	; END of VisibleSegmentList
	with !rVSegEnd
	%add_i(rlvXs1)
;
	if useHIGHDETAIL != 0
	lm !rMaxPixX,(RLMaxPixX2&$FFFF)	; Maximum X Coordinate
	lm !rMinPixX,(RLMinPixX2&$FFFF)	; Minimum X Coordinate
	endif
	if useHIGHDETAIL == 0
	lms !rMaxPixX,(RLMaxPixX&$FFFF)	; Maximum X Coordinate
	lms !rMinPixX,(RLMinPixX&$FFFF)	; Minimum X Coordinate
	endif
	ibt !rXsT,#-1	; Default VSEG to Clipped

	%CACHEB(_RLBuildTrace)
;
;	* * * * * * *       HANDLE NEXT VISIBLE SEGMENT       * * * * * * *
;
_TRS3200:
	ibt r0,#(rlvSize-rlvXsT+rlvXs1)	; Offset to Next VSEG
	with !rVSeg	; Move to Next VSEG
	add r0
	from !rVSeg	; At End?
;	to	r0
	sub !rVSegEnd	; @CMP@
	beq _TRS5000	; Yes!  No More VisibleSegments!

;
;	* * * * * * *       PROCESS NEXT VISIBLE SEGMENT       * * * * * * *
;
;	>>>   GET STARTING/ENDING SCREEN COORDINATES   <<<
;
	to !rXs	; Start.B / End.B
	ldw (!rVSeg)
	with !rVSeg	; Move to XsT
	%sub_i((rlvXs1-rlvXsT))
;
;	>>>   IS THIS SEGMENT WITHIN RANGE?   <<<
;
	from !rXs	; Get StartPixX
;	to	r0
	lob
;	with	r0				; StartPixX >= MaxPixX?
	sub !rMaxPixX	; @CMP@
	bge _TRS3800	; Yes, Skip this Segment!
	from !rXsT	; CLIP SEGMENT!
;
	from !rXs	; Get EndPixX
;	to	r0
	hib
;	with	r0				; EndPixX < MinPixX?
	sub !rMinPixX	; @CMP@
	blt _TRS3800	; Yes, Skip this Segment!
	from !rXsT	; CLIP SEGMENT!
;
;	>>>   GET OFFSET TO CLIPPING RANGE   <<<
;
	from !rXs	; R1 = StartPixX
	to r1
	lob
	from r1	; Get Offset from MinPixX
;	to	r0
	sub !rMinPixX
	bpl _TRS3500	; >= MinPixX
;	with	r0				; Get WORD Offset
	add r0
	move r1,!rMinPixX	; StartPixX = MinPixX
;	with	r0				; Offset = 0
	sub r0
_TRS3500:
	iwt !rClipRangePtr,#lo16(_RLClipRange)	; Point to Start of ClipRange
	with !rClipRangePtr	; Add Segment Offset
	add r0
;
;	>>>   SAVE OFFSET TO CLIPPING RANGE   <<<
;
	from !rVSeg	; Move to ClipRangePointer
;	to	r0
	%add_i((rlvClipRangeP-rlvXsT))
	from !rClipRangePtr
	stw (r0)
;
;	>>>   CLIP ENDING COORDINATE   <<<
;
	with !rXs	; RXs = EndPixX
	hib
	from !rXs	; EndPixX >= MaxPixX?
;	to	r0				; @CMP@
	sub !rMaxPixX
	blt _TRS3600+1	; No
	moves !rXs,!rMaxPixX	; EndPixX = (MaxPixX-1)
	dec !rXs
;
;	>>>   GET NUMBER OF PIXELS TO STEP   <<<
;
_TRS3600:
	with !rXs	; Get (EndPixX-StartPixX)+1
	sub r1
	inc !rXs
	with !rXs	; RXST = Count.B / Xs.B
	swap
	with !rXs
	or r1
;
;	>>>   SAVE STARTING PIXEL/#PIXELS TO TRACE   <<<
;
	from !rXs	; Save Xs1/XsCount
_TRS3800:
	bra _TRS3200
	stw (!rVSeg)


;
;	* * * * * * *       BEGIN RLENGINE TRACE PROCESSING       * * * * * * *
;
_TRS5000:
	iwt r0,#lo16(_RLBuildTraceWalls)	; BUILD TRACE WALLS
	ibt r8,#bank(_RLBuildTraceWalls)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

	%CACHEE(_RLBuildTrace)
