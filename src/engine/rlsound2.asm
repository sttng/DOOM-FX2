	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                        ENGINE SOUND MODULE 2                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlsound.inc"
	incsrc "src/include/music.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


;
;	* * * * * * *       CALCULATE SOUND EFFECT       * * * * * * *
;
;	R3 = Address of Sound Effect Table-1
;	R4 = X Coordinate of Sound Origin
;	R6 = Y Coordinate of Sound Origin
;
;	(this port) A table address of 0 (R3 = -1) is no sound: the arch-vile's
;	fire (modVileFire) has no birth sound.  Read as a table, ROM $00:0000
;	gave an effect number past the turbo table (140); the SNES streamed
;	7936 bytes of other ROM data to the APU as that "turbo sound" and hung
;	on its last block (the game froze after an arch-vile's second attack).
;
_RLSoundEffect:
	inc r3	; No sound effect?
	beq _RLSE8000	; Yes: return (the dec below runs either way)
	dec r3
;
;	>>>   CALCULATE DISTANCE TO SOUND ORIGIN   <<<
;
	lms r0,(ViewX&$FFFF)	; Get |(ViewX - SoundOriginX)|
;	with	r0
	sub r4
	bpl _RLSE1200
	nop
;	with	r0
	not
	inc r0
_RLSE1200:
	lms r1,(ViewY&$FFFF)	; Get |(ViewY - SoundOriginY)|
	with r1
	sub r6
	bpl _RLSE1400
	nop
	with r1
	not
	inc r1
_RLSE1400:
;	from	r0				; |X| >= |Y|?
	cmp r1
	bge _RLSE1600	; Yes
	moves r0,r1	; |Y| > |X|
_RLSE1600:
	iwt r1,#1024	; Maximum Hearing Distance
;	from	r0
	cmp r1
	bge _RLSE8000-2	; Too Far Away to Hear!
;
;	>>>   CALCULATE VOLUME LEVEL   <<<
;
_RLSE2000:
	iwt r1,#$FE	; Quiescent Hearing Distance
;	from	r0
	cmp r1
	blt _RLSE3000	; Maximum Volume
;	with	r0
	lsr
;	from	r0				; R1 = Index into RL->SCN Pixel Scale
	to r1
	add r0
	with r1
	add r0
	ibt r0,#bank(RLSCNPixScale)	; Move to RL->SCN Pixel Scaling Table
	romb
	iwt r0,#lo16(RLSCNPixScale+(2*3))
;	from	r0
	to r14
	add r1
	getb
	inc r14
	to r6
	getbh
	iwt r0,#($FE<<1)	; Maximum Volume
;	from	r0
	to r1
	fmult

;
;	>>>   CALCULATE PANNING/BALANCE   <<<
;
_RLSE3000:

;
;	>>>   GET SOUND EFFECT NUMBER   <<<
;
_RLSE4000:
	ibt r0,#bank(_RLSoundEffects)	; Move to SoundEffects Bank
	romb
	move r14,r3	; Move to SoundEffect Data
_RLSE4200:
	inc r14
	getb	; Get Volume Level
	inc r14
;	with	r0				; Volume Threshold < Calculated Volume?
	sub r1	; @CMP@
	blt _RLSE4200	; Yes, keep scanning
	to r3	; R3 = Sound Effect#
	getb

;
;	* * * * * * *       ADD SOUND EFFECT       * * * * * * *
;
_RLSoundEffect2:
	with r3	; R3 = Volume.B / Effect.B
	swap
	with r3
	or r1
;
	lms r0,(RLNumSounds&$FFFF)	; Get #Sounds Added
	ibt r1,#MaxRLSounds
;	from	r0				; Too Many?
	to r4
	sub r1
	bne _RLSE7000	; No, Add One More!
	inc r0
;
;	>>>   SCAN TO FIND SOUND EFFECT TO OVERWRITE   <<<
;
_RLSE6000:
	iwt r4,#lo16(RLGSUSounds-2)	; Scan for Lowest Priority
	ibt r6,#0	; NO Lowest Priority
_RLSE6200:
	inc r4	; Next SoundEffect
	dec r1	; Finished Scanning Priorities
	bmi _RLSE6400
	inc r4
;	to	r0				; Get SoundEffect Priority
	ldb (r4)
;	with	r0				; Priority Lower than New Priority?
	sub r3
;	with	r0
	lob
;	with	r0
	sex
	bpl _RLSE6200	; No, Can't OverWrite!
;	with	r0				; Lower than Lowest Priority?
	sub r6
	bge _RLSE6200	; No
	with r6	; YES!  New Lowest Priority!
	add r0
	with r4
	bra _RLSE6200
	to r14
_RLSE6400:
	moves r6,r6	; Any SoundEffect with Lower Priority?
	with r14
	beq _RLSE8000	; No
	to r6
	from r3	; Yes!  OverWrite It!
	stw (r6)
_RLSE8000:
	jmp r11	; Return to Caller
	nop
;
;	>>>   SAVE SOUND EFFECT PARAMETERS   <<<
;
_RLSE7000:
	sbk	; Update #Sounds
;	with	r0				; Move to SoundEffect Slot
	add r0
;	umult	#rlseSize
	iwt r6,#lo16(RLGSUSounds-rlseSize)
;	with	r0
	add r6
	from r3	; Save Volume.B / Effect.B
	stw (r0)
	jmp r11	; Return to Caller
	nop

;
;	* * * * * * *       START PLAYER SOUND EFFECT       * * * * * * *
;
;	R3 = SoundEffect#
;
_RLPlayerSoundEffect:
	iwt r1,#$FF	; Volume Level (Always Highest)
	bra _RLSoundEffect2	; Add Sound Effect!
	nop
