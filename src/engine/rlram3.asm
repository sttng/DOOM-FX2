	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                                  RAM3 MEMORY       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/rlcut.inc"

	; extern RAM3Start,RAM3End

	if !DEBUG != 0
	%section(RAM3)
	endif
	if !DEBUG == 0
	%section(RAM3)
	endif


;
;	* * * * * * *       RAM3 VARIABLES       * * * * * * *
;
RAM3Start:
;
;	>>>   PROFILER DATA BLOCK   <<<
;
	if !PROFILE != 0
RLProfileData:	; Profile DataBlock
	endif

;
;	>>>   ALL VARIABLES THAT MUST REMAIN AVAILABLE DURING DECOMP   <<<
;
	%ds(1*2)	; DECOMP MUST NOT START AT $0000!

;
;	>>>   ALL VARIABLES THAT CAN BE OVERWRITTEN DURING DECOMP   <<<
;
DeCompBuffer:	; DeComp Buffer (MUST NOT START AT $0000!!!)
;
RLVMap0:	%ds(((RLViewCharY*32))*2)	; VRAM Map for View0
RLVMap1:	%ds(((RLViewCharY*32))*2)	; VRAM Map for View1
RLStatFacesDefRAM:	%ds((4*8)*(3*4*32))	; Faces Sprites
RLStatKeysDefRAM:	%ds((6*32))	; KeyCards Sprites
RLStatArmsDefRAM:	%ds(8*(4*2*32))	; Arms Sprites

;
;	>>>   WEAPONS DATA BLOCKS   <<<
;
_WeaponOAMTable:	%ds(MaxCutImages*4)	; OAM DataIndex per Frame
_WeaponDEFGDMATable:	%ds(MaxCutImages*4)	; CHR DataStart per Frame
;
_WeaponOAMData:	%ds((MaxCutImages*RLMaxCutSprOAMs*6))	; OAM DataBlocks per Frame
_WeaponDEFGDMAData:
	%ds(MaxCutImages*((RLMaxCutSprCHRs/8)+1)*((8*2)+2))	; CHR DataBlocks per Frame

;
;	>>>   CUTTER MEMORY BLOCKS   <<<
;
_CDStack:	%ds(256)	; CharData Stack
_CDStackEnd:
_ImageTbl:	%ds((MaxCutImages*itsSize))	; CUTTER _ImageTbl
_CharData:	%ds(MaxCutCharData)	; CUTTER _CharData
_MiscData:	%ds(MaxCutMiscData)	; CUTTER _MiscData
	%align_pad(26, 32, 0)	; align 32	; MUST BE ON 32-BYTE BOUNDARY!
_CharDef:	%ds(MaxCutCharDef)	; CUTTER _CharDef


;
;	>>>   MUSIC DRIVER DECOMPRESSION BUFFER   <<<
;
_MDDeCompBuffer:	%ds($4000)	; Music DeCompression Buffer
_MDDeCompBuffer2:	; Music DeCompression Buffer


;
;	>>>   MENU DATA BLOCKS   <<<
;
MenuHDMATM:	%ds(128)	; HDMA TM Data
MenuDeCompBuffer:	%ds(8192)	; Menu DeComp Buffer


	if 0 != 0
;
;	>>>   DEMO MEMORY BLOCKS   <<<
;
DemoData:	%ds(4096)	; Recorded Joystick DemoData
	endif


;
;	* * * * * * *       END OF RAM3 VARIABLES       * * * * * * *
;
RAM3End:
