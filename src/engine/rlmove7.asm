	arch 65816
;**********************************************************************
;*                                                                    *
;*                  P R O J E C T :   REALITY_ENGINE                  *
;*                                                                    *
;*                      OBJECT MOVEMENT MODULE 7                      *
;*                                                                    *
;*                            LINE TRIGGERS                           *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/music.inc"


	; public _RLMoveXY7


	%section(ENGINE_GSUCODE)
	arch superfx


	!rTemp = r12	; Temporary Variable
;
	!rDX = r5	; DeltaX
	!rDY = r6	; DeltaY
;
	!rX0 = r7	; Initial Object X Coordinate
	!rY0 = r8	; Initial Object Y Coordinate
	!rX1 = r9	;   Final Object X Coordinate
	!rY1 = r10	;   Final Object Y Coordinate
;
	!rMoveLinesPtr = r11	; MoveLines Pointer
;
	!rLX0 = r3	; Line X0 Coordinate
	!rLY0 = r13	; Line Y0 Coordinate
	!rLDY = r14	; Line Delta Y
;
	!rObj = r12	; Pointer to RLObject
	!rSectorData = r9	; Pointer to Object's SectorData


	%align_pad(5, 16, (_RM7XY10000-_RM7XY2000)&$0F)

;
;	* * * * * * *       FINISHED MOVEMENT!       * * * * * * *
;
_RM7XY10000:
	lms !rObj,(MVRObj&$FFFF)	; Get RLObject Pointer
	lms r15,(MVReturnAddress&$FFFF)	; Return to Caller
;	with	r0				; R0 = 0 = MOVEMENT!
	sub r0

;
;	* * * * * * *       REALITY_ENGINE MOVE RLOBJECT XY       * * * * * * *
;
_RLMoveXY7:
	lms r0,(MVIPercent&$FFFF)	; Percentage of Movement Without Collision
	dec r0
	bmi _RM7XY10000	; NO MOVEMENT!
	nop
_RLMoveXY7A:
	iwt r0,#lo16(MVULCount)	; #Lines Matching Trigger Flags
;	to	r0
	ldb (r0)
	dec r0
	bmi _RM7XY10000	; NO MATCHING LINES!
	nop
;
;	>>>   INITIALIZE MOVELINES LIST POINTER   <<<
;
	iwt r0,#lo16(_RLMoveLines-rlmlSize)	; Start of MoveLines List
	sms (MVMLPtr&$FFFF),r0	; MoveLines Pointer
;
;	>>>   GET OBJECT MOVEMENT COORDINATES   <<<
;
_RM7XY1000:
	lms !rX0,(MVRX&$FFFF)	; Initial Object X Coordinate
	lms !rY0,(MVRY&$FFFF)	; Initial Object Y Coordinate
	lms r0,(MVRObj&$FFFF)	; Pointer to Object
;	with	r0				; Move to X Coordinate
	%add_i((rloX+2))
	to !rX1	; Final Object X Coordinate
	ldw (r0)
;	with	r0
	%add_i(((rloY+2)-(rloX+2)))
	to !rY1	; Final Object Y Coordinate
	ldw (r0)
;
	ibt r0,#lo16(EMBSP+2)	; Bank of EM Data
	assert (lo16(EMBSP+2))&$FFFF < $80 || (lo16(EMBSP+2))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	ldb (r0)
	romb

;
;	* * * * * * *       CHECK MOVEMENT AGAINST LINELIST       * * * * * * *
;
	%CACHEB(_RLMoveXY7)
_RM7XY2000:
;
;	>>>   CHECK NEXT MOVELINE   <<<
;
_RM7XY2100:
	iwt r4,#lo16(MVULMask)	; LineFlags Type Mask
	to r4
	ldb (r4)
	lms !rMoveLinesPtr,(MVMLPtr&$FFFF)	; MoveLines Pointer
	ibt r6,#rlmlSize	; Size of MoveLines Entry
_RM7XY2200:
	with !rMoveLinesPtr	; Move to Next Line
	add r6
	to r2	; Get Next Line#
	ldw (!rMoveLinesPtr)
	inc r2	; End of MoveLines?
	beq _RM7XY10000	; Yes!
;
;	>>>   GET LINE FLAGS   <<<
;
	from !rMoveLinesPtr	; Move to LineFlags
;	to	r0
	%add_i((rlmlFlags+1))
;	to	r0
	ldb (r0)
;	with	r0				; TRIGGER Line?
	and r4
	beq _RM7XY2200+1	; No
	with !rMoveLinesPtr	; Move to Next Line

;
;	* * * * * * *       DOES LINE CROSS MOVEMENT?       * * * * * * *
;
	sms (MVMLPtr&$FFFF),!rMoveLinesPtr	; Save MoveLines Pointer
	from !rX1	; Delta X
	to !rDX
	sub !rX0
	from !rY1	; Delta Y
	to !rDY
	sub !rY0
;
;	>>>   GET LINE VERTEXES   <<<
;
	from !rMoveLinesPtr	; Move to Vertex X1
;	to	r0
	%add_i(rlmlLX1)
	to !rLX0
	ldw (r0)
	inc r0
	inc r0
	to !rLY0
	ldw (r0)
	from !rLX0	; R0 = (LineX0 - ObjectX)
;	to	r0
	sub !rX0
	move r1,!rLY0	; R1 = (LineY0 - ObjectY)
	link #4
	with r1
	bra _RM7XY4000
	sub !rY0
;
;	>>>   VERTEX 2   <<<
;
	move !rTemp,r0	; Save SIDE1
	from !rY1	; Delta Y
	to !rDY
	sub !rY0
	lms r0,(MVMLPtr&$FFFF)	; Move to Vertex Y2
;	with	r0
	%add_i(rlmlLY2)
	to r1
	ldw (r0)
	dec r0
	dec r0
;	to	r0
	ldw (r0)
;	with	r0				; R0 = (LineX1 - ObjectX)
	sub !rX0
	link #4
	with r1	; R1 = (LineY1 - ObjectY)
	bra _RM7XY4000
	sub !rY0
;
;	with	r0				; On Opposite Sides?
	xor !rTemp
	bpl _RM7XY2100	; No, Same Side!
	nop

;
;	* * * * * * *       DOES MOVEMENT CROSS LINE?       * * * * * * *
;
	lms r0,(MVMLPtr&$FFFF)	; Move to Vertex X2
;	with	r0
	%add_i(rlmlLX2)
	to r1
	ldw (r0)
	from r1	; DeltaX
	to !rDX
	sub !rLX0
	inc r0
	inc r0
;	to	r0				; DeltaY
	ldw (r0)
;	from	r0
	to !rDY
	sub !rLY0
	move !rLDY,!rDY
