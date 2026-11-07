	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                     ENGINE USE/OPERATE MODULE 2                    *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/music.inc"


	; public _RLUseXY2


	%section(ENGINE_GSUCODE)
	arch superfx


	!rLX0 = r3	; Line Coordinate (Top-Left)
	!rLY0 = r5	; Line Coordinate
	!rLX1 = r12	; Line Coordinate (Bottom-Right)
	!rLY1 = r13	; Line Coordinate
	!rX0 = r7	; Object Coordinate (Top-Left)
	!rY0 = r8	; Object Coordinate
	!rX1 = r9	; Object Coordinate (Bottom-Right)
	!rY1 = r10	; Object Coordinate
;
	!rUseLinesPtr = r11	; UseLines Pointer
	!rLineFlagsMask = !rLX0	; LineFlags Mask


	%align_pad(12, 16, (_RU2XY10000-_RU2XY2000)&$0F)	; align 16,(_RU2XY10000-_RU2XY2000)&$0f

;
;	* * * * * * *       SWITCH WEAPONS?       * * * * * * *
;
_RU2XY10000:
	if useID7 == 0
	lms r0,(WeaponType&$FFFF)	; Current Weapon = Next Weapon?
	lms r1,(WeaponNext&$FFFF)
;	with	r0
	sub r1
	beq _RU2XY12000	; Yes!  Don't Switch Weapons!
	nop
	lms r11,(ULReturnAddress&$FFFF)
	iwt r15,#lo16(_RLDropWeapon)	; DROP CURRENT WEAPON!
	nop
	endif
;
;	* * * * * * *       USE/OPERATE!       * * * * * * *
;
_RU2XY11000:
	ibt r3,#swtchn_eff
	bra _RU2XY15000
	nop
;
;	* * * * * * *       NOTHING TO USE/OPERATE!       * * * * * * *
;
_RU2XY12000:
	ibt r3,#noway_eff
;
;	* * * * * * *       MAKE SOUND EFFECT       * * * * * * *
;
_RU2XY15000:
	lms r11,(ULReturnAddress&$FFFF)	; Get Return Address
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop

;
;	* * * * * * *       REALITY_ENGINE USE LINES 2       * * * * * * *
;
_RLUseXY2:
;
;	>>>   CALCULATE OBJECT USE/OPERATE BOUNDING BOX COORDINATES   <<<
;
	lms !rX0,(ULObjX0&$FFFF)	; Get Object Initial X
	lms !rY0,(ULObjY0&$FFFF)	; Get Object Initial Y
	lms !rX1,(ULObjX1&$FFFF)	; Get Object Projected X
	lms !rY1,(ULObjY1&$FFFF)	; Get Object Projected Y
;
	from !rX1	; X1 >= X0?
;	to	r0				; @CMP@
	sub !rX0
	bge _RU2XY1200
	nop
	move r0,!rX0
	move !rX0,!rX1
	move !rX1,r0
_RU2XY1200:
	from !rY0	; Y0 >= Y1?
;	to	r0				; @CMP@
	sub !rY1
	bge _RU2XY1400
	nop
	move r0,!rY0
	move !rY0,!rY1
	move !rY1,r0
_RU2XY1400:
;
	ibt r0,#lo16(EMBSP+2)	; Bank of EM Data
	assert (lo16(EMBSP+2))&$FFFF < $80 || (lo16(EMBSP+2))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	ldb (r0)
	romb
;
	iwt !rUseLinesPtr,#lo16(_RLUseLines)	; Start of UseLines List

;
;	* * * * * * *       CHECK USE/OPERATE AGAINST LINELIST       * * * * * * *
;
	%CACHEB(_RLUseXY2)
_RU2XY2000:
;
;	>>>   CHECK NEXT USELINE   <<<
;
_RU2XY2200:
	iwt r0,#lo16(MVULMask)	; LineFlags Type Mask
	to !rLineFlagsMask
	ldb (r0)
_RU2XY2300:
	to r2	; Get Next Line#
	ldw (!rUseLinesPtr)
	inc r2	; End of UseLines?
	if useID7 == 0
	beq _RU2XY10000	; Yes!
	endif
	if useID7 != 0
	beq _RU2XY12000	; Yes!
	endif
	dec r2
