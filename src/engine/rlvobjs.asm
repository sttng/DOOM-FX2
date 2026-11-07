	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                        ENGINE VOBJS MODULE 1                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildVObjList1


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD VOBJECT LIST 1                       PROCESS OBJECTS  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       PROCESS OBJECTS       * * * * * * *
;
	!rViewX = r2	; View X
	!rViewY = r3	; View Y
	!rScaleF = r5	; RL->SCN Scaling Fraction
	!rVObjFree = r7	; #Free VisibleObjects (high byte)
	!rX = r8	; Vertex X
	!rY = r9	; Vertex Y
	!rObj = r10	; Pointer to RLObject
	!rVSec = r11	; Pointer in VisibleSectorList
	!rSin = r12	; Sine Constant
	!rCos = r13	; CoSine Constant
	!rYTemp = r14	; Rotation Temporary Variable
	!rScale = r14	; RL->SCN Scaling Integer
;
	!rVObj = r6	; Pointer to NEW VisibleObject
	!rVObjPtr = r4	; Pointer to Current VisibleObject
	!rVObjPtrP = r1	; Pointer to Previous VisibleObject
	!rVObj0 = !rScaleF	; Pointer to NEW VisibleObject


	%align_pad(3, 16, (_BOL9000-_BOL2000)&$0F)	; align 16,(_BOL9000-_BOL2000)&$0f
;
;	* * * * * * *       FINISHED PROCESSING OBJECTS       * * * * * * *
;
_BOL9000:
	iwt r0,#lo16(EMSECTORS+2)	; (this port) ROMB = the level data's bank, as the
	ldb (r0)	;  original left it after each object for the code
	romb	;  that follows (the level objects are in GSU RAM now)
	iwt r0,#lo16(_RLBuildA)	; BUILD TRACE A!
	ibt r8,#bank(_RLBuildA)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	* * * * * * *       START PROCESSING OBJECTS       * * * * * * *
;
_RLBuildVObjList1:
	lms !rViewX,(ViewX&$FFFF)	; Get View X
	lms !rViewY,(ViewY&$FFFF)	; Get View Y
;
	lms !rSin,(RLSin&$FFFF)	; Get Sine
	lms !rCos,(RLCos&$FFFF)	; Get CoSine
;
	iwt !rVObjFree,#(MaxRLVObjs<<8)	; (this port: no ROMB, the level objects are in GSU RAM)
;
	ibt r0,#0	; Start of VisibleObjectList
	sms (VObjListStart&$FFFF),r0
	sms (VObjListMaxY&$FFFF),r0	; VisibleObject with Maximum Y
	sms (VObjMaxY&$FFFF),r0	; Maximum VisibleObject Y
;
	iwt !rVSec,#lo16(_RLVSectors)	; Start of VisibleSectorList
;
	iwt r0,#lo16(_RLVObjList)	; End of VisibleObjectList
	sms (VObjListEnd&$FFFF),r0


	%CACHEB(_RLBuildVObjList1)
;
;	* * * * * * *       PROCESS NEXT VISIBLE SECTOR       * * * * * * *
;
_BOL2000:
;	to	r0				; Get Next VisibleSector
	ldw (!rVSec)
;	from	r0				; At End?
	to !rObj
	%add_i(rlsdObjects)
	bmi _BOL9000	; Yes!  No More Visible Sectors!
	inc !rVSec	; No!  Process this Sector's Objects!
	sms (VObjSectorData&$FFFF),r0	; Save Pointer to SectorData
	inc !rVSec
;
;	* * * * * * *       PROCESS NEXT RLOBJECT       * * * * * * *
;
_BOL3000:
;	to	r0				; Move to Next Object
	ldw (!rObj)
	moves !rObj,r0	; Any more Objects?
	beq _BOL2000	; No!
;
;	>>>   GET RLOBJECT'S FLAGS   <<<
;
	from !rObj	; Move to RLObject Flags
	to r1
	%add_i(rloFlags)
;	to	r0				; Get Flags
	ldb (r1)
;	with	r0				; Is RLObject ACTIVE?
	swap
	bpl _BOL3000	; NO!  DISCARD IT!
;	with	r0				; Is RLObject MOVABLE?
	add r0
	bpl _BOL3200	; No!
	inc r1	; Move to RLObject Type
;
;	>>>   GET MOVABLE OBJECT'S WORLD COORDINATES   <<<
;
	with r1	; Move to RLObject X
	%add_i((rloX+2-rloType))
	to !rX	; Get RLObject X
	ldw (r1)
	with r1	; Move to RLObject Y
	%add_i(((rloY+2)-(rloX+2)))
	to !rY	; Get RLObject Y
	ldw (r1)
	with r1	; Move to RLObject Z
	%add_i((rloZ-(rloY+2)))
	bra _BOL4000
;	to	r0				; Get RLObject Z
	ldw (r1)

;
;	>>>   GET FIXED OBJECT'S WORLD COORDINATES   <<<
;
_BOL3200:
	inc r1	; Move to LevelObject
	to !rY	; Get LevelObject (in the level RAM image, GSU RAM $71)
	ldw (r1)
	ibt r0,#1
	ramb
	to !rX	; Get RLObject X
	ldw (!rY)
	inc !rY
	inc !rY
	to !rY	; Get RLObject Y
	ldw (!rY)
	ibt r0,#0	; back to GSU RAM $70
	ramb
;
	lms r0,(VObjSectorData&$FFFF)	; Get Pointer to SectorData
;	with	r0				; Get SectorData.FloorHeight
	%add_i(rlsdFloorHeight)
;	to	r0
	ldw (r0)

;
;	>>>   SAVE OBJECT Z COORDINATE   <<<
;
_BOL4000:
	sms (VObjZ&$FFFF),r0	; RLObject Z (fixed object: SectorData.FloorHeight)

;
;	>>>   TRANSLATE VERTEX TO VIEW COORDINATE SYSTEM   <<<
;
;	>>>   ROTATE VERTEX BY (90DEGREES-VIEWANGLE)   <<<
;
;	ROTATED_Y = 	 sin(90deg.-ViewAngle) * (VertexX)
;			+cos(90deg.-ViewAngle) * (VertexY)
;
;	ROTATED_X = 	 cos(90deg.-ViewAngle) * (VertexX)
;			-sin(90deg.-ViewAngle) * (VertexY)
;
	move r6,!rSin	; sin(90deg.-ViewAngle)
;
	with !rX	; VertexX - ViewX
	sub !rViewX
	move r1,!rY	; VertexY
;
	from !rX	; *VertexX
;	to	r0
	fmult
;	from	r0
	to !rY
	rol
;
	from r1	; VertexY - ViewY
	to !rYTemp
	sub !rViewY
;
	from !rYTemp	; *VertexY
;	to	r0
	fmult
;	from	r0
	to r1
	rol
;
	move r6,!rCos	; cos(90deg.-ViewAngle)
	from !rYTemp	; *Vertex Y
;	to	r0
	fmult
;	with	r0
	rol
	with !rY	; Rotated Y
	add r0
;
	from !rY	; Adjust Y
;	to	r0
	%sub_i(RLScreenPlane)
	bmi _BOL3000	; BEFORE VIEWPLANE!  DISCARD IT!
	nop
	iwt r0,#(RLMaxViewDistance-1)	; Maximum Distance Away
;	with	r0				; Object >= MaxDistance?
	sub !rY	; @CMP@
	blt _BOL3000	; YES!  DISCARD IT!
	nop
;
	from !rX	; *Vertex X
;	to	r0
	fmult
;	with	r0
	rol
;	from	r0				; Rotated X
	to !rX
	sub r1
;
;	>>>   GET IMAGERY   <<<
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
	iwt r1,#lo16(_ObjData+rlodFlags+1)	; Add Base of _ObjData
;	from	r0				; Move to Object Flags
	to r14
	add r1
	getb	; Get RLObject.Flags
;	from	r0				; Does RLObject has Imagery?
	to r1
	%and_i((rlodfImage>>8))
	beq _BOL4400	; No
	with r14	; Move to Image#
;
;	>>>   GET RLOBJECT IMAGE NUMBER   <<<
;
	ibt r0,#rloImage	; Yes!  Get RLObject Image#
;	with	r0
	add !rObj
;	to	r0
	alt1
	bra _BOL4500
	ldw (r0)
;	ldb	(r0)
;
;	>>>   GET FIXED IMAGE NUMBER   <<<
;
_BOL4400:
;	with	r14				; Move to Image#
	%add_i((rlodImage-(rlodFlags+1)))
