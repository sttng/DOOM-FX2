	arch 65816
;**********************************************************************
;*                                                                    *
;*                  P R O J E C T :   REALITY_ENGINE                  *
;*                                                                    *
;*                      OBJECT HANDLING MODULE 1                      *
;*                                                                    *
;*                    LEVEL OBJECT INITIALIZATION                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/snesmac.inc"


	; public _RLInitObjects


	%section(LEVEL)

;
;	* * * * * * *       REALITY_ENGINE INITIALIZE OBJECTS       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitObjects:
	rep #$30		; mode 'AX!'
	ldy.w #(MaxRLFObjects-1)	; ALL Fixed RLObjects are FREE
	ldx.w #0
_RILO400:
	lda.w #0
	sta.l _RLObjects+rloFlags,x
	txa
	clc
	adc.w #rloSize0
	tax
	dey
	bpl _RILO400
;
;	>>>   SCAN LEVEL OBJECT LIST AND CREATE RLOBJECTS   <<<
;
	sep #$20		; mode 'a!'
	phb	; Save .DB
	lda.b #bank(_RLObjects)
	pha
	plb
	; dbr ^(_RLObjects)
;
	lda.b #0	; BARON OF HELL COUNTER (E1M8 SPECIAL)
	sta.w BaronOfHellCount
;
	lda.b #$71	; OBJECTS are in the level RAM image (GSU RAM $71)
	sta.b Temp4+2
;
;	>>>   GET SKILLLEVEL MASK   <<<
;
	rep #$20		; mode 'A!'
	ldx.w SkillLevel	; 0=Easy,1=Med,2=Hard,3=UltraViolence,4=Nightmare
	lda.l RLObjSkillMask,x
	and.w #$00FF
	sta.b Temp4+6	; (TEMP4+6) = SKILLLEVEL MASK
;
;	>>>   COUNT LEVEL ITEM/KILL TOTALS   <<<
;
	stz.w EMTOTALITEMS	; Number of ITEMS
	stz.w NumItems
	stz.w EMTOTALKILLS	; Number of KILLS
	stz.w NumKills
;
;	>>>   MOVABLE OBJECT INDEX   <<<
;
	stz.b Temp3	; (TEMP3) = Index to _RLMObjs
;
;	>>>   START PROCESSING LEVEL OBJECTS   <<<
;
	lda.w #lo16(_RLObjects)	; (TEMP2) = Offset to _RLObjects
	sta.b Temp2
	lda.w #lo16(_RLMObjects)	; (TEMP2+2) = Offset to _RLMObjects
	sta.b Temp2+2
	lda.w EMOBJECTS	; Get Pointer to OBJECTS
;
;	>>>   PROCESS NEXT LEVEL OBJECT   <<<
;
_RILO2000:
	sta.b Temp4	; Save Updated Pointer to LevelObjects
;	ldy	#rlpFlags			; Flags/Type
	lda.b [Temp4]	; Any more Objects?
	bne _RILO2100	; Yes
	jmp.w _RILO9000	; NO!
;
;	>>>   LEVEL OBJECT PRESENT AT THIS SKILL LEVEL?   <<<
;
_RILO2100:
	bit.w #rlpfMultiPlayer	; MultiPlayer Mode Only?
	bne _RILO2180	; Yes!
	bit.b Temp4+6	; Object Present?
	bne _RILO2200	; YES!
_RILO2120:
	if useMULTIPLAYER == 0
_RILO2180:
	endif
	jmp.w _RILO8000	; NO!

	if useMULTIPLAYER != 0
;
;	>>>   MULTIPLAYER OBJECT   <<<
;
_RILO2180:
	jmp.w _RILO8000	; NO!
	nop
	endif

;
;	>>>   FIXED OR MOVABLE OBJECT?   <<<
;
_RILO2200:
	pha	; Save Flags/Type
	bit.w #rlpfMovable	; MOVABLE/FIXED?
	beq _RILO2500	; FIXED
	ldx.b Temp2+2	; MOVABLE
	cpx.w #lo16(_RLMObjectsE-(16*rloSize))	; Too Many MOVABLE Objects?
	bne _RILO2600
	bra _RILO2550	; YES!
_RILO2500:
	ldx.b Temp2	; FIXED
	cpx.w #lo16(_RLObjectsE)	; Too Many FIXED Objects?
	bne _RILO2600
_RILO2550:
	if (0*!DEBUG) != 0
	%HALT($30)	; YES!!!  ERROR!!!
	endif
	pla
	jmp.w _RILO8000	; YES!
;
;	>>>   LINK THIS RLOBJECT INTO A SECTOR   <<<
;
_RILO2600:
	and.w #(($FF<<8)|(rlpfMovable|rlpfActive|rlpfSolid|rlpfTarget))
	sta.b Temp+4
