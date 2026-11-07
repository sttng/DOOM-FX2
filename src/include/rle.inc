includeonce
	incsrc "levels.inc"	; data set limits (!RLMAX...)
	incsrc "savegame.inc"	; save game area (SAVEBASE)
	incsrc "rumble.inc"	; rumble effects (this port, rumble.asm)
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                   ENGINE STRUCTURE DEFINITIONS     *
;*                                                                    *
;**********************************************************************


;
;	* * * * * * *       DEFINITIONS       * * * * * * *
;
	RLCharX = 27	; #Characters Wide
	RLCharY = 22	; #Characters Tall
	RLPixX = RLCharX*8	; #Pixels Wide
	RLPixY = RLCharY*8	; #Pixels Tall
;
	RLStatStartPixX = ((256-RLPixX)/2)
	RLStatStartPixY = $A7
	assert (RLStatStartPixY&$FFFFFF) == ((RLVIntTop+(RLPixY-RLStatPixY))&$FFFFFF), "cached constant RLStatStartPixY is stale (tools/fixup.py)"
	RLStatCharX = 27	; #Characters Wide
	RLStatCharY = 4	; #Characters Tall
	RLStatPixX = RLStatCharX*8
	RLStatPixY = RLStatCharY*8
	RLStatEndPixY = RLStatStartPixY+RLStatPixY
;
	RLViewCharX = 27	; #Characters Wide
	RLViewCharY = 18	; #Characters Tall
	RLViewPixX = RLViewCharX*8	; #Pixels Wide
	RLViewPixY = RLViewCharY*8	; #Pixels Tall
;
	RLVIntTop = ((224-RLPixY)/2)-1	; Top Interrupt ScanLine
	RLVIntBottom = 224-((224-RLPixY)/2)-1	; Bottom Interrupt ScanLine
;
;	HInt = ( BorderRightStart - (TotalCycles To On/Off Display*2) - (IRQTime*2)+ Fudge )
;	       ( (256-((256-(RLPixX*8))/2)) - (50*2) - (8*2) + 10)
;
	RLHIntL = 96	; Left Interrupt HPos
	RLHIntR = 248	; 242		; Right Interrupt HPos


;
;	* * * * * * *       ENGINE MAXIMUMS       * * * * * * *
;
	MaxRLVertexes = !RLMAXVERTEXES	; *Maximum VERTEXES per Level (data set, levels.inc)
	MaxRLSectors = !RLMAXSECTORS	; *Maximum SECTORS per Level (data set, levels.inc)
;MaxRLAreas		equ	512			; Maximum AREA Nodes per Level
;MaxRLSegs		equ	2438			; Maximum SEGS per Level
	MaxRLLines = !RLMAXLINES	; *Maximum LINES per Level (data set, levels.inc)
;MaxRLFaces		equ	1440			; Maximum FACES per Level
;
	MaxRLTextures = 256	; Maximum TEXTURES
;
	MaxRLFObjects = 180	; 160		; *Maximum FIXED OBJECTS per Level
	if defined("RLMAXMOBJECTS")
	MaxRLMObjects = !RLMAXMOBJECTS	; *Maximum MOVABLE OBJECTS per Level (data set, levels.inc:
	else	; the most any level has on one skill + 16 for projectiles; 116 = FX3, original: 100)
	MaxRLMObjects = 116
	endif
	assert MaxRLMObjects >= 116 && MaxRLMObjects <= 300, "MaxRLMObjects: 116..300 (FX3: 116, DOOM II MAP10 UV: 296)"
	MaxRLObjectTypes = 256	; Maximum OBJECT Types
	MaxRLImages = 256	; Maximum IMAGES
;
	RLScreenPlane = 4	; Distance from Eye to ScreenPlane
	RLAspectRatio = $00014000	; AspectRatio (%Increase in Y)
	RLMaxViewDistance = 7168	; Maximum Viewing Distance
	if useHIGHDETAIL == 0
	MaxRLClipZones = (RLViewPixX/2/(2+1))	; Maximum CLIPZONES (2SOLID+1BLANK)
	endif
	if useHIGHDETAIL != 0
	MaxRLClipZones = (RLViewPixX/(2+1))	; Maximum CLIPZONES (2SOLID+1BLANK)
	endif
;
	MaxRLVSegs = 168	; 160		; Maximum Visible Segments
;MaxRLVAreas		equ	256			; Maximum Visible Areas
	MaxRLVSectors = (128-1)	; Maximum Visible Sectors (original: 64-1)
	MaxRLVisNodes = 1664	; Maximum BSP NODES per Level (visibility bits _RLNodeVisBits, rlram7.asm)
	MaxRLVisAreas = 1664	; Maximum AREAS per Level (visibility bits _RLAreaVisBits)
	MaxRLVObjs = 28	; 32			; Maximum Visible Objects
;
	MaxRLTasks = 48	; 64			; Maximum TASKS
;
;MaxRLMoveLines		equ	(64-1)			; Maximum Lines Checked when Moving
	MaxRLUseLines = (64-1)	; Maximum Lines Checked to Use/Operate
;
	MaxRLMPlats = 48	; 64			; Maximum Movable Platforms
	MaxRLToggles = 12	; Maximum Toggles
;
	MaxRLSounds = 8	; Maximum Sound Effects
;
;MaxRLEnemies		equ	MaxRLMObjects		; Maximum Enemies
	MaxRLTargetEnemies = 24	; Maximum Targetting Enemies
	MaxRLMoveEnemies = 24	; Maximum Moving Enemies
	MaxRLAttackEnemies = 20	; Maximum Attacking Enemies
	MaxRLBirthEnemies = MaxRLAttackEnemies	; Maximum Birthing Enemies
	MaxRLMoveProjectiles = 24	; Maximum Moving Projectiles
	MaxRLRadiusDamages = 14	; Maximum Radius Damages

	RLMaxCutSprOAMs = (128-(3+8+12+3+3+3))	; Max CutSpriteOAMs (96)
;RLMaxCutSprCHRs	equ	(512-((vmWEAPONDEF&$1fff)>>4))	; Max CutSpriteCHRs (168)
	RLMaxCutSprCHRs = RLMaxCutSprOAMs
;
	RLMaxCharDefXFer = 1024	; Maximum .CHARDEF Bytes per XFer


;
;	* * * * * * *       VRAM MEMORY MAP       * * * * * * *
;
	!vm #= 0
	vmCHR1 = !vm
	vmCHRA = !vm	; CHAR Set "A"
	!vm #= !vm+((RLCharX/3)*RLViewCharY*(64/2))
	vmCHRB = !vm	; CHAR Set "B"
	!vm #= !vm+((RLCharX/3)*RLViewCharY*(64/2))
	vmCHRC = !vm	; CHAR Set "C" (COMMON)
	!vm #= !vm+((RLCharX/3)*RLViewCharY*(64/2))
	vmCHRD = !vm	; CHAR Set "D" (SWAP A)
	!vm #= !vm+((RLCharX/3)*RLViewCharY*(64/2))
	vmCHRE = !vm	; CHAR Set "E" (SWAP B)
	!vm #= !vm+((RLCharX/3)*RLViewCharY*(64/2))
