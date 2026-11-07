	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                         MUSIC DRIVER MODULE                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/snesmac.inc"
	incsrc "src/include/rlsound.inc"
	incsrc "src/include/music.inc"


	%section(MUSIC_DRIVER)
	%section(MUSIC_TABLES)	; (this port: data only, read with long addressing: any ROM bank)

;
;	* * * * * * *       MUSIC BOOT       * * * * * * *
;
_MusicBoot:
	incbin "data/RLDATA/MUSIC/MUSIC_B.C"

;
;	* * * * * * *       MUSIC DRIVER       * * * * * * *
;
_MusicDriver:
	incbin "data/RLDATA/MUSIC/MUSIC_D.C"

;
;	* * * * * * *       MUSIC CHUNKINDEX       * * * * * * *
;
_MusicChunkIndex:
	incbin "data/RLDATA/MUSIC/MUSIC_I"

;
;	* * * * * * *       MUSIC CHUNKLISTS       * * * * * * *
;
_MusicChunkLists:
	incbin "data/RLDATA/MUSIC/MUSIC_L"

;
;	* * * * * * *       MUSIC CHUNKTABLE       * * * * * * *
;
_MusicChunkTable:
;	LOAD.L/SIZE.W per chunk; (this port) the file is built for the chunks at
;	$47:0000, relocated here to wherever _MusicChunks was placed
	!__n #= filesize("data/RLDATA/MUSIC/MUSIC_T")/5
	!__i #= 0
	while !__i < !__n
		dl readfile3("data/RLDATA/MUSIC/MUSIC_T", !__i*5)-$470000+_MusicChunks
		dw readfile2("data/RLDATA/MUSIC/MUSIC_T", !__i*5+3)
		!__i #= !__i+1
	endwhile

;
;	* * * * * * *       MUSIC TURBO SOUNDEFFECTS TABLE       * * * * * * *
;
__MusicTurboTable:
	incbin "data/RLDATA/MUSIC/MUSIC_O.C"

	%section(MUSIC_DRIVER)


;
;	* * * * * * *       INITIALIZE MUSIC DRIVER       * * * * * * *
;
	; dbr ?
	; dpr 0
_InitMusicDriver:
	rep #$30		; mode 'AX!'
	phb
	ldx.w #lo16(__MusicTurboTable)	; DeCompress TURBOTABLE
	lda.w #(bank(_MusicTurboTable)<<8)|bank(__MusicTurboTable)
	ldy.w #lo16(_MusicTurboTable)
	jsl.l _DeCompressTurbo	; DeCompress + relocate (musicdat.asm)
;
	ldx.w #lo16(_MusicBoot)	; DeCompress BOOT Code
	lda.w #(bank(_MDDeCompBuffer)<<8)|bank(_MusicBoot)
	ldy.w #lo16(_MDDeCompBuffer)
	jsl.l DeCompress
	plb
	tyx	; Upload BOOT Code
	ldy.w #lo16(_MDDeCompBuffer)
	lda.w #bank(_MDDeCompBuffer)
	jsr.w _APUUploadRun0
;
	rep #$30		; mode 'AX!'
	phb
	ldx.w #lo16(_MusicDriver)	; DeCompress DRIVER Code
	lda.w #(bank(_MDDeCompBuffer)<<8)|bank(_MusicDriver)
	ldy.w #lo16(_MDDeCompBuffer)
	jsl.l DeCompress
	plb
	tyx	; Upload DRIVER Code
	ldy.w #lo16(_MDDeCompBuffer)
	lda.w #bank(_MDDeCompBuffer)
	jsr.w _APUUploadRun0
;
	rep #$20		; mode 'A!'
	; Upload Common Module
	lda.w #0
	jsl.l _LoadModule2
_IMD900:
	rtl


;
;	* * * * * * *       LOAD A SOUND MODULE       * * * * * * *
;
;	.A = Module#
;
	; dbr ?
	; dpr 0
	; mode 'X'