;
	from !rY0	; R1 = (ObjectY0 - LineY)
	to r1
	sub !rLY0
	link #4
	from !rX0	; R0 = (ObjectX0 - LineX)
;	to	r0
	bra _RM7XY4000
	sub !rLX0
;
	moves !rTemp,r0	; Save SIDE1
;	bmi	_RM7XY3800			; Only Trigger RIGHT->LEFT!
;
	from !rY1	; R1 = (ObjectY1 - LineY)
	to r1
	sub !rLY0
	move !rDY,!rLDY
	link #4
	from !rX1	; R0 = (ObjectX1 - LineX)
;	to	r0
	bra _RM7XY4000
	sub !rLX0
;
;	with	r0				; On Opposite Sides?
	xor !rTemp
	bmi _RM7XY5000	; YES!  TRIGGERED!
	nop
_RM7XY3800:
	iwt r15,#lo16(_RM7XY2100)	; No, Not Triggered
	nop

;
;	* * * * * * *       GET DIRECTION OF COORDINATE RELATIVE TO LINE       * * * * * * *
;
_RM7XY4000:
;	with	r0				; Result in R0:R2
	lmult
	move r2,r4
	move r6,r5	; Result in R1:R4
	with r1
	lmult
	with r2
	sub r4
;	with	r0				; R0:R2 = SIDE
	sbc r1
	jmp r11
	nop
_RM7XY4900:
	iwt r15,#lo16(_RM7XY2100)	; Line Triggered Already!
	nop

;
;	* * * * * * *       FOUND A TRIGGERABLE LINE/ITEM       * * * * * * *
;
_RM7XY5000:
	lms r0,(MVMLPtr&$FFFF)	; MoveLines Pointer
	to r2	; Get TRIGGER LINE/ITEM RLOBJECT
	ldw (r0)
;
;	with	r0				; Move to LineFlags
	%add_i((rlmlFlags-rlmlLine))
;	to	r0				; TRIGGER LINE/ITEM?
	ldw (r0)
	inc r0
	bmi _RM7XY7000	; ITEM
	dec r0
;
;	* * * * * * *       FOUND A TRIGGERABLE LINE       * * * * * * *
;
_RM7XY6000:
;
;	>>>   HAS THIS LINE BEEN TRIGGERED ALREADY?   <<<
;
	iwt r3,#lo16(_RLLineFlags)	; Base of LineFlags
	with r3
	add r2
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%and_i(rllfUsed)	; USED?
	bne _RM7XY3800-1	; Yes, Can't REUSE It!
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
	sms (MVLine&$FFFF),r0	; Save Pointer to Line
	%RAMB71(r1)
	to r4	; R4 = Type.B / Tag.B
	ldw (r0)
	%RAMB70(r1)
	sms (MVType&$FFFF),r4
;
;	* * * * * * *       TRIGGER!       * * * * * * *
;
;	>>>   CALL TRIGGER LINE CODE   <<<
;
	ibt r0,#bank(_RLTriggerCode)	; Bank of Trigger Line Code
	romb
	iwt r1,#lo16(_RLTriggerCode)
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
	to r15	; Call Trigger Line Code
	getbh
	nop

;
;	* * * * * * *       FOUND AN ITEM!       * * * * * * *
;
;	>>>   CALL ITEM CODE   <<<
;
_RM7XY7000:
	dec r0	; SOLID ITEM?
	bmi _RM7XY7050	; YES!  CAN'T PICK IT UP!
	nop
	lms r0,(PlayerDead&$FFFF)	; Is Player Dead?
	dec r0
	bmi _RM7XY7100	; No
	nop
_RM7XY7050:
	iwt r15,#lo16(_RM7XY1000)	; SOLID Item or Player Dead: Can't Pick Up!
	nop
_RM7XY7100:
	ibt r0,#bank(_RLItemCode)	; Bank of Item Code
	romb
	from r2	; Get Item Type
;	to	r0
	%add_i(rloType)
;	to	r0
	ldb (r0)
	sms (MVType&$FFFF),r0	; Save Item Type
	iwt r1,#lo16(_RLItemCode)
;	with	r0
	add r0
;	from	r0
	to r14
	add r1
	sms (MVLine&$FFFF),r2	; Save Item RLObject
	getb
	inc r14
	link #4	; Return Address
	to r15	; Call Item Code
	getbh
	nop
;
;	>>>   COMPLETED GETTING ITEM   <<<
;
_RM7XY8000:
	lms r0,(RLRGB&$FFFF)	; rgbNone?
	inc r0
	bne _RM7XY8300+1	; No!  Can't Change RGB!
	ibt r0,#rgbPick	; Use PickUp RGBAnim
_RM7XY8200:
	sms (RLRGB&$FFFF),r0
;
;	>>>   DISPLAY MESSAGE   <<<
;
_RM7XY8300:
	ibt r0,#bank(_RLItemCode)	; Bank of Item Code
	romb
	lms r0,(MVType&$FFFF)	; Get Item Type
	iwt r1,#lo16(_RLItemMsgA)
;	with	r0
	add r0
;	from	r0
	to r14
	add r1
	ibt r1,#lo16(_RLItemMsgB-_RLItemMsgA-1)
	assert (lo16(_RLItemMsgB-_RLItemMsgA-1))&$FFFF < $80 || (lo16(_RLItemMsgB-_RLItemMsgA-1))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	getb	; MessageA
	inc r14
	getbh
	with r14
	add r1
	sms (MsgDataA&$FFFF),r0
	getb	; MessageB
	inc r14
	getbh
	with r14
	add r1
	sms (MsgDataB&$FFFF),r0
	getb	; MessageC
	inc r14
	getbh
	sms (MsgDataC&$FFFF),r0
	iwt r0,#(3*60)	; Display Message for 3 Seconds
	sms (MsgCount&$FFFF),r0
;
;	>>>   MAKE SOUND EFFECT   <<<
;
	ibt r3,#itemup_eff	; Make Item SoundEffect
	link #4
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop
;
;	>>>   MOVABLE RLOBJECT CONVERTED TO ITEM?   <<<
;
_RM7XY8400:
	lms !rObj,(MVLine&$FFFF)	; Get Item RLObject
	from !rObj
	to r2
	%add_i(rloFlags)
	to r1	; R1 = RLObject.Flags
	ldb (r2)
	from r1
;	to	r0
	swap
;	with	r0				; Movable?
	add r0
	with r1
	bpl _RM7XY8600	; No
	to r0
;
;	>>>   CONVERT MOVABLE RLOBJECT ITEM BACK   <<<
;
_RM7XY8500:
	ibt r1,#rlpfItem
;	with	r0
	bic r1
;	from	r0
	stb (r2)
	iwt r15,#lo16(_RM7XY1000)	; Check Next Trigger Line/Item
	nop