;
	vmCHR2 = ((!vm>>12)<<12)	; CHR2 Base ($6000)
	vmSPR = ((!vm>>13)<<13)	; SPRITES Base ($6000)
;
	vmSTATDEF = !vm	; CHAR Set "STATUS" ($6540)
	!vm #= !vm+((RLCharX*RLStatCharY)*(32/2))
;
	vmFACEDEF = !vm+((0+0)*32/2)	; CHAR Set "FACE" ($6c00)
;
	vmNUMDEF = !vm+((0+12)*32/2)	; CHAR Set "NUMBERS" ($6cc0)
;
	vmARMSDEF = !vm+((16+0)*32/2)	; CHAR Set "ARMS" ($6d00)
;
	vmKEYSDEF = !vm+((16+8)*32/2)	; CHAR Set "KEYS" ($6d80)
;
	vmCHR2B = !vm+((16+11)*32/2)	; CHAR Set "BLANK" ($6db0)
;
	!vm #= !vm+((16*4)*32/2)
;
	vmMAP1 = !vm	; MAP for VIEW0/1 ($7000)
	!vm #= !vm+(RLCharY*32*2/2)
	vmMAP2 = !vm-(4*32*2/2)	; MAP for STATUS ($7240)
	!vm #= !vm+((RLCharY-4)*32*2/2)
;
	vmWEAPONDEF = !vm	; CHAR Set "WEAPON" ($7500)
	!vm #= !vm+(RLMaxCutSprCHRs*(32/2))
;
	vmCHR2C = !vm	; CHAR Set "DEBUG" ($7b30)


;
;	* * * * * * *       REALITY_ENGINE FLAGS       * * * * * * *
;
	rlfPhasePending = $8000	; Phase Ended, Next Phase Pending
	rlfHalt = $4000	; RLEngine Halted
;rlfPause		equ	$2000			; RLEngine Pause
	rlfDraw = $0001	; Draw Built
	rlfStatus = $0002	; Status Built
	rlfWeaponOAM = $0004	; Weapon OAM Built
	rlfWeaponDEF = $0008	; Weapon DEF+OAM Built
	rlfDebugSCR = $0100	; Debugging Screen Built
	rlfDebug = $0200	; Debugging Screen Update
	rlfExchange = $1000	; Packets Exchanged


;
;	* * * * * * *       RGB PALETTE ANIMATION TAGS       * * * * * * *
;
	!rgbNone = (-1)	; No RGB Change
	rgbNormal = 0	; Normal RGB
	rgbRad = 2	; Radiation Suit
	rgbBerserk = 4	; Berserk PowerUp
	rgbPick = 6	; PickUp
	rgbHit = 8	; Player Hit


;
;	* * * * * * *       BSP TREE NODE STRUCTURE       * * * * * * *
;
	!rlb #= 0
	rlbLineY = !rlb	; Partition Line Y
	!rlb #= !rlb+2
	rlbDeltaX = !rlb	; Partition Line Delta X
	!rlb #= !rlb+2
	rlbLineX = !rlb	; Partition Line X
	!rlb #= !rlb+2
	rlbDeltaY = !rlb	; Partition Line Delta Y
	!rlb #= !rlb+2
	rlbLeftYMax = !rlb	; Left BoundaryBox Y Maximum
	!rlb #= !rlb+2
	rlbLeftYMin = !rlb	; Left BoundaryBox Y Minimum
	!rlb #= !rlb+2
	rlbLeftXMin = !rlb	; Left BoundaryBox X Minimum
	!rlb #= !rlb+2
	rlbLeftXMax = !rlb	; Left BoundaryBox X Maximum
	!rlb #= !rlb+2
	rlbLeftChild = !rlb	; Left Child, >=$8000 = AREA
	!rlb #= !rlb+2
	rlbRightYMax = !rlb	; Right BoundaryBox Y Maximum
	!rlb #= !rlb+2
	rlbRightYMin = !rlb	; Right BoundaryBox Y Minimum
	!rlb #= !rlb+2
	rlbRightXMin = !rlb	; Right BoundaryBox X Minimum
	!rlb #= !rlb+2
	rlbRightXMax = !rlb	; Right BoundaryBox X Maximum
	!rlb #= !rlb+2
	rlbRightChild = !rlb	; Right Child,>=$8000 = AREA
	!rlb #= !rlb+2
	rlbSize = !rlb


;
;	* * * * * * *       AREA STRUCTURE       * * * * * * *
;
	!rla #= 0
	rlaNumSegs = !rla	; Number of Segments
	!rla #= !rla+1
	rlaSegOffset = !rla	; Offset to Starting Segment
	!rla #= !rla+2
	rlaSector = !rla	; Sector this Area belongs to
	!rla #= !rla+1
	rlaSize = !rla


;
;	* * * * * * *       VERTEX STRUCTURE       * * * * * * *
;
	!rlx #= 0
	rlxVertexX = !rlx	; Vertex X
	!rlx #= !rlx+2
	rlxVertexY = !rlx	; Vertex Y
	!rlx #= !rlx+2
	rlxSize = !rlx


;
;	* * * * * * *       SEGMENT STRUCTURE       * * * * * * *
;
	!rlg #= 0
	rlgVertex1 = !rlg	; Vertex1
	!rlg #= !rlg+2
	rlgVertex2 = !rlg	; Vertex2
	!rlg #= !rlg+2
	rlgFlags = !rlg	; Flags
	!rlg #= !rlg+1
	rlgOffsetX = !rlg	; FaceOffsetX
	!rlg #= !rlg+1
	rlgOffsetY = !rlg	; FaceOffsetY
	!rlg #= !rlg+1
	rlgFace = !rlg	; Face
	!rlg #= !rlg+2
	rlgLine = !rlg	; Line
	!rlg #= !rlg+2
	rlgSize = !rlg
;
;	>>>   SEGMENT FLAGS   <<<
;
	rlgfSolid = $01	; SEGMENT is SOLID
	rlgfSky = $02	; UPPER TEXTURE is SKY
	rlgfDoor = $04	; SEGMENT is DOOR
	rlgfClear = $08	; SEGMENT is CLEAR
	rlgfALTTEXTURE = $10	; ALTERNATE TEXTURE
	rlgfNORMALPEGGED = $40	; NORMAL WALL TEXTURE IS PEGGED
	rlgfLOWERPEGGED = $40	; LOWER WALL TEXTURE IS PEGGED
	rlgfUPPERPEGGED = $20	; UPPER WALL TEXTURE IS PEGGED


;
;	* * * * * * *       FACE STRUCTURE       * * * * * * *
;
;	>>>   SOLID/TRANSPARENT FACE   <<<
;
	!rlf #= 0
	rlfSectorNear = !rlf	; Sector Near
	!rlf #= !rlf+1
	rlfSizeST = !rlf	; SIZE FOR UNION SOLID/TRANSPARENT
;
;	>>>   SOLID FACE   <<<
;
	!rlf #= rlfSizeST
	rlfWallTexture = !rlf	; Texture of Normal Wall
	!rlf #= !rlf+1
	rlfSizeS = !rlf	; SIZE FOR SOLID FACE
;
;	>>>   TRANSPARENT FACE   <<<
;
	!rlf #= rlfSizeST
	rlfSectorFar = !rlf	; Sector Far
	!rlf #= !rlf+1
	rlfUpperTexture = !rlf	; Texture of Upper Wall
	!rlf #= !rlf+1
	rlfLowerTexture = !rlf	; Texture of Lower Wall
	!rlf #= !rlf+1
	rlfSizeT = !rlf	; SIZE FOR TRANSPARENT FACE


;
;	* * * * * * *       SECTOR STRUCTURE       * * * * * * *
;
	!rls #= 0
	rlsType = !rls	; Sector Type
	!rls #= !rls+1
	rlsLightLevel = !rls	; Light Level (Near)
	!rls #= !rls+1
	rlsLightLevel2 = !rls	; Light Level (Far/Neighbor)
	!rls #= !rls+1
	rlsFloorHeight = !rls	; Floor Height
	!rls #= !rls+2
	rlsCeilingHeight = !rls	; Ceiling Height
	!rls #= !rls+2
	rlsFloorTexture = !rls	; Floor Texture
	!rls #= !rls+1
	rlsCeilingTexture = !rls	; Ceiling Texture
	!rls #= !rls+1
	rlsTag = !rls	; Tag
	!rls #= !rls+1
	rlsSize = !rls


;
;	* * * * * * *       SECTORDATA STRUCTURE       * * * * * * *
;
	!rlsd #= 0
	rlsdFlags = !rlsd	; Flags
	!rlsd #= !rlsd+1
	rlsdLightLevel = !rlsd	; LightLevel ($00=Bright,$ff=Dark)
	!rlsd #= !rlsd+1
	rlsdFloorHeight = !rlsd	; Floor Height
	!rlsd #= !rlsd+2
	rlsdCeilingHeight = !rlsd	; Ceiling Height
	!rlsd #= !rlsd+2
	rlsdData = !rlsd	; DataBlock
	!rlsd #= !rlsd+1
	!rlsd #= !rlsd+1	; UNUSED!
	rlsdFloorTexture = !rlsd	; Floor Texture
	!rlsd #= !rlsd+1
	rlsdCeilingTexture = !rlsd	; Ceiling Texture
	!rlsd #= !rlsd+1
	rlsdRLCount = !rlsd	; RLEngine Count
	!rlsd #= !rlsd+2
	rlsdObjects = !rlsd	; Pointer to First RLObject
	!rlsd #= !rlsd+2
	rlsdSize = !rlsd
;
;	>>>   SECTORDATA FLAGS   <<<
;
	rlsdfLightDir = $01	; LightLevel is Incrementing
	rlsdfSecret = $02	; SECRET Found
	rlsdfTypeNormal = $04	; TYPE Now NORMAL
	rlsdfTypeNukage = $08	; TYPE Now NUKAGE
	rlsdfCeilingSky = $80	; Ceiling Texture is SKY!


;
;	* * * * * * *       LINE STRUCTURE       * * * * * * *
;
	!rll #= 0
	rllVertex1 = !rll	; Vertex 1
	!rll #= !rll+2
	rllVertex2 = !rll	; Vertex 2
	!rll #= !rll+2
	rllFlags = !rll	; Flags
	!rll #= !rll+2
	rllAngle = !rll	; Angle
	!rll #= !rll+2
	rllFace = !rll	; Face
	!rll #= !rll+2
	rllType = !rll	; Type
	!rll #= !rll+1
	rllTag = !rll	; Tag
	!rll #= !rll+1
	rllSize = !rll	; !!!DANGER!!!  _RLE2T3300  !!!
;
;	>>>   LINE FLAGS (* indicates which flags are in RAM)   <<<
;
	rllfSolid = $0001	; *LINE is SOLID
	rllfMapped = $0002	; *LINE is MAPPED
	rllfUsed = $0004	; *LINE is USED (Operates Once)
	rllfSecret = $0004	;  LINE is SECRET
	rllfImpassible = $0008	;  LINE is IMPASSIBLE
	rllfDoor = $0010	;  LINE is DOOR
	rllfDontDraw = $0020	;  LINE is HIDDEN
;
	rllfFloorH = $0100	; FloorHeight Changes
	rllfCeilingH = $0200	; CeilingHeight Changes
	rllfTrigger = $0400	; LINE is TRIGGER
	rllfUsable = $0800	; LINE is USABLE
	rllfTriggerE = $1000	; LINE is TRIGGER BY ENEMIES
	rllfUsableE = $2000	; LINE is USABLE BY ENEMIES
;
	rllfItem = $8000	; LINE is ITEM


;
;	* * * * * * *       BLOCKMAP STRUCTURE       * * * * * * *
;
	!rlk #= 0
	rlkX = !rlk	; X Origin
	!rlk #= !rlk+2
	rlkY = !rlk	; Y Origin
	!rlk #= !rlk+2
	rlkDim = !rlk	; Dimensions
	rlkXBlocks = !rlk	; #Blocks in X
	!rlk #= !rlk+1
	rlkYBlocks = !rlk	; #Blocks in Y
	!rlk #= !rlk+1
;
;	>>>   LIST OF BLOCKMAP OFFSETS FOLLOWS   <<<
;
	rlkBlockOffsets = !rlk	; Start of BlockOffsets
;
;	>>>   LISTS OF LINES FOLLOW   <<<
;
;rlkLines		equ	rlk			; Start of LineLists
;rlkSize		equ	rlk


;
;	* * * * * * *       LEVEL OBJECT STRUCTURE       * * * * * * *
;
	!rlp #= 0
	rlpFlags = !rlp	; Flags
	!rlp #= !rlp+1
	rlpType = !rlp	; Type
	!rlp #= !rlp+1
	rlpX = !rlp	; X Coordinate
	!rlp #= !rlp+2
	rlpY = !rlp	; Y Coordinate
	!rlp #= !rlp+2
	rlpSize0 = !rlp
	rlpAngle = !rlp	; Angle
	!rlp #= !rlp+2
	rlpSize = !rlp
;
;	>>>   LEVEL OBJECT FLAGS   <<<
;
	rlpfSkill12 = $01	; Present at skill 1 and 2
	rlpfSkill3 = $02	; Present at skill 3 (hurt me plenty)
	rlpfSkill45 = $04	; Present at skill 4 and 5 (ultra-violence, nightmare)
