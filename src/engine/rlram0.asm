	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                                  RAM0 MEMORY       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/rlsound.inc"

	; extern RAM0Start,RAM0End

	%section(RAM0)

;
;	* * * * * * *       RAM0 VARIABLES       * * * * * * *
;
RAM0Start:

Temp:	%ds(8)	; Temporary Variable
Temp2:	%ds(8)	; Temporary Variable2
Temp3:	%ds(8)	; Temporary Variable3
Temp4:	%ds(8)	; Temporary Variable4
ITemp:	%ds(8)	; Temporary IRQ Variable

;
;	>>>   TRANSFER VARIABLES   <<<
;
XFerPtr:	%ds(1*3)	; Pointer to XFER DataTable

;
;	>>>   REALITY_ENGINE VARIABLES   <<<
;
RLFlags:	%ds(1*2)	; Engine Flags
IRQTPhase:	%ds(1*2)	; Phase of TOP IRQ Operation
IRQBPhase:	%ds(1*2)	; Phase of BOTTOM IRQ Operation
GSUPhase:	%ds(1*2)	; Phase of GSU Operation
FrameDone:	%ds(1)	; Frame Completed Flag
FrameCount:	%ds(1)	; Initial Frame Counter


;
;	>>>   MUSIC DRIVER VARIABLES   <<<
;
_MDChunkPtr:	%ds(1*3)	; Pointer within _MusicChunks


;
;	>>>   SOUND VARIABLES   <<<
;
_TSBytes:	%ds(1*2)	; #Bytes Transferred (>0 = Turbo Active!)
_TSData:	%ds(1*3)	; Pointer to Data
SoundQueueI:	%ds(1*2)	; Regular SoundEffects Queue Index
SoundQueueE:	%ds(1*2)	; Regular SoundEffects Queue End
TSoundsI:	%ds(MaxRLTSounds*2)	; Turbo SoundEffects Priority Index Order


;
;	>>>   CUTTER SPRITE VARIABLES   <<<
;
_CDOfst:	%ds(1*2)	; CharData Index
_CDSP:	%ds(1*2)	; CharData StackPointer
_CDMode:	%ds(1*2)	; CharData DeCompressor Mode
_CDNumDups:	%ds(1*2)	; CharData Number of Duplicates
_CDNumReps:	%ds(1*2)	; CharData Number of Repeats
_CDCharNum:	%ds(1*2)	; CharData Character Number
_CDCharNumNT:	%ds(1*2)	; CharData Character Number (Non-Transparent)
_OAMI:	%ds(1*2)	; OAM/OAMData Index
_CHRNum:	%ds(1*2)	; Current VRAM Character#
_DEFGDMASP:	%ds(1*2)	; MCHR DEF GDMA StackPointer

;
;	>>>   WEAPON VARIABLES   <<<
;
WeaponTypeOld:	%ds(1*2)	; OLD Type of Weapon (wtType)
WeaponFrameOld:	%ds(1*2)	; OLD Weapon Frame (CutSprite#)
WeaponXOld:	%ds(1*2)	; OLD Weapon X Coordinate
WeaponYOld:	%ds(1*2)	; OLD Weapon Y Coordinate
WeaponNextOld:	%ds(1*2)	; OLD Next Weapon (wtType)
WeaponDEFGDMA:	%ds(1*2)	; Address of GDMA Stack for DEFs
WeaponDEFGDMABytes:	%ds(1*2)	; #Bytes of GDMAStackData to DMA
WeaponOAMBytes:	%ds(1*2)	; #Bytes of OAM Data to DMA
WeaponOAMBytesOld:	%ds(1*2)	; OLD #Bytes of OAM Data to DMA
WeaponIRQBuildPhase:	%ds(1*2)	; Index into WeaponIRQBuildPhaseCode Table
WeaponBuildPhase:	%ds(1*2)	; Index into WeaponBuildPhaseCode Table
WeaponBuildList:	%ds(1*2)	; Pointer to WeaponFrame List
WeaponBuildFrame:	%ds(1*2)	; Current WeaponFrame Being Built
WeaponBuildLeft:	%ds(1*2)	; #Frames Left to Build
;
WeaponCharDefSize:	%ds(1*2)	; #Bytes of WeaponData .CHARDEF Remaining
WeaponCharDefAddr:	%ds(1*3)	; Address of WeaponData .CHARDEF
WeaponCharDefWAddr:	%ds(1*2)	; Address of WeaponData .CHARDEF WRAM

;
;	>>>   AUTOMAP VARIABLES   <<<
;
AutoMapModeOld:	%ds(1*2)	; OLD AutoMapMode
	if !DEBUGSCR != 0
DebugScreenOld:	%ds(1*2)	; OLD Debugging Screen
	endif

;
;	>>>   MENU VARIABLES   <<<
;
MenuData:	%ds(1*4)	; Pointer to MenuData
MenuItem:	%ds(1*2)	; Current Menu Item
MenuJoyOld:	%ds(1*2)	; Old Joystick Bits
MenuMaxItem:	%ds(1)	; Maximum Menu Item


;
;	* * * * * * *       END OF RAM0 VARIABLES       * * * * * * *
;
RAM0End:
