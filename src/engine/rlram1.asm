	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                                  RAM1 MEMORY       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/rlsound.inc"

	; extern RAM1Start,RAM1End


	%section(RAM1GSUVECTORS)

	%section(RAM1)

;
;	* * * * * * *       RAM1 VARIABLES       * * * * * * *
;
RAM1Start:

OAMA:	%ds(MaxOAMs*4)	; OAM Data Block A
OAMAA:	%ds(((MaxOAMs/16))*4)
OAMB:	%ds(RLMaxCutSprOAMs*4)

RGBData:	%ds(256*2)	; 512 bytes of RGB Data
RGBXFer:	%ds(1)	; $FF = Transfer RGB Data

JOY1:	%ds(1*2)	; Joystick Controller I
JOY1Stat:	%ds(1)	; $00=JOYSTICK,$01=MOUSE,$FF=INVALID!
MOUSE1X:	%ds(1)	; Mouse1 X Displacement
MOUSE1Y:	%ds(1)	; Mouse1 Y Displacement

View:	%ds(1)	; View being Displayed
ViewB:	%ds(1)	; View being Built

VBlankCount:	%ds(1)	; VBlank Counter (GameLoop)
	if usePAL != 0
VBlankCountF:	%ds(1)	; VBlank Counter Fraction
	endif

;
;	>>>   XFER VARIABLES   <<<
;
XFerNasty:	%ds(1)	; $FF=Transfer during ScreenON!

;
;	>>>   HARDWARE SHADOWS   <<<
;
INIDISP_S:	%ds(1)	; INIDISP Shadow
HDMAEN_S:	%ds(1)	; HDMAEN Shadow


;
;	>>>   MUSIC DRIVER VARIABLES   <<<
;
_MDSerialNum:	%ds(1)	; APU Serial Synchronization Number
_MDModule:	%ds(1*2)	; Resident Module# Loaded
_MDSong:	%ds(1*2)	; Song# Loaded
_MDLocks:	%ds(1*2)	; MusicDriver Semaphores


;
;	>>>   RGB COLOUR VARIABLES   <<<
;
RLRGBLock:	%ds(1*2)	; 0=RGB Palettes UnLocked,-1=Locked
RLRGBPtr:	%ds(1*2)	; Address of RGB Table to XFer (0=None)
RLRGBAnim0:	%ds(1*2)	; Base RGB AnimTable Index
RLRGBAnim:	%ds(1*2)	; Current RGB AnimTable Index
RLRGBCount:	%ds(1*2)	; Counter for Current RGB Entry
RLRGBPickCount:	%ds(1*2)	; #Pick Ups
RLRGBHitCount:	%ds(1*2)	; #Hits

;
;	>>>   PLAYER VARIABLES   <<<
;
Level:	%ds(1*2)	; Current Level
_PlayerBullets:	%ds(1*2)	; #Bullets (Pistol/ChainGun)
_PlayerShells:	%ds(1*2)	; #Shells (ShotGun)
_PlayerRockets:	%ds(1*2)	; #Rockets (Rocket)
_PlayerCells:	%ds(1*2)	; #Cells (Plasma/BFG)
_PlayerHealth:	%ds(1*2)	; Player's Health
_PlayerArmor:	%ds(1*2)	; Player's Armor
_PlayerKeys:	%ds(1)	; Player's Keys
_PlayerArms:	%ds(1)	; Player's Weapons
_PlayerWeapon:	%ds(1*2)	; Player's Selected Weapon
_PlayerBackPack:	%ds(1*2)	; Player's BackPack
;
PlayerFaceOld:	%ds(1*2)	; OLD Player's Face
PlayerKeysOld:	%ds(1)	; OLD Player's Keys
PlayerArmsOld:	%ds(1)	; OLD Player's Arms
;
PlayerLevelCount:	%ds(1)	; #Ticks until 1 Second
PlayerLevelTime:	%ds(1*2)	; #Seconds in current Level
;
PlayerJoy0:	%ds(1*2)	; Player's Old JoyStick Bits


	if (RECORDDEMO|useDEMO) != 0