;
;	>>>   GET LINE FLAGS   <<<
;
	ibt r6,#rllSize	; Move to LINE
	from r2
;	to	r0
	lmult
	lms r1,(EMLINES&$FFFF)	; Get Base Address of Lines Table (level RAM $71)
	from r4
	to r6	; R6 = Line
	add r1
;
;	>>>   GET LINE VERTEXES AND FLAGS   <<<
;
	%RAMB71(r1)
	to r4	; R4 = Vertex1
	ldw (r6)
	inc r6
	inc r6
	to r2	; R2 = Vertex2
	ldw (r6)
	inc r6
	inc r6
	inc r6
	ldb (r6)	; Get LineFlags (high byte)
	%RAMB70(r6)
	inc !rUseLinesPtr	; Move to next UseLine
;	with	r0				; USABLE Line?
	and !rLineFlagsMask
	beq _RU2XY2300	; No
	inc !rUseLinesPtr	; Move to next UseLine

;
;	* * * * * * *       DOES OBJECT BOX INTERSECT LINE BOX?       * * * * * * *
;
	lms r1,(EMVERTEXES&$FFFF)	; Base Address of Vertexes Table
	from r4	; Vertex1
;
;	>>>   VERTEX 1   <<<
;
;	from	r0				; Get Vertex1 Coordinates
	to r14
	add r1
	getb	; Vertex1 X
	inc r14
	to !rLX0
	getbh
	inc r14
	getb	; Vertex1 Y
	inc r14
	to !rLY0
	getbh
;
;	>>>   VERTEX 2   <<<
;
	from r2	; Get Vertex2 Coordinates
	to r14
	add r1
	getb	; Vertex2 X
	inc r14
	to !rLX1
	getbh
	inc r14
	getb	; Vertex2 Y
	inc r14
	to !rLY1
	getbh

;
;	>>>   ENSURE BOUNDING BOXES INTERSECT   <<<
;
	from !rLX0	; Both Line X Coordinates < X0?
;	to	r0				; @CMP@
	sub !rX0
	bge _RU2XY3200
	from !rLX1
;	to	r0				; @CMP@
	sub !rX0
	blt _RU2XY2200	; Yes, Boxes Don't Intersect!
_RU2XY3200:
	from !rLX0	; Both Line X Coordinates > X1?
;	to	r0				; @CMP@
	sub !rX1
	blt _RU2XY3400
	from !rLX1
;	to	r0				; @CMP@
	sub !rX1
	bge _RU2XY2200	; Yes, Boxes Don't Intersect!
_RU2XY3400:
	from !rLY0	; Both Line Y Coordinates > Y0?
;	to	r0				; @CMP@
	sub !rY0
	blt _RU2XY3600
	from !rLY1
;	to	r0				; @CMP@
	sub !rY0
	bge _RU2XY2200	; Yes, Boxes Don't Intersect!
_RU2XY3600:
	from !rLY0	; Both Line Y Coordinates < Y1?
;	to	r0				; @CMP@
	sub !rY1
	bge _RU2XY3800
	from !rLY1
;	to	r0				; @CMP@
	sub !rY1
	blt _RU2XY2200	; Yes, Boxes Don't Intersect!
_RU2XY3800:
	nop

;
;	>>>   DETERMINE DIRECTION LINE IS CROSSED (R->L OR L->R)   <<<
;
_RU2XY4000:
	lms r1,(ULObjY0&$FFFF)	; R1 = (ObjectY0 - LineY)
	with r1
	sub !rLY0
	lms r0,(ULObjX0&$FFFF)	; R0 = (ObjectX0 - LineX)
;	with	r0
	sub !rLX0
	from !rLY1	; Result in R0:R2
	to r6
	sub !rLY0
;	with	r0
	lmult
	move r2,r4
	from !rLX1	; Result in R1:R4
	to r6
	sub !rLX0
	with r1
	lmult
	with r2
	sub r4
;	with	r0				; R0:R2 = SIDE
	sbc r1
	bpl _RU2XY5000
	nop
_RU2XY4800:
	iwt r15,#lo16(_RU2XY2200)	; Line Used/Operated from Wrong Side!
	nop
