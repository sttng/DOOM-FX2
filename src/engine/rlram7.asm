	arch 65816
	; plist ON
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                                  RAM7 MEMORY (GSU) *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"

	; extern RAM7AStart,RAM7AEnd
	; extern RAM7BStart,RAM7BEnd
	; extern RAM7CStart,RAM7CEnd
	; extern RAM7DStart,RAM7DEnd

	; public _RLVClipZone


;
;	* * * * * * *       RAM7 SHORT PAGE VARIABLES       * * * * * * *
;
	%section(RAM7A)
RAM7AStart:
;
;	>>>   REALITY_ENGINE VARIABLES   <<<
;
SkillLevel:	%ds(1*2)	; 0=Easy,1=Med,2=Hrd,3=UltVio,4=Ngtmre
	if useHIGHDETAIL != 0
DetailLevel:	%ds(1*2)	; Level of Detail (0=HIGH,1=LOW)
	endif
RandomNumI:	%ds(1*2)	; Random Number Index
Timer1:	%ds(1*2)	; CountDown Timer for 1 second
Anim2Frame:	%ds(1)	; Anim2 FrameCounter
Anim4Frame:	%ds(1)	; Anim4 FrameCounter
FPSRatio:	%ds(1*2)	; FramesPerSecond Ratio
;
RLMinPixX:	%ds(1*2)	; Minimum PixX Coordinate
RLMaxPixX:	%ds(1*2)	; Maximum PixX Coordinate
	if useHIGHDETAIL != 0
RLMinPixX2:	%ds(1*2)	; Minimum PixX  (/2 if LOW)
RLMaxPixX2:	%ds(1*2)	; Maximum PixX  (/2 if LOW)
RLViewPixX2:	%ds(1*2)	; Maximum ViewPixX (/2 if LOW)
	endif
RLSin:	%ds(1*2)	; Sine Constant (90-PlayerAngle)
RLCos:	%ds(1*2)	; CoSine Constant (90-PlayerAngle)
RLNextCode:	%ds(1*2)	; Address of Next RLEngine Code
;
RLCount:	%ds(1*2)	; RLEngine Generation Counter
RLFrame:	%ds(1*2)	; RLEngine Total Frames
;
RLLineCount:	%ds(1*2)	; RLEngine Generation LineCounter


;
;	>>>   MESSAGE VARIABLES   <<<
;
MsgDataA:	%ds(1*2)	; MessageText
MsgDataB:	%ds(1*2)
MsgDataC:	%ds(1*2)
MsgCount:	%ds(1*2)	; Message Display Counter


;
;	>>>   VIEW VARIABLES   <<<
;
ViewX:	%ds(1*2)	; View X
ViewY:	%ds(1*2)	; View Y
ViewZ:	%ds(1*2)	; View Z
ViewAngle:	%ds(1*2)	; View Angle


;
;	>>>   PLAYER VARIABLES   <<<
;
PlayerJoyOld:	%ds(1*2)	; Player's Old JoyStick Bits
;
PlayerDead:	%ds(1*2)	; Player's Status
PlayerDeadOld:	%ds(1*2)	; Player's Previous Status
PlayerHeight:	%ds(1*2)	; Player's Height
PlayerOnGround:	%ds(1*2)	; Player is ON Ground!
;
PlayerSway:	%ds(1*2)	; Player's Sway Factor
;
PlayerFaceAnim0:	%ds(1*2)	; Pointer to "Normal" FaceAnim
PlayerFaceAnim:	%ds(1*2)	; Pointer to FaceAnim
PlayerFaceCount:	%ds(1*2)	; Counter for Current Face
;
RadCount:	%ds(1*2)	; Countdown for Radiation Suit
BerserkCount:	%ds(1*2)	; Countdown for Berserk
InvulnerableCount:	%ds(1*2)	; Countdown for Invulnerability
LightGoggles:	%ds(1*2)	; Countdown for Light Goggles
Berserk:	%ds(1*2)	; Berserk
ComputerMap:	%ds(1)	; ComputerMap
BackPack:	%ds(1)	; BackPack
PlayerHurt:	%ds(1)	; Player Hurt (SoundEffect)
	%ds(1)
;
NumItems:	%ds(1*2)	; Number of ITEMS
NumKills:	%ds(1*2)	; Number of KILLS
NumSecrets:	%ds(1*2)	; Number of SECRETS


;
;	>>>   WEAPON VARIABLES   <<<
;
WeaponData:	%ds(1*2)	; Address of WeaponData (wd)
WeaponState:	%ds(1*2)	; WeaponState (wdType)
WeaponStateData:	%ds(1*2)	; Address of WeaponStateData (ws)
WeaponStateCount:	%ds(1*2)	; #Cycles Left in Current State
WeaponXOffset:	%ds(1*2)	; X Offset
WeaponYOffset:	%ds(1*2)	; Y Offset
WeaponAmmo:	%ds(1*2)	; Address of Ammo (-1=Fist/ChainSaw)
WeaponBullets:	%ds(1*2)	; #Bullets (Pistol/ChainGun)
WeaponShells:	%ds(1*2)	; #Shells (ShotGun)
WeaponRockets:	%ds(1*2)	; #Rockets (Rocket)
WeaponCells:	%ds(1*2)	; #Cells (Plasma/BFG)
WeaponLight:	%ds(1)	; Light Created by Weapon
LightAdjust:	%ds(1)	; Light Adjustment (Weapons/LightGoggles)


;
;	>>>   AUTOMAP VARIABLES   <<<
;
AutoMapScale:	%ds(1*2)	; AutoMap Scaling Factor
AMLevelTextPtr:	%ds(1*2)	; Address of LevelText
AMObjX1:	%ds(1*2)	; Object Triangle X1
AMObjY1:	%ds(1*2)	; Object Triangle Y1
AMObjX2:	%ds(1*2)	; Object Triangle X2
AMObjY2:	%ds(1*2)	; Object Triangle Y2
AMObjX3:	%ds(1*2)	; Object Triangle X3
AMObjY3:	%ds(1*2)	; Object Triangle Y3
AMMObjPtr:	%ds(1*2)	; Pointer to MObjList


;
;	>>>   EPISODE/MISSION VARIABLES   <<<
;
EMNUM:	%ds(1*2)	; EPISODE.B / MISSION.B
;
EMBSP:	%ds(1*4)	; Pointer to BSP
EMBSPR:	%ds(1*2)	; Pointer to BSPROOT
EMAREAS:	%ds(1*2)	; Pointer to AREAS
EMVERTEXES:	%ds(1*2)	; Pointer to VERTEXES
EMLINES:	%ds(1*2)	; Pointer to LINES
EMSEGS:	%ds(1*2)	; Pointer to SEGS
EMSEGS2:	%ds(1*2)	; Pointer to SEGS2
EMREJECT:	%ds(1*2)	; Pointer to REJECT
EMNUMVERTEXES:	%ds(1*2)	; Number of VERTEXES
EMNUMLINES:	%ds(1*2)	; Number of LINES
EMNUMSEGS:	%ds(1*2)	; Number of SEGS
EMFACES:	%ds(1*2)	; Pointer to FACES
;
EMSECTORS:	%ds(1*4)	; Pointer to SECTORS
EMNUMSECTORS:	%ds(1*2)	; Number of SECTORS
EMOBJECTS:	%ds(1*2)	; Pointer to OBJECTS
EMBLOCKMAP:	%ds(1*2)	; Pointer to BLOCKMAP
EMDOORS:	%ds(1*2)	; Pointer to DOORS
EMSTAIRS:	%ds(1*2)	; Pointer to STAIRS
EMFLOORS:	%ds(1*2)	; Pointer to FLOORS
EMCEILINGS:	%ds(1*2)	; Pointer to CEILINGS
EMLIFTS:	%ds(1*2)	; Pointer to LIFTS
;
EMBLOCKMAPORIGIN:	%ds(1*4)	; BLOCKMAP X,Y Origin (X.W/Y.W)
EMBLOCKMAPDIM:	%ds(1*2)	; BLOCKMAP Dimensions (W.B/H.B)
;
EMTOTALITEMS:	%ds(1*2)	; Number of ITEMS
EMTOTALKILLS:	%ds(1*2)	; Number of KILLS
EMTOTALSECRETS:	%ds(1*2)	; Number of SECRETS


;
;	>>>   BUILD BSP VARIABLES   <<<
;
BBBSPPtr:	%ds(1*2)	; Saved BSP Pointer
BBBSPStack:	%ds(1*2)	; Saved BSP StackPointer
BBAreaPtr:	%ds(1*2)	; Saved AREA Pointer
BBSegCount:	; #BSP AREA SEGMENTS
BBAreaPtrP:	%ds(1*2)	; Saved AREA PointerPrevious
BBOutSightCode:	%ds(1*2)	; Address of OutSight Code
BBInSightCode:	%ds(1*2)	; Address of InSight Code


;
;	>>>   SEGMENT LIST VARIABLES   <<<
;
SLAreaPtr:	%ds(1*2)	; Pointer to Start of AREA List
SLAreaPtrP:	%ds(1*2)	; Pointer to Previous AREA Group
SLAreaPtrV:	%ds(1*2)	; Pointer to Last Valid AREA Group
SLAreaSegCount:	%ds(1*2)	; Counter of Segments in AREA
;
SLClipZoneStart:	%ds(1*2)	; ClipZone Start
SLClipZoneEnd:	%ds(1*2)	; ClipZone End
SLClipCount:	%ds(1*2)	; #Clipped PixelStrips
SLV1Angle:	%ds(1*2)	; Segment Vertex1 Angle
;
SLXsRatioI:	%ds(1*2)	; ScreenXRatioIndex (rXs3-rXs0+1)
;
SLVSecPtr:	%ds(1*2)	; Pointer to End of VSECTORS List


;
;	>>>   VISIBLE SEGMENT LIST VARIABLES   <<<
;
VSegListEnd:	%ds(1*2)	; End of VisibleSegmentList
VSegMaxY:	%ds(1*2)	; Maximum VisibleSegment WorldY


;
;	>>>   VISIBLE OBJECT LIST VARIABLES   <<<
;
VObjListStart:	%ds(1*2)	; Start of VisibleObjectList
VObjListEnd:	%ds(1*2)	; End of VisibleObjectList
VObjListMaxY:	%ds(1*2)	; VisibleObject with Maximum Y
VObjMaxY:	%ds(1*2)	; Maximum VisibleObject Y
;
VObjSectorData:	%ds(1*2)	; VisibleObject SectorData
VObjZ:	%ds(1*2)	; VisibleObject Z Coordinate
VObjHeight:	%ds(1)	; VisibleObject Height
VObjWidth:	%ds(1)	; VisibleObject Width
VObjImage:	%ds(1*2)	; Pointer to Imagery


;
;	>>>   TRACE VARIABLES   <<<
;
;	(this port) Some are free while the BSP is walked and hold its chunk state
;	(rlbsp.asm): TRPreWallPlotPtr0 = end of the chunk, TRClipRangePtr0 = the
;	AREA entry being added, TRClipRangePtr = segment passes run (0/1/2),
;	TRXsT = 1: walk to resume, TRCeilingY/TRYs0 = its BSP pointer/stack.
;
TRVSeg:	%ds(1*2)	; Pointer to Current VisibleSegment
TRVObj:	%ds(1*2)	; Pointer to Current VisibleObject
;
TRFloors:	%ds(1*2)	; Start of FloorsData
TRFloorsEnd:	%ds(1*2)	; End of FloorsData
TRFloorKey:	%ds(1*2)	; Current FloorKey
TRCeilingKey:	%ds(1*2)	; Current CeilingKey
TRFloorCeilingKey:	%ds(1*2)	; Key for Floor/Ceiling Data
TRFloorsPtr0:	%ds(1*2)	; Start of Current FloorsData (rltracef.asm: the floors' limit)
;
TRPixScale:	%ds(1*2)	; SCN->RL Pixel Scale
TRTextureHeight:	%ds(1)	; Height of Texture
	%ds(1)	; UNUSED!
;
TRPreWallPlotPtr0:	%ds(1*2)	; Pointer to End of PreWallPlotData
TRPreWallPlotPtr:	%ds(1*2)	; Pointer to Current PreWallPlotData
TRWallPlotPtr:	%ds(1*2)	; Pointer to End of WallPlotData
TRObjPlotPtr:	%ds(1*2)	; Pointer to End of ObjPlotData
;
TRWallPlot:	%ds(1*2)	; Pointer to Current WallPlots
TRClipRangePtr0:	%ds(1*2)	; Pointer to Current ClipRange
TRClipRangePtr:	%ds(1*2)	; Pointer in Current ClipRange
TRClipZonePtr0:	%ds(1*2)	; Pointer to Current ClipZone
TRClipZonePtr:	%ds(1*2)	; Pointer in Current ClipZone
;
TRXsT:	%ds(1*2)	; Current X/#Pixels Left
TRYs0:	%ds(1*2)	; Y Coordinate at Bottom of Wall
TRCeilingY:	%ds(1*2)	; Y Coordinate at Ceiling
;
TRFloorPlotPtr:	%ds(1*2)	; Pointer to End of FloorPlotData


;
;	>>>   DRAW WALLS VARIABLES   <<<
;
DWPlotPtr:	%ds(1*2)	; Pointer to Next PlotDataStart


;
;	>>>   MOVEMENT VARIABLES   <<<
;
MVReturnAddress:	%ds(1*2)	; Return Address
MVRObj:	%ds(1*2)	; RLObject Pointer
MVRX:	%ds(1*2)	; RLObject X Coordinate
MVRY:	%ds(1*2)	; RLObject Y Coordinate
;
MVULMask:	%ds(1)	; LineFlag Mask for Trigger/Use/Operate
MVULCount:	%ds(1)	; #Lines that match LineFlag Mask
;
MVObjD:	%ds(1*2)	; Object Diameter
MVCount:	%ds(1*2)	; Movement Remainder ReScan Count
MVMLPtr:	%ds(1*2)	; MoveLines Pointer
MVLine:	%ds(1*2)	; Line Pointer/Item RLObject
MVVX:	%ds(1*2)	; Velocity X
MVVY:	%ds(1*2)	; Velocity Y
MVVZ:	%ds(1*2)	; Velocity Z (Projectiles Only)
;
MVLRX:	%ds(1*2)	; Line UnitVector Radius X
MVLRY:	%ds(1*2)	; Line UnitVector Radius Y
MVLPRX:	%ds(1*2)	; Line Perpendicular Radius X
MVLPRY:	%ds(1*2)	; Line Perpendicular Radius Y
MVLPUX:	%ds(1*2)	; Line Perpendicular UnitVector X
MVLPUY:	%ds(1*2)	; Line Perpendicular UnitVector Y
;
MVIPercent:	%ds(1*2)	; Intersection Percentage
MVIPUX:	%ds(1*2)	; Intersection Perp. UnitVector X
MVIPUY:	%ds(1*2)	; Intersection Perp. UnitVector Y
MVIZ:	%ds(1*2)	; Intersection Near Z
MVIZ2:	%ds(1*2)	; Intersection Near Z2
;MVIZ2S			ds.w	1		; Intersection Near Z2 Start
MVIC2:	%ds(1*2)	; Intersection Near C2
;MVIC2S			ds.w	1		; Intersection Near C2 Start
MVIMLPtr:	%ds(1*2)	; Intersection MoveLines Pointer
;
MVBlock:	; Line Blocks Movement IF Crossed
MVType:	%ds(1)	; Type of Line
MVTag:	%ds(1)	; Line Tag Value
MVSector:	%ds(1*2)	; Pointer to Sector Triggered
MVCode:	%ds(1*2)	; Code to call for each Sector
;
MVIMask:	%ds(1)	; ObjectFlag Mask for Collisions
	%ds(1)


;
;	>>>   USE LINES VARIABLES   <<<
;
ULReturnAddress:	%ds(1*2)	; Return Address
ULObjX0:	%ds(1*2)	; Object Top-Left
ULObjY0:	%ds(1*2)
ULObjX1:	%ds(1*2)	; Object Bottom-Right
ULObjY1:	%ds(1*2)
;
ULLine:	%ds(1*2)	; Pointer to Line Used/Operated
ULType:	%ds(1)	; Type of Line
ULTag:	%ds(1)	; Line Tag Value
ULSector:	%ds(1*2)	; Pointer to Sector Used/Operated
ULCount:	%ds(1*2)	; Counter
ULCode:	%ds(1*2)	; Code to call for each Sector

;
;	>>>   TASKS VARIABLES   <<<
;
RLNumTasks:	%ds(1*2)	; Number of Allocated Tasks

;
;	>>>   CHECK CEILINGS/FLOORS VARIABLES   <<<
;
CeilingCrush:	%ds(1)	; 1=Ceiling Crushes RLObject(s)
CeilingBlocked:	%ds(1)	; 1=Ceiling Blocked by RLObject(s)
CCDestHeight:	%ds(1*2)	; Destination Floor/Ceiling Height
CCRadius:	%ds(1*2)	; Radius to Check for Player
CCReturnAddress:	%ds(1*2)	; Return Address

;
;	>>>   MOVABLE OBJECTS VARIABLES   <<<
;
RLNumMObjs:	%ds(1*2)	; Number of Allocated MovableObjects
RLNumPMObjs:	%ds(1*2)	; Number of Processing MovableObjects
RLNumPObjs:	%ds(1*2)	; Number of Projectile MovableObjects

;
;	>>>   ENEMIES VARIABLES   <<<
;
ENEnemy:	%ds(1*2)	; Pointer to Current Enemy
ENTObj:	%ds(1*2)	; Pointer to Current Target RLObject
ENBirthsPtr:	%ds(1*2)	; Enemy Births Pointer

;
;	>>>   RADIUS DAMAGE VARIABLES   <<<
;
ENRadiusPtr:	%ds(1*2)	; Radius Damages Pointer
ENRadiusLine:	%ds(1*2)	; Radius Line#

;
;	>>>   MOVE OBJECTS VARIABLES   <<<
;
MOReturnAddress:	%ds(1*2)	; Return Address

;
;	>>>   TARGETTING VARIABLES   <<<
;
TGZ:	%ds(1*2)	; Object Z Coordinate
TGdZUpper:	%ds(1*2)	; Upper DeltaZ Bounds
TGdZLower:	%ds(1*2)	; Lower DeltaZ Bounds



;
;	* * * * * * *       PATCH VARIABLES       * * * * * * *
;
;
;	>>>   MISCELLANEOUS VARIABLES   <<<
;
BaronOfHellCount:	%ds(1)	; BaronOfHell Counter (E1M8 Special)
BirthAngleOfs:	%ds(1)	; (this port, DOOM II) next birth's angle: 1 = +ANG90/8, -1 = -ANG90/8
;
;	* * * * * * *       MULTIPLAYER VARIABLES       * * * * * * *
;
	if useMULTIPLAYER != 0
MPPlayerObject:	%ds(1*2)	; Player Object
MPEnemyTarget:	%ds(1*2)	; Enemy Target
	endif
;
;	* * * * * * *       PATCH VARIABLES       * * * * * * *
;
	if usePATCH != 0
PTRLDoTasks:	%ds(1*2)	; _RLDoTasks
PTRLMSObjects:	%ds(1*2)	; _RLMSObjects
PTRLMAObjects:	%ds(1*2)	; _RLMAObjects
PTRLEnemiesTarget:	%ds(1*2)	; _RLEnemiesTarget
PTRLPlayer:	%ds(1*2)	; _RLPlayer
PTRLWeapons:	%ds(1*2)	; _RLWeapons
PTRLDoSectors:	%ds(1*2)	; _RLDoSectors
PTRLMisc2:	%ds(1*2)	; _RLMisc2
PTRLBuildBSP:	%ds(1*2)	; _RLBuildBSP
PTRLBuildDone:	%ds(1*2)	; _RLBuildDone
;
PTRLBuildCheckObjs:	%ds(1*2)	; _RLBuildCheckObjs
PTRLFireTarget:	%ds(1*2)	; _RLFireTarget
PTRLFireTarget2:	%ds(1*2)	; _RLFireTarget2
PTRLDamageObject:	%ds(1*2)	; _RLDamageObject
;
PTRLMAPlayerDie:	%ds(1*2)	; _RLMAPlayerDie
PTTRO2SPlayer:	%ds(1*2)	; _RLBuildTraceObjs2Player
;
	if 1 != 0
PTRAM7A:	; PatchVariables (32 bytes; this port uses all of them for the variables below)
DWBandX:	%ds(2)	; Draw walls: X of the current 8-pixel band
DWMinY:	%ds(2)	; Draw walls: lowest Y drawn in the band
DWMaxY:	%ds(2)	; Draw walls: highest Y drawn in the band (-1 = none)
NVSector:	%ds(2)	; Sector the BSP visibility bits were built for (-1 = rebuild)
MouseTurn:	%ds(2)	; Mouse turn for this frame (angle units, from the CPU; 0 after use)
NMX:	%ds(2)	; Nightmare respawn: spawn point X
NMY:	%ds(2)	; Nightmare respawn: spawn point Y
NMAngle:	%ds(2)	; Nightmare respawn: spawn angle
NMCount:	%ds(2)	; Nightmare respawns so far (for tests)
NMFast:	%ds(2)	; 0 = Nightmare (fast monsters) this frame
NMFastShot:	%ds(2)	; 0 = the fireball being born is fast
DWBandBase:	%ds(2)	; Draw walls: band buffer column of the current strip
MVOVX:	%ds(2)	; Player move: the frame's velocity X (rlmove4 stairstep)
MVOVY:	%ds(2)	; Player move: the frame's velocity Y
MVStair:	%ds(2)	; Player move: stairstep stage (0 = none tried)
PlayerFallV:	%ds(2)	; Player's fall speed (8.8 units per PC tic; 0 = on the ground)
	endif
	endif
;
;	* * * * * * *       VARIABLE BLOCK TRANSFERRED TO SNES       * * * * * * *
;
RLGSUXVars:
	if !DEBUG != 0
GSUERROR:	%ds(1*2)	; GSU ERROR CODE
	endif
;
PlayerAmmo:	%ds(1*2)	; Player's Ammo
PlayerHealth:	%ds(1*2)	; Player's Health
PlayerArmor:	%ds(1*2)	; Player's Armor
PlayerFace:	%ds(1*2)	; Player's Face
PlayerKeys:	%ds(1)	; Player's Keys
PlayerArms:	%ds(1)	; Player's Weapons
;
RLRGB:	%ds(1*2)	; Current Desired RGB
;
WeaponType:	%ds(1*2)	; Type of Weapon (wtType)
WeaponFrame:	%ds(1*2)	; Weapon Frame
WeaponX:	%ds(1*2)	; Weapon Sprite X Coordinate
WeaponY:	%ds(1*2)	; Weapon Sprite Y Coordinate
WeaponNext:	%ds(1*2)	; Next Selected Weapon (wtType)
;
AutoMapMode:	%ds(1*2)	; -1 = AUTOMAP ON
ExitLevel:	%ds(1*2)	; 11=Next,51=Secret,-1=ReStart,-2=Died,$xx52=New(level $xx),$4C=Load
InvisibleCount:	%ds(1*2)	; Countdown for Invisibility
;
RLNumSounds:	%ds(1*2)	; #Sound Effects to Process

	if !DEBUGSCR != 0
DebugScreen:	%ds(1*2)	; 0=DEBUG OFF,1=DEBUG ON
DebugPlayerX:	%ds(1*4)
DebugPlayerY:	%ds(1*4)
DebugPlayerA:	%ds(1*2)
;
DebugPlayerS:	%ds(1*2)
DebugPlayerZ:	%ds(1*2)
;
DebugClipZonePtrA:	%ds(1*2)
DebugPreWallPtrA:	%ds(1*2)
DebugWallPlotPtrA:	%ds(1*2)
DebugFloorPlotPtrA:	%ds(1*2)
DebugObjPlotPtrA:	%ds(1*2)
DebugFloorsSizeA:	%ds(1*2)
;
DebugClipZonePtrB:	%ds(1*2)
DebugPreWallPtrB:	%ds(1*2)
DebugWallPlotPtrB:	%ds(1*2)
DebugFloorPlotPtrB:	%ds(1*2)
DebugObjPlotPtrB:	%ds(1*2)
DebugFloorsSizeB:	%ds(1*2)
;
DebugClipZonePtrC:	%ds(1*2)
DebugPreWallPtrC:	%ds(1*2)
DebugWallPlotPtrC:	%ds(1*2)
DebugFloorPlotPtrC:	%ds(1*2)
DebugObjPlotPtrC:	%ds(1*2)
DebugFloorsSizeC:	%ds(1*2)
;
DebugVSegSize:	%ds(1*2)
DebugVObjSize:	%ds(1*2)
DebugBSPPtr:	%ds(1*2)
DebugRLNumTasks:	%ds(1*2)
DebugRLNumMObjs:	%ds(1*2)
DebugVSecNum:	%ds(1*2)
;
DebugEnemyTargets:	%ds(1*2)
DebugEnemyMoves:	%ds(1*2)
DebugEnemyAttacks:	%ds(1*2)
DebugEnemyBirths:	%ds(1*2)
DebugProjectileMoves:	%ds(1*2)
	endif
;
RLGSUXVarsE:

;
;	* * * * * * *       VARIABLE BLOCK TRANSFERRED FROM SNES       * * * * * * *
;
RLGSUSNESXVars:
	%ds(12)	; ds.b (RLSNESXVarsE-RLSNESXVars)
	assert 12 == (RLSNESXVarsE-RLSNESXVars), "cached ds size is stale (tools/fixup.py)"
	RLGSUSNESXVarsO = $6FFADE	; to get SNES from GSU
	assert (RLGSUSNESXVarsO&$FFFFFF) == ((RLGSUSNESXVars-RLSNESXVars)&$FFFFFF), "cached constant RLGSUSNESXVarsO is stale (tools/fixup.py)"
;
;	>>>   MORE SHORT PAGE VARIABLES (this port)   <<<
;
PVSRow:	%ds(2)	; Address of the player's sector visibility row (level RAM image in GSU RAM $71, or ROM: see EMBSP+3)
TRObjFuzz:	%ds(2)	; 1 = the VObj being traced is drawn as a shadow (Spectre)
ULStairStep:	%ds(2)	; Stair step height (8, or 16 for the Ultimate DOOM turbo stairs)
	assert pc()&$FFFF <= $200, "RAM7A must stay in the lms/sms page"
;
;	* * * * * * *       RAM7 SHORT PAGE VARIABLES END       * * * * * * *
;
RAM7AEnd:



;
;	* * * * * * *       RAM7 MEDIUM PAGE VARIABLES       * * * * * * *
;
	%section(RAM7B)
RAM7BStart:
_RLSlopeYInvTable:	%ds(RLViewPixY*2)	; Slope Y Inverse Table
RLGSUSounds:	%ds((MaxRLSounds*rlseSize))	; GSU Sound Effects Table
RLNumRumbles:	%ds(1*2)	; (this port) #Rumble requests (rumble.asm), then
RLGSURumbles:	%ds(MaxRLRumbles)	;  the requests (copied with the count)
RLRumbleTemp:	%ds(2)	; _RLAddRumble: the request
_RLProjectileMoves:	%ds(((MaxRLMoveProjectiles+1))*2)	; Moving Projectiles
_RLProjectileMovesE:

;	org $700340
	if usePATCH != 0
PTRAM7B:	%ds(64)
	endif
;


RAM7BEnd:


;
;	* * * * * * *       RAM7 CHARDEF MEMORY       * * * * * * *
;
	%section(RAM7C)
RAM7CStart:
_RLGSUChrDef:	;ds.b	(RLCharX/3*20*64)			 ; Draw ChrDef
	_RLGSUChrDefEnd = $703080
	assert (_RLGSUChrDefEnd&$FFFFFF) == ((_RLGSUChrDef+(RLCharX/3*20*64)-((20-RLViewCharY)*64))&$FFFFFF), "cached constant _RLGSUChrDefEnd is stale (tools/fixup.py)"
	RAM7CEnd = _RLGSUChrDefEnd


;
;	* * * * * * *       RAM7 UNUSED CHARDEF MEMORY       * * * * * * *
;
	RAM7CnSIZE = ((20-RLViewCharY)*64)

	%section(RAM7C0)
RAM7C0Start:
SingleBitArray:	%ds(8)	; Single Bit Array
RAM7C0End:
	assert RAM7C0End-RAM7C0Start <= ((20-RLViewCharY)*64), "RAM7C0 overflows its screen buffer hole"

	%section(RAM7C1)
RAM7C1Start:
_RLMoveSectors:	; Movement Sectors List
_RLCheckObjs:	%ds(((63+1))*2)	; CheckFloor/CheckCeiling Objects
RAM7C1End:

	%section(RAM7C2)
RAM7C2Start:
_RLUseLines:	%ds(((MaxRLUseLines+1))*2)	; Maximum Use Lines
RAM7C2End:

	%section(RAM7C3)
RAM7C3Start:
_RLEnemyTargets:	%ds(((MaxRLTargetEnemies+1))*2)	; Targetting Enemies
_RLEnemyTargetsE:
_RLEnemyMoves:	%ds(((MaxRLMoveEnemies+1))*2)	; Moving Enemies
_RLEnemyMovesE:
RAM7C3End:
	assert RAM7C3End-RAM7C3Start <= ((20-RLViewCharY)*64), "RAM7C3 overflows its screen buffer hole"

	%section(RAM7C4)
RAM7C4Start:
PVSRowBuf:	%ds(32)	; (this port) Visibility row of the player's sector, copied from the level RAM image or the GamePak ROM
RAM7C4End:
	assert RAM7C4End-RAM7C4Start <= ((20-RLViewCharY)*64), "RAM7C4 overflows its screen buffer hole"

	%section(RAM7C5)
RAM7C5Start:
_RLEnemyAttacks:	%ds(((MaxRLAttackEnemies+1))*4)	; Attacking Enemies
_RLEnemyAttacksE:
AMLevelText:	%ds((((RLCharX+3+1)/2))*2)	; Overlay ASCII Text
RAM7C5End:
	assert RAM7C5End-RAM7C5Start <= ((20-RLViewCharY)*64), "RAM7C5 overflows its screen buffer hole"

	%section(RAM7C6)
RAM7C6Start:
_RLEnemyBirths:	%ds((MaxRLBirthEnemies+1)*6)	; Birthing Enemies
RAM7C6End:
	assert RAM7C6End-RAM7C6Start <= ((20-RLViewCharY)*64), "RAM7C6 overflows its screen buffer hole"

	%section(RAM7C7)
RAM7C7Start:
_RLRadiusDamages:	%ds((MaxRLRadiusDamages+1)*6)	; Radius Damages
_RLRadiusDamagesE:
RAM7C7End:
	assert RAM7C7End-RAM7C7Start <= ((20-RLViewCharY)*64), "RAM7C7 overflows its screen buffer hole"


;
;	* * * * * * *       REGULAR RAM7 VARIABLES       * * * * * * *
;
	%section(RAM7D)
RAM7DStart:
;
;	>>>   THE FOLLOWING BLOCKS ARE ORDER/SIZE SPECIFIC !!!   <<<
;
_RLSectorData:	%ds((MaxRLSectors*rlsdSize))	;!MUST BE FIRST! ; Sector Data Block
;
;	The objects come next: they must end below $8000 (the enemy code tests
;	object pointers with bmi), so they sit below the vertex table and the
;	line arrays, whose size depends on the levels.  Movable objects are
;	followed directly by the fixed ones (the radius damage walk runs from
;	_RLMObjects to _RLObjectsE).
;
PlayerObject:	; Player's Object
	assert (pc()&1) == 0, "GSU RAM objects must be word aligned (ldw/stw)"
_RLMObjects:	%ds((MaxRLMObjects*rloSize))	; Movable Objects
_RLMObjectsE:
_RLObjects:	%ds((MaxRLFObjects*rloSize0))	; Fixed Objects
_RLObjectsE:
;
_RLVertexes:	%ds(MaxRLVertexes*4)	; Rotated Vertexes
	assert (_RLVertexes&$FFFF) == !RLVERTEXBASE, "_RLVertexes moved: rebuild the level data (tools/fx3_convert_levels.py --vbase / tools/wad2rl.py finalize)"
	assert (_RLVertexes&$FFFF) == ((_RLSectorData&$FFFF)+MaxRLSectors*rlsdSize+MaxRLMObjects*rloSize+MaxRLFObjects*rloSize0), "tools compute the vertex base as sectors + objects"

;
;	>>>   THE FOLLOWING BLOCKS ARE NOT SPECIFIC   <<<
;
_RLTextureXLatTable:
	%ds(filesize("data/RLDATA/WALLS/TEXTURE2.TBL"))	; ds.b <(RLTextureXLatTableE-RLTextureXLatTable)
	; TEXTURE->ALTTEXTURE
;
_RLTasks:	%ds((MaxRLTasks*rlmSize))	; Task Data
_RLTaskSpare:	%ds(rlmSize)	; (this port) where a task goes when the table is full
;
;	BSP visibility bits (this port; too many for the 128-byte screen buffer
;	holes).  Each table follows a copy of SingleBitArray: the bit masks are
;	read at <table>-8.
_RLSBA1:	%ds(8)	; Copy of SingleBitArray (bit masks) just before the NODE bits
_RLNodeVisBits:	%ds(MaxRLVisNodes/8)	; BSP NODE n can lead to a sector visible from the player's sector (bit n)
_RLSBA2:	%ds(8)	; Copy of SingleBitArray (bit masks) just before the AREA bits
_RLAreaVisBits:	%ds(MaxRLVisAreas/8)	; AREA a is in a sector visible from the player's sector (bit a)
;
_RLLineFlags:	%ds(MaxRLLines)	; Line Flags
_RLLineRLCounts:	%ds(MaxRLLines*2)	; RLEngine Count
;
_RLPlatTasks:	%ds((MaxRLMPlats*rlptSize))	; Platform Task Data
;
_RLToggleTasks:	%ds((MaxRLToggles*rlttSize))	; Toggle Task Data
;
_RLMObjs:	%ds(((MaxRLMObjects+1))*2)	; Movable Objects
;
RAM7DEnd:

;
;	>>>   RLENGINE RAM OVERLAY 1   <<<
;
	base RAM7DEnd
	; load RAM7DEnd
_RLTargetList:	;ds.b	((MaxRLVObjs+1)*6)		; Player TargetList

;
;	>>>   RLENGINE RAM OVERLAY 1   <<<
;
	base RAM7DEnd
	; load RAM7DEnd
_RLMoveLines:	;ds.b	((MaxRLMoveLines+1)*rlmlSize)	; Movement Lines Data

;
;	>>>   RLENGINE RAM OVERLAY 1   <<<
;
	base RAM7DEnd
	; load RAM7DEnd
_RLBSPStack:	; Stack for BSP (line-of-sight walks: enemies, radius damage; the render walk uses _RLRenderBSPStack, rlbsp.asm)

;
;	>>>   RLENGINE RAM OVERLAY 1   <<<
;
	base RAM7DEnd
	; load RAM7DEnd
_RLVSegList:	%ds((MaxRLVSegs*rlvSize))	; Visible Segment List
_RLVSegListE:
;
;	(this port) The visible sectors list: not in a 128-byte screen buffer hole
;	(63 sectors, original): views of large PC maps (E4M8) see more.  It lives
;	while the VSegs do.
;
_RLVSectors:	%ds(MaxRLVSectors*2)	; Visible Sectors List
_RLVSectorsE:	%ds(2)	; Last slot: the terminator
	if !RLMASKED
;
;	Masked middle textures (this port): the list (rlvsegs4.asm) and the
;	variables of drawing them with the objects (rltraceo.asm); live while
;	the VSegs do
;
_RLMaskList:	%ds(MaxRLMasks*rlmkSize)	; Masked Middle Texture List
_RLMaskListE:
TRMaskEnd:	%ds(2)	; End of the list
TRMaskN:	%ds(2)	; #Entries not drawn yet
TRMkRet:	%ds(2)	; Return address
TRMkVObj:	%ds(2)	; VObj being traced (0 = draw all the rest)
TRMkE:	%ds(2)	; Next entry
TRMkImg:	%ds(2)	; Image of the entry being drawn
TRMkZ:	%ds(2)	; World Z of its bottom
TRMkHW:	%ds(2)	; Height / Width-1
TRMkAng:	%ds(2)	; VSeg RSAngle
TRMkRSPD:	%ds(2)	; VSeg RSPDistance
TRMkVTO:	%ds(2)	; VSeg VTOffset
TRMkFOX:	%ds(2)	; VSeg FaceOffsetX
TRMkLMin:	%ds(2)	; Light: minimum level
TRMkLMax:	%ds(2)	; Light: maximum level
TRMkLRng:	%ds(2)	; Light: range
TRMkOld:	%ds(2)	; ObjPlotPtr before the ObjPlot
	endif
RAM7DEnd2:


;
;	>>>   RLENGINE RAM OVERLAY 2   <<<
;
	base RAM7DEnd2
	; load RAM7DEnd2
_RLClipZoneList:	%ds((MaxRLClipZones*rlczSize))	; ClipZone List
	%ds(0)	; ds.b (((*-$708000)>>31)*($708000-*))
	assert 0 == (((pc()-$708000)>>31)*($708000-pc())), "cached ds size is stale (tools/fixup.py)"
	; PAD TO $8000!
_RLAreaSegList:	;ds.b	((MaxRLVAreas*rlasSize)+(MaxRLSegs*rluSize)) ; Area/Segment List
_RLAreaSegListE:

;
;	>>>   RLENGINE RAM OVERLAY 2   <<<
;
	base RAM7DEnd2
	; load RAM7DEnd2
_RLVObjList:	%ds((MaxRLVObjs*rlqSize))	; Visible Object List
;
_RLWallPlots:	; Wall Plots
	if useHIGHDETAIL != 0
	%ds(((RLViewPixX/3))*2)
	endif
	if useHIGHDETAIL == 0
	%ds(((RLViewPixX/3/2))*2)
	endif
_RLClipRange:	; X Clipping Range
	if useHIGHDETAIL != 0
			;ds.w	(RLViewPixX/3)
	endif
	if useHIGHDETAIL == 0
			;ds.w	(RLViewPixX/3/2)
	endif
_RLFloorStart:	%ds((RLViewPixY+2))	; Y Drawing Starts

;
;	From here to _RLPlotDataEnd (this port): the WallPlots growing up while the
;	PreWallPlots grow down from the ClipZones (trace walls), then the ObjPlots,
;	then the Floors/Ceilings (trace floors: from the ObjPlot end, while the
;	ClipZones are still read), then the FloorPlots.
;	(No fixed floor array: DOOM II MAP14/MAP15 views need the room.)
;
_RLFloors:	; (only for the DEBUGSCR sizes: the Floors/Ceilings start after the ObjPlots)
_RLWalls:	; Wall PlotData
;
;	Wall band buffer (draw walls): 4 strips x RLViewPixY bytes, one byte per
;	low-detail strip pixel.  (This port: in bank $71 since the walls' colour
;	maps were copied there (RAMWALLCMAPS): the wall pixel loops read the
;	colour from RAM instead of switching the ROM bank twice a pixel.)  The
;	plot data above _RLWalls ends below _RLPlotDataEnd (checked by
;	_RLDrawWalls, never reached in any level, and _RLAddFloorPlot).
	_RLPlotDataEnd = $70FFF0	; (16 bytes left: the 16-bit pointers never wrap)
	_RLBandBuffer = RAMWALLCMAPS-(4*RLViewPixY)	; (this port: in bank $71, below the walls' colour maps)
	assert _RLBandBuffer == RAMIMAGEEND, "savegame.inc RAMIMAGEEND: the band buffer starts there"
	assert RAMWALLCMAPS+(33*256) <= SAVEBASE, "the walls' colour maps run into the save area"

	_RLVClipZone = $710000	; VSeg ClipZones (grow down from the top of bank $70)


;
;	* * * * * * *       VARIOUS RANGE CHECKS AND WARNINGS       * * * * * * *
;
	assert ((_RLMObjectsE-$700000)>>15) == 0, "***  WARNING!  _RLMOBJECTS OVERFLOW!   ***"
	assert ((_RLAreaSegListE>>16)-$70) == 0, "***  WARNING!  _RLAREASEGLIST OVERFLOW!   ***"