;
;	>>>   DEMO VARIABLES   <<<
;
DemoIndex:	%ds(1*2)	; Index into DemoData
DemoJOY:	%ds(1*2)	; JOYStickBits
DemoCount:	%ds(1*2)	; #Cycles
	endif


;
;	>>>   MENU VARIABLES   <<<
;
MenuSkillLevel:	%ds(1*2)	; 0=Easy,1=Med,2=Hrd,3=UltVio,4=Ngtmre


;
;	>>>   SCORE VARIABLES   <<<
;
ScoreSecret:	%ds(1*2)	; -1=Player Got Episode Secret
ScoreLevelDone:	%ds(1*2)	; (this port) the level just finished (its name on the score page)
SaveLoadPending:	%ds(1*2)	; slot+1 of a game being loaded (savegame.asm)
SaveSavePending:	%ds(1*2)	; slot+1 of a game being saved (savegame.asm: finished after the level restart)
SaveMsgPending:	%ds(1*2)	; message after a save: 1 = saved, 2 = no room (savegame.asm SaveMessage)


;
;	>>>   MISCELLANEOUS VARIABLES   <<<
;
	if IDLERESET != 0
IdleCount:	%ds(1*2)	; Idle Counter
	endif


;
;	>>>   SCREEN THIRDS QUEUE (this port, rlirq.asm _RLCopyThird)   <<<
;
TQCount:	%ds(1*2)	; Thirds in the WRAM buffers, waiting for VRAM (0-2)
TQHead:	%ds(1*2)	; WRAM buffer of the next third to send (0/1)
TQSrc:	%ds(1*2)	; (_RIBDrawXFer: address of that buffer)
TQStrip:	%ds(1*2)	; Strips of the drawn third copied so far (0-8)
TQMiscTokens:	%ds(1*2)	; Frames the GSU may start (its tasks phase) before the next vars swap
TQUpLeft:	%ds(1*2)	; Strips of the third being uploaded still to send
WeaponWait:	%ds(1*2)	; Nonzero: a weapon to send waited one phase D (_RIBDrawD)
TQNoCopy:	%ds(1*2)	; Nonzero: _RLCopyThird copies nothing (the GSU start before a VRAM upload)

;
;	* * * * * * *       VARIABLE BLOCK TRANSFERRED TO GSU       * * * * * * *
;
RLSNESXVars:
FPSCount:	%ds(1*2)	; FramesPerSecond Counter
;
PlayerJoy:	%ds(1*2)	; Player's JoyStick Bits
PlayerMouseX:	%ds(1*2)	; X Displacement
PlayerMouseY:	%ds(1*2)	; Y Displacement
;
WeaponTypeBuilt:	%ds(1*2)	; Type of Weapon Built (wtType)
;
VBlankTotal:	%ds(1)	; VBlank Counter Total
	%ds(1)	; UNUSED
RLSNESXVarsE:

;
;	* * * * * * *       VARIABLE BLOCK TRANSFERRED FROM GSU       * * * * * * *
;
RLSNESGSUXVars:
	%ds($1E)	; ds.b (RLGSUXVarsE-RLGSUXVars)
	assert $1E == (RLGSUXVarsE-RLGSUXVars), "cached ds size is stale (tools/fixup.py)"
	assert (-$6FFABA&$FFFFFF) == ((RLSNESGSUXVars-RLGSUXVars)&$FFFFFF), "cached constant RLSNESGSUXVarsO is stale (tools/fixup.py)"
	!RLSNESGSUXVarsO = (-$6FFABA)	; to get GSU  from SNES
;
;	>>>   TABLE OF SOUND EFFECTS COMMANDS   <<<
;
RLSNESSounds:	%ds((MaxRLSounds*rlseSize))	; SNES Sound Effects Table
;
;	>>>   RUMBLE (this port, rumble.asm)   <<<
;
RLSNESRumbleN:	%ds(1*2)	; The GSU's requests of this frame (count, then
RLSNESRumbles:	%ds(MaxRLRumbles)	;  the requests: RLNumRumbles, RLGSURumbles)
RumbleFx:	%ds(MaxRumbles*2)	; Effect# per slot (0 = free)
RumblePos:	%ds(MaxRumbles*4)	; Per slot: left, right wave offset (0 = ended)
RumbleOut:	%ds(1*2)	; Motor strengths: right.4 | left.4
RumbleBits:	%ds(1*2)	; Bits being sent
RumbleSum:	%ds(1*2)
RumbleTemp:	%ds(1*2)