;
;	>>>   ONE MORE PICKED UP ITEM   <<<
;
_RM7XY8600:
	ibt r0,#bank(_ObjData)	; Move to _ObjData Bank
	romb
	lms r0,(MVType&$FFFF)	; Get Item Type
;	with	r0				; Get Offset into _ObjData
	%umult_i(rlodSize)
	iwt r1,#lo16(_ObjData+rlodFlags)	; Add Base of _ObjData
;	from	r0				; Move to Object Flags
	to r14
	add r1
	ibt r1,#rlodfItemCount	; Does Item Count towards TOTAL?
	getb
;	with	r0
	and r1
	beq _RM7XY8800+1	; NO!
;
	lms r0,(NumItems&$FFFF)	; Number of ITEMS++
	inc r0
;	from	r0
	sbk
;
;	>>>   REMOVE RLOBJECT   <<<
;
_RM7XY8800:
	lms r1,(MVMLPtr&$FFFF)	; MoveLines Pointer
	ibt r0,#rlmlSectorData	; Get MoveObject SectorData
;	with	r0
	add r1
	to r1	; R1 = SectorData.Objects
	ldw (r0)
	iwt r11,#lo16(_RM7XY1000)	; Check Next Trigger Line/Item
	iwt r15,#lo16(_RLRemSectorObject2)	; Remove RLObject
	nop

	%CACHEE(_RLMoveXY7)


;
;	* * * * * * *       ITEM CODE JUMPTABLE       * * * * * * *
;
_RLItemCode:
	dw 0	; Player1Start
	dw 0	; Player2Start
	dw 0	; Player3Start
	dw 0	; Player4Start
	dw 0	; DeathMatchStart
	dw 0	; TeleportSpot
;
	dw lo16(_IClip)	; Soldier
	dw lo16(_IShotGun)	; Sergeant
	dw 0	; Trooper
	dw 0	; Demon
	if !RLSPECTRE != 0
	dw 0	; Spectre
	endif
	dw 0	; CacoDemon
	dw 0	; LostSoul
	dw 0	; BaronOfHell
	dw 0	; CyberDemon
	dw 0	; SpiderDemon
	if !RLDOOM2MONSTERS != 0
	dw lo16(_IChainGun)	; ChainGunner (drops its chaingun)
	dw lo16(_IClip)	; WolfSS (drops a clip)
	dw 0	; HellKnight
	dw 0	; Arachnotron
	dw 0	; Mancubus
	dw 0	; Revenant
	dw 0	; PainElemental
	dw 0	; ArchVile
	dw 0	; Keen
	dw 0	; BossBrain
	dw 0	; BossShooter
	dw 0	; BossTarget
	endif
;
	dw lo16(_IShotGun)	; ShotGun
	dw lo16(_IChainSaw)	; ChainSaw
	dw lo16(_IChainGun)	; ChainGun
	dw lo16(_IRocketGun)	; RocketLauncher
	dw lo16(_IPlasmaGun)	; PlasmaGun
	dw lo16(_IBFG9000)	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw lo16(_ISuperShotGun)	; SuperShotGun
	endif
	dw lo16(_IKeyCardRed)	; RedKeyCard
	dw lo16(_IKeyCardBlue)	; BlueKeyCard
	dw lo16(_IKeyCardYellow)	; YellowKeyCard
	dw lo16(_IKeySkullRed)	; RedSkullKey
	dw lo16(_IKeySkullYellow)	; YellowSkullKey
	dw lo16(_IKeySkullBlue)	; BlueSkullKey
	dw lo16(_IBackPack)	; BackPack
	dw lo16(_IClip)	; Clip
	dw lo16(_IAmmoBox)	; AmmoBox
	dw lo16(_IShells)	; Shells
	dw lo16(_IShellsBox)	; ShellsBox
	dw lo16(_IRocket)	; Rocket
	dw lo16(_IRocketsBox)	; RocketBox
	dw lo16(_ICell)	; Cell
	dw lo16(_ICellPack)	; CellPack
	dw lo16(_IStimPack)	; StimPack
	dw lo16(_IMediKit)	; Medikit
	dw lo16(_IHealthBonus)	; HealthBonus
	dw lo16(_IArmorBonus)	; ArmorBonus
	dw lo16(_IArmorGreen)	; ArmorGreen
	dw lo16(_IArmorBlue)	; ArmorBlue
	dw lo16(_ISoulSphere)	; SoulSphere
	dw lo16(_IInvulnerable)	; Invulnerable
	dw lo16(_IBerserk)	; Berserk
	dw lo16(_IInvisible)	; Invisible
	dw lo16(_IRadiation)	; RadiationSuit
	dw lo16(_IComputerMap)	; ComputerMap
	dw lo16(_ILightGoggles)	; LightGoggles

;
;	* * * * * * *       TRIGGER LINE CODE JUMPTABLE       * * * * * * *
;
_RLTriggerCode:
	dw 0	; 000
	dw 0	; 001
	dw lo16(_GRDoorOpenOnce)	; 002
	dw lo16(_GRDoorCloseOnce)	; 003
	dw 0	; 004
	dw lo16(_GFloorOnce)	; 005
	dw 0	; 006
	dw 0	; 007
	dw lo16(_GStairs)	; 008
	dw 0	; 009
;
	dw lo16(_GLiftOnce)	; 010
	dw 0	; 011
	dw 0	; 012
	dw lo16(_GLightOnOnce)	; 013
	dw 0	; 014
	dw 0	; 015
	dw lo16(_GRDoorCloseOpenOnce)	; 016
	dw 0	; 017
	dw 0	; 018
	dw lo16(_GFloorOnce)	; 019
;
	dw 0	; 020
	dw 0	; 021
	dw lo16(_GFloorOnce)	; 022
	dw 0	; 023
	dw 0	; 024
	dw lo16(_GCeilingStart)	; 025 (Ultimate DOOM)
	dw 0	; 026
	dw 0	; 027
	dw 0	; 028
	dw 0	; 029
;
	dw lo16(_GFloorOnce)	; 030
	dw 0	; 031
	dw 0	; 032
	dw 0	; 033
	dw 0	; 034
	dw lo16(_GLightOffOnce)	; 035
	dw lo16(_GFloorOnce)	; 036
	dw lo16(_GFloorOnce)	; 037
	dw lo16(_GFloorOnce)	; 038
	dw lo16(_GTeleportOnce)	; 039*
;
	dw 0	; 040
	dw 0	; 041
	dw 0	; 042
	dw 0	; 043
	dw lo16(_GCeilingStart)	; 044 (Ultimate DOOM)
	dw 0	; 045
	dw 0	; 046
	dw 0	; 047
	dw 0	; 048
	dw 0	; 049
;
	dw 0	; 050
	dw 0	; 051
	dw lo16(_GExit)	; 052
	dw 0	; 053
	dw 0	; 054
	dw 0	; 055
	dw lo16(_GFloorOnce)	; 056
	dw 0	; 057
	dw lo16(_GFloorOnce)	; 058
	dw lo16(_GFloorOnce)	; 059
;
	dw 0	; 060
	dw 0	; 061
	dw 0	; 062
	dw 0	; 063
	dw 0	; 064
	dw lo16(_GFloorOnce)	; 065 (Ultimate DOOM)
	dw 0	; 066
	dw 0	; 067
	dw 0	; 068
	dw 0	; 069
;
	dw 0	; 070
	dw 0	; 071
	dw 0	; 072
	dw lo16(_GCeilingStart)	; 073
	dw lo16(_GCeilingStop)	; 074
	dw lo16(_GRDoorClose)	; 075
	dw lo16(_GRDoorCloseOpen)	; 076 (Ultimate DOOM)
	dw lo16(_GCeilingStart)	; 077
	dw 0	; 078
	dw 0	; 079
;
	dw 0	; 080
	dw 0	; 081
	dw lo16(_GFloor)	; 082
	dw lo16(_GFloor)	; 083 (Ultimate DOOM)
	dw 0	; 084
	dw 0	; 085
	dw lo16(_GRDoorOpen)	; 086
	dw lo16(_GMovingFloorStart)	; 087
	dw lo16(_GLift)	; 088*
	dw lo16(_GMovingFloorStop)	; 089
;
	dw lo16(_GRDoorOpenClose)	; 090
	dw lo16(_GFloor)	; 091
	dw 0	; 092
	dw 0	; 093
	dw 0	; 094
	dw 0	; 095
	dw 0	; 096
	dw lo16(_GTeleport)	; 097*
	dw lo16(_GFloor)	; 098
	dw 0	; 099
	dw 0	; 100
	dw 0	; 101
	dw 0	; 102
	dw 0	; 103
	dw lo16(_GLightOffOnce)	; 104 (Ultimate DOOM)
	dw lo16(_GRDoorOpenClose)	; 105 (Ultimate DOOM)
	dw 0	; 106
	dw 0	; 107
	dw 0	; 108
	dw lo16(_GRDoorOpenOnce)	; 109 (Ultimate DOOM)
	dw 0	; 110
	dw 0	; 111
	dw 0	; 112
	dw 0	; 113
	dw 0	; 114
	dw 0	; 115
	dw 0	; 116
	dw 0	; 117
	dw 0	; 118
	dw 0	; 119
	dw lo16(_GLift)	; 120 (Ultimate DOOM)
	dw 0	; 121
	dw 0	; 122
	dw 0	; 123
	dw 0	; 124
	dw 0	; 125
	dw 0	; 126

;
;	* * * * * * *       TABLE OF ITEM MESSAGE A TEXTS       * * * * * * *
;
_RLItemMsgA:
	dw 0	; Player1Start
	dw 0	; Player2Start
	dw 0	; Player3Start
	dw 0	; Player4Start
	dw 0	; DeathMatchStart
	dw 0	; TeleportSpot
	dw lo16(CLIPMSGA)	; Soldier
	dw lo16(SHOTGUNMSGA)	; Sergeant
	dw 0	; Trooper
	dw 0	; Demon
	if !RLSPECTRE != 0
	dw 0	; Spectre
	endif
	dw 0	; CacoDemon
	dw 0	; LostSoul
	dw 0	; BaronOfHell
	dw 0	; CyberDemon
	dw 0	; SpiderDemon
	if !RLDOOM2MONSTERS != 0
	dw lo16(CHAINGUNMSGA)	; ChainGunner
	dw lo16(CLIPMSGA)	; WolfSS
	dw 0	; HellKnight
	dw 0	; Arachnotron
	dw 0	; Mancubus
	dw 0	; Revenant
	dw 0	; PainElemental
	dw 0	; ArchVile
	dw 0	; Keen
	dw 0	; BossBrain
	dw 0	; BossShooter
	dw 0	; BossTarget
	endif
	dw lo16(SHOTGUNMSGA)	; ShotGun
	dw lo16(CHAINSAWMSGA)	; ChainSaw
	dw lo16(CHAINGUNMSGA)	; ChainGun
	dw lo16(ROCKETGUNMSGA)	; RocketLauncher
	dw lo16(PLASMAGUNMSGA)	; PlasmaGun
	dw lo16(BFGMSGA)	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw lo16(YOUGOTA)	; SuperShotGun
	endif
	dw lo16(REDKEYCARDMSGA)	; RedKeyCard
	dw lo16(BLUEKEYCARDMSGA)	; BlueKeyCard
	dw lo16(YELLOWKEYCARDMSGA)	; YellowKeyCard
	dw lo16(REDKEYCARDMSGA)	; RedSkullKey
	dw lo16(YELLOWKEYCARDMSGA)	; YellowSkullKey
	dw lo16(BLUEKEYCARDMSGA)	; BlueSkullKey
	dw lo16(BACKPACKMSGA)	; BackPack
	dw lo16(CLIPMSGA)	; Clip
	dw lo16(BULLETSBOXMSGA)	; AmmoBox
	dw lo16(SHELLSMSGA)	; Shells
	dw lo16(SHELLSBOXMSGA)	; ShellsBox
	dw lo16(ROCKETMSGA)	; Rocket
	dw lo16(ROCKETSBOXMSGA)	; RocketBox
	dw lo16(CELLMSGA)	; Cell
	dw lo16(CELLPACKMSGA)	; CellPack
	dw lo16(STIMPACKMSGA)	; StimPack
	dw lo16(MEDIKITMSGA)	; Medikit
	dw lo16(HEALTHBONUSMSGA)	; HealthBonus
	dw lo16(ARMORBONUSMSGA)	; ArmorBonus
	dw lo16(MEGAARMORMSGA)	; ArmorGreen
	dw lo16(MEGAARMORMSGA)	; ArmorBlue
	dw lo16(SUPERCHARGEMSGA)	; SoulSphere
	dw lo16(INVULNERABLEMSGA)	; Invulnerable
	dw lo16(BERSERKMSGA)	; Berserk
	dw lo16(INVISIBLEMSGA)	; Invisible
	dw lo16(RADSUITMSGA)	; RadiationSuit
	dw lo16(COMPUTERMAPMSGA)	; ComputerMap
	dw lo16(LIGHTGOGGLESMSGA)	; LightGoggles
;
;	* * * * * * *       TABLE OF ITEM MESSAGE B TEXTS       * * * * * * *
;
_RLItemMsgB:
	dw 0	; Player1Start
	dw 0	; Player2Start
	dw 0	; Player3Start
	dw 0	; Player4Start
	dw 0	; DeathMatchStart
	dw 0	; TeleportSpot
	dw lo16(CLIPMSGB)	; Soldier
	dw lo16(SHOTGUNMSGB)	; Sergeant
	dw 0	; Trooper
	dw 0	; Demon
	if !RLSPECTRE != 0
	dw 0	; Spectre
	endif
	dw 0	; CacoDemon
	dw 0	; LostSoul
	dw 0	; BaronOfHell
	dw 0	; CyberDemon
	dw 0	; SpiderDemon
	if !RLDOOM2MONSTERS != 0
	dw lo16(CHAINGUNMSGB)	; ChainGunner
	dw lo16(CLIPMSGB)	; WolfSS
	dw 0	; HellKnight
	dw 0	; Arachnotron
	dw 0	; Mancubus
	dw 0	; Revenant
	dw 0	; PainElemental
	dw 0	; ArchVile
	dw 0	; Keen
	dw 0	; BossBrain
	dw 0	; BossShooter
	dw 0	; BossTarget
	endif
	dw lo16(SHOTGUNMSGB)	; ShotGun
	dw lo16(CHAINSAWMSGB)	; ChainSaw
	dw lo16(CHAINGUNMSGB)	; ChainGun
	dw lo16(ROCKETGUNMSGB)	; RocketLauncher
	dw lo16(PLASMAGUNMSGB)	; PlasmaGun
	dw lo16(BFGMSGB)	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw lo16(SUPERSHOTGUNMSGB)	; SuperShotGun
	endif
	dw lo16(REDKEYCARDMSGB)	; RedKeyCard
	dw lo16(BLUEKEYCARDMSGB)	; BlueKeyCard
	dw lo16(YELLOWKEYCARDMSGB)	; YellowKeyCard
	dw lo16(REDKEYCARDMSGB)	; RedSkullKey
	dw lo16(YELLOWKEYCARDMSGB)	; YellowSkullKey
	dw lo16(BLUEKEYCARDMSGB)	; BlueSkullKey
	dw lo16(BACKPACKMSGB)	; BackPack
	dw lo16(CLIPMSGB)	; Clip
	dw lo16(BULLETSBOXMSGB)	; AmmoBox
	dw lo16(SHELLSMSGB)	; Shells
	dw lo16(SHELLSBOXMSGB)	; ShellsBox
	dw lo16(ROCKETMSGB)	; Rocket
	dw lo16(ROCKETSBOXMSGB)	; RocketBox
	dw lo16(CELLMSGB)	; Cell
	dw lo16(CELLPACKMSGB)	; CellPack
	dw lo16(STIMPACKMSGB)	; StimPack
	dw lo16(MEDIKITMSGB)	; Medikit
	dw lo16(HEALTHBONUSMSGB)	; HealthBonus
	dw lo16(ARMORBONUSMSGB)	; ArmorBonus
	dw lo16(MEGAARMORMSGB)	; ArmorGreen
	dw lo16(MEGAARMORMSGB)	; ArmorBlue
	dw lo16(SUPERCHARGEMSGB)	; SoulSphere
	dw lo16(INVULNERABLEMSGB)	; Invulnerable
	dw lo16(BERSERKMSGB)	; Berserk
	dw lo16(INVISIBLEMSGB)	; Invisible
	dw lo16(RADSUITMSGB)	; RadiationSuit
	dw lo16(COMPUTERMAPMSGB)	; ComputerMap
	dw lo16(LIGHTGOGGLESMSGB)	; LightGoggles
;
;	* * * * * * *       TABLE OF ITEM MESSAGE C TEXTS       * * * * * * *
;
_RLItemMsgC:
	dw 0	; Player1Start
	dw 0	; Player2Start
	dw 0	; Player3Start
	dw 0	; Player4Start
	dw 0	; DeathMatchStart
	dw 0	; TeleportSpot
	dw lo16(CLIPMSGC)	; Soldier
	dw lo16(SHOTGUNMSGC)	; Sergeant
	dw 0	; Trooper
	dw 0	; Demon
	if !RLSPECTRE != 0
	dw 0	; Spectre
	endif
	dw 0	; CacoDemon
	dw 0	; LostSoul
	dw 0	; BaronOfHell
	dw 0	; CyberDemon
	dw 0	; SpiderDemon
	if !RLDOOM2MONSTERS != 0
	dw lo16(CHAINGUNMSGC)	; ChainGunner
	dw lo16(CLIPMSGC)	; WolfSS
	dw 0	; HellKnight
	dw 0	; Arachnotron
	dw 0	; Mancubus
	dw 0	; Revenant
	dw 0	; PainElemental
	dw 0	; ArchVile
	dw 0	; Keen
	dw 0	; BossBrain
	dw 0	; BossShooter
	dw 0	; BossTarget
	endif
	dw lo16(SHOTGUNMSGC)	; ShotGun
	dw lo16(CHAINSAWMSGC)	; ChainSaw
	dw lo16(CHAINGUNMSGC)	; ChainGun
	dw lo16(ROCKETGUNMSGC)	; RocketLauncher
	dw lo16(PLASMAGUNMSGC)	; PlasmaGun
	dw lo16(BFGMSGC)	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw lo16(SUPERSHOTGUNMSGC)	; SuperShotGun
	endif
	dw lo16(REDKEYCARDMSGC)	; RedKeyCard
	dw lo16(BLUEKEYCARDMSGC)	; BlueKeyCard
	dw lo16(YELLOWKEYCARDMSGC)	; YellowKeyCard
	dw lo16(REDKEYCARDMSGC)	; RedSkullKey
	dw lo16(YELLOWKEYCARDMSGC)	; YellowSkullKey
	dw lo16(BLUEKEYCARDMSGC)	; BlueSkullKey
	dw lo16(BACKPACKMSGC)	; BackPack
	dw lo16(CLIPMSGC)	; Clip
	dw lo16(BULLETSBOXMSGC)	; AmmoBox
	dw lo16(SHELLSMSGC)	; Shells
	dw lo16(SHELLSBOXMSGC)	; ShellsBox
	dw lo16(ROCKETMSGC)	; Rocket
	dw lo16(ROCKETSBOXMSGC)	; RocketBox
	dw lo16(CELLMSGC)	; Cell
	dw lo16(CELLPACKMSGC)	; CellPack
	dw lo16(STIMPACKMSGC)	; StimPack
	dw lo16(MEDIKITMSGC)	; Medikit
	dw lo16(HEALTHBONUSMSGC)	; HealthBonus
	dw lo16(ARMORBONUSMSGC)	; ArmorBonus
	dw lo16(MEGAARMORMSGC)	; ArmorGreen
	dw lo16(MEGAARMORMSGC)	; ArmorBlue
	dw lo16(SUPERCHARGEMSGC)	; SoulSphere
	dw lo16(INVULNERABLEMSGC)	; Invulnerable
	dw lo16(BERSERKMSGC)	; Berserk
	dw lo16(INVISIBLEMSGC)	; Invisible
	dw lo16(RADSUITMSGC)	; RadiationSuit
	dw lo16(COMPUTERMAPMSGC)	; ComputerMap
	dw lo16(LIGHTGOGGLESMSGC)	; LightGoggles