_LoadModule:
	rep #$20		; mode 'A!'
	and.w #$00FF	; Module Resident?
	cmp.w _MDModule
	beq _IMD900	; Yes!  Don't ReLoad!
_LoadModule2:
	sta.w _MDModule	; Save Module# Loaded
	asl a	; Get Offset into ChunkIndex
	tax
	lda.l _MusicChunkIndex,x	; Get ChunkList Index
	pha
;
;	>>>   TELL DRIVER TO SWITCH TO LOAD MODE   <<<
;
	lda.w #DCOM_RELOAD
	jsl.l __SendDriverCommand
;
;	>>>   LOAD A CHUNKLIST   <<<
;
_LoadChunkList:
	plx	; .X = ChunkList Index
	lda.l _MusicChunkLists,x	; .A = APU Destination Address
	tay
	jsr.w _APUUploadInit	; Initialize APU Upload
	bra _LCL500
;
;	>>>   NEXT CHUNKLIST GROUP   <<<
;
_LCL200:
	inx	; Next ChunkList Group
	inx
	sep #$20		; mode 'a!'
	pla	; Restore Serial#
_LCL220:
	inc a	; Next Serial#
	beq _LCL220
	pha	; Save Serial#
	rep #$20		; mode 'A!'
	lda.l _MusicChunkLists,x	; .A = APU Destination Address
	beq _LCL800	; End of ChunkList!
	tay
	sep #$20		; mode 'a!'
	; Restore Serial#
	pla
	jsr.w _APUUploadInit2	; Initialize APU Upload
	bra _LCL500
;
;	>>>   NEXT CHUNKLIST CHUNK   <<<
;
	; mode 'a'
_LCL400:
	plx	; Restore ChunkList Index
_LCL500:
	pha	; Save Serial#
	rep #$20		; mode 'A!'
	inx	; Next ChunkList Chunk
	inx
	lda.l _MusicChunkLists,x	; .A = Chunk#
	bmi _LCL200	; End of ChunkList Group!
;
	txy	; Save ChunkList Index
	sta.b _MDChunkPtr	; Multiply by 5 (LOAD.L/SIZE.W)
	asl a
	asl a
;	clc
	adc.b _MDChunkPtr
	tax
	lda.l _MusicChunkTable+3,x	; Get SIZE.W
	pha
	lda.l _MusicChunkTable+0,x	; Get LOAD.L
	sta.b _MDChunkPtr
	sep #$20		; mode 'a!'
	lda.l _MusicChunkTable+2,x
	sta.b _MDChunkPtr+2
	plx	; .X = #Bytes
	bpl _LCL700	; UnCompressed
	phy
	jsl.l UnPackRL0	; RLC COMPRESSED!
	tyx	; .X = #Bytes
	ply
	sep #$20		; mode 'a!'
_LCL700:
	pla	; Restore Serial#
	phy	; Save ChunkList Index
	jsr.w _APUUpload	; APU Upload Block
	bra _LCL400
;
;	>>>   START DRIVER RUNNING   <<<
;
_LCL800:
	sep #$20		; mode 'a!'
	; Restore Serial#
	pla
	jsr.w _APUUploadRun	; Start Driver Running!
	lda.b #DCOM_RUN
	jml.l __SendDriverCommand


;
;	* * * * * * *       UPLOAD TO APU AND RUN       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'aX'
_APUUploadRun0:
	pea.w lo16(_APUUploadRun-1)	; Start APU Running
	sty.b _MDChunkPtr	; Save Pointer to ChunkData
	sta.b _MDChunkPtr+2
	pea.w lo16(_APUUpload-1)	; Upload APU Block
	ldy.w #$0700	; APU Destination Address
	rep #$20		; mode 'A!'
;
;	* * * * * * *       UPLOAD TO APU INITIALIZE       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
_APUUploadInit:
	lda.w #$BBAA	; APU ReadyState Sentry
_AUI120:
	cmp.w APUIO0
	bne _AUI120
	sep #$20		; mode 'a!'
	sei	; Disable IRQs
	stz.w NMITIMEN	; Disable NMIs
	lda.b #$CC	; CPU ReadyState Sentry
_APUUploadInit2:
	sty.w APUIO2	; Send APU Destination Address
	sta.w APUIO1
	sta.w APUIO0
_AUI140:
	cmp.w APUIO0	; Wait for Acknowledge
	bne _AUI140
	lda.b #0
	rts
;
;	* * * * * * *       UPLOAD TO APU       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'aX'
_APUUpload:
	ldy.w #0	; .Y = ChunkData Index
_AUU200:
	xba	; .B = Serial#
	lda.b [_MDChunkPtr],y	; Send Byte
	sta.w APUIO1
	xba	; Send Serial#
	sta.w APUIO0
	iny
_AUU220:
	cmp.w APUIO0	; Wait for Acknowledge
	bne _AUU220
	inc a	; Next Serial#
	dex	; Next Byte
	bne _AUU200
	rts
;
;	* * * * * * *       START APU RUNNING AFTER UPLOAD       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'aX'
_APUUploadRun:
	ldx.w #$0700	; Send JumpVector
	stx.w APUIO2
	stz.w APUIO1
_AUR120:
	inc a	; Next Serial#
	beq _AUR120
	sta.w APUIO0	; Send Serial#
_AUR140:
	cmp.w APUIO0	; Wait for Acknowledge
	bne _AUR140
	stz.w APUIO0	; Clear Ports
	stz.w APUIO1
	stz.w APUIO2
	stz.w APUIO3
	lda.b #1	; Initialize Serial#
	sta.w _MDSerialNum
	ldx.w #0	; Delay for Music Driver to Initialize
_AUR160:
	dex
	bne _AUR160
	rts


;
;	* * * * * * *       LOAD AND PLAY A SONG       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
_PlaySong:
	sta.w _MDSong	; Save Song#/Module# to Play
	jsl.l _LoadSong	; Load Song
	ldy.w _MDSong	; Get Song# to Play
	lda.w #DCOM_START_SONG
	jsl.l __SendDriverCommand
	lda.w #DCOM_FADEIN	; Fade in Music
	ldy.w #$7F01
	jml.l __SendDriverCommand


;
;	* * * * * * *       LOAD A SONG       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
_LoadSong:
;
;	>>>   SHUT OFF EVERYTHING   <<<
;
	lda.w #DCOM_STOP_SONG
	ldy.w #$0000
	jsl.l __SendDriverCommand
	lda.w #DCOM_STOP_SOUND
	ldy.w #$8080
	jsl.l __SendDriverCommand
;
;	>>>   CONTROL CLICKS AND POPS   <<<
;
	lda.w #DCOM_FADE_AND_STOP
	ldy.w #$7F01
	jsl.l __SendDriverCommand
	ldx.w #$4000	; Wait 4 Driver Ticks?!
_LSG200:
	dex
	bne _LSG200
;
;	>>>   LOAD MODULE FOR DESIRED SONG, IF NECESSARY   <<<
;
	lda.w _MDSong	; Module Already Loaded?
	xba
	jsl.l _LoadModule	; Load Module if Necessary
	ldx.w #$4000	; Wait for Driver to Init
_LSG300:
	dex
	bne _LSG300
;
;	>>>   FADE MUSIC IN/OUT (DRIVER USUALLY? FADES THEM IN)   <<<
;
	lda.w #DCOM_FADE_AND_STOP
	ldy.w #$7F01
	jsl.l __SendDriverCommand
	ldx.w #$4000	; Wait for Fade to Complete
_LSG500:
	dex
	bne _LSG500
	rtl



	%section(ENGINE_RAMCODE)