_RU2XY4900:
	inc !rUseLinesPtr	; Line Used Already: keep looking (this port;
	iwt r15,#lo16(_RU2XY2200)	; the original stopped the search with "oof")
	inc !rUseLinesPtr


	%CACHEE(_RLUseXY2)
;
;	* * * * * * *       FOUND A USABLE/OPERABLE LINE       * * * * * * *
;
_RU2XY5000:
	dec !rUseLinesPtr	; Move to USED Line
	dec !rUseLinesPtr
	to r2	; Get USED Line#
	ldw (!rUseLinesPtr)
;
;	>>>   HAS THIS LINE BEEN USED ALREADY?   <<<
;
	iwt r3,#lo16(_RLLineFlags)	; Base of LineFlags
	with r3
	add r2
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%and_i(rllfUsed)	; USED?
	bne _RU2XY4900-1	; Yes, Can't REUSE It: look on
;
;	>>>   GET LINE TYPE   <<<
;
	ibt r6,#rllSize	; Move to LINE
	from r2
;	to	r0
	lmult
	lms r1,(EMLINES&$FFFF)	; Get Base Address of Lines Table (level RAM $71)
	with r1
	%add_i(rllType)
	from r4
;	to	r0
	add r1
	sms (ULLine&$FFFF),r0	; Save Pointer to Line
	%RAMB71(r1)
	to r4	; R4 = Type.B / Tag.B
	ldw (r0)
	%RAMB70(r1)
	sms (ULType&$FFFF),r4
;
;	* * * * * * *       USE/OPERATE!       * * * * * * *
;
;	>>>   CALL USABLE LINE CODE   <<<
;
	ibt r0,#bank(_RLUseCode)	; Get Address of Usable Line Code
	romb
	iwt r1,#lo16(_RLUseCode)
	from r4
;	to	r0
	lob
;	with	r0
	add r0
;	from	r0
	to r14
	add r1
	getb
	inc r14
	to r15	; Call Usable Line Code
	getbh
	nop


;
;	* * * * * * *       USABLE LINE CODE JUMPTABLE       * * * * * * *
;
_RLUseCode:
	dw 0	; 000
	dw lo16(_UDoorOpenClose)	; 001*
	dw 0	; 002
	dw 0	; 003
	dw 0	; 004
	dw 0	; 005
	dw 0	; 006
	dw lo16(_UStairs)	; 007
	dw 0	; 008
	dw lo16(_UFloorOnce)	; 009
;
	dw 0	; 010
	dw lo16(_UExit)	; 011
	dw 0	; 012
	dw 0	; 013
	dw lo16(_UFloorOnce)	; 014
	dw 0	; 015
	dw 0	; 016
	dw 0	; 017
	dw lo16(_UFloorOnce)	; 018
	dw 0	; 019
;
	dw lo16(_UFloorOnce)	; 020
	dw lo16(_ULiftOnce)	; 021
	dw 0	; 022
	dw lo16(_UFloorOnce)	; 023
	dw 0	; 024
	dw 0	; 025
	dw lo16(_UDoorBOpenClose)	; 026
	dw lo16(_UDoorYOpenClose)	; 027
	dw lo16(_UDoorROpenClose)	; 028
	dw lo16(_URDoorOpenCloseOnce)	; 029
;
	dw 0	; 030
	dw lo16(_UDoorOpen)	; 031
	dw lo16(_UDoorBOpen)	; 032
	dw lo16(_UDoorROpen)	; 033
	dw lo16(_UDoorYOpen)	; 034
	dw 0	; 035
	dw 0	; 036
	dw 0	; 037
	dw 0	; 038
	dw 0	; 039
;
	dw 0	; 040
	dw 0	; 041
	dw lo16(_URDoorClose)	; 042!
	dw 0	; 043
	dw 0	; 044
	dw lo16(_UFloor)	; 045 (Ultimate DOOM)
	dw 0	; 046
	dw 0	; 047
	dw 0	; 048
	dw 0	; 049
;
	dw 0	; 050
	dw lo16(_UExitSecret)	; 051
	dw 0	; 052
	dw 0	; 053
	dw 0	; 054
	dw 0	; 055
	dw 0	; 056
	dw 0	; 057
	dw 0	; 058
	dw 0	; 059
;
	dw lo16(_UFloorOnce)	; 060 (Ultimate DOOM)
	dw lo16(_URDoorOpen)	; 061!
	dw lo16(_ULift)	; 062!
	dw lo16(_URDoorOpenClose)	; 063!
	dw 0	; 064
	dw 0	; 065
	dw 0	; 066
	dw 0	; 067
	dw 0	; 068
	dw 0	; 069
;
	dw lo16(_UFloor)	; 070!
	dw lo16(_UFloor)	; 071 (Ultimate DOOM)
	dw 0	; 072
	dw 0	; 073
	dw 0	; 074
	dw 0	; 075
	dw 0	; 076
	dw 0	; 077
	dw 0	; 078
	dw 0	; 079
;
	dw 0	; 080
	dw 0	; 081
	dw 0	; 082
	dw 0	; 083
	dw 0	; 084
	dw 0	; 085
	dw 0	; 086
	dw 0	; 087
	dw 0	; 088
	dw 0	; 089
;
	dw 0	; 090
	dw 0	; 091
	dw 0	; 092
	dw 0	; 093
	dw 0	; 094
	dw 0	; 095
	dw 0	; 096
	dw 0	; 097
	dw 0	; 098
	dw lo16(_URDoorBOpen)	; 099 (Ultimate DOOM)
;
	dw 0	; 100
	dw lo16(_UFloorOnce)	; 101 (Ultimate DOOM)
	dw lo16(_UFloorOnce)	; 102
	dw lo16(_URDoorOpenOnce)	; 103
	dw 0	; 104
	dw 0	; 105
	dw 0	; 106
	dw 0	; 107
	dw 0	; 108
	dw 0	; 109
	dw 0	; 110
	dw 0	; 111
	dw lo16(_URDoorOpenOnce)	; 112 (Ultimate DOOM)
	dw 0	; 113
	dw lo16(_URDoorOpenClose)	; 114 (Ultimate DOOM)
	dw lo16(_URDoorOpen)	; 115 (Ultimate DOOM)
	dw 0	; 116
	dw lo16(_UDoorOpenClose)	; 117 (Ultimate DOOM)
	dw lo16(_UDoorOpen)	; 118 (Ultimate DOOM)
	dw 0	; 119
	dw 0	; 120
	dw 0	; 121
	dw 0	; 122
	dw lo16(_ULift)	; 123 (Ultimate DOOM)
	dw 0	; 124
	dw 0	; 125
	dw 0	; 126
	dw lo16(_UStairs16)	; 127 (Ultimate DOOM)
	dw 0	; 128
	dw 0	; 129
	dw 0	; 130
	dw 0	; 131
	dw 0	; 132
	dw lo16(_URDoorBOpen)	; 133 (Ultimate DOOM)
	dw lo16(_URDoorROpen)	; 134 (Ultimate DOOM)
	dw lo16(_URDoorROpen)	; 135 (Ultimate DOOM)
	dw lo16(_URDoorYOpen)	; 136 (Ultimate DOOM)
	dw lo16(_URDoorYOpen)	; 137 (Ultimate DOOM)
	dw 0	; 138
	dw 0	; 139


;
;	* * * * * * *       DOORS/REMOTE DOORS       * * * * * * *
;
_URDoorOpenOnce:
	ibt r7,#(_TPCDoorOpen-_TPlatformCode)
	bra _URDoors2
	nop
_URDoorOpenCloseOnce:
	ibt r7,#(_TPCDoorOpenClose-_TPlatformCode)
	bra _URDoors2
	nop

_URDoorClose:
	ibt r7,#(_TPCDoorClose-_TPlatformCode)
	bra _URDoors
	nop
_URDoorOpen:
	ibt r7,#(_TPCDoorOpen-_TPlatformCode)
	bra _URDoors
	nop
_URDoorOpenClose:
	ibt r7,#(_TPCDoorOpenClose-_TPlatformCode)
;
;	>>>   COMMON REMOTE DOOR CODE   <<<
;
_URDoors:
	link #4	; Add Switch Toggle Task
	iwt r15,#lo16(_RLAddToggle)
	nop
_URDoors2:
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%or_i(rllfUsed)	; USED
;	from	r0
	stb (r3)
	lms r0,(EMDOORS&$FFFF)	; Base of Doors
	sms (ULSector&$FFFF),r0
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb
_URDoors5:
	lms r14,(ULSector&$FFFF)	; Door Sector
	iwt r1,#lo16(ULTag)	; Get LineTag
	to r1
	ldb (r1)
	lms r11,(EMSECTORS&$FFFF)	; R11 = Base of Sectors
	with r11
	%add_i(rlsTag)
_URDoors6:
	to r6	; Get Sector
	getb
	from r6	; End of Door Sectors?
;	to	r0
	sex
	inc r0
	beq _URDoors9	; Yes!
	with r14	; No
	%add_i((rlpdNumLines-rlpdSector))
	getb	; Get #Lines
;	with	r0
	add r0
	inc r0
;	from	r0				; Next DoorData
	to r12
	add r14
	from r6	; Get Sector Tag
;	to	r0
	%umult_i(rlsSize)
;	from	r0
	to r14
	add r11
	getb
;	with	r0				; SectorTag = LineTag?
	sub r1	; @CMP@
	with r12
	bne _URDoors6	; No, Next Door (Yes: Add this Door!)
	to r14
	iwt r4,#lo16(ULType)	; Get LineType
	to r4
	ldb (r4)
	sms (ULSector&$FFFF),r12	; Door Sector
	iwt r12,#lo16(_URDoors5)
	iwt r15,#lo16(_RLAddPlatformDoor2)
	nop
_URDoors9:
	iwt r15,#lo16(_RU2XY11000)
	nop

;
;	>>>   KEYED REMOTE DOORS (Ultimate DOOM: 99, 133-137, opened once)   <<<
;
_URDoorBOpen:
	ibt r1,#%00000011	; BLUE KEYS
	iwt r6,#lo16(DOORBLUELOCKEDMSGA)
	iwt r7,#lo16(DOORBLUELOCKEDMSGB)
	iwt r8,#lo16(DOORBLUELOCKEDMSGC)
	bra _URDoorKOpen
	nop
_URDoorROpen:
	ibt r1,#%00110000	; RED KEYS
	iwt r6,#lo16(DOORREDLOCKEDMSGA)
	iwt r7,#lo16(DOORREDLOCKEDMSGB)
	iwt r8,#lo16(DOORREDLOCKEDMSGC)
	bra _URDoorKOpen
	nop
_URDoorYOpen:
	ibt r1,#%00001100	; YELLOW KEYS
	iwt r6,#lo16(DOORYELLOWLOCKEDMSGA)
	iwt r7,#lo16(DOORYELLOWLOCKEDMSGB)
	iwt r8,#lo16(DOORYELLOWLOCKEDMSGC)
_URDoorKOpen:
	iwt r0,#lo16(PlayerKeys)	; Does Player Have Key?
	ldb (r0)
	and r1
	beq _UDoorLocked	; No!
	nop
	iwt r15,#lo16(_URDoorOpenOnce)
	nop

_UDoorLocked:
	sms (MsgDataA&$FFFF),r6	; Door Locked!
	sms (MsgDataB&$FFFF),r7
	sms (MsgDataC&$FFFF),r8
	iwt r0,#(3*60)	; Display Message for 3 Seconds
	sms (MsgCount&$FFFF),r0
	iwt r15,#lo16(_RU2XY12000)
	nop

_UDoorBOpen:
	ibt r1,#%00000011	; BLUE KEYS
	iwt r6,#lo16(DOORBLUELOCKEDMSGA)
	iwt r7,#lo16(DOORBLUELOCKEDMSGB)
	iwt r8,#lo16(DOORBLUELOCKEDMSGC)
	bra _UDoorKOpen
	nop
_UDoorROpen:
	ibt r1,#%00110000	; RED KEYS
	iwt r6,#lo16(DOORREDLOCKEDMSGA)
	iwt r7,#lo16(DOORREDLOCKEDMSGB)
	iwt r8,#lo16(DOORREDLOCKEDMSGC)
	bra _UDoorKOpen
	nop
_UDoorYOpen:
	ibt r1,#%00001100	; YELLOW KEYS
	iwt r6,#lo16(DOORYELLOWLOCKEDMSGA)
	iwt r7,#lo16(DOORYELLOWLOCKEDMSGB)
	iwt r8,#lo16(DOORYELLOWLOCKEDMSGC)
_UDoorKOpen:
	iwt r0,#lo16(PlayerKeys)	; Does Player Have Key?
;	to	r0
	ldb (r0)
;	with	r0
	and r1
	beq _UDoorLocked	; No!
	nop
_UDoorOpen:
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%or_i(rllfUsed)	; USED
;	from	r0
	stb (r3)
	ibt r7,#(_TPCDoorOpen-_TPlatformCode)
	bra _UDoors
	nop

_UDoorBOpenClose:
	ibt r1,#%00000011	; BLUE KEYS
	iwt r6,#lo16(DOORBLUELOCKEDMSGA)
	iwt r7,#lo16(DOORBLUELOCKEDMSGB)
	iwt r8,#lo16(DOORBLUELOCKEDMSGC)
	bra _UDoorKOpenClose
	nop
_UDoorROpenClose:
	ibt r1,#%00110000	; RED KEYS
	iwt r6,#lo16(DOORREDLOCKEDMSGA)
	iwt r7,#lo16(DOORREDLOCKEDMSGB)
	iwt r8,#lo16(DOORREDLOCKEDMSGC)
	bra _UDoorKOpenClose
	nop
_UDoorYOpenClose:
	ibt r1,#%00001100	; YELLOW KEYS
	iwt r6,#lo16(DOORYELLOWLOCKEDMSGA)
	iwt r7,#lo16(DOORYELLOWLOCKEDMSGB)
	iwt r8,#lo16(DOORYELLOWLOCKEDMSGC)
_UDoorKOpenClose:
	iwt r0,#lo16(PlayerKeys)	; Does Player Have Key?
;	to	r0
	ldb (r0)
;	with	r0
	and r1
	beq _UDoorLocked	; No!
	nop
_UDoorOpenClose:
	ibt r7,#(_TPCDoorOpenClose-_TPlatformCode)
;
;	>>>   COMMON DOOR CODE   <<<
;
_UDoors:
;
;	>>>   GET LINE FACE   <<<
;
	ibt r0,#lo16(EMBSP+2)	; Bank of EM Data
	assert (lo16(EMBSP+2))&$FFFF < $80 || (lo16(EMBSP+2))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	ldb (r0)
	romb
	lms r0,(ULLine&$FFFF)	; Get Pointer to Line (level RAM $71)
;	with	r0
	%sub_i((rllType-rllFace))
	%RAMB71(r1)
	ldw (r0)	; Get Line's Face
	%RAMB70(r1)
	lms r1,(EMFACES&$FFFF)	; Add Base of Faces
	with r1
	add r0
	inc r1	; Move to SectorFar
	move r14,r1	; Get SectorFar
	lms r12,(ULReturnAddress&$FFFF)	; Get Return Address
;	move	r12,#<_RU2XY15000
	with r4	; LineType
	lob
	to r6	; Sector
	getb
	iwt r15,#lo16(_RLAddPlatformDoor)
	nop


;
;	* * * * * * *       EXIT TO NEXT/SECRET LEVEL       * * * * * * *
;
_UExitSecret:
_UExit:
	sms (ExitLevel&$FFFF),r4	; 11=GO TO NEXT LEVEL, 51=GO TO SECRET LEVEL
	ibt r3,#swtchx_eff
	iwt r15,#lo16(_RU2XY15000)
	nop


;
;	* * * * * * *       STAIRS       * * * * * * *
;
_UStairs16:	; (Ultimate DOOM) S1 127: stairs with 16-unit steps
	ibt r0,#16
	bra _UStairsS
	nop
_UStairs:
	ibt r0,#8
_UStairsS:
	sms (ULStairStep&$FFFF),r0
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%or_i(rllfUsed)	; USED
;	from	r0
	stb (r3)
	with r4	; LineTag
	hib
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb
	lms r14,(EMSTAIRS&$FFFF)	; Base of StairData
	ibt r7,#(_TPCStairRise-_TPlatformCode)
_UStairs3:
	getb	; Get StairTag
;	with	r0				; StairTag = LineTag?
	sub r4	; @CMP@
	beq _UStairs5	; Yes!
	with r14	; No!
	%add_i((rlpsNumSectors-rlpsTag))
	getb	; Get #Sectors
	inc r0
	with r14	; Next StairData
	bra _UStairs3
	add r0
_UStairs5:
;	with	r14				; R5 = STARTING HEIGHT
	%add_i((rlpsHeight-rlpsTag))
	sms (ULCode&$FFFF),r14	; STAIRDATA
	getb
	inc r14
	to r5
	getbh
	inc r14
	sms (ULSector&$FFFF),r14	; Save StairData Pointer
;	to	r0				; R0 = #SECTORS
	getb
	sms (ULCount&$FFFF),r0	; Save Counter
	iwt r12,#lo16(_UStairs6)
_UStairs6:
	lms r0,(ULCount&$FFFF)	; Get Counter
	dec r0
	bmi _UStairs9
;	from	r0				; Update Counter
	sbk
	lms r1,(ULStairStep&$FFFF)	; FloorHeight += StairStep
	with r5
	add r1
	lms r10,(ULCode&$FFFF)	; R10 = STAIRDATA
	lms r14,(ULSector&$FFFF)	; Get StairData Pointer
	inc r14
	from r14	; Update StairData Pointer
	sbk
	to r6	; R6 = SECTOR
	getb
	iwt r15,#lo16(_RLAddPlatformFloor)
	nop
_UStairs9:
	iwt r15,#lo16(_RU2XY11000)
	nop


;
;	* * * * * * *       COMPLEX FLOORS       * * * * * * *
;
_UFloor:
	link #4	; Add Switch Toggle Task
	iwt r15,#lo16(_RLAddToggle)
	nop
_UFloorOnce:
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%or_i(rllfUsed)	; USED
;	from	r0
	stb (r3)
;
	from r4	; R1 = LineTag.B
	to r1
	hib
	with r4	; R4 = LineType.B
	lob
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb
	lms r14,(EMFLOORS&$FFFF)	; Base of FloorData
_UFloor3:
	getb	; Get FloorTag
;	with	r0				; FloorTag = LineTag?
	sub r1	; @CMP@
	bne _UFloor4	; No!
	inc r14
	getb	; Get FloorType
;	with	r0				; FloorType = LineType?
	sub r4	; @CMP@
	beq _UFloor5
_UFloor4:
	inc r14
	getb	; Get #Sectors
;	with	r0
	%umult_i(rlpfsSize)
	inc r0
	with r14	; Next FloorData
	bra _UFloor3
	add r0
_UFloor5:
	sms (ULSector&$FFFF),r14	; Save FloorData Pointer
;	to	r0				; R0 = #SECTORS
	getb
	sms (ULCount&$FFFF),r0	; Save Counter
	iwt r12,#lo16(_UFloor6)
_UFloor6:
	lms r0,(ULCount&$FFFF)	; Get Counter
	dec r0
	bmi _UFloor9
;	from	r0				; Update Counter
	sbk
	lms r14,(ULSector&$FFFF)	; Get FloorData Pointer
	inc r14
	move r10,r14	; R10 = FLOORDATA
	to r6	; R6 = SECTOR
	getb
	inc r14
	getb	; R5 = DESTINATION HEIGHT
	inc r14
	to r5
	getbh
	from r14	; Update FloorData Pointer
;	to	r0
	%add_i((rlpfsSize-(rlpfsHeight+1)-1))
;	from	r0
	sbk
	from r6	; R9 = SECTORDATA
;	to	r0
	%umult_i(rlsdSize)
	iwt r9,#lo16(_RLSectorData)
	with r9
	add r0
;
;	>>>   DOES THIS FLOOR SECTOR CHANGE IT'S TEXTURE?   <<<
;
	from r4	; R0 = LineType.B
;	to	r0
	lob
;	with	r0				; LineType = 9?
	sub #9
	beq _UFloor6C
;	with	r0				; LineType = 20?
	%sub_i((20-9))
	bne _UFloor8	; No, Don't Change FloorTexture
;
;	>>>   CHANGE FLOOR TEXTURE/TYPE   <<<
;
_UFloor6C:
	with r14	; Get ModelSector
	%add_i((rlpfsModelSector-(rlpfsHeight+1)))
	getb
;	with	r0
	%umult_i(rlsSize)
	lms r1,(EMSECTORS&$FFFF)	; R1 = Base of Sectors
;	with	r0				; Get ModelSector.FloorTexture
	%add_i(rlsFloorTexture)
;	from	r0				; R1 = ModelSector.FloorTexture
	to r14
	add r1
	to r1
	getb
	with r14	; Get ModelSector.Type
	%sub_i((rlsFloorTexture-rlsType))
	from r9	; SET NEW FLOORTEXTURE
;	to	r0
	%add_i(rlsdFloorTexture)
	from r1
	stb (r0)
	ibt r1,#rlsdfTypeNormal	; Type now NORMAL
	getb
;	with	r0				; Get SectorType
	lsr
;	with	r0
	lsr
;	with	r0
	sub #4
	beq _UFloor7C	; Type=4?
	dec r0
	beq _UFloor7C	; Type=5?
	dec r0
	dec r0
	beq _UFloor7C	; Type=7?
;	with	r0
	%sub_i((16-7))
	bne _UFloor7E	; Type=16?
	nop
_UFloor7C:
	ibt r1,#rlsdfTypeNukage	; Type now NUKAGE
_UFloor7E:
;	to	r0				; MARK SECTOR TYPE CHANGED
	ldb (r9)
	%bic_i(rlsdfTypeNormal|rlsdfTypeNukage)	; drop the previous type (Ultimate DOOM)
;	with	r0
	or r1
;	from	r0
	stb (r9)
;
;	>>>   DETERMINE DIRECTION OF FLOOR MOVEMENT   <<<
;
_UFloor8:
	ibt r7,#(_TPCFloorLower-_TPlatformCode)
	from r9	; Get Current FloorHeight
;	to	r0
	%add_i(rlsdFloorHeight)
;	to	r0
	ldw (r0)
;	with	r0				; Destination < Current?
	sub r5	; @CMP@
	bge _UFloor8E	; Yes, Lower Floor
	nop	;  No, Raise Floor
	ibt r7,#(_TPCFloorRise-_TPlatformCode)
_UFloor8E:
	iwt r15,#lo16(_RLAddPlatformFloor2)
	nop
_UFloor9:
	iwt r15,#lo16(_RU2XY11000)
	nop


;
;	* * * * * * *       LIFTS       * * * * * * *
;
_ULift:
	link #4	; Add Switch Toggle Task
	iwt r15,#lo16(_RLAddToggle)
	nop
_ULiftOnce:
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%or_i(rllfUsed)	; USED
;	from	r0
	stb (r3)
;
	from r4	; R1 = LineType.B
	to r1
	lob
	with r4	; R4 = LineTag.B
	hib
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb
	lms r14,(EMLIFTS&$FFFF)	; Base of LiftData
_ULift3:
	getb	; Get LiftTag
;	with	r0				; LiftTag = LineTag?
	sub r4	; @CMP@
	bne _ULift4	; No!
	inc r14
	getb	; Get LiftType
;	with	r0				; LiftType = LineType?
	sub r1	; @CMP@
	beq _ULift5
_ULift4:
	inc r14
	getb	; Get #Sectors
;	with	r0
	%umult_i(rlplsSize)
	inc r0
	with r14	; Next LiftData
	bra _ULift3
	add r0
;
_ULift5:
	sms (ULSector&$FFFF),r14	; Save LiftData Pointer
;	to	r0				; R0 = #SECTORS
	getb
	sms (ULCount&$FFFF),r0	; Save Counter
	iwt r12,#lo16(_ULift6)
_ULift6:
	lms r0,(ULCount&$FFFF)	; Get Counter
	dec r0
	bmi _ULift9
;	from	r0				; Update Counter
	sbk
	lms r14,(ULSector&$FFFF)	; Get LiftData Pointer
	inc r14
	move r10,r14	; R10 = LIFTDATA
	to r6	; R6 = LIFTSECTOR
	getb
	from r14
;	to	r0
	%add_i((rlplsSize-rlplsSector-1))
;	from	r0				; Update LiftData Pointer
	sbk
	ibt r7,#(_TPCLift-_TPlatformCode)	; R7 = LIFTSTATECODE
	iwt r15,#lo16(_RLAddPlatformLift)
	nop
_ULift9:
	iwt r15,#lo16(_RU2XY11000)
	nop
