	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                         ENGINE SOUND MODULE                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/rlsound.inc"
	incsrc "src/include/music.inc"


	%section(LEVEL)

;
;	* * * * * * *       INITIALIZE GSU SOUND COMMANDS       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitSound:
	rep #$20		; mode 'A!'
	lda.w #0	; NO Sounds to Process
	sta.l RLNumSounds
;
;	>>>   INITIALIZE MUSIC DRIVER SEMAPHORE LOCKS   <<<
;
	stz.w _MDLocks	; MusicDriver Semaphore Locks
;
;	>>>   INITIALIZE REGULAR SOUND EFFECTS   <<<
;
	stz.b SoundQueueI	; Empty Regular SoundEffects Queue
	stz.b SoundQueueE
;
;	>>>   INITIALIZE TURBO SOUND EFFECTS   <<<
;
	lda.w #($FF<<8)|rlsetfIdle	; BWAVE# / IDLE
	!rlset #= 0
	for __rep = 0..MaxRLTSounds
	sta.w TSounds+rlsetFlags+(!rlset*rlsetSize)
	!rlset #= !rlset+1
	endfor

	!rlset #= 0
	!rlapu #= BlastBufferAddress
	for __rep = 0..MaxRLTSounds
	lda.w #lo16(!rlapu)	; APUBASE
	sta.w TSounds+rlsetAPUBase+(!rlset*rlsetSize)
	!rlset #= !rlset+1
	!rlapu #= !rlapu+((BlastBufferSize/MaxRLTSounds)/9*9)
	endfor

	!rlset #= 0
	for __rep = 0..MaxRLTSounds
	lda.w #(!rlset*rlsetSize)	; PRIORITY INDEX ORDER
	sta.b TSoundsI+(!rlset*2)
	!rlset #= !rlset+1
	endfor
;
	rtl



	%section(ENGINE_RAMCODE)

;
;	* * * * * * *       HANDLE TURBO SOUND EFFECTS       * * * * * * *
;
	; dbr 0
	; dpr 0
	; mode 'AX'
_RLIRQUpdateTSounds:
;
;	>>>   ANY TURBO SOUNDS TO PROCESS?   <<<
;
	bit.w _MDLocks	; MusicDriver Locked?
	bmi _RIUTS800	; Yes, Can't Activate Turbo!
;
	!rlset #= 0
	for __rep = 0..MaxRLTSounds
	bit.w TSounds+rlsetFlags-1+(!rlset*rlsetSize)	; TurboSound Active?
	db $30,$05	; bmi *+5
	lda.w TSounds+rlsetBytes+(!rlset*rlsetSize)	; #Bytes Remaining to Transfer
	bne _RIUTS1000	; ACTIVATE TURBO!
	!rlset #= !rlset+1
	endfor
	bra _RIUTS2000	; UPDATE TURBO SOUNDS NOW
_RIUTS800:
	rts
;
;	>>>   ACTIVATE TURBO   <<<
;
_RIUTS1000:
	sep #$20		; mode 'a!'
	lda.w _MDSerialNum	; Has the music driver taken the last command?
	cmp.w APUIO2	; (this port: otherwise both could be lost)
	beq _RIUTS1050
	rep #$20		; mode 'A!'
	rts	; No: try again at the next IRQ
_RIUTS1050:
	sep #$20		; mode 'a!'
	lda.b #DCOM_SLOW_BLAST	; Activate Turbo
	xba
	lda.w _MDSerialNum	; Get New Serial#
	inc a
	bmi _RIUTS1100
	lda.b #$80
_RIUTS1100:
	sta.w _MDSerialNum	; Save New Serial#
	sta.w _MDLocks	; Activate Turbo
	rep #$20		; mode 'A!'
	ldx.w #(BlastBufferAddress+BlastBufferSize-3)	; APU ADDRESS
	sta.w APUIO2
	stx.w APUIO0
;
;	>>>   PROCESS TURBO SOUNDS   <<<
;
_RIUTS2000:
	sep #$10		; mode 'x!'
	!rlset #= 0
	for __rep = 0..MaxRLTSounds
	ldy.w TSounds+rlsetFlags+(!rlset*rlsetSize)	; TurboSound Active?
	db $30,$05	; bmi *+5	; No
	ldx.b #(!rlset*rlsetSize)
	jsr.w _RLIRQUpdateTSound	; Process TurboSound Effect
	!rlset #= !rlset+1
	endfor
