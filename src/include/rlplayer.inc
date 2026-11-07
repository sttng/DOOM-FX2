includeonce
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                    PLAYER STRUCTURE DEFINITIONS    *
;*                                                                    *
;**********************************************************************


;
;	* * * * * * *       JOYSTICK BUTTON CONFIGURATION       * * * * * * *
;
	pjFORWARD = joyUP	; FORWARD
	pjREVERSE = joyDOWN	; REVERSE
	pjROTATELEFT = joyLEFT	; ROTATE LEFT
	pjROTATERIGHT = joyRIGHT	; ROTATE RIGHT
	pjSTRAFELEFT = joyL	; STRAFE LEFT
	pjSTRAFERIGHT = joyR	; STRAFE RIGHT
	useFX3CONTROLS = 1	; 1 = The Ultimate DOOM (FX3) controls: <LEFT>/<RIGHT> turn while
				;     <L>/<R> strafe, FX3 walk/run/turn speeds
				; 0 = the original controls (no turning while strafing)
	if useID8 == 0
	pjFIRE = joyX	; FIRE
	pjRUN = joyA	; RUN
	pjUSE = joyB	; USE/OPERATE/OPEN
	pjWEAPON = joyY	; WEAPON CYCLE
	endif
	if useID8 != 0
	pjFIRE = joyY	; FIRE
	pjRUN = joyB	; RUN
	pjUSE = joyA	; USE/OPERATE/OPEN
	pjWEAPON = joyX	; WEAPON CYCLE
	endif
	pjAUTOMAP = joySELECT	; AUTOMAP TOGGLE
	pjPAUSE = joySTART	; PAUSE
;
;	* * * * * * *       MOUSE BUTTON CONFIGURATION       * * * * * * *
;
;	(original, not used: rlplayer.asm ReadMouse2 maps left = fire, right = use)
;
	pmFIRE = joyX	; FIRE
	pmUSE = joyA	; USE/OPERATE/OPEN