;rlpfDeafGuard		equ	$08			; Deaf Guard
	rlpfMultiPlayer = $10	; Only appears in MultiPlayer Mode
	rlpfMovable = $40	; Object can MOVE throughout Level
	rlpfActive = $80	; Object is ACTIVE (Visible)
;
;	>>>   LEVEL OBJECT FLAGS   <<<
;
	rlpfEnemyBlocked = $07	; Enemy Movement was just Blocked
	rlpfProjectileFast = $01	; Projectile is FAST
	rlpfSolid = $08	; Object is SOLID
;rlpfProjectile		equ	$10			; Object is PROJECTILE
	rlpfItem = $10	; Object is ITEM
	rlpfTarget = $20	; Object is TARGET
	; (dup) rlpfMovable = $40	; Object is MOVABLE
	; (dup) rlpfActive = $80	; Object is ACTIVE


;
;	* * * * * * *       PLATFORM DOOR STRUCTURE       * * * * * * *
;
	!rlpd #= 0
	rlpdSector = !rlpd	; Sector#
	!rlpd #= !rlpd+1
	rlpdMaxHeight = !rlpd	; Maximum Ceiling Height
	!rlpd #= !rlpd+2
	rlpdOriginX = !rlpd	; Sound Origin X
	!rlpd #= !rlpd+2
	rlpdOriginY = !rlpd	; Sound Origin Y
	!rlpd #= !rlpd+2
	rlpdNumLines = !rlpd	; #Lines
	!rlpd #= !rlpd+1
	rlpdLines = !rlpd	; Line List
;rlpdSize		equ	rlpd

;
;	* * * * * * *       PLATFORM FLOOR STRUCTURE       * * * * * * *
;
	!rlpf #= 0
	rlpfTag = !rlpf	; Tag
	!rlpf #= !rlpf+1
	rlpfType = !rlpf	; Type
	!rlpf #= !rlpf+1
	rlpfNumSectors = !rlpf	; #Sectors
	!rlpf #= !rlpf+1
	rlpfSize = !rlpf
;
	!rlpfs #= 0	; REPEATED FOR EACH FLOOR SECTOR
	rlpfsSector = !rlpfs	; Sector#
	!rlpfs #= !rlpfs+1
	rlpfsHeight = !rlpfs	; Destination Height
	!rlpfs #= !rlpfs+2
	rlpfsOriginX = !rlpfs	; Sound Origin X
	!rlpfs #= !rlpfs+2
	rlpfsOriginY = !rlpfs	; Sound Origin Y
	!rlpfs #= !rlpfs+2
	rlpfsModelSector = !rlpfs	; Model Sector#
	!rlpfs #= !rlpfs+1
	rlpfsSize = !rlpfs

;
;	* * * * * * *       PLATFORM STAIR STRUCTURE       * * * * * * *
;
	!rlps #= 0
	rlpsTag = !rlps	; Tag
	!rlps #= !rlps+1
	rlpsOriginX = !rlps	; Sound Origin X
	!rlps #= !rlps+2
	rlpsOriginY = !rlps	; Sound Origin Y
	!rlps #= !rlps+2
	rlpsHeight = !rlps	; Starting Height
	!rlps #= !rlps+2
	rlpsNumSectors = !rlps	; #Sectors
	!rlps #= !rlps+1
	rlpsSectors = !rlps	; Sector List
;rlpsSize		equ	rlps

;
;	* * * * * * *       PLATFORM CEILING STRUCTURE       * * * * * * *
;
	!rlpc #= 0
	rlpcTag = !rlpc	; Tag
	!rlpc #= !rlpc+1
	rlpcType = !rlpc	; Type
	!rlpc #= !rlpc+1
	rlpcNumSectors = !rlpc	; #Sectors
	!rlpc #= !rlpc+1
;
	!rlpcs #= 0	; REPEATED FOR EACH CEILING SECTOR
	rlpcsSector = !rlpcs	; Sector#
	!rlpcs #= !rlpcs+1
	rlpcsMaxHeight = !rlpcs	; Maximum Ceiling Height
	!rlpcs #= !rlpcs+2
	rlpcsOriginX = !rlpcs	; Sound Origin X
	!rlpcs #= !rlpcs+2
	rlpcsOriginY = !rlpcs	; Sound Origin Y
	!rlpcs #= !rlpcs+2
	rlpcsNumLines = !rlpcs	; #Lines
	!rlpcs #= !rlpcs+1
	rlpcsLines = !rlpcs	; Line List
;rlpcsSize		equ	rlpcs

;
;	* * * * * * *       PLATFORM LIFT STRUCTURE       * * * * * * *
;
	!rlpl #= 0
	rlplTag = !rlpl	; Tag
	!rlpl #= !rlpl+1
	rlplType = !rlpl	; Type
	!rlpl #= !rlpl+1
	rlplNumSectors = !rlpl	; #Sectors
	!rlpl #= !rlpl+1
;
	!rlpls #= 0	; REPEATED FOR EACH LIFT SECTOR
	rlplsSector = !rlpls	; Sector#
	!rlpls #= !rlpls+1
	rlplsMinHeight = !rlpls	; Minimum Floor Height
	!rlpls #= !rlpls+2
	rlplsMaxHeight = !rlpls	; Maximum Floor Height
	!rlpls #= !rlpls+2
	rlplsOriginX = !rlpls	; Sound Origin X
	!rlpls #= !rlpls+2
	rlplsOriginY = !rlpls	; Sound Origin Y
	!rlpls #= !rlpls+2
	rlplsSize = !rlpls


;
;	* * * * * * *       TEXTURE STRUCTURE       * * * * * * *
;
	!rlt #= 0
	rltWidth = !rlt	; #Pixels Wide
	!rlt #= !rlt+2
	rltHeight = !rlt	; #Pixels Tall
	!rlt #= !rlt+2
	rltNumPatches = !rlt	; #Patches
	!rlt #= !rlt+1
	rltPatches = !rlt	; Patch Definitions
;
;	* * * * * * *       TEXTURE PATCH STRUCTURE       * * * * * * *
;
	!rlh #= 0
	rlhXOffset = !rlh	; X Offset
	!rlh #= !rlh+2
	rlhYOffset = !rlh	; Y Offset
	!rlh #= !rlh+2
	rlhWall = !rlh	; Wall#
	!rlh #= !rlh+2
	rlhSize = !rlh


;
;	* * * * * * *       IMAGERY STRUCTURE       * * * * * * *
;
	!rli #= 0
;rliFlags		equ	rli			; Flags
;rli			var	rli+2
	rliHeight = !rli	; #Pixels Tall
	!rli #= !rli+1
	rliWidth = !rli	; #Pixels Wide
	!rli #= !rli+1
	rliData = !rli	; Pointers to PixelStrips