;
;	>>>   DEACTIVATE TURBO   <<<
;
	ldx.w _MDLocks	; Turbo Activated?
	beq _RIUTS2800	; No!
	stz.w _MDLocks	; Yes, DeActivate Turbo
	stx.w _MDSerialNum	; Restore Turbo Serial#
	stz.w APUIO0
	stx.w APUIO2
_RIUTS2800:
	rep #$10		; mode 'X!'
	rts


;
;	* * * * * * *       HANDLE ONE TURBO SOUND EFFECT       * * * * * * *
;
;	.X = Offset into TSounds
;
	; dbr 0
	; dpr 0
	; mode 'Ax'
_RIUT1000:
	jmp.w _RIUT6000
_RLIRQUpdateTSound:
;
;	>>>   ANY MORE DATA TO LOAD?   <<<
;
;_RIUT2000
	lda.w TSounds+rlsetBytes,x	; #Bytes Remaining to Transfer
	beq _RIUT1000	; Nothing to Transfer!
	cmp.w #111	; 126			; > Max #Bytes to Transfer?
	bcc _RIUT2200	; No
	lda.w #111	; Yes!  Use Max #Bytes
_RIUT2200:
	pha	; Save #Bytes to Transfer
;
;	>>>   SEND TRANSFER ADDRESS   <<<
;
;_RIUT3000
	ldy.w _MDSerialNum	; Get Serial#
_RIUT3200:
	cpy.w APUIO2	; Wait for MusicDriver
	bne _RIUT3200
	iny	; New Serial#
	bmi _RIUT3300
	ldy.b #$80
_RIUT3300:
	lda.w TSounds+rlsetAPU,x	; APU ADDRESS
	sta.w APUIO0
	sty.w APUIO2
	lda.w TSounds+rlsetData,x	; DATA ADDRESS
	sta.b _TSData
_RIUT3400:
	cpy.w APUIO2	; Wait for Acknowledge
	bne _RIUT3400
	ldy.w TSounds+rlsetData+2,x	; DATA BANK
	sty.b _TSData+2
;
;	>>>   TRANSFER NEXT BLOCK   <<<
;
;_RIUT4000
	pla	; Get #Bytes to Transfer
	sta.b _TSBytes
;
	ldy.b #%00001111	; 160 Pixels, GSU has RAM, SNES has ROM, 256 Colour
;	ifn	DEBUG
;	sty	SCR_XS				; XSLV Shadow
;	endif
	sty.w sfxSCR
;
	ldy.b #0	; Data Index
_RIUT4200:
	lda.b [_TSData],y	; Bytes 0/1
	sta.w APUIO0
	iny
	iny
	sep #$20		; mode 'a!'
	lda.b [_TSData],y	; Byte 2
	sta.w APUIO3
	iny
	sty.w APUIO2	; Serial#
	rep #$20		; mode 'A!'
_RIUT4400:
	cpy.w APUIO2	; Wait for Acknowledge
	bne _RIUT4400
	cpy.b _TSBytes	; Finished Block?
	bne _RIUT4200	; No, Keep Transferring
	sty.w _MDSerialNum	; Yes, Save New Synchronized Serial#
;
	ldy.b #%00011111	; 160 Pixels, GSU has ROM/RAM, 256 Colour
;	ifn	DEBUG
;	sty	SCR_XS				; XSLV Shadow
;	endif
	sty.w sfxSCR
;
;	>>>   UPDATE #BYTES REMAINING   <<<
;
;_RIUT5000
	lda.w TSounds+rlsetBytes,x	; #Bytes -= #Bytes Transferred
	sec
	sbc.b _TSBytes
	sta.w TSounds+rlsetBytes,x
	beq _RIUT6000	; Finished Transferring!
;
;	>>>   UPDATE TRANSFER VARIABLES   <<<
;
	ldy.b _TSBytes	; APUAddress += #Bytes Transferred
	tya
	clc
	adc.w TSounds+rlsetAPU,x
	sta.w TSounds+rlsetAPU,x
;
	tya	; DataAddress += #Bytes Transferred