;
;	* * * * * * *       SEND MUSIC DRIVER COMMAND       * * * * * * *
;
;	.A = Command
;	.Y = Parameter
;
;	.C = 0 = OK, = 1 = TIMEOUT!
;
	; dbr ?
	; dpr 0
	; mode 'AX'

;
;	* * * * * * *       SEND DRIVER COMMAND LOCK       * * * * * * *
;
_SendDriverCommandL:
	pha	; Save Command
	lda.w #mdlLock	; Lock MusicDriver
	tsb.w _MDLocks
_SDCL400:
	lda.b 1,s	; Get Command
	jsl.l _SendDriverCommand	; Send Command
	bcs _SDCL400	; TimeOut!  ReSend!
	sep #$20		; mode 'a!'
;	lda	_MDSerialNum			; .A = Serial#
_SDCL600:
	cmp.w APUIO2	; Wait for Acknowledge
	bne _SDCL600
	rep #$20		; mode 'A!'
	lda.w #mdlLock	; UnLock MusicDriver
	trb.w _MDLocks
	pla	; Discard Command
	rtl

;
;	* * * * * * *       SEND DRIVER COMMAND       * * * * * * *
;
_SendDriverCommand:
;__SendDriverCommand	equ	((**&$00ff8000)<<1)+(**&$7fff)+$8000
	__SendDriverCommand = $5C368E
	assert (__SendDriverCommand&$FFFFFF) == ((((snestopc(realbase())&$00FFFFFF)+$400000))&$FFFFFF), "cached constant __SendDriverCommand is stale (tools/fixup.py)"
	ldx.w #$2800	; .X = TimeOut Counter
;
;	>>>   DCOM_RELOAD / DCOM_RUN?   <<<
;
	sep #$20		; mode 'a!'
	cmp.b #DCOM_RELOAD	; RELOAD Command?
	beq _SDC200	; Yes
	cmp.b #DCOM_RUN	; RUN Command?
	bne _SDC500	; No
_SDC200:
	xba	; .B = Command
	lda.w _MDSerialNum	; .A = Serial#
_SDC220:
	cmp.w APUIO2	; Wait for Acknowledge, NO TIMEOUT!
	bne _SDC220
	bra _SDC700

;
;	* * * * * * *       SEND DRIVER COMMAND QUICK       * * * * * * *
;
	; dbr ?
	; dpr 0
_SendDriverCommandQuick:
;__SendDriverCommandQuick	equ	((**&$00ff8000)<<1)+(**&$7fff)+$8000
	__SendDriverCommandQuick = $5C36A6
	assert (__SendDriverCommandQuick&$FFFFFF) == ((((snestopc(realbase())&$00FFFFFF)+$400000))&$FFFFFF), "cached constant __SendDriverCommandQuick is stale (tools/fixup.py)"
	if usePAL == 0
	ldx.w #40	; .X = TimeOut Counter
	endif
	if usePAL != 0
	ldx.w #100	; .X = TimeOut Counter
	endif
	sep #$20		; mode 'a!'
;
;	>>>   SYNCHRONIZE WITH MUSIC DRIVER   <<<
;
_SDC500:
	xba	; .B = Command
	lda.w _MDSerialNum	; .A = Serial#
_SDC520:
	cmp.w APUIO2	; Wait for Acknowledge
	beq _SDC700
	dex	; TimeOut?
	bne _SDC520
	rep #$20		; mode 'A!'
	; Yes!  Error!
	sec	; .C = 1 = Command NOT Sent!
	rtl
;
;	>>>   SEND COMMAND/PARAMETERS/SERIAL# TO MUSIC DRIVER   <<<
;
	; mode 'a'
_SDC700:
	inc a	; Next Serial#
	beq _SDC700	; Skip Serial# $00
	sta.w _MDSerialNum	; Save New Serial#
	rep #$20		; mode 'A!'
	sty.w APUIO0	; Send Parameter
	sta.w APUIO2	; Send Command/Serial#
	clc	; .C = 0 = Command Sent
	rtl
