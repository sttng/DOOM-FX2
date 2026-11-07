includeonce
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                       SOUND EFFECTS DEFINITIONS    *
;*                                                                    *
;**********************************************************************


;
;	* * * * * * *       DEFINITIONS       * * * * * * *
;
	MaxRLRSounds = 16	; Maximum RegularSound Effects
	MaxRLTSounds = 4	; Maximum TurboSound Effects


;
;	* * * * * * *       MUSIC DRIVER SEMAPHORE LOCKS       * * * * * * *
;
	mdlLock = $8000	; Lock MusicDriver


;
;	* * * * * * *       SOUND EFFECTS DATA STRUCTURE       * * * * * * *
;
	!rlsx #= 0
	rlsxVol = !rlsx	; Volume Threshold
	!rlsx #= !rlsx+1
	rlsxEffect = !rlsx	; Effect# to play when <= Volume
	!rlsx #= !rlsx+1
	rlsxSize = !rlsx


;
;	* * * * * * *       SOUND EFFECT STRUCTURE       * * * * * * *
;
;	(the labels are defined in rle.inc)
;
	!rlse #= 0
	; (dup) rlsePriority = !rlse	; Priority (Volume)
	!rlse #= !rlse+1
	; (dup) rlseEffect = !rlse	; Sound Effect#
	!rlse #= !rlse+1
	; (dup) rlseSize = !rlse


;
;	* * * * * * *       REGULAR SOUND EFFECT STRUCTURE       * * * * * * *
;
	!rlser #= 0
	rlserPriority = !rlser	; Priority (Volume)
	!rlser #= !rlser+1
	rlserEffect = !rlser	; Sound Effect#
	!rlser #= !rlser+1
	rlserSize = !rlser


;
;	* * * * * * *       TURBO SOUND EFFECT STRUCTURE       * * * * * * *
;
	!rlset #= 0
	rlsetPriority = !rlset	; Priority (Volume)
	!rlset #= !rlset+1
	rlsetEffect = !rlset	; Effect#
	!rlset #= !rlset+1
	rlsetFlags = !rlset	; Flags
	!rlset #= !rlset+1
	rlsetBWave = !rlset	; BWave#
	!rlset #= !rlset+1
	rlsetData = !rlset	; Data Address
	!rlset #= !rlset+3
	rlsetAPU = !rlset	; APU Address
	!rlset #= !rlset+2
	rlsetBytes = !rlset	; #Bytes Remaining
	!rlset #= !rlset+2
	rlsetAPUBase = !rlset	; APU BaseAddress
	!rlset #= !rlset+2
	rlsetStart = !rlset	; (this port) Data Address (low 16 bits) at the start: which sound
	!rlset #= !rlset+2
	rlsetSize = !rlset
;
;	>>>   TURBO SOUND EFFECT FLAGS   <<<
;
	rlsetfIdle = $80	; Idle
	rlsetfPlaying = $40	; Playing
	rlsetfCycle = $3F	; MASK		; Cycle Counter ($00-$3F)


;
;	* * * * * * *       TURBO SOUND EFFECT TABLE STRUCTURE       * * * * * * *
;
	!rlsett #= 0
	rlsettBWave = !rlsett	; BWave#
	!rlsett #= !rlsett+1
	rlsettData = !rlsett	; Data Address
	!rlsett #= !rlsett+3
	rlsettBytes = !rlsett	; #Bytes
	!rlsett #= !rlsett+2
	rlsettSize = !rlsett