;	clc
	adc.b _TSData
	sta.w TSounds+rlsetData,x
	bcc _RIUT5600
	inc.w TSounds+rlsetData+2,x
_RIUT5600:
	ldy.w TSounds+rlsetFlags,x	; Ready to Start Playing?
	cpy.b #4	; #Minimum LoadCycles
	bcc _RIUT8000	; No

;
;	>>>   START PLAYING TURBO SOUND EFFECT   <<<
;
_RIUT6000:
	bit.w TSounds+rlsetFlags-1,x	; Already Playing Sound?
	bvs _RIUT8000	; Yes
;
	rep #$10		; mode 'X!'
	phx
	txa	; Queue TurboSound Initialization
	ora.w #$8000
	jsr.w _RLIRQQueueSound
	plx
	bcs _RIUT9000	; Queue Full!
;
	phx
	lda.w TSounds+rlsetPriority,x	; Queue Priority/Effect#
	jsr.w _RLIRQQueueSound
	plx
	bcs _RIUT9000	; Queue Full!
;
	sep #$30		; mode 'ax!'
	lda.b #rlsetfPlaying	; Now Playing Sound!
	sta.w TSounds+rlsetFlags,x
	rep #$20		; mode 'A!'
;
;	>>>   WAIT FOR SOUND TO FINISH PLAYING   <<<
;
_RIUT8000:
	inc.w TSounds+rlsetFlags,x	; PlayCycle++
	rts
;
;	>>>   CAN'T QUEUE SOUND EFFECT!   <<<
;
_RIUT9000:
	sep #$10		; mode 'x!'
	rts


;
;	* * * * * * *       HANDLE REGULAR SOUND EFFECTS       * * * * * * *
;
	; dbr 0
	; dpr 0
	; mode 'AX'
_RLIRQUpdateSounds:
	bit.w _MDLocks	; MusicDriver Locked?
	bmi _RIUSS900	; Yes
	lda.w #4	; Maximum #SoundEffects to Send
	sta.b _TSBytes
	ldx.b SoundQueueI	; Regular SoundEffects Queue Index
_RIUSS200:
	cpx.b SoundQueueE	; Any More Regular SoundEffects Queued?
	beq _RIUSS900	; No
	ldy.w SoundQueue+rlserPriority,x	; Regular/TURBO SoundEffect?
	bpl _RIUSS500	; REGULAR
;
;	>>>   TURBO SOUNDEFFECT INITIALIZATION   <<<
;
	tyx	; APU BASEADDRESS
	ldy.w TSounds+rlsetAPUBase+$8000,x
	lda.w #DCOM_BLAST_ADDR
	jsl.l _SendDriverCommandQuick
	bcs _RIUSS800	; TimeOut!  Don't Empty from Queue!
;
	ldy.b SoundQueueI	; BWAVE#
	ldx.w SoundQueue+rlserPriority,y
	ldy.w TSounds+rlsetBWave+$8000,x
	lda.w #DCOM_SETWAVEASBLAST
	jsl.l _SendDriverCommandQuick
	bcc _RIUSS700
	bra _RIUSS800	; TimeOut!  Don't Empty from Queue!
;
;	>>>   REGULAR SOUNDEFFECT   <<<
;
_RIUSS500:
	lda.w #DCOM_SET_NEXT_EFFECT_VOL	; VOLUME LEVEL
	jsl.l _SendDriverCommandQuick
	bcs _RIUSS800	; TimeOut!  Don't Empty from Queue!
	ldx.b SoundQueueI
	ldy.w SoundQueue+rlserEffect,x	; EFFECT NUMBER
	lda.w #DCOM_START_EFFECT
	jsl.l _SendDriverCommandQuick
	bcs _RIUSS800	; TimeOut!  Don't Empty from Queue!
;
;	>>>   NEXT REGULAR SOUNDEFFECT   <<<
;
_RIUSS700:
	ldx.b SoundQueueI	; Empty SoundEffect from Queue
	inx
	inx
	cpx.w #lo16(SoundQueueEnd-SoundQueue)	; WrapAround?
	bne _RIUSS750	; No
	ldx.w #0	; Yes!
_RIUSS750:
	stx.b SoundQueueI
	dec.b _TSBytes	; One More SoundEffect Sent
	bne _RIUSS200	; We Can Send More!
;
;	>>>   TIMEOUT ERROR!   <<<
;
_RIUSS800:
;
;	>>>   ALL SOUNDEFFECTS HANDLED   <<<
;
_RIUSS900:
	rts


;
;	* * * * * * *       UPDATE SOUND EFFECTS QUEUES       * * * * * * *
;
	; dbr 0
	; dpr 0
	; mode 'AX'
_RLIRQUpdateSoundQueues:
	ldy.w #0	; .Y = SoundEffects Index
_RIUSQ2000:
	lda.w RLSNESSounds+rlseEffect,y	; Get SoundEffect Effect#
	and.w #$00FF
	asl a	; .X = TurboTable Index
	sta.b _TSBytes
	asl a
;	clc
	adc.b _TSBytes
	tax
	lda.w _MusicTurboTable+rlsettBWave,x	; Regular/Turbo?
	bne _RIUSQ3000	; Turbo
	jmp.w _RIUSQ8000	; Regular

;
;	* * * * * * *       QUEUE A TURBO SOUNDEFFECT       * * * * * * *
;
_RIUSQ3000:
	phy	; Save SoundEffect Index
	txy	; .Y = TurboTable Index

;
;	>>>   CHECK ALL TURBO SOUNDS FOR MATCHING BWAVE   <<<
;
;	(this port) ... and the same data: the chainsaw sounds share the super
;	shotgun's BWave (sample number), tools/wad2soundfx.py NEWTURBO.
;
	!rlset #= 0
	for __rep = 0..MaxRLTSounds
	ldx.w #(!rlset*rlsetSize)	; .X = TurboSound Index
	sep #$20		; mode 'a!'
	cmp.w TSounds+rlsetBWave,x	; Same BWAVE Number?
	rep #$20		; mode 'A!'
	bne +
	lda.w _MusicTurboTable+rlsettData,y	; Same data?
	cmp.w TSounds+rlsetStart,x
	beq _RIUSQ3790	; Yes!
	lda.w _MusicTurboTable+rlsettBWave,y
+
	!rlset #= !rlset+1
	endfor
	sep #$20		; mode 'a!'

;
;	>>>   FIND A FREE TURBOSOUND   <<<
;
	!rlset #= 0
	for __rep = 0..MaxRLTSounds
	ldx.b TSoundsI+(!rlset*2)	; Get Priority Order Index
	bit.w TSounds+rlsetFlags,x	; Is TurboSound Idle?
	bmi _RIUSQ5000	; Yes!
	!rlset #= !rlset+1
	endfor

;
;	>>>   NO FREE TURBOSOUNDS!   <<<
;
	ply	; Restore SoundEffect Index
;_RIUSQ3600
	jmp.w _RIUSQ9000	; No TurboSounds Free!
_RIUSQ3790:
	lda.w _MusicTurboTable+rlsettBWave,y
	sep #$20		; mode 'a!'
;
;	>>>   EXISTING TURBOSOUND EFFECT MATCHES BWAVE NUMBER   <<<
;
_RIUSQ3800:
	jsr.w _RIUSQ4000	; Update Priority Order Index
	jmp.w _RIUSQ7000

;
;	>>>   UPDATE PRIORITY INDEX   <<<
;
;	.X = TSound Index to Use
;
_RIUSQ4000:
	phy	; Save _MusicTurboTable Index
	stx.b _TSBytes
	phx	; Most Recently Used
	ldy.w #((MaxRLTSounds-1)*2)
_RIUSQ4200:
	ldx.b TSoundsI,y	; Get Priority Order Index
	cpx.b _TSBytes	; Our New Top Priority?
	beq _RIUSQ4300	; Yes, Don't Add Twice!
	phx	; No, Add This Older Priority!
_RIUSQ4300:
	dey
	dey
	bpl _RIUSQ4200

	!rlset #= 0
	for __rep = 0..MaxRLTSounds
	plx	; Get Priority Order Index
	stx.b TSoundsI+(!rlset*2)
	!rlset #= !rlset+1
	endfor
	ply	; Restore _MusicTurboTable Index
	rts

