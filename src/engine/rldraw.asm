	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       ENGINE VIEW DRAW MODULE                      *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"

	; public _RLDrawA
	; public _RLDrawB
	; public _RLDrawC
	; public _RLDraw


	%section(ENGINE_GSUCODE)
	arch superfx

;
;	* * * * * * *       REALITY_ENGINE DRAW       * * * * * * *
;
_RLDrawC:
	if !DEBUGSCR != 0
	lms r0,(TRFloorsEnd&$FFFF)	; Size of Floors/Ceilings
	iwt r1,#lo16(_RLFloors)
;	with	r0
	sub r1
	sm (DebugFloorsSizeC&$FFFF),r0
;
	lms r0,(TRClipZonePtr0&$FFFF)	; Get ClipZonePointer
	sm (DebugClipZonePtrC&$FFFF),r0
	lms r0,(TRPreWallPlotPtr0&$FFFF)	; Get PreWallPlotPointer
	sm (DebugPreWallPtrC&$FFFF),r0
	lms r0,(TRWallPlotPtr&$FFFF)	; Get WallPlotPointer
	sm (DebugWallPlotPtrC&$FFFF),r0
	lms r0,(TRFloorPlotPtr&$FFFF)	; Get FloorPlotPointer
	sm (DebugFloorPlotPtrC&$FFFF),r0
	lms r0,(TRObjPlotPtr&$FFFF)	; Get ObjPlotPointer
	sm (DebugObjPlotPtrC&$FFFF),r0
	endif
	iwt r1,#lo16(_RLDrawWallsC)	; DRAW WALLS C
	iwt r2,#lo16(_RLDrawAutoMapC)	; DRAW AUTOMAP C
	if !DEBUGSCR == 0
	bra _RLDraw
	endif
	if !DEBUGSCR != 0
	iwt r15,#lo16(_RLDraw)
	endif
	nop
_RLDrawB:
	if !DEBUGSCR != 0
	lms r0,(TRFloorsEnd&$FFFF)	; Size of Floors/Ceilings
	iwt r1,#lo16(_RLFloors)
;	with	r0
	sub r1
	sm (DebugFloorsSizeB&$FFFF),r0
;
	lms r0,(TRClipZonePtr0&$FFFF)	; Get ClipZonePointer
	sm (DebugClipZonePtrB&$FFFF),r0
	lms r0,(TRPreWallPlotPtr0&$FFFF)	; Get PreWallPlotPointer
	sm (DebugPreWallPtrB&$FFFF),r0
	lms r0,(TRWallPlotPtr&$FFFF)	; Get WallPlotPointer
	sm (DebugWallPlotPtrB&$FFFF),r0
	lms r0,(TRFloorPlotPtr&$FFFF)	; Get FloorPlotPointer
	sm (DebugFloorPlotPtrB&$FFFF),r0
	lms r0,(TRObjPlotPtr&$FFFF)	; Get ObjPlotPointer
	sm (DebugObjPlotPtrB&$FFFF),r0
	endif
	iwt r1,#lo16(_RLDrawWallsB)	; DRAW WALLS B
	iwt r2,#lo16(_RLDrawAutoMapB)	; DRAW AUTOMAP B
	bra _RLDraw
	nop
_RLDrawA:
	if !DEBUGSCR != 0
	lms r0,(TRFloorsEnd&$FFFF)	; Size of Floors/Ceilings
	iwt r1,#lo16(_RLFloors)
;	with	r0
	sub r1
	sm (DebugFloorsSizeA&$FFFF),r0
;
	lms r0,(VObjListEnd&$FFFF)	; Size of VisibleObjectList
	iwt r1,#lo16(_RLVObjList)
;	with	r0
	sub r1
	sm (DebugVObjSize&$FFFF),r0
;
	lms r0,(VSegListEnd&$FFFF)	; Size of VisibleSegmentList
	iwt r1,#lo16(_RLVSegList)
;	with	r0
	sub r1
	sm (DebugVSegSize&$FFFF),r0
;
	lms r0,(RLNumTasks&$FFFF)	; Number of RLTasks Running
	sm (DebugRLNumTasks&$FFFF),r0
;
	lms r0,(RLNumMObjs&$FFFF)	; Number of RLMObjs Active
	sm (DebugRLNumMObjs&$FFFF),r0
;
	lms r0,(SLVSecPtr&$FFFF)	; #VisibleSectors
	iwt r1,#lo16(_RLVSectors)
;	with	r0
	sub r1
;	with	r0
	lsr
	sm (DebugVSecNum&$FFFF),r0
;
	lms r0,(TRClipZonePtr0&$FFFF)	; Get ClipZonePointer
	sm (DebugClipZonePtrA&$FFFF),r0
	lms r0,(TRPreWallPlotPtr0&$FFFF)	; Get PreWallPlotPointer
	sm (DebugPreWallPtrA&$FFFF),r0
	lms r0,(TRWallPlotPtr&$FFFF)	; Get WallPlotPointer
	sm (DebugWallPlotPtrA&$FFFF),r0
	lms r0,(TRFloorPlotPtr&$FFFF)	; Get FloorPlotPointer
	sm (DebugFloorPlotPtrA&$FFFF),r0
	lms r0,(TRObjPlotPtr&$FFFF)	; Get ObjPlotPointer
	sm (DebugObjPlotPtrA&$FFFF),r0
	endif
	iwt r1,#lo16(_RLDrawWallsA)	; DRAW WALLS A
	iwt r2,#lo16(_RLDrawAutoMapA)	; DRAW AUTOMAP A
_RLDraw:
	ibt r0,#%00000001	; Transp.Off,NoDither,8-BitColour,NoSpr.
	cmode
	lms r0,(AutoMapMode&$FFFF)	; AUTOMAP Active?
	dec r0
	move r0,r1	; No!
	bmi _RLDraw200
	move r0,r2	; Yes!
_RLDraw200:
	ibt r8,#bank(_RLDrawWallsA)	; Begin Execution of Next Code
	if !PROFILE == 0
;	from	r0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop
