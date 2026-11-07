includeonce
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                                             GLOBAL DEFINITIONS     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rlinc.inc"


;
;	* * * * * * *       GAME FEATURES       * * * * * * *
;
	useSOUND = 1	; 1=Enable SOUND/MUSIC
	useAUTOMAP = 1	; 1=Enable AUTOMAP
	useAUTOMAPROT = 1	; 1=Enable AUTOMAP Rotation
	useXBAND = 0	; 1=Enable XBAND Hardware
;
	usePATCH = 1	; 1=Enable PATCHES
;
	useWILLIAMS = 1	; 1=Enable WILLIAMS Changes
	useID = 1	; 1=Enable ID Changes
	useID2 = 1	; 1=Enable ID Changes2
	useID3 = 1	; 1=Enable ID Changes3
	useID4 = 1	; 1=Enable ID Changes4
	useID7 = 1	; 1=Enable ID Changes7
	useID8 = 1	; 1=Enable ID Changes8
;
	useMULTIPLAYER = 1	; 1=Enable MULTIPLAYER
	useSCOPE = 0	; 1=Enable SUPERSCOPE
	useCHEATS = 0	; 1=Enable CHEAT Codes
;
	usePAL = 0	; 1=Enable PAL Version
	useOCEAN = 0	; 1=Enable OCEAN Version
	useIMAGINEER = 0	; 1=Enable IMAGINEER Version


;
;	* * * * * * *       FLUFF SCREENS       * * * * * * *
;
	useSYSINFO = 0	; 1=Enable SystemInfo Sequence
	useLOGO = 0	; 1=Enable Logo Sequence
	useLOGO2 = 0	; 1=Enable Logo2 Sequence (the "R&D" logo; off in this port)
	useSCULPT = 0	; 1=Enable Sculptured Sequence
	useTITLE = 1	; 1		; 1=Enable Title Sequence
	useSCORE = 1	; 1		; 1=Enable Score Sequence
	useSTARTSCREEN = 1	; 1=Enable Start Screen (this port: the PC start-up log, in the original legal page's slot)
;
	!TQIDLE = 0	; 1=copy screen thirds out of GSU RAM only while the GSU is halted
	if canreadfile1("src/TQIDLE.opt", 0)	;   (rlirq.asm _RLCopyThird; hardware test build:
	!TQIDLE = 1	;   the file src/TQIDLE.opt exists)
	endif
	useDEMO1 = 0	; 1=Enable Demo1 Sequence
	useDEMO = useDEMO1


;
;	* * * * * * *       LEVELS       * * * * * * *
;
	!useE1M1ONLY #= 0	; 1=Enable E1M1 ONLY
	incsrc "levels.inc"	; !use<level> flags of the data set
	!__l #= 1
	while !__l < !NUMLEVELS
	!{use!{lvl!__l}} #= !{use!{lvl!__l}}*(1-!useE1M1ONLY)
	!__l #= !__l+1
	endwhile