;
;	>>>   INITIALIZE NEW TURBOSOUND   <<<
;
_RIUSQ5000:
	jsr.w _RIUSQ4000	; Update Priority Order Index
	stz.w TSounds+rlsetFlags,x	; Cycle
	rep #$20		; mode 'A!'
	sta.w TSounds+rlsetBWave,x	; BWave# / Data Address Low
	lda.w _MusicTurboTable+rlsettData+1,y	; Data Address High/Bank
	sta.w TSounds+rlsetData+1,x
	lda.w _MusicTurboTable+rlsettBytes,y	; #Bytes to Transfer
	sta.w TSounds+rlsetBytes,x
	lda.w _MusicTurboTable+rlsettData,y	; (this port) Which sound
	sta.w TSounds+rlsetStart,x
	ply	; Restore SoundEffect Index
	lda.w RLSNESSounds+rlsePriority,y	; Priority/Effect#
	sta.w TSounds+rlsetPriority,x
	lda.w TSounds+rlsetAPUBase,x	; APU BaseAddress
	sta.w TSounds+rlsetAPU,x	; APU
	bra _RIUSQ9500

;
;	>>>   MATCHING TURBO SOUND EXISTS!   <<<
;
	; mode 'a'
_RIUSQ7000:
	ply	; Restore SoundEffect Index
	lda.w RLSNESSounds+rlsePriority,y	; Get New Priority
;
	bit.w TSounds+rlsetFlags,x	; Is TurboSound Idle?
	bpl _RIUSQ7200	; No, Playing or Loading
;
;	>>>   TURBOSOUND IS IDLE   <<<
;
	sta.w TSounds+rlsetPriority,x	; Yes, Force New Priority!
	bra _RIUSQ7500
;
;	>>>   TURBOSOUND IS LOADING/PLAYING   <<<
;
_RIUSQ7200:
	cmp.w TSounds+rlsetPriority,x	; New Priority >= Old Priority?
	bcc _RIUSQ7300	; No
	sta.w TSounds+rlsetPriority,x	; Yes!  Use New Priority!
;
;	>>>   TURBOSOUND NOT PLAYING YET -- WAIT FOR NORMAL LOAD PROCESS   <<<
;
_RIUSQ7300:
	bvc _RIUSQ9000	; TurboSound NOT Playing -- Wait
;
;	>>>   TURBOSOUND LOADED!  QUEUE REGULAR SOUNDEFFECT TO PLAY TURBOSOUND   <<<
;
_RIUSQ7500:
	lda.b #rlsetfPlaying	; ReStart PlayCycle
	sta.w TSounds+rlsetFlags,x
	rep #$20		; mode 'A!'
;
;	* * * * * * *       QUEUE A REGULAR SOUNDEFFECT       * * * * * * *
;
_RIUSQ8000:
	lda.w RLSNESSounds+rlsePriority,y	; Get SoundEffect Priority/Effect#
	jsr.w _RLIRQQueueSound
;
;	>>>   ONE MORE SOUNDEFFECT QUEUED   <<<
;
_RIUSQ9000:
	rep #$20		; mode 'A!'
_RIUSQ9500:
	iny	; Next SoundEffect
	iny
	dec.w RLNumSounds+!RLSNESGSUXVarsO	; Any More SoundEffects to Queue?
	beq _RIUSQ9900	; No
	jmp.w _RIUSQ2000	; Yes
_RIUSQ9900:
	rts


;
;	* * * * * * *       QUEUE A REGULAR SOUND EFFECT       * * * * * * *
;
;	.A = Priority/Effect
;	.A = TurboSound Index + $8000
;
;	.C = 0 = SoundEffect Queued
;	   = 1 = Queue Full!
;
	; dbr 0
	; dpr 0
	; mode 'AX'
_RLIRQQueueSound:
	ldx.b SoundQueueE	; SoundEffect Queue Full?
	inx
	inx
	cpx.w #lo16(SoundQueueEnd-SoundQueue)	; WrapAround?
	bne _RIQS200
	ldx.w #0
_RIQS200:
	cpx.b SoundQueueI
	beq _RIQS900	; YES!  CAN'T QUEUE SOUNDEFFECT!
	phx
	ldx.b SoundQueueE	; Queue SoundEffect
	sta.w SoundQueue+rlserPriority,x
	plx
	stx.b SoundQueueE
	clc
_RIQS900:
	rts