;
;	>>>   VARIABLES PRESERVED BETWEEN RESETS   <<<
;
VarsCheckSum:	%ds(1*2)	; CHECKSUM for RESTART

Vars:
RandSentry:	%ds(1*4)	; RAND sentry for RESTART
;
;	>>>   GAME GLOBALS   <<<
;
_SoundsOn:	%ds(1*2)	; $FFFF=Sound Effects ON, 0=OFF
_MusicOn:	%ds(1*2)	; $FFFF=Music ON, 0=OFF
_RumbleOn:	%ds(1*2)	; (this port) $FFFF=Rumble ON, 0=OFF
_SkillLevel:	%ds(1*2)	; 0=Easy,1=Med,2=Hrd,3=UltVio,4=Ngtmre
;
;	>>>   RESET COUNTER   <<<
;
_ResetCount:	%ds(1*2)	; Reset Counter
	if usePAL == 0
_TitleCount:	%ds(1*2)	; Title Counter
	endif
;
VarsEnd:

	if usePAL != 0
_TitleCount:	%ds(1*2)	; Title Counter
	endif


;
;	>>>   CUTTER SPRITE VARIABLES   <<<
;
WeaponPriMask:	%ds(1*2)	; PriorityMask
_MCHRGDMASP:	%ds(1*2)	; StackPointer
;
	%ds(64)	; NMIs,IRQs,ETC.
_WeaponDEFGDMAStack:	%ds(((RLMaxCutSprCHRs/8)+1)*((8*2)+2))	; DEF GDMA Stack


;
;	>>>   SOUND VARIABLES   <<<
;
SoundQueue:	%ds((MaxRLRSounds*rlserSize))	; Regular SoundEffects Queue
SoundQueueEnd:
;
TSounds:	%ds((MaxRLTSounds*rlsetSize))	; Turbo SoundEffects
;
_MusicTurboTable:	%ds((128*rlsettSize))	; Turbo SoundEffects TurboTable


;
;	>>>   MOUSE IN PORT 2 / MOUSE TURNING (this port)   <<<
;
JOY2:	%ds(1*2)	; Mouse in port 2: buttons (bit 7 = right, bit 6 = left)
JOY2Stat:	%ds(1)	; Port 2: $01=MOUSE, $FF=no mouse
MOUSE2X:	%ds(1)	; Mouse2 X Displacement
MOUSE2Y:	%ds(1)	; Mouse2 Y Displacement
MouseTmp:	%ds(1*2)	; Mouse turn conversion temporary
PlayerMouseTurn:	%ds(1*2)	; Mouse turn since the last frame (angle units)
;
;	>>>   TITLE SCREEN MELT (this port)   <<<
;
MeltRnd:	%ds(1*2)	; RandomTable index
MeltY:	%ds(33*2)	; Column offsets (<0: frames still to wait, 224: gone)
MeltV:	%ds(33*2)	; Column BG VOFS (MeltV+2..: the offset-per-tile table)
;
;	>>>   TITLE MENUS (this port)   <<<
;
TitleLevel:	%ds(1*2)	; New Game from the title menu: the first level (episode*9)
TitleLoad:	%ds(1*2)	; <>0: Load Game from the title menu (LoadGame done)
TMenuNum:	%ds(1*2)	; Title menu shown (0-3)
TMenuItem:	%ds(1*2)	; Its item under the skull
TMenuMax:	%ds(1*2)	; Its #items
TMenuJoy:	%ds(1*2)	; Joypad bits of the last frame
TMenuFrame:	%ds(1*2)	; Frame counter (skull animation)
TMenuPtr:	%ds(1*2)	; TTLMenuData offset of the menu shown
TMenuTmp:	%ds(1*2)	; Scratch
TMenuTmp2:	%ds(1*2)	; Scratch

;
;	* * * * * * *       END OF RAM1 VARIABLES       * * * * * * *
;
RAM1End:
