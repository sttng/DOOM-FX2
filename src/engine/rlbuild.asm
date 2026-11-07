	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       ENGINE BUILD VIEW MODULE                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"

	; public _RLBuildA
	; public _RLBuildB
	; public _RLBuildC
	; public _RLBuild


	%section(ENGINE_GSUCODE)
	arch superfx

;
;	* * * * * * *       REALITY_ENGINE BUILD       * * * * * * *
;
_RLBuildC:
	if useHIGHDETAIL != 0
	iwt r3,#((RLViewPixX/3)*2)	; Minimum X Coordinate
	iwt r4,#((RLViewPixX/3)*3)	; Maximum X Coordinate
	endif
	if useHIGHDETAIL == 0
	ibt r3,#((RLViewPixX/3)*2)/2	; Minimum X Coordinate
	ibt r4,#((RLViewPixX/3)*3)/2	; Maximum X Coordinate
	endif
	bra _RLBuild
	nop

_RLBuildB:
	if useHIGHDETAIL != 0
	ibt r3,#((RLViewPixX/3)*1)	; Minimum X Coordinate
	iwt r4,#((RLViewPixX/3)*2)	; Maximum X Coordinate
	endif
	if useHIGHDETAIL == 0
	ibt r3,#((RLViewPixX/3)*1)/2	; Minimum X Coordinate
	ibt r4,#((RLViewPixX/3)*2)/2	; Maximum X Coordinate
	endif
	bra _RLBuild
	nop

_RLBuildA:
	if useHIGHDETAIL != 0
	ibt r3,#((RLViewPixX/3)*0)	; Minimum X Coordinate
	ibt r4,#((RLViewPixX/3)*1)	; Maximum X Coordinate
	endif
	if useHIGHDETAIL == 0
	ibt r3,#((RLViewPixX/3)*0)/2	; Minimum X Coordinate
	ibt r4,#((RLViewPixX/3)*1)/2	; Maximum X Coordinate
	endif

;
;	>>>   REALITY_ENGINE BUILD DISPLAY   <<<
;
_RLBuild:
	lms r0,(AutoMapMode&$FFFF)	; AUTOMAP Active?
	if useHIGHDETAIL != 0
	lm r1,(DetailLevel&$FFFF)	; DETAIL Level
	endif
	sms (RLMinPixX&$FFFF),r3	; Save Minimum X Coordinate
	sms (RLMaxPixX&$FFFF),r4	; Save Maximum X Coordinate
	if useHIGHDETAIL != 0
	dec r1	; Low/High Detail?
	bmi _RLBuild200	; High
	with r3	; Low
	lsr
	with r4
	lsr
_RLBuild200:
	sm (RLMinPixX2&$FFFF),r3	; Save Minimum X Coordinate for LOWDETAIL
	sm (RLMaxPixX2&$FFFF),r4	; Save Maximum X Coordinate for LOWDETAIL
	endif
	dec r0
	iwt r0,#lo16(_RLBuildTrace)	; BUILD DISPLAY
	ibt r8,#bank(_RLBuildTrace)	; Begin Execution of Next Code
	bmi _RLBuild800	; No
	nop
	if !DEBUG != 0
	ibt r0,#0	; NO ERROR!
	sm (GSUERROR&$FFFF),r0
	endif
	stop	; AUTOMAP ACTIVE!
	nop
_RLBuild800:
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	* * * * * * *       BUILD COMPLETED       * * * * * * *
;
_RLBuildDone:
	stop
	nop