;
;	* * * * * * *       TELEPORT       * * * * * * *
;
_GTeleport0:
	iwt r15,#lo16(_RM7XY1000)
_GTeleportOnce:
	moves !rTemp,!rTemp	; Teleport RIGHT->LEFT?
	bmi _GTeleport0	; NO!  Can't Teleport LEFT->RIGHT!
	nop
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%or_i(rllfUsed)	; USED
;	from	r0
	stb (r3)
_GTeleport:
	moves !rTemp,!rTemp	; Teleport RIGHT->LEFT?
	bmi _GTeleport0	; NO!  Can't Teleport LEFT->RIGHT!
	nop
;
;	>>>   MAKE SOUND EFFECT   <<<
;
	lms r0,(MVRObj&$FFFF)	; Get Object Coordinates
;	with	r0
	%add_i((rloX+2))
	to r4
	ldw (r0)
;	with	r0
	%add_i(((rloY+2)-(rloX+2)))
	to r6
	ldw (r0)
	iwt r3,#lo16(sxTeleport-1)	; Sound Effect#
	link #4
	iwt r15,#lo16(_RLSoundEffect)
	nop
;
;	>>>   REMOVE RLOBJECT FROM OLD SECTOR   <<<
;
	lms !rObj,(MVRObj&$FFFF)	; Update Object Coordinates
	link #4	; Remove RLObject from Sector's ObjectList
	iwt r15,#lo16(_RLRemSectorObject)
	nop
;
;	>>>   FIND DESTINATION SECTOR   <<<
;
	lms r4,(MVType&$FFFF)	; LineTag
	with r4
	hib
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb
	lms r14,(EMSECTORS&$FFFF)	; Base of Sectors
	iwt r3,#lo16(_RLSectorData-rlsdSize)	; R3 = SectorData
	ibt r6,#-1	; Sector#
_GTeleport3:
	with r14	; Get SectorTag
	%add_i(rlsTag)
	with r3
	%add_i(rlsdSize)
	inc r6
	getb
	inc r14
;	with	r0				; SectorTag = LineTag?
	sub r4	; @CMP@
	bne _GTeleport3	; No
	from r3	; Move to Sector's RLObjects
	to r1
	%add_i(rlsdObjects)
_GTeleport5:
	to r1	; Move to Next Object
	ldw (r1)
	moves r1,r1
	beq _GTeleport3	; No More Objects?!
	from r1	; Get Object's Type
;	to	r0
	%add_i(rloType)
;	to	r0
	ldb (r0)
;	with	r0				; TELEPORT SPOT?
	%sub_i(otTeleportSpot)
	bne _GTeleport5+1	; No
	to r1
;
	with r1	; Get Teleport LevelObject
	%add_i(rloLObj)
	to r4	; R4 = LevelObject (level RAM, GSU RAM $71)
	ldw (r1)
	ibt r0,#1
	ramb
	to r7	; LevelObject X
	ldw (r4)
	inc r4
	inc r4
	to r8	; LevelObject Y
	ldw (r4)
	inc r4
	inc r4
	to r10	; LevelObject Angle
	ldw (r4)
	ibt r0,#0	; back to GSU RAM $70
	ramb
	from !rObj	; Update Object Coordinates
	to r2
	%add_i(rloX)
;	with	r0				; Update Object X Coordinate
	sub r0
;	from	r0
	stw (r2)
	inc r2
	inc r2
	from r7
	stw (r2)
	inc r2
	inc r2
;	from	r0				; Update Object Y Coordinate
	stw (r2)
	inc r2
	inc r2
	from r8
	stw (r2)
	inc r2
	inc r2
	from r3	; Update Object Z Coordinate
;	to	r0
	%add_i(rlsdFloorHeight)
	to r1
	ldw (r0)
	from r1
	stw (r2)
	inc r2
	inc r2
;	with	r0				; Update Object X Velocity
	sub r0
;	from	r0
	stw (r2)
	inc r2
	inc r2
;	from	r0				; Update Object Y Velocity
	stw (r2)
	inc r2
	inc r2
	from r10	; Update Object Angle
	stw (r2)
	inc r2
	inc r2
	from r6	; Update Object Sector
	stb (r2)
	with r2	; Move to Z2/TObj
	%add_i((rloZ2-rloSector))
	from !rObj	; Get Object Type
;	to	r0
	%add_i(rloType)
;	to	r0
	ldb (r0)
	dec r0	; Player Object?
	bmi _GTeleport6
	from r1	; Yes!  Update Z2
	from r0	; No!  Update TObj
_GTeleport6:
;	from	r0				; rloZ2/rloTObj
	stw (r2)
;
;	>>>   ADD RLOBJECT TO NEW SECTOR   <<<
;
	iwt r11,#lo16(_RM7XY1000)	; Add RLObject to Sector's ObjectList
	iwt r15,#lo16(_RLAddSectorObject)
	nop


;
;	* * * * * * *       EXIT TO NEXT LEVEL       * * * * * * *
;
_GExit:
;
;	>>>   MAKE SOUND EFFECT   <<<
;
	sms (ExitLevel&$FFFF),r4	; Low = LineType 52 (not 51) = GO TO NEXT LEVEL
	ibt r3,#swtchx_eff	; Sound Effect#
	iwt r11,#lo16(_RM7XY1000)
	iwt r15,#lo16(_RLPlayerSoundEffect)
	nop


;
;	* * * * * * *       REMOTE DOORS       * * * * * * *
;
_GRDoorCloseOnce:
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%or_i(rllfUsed)	; USED
;	from	r0
	stb (r3)
_GRDoorClose:
	ibt r7,#(_TPCDoorClose-_TPlatformCode)
	bra _GRDoors
	nop

_GRDoorOpenOnce:
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%or_i(rllfUsed)	; USED
;	from	r0
	stb (r3)
_GRDoorOpen:
	ibt r7,#(_TPCDoorOpen-_TPlatformCode)
	bra _GRDoors
	nop

_GRDoorCloseOpenOnce:
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%or_i(rllfUsed)	; USED
;	from	r0
	stb (r3)
_GRDoorCloseOpen:	; (Ultimate DOOM) WR 76: close, wait, open
	ibt r7,#(_TPCDoorCloseOpen-_TPlatformCode)
	bra _GRDoors
	nop

_GRDoorOpenClose:
	ibt r7,#(_TPCDoorOpenClose-_TPlatformCode)
