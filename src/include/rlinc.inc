includeonce
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                             GLOBAL DEFINITIONS     *
;*                                                                    *
;**********************************************************************


;
;	* * * * * * *       TARGET EXECUTABLE       * * * * * * *
;
	ROM = 1	; 1=ROM Version
;
	!DEBUG #= 1*(1-ROM)	; 1=DEBUGGING Version
	!DEBUGSCR #= 1*(1-ROM)	; 1=DEBUGGING SCREEN Version
	!PROFILE #= 0*(1-ROM)	; 1=Enable DEVELOPMENT PROFILER
	!MEMTEST #= 0*(1-ROM)	; 1=Enable DEVELOPMENT MEMORY TEST
	!RAMBPINTEST #= 0*(1-ROM)	; 1=Enable DEVELOPMENT RAM BANK PIN TEST
	RECORDDEMO = 0*(1-ROM)	; 1=Enable RECORDING DEMOS
	IDLERESET = 0*(1-ROM)	; 1=Enable IDLE TIMEOUT RESET (Show Demos)


;
;	* * * * * * *       DEVELOPMENT HARDWARE       * * * * * * *
;
	SFX2 = 0	; SFX2 Hardware Interface
	WIRE = 0	; WIRE Hardware Interface
	NOAICESE = 1	; NOA ICE SE Hardware


;
;	* * * * * * *       DEVELOPMENT SOFTWARE       * * * * * * *
;
	ACCESS = 1	; 1=ACCESS Development System
	SASM = 0	; 1=SASM Development Assembler


;
;	* * * * * * *       GSU HARDWARE       * * * * * * *
;
	GSUREV1 = 0	; 1=GSU Revision 1 (StarFox 8MBit 10MHz $01)
	GSUREV1A = 0	; 1=GSU Revision 1A (StuntRaceFX 8MBit $04)
	GSUREV2 = 1	; 1=GSU Revision 2 (StarFox2 16MBit $04)
	GSUFAST = 1	; 1=HighSpeed GSU Operations (21MHz)


;
;	* * * * * * *       ENGINE FEATURES       * * * * * * *
;
	useSKY = 1	; 1=Enable SKY Texture Mapping
	useFLOORS = 0	; 1=Enable FLOOR/CEILING Texture Mapping
	useHIGHDETAIL = 0	; 1=Enable HIGH DETAIL
	useTEXTURES = 0	; 1=Enable WALL Texturing


;
;	* * * * * * *       ENGINE TESTING/DEBUGGING       * * * * * * *
;
	!useTESTMOVEXY #= 0*!DEBUG	; 1=Enable MoveXY Testing
	!useTESTLEVELOBJ #= 0*!DEBUG	; 1=Enable Level Object Testing
	!useTESTTARGET #= 0*!DEBUG	; 1=Enable Targetting Testing
;
	!useCHECKBSPDATA #= 0*!DEBUG	; 1=Enable BSP AreaSegList Overflow Checking
	!useCHECKVSEGS #= 0*!DEBUG	; 1=Enable VisibleSegmentList Overflow Checking
	!useCHECKWALLPLOTDATA #= 0*!DEBUG	; 1=Enable WallPlotData Pixel Range Checking
	!useCHECKFLOORPLOTDATA #= 0*!DEBUG	; 1=Enable FloorPlotData Pixel Range Checking
	!useCHECKOBJPLOTDATA #= 0*!DEBUG	; 1=Enable ObjPlotData Pixel Range Checking
;
	!useCHECKSECTOROBJECTS #= 0*!DEBUG	; 1=Enable Checking Sector Object Lists
;
	!useCHECKSOUND #= 0*!DEBUG	; 1=Enable Checking SoundCommands