;	with	r0				; Anim2/Anim4?
	%and_i(((rlodfAnim2>>8)+(rlodfAnim4>>8)))
	with r1
	beq _BOL4420	; No
	sub r1
	ibt r1,#lo16(Anim2Frame-1)	; Get Anim2/Anim4 Frame#
	assert (lo16(Anim2Frame-1))&$FFFF < $80 || (lo16(Anim2Frame-1))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
;	with	r0
	add r1
	to r1	; Get Frame#
	ldb (r0)
_BOL4420:
	getb	; Get Image#
;	with	r0				; Add Frame#
	add r1
;
;	>>>   GET IMAGE DIMENSIONS   <<<
;
_BOL4500:
;	from	r0				; R1 = (Image#<<1)
	to r1
	add r0
	if !RLDOOM2MONSTERS != 0
	ibt r0,#rloType	; Image page 1? (_ObjData flags rlodfPage1: DOOM II
;	with	r0				;  monsters; ROMB is still the _ObjData bank)
	add !rObj
	ldb (r0)
	%umult_i(rlodSize)
	iwt r14,#lo16(_ObjData+rlodFlags+1)
	with r14
	add r0
	getb	; (rlodfPage1>>8) = $20
	lsr
	lsr
	lsr
	lsr
	lsr
	%and_i(1)
	swap	; $0100: 256 image#s = $0200 bytes of table
	add r0
	with r1
	add r0
	endif
	ibt r0,#bank(RLImagesTable)	; Get Address of ImageTable
	romb
	iwt r0,#lo16(RLImagesTable)
;	from	r0
	to r14
	add r1
;
	iwt r1,#lo16(RLImagesData+rliHeight)	; Add Base of ImageData
	getb	; Get Offset within ImageDataTable
	inc r14
	getbh
;	from	r0
	to r14
	add r1
	sms (VObjImage&$FFFF),r14	; Save Pointer to Imagery
;
;	>>>   PERFORM PERSPECTIVE TRANSFORM ON RADIUS TO GET RADIUS_SCREEN   <<<
;
	iwt r6,#lo16(RLAspectRatio)	; Compensate for SNES<->PC Aspect Ratio
	from !rY
;	to	r0
	fmult
;
	to r6	; Get Object Height
	getb
	inc r14
;
;	with	r0				; R0 = WorldY AspectAdjusted
	add !rY
;	from	r0				; Get Long Offset
	to r1
	add r0
	with r1
	add r0
;
	with r6	; Height / Width
	getbh
	sms (VObjHeight&$FFFF),r6
;
	to r6	; Get Object Diameter
	getb
;
;	>>>   RL->SCN PIXEL SCALE   <<<
;
	ibt r0,#bank(RLSCNPixScale)	; RL->SCN Pixel Scaling Table
	romb
	iwt r0,#lo16(RLSCNPixScale)
;	from	r0
	to r14
	add r1
;
	getb	; Get Fraction
	inc r14
	to !rScaleF
	getbh
	inc r14
;
	from !rScaleF	; r0:r4 = Fraction
;	to	r0
	fmult
;	with	r0
	rol
	to !rScale	; r4 = Integer
	getb
	from !rScale
	to r4
	umult r6
;
	move r6,!rX	; Transform Rotated X
;
;	from	r0				; RX = DIAMETER #SCREEN PIXELS
	to !rX
	add r4
;
;	>>>   PERFORM PERSPECTIVE TRANSFORM ON ROTATED X/Y TO GET X_SCREEN   <<<
;
	from !rScaleF	; r1 = Integer
;	to	r0
	fmult
;	from	r0
	to r1
	rol
	from !rScale	; r0 = Integer
;	to	r0
	lmult
	with r1
	add r4
;
	with r4	; $FFFF8000 <= X <= $00007FFF
	add r4
;	from	r0
	to r4
	rol
;	with	r0
	sub r4
	bne _BOL5800-1	; *WAY* OFF SCREEN!  DISCARD IT!
;
;	>>>   CENTER TRANSLATED X_SCREEN   <<<
;
	ibt r0,#(RLViewPixX/2)	; ScreenWidth/2
;	with	r0
	add r1
;
;	>>>   GET SCREEN SPAN OF OBJECT   <<<
;
	from !rX	; R1 = RADIUS #SCREEN PIXELS EVEN
	to r1
	lsr
;	from	r0				; RX = (X_SCREEN + RADIUS_SCREEN + ODD -1)
	to !rX
	adc r1
	dec !rX
	bmi _BOL5800	; OFF LEFT OF SCREEN!  DISCARD IT!
;	from	r0				; R4 = (X_SCREEN - RADIUS_SCREEN)
	to r4
	sub r1
;
;	>>>   ENSURE OBJECT IS ON SCREEN   <<<
;
	move r1,r4	; Ensure Xs1 STARTS on EVEN Pixel
	inc r1
	with r1
	asr
	with !rX	; Ensure Xs2 ENDS on EVEN Pixel
	asr
	from !rX	; Xs2 < Xs1?
;	to	r0				; @CMP@
	sub r1
	blt _BOL5800-1	; Yes!  Can't Draw It!
	ibt r0,#(RLViewPixX/2)
	from r1	; ObjectLeft >= ScreenRight?
;	to	r0				; @CMP@
	sub r0
	blt _BOL6200
	from !rVObjFree	; Number of Free VisibleObjects
_BOL5800:
	iwt r15,#lo16(_BOL8000)	; OFF RIGHT OF SCREEN!  DISCARD IT!

;
;	* * * * * * *       ADD A NEW VISIBLE OBJECT!       * * * * * * *
;
_BOL6200:
;
;	>>>   CREATE VISIBLE OBJECT   <<<
;
;	from	rVObjFree			; Number of Free VisibleObjects
;	to	r0
	hib
	bne _BOL6600+1	; At Least One Free!
;
;	>>>   OVERLAY FURTHEST VISIBLE OBJECT   <<<
;
	lms r0,(VObjMaxY&$FFFF)	; Get Maximum WorldY
	from !rY	; WorldY >= Maximum WorldY?
;	to	r0				; @CMP@
	sub r0
	bge _BOL5800
	nop
	lms r1,(VObjListStart&$FFFF)	; Start of VObjList
	ibt r0,#(MaxRLVObjs-2)
	inc r1	; Move to VObj.Next
_BOL6300:
	inc r1	; Move to VObj.Next
	to r1
	ldw (r1)
	dec r0
	bne _BOL6300
	inc r1	; Move to VObj.Next
;
	inc r1	; Move to VObj.Next
	to !rVObj0	; Get VObj.Next (LAST!)
	ldw (r1)
;	with	r0				; VObj.Next = NULL
	sub r0
;	from	r0
	sbk
	dec r1	; Move to VObj.WorldY
	dec r1
;	to	r0				; Get VObj.WorldY
	ldw (r1)
	sms (VObjMaxY&$FFFF),r0	; New Maximum WorldY
	sms (VObjListMaxY&$FFFF),r1	; New Maximum WorldY VObj
	bra _BOL6700+1
	with !rVObj0
;
;	>>>   CREATE NEW VISIBLE OBJECT   <<<
;
_BOL6600:
	lms !rVObj0,(VObjListEnd&$FFFF)	; End of VisibleObjectList
_BOL6700:
	move r1,!rVObj0	; Save Start of VObj
;
	from !rY	; Save World Y
	stw (r1)
	with r1
	%add_i((rlqObj-rlqY))
;
	from !rObj	; Save RLObject
	stw (r1)
	inc r1
	inc r1
;
	from r6	; Save World X
	stw (r1)
	inc r1
	inc r1
;
;	>>>   ADJUST OBJECT Z COORDINATE BY EYE HEIGHT   <<<
;
	lms r0,(VObjZ&$FFFF)	; Get World Z
	lms r6,(ViewZ&$FFFF)	; Get View Z Coordinate
;	with	r0
	sub r6
;	from	r0				; Save World Z
	stw (r1)
	inc r1
	inc r1
;
	from r4	; Save Xs1
	stw (r1)
	inc r1
	inc r1
;
	from !rX	; Save Xs2
	stw (r1)
	inc r1
	inc r1
;
	lms r0,(VObjHeight&$FFFF)	; Get World Height/Width
;	from	r0				; WorldHeight.B / WorldWidth.B
	stw (r1)
	inc r1
	inc r1
;
	lms r0,(VObjSectorData&$FFFF)	; Save SectorData
;	from	r0
	stw (r1)
	inc r1
	inc r1
;
	lms r0,(VObjImage&$FFFF)	; Save Imagery Pointer
;	from	r0
	stw (r1)
	inc r1
	inc r1
;
;	with	r0				; Image NOT Drawn
	sub r0
;	from	r0
	stb (r1)
;
	from !rVObjFree	; Number of Free VisibleObjects
;	to	r0
	hib
;
	lms r0,(VObjMaxY&$FFFF)	; Get Maximum WorldY
;
	with !rVObj0	; Get Start of New VObj
	beq _BOL7100	; NONE!  OVERWRITING!
	to !rVObj
;
	with r1	; Move to next VObj
	%add_i((rlqSize-rlqDrawn))
	sms (VObjListEnd&$FFFF),r1	; Save Updated Pointer
;
;	>>>   IS THIS VOBJ FARTHER THAN THE FURTHEST VOBJ SO FAR?   <<<
;
_BOL7100:
	from !rY	; WorldY >= Maximum WorldY?
;	to	r0				; @CMP@
	sub r0
	blt _BOL7400+1	; No
;
;	>>>   YES!  APPEND TO END OF VOBJ LIST!   <<<
;
	lms r0,(VObjListMaxY&$FFFF)	; Get Maximum WorldY VObj
	from !rVObj	; Save NEW Maximum WorldY VObj
	sbk
	moves r0,r0	; Any Previous Maximum WorldY VObj?
	beq _BOL7200	; No!
	inc r0	; Yes, Previous.Next = New
	inc r0
	from !rVObj
	bra _BOL7300
	stw (r0)
_BOL7200:
	sms (VObjListStart&$FFFF),!rVObj	; New Start!
_BOL7300:
	inc !rVObj	; New.Next = 0
	inc !rVObj
;	with	r0
	sub r0
	sms (VObjMaxY&$FFFF),!rY	; Save Updated Maximum WorldY
	bra _BOL7900
;	from	r0
	stw (!rVObj)
;
;	>>>   LINK THE VISIBLE OBJECT INTO THE LIST IN INCREASING WORLD Y ORDER   <<<
;
_BOL7400:
	lms !rVObjPtr,(VObjListStart&$FFFF)	; Start of VObjList
	ibt !rVObjPtrP,#0	; NO Previous VObj
_BOL7500:
;	to	r0				; Get Current VObj.WorldY
	ldw (!rVObjPtr)
;	with	r0				; Current >= New?
	sub !rY	; @CMP@
	bge _BOL7600	; Yes!  Insert It!
	move !rVObjPtrP,!rVObjPtr	; Previous = Current
	inc !rVObjPtr	; Move to Current.Next
	inc !rVObjPtr
;
	if GSUREV2 != 0
	to !rVObjPtr	; Current = Current.Next
	bra _BOL7500
	ldw (!rVObjPtr)
	endif
;
	if (1-GSUREV2) != 0
	to !rVObjPtr	; Current = Current.Next
	ldw (!rVObjPtr)
	bra _BOL7500
	nop
	endif
;
_BOL7600:
	moves !rVObjPtrP,!rVObjPtrP	; Any Previous?
	bne _BOL7700	; Yes
	inc !rVObjPtrP	; Move to Previous.Next
	sms (VObjListStart&$FFFF),!rVObj	; No, New Start!
	bra _BOL7800
_BOL7700:
	inc !rVObjPtrP	; Move to Previous.Next
	from !rVObj	; Previous.Next = New
	stw (!rVObjPtrP)
_BOL7800:
	inc !rVObj	; Move to New.Next
	inc !rVObj	; Move to New.Next
	from !rVObjPtr	; New.Next = Current
	stw (!rVObj)
;
;	>>>   ONE MORE VISIBLE OBJECT ADDED   <<<
;
_BOL7900:
	from !rVObjFree	; Number of Free VisibleObjects
;	to	r0
	hib
	beq _BOL8000	; NONE FREE!
	dec r0	; (delay slot)
	swap	; One fewer
	move !rVObjFree,r0
;
;	* * * * * * *       RLOBJECT COMPLETED       * * * * * * *
;
_BOL8000:
;
;	>>>   PROCESS NEXT RLOBJECT   <<<
;
	iwt r15,#lo16(_BOL3000)+1	; Process Next RLObject
;	to	r0				; Move to Next Object
	ldw (!rObj)

	%CACHEE(_RLBuildVObjList1)