;
;	>>>   COMMON REMOTE DOOR CODE   <<<
;
_GRDoors:
	lms r0,(EMDOORS&$FFFF)	; Base of Doors
	sms (MVSector&$FFFF),r0
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb
_GRDoors2:
	lms r14,(MVSector&$FFFF)	; Door Sector
	iwt r1,#lo16(MVTag)	; Get LineTag
	to r1
	ldb (r1)
	lms r11,(EMSECTORS&$FFFF)	; R11 = Base of Sectors
	with r11
	%add_i(rlsTag)
_GRDoors3:
	to r6	; Get Sector
	getb
	from r6	; End of Door Sectors?
;	to	r0
	sex
	inc r0
	beq _GRDoors9	; Yes!
	with r14	; No
	%add_i((rlpdNumLines-rlpdSector))
	getb	; Get #Lines
;	with	r0
	add r0
	inc r0
	from r14	; Next DoorData
	to r12
	add r0
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
	bne _GRDoors3	; No, Next DoorData (delay: R14 = R12)
	to r14
	iwt r4,#lo16(MVType)	; Get LineType
	to r4
	ldb (r4)
	sms (MVSector&$FFFF),r12	; Next DoorData
	iwt r12,#lo16(_GRDoors2)
	iwt r15,#lo16(_RLAddPlatformDoor2)
	nop
_GRDoors9:
	iwt r15,#lo16(_RM7XY1000)
	nop


;
;	* * * * * * *       LIGHTING       * * * * * * *
;
_GLightOffOnce:
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%or_i(rllfUsed)	; USED
;	from	r0
	stb (r3)
	ibt r1,#$F7	; LightLevel = $F7 = OFF
	bra _GLights
	nop

_GLightOnOnce:
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%or_i(rllfUsed)	; USED
;	from	r0
	stb (r3)
	ibt r1,#$00	; LightLevel = $00 = ON
;
;	>>>   COMMON LIGHTING CODE   <<<
;
_GLights:
	with r4	; R4 = LineTag
	hib
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb
	lms r14,(EMSECTORS&$FFFF)	; Base of Sectors
	iwt r3,#lo16(_RLSectorData+rlsdLightLevel-rlsdSize)	; R3 = SectorData
	ibt r2,#$4C	; END OF SECTORS MARKER
_GLights3:
	with r3	; Next Sector
	%add_i(rlsdSize)
	getb	; Get SectorType
;	with	r0
	sub r2
	beq _GLights9
	with r14	; Get SectorTag
	%add_i(rlsTag)
	getb
	inc r14
;	with	r0				; SectorTag = LineTag?
	sub r4	; @CMP@
	bne _GLights3	; No
	from r1	; Set New LightLevel
	alt1
	bra _GLights3
;	stb	(r3)
	stw (r3)
_GLights9:
	iwt r15,#lo16(_RM7XY1000)
	nop


;
;	* * * * * * *       COMPLEX FLOORS       * * * * * * *
;
_GFloorOnce:
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%or_i(rllfUsed)	; USED
;	from	r0
	stb (r3)
_GFloor:
	from r4	; R1 = LineTag.B
	to r1
	hib
	with r4	; R4 = LineType.B
	lob
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb
	lms r14,(EMFLOORS&$FFFF)	; Base of FloorData
_GFloor3:
	getb	; Get FloorTag
;	with	r0				; FloorTag = LineTag?
	sub r1	; @CMP@
	bne _GFloor4	; No!
	inc r14
	getb	; Get FloorType
;	with	r0				; FloorType = LineType?
	sub r4	; @CMP@
	beq _GFloor5
_GFloor4:
	inc r14
	getb	; Get #Sectors
;	with	r0
	%umult_i(rlpfsSize)
	inc r0
	with r14	; Next FloorData
	bra _GFloor3
	add r0
_GFloor5:
	sms (MVSector&$FFFF),r14	; Save FloorData Pointer
;	to	r0				; R0 = #SECTORS
	getb
	sms (MVCount&$FFFF),r0	; Save Counter
	iwt r12,#lo16(_GFloor6)
_GFloor6:
	lms r0,(MVCount&$FFFF)	; Get Counter
	dec r0
	bmi _GFloor9
;	from	r0				; Update Counter
	sbk
	lms r14,(MVSector&$FFFF)	; Get FloorData Pointer
	inc r14
	move r10,r14	; R10 = FLOORDATA
	to r6	; R6 = SECTOR
	getb
	inc r14
	getb	; R5 = DESTINATION HEIGHT
	inc r14
	to r5
	getbh
	from r14
;	to	r0
	%add_i((rlpfsSize-(rlpfsHeight+1)-1))
;	from	r0				; Update FloorData Pointer
	sbk
	from r6	; R9 = SECTORDATA
;	to	r0
	%umult_i(rlsdSize)
	iwt r9,#lo16(_RLSectorData)
	with r9
	add r0
;
;	>>>   DOES THIS FLOOR SECTOR CHANGE IT'S TEXTURE/TYPE?   <<<
;
	from r4	; R0 = LineType.B
;	to	r0
	lob
	ibt r7,#22	; LineType = 22?
;	with	r0				; @CMP@
	sub r7
	beq _GFloor7-1
	ibt r7,#(37-22)	; LineType = 37?
;	with	r0				; @CMP@
	sub r7
	beq _GFloor7-1
	ibt r7,#(59-37)	; LineType = 59?
;	with	r0				; @CMP@
	sub r7
	bne _GFloor8	; No, Don't Change FloorTexture
;
;	>>>   CHANGE FLOOR TEXTURE/TYPE   <<<
;
_GFloor7:
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
	beq _GFloor7C	; Type=4?
	dec r0
	beq _GFloor7C	; Type=5?
	dec r0
	dec r0
	beq _GFloor7C-1	; Type=7?
;	with	r0
	%sub_i((16-7))
	bne _GFloor7E	; Type=16?
	nop
_GFloor7C:
	ibt r1,#rlsdfTypeNukage	; Type now NUKAGE
_GFloor7E:
;	to	r0				; MARK SECTOR TYPE CHANGED
	ldb (r9)
	%bic_i(rlsdfTypeNormal|rlsdfTypeNukage)	; drop the previous type (Ultimate DOOM)
;	with	r0
	or r1
;	from	r0
	stb (r9)
_GFloor8:
	ibt r7,#(_TPCFloorLower-_TPlatformCode)
	from r9	; Get Current FloorHeight
;	to	r0
	%add_i(rlsdFloorHeight)
;	to	r0
	ldw (r0)
;	with	r0				; Destination < Current?
	sub r5	; @CMP@
	bge _GFloor8E	; Yes, Lower Floor
	nop	;  No, Raise Floor
	ibt r7,#(_TPCFloorRise-_TPlatformCode)
_GFloor8E:
	iwt r15,#lo16(_RLAddPlatformFloor2)
	nop
