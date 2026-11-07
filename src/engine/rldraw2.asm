	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                   ENGINE DRAW MISCELLANEOUS MODULE                 *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"

	; public _RLDrawMiscA
	; public _RLDrawMiscB
	; public _RLDrawMiscC


	%section(ENGINE_GSUCODE)
	arch superfx

;
;	* * * * * * *       REALITY_ENGINE DRAW MISCELLANEOUS A       * * * * * * *
;

;	align	16,(_RLDrawMiscA-_RLDrawMiscAAlign)&$0f
_RLDrawMiscA:
;
;	>>>   HANDLE MESSAGES   <<<
;
	lms r0,(MsgCount&$FFFF)	; Any Message to Display?
	dec r0
	bmi _RLDMA200	; No
	nop
	ibt r1,#((RLViewPixX/3)*0)
	ibt r2,#0
	lms r12,(MsgDataA&$FFFF)
	link #4
	iwt r15,#lo16(_RLText)
	nop
_RLDMA200:
	ibt r1,#0	; Flush Pixel Cache
	ibt r2,#0
	rpix
	if !DEBUG != 0
	ibt r0,#0	; NO ERROR!
	sm (GSUERROR&$FFFF),r0
	endif
	stop
	nop


;
;	* * * * * * *       REALITY_ENGINE DRAW MISCELLANEOUS B       * * * * * * *
;
_RLDrawMiscB:
;
;	>>>   HANDLE MESSAGES   <<<
;
	lms r0,(MsgCount&$FFFF)	; Any Message to Display?
	dec r0
	bmi _RLDMB200	; No
	nop
	iwt r1,#((RLViewPixX/3)*0)
	ibt r2,#0
	lms r12,(MsgDataB&$FFFF)
	link #4
	iwt r15,#lo16(_RLText)
	nop
_RLDMB200:
;
;	>>>   HANDLE FACES   <<<
;
	link #4
	iwt r15,#lo16(_RLAnimFace)
	nop
	ibt r1,#0	; Flush Pixel Cache
	ibt r2,#0
	rpix
	if !DEBUG != 0
	ibt r0,#0	; NO ERROR!
	sm (GSUERROR&$FFFF),r0
	endif
	stop
	nop


;
;	* * * * * * *       REALITY_ENGINE DRAW MISCELLANEOUS C       * * * * * * *
;
_RLDrawMiscC:
;
;	>>>   HANDLE MESSAGES   <<<
;
	lms r0,(MsgCount&$FFFF)	; Any Message to Display?
	dec r0
	bmi _RLDMC200	; No
	inc r0
	lms r2,(FPSCount+RLGSUSNESXVarsO&$FFFF)	; #VBlanks
;	with	r0				; Update Counter
	sub r2
	bpl _RLDMC120	; Not Finished
	nop
;	with	r0				; Finished
	sub r0
_RLDMC120:
	sms (MsgCount&$FFFF),r0	; Save Updated Counter
;
	iwt r1,#((RLViewPixX/3)*0)
	ibt r2,#0
	lms r12,(MsgDataC&$FFFF)
	link #4
	iwt r15,#lo16(_RLText)
	nop
_RLDMC200:
	ibt r1,#0	; Flush Pixel Cache
	ibt r2,#0
	rpix
	if !DEBUG != 0
	ibt r0,#0	; NO ERROR!
	sm (GSUERROR&$FFFF),r0
	endif
	stop
	nop