;
;	>>>   DOES THIS OBJECT COUNT FOR ITEM/KILL TOTALS?   <<<
;
	lda.b 1,s	; Get Flags/Type
	phx	; Save Index
	xba	; Get Type
	and.w #$00FF
	asl a
	tax
	lda.l _ObjDataO,x	; Get _ObjData Offset
	tax
	lda.l _ObjData+rlodHeight,x	; Get _ObjData Height
	and.w #$00FF
	sta.b Temp+2
	lda.l _ObjData+rlodFlags,x	; Get _ObjData Flags
	sta.b Temp
;
	bit.w #rlodfItemCount	; Is Object an "ITEM"?
	beq _RILO2700
	inc.w EMTOTALITEMS	; Number of ITEMS++
_RILO2700:
	bit.w #rlodfKill	; Is Object a "KILL"?
	beq _RILO2800
	inc.w EMTOTALKILLS	; Number of KILLS++
_RILO2800:
;
	plx	; Restore Index
	lda.b Temp	; Add _ObjData Flags
	and.w #rlodfItem
	ora.b Temp+4
	sta.w RAM7AStart+rloFlags,x	; Flags/Type
	ldy.w #rlpX	; X Coordinate
	lda.b [Temp4],y
	sta.l sfxR7
	ldy.w #rlpY	; Y Coordinate
	lda.b [Temp4],y
	sta.l sfxR8
;
	lda.w #lo16(__RLGetXYSectorData)	; Call GSU to Find SectorData
	jsl.l __RLCallGSU
;
	lda.l sfxR9	; Get SECTORDATA
	tay
	lda.w RAM7AStart+rlsdObjects,y	; Get SectorData.FirstObject
	pha
	txa
	sta.w RAM7AStart+rlsdObjects,y	; SectorData.FirstObject = NewObject
;
	ply	; .Y = FirstObject
	beq _RILO3200	; No FirstObject!
	sta.w RAM7AStart+rloPrev,y	; FirstObject.Previous=NewObject
_RILO3200:
	tya
	sta.w RAM7AStart+rloNext,x	; NewObject.Next = FirstObject
	stz.w RAM7AStart+rloPrev,x	; NewObject.Previous = NULL
;
	lda.b Temp4	; LevelObject
	clc
	adc.w #rlpX
	sta.w RAM7AStart+rloLObj,x
;
;	>>>   FIXED OR MOVABLE OBJECT?   <<<
;
	pla	; Flags/Type
	bit.w #rlpfMovable	; MOVABLE OBJECT?
	bne _RILO5000	; YES!
;
	txa	; Move to next RLObject
	clc
	adc.w #rloSize0
	sta.b Temp2
	jmp.w _RILO8000

;
;	* * * * * * *       CREATE A MOVABLE RLOBJECT       * * * * * * *
;
_RILO5000:
	pha	; Save Type
	lda.l sfxR7	; X Coordinate
	sta.w RAM7AStart+rloX+2,x
	lda.l sfxR8	; Y Coordinate
	sta.w RAM7AStart+rloY+2,x
	stz.w RAM7AStart+rloX,x	; X Coordinate Fraction
	stz.w RAM7AStart+rloY,x	; Y Coordinate Fraction
	stz.w RAM7AStart+rloVX,x	; X Velocity
	stz.w RAM7AStart+rloVY,x	; Y Velocity
;
	lda.l sfxR6	; Sector
	sep #$20		; mode 'a!'
	sta.w RAM7AStart+rloSector,x
	rep #$20		; mode 'A!'
;
	lda.l sfxR9	; SectorData
	tay
	lda.b Temp	; ObjData Flags
	bit.w #rlodfFloat	; Does Object FLOAT?
	beq _RILO5300	; No
	lda.w RAM7AStart+rlsdFloorHeight,y	; Z Coordinate
	clc
	adc.w #32	; FLOATs 32 above the floor
	bra _RILO5400
_RILO5300:
	lda.w RAM7AStart+rlsdFloorHeight,y	; Z Coordinate
_RILO5400:
	sta.w RAM7AStart+rloZ,x	; Z Coordinate
	sta.w RAM7AStart+rloZ2,x	; Z2 Coordinate
	lda.w RAM7AStart+rlsdCeilingHeight,y	; C2 Coordinate
	sta.w RAM7AStart+rloC2,x
;
	ldy.w #rlpAngle	; Angle
	lda.b [Temp4],y
	sta.w RAM7AStart+rloAngle,x
;
	txy
	pla	; Get Type
	xba
	and.w #$00FF
	asl a
	tax
;
	inc.w RLNumMObjs	; NumMObjs++
;
;	>>>   GET MOVABLE OBJECT DATA   <<<
;
	lda.l RLMObjData,x	; MObjData
	sta.w RAM7AStart+rloMData,y
	tax
;
;	>>>   INITIALIZE MOBJ HEALTH   <<<
;
	lda.l +(bank(_MObjData)<<16)+rlmodHealth,x	; Health
	sta.w RAM7AStart+rloHealth,y
;
;	>>>   INITIALIZE MOBJ STATE MACHINE   <<<
;
	lda.l +(bank(_MObjData)<<16)+rlmodSleepS,x	; State
	beq _RILO7800	; NO STATE (PLAYER)
	sta.w RAM7AStart+rloState,y
;
;	>>>   INITIALIZE MOBJ ANIMATION STATE MACHINE   <<<
;
	lda.l +(bank(_MObjData)<<16)+rlmodSleepA,x	; Animation
	sta.w RAM7AStart+rloAnim,y
	tya	; StateCount (SLEEP0) = the object's address & $7F
	clc	; as at the original _RLMObjects base ($6332), so
	adc.w #($6332-lo16(_RLMObjects))&$007F	; monsters wake as they always did
	and.w #$007F	; Maximum of 127 ticks (2 secs.)
	xba
	sta.w RAM7AStart+rloAnimCount,y	; AnimCount/StateCount
;
;	>>>   INITIALIZE MOBJ ENEMY LOGIC   <<<
;
	lda.w #0	; No Target
	sta.w RAM7AStart+rloTObj,y
;
;	>>>   ADD MOVABLE OBJECT TO PROCESSING LIST   <<<
;
	ldx.b Temp3	; Get Index into _RLMObjs
	tya	; Save Pointer to RLObject
	dec a
	sta.w _RLMObjs,x
	inx
	inx
	stx.b Temp3
	inc.w RLNumPMObjs	; NumPMObjs++
;
;	>>>   FINISHED CREATING MOVABLE RLOBJECT   <<<
;
_RILO7800:
	lda.b Temp2+2	; Move to next RLMObject
	clc
	adc.w #rloSize
	sta.b Temp2+2
;
;	* * * * * * *       PROCESS NEXT LEVEL OBJECT       * * * * * * *
;
_RILO8000:
	ldy.w #rlpType	; Type
	lda.b [Temp4],y
	and.w #$00FF
	ldy.w #rlpSize0
	cmp.w #(otAngular+1)	; ANGULAR OBJECT?
	bcs _RILO8200	; NO!
	ldy.w #rlpSize	; YES!
_RILO8200:
	tya
	clc
	adc.b Temp4	; Next LEVEL Object
	jmp.w _RILO2000
;
;	* * * * * * *       FINISHED INITIALIZING LEVEL OBJECTS       * * * * * * *
;
_RILO9000:
	plb	; Restore .DB
	rts



;
;	* * * * * * *       TABLE OF MASK BITS FOR SKILL LEVEL       * * * * * * *
;
RLObjSkillMask:
	db rlpfSkill12,rlpfSkill12,rlpfSkill3,rlpfSkill45,rlpfSkill45


;
;	* * * * * * *       TABLE OF OFFSETS TO OBJECT DATA       * * * * * * *
;
_ObjDataO:
	!odo #= 0
	for __rep = 0..otMax
	dw !odo
	!odo #= !odo+rlodSize
	endfor


;
;	* * * * * * *       TABLE OF MOVABLE OBJECTS' DATA       * * * * * * *
;
RLMObjData:
	dw lo16(modPlayer)	; Player1 Start
	dw lo16(modPlayer)	; Player2 Start
	dw lo16(modPlayer)	; Player3 Start
	dw lo16(modPlayer)	; Player4 Start
	dw 0	; DeathMatch Start
	dw 0	; Teleport
	dw lo16(modSoldier)	; Soldier
	dw lo16(modSergeant)	; Sergeant
	dw lo16(modTrooper)	; Trooper
	dw lo16(modDemon)	; Demon
	if !RLSPECTRE != 0
	dw lo16(modDemon)	; Spectre (Invisible Demon): Demon's data, states and sounds
	endif
	dw lo16(modCacoDemon)	; CacoDemon
	dw lo16(modLostSoul)	; LostSoul
	dw lo16(modBaronOfHell)	; BaronOfHell
	dw lo16(modCyberDemon)	; CyberDemon
	dw lo16(modSpiderDemon)	; SpiderDemon
	if !RLDOOM2MONSTERS != 0
	dw lo16(modChainGunner)	; ChainGunner (DOOM II)
	dw lo16(modWolfSS)	; WolfSS
	dw lo16(modHellKnight)	; HellKnight
	dw lo16(modArachnotron)	; Arachnotron
	dw lo16(modMancubus)	; Mancubus
	dw lo16(modRevenant)	; Revenant
	dw lo16(modPainElemental)	; PainElemental
	dw lo16(modArchVile)	; ArchVile
	dw lo16(modKeen)	; Keen
	dw lo16(modBossBrain)	; BossBrain
	dw lo16(modBossShooter)	; BossShooter
	dw lo16(modBossTarget)	; BossTarget
	endif
	assert (((pc()-RLMObjData)/2)-(otMObj+1)) == 0, "***  WARNING!  RLMOBJDATA INVALID!   ***"