;
	!rlid #= 0
	rlidStrip = !rlid	; Pointer to PixelStrip
	!rlid #= !rlid+3


;
;	* * * * * * *       SPRITE STRUCTURE       * * * * * * *
;
	!rlr #= 0
	rlrWidth = !rlr	; #Pixels Wide (Whole Sprite)
	!rlr #= !rlr+1
	rlrHeight = !rlr	; #Pixels Tall (Whole Sprite)
;
;	>>>   SPRITESTRIP SUBSTRUCTURE (FOR EACH LINE)   <<<
;
	!rlrs #= 0
	rlrsOffset = !rlrs	; #Pixels Offset (This Line)
	!rlrs #= !rlrs+1
	rlrsWidth = !rlrs	; #Pixels Wide (This Line)
	!rlrs #= !rlrs+1
	rlrsLineOffset = !rlrs	; LineOffset (This Line)
	!rlrs #= !rlrs+2	; (from HighByte to LineData)
	rlrsSize = !rlrs
;
;	>>>   SPRITEPIXELBLOCK SUBSUBSTRUCTURE (FOR EACH PIXELBLOCK ON A LINE)   <<<
;
	!rlrb #= 0
	rlrbLength = !rlrb	; #Pixels Wide ($00=End of Line)
	!rlrb #= !rlrb+1
	rlrbOffset = !rlrb	; #Pixels Offset
	!rlrb #= !rlrb+1
	rlrbData = !rlrb	; DataBlock (COLOUR# per Pixel)
;							; $FF,LEN,COLOUR for RUNS >=3


;
;	* * * * * * *       GSU AREA/SEGMENT LIST STRUCTURE       * * * * * * *
;
	!rlas #= 0
	rlasPrev = !rlas	; Previous Segment Block
	!rlas #= !rlas+2
	rlasArea = !rlas	; Area
	!rlas #= !rlas+2
	rlasSegs = !rlas	; List of Segments and Segments' Data
;rlas			var	rlas+(#Segs*rluSize)
	rlasEnd = !rlas	; Ending Segment Terminator ($7FXX)
	!rlas #= !rlas+2
	rlasSize = !rlas


;
;	* * * * * * *       GSU BSP SEGMENT LIST STRUCTURE       * * * * * * *
;
	!rlu #= 0
	rluSeg = !rlu	; Segment
	!rlu #= !rlu+2
	rluV1 = !rlu	; Vertex 1
	!rlu #= !rlu+2
	rluV2 = !rlu	; Vertex 2
	!rlu #= !rlu+2
	rluXs1 = !rlu	; Screen X1
	!rlu #= !rlu+2
	rluXs2 = !rlu	; Screen X2
	!rlu #= !rlu+2
	rluY1 = !rlu	; World Y1
	!rlu #= !rlu+2
	rluY2 = !rlu	; World Y2
	!rlu #= !rlu+2
	rluSize = !rlu


;
;	* * * * * * *       GSU BSP SEGMENT CLIPZONE STRUCTURE       * * * * * * *
;
	!rlcz #= 0
	rlczX2 = !rlcz	; Screen X2
	!rlcz #= !rlcz+1
	rlczX1 = !rlcz	; Screen X1
	!rlcz #= !rlcz+1
	rlczNext = !rlcz	; Next
	!rlcz #= !rlcz+2
	rlczSize = !rlcz


;
;	* * * * * * *       GSU BSP VISIBLE SEGMENT CLIPZONE STRUCTURE       * * * * * * *
;
	!rlvcz #= 0
	rlvczClipRange = !rlvcz	; Screen ClipRange MinY/MaxY PreVSeg
	!rlvcz #= !rlvcz+2
	rlvczY = !rlvcz	; World Y Distance
	!rlvcz #= !rlvcz+2
	rlvczCeilingY = !rlvcz	; Screen Ceiling Y
	!rlvcz #= !rlvcz+2
	rlvczFloorY = !rlvcz	; Screen Floor Y
	!rlvcz #= !rlvcz+2
	rlvczClipRange2 = !rlvcz	; Screen ClipRange MinY/MaxY PostVSeg
	!rlvcz #= !rlvcz+2
	rlvczSize = !rlvcz


;
;	* * * * * * *       GSU VISIBLE SEGMENT LIST STRUCTURE       * * * * * * *
;
	!rlv #= 0
	rlvSeg = !rlv	; Segment Address
	rlvXsT = !rlv	; Screen X1/XsCount (#Pixels to Trace)
	!rlv #= !rlv+2
	rlvXs0 = !rlv	; Screen X0 (rXs0)
	!rlv #= !rlv+2
	rlvFlags = !rlv	; Flags
	!rlv #= !rlv+2
	rlvXs1 = !rlv	; Screen X1 (rXs1)
	!rlv #= !rlv+1
	rlvXs2 = !rlv	; Screen X2 (rXs2)
	!rlv #= !rlv+1
	rlvXsRatioI = !rlv	; Screen Xs RatioIndex (ScreenX3-ScreenX0+1)
	rlvFace = !rlv	; Face Address
	!rlv #= !rlv+2
;
	rlvSegFlags = !rlv	; SegmentFlags
	rlvClipRangeP = !rlv	; ClipRange Address
	!rlv #= !rlv+2
;
	rlvClipZoneP = !rlv	; ClipZone Address
	!rlv #= !rlv+2
;
	rlvY1 = !rlv	; World Y1
	!rlv #= !rlv+2
	rlvY2 = !rlv	; World Y2
	!rlv #= !rlv+2
	rlvYInvF = !rlv	; YInv Fraction
	!rlv #= !rlv+2
	rlvYInv = !rlv	; YInv
	!rlv #= !rlv+2
;
	rlvFaceOffsetX = !rlv	; FaceOffsetX
	!rlv #= !rlv+1
	rlvFaceOffsetY = !rlv	; FaceOffsetY
	!rlv #= !rlv+1
;
	rlvYInvStepF = !rlv	; YInv StepDelta Fraction
	!rlv #= !rlv+2
	rlvYInvStep = !rlv	; YInv StepDelta
	!rlv #= !rlv+2
;
	rlvSectorNearData = !rlv	; SectorNearData Address
	!rlv #= !rlv+2
	rlvSectorFarData = !rlv	; SectorFarData Address
	!rlv #= !rlv+2
;
	rlvFloorHeight = !rlv	; Height of Floor
	rlvNormalWallBotHeight = !rlv	; Height of Normal Wall Bottom
	rlvLowerWallBotHeight = !rlv	; Height of Lower  Wall Bottom
	!rlv #= !rlv+2
	rlvCeilingHeight = !rlv	; Height of Ceiling
	rlvNormalWallTopHeight = !rlv	; Height of Normal Wall Top
	rlvUpperWallTopHeight = !rlv	; Height of Upper  Wall Top
	!rlv #= !rlv+2
;
	rlvUpperWallBotHeight = !rlv	; Height of Upper  Wall Bottom
	!rlv #= !rlv+2
	rlvLowerWallTopHeight = !rlv	; Height of Lower  Wall Top
	!rlv #= !rlv+2
;
	rlvWallPlotDataStart = !rlv	; Start of WallPlotData for this VSeg
	!rlv #= !rlv+2
	rlvWallPlotDataEnd = !rlv	; End of WallPlotData for this VSeg
	!rlv #= !rlv+2
;
	rlvNormalWallTextureH = !rlv	; TextureHeight  for Normal Wall
	rlvUpperWallTextureH = !rlv	; TextureHeight  for Upper  Wall
	!rlv #= !rlv+1
	rlvNormalWallTextureW = !rlv	; TextureWidth   for Normal Wall
	rlvUpperWallTextureW = !rlv	; TextureWidth   for Upper  Wall
	!rlv #= !rlv+1
	rlvNormalWallTexture = !rlv	; TextureAddress for Normal Wall
	rlvUpperWallTexture = !rlv	; TextureAddress for Upper  Wall
	!rlv #= !rlv+2
	rlvLowerWallTextureH = !rlv	; TextureHeight  for Lower  Wall
	!rlv #= !rlv+1
	rlvLowerWallTextureW = !rlv	; TextureWidth   for Lower  Wall
	!rlv #= !rlv+1
	rlvLowerWallTexture = !rlv	; TextureAddress for Lower  Wall
	!rlv #= !rlv+2
;
	rlvVertex1 = !rlv	; Vertex 1
	!rlv #= !rlv+2
	rlvVertex2 = !rlv	; Vertex 2
	!rlv #= !rlv+2
;
	rlvRSAngle = !rlv	; Rotated Segment Angle
	!rlv #= !rlv+2
	rlvRSPDistance = !rlv	; Rotated Segment Perpendicular Distance
	!rlv #= !rlv+2
	rlvVTOffset = !rlv	; Vertex TextureOffset
	!rlv #= !rlv+2
;
	rlvSize = !rlv
;
;	>>>   VISIBLE SEGMENT FLAGS   <<<
;
	rlvfWALL = $8000	; WALL *ANY WALL*
;
	rlvfNORMALWALL = $0001	; NORMAL WALL
	rlvfUPPERWALL = $0002	; UPPER WALL
	rlvfLOWERWALL = $0004	; LOWER WALL
;
;rlvfNORMALCLIP		equ	$0010		; NORMAL CLIP
	rlvfUPPERCLIP = $0100	; UPPER CLIP
	rlvfLOWERCLIP = $0080	; LOWER CLIP
;
	rlvfADDCEILING = $0020	; CEILING *ONLY*
	rlvfADDFLOOR = $0040	; FLOOR *ONLY*
;
	rlvfNORMALSPRCLIP = $0200	; NORMAL SPRITE CLIP
	rlvfUPPERSPRCLIP = $0400	; UPPER SPRITE CLIP
	rlvfLOWERSPRCLIP = $0008	; LOWER SPRITE CLIP
;
	rlvfNORMALPEGGED = $4000	; NORMAL WALL TEXTURE IS PEGGED
	rlvfLOWERPEGGED = $4000	; LOWER WALL TEXTURE IS PEGGED
	rlvfUPPERPEGGED = $2000	; UPPER WALL TEXTURE IS PEGGED
;
	rlvfALTTEXTURE = $1000	; ALTERNATE TEXTURE
	rlvfMASKED = $0800	; MASKED MIDDLE TEXTURE (SEGMENT FLAG rlgfClear, this port)
;
;	* * * * * * *       MASKED MIDDLE TEXTURE LIST STRUCTURE (this port)       * * * * * * *
;
;	One entry per visible segment with a masked middle texture (rlvsegs4.asm
;	_RLBuildMaskList), drawn by the objects pass (rltraceo.asm _TRMkScan)
;
	MaxRLMasks = 32	; Maximum entries (more are left out)
	!rlmk #= 0
	rlmkVSeg = !rlmk	; VisibleSegment (+1 = drawn in this third)
	!rlmk #= !rlmk+2
	rlmkImage = !rlmk	; Image (bank of RLImagesTable, at rliHeight)
	!rlmk #= !rlmk+2
	rlmkZ = !rlmk	; World Z of the bottom (relative to the eye)
	!rlmk #= !rlmk+2
	rlmkHeight = !rlmk	; Height
	!rlmk #= !rlmk+1
	rlmkWMask = !rlmk	; Width-1
	!rlmk #= !rlmk+1
	rlmkSize = !rlmk


;
;	* * * * * * *       GSU VISIBLE OBJECT LIST STRUCTURE       * * * * * * *
;
	!rlq #= 0
	rlqY = !rlq	; World Y
	!rlq #= !rlq+2
	rlqNext = !rlq	; Pointer to Next VObj
	!rlq #= !rlq+2
	rlqObj = !rlq	; RLObject Address
	!rlq #= !rlq+2
	rlqWX = !rlq	; World X
	!rlq #= !rlq+2
	rlqWZ = !rlq	; World Z
	!rlq #= !rlq+2
	rlqXs1 = !rlq	; Screen X1 (rXs1)
	!rlq #= !rlq+2
	rlqXs2 = !rlq	; Screen X2 (rXs2)
	!rlq #= !rlq+2
	rlqHeight = !rlq	; World Height
	!rlq #= !rlq+1
	rlqWidth = !rlq	; World Width
	!rlq #= !rlq+1
	rlqSectorData = !rlq	; Pointer to SectorData
	!rlq #= !rlq+2
	rlqImage = !rlq	; Imagery Pointer
	!rlq #= !rlq+2
	rlqDrawn = !rlq	; Drawn Flag
	!rlq #= !rlq+1
	rlqFlipWidth = !rlq	; World Width-1
	!rlq #= !rlq+1
	rlqObjPlotDataStart = !rlq	; Start of ObjPlotData for this VObj
	!rlq #= !rlq+2
	rlqObjPlotDataEnd = !rlq	; End of ObjPlotData for this VObj
	!rlq #= !rlq+2
	rlqSize = !rlq


;
;	* * * * * * *       GSU FLOOR/CEILING DATA STRUCTURE       * * * * * * *
;
	!rlfd #= 0
	rlfdKey = !rlfd	; Search Key
	rlfdSectorData = !rlfd	; SectorDataNear (Bit0:Floor=0,Ceiling=1)
	!rlfd #= !rlfd+2
	rlfdNext = !rlfd	; Pointer to Next Floor/Ceiling
	!rlfd #= !rlfd+2
	rlfdMinX = !rlfd	; Minimum X Coordinate
	!rlfd #= !rlfd+1
	rlfdMaxX = !rlfd	; Maximum X Coordinate
	!rlfd #= !rlfd+1
	rlfdHeight = !rlfd	; Height of this Floor/Ceiling
	!rlfd #= !rlfd+2
	rlfdFloorPlotDataStart = !rlfd	; Start of FloorPlotData
	!rlfd #= !rlfd+2
	rlfdFloorPlotDataEnd = !rlfd	; End of FloorPlotData
	!rlfd #= !rlfd+2
	rlfdRange = !rlfd	; Range of Floor/Ceiling Data
	if useHIGHDETAIL == 0
	!rlfd #= !rlfd+(((RLViewPixX/3/2)+1)*2)
	endif
	if useHIGHDETAIL != 0
	!rlfd #= !rlfd+(((RLViewPixX/3)+1)*2)
	endif
	rlfdSize = !rlfd


;
;	* * * * * * *       GSU PRE WALL PLOT LIST STRUCTURE       * * * * * * *
;
	!plv #= 0
	plvZ2 = !plv	; World Z Adjust
	!plv #= !plv+2
	plvY = !plv	; World Y
	!plv #= !plv+2
	plvClipRange = !plv	; Clipping Range
	!plv #= !plv+2
	plvXs = !plv	; Screen X Coordinate
	!plv #= !plv+1
	!plv #= !plv+1
	plvScaleF = !plv	; RL->SCN Pixel Scaling Fraction
	!plv #= !plv+2
	plvVSegTextureH = !plv	; Offset to VisibleSegment Texture Height
	!plv #= !plv+1
	plvScale = !plv	; RL->SCN Pixel Scaling Integer
	!plv #= !plv+1
	plvZ = !plv	; World Z at Bottom
	!plv #= !plv+2
	plvSize = !plv


;
;	* * * * * * *       GSU WALL PLOT LIST STRUCTURE       * * * * * * *
;
	!plw #= 0
	plwNumPix = !plw	; Number of ScreenPixels to Plot
	!plw #= !plw+1
	plwColourMap = !plw	; HighByte of ColourMap
	!plw #= !plw+1
	plwPixScale = !plw	; SCN->RL Pixel Scaling Value
	!plw #= !plw+2
	plwPixY = !plw	; Starting Y Coordinate
	!plw #= !plw+1
	plwScale = !plw	; RL->SCN Pixel Scaling Integer
	plwBank = !plw	; Bank of Data to Plot
	!plw #= !plw+1
	plwScaleF = !plw	; RL->SCN Pixel Scaling Fraction
	plwData = !plw	; Address of Data to Plot
	!plw #= !plw+2
	plwWallF = !plw	; World Z Fraction
	!plw #= !plw+1
	plwTextureOffset = !plw	; TextureOffset in Pixels
	!plw #= !plw+1
	plwVSegTextureH = !plw	; Offset to VisibleSegment TextureHeight
	!plw #= !plw+1
	plwXs = !plw	; Screen X Coordinate
	!plw #= !plw+1
	plwNext = !plw	; Pointer to Next WallPlot
	!plw #= !plw+2
	plwSize = !plw


;
;	* * * * * * *       GSU FLOOR PLOT LIST STRUCTURE       * * * * * * *
;
	if useFLOORS == 0
	!plf #= 0
	plfNumPix = !plf	; Number of ScreenPixels to Plot +1
	!plf #= !plf+1
	plfColourMap = !plf	; HighByte of ColourMap (0=SKY)
	!plf #= !plf+1
	plfPixX = !plf	; Starting X Coordinate
	!plf #= !plf+1
	plfPixY = !plf	; Starting Y Coordinate
	!plf #= !plf+1
	plfSector = !plf	; Pointer to SectorData
	!plf #= !plf+2
	plfSize = !plf
	endif
	if useFLOORS != 0
	!plf #= 0
	plfNumPix = !plf	; Number of ScreenPixels to Plot +1
	!plf #= !plf+1
	plfColourMap = !plf	; HighByte of ColourMap (0=SKY)
	!plf #= !plf+1
	plfPixScaleX = !plf	; SCN->RL X Pixel Scaling Value
	!plf #= !plf+2
	plfPixScaleY = !plf	; SCN->RL Y Pixel Scaling Value
	!plf #= !plf+2
	plfSector = !plf	; Pointer to SectorData
	plfFloorXY = !plf	; Texture X/Y Offsets
	!plf #= !plf+2
	plfFloorXYF = !plf	; World X/World Y Fractions
	!plf #= !plf+2
	plfPixX = !plf	; Starting X Coordinate
	!plf #= !plf+1
	plfPixY = !plf	; Starting Y Coordinate
	!plf #= !plf+1
	plfSize = !plf
	endif


;
;	* * * * * * *       GSU OBJ PLOT LIST STRUCTURE       * * * * * * *
;
	!plo #= 0

	ploImageOffset = !plo	; ImageOffset in Pixels
	!plo #= !plo+1
	!plo #= !plo+1	; UNUSED!

	ploXs = !plo	; Screen X Coordinate
	!plo #= !plo+1
	ploYs = !plo	; Screen Y Coordinate
	!plo #= !plo+1

	ploData = !plo	; Address of Data to Plot
	!plo #= !plo+2

	ploBank = !plo	; Bank of Data to Plot
	!plo #= !plo+1
	ploColourMap = !plo	; HighByte of ColourMap
	!plo #= !plo+1

	ploObjF = !plo	; World Z Fraction
	!plo #= !plo+1
	ploNumPix = !plo	; Number of ScreenPixels to Plot
	!plo #= !plo+1

	ploSize = !plo


;
;	* * * * * * *       GSU OBJECT STRUCTURE       * * * * * * *
;
	!rlo #= 0
	rloNext = !rlo	; Next Object (-1=FREE)
	!rlo #= !rlo+2
	rloPrev = !rlo	; Previous Object
	!rlo #= !rlo+2
	rloFlags = !rlo	; rlpFlags (from LevelObject)
	!rlo #= !rlo+1
	rloType = !rlo	; Type
	!rlo #= !rlo+1
;
	rloLObj = !rlo	; Level Object (UNMOVABLE ONLY!)
	rloSize0 = !rlo+2	; SIZE FOR UNMOVABLE OBJECTS
;
	rloX = !rlo	; X Coordinate
	!rlo #= !rlo+4
	rloY = !rlo	; Y Coordinate
	!rlo #= !rlo+4
	rloZ = !rlo	; Z Coordinate
	!rlo #= !rlo+2
	rloVX = !rlo	; X Velocity
	!rlo #= !rlo+2
	rloVY = !rlo	; Y Velocity
	!rlo #= !rlo+2
	rloAngle = !rlo	; Angle
	!rlo #= !rlo+2
	rloSector = !rlo	; Sector
	!rlo #= !rlo+1
;
;	>>>   ANIMATION/IMAGERY SUBSTRUCTURE   <<<
;
	rloImage = !rlo	; Image#
	!rlo #= !rlo+1
	rloAnim = !rlo	; Animation
	!rlo #= !rlo+2
	rloAnimCount = !rlo	; #Cycles Left in Current AnimImage
	!rlo #= !rlo+1
;
;	>>>   STATE SUBSTRUCTURE   <<<
;
	rloStateCount = !rlo	; #Cycles Left in Current State
	!rlo #= !rlo+1
	rloState = !rlo	; Pointer to MObjState
	!rlo #= !rlo+2
	rloMData = !rlo	; Pointer to MObjData
	!rlo #= !rlo+2
	rloSize1 = !rlo	; BASE SIZE FOR MOVABLE OBJECTS
;
;	>>>   MOVING OBJECTS SUBSTRUCTURE UNION   <<<
;
	!rlo #= rloSize1
	rloHealth = !rlo	; #Health Points
	!rlo #= !rlo+2
	rloSize2 = !rlo	; BASE SIZE FOR PLAYER/ENEMIES
;
;	>>>   PLAYER DATA SUBSTRUCTURE UNION   <<<
;
;rloPlayerData		equ	rlo		; PlayerData SubStructure
	rloZ2 = !rlo	; Z2 Coordinate
	!rlo #= !rlo+2
	rloC2 = !rlo	; C2 Coordinate
	!rlo #= !rlo+2
;
;	>>>   ENEMY DATA SUBSTRUCTURE UNION   <<<
;
	!rlo #= rloSize2
;rloEnemyData		equ	rlo		; EnemyData SubStructure
	rloTObj = !rlo	; Pointer to Target RLObject
	!rlo #= !rlo+2
	rloTDistance = !rlo	; Distance to Target
	!rlo #= !rlo+2
;rloTAngle		equ	rlo		; Angle to Target
;rlo			var	rlo+2
	rloSize = !rlo	; SIZE FOR MOVABLE OBJECTS
;
;	>>>   PROJECTILE SUBSTRUCTURE UNION   <<<
;
	!rlo #= rloSize1
	rloVZ = !rlo	; Z Velocity
	!rlo #= !rlo+2
	rloVXY = !rlo	; XY Velocity (+$8000>>1)
	!rlo #= !rlo+2	; (OVERLAYS rloTObj!)
	rloZF = !rlo	; Z Coordinate Fraction (Projectiles)
	!rlo #= !rlo+2


;
;	* * * * * * *       GSU MOVE OBJECT LINE STRUCTURE       * * * * * * *
;
	!rlml #= 0
	rlmlLine = !rlml	; Line#
	!rlml #= !rlml+2
	rlmlLX1 = !rlml	; Line Vertex X1
	!rlml #= !rlml+2
	rlmlLY1 = !rlml	; Line Vertex Y1
	!rlml #= !rlml+2
	rlmlPUX = !rlml	; Line Perpendicular UnitVector X
	!rlml #= !rlml+2
	rlmlPUY = !rlml	; Line Perpendicular UnitVector Y
	!rlml #= !rlml+2
	rlmlFlags = !rlml	; Line Flags
	!rlml #= !rlml+2
	rlmlLX2 = !rlml	; Line Vertex X2
	!rlml #= !rlml+2
	rlmlLY2 = !rlml	; Line Vertex Y2
	!rlml #= !rlml+2
	rlmlHighFloorHeight = !rlml	; Highest Floor Height
	rlmlSectorData = !rlml	; SectorData for Items
	!rlml #= !rlml+2
	rlmlLowCeilingHeight = !rlml	; Lowest Ceiling Height
	!rlml #= !rlml+2
	rlmlLowFloorHeight = !rlml	; Lowest Floor Height
	!rlml #= !rlml+2
	rlmlSize = !rlml


;
;	* * * * * * *       GSU TASK STRUCTURE       * * * * * * *
;
	!rlm #= 0
	rlmCode = !rlm	; Pointer to TaskCode
	!rlm #= !rlm+2
	rlmData = !rlm	; Pointer to TaskData
	!rlm #= !rlm+2
	rlmSize = !rlm


;
;	* * * * * * *       TOGGLE TASK STRUCTURE       * * * * * * *
;
	!rltt #= 0
	rlttCount = !rltt	; Toggle TimeCount
	!rltt #= !rltt+2
	rlttLineFlag = !rltt	; Pointer to LineFlag
	!rltt #= !rltt+2
	rlttSize = !rltt
	rlttCountTime = 60	; Toggle in 60 Ticks (1 Second)


;
;	* * * * * * *       PLATFORM TASK STRUCTURE       * * * * * * *
;
	!rlpt #= 0
	rlptState = !rlpt	; Platform State
	!rlpt #= !rlpt+2
	rlptData1 = !rlpt	; DataVariable
	!rlpt #= !rlpt+2
	rlptPlatform = !rlpt	; Pointer to PlatformData
	!rlpt #= !rlpt+2
	rlptSectorData = !rlpt	; Pointer to SectorData
	!rlpt #= !rlpt+2
	rlptSize = !rlpt

;
;	* * * * * * *       PLATFORM DOOR TASK UNION STRUCTURE       * * * * * * *
;
	rlpdtHoldCount = rlptData1	; Hold Counter
	rlpdtDoor = rlptPlatform	; DoorData
	rlpdtSectorData = rlptSectorData	; SectorData
	rlpdMovement = 6	; Doors Move 6 Pixels

;
;	* * * * * * *       PLATFORM FLOOR TASK UNION STRUCTURE       * * * * * * *
;
	rlpftHeight = rlptData1	; Destination Height
	rlpftFloor = rlptPlatform	; FloorData
	rlpftSectorData = rlptSectorData	; SectorData
	rlpfMovement = 3	; Floors Move 3 Pixels
	rlpsMovement = 2	; Stairs Move 2 Pixels

;
;	* * * * * * *       PLATFORM CEILING TASK UNION STRUCTURE       * * * * * * *
;
	rlpctHeight = rlptData1	; Destination Height
	rlpctCeiling = rlptPlatform	; CeilingData
	rlpctSectorData = rlptSectorData	; SectorData
	rlpcMovement = 2	; Ceilings Move 2 Pixels

;
;	* * * * * * *       PLATFORM LIFT TASK UNION STRUCTURE       * * * * * * *
;
	rlpltHoldCount = rlptData1	; Hold Counter
	rlpltLift = rlptPlatform	; LiftData
	rlpltSectorData = rlptSectorData	; SectorData
	rlplMovement = 6	; Lifts Move 6 Pixels
	rlpmMovement = 2	; MovingFloors Move 2 Pixels


;
;	* * * * * * *       SOUND EFFECT STRUCTURE       * * * * * * *
;
	!rlse #= 0
	rlsePriority = !rlse	; Priority (Volume)
	!rlse #= !rlse+1
	rlseEffect = !rlse	; Sound Effect#
	!rlse #= !rlse+1
	rlseSize = !rlse