_GFloor9:
	iwt r15,#lo16(_RM7XY1000)
	nop


;
;	* * * * * * *       STAIRS       * * * * * * *
;
_GStairs:
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
_GStairs3:
	getb	; Get StairTag
;	with	r0				; StairTag = LineTag?
	sub r4	; @CMP@
	beq _GStairs5	; Yes!
	with r14	; No!
	%add_i((rlpsNumSectors-rlpsTag))
	getb	; Get #Sectors
	inc r0
	with r14	; Next StairData
	bra _GStairs3
	add r0
_GStairs5:
;	with	r14				; R5 = STARTING HEIGHT
	%add_i((rlpsHeight-rlpsTag))
	sms (MVCode&$FFFF),r14	; STAIRDATA
	getb
	inc r14
	to r5
	getbh
	inc r14
	sms (MVSector&$FFFF),r14	; Save StairData Pointer
;	to	r0				; R0 = #SECTORS
	getb
	sms (MVCount&$FFFF),r0	; Save Counter
	iwt r12,#lo16(_GStairs6)
_GStairs6:
	lms r0,(MVCount&$FFFF)	; Get Counter
	dec r0
	bmi _GStairs9
;	from	r0				; Update Counter
	sbk
	with r5	; FloorHeight += 8
	add #8
	lms r10,(MVCode&$FFFF)	; R10 = STAIRDATA
	lms r14,(MVSector&$FFFF)	; Get StairData Pointer
	inc r14
	from r14	; Update StairData Pointer
	sbk
	to r6	; R6 = SECTOR
	getb
	iwt r15,#lo16(_RLAddPlatformFloor)
	nop
_GStairs9:
	iwt r15,#lo16(_RM7XY1000)
	nop


;
;	* * * * * * *       LIFTS       * * * * * * *
;
_GLiftOnce:
;	to	r0				; Get LineFlags
	ldb (r3)
;	with	r0
	%or_i(rllfUsed)	; USED
;	from	r0
	stb (r3)
_GLift:
	ibt r7,#(_TPCLift-_TPlatformCode)	; R7 = LIFTSTATECODE
_GLift1:
	from r4	; R1 = LineType.B
	to r1
	lob
	with r4	; R4 = LineTag.B
	hib
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb
	lms r14,(EMLIFTS&$FFFF)	; Base of LiftData
_GLift3:
	getb	; Get LiftTag
;	with	r0				; LiftTag = LineTag?
	sub r4	; @CMP@
	bne _GLift4	; No!
	inc r14
	getb	; Get LiftType
;	from	r0				; LiftType = LineType?
	cmp r1
	beq _GLift5
_GLift4:
	inc r14
	getb	; Get #Sectors
;	with	r0
	%umult_i(rlplsSize)
	inc r0
	with r14	; Next LiftData
	bra _GLift3
	add r0
_GLift5:
	sms (MVSector&$FFFF),r14	; Save LiftData Pointer
;	to	r0				; R0 = #SECTORS
	getb
	sms (MVCount&$FFFF),r0	; Save Counter
	iwt r12,#lo16(_GLift6)
_GLift6:
	lms r0,(MVCount&$FFFF)	; Get Counter
	dec r0
	bmi _GLift9
;	from	r0				; Update Counter
	sbk
	lms r14,(MVSector&$FFFF)	; Get LiftData Pointer
	inc r14
	move r10,r14	; R10 = LIFTDATA
	to r6	; R6 = LIFTSECTOR
	getb
	from r14
;	to	r0
	%add_i((rlplsSize-rlplsSector-1))
;	from	r0				; Update LiftData Pointer
	sbk
	iwt r15,#lo16(_RLAddPlatformLift)
	nop
_GLift9:
	iwt r15,#lo16(_RM7XY1000)
	nop


;
;	* * * * * * *       MOVING FLOORS       * * * * * * *
;
_GMovingFloorStart:
	ibt r7,#(_TPCMovingFloor-_TPlatformCode)	; R7 = LIFTSTATECODE
	bra _GLift1
	nop
_GMovingFloorStop:
	ibt r7,#-1	; R7 = LIFTSTATECODE
	bra _GLift1
	nop


;
;	* * * * * * *       CRUSHING CEILINGS       * * * * * * *
;
_GCeilingStart:
	ibt r7,#(_TPCCrushingCeiling-_TPlatformCode)	; R7 = CEILINGSTATECODE
	bra _GCeiling
	nop
_GCeilingStop:
	ibt r7,#-1	; R7 = CEILINGSTATECODE
;
;	* * * * * * *       COMMON CEILINGS       * * * * * * *
;
_GCeiling:
	from r4	; R1 = LineType.B
	to r1
	lob
	with r4	; R4 = LineTag.B
	hib
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb
	lms r14,(EMCEILINGS&$FFFF)	; Base of CeilingData
_GCeiling3:
	getb	; Get CeilingTag
;	with	r0				; CeilingTag = LineTag?
	sub r4	; @CMP@
	bne _GCeiling4	; No!
	inc r14
	getb	; Get CeilingType
;	with	r0				; CeilingType = LineType?
	sub r1	; @CMP@
	beq _GCeiling5
_GCeiling4:
	inc r14
	to r2	; R2 = #Sectors
	getb
_GCeiling4E:
	with r14	; Get #Lines in this Sector
	%add_i((rlpcsNumLines+1))
	getb
;	with	r0				; Skip LineList
	add r0
	dec r2	; One less Sector
	with r14
	bne _GCeiling4E
	add r0
	bra _GCeiling3	; Next CeilingData
	inc r14
_GCeiling5:
	sms (MVSector&$FFFF),r14	; Save CeilingData Pointer
;	to	r0				; R0 = #SECTORS
	getb
	sms (MVCount&$FFFF),r0	; Save Counter
	iwt r12,#lo16(_GCeiling6)
_GCeiling6:
	lms r0,(MVCount&$FFFF)	; Get Counter
	dec r0
	bmi _GCeiling9
;	from	r0				; Update Counter
	sbk
	lms r14,(MVSector&$FFFF)	; Get CeilingData Pointer
	inc r14
	move r10,r14	; R10 = CEILINGDATA
	to r6	; R6 = CEILINGSECTOR
	getb
	inc r14
	getb	; R5 = MAXIMUM CEILING HEIGHT
	inc r14
	to r5
	getbh
	with r14	; Get #Lines
	%add_i((rlpcsNumLines-(rlpcsMaxHeight+1)))
	getb
;	with	r0
	add r0
;	with	r0
	add r14
	iwt r15,#lo16(_RLAddPlatformCeiling)
;	from	r0				; Update CeilingData Pointer
	sbk
_GCeiling9:
	iwt r15,#lo16(_RM7XY1000)
	nop
