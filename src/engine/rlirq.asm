	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                          ENGINE IRQ MODULE                         *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/snesmac.inc"

	; public _RLInitIRQ
	; public _RLIRQTop
	; public _RLIRQBottom


	%section(ENGINE)
;
;	* * * * * * *       INITIALIZE REALITY_ENGINE IRQS       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitIRQ:
	rep #$20		; mode 'A!'
	stz.b IRQTPhase	; Phase of TOP IRQ Operations
	stz.b IRQBPhase	; Phase of BOTTOM IRQ Operations
	stz.w TQCount	; (this port) no screen thirds waiting in WRAM
	stz.w TQHead
	stz.w TQStrip
	stz.w TQNoCopy
	stz.w WeaponWait
	lda.w #2	; (_RLGSUReqMisc)
	sta.w TQMiscTokens
	sep #$20
	rep #$10		; mode 'aX!'
	ldx.w #RLHIntL	; Horizontal Interrupt
	stx.w HTIMEL
	ldx.w #RLVIntTop	; Vertical Interrupt
	stx.w VTIMEL
	ldx.w #lo16(_RLIRQTop)	; Top IRQ
	lda.b #bank(_RLIRQTop)
	jml.l InitIRQ	; Initialize IRQs


	%section(ENGINE_RAMCODE)
;
;	* * * * * * *       REALITY_ENGINE IRQ AT BOTTOM OF SCREEN       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLIRQBottom:
	sep #$20		; mode 'a!'
	pha
	lda.l _SLHV	; Latch Raster Position
	lda.l _STAT78	; Update H/V Counters
	lda.l _OPVCT	; Get Low 8Bits VPos
	cmp.b #(RLVIntBottom-1)	; (this port) From 1 scanline above to 8 below:
	bcc _RIB0900	; the bottom IRQ, maybe late (an IRQ handler ran
	cmp.b #(RLVIntBottom+9)	; into its line; the original took it for a GSU IRQ and
	bcc _RIB1000	; then ran the IRQ again every scanline until the next
_RIB0900:	; frame's: no VRAM upload, the game stalled)
	xba	; (GSU)
	pha
	phb	; Save .DBR
	lda.b #$00
	pha
	plb
	; dbr $00
	rep #$30		; mode 'AX!'
	phx
	phy
	jmp.w _RLIRQGSU

;
;	>>>   SCANLINE AT BOTTOM OF DISPLAY   <<<
;
	; mode 'a'
_RIB1000:
	lda.b #RLHIntR	; Right Horizontal Interrupt
	sta.l HTIMEL
	lda.l sfxSFR+1	; Clear GSU Flag
	lda.l _TIMEUP	; Clear IRQ Flag
;	(this port) WAI waits for the IRQ at RLHIntR on this line.  When that
;	point has passed (the IRQ came late after a GSU IRQ handler), WAI would
;	wait up to a frame for the next GSU IRQ (display left blanked, or the
;	VRAM transfer lost): then no WAI.
	lda.l _SLHV	; Latch Raster Position
	lda.l _STAT78	; (reset the OPHCT/OPVCT flip-flops)
	lda.l _OPVCT
	cmp.b #RLVIntBottom
	bcc _RIB1000W	; (a line early: the IRQ is still to come)
	bne _RIB1000L	; Past the line
	lda.l _OPHCT	; H (9 bits)
	pha
	lda.l _OPHCT
	lsr a
	pla
	bcs _RIB1000L
	cmp.b #(RLHIntR-16)	; (the IRQ comes when H reaches RLHIntR)
	bcs _RIB1000L
_RIB1000W:
	lda.b #$80	; Disable Display
	wai
	bra _RIB1000S
_RIB1000L:
	lda.b #$80	; Disable Display
_RIB1000S:
	sta.l INIDISP
;
	xba
	pha
	phb
	lda.b #$00
	pha
	plb
	; dbr $00
	rep #$30		; mode 'AX!'
	lda.w #$00FF	; Close Window Completely
	sta.w WH0
	phx
	phy
	lda.w #RLVIntTop	; Initialize Interrupt Timer
	sta.w VTIMEL
	lda.w #RLHIntL	; Left Horizontal Interrupt
	sta.w HTIMEL
	lda.w #lo16(_RLIRQTop)	; Set up Top IRQ
	sta.w GSUIRQRAM+1
	bit.w _TIMEUP	; Clear IRQ Flag
;	cli					; Release Interrupts for GSU
;
;	>>>   IRQ PHASE DISPATCH   <<<
;
;_RIB3000
	ldx.b IRQBPhase	; Get Current BOTTOM IRQ Phase
	cpx.w #(3*2)	; DRAWD/MENUS?
	bcs _RIB3400	; Yes, don't wait for GSU
	lda.w TQCount	; (this port) A third waiting in WRAM?
	bne _RIB3400	; Yes
	jmp.w _RIB5000	; NO!
_RIB3400:
	jmp.w (_RIBPhaseCode,x)	; IRQ BOTTOM PhaseCode
;
;	* * * * * * *       IRQ BOTTOM PHASE CODE JUMP TABLE       * * * * * * *
;
_RIBPhaseCode:
	dw lo16(_RIBDrawA)	; Draw A (Face, Keys, Arms)
	dw lo16(_RIBDrawB)	; Draw B (RGB, OAMs, Sounds)
	dw lo16(_RIBDrawC)	; Draw C (Map, Flip)
	dw lo16(_RIBDrawD)	; Draw D (Weapon)
	dw lo16(_RIBMenus)	; Menus (Arms)


;
;	* * * * * * *       MENUS       * * * * * * *
;
	; mode 'AX'
_RIBMenus:
;
;	>>>   TRANSFER STATUS BAR PLAYER WEAPON   <<<
;
	ldx.w WeaponNext+!RLSNESGSUXVarsO	; Same Next Weapon as Last?
	cpx.b WeaponNextOld
	beq _RIBMenus200	; Yes
	stx.b WeaponNextOld	; No!  Different!
;
	stz.w MDMAEN	; Stop HDMAs
	lda.l RLStatArmsDefAddr,x	; Transfer FIRST Strip
	ldy.w #(1<<7)
	ldx.w #vmARMSDEF	; VRAM Destination
	stx.w VMADDL
	ldx.w #(4*32)	; 4 Characters Wide
	sta.w DMA7A1L
	stx.w DMA7NUML
	sty.w MDMAEN
	clc	; Transfer SECOND Strip
	adc.w #(8*4*32)
	sta.w DMA7A1L
	stx.w DMA7NUML
	sty.w MDMAEN
;
;	>>>   RESTART HDMAS   <<<
;
_RIBMenus200:
	sep #$20		; mode 'a!'
	lda.w HDMAEN_S	; Start HDMAs
_RIBMenus220:
	bit.w _HVBJOY	; Wait for VBlank
	bpl _RIBMenus220
	sta.w HDMAEN
	jmp.w _RLIRQDone


;
;	* * * * * * *       CALLED WHEN NOTHING ELSE PENDING       * * * * * * *
;
	; mode 'AX'
_RIB5000:
;
;	>>>   TRANSFER RGB   <<<
;
	bit.w RLRGBLock	; RGB Palettes Locked?
	bmi _RIB5200	; Yes!
	lda.w RLRGBPtr	; Any RGB to XFer?
	bmi _RIB5200	; No
	sta.w DMA5A1L
	ora.w #$8000
	sta.w RLRGBPtr
	lda.w #(256*2)	; Transfer 256 RGB Colours
	sta.w DMA5NUML
	stz.w CGADD-1
	lda.w #(1<<5)
	sta.w MDMAEN
;
;	>>>   HANDLE REGULAR SOUND EFFECTS   <<<
;
_RIB5200:
	jsr.w _RLIRQUpdateSounds	; Update Regular Sound Effects
	jmp.w _RLIRQGSU


;
;	* * * * * * *       DRAWA,DRAWB,DRAWC TRANSFER       * * * * * * *
;
;	.A = VRAM Dest. Address
;
	; mode 'AX'
_RIBDrawXFer:
;
;	(this port) The third comes from the WRAM buffer at the head of the
;	queue (_RLCopyThird put it there as soon as the GSU had drawn it), so
;	the GSU keeps its RAM and runs on during this transfer.  A GSU halted
;	at the end of a phase is started first (it waited for this IRQ to end).
;
	pha
	inc.w TQNoCopy
	jsr.w _RLGSUStart
	stz.w TQNoCopy
	pla
	sta.w VMADDL	; VRAM Destination
	lda.w TQHead	; Source: the WRAM buffer at the head of the queue
	asl a
	tax
	lda.l _TQBufs,x
	sta.w TQSrc
	lda.w TQHead	; Take it off the queue
	eor.w #1
	sta.w TQHead
	dec.w TQCount
;
;	>>>   TRANSFER THE 9 STRIPS   <<<
;
;	(this port) one DMA per strip (channel 0), and between strips a GSU
;	that halted at the end of a phase is started: the CPU is stopped while
;	a DMA runs, so the GSU would otherwise wait for the whole upload.
;
	sep #$20		; mode 'a!'
	lda.b #bank(TQBuf0)	; A Bank: WRAM
	sta.w DMA0A1B
	rep #$20		; mode 'A!'
	lda.w #9	; Strips left
	sta.w TQUpLeft
_RIBDX200:
	lda.w TQSrc	; This strip
	sta.w DMA0A1L
	clc
	adc.w #(20*64)	; Next strip
	sta.w TQSrc
	lda.w #(RLViewCharY*64)	; #Bytes
	sta.w DMA0NUML
	sep #$20		; mode 'a!'
	lda.b #$01
	sta.w MDMAEN
	lda.w sfxSFR	; GSU halted? (the low byte only: reading SFR's high byte
	and.b #%00100000	;  would clear the GSU IRQ flag)
	rep #$20		; mode 'A!'
	bne _RIBDX300	; No
	inc.w TQNoCopy	; Yes: start its next phase (no copy now: the blank is the upload's)
	jsr.w _RLGSUStart
	stz.w TQNoCopy
_RIBDX300:
	dec.w TQUpLeft
	bne _RIBDX200
	sep #$20		; mode 'a!'
	lda.b #$70	; (channel 0: GSU RAM, as _RLReInitDMA left it)
	sta.w DMA0A1B
	rep #$20		; mode 'A!'
;
;	>>>   A WEAPON WAITING? (this port, see _RIBDrawD)   <<<
;
	lda.w #rlfWeaponDEF	; Weapon built, not sent?
	bit.b RLFlags
	bne _RIB4800	; No
	lda.w WeaponDEFGDMABytes	; Lines it takes: 1.5 + 0.14 per GDMA stack byte
	lsr a	; (measured), here 5 + 9/64 per byte (a margin
		; of 3 lines: it must end before the top IRQ)
	lsr a
	lsr a
	pha
	lsr a
	lsr a
	lsr a
	clc
	adc 1,s
	adc.w #5
	sta 1,s
	jsr.w _RLLinesLeft	; Room left in this blank?
	cmp 1,s
	pla
	bcc _RIB4800	; No
	jsr.w _RIBWeaponUp
;
;	>>>   DRAW COMPLETED   <<<
;
	; mode 'A'
_RIB4800:
	jmp.w _RLIRQGSU


;
;	* * * * * * *       TABLE OF STATUS BAR FACES CHRDATA       * * * * * * *
;
RLStatFacesDefAddr:
	!fn #= 0
	for __rep = 0..(8*4)
	dw lo16(RLStatFacesDefRAM+((!fn&7)*3*32)+((!fn/8)*(8*3*4*32)))
	!fn #= !fn+1
	endfor
;
;	* * * * * * *       TABLE OF STATUS BAR ARMS CHRDATA       * * * * * * *
;
RLStatArmsDefAddr:
	!fn #= 0
	for __rep = 0..8	; (asar: 0..7)
	dw lo16(RLStatArmsDefRAM+((!fn&7)*4*32))
	!fn #= !fn+1
	endfor
	if !RLDOOM2MONSTERS != 0
	dw lo16(RLStatArmsDefRAM+(2*4*32))	; Super Shotgun (DOOM II): same as the Shotgun
	endif


;
;	* * * * * * *       DRAW A       * * * * * * *
;
	; mode 'AX'
_RIBDrawA:
;
;	>>>   TRANSFER STATUS BAR PLAYER FACE   <<<
;
	ldx.w PlayerFace+!RLSNESGSUXVarsO	; Same Face as Last?
	cpx.w PlayerFaceOld
	beq _RIBDrawA200	; Yes
	stx.w PlayerFaceOld	; No!  Different!
;
	lda.w #vmFACEDEF	; VRAM Destination
	sta.w VMADDL
	lda.l RLStatFacesDefAddr,x	; Transfer FIRST Strip
	ldx.w #(1<<7)	; MDMAEN / HDMAEN
	ldy.w #(3*32)	; 3 Characters Wide
;
	sta.w DMA7A1L
	sty.w DMA7NUML
	stx.w MDMAEN
	clc	; Transfer SECOND Strip
	adc.w #(8*3*32)
	sta.w DMA7A1L
	sty.w DMA7NUML
	stx.w MDMAEN
;	clc					; Transfer THIRD Strip
	adc.w #(8*3*32)
	sta.w DMA7A1L
	sty.w DMA7NUML
	stx.w MDMAEN
;	clc					; Transfer FOURTH Strip
	adc.w #(8*3*32)
	sta.w DMA7A1L
	sty.w DMA7NUML
	stx.w MDMAEN
;
;	>>>   TRANSFER STATUS BAR PLAYER KEYS   <<<
;
_RIBDrawA200:
	ldx.w PlayerKeys+!RLSNESGSUXVarsO	; Same Keys as Last?
	cpx.w PlayerKeysOld
	beq _RIBDrawA400	; Yes
	stx.w PlayerKeysOld	; No!  Different!
;
	txa	; BLUE KEY?
	and.w #%00000011
	beq _RIBDrawA240	; No
	dec a
	beq _RIBDrawA220
	lda.w #32
_RIBDrawA220:
	clc
	adc.w #lo16(RLStatKeysDefRAM+(0*32))
	sta.w DMA7A1L
	lda.w #(1*32)	; 1 Character Wide
	sta.w DMA7NUML
	lda.w #(vmKEYSDEF+((32*0)/2))	; VRAM Destination
	sta.w VMADDL
	lda.w #(1<<7)	; MDMAEN / HDMAEN
	sta.w MDMAEN
;
_RIBDrawA240:
	txa	; YELLOW KEY?
	lsr a
	lsr a
	tax
	and.w #%00000011
	beq _RIBDrawA280	; No
	dec a
	beq _RIBDrawA260
	lda.w #32
_RIBDrawA260:
	clc
	adc.w #lo16(RLStatKeysDefRAM+(2*32))
	sta.w DMA7A1L
	lda.w #(1*32)	; 1 Character Wide
	sta.w DMA7NUML
	lda.w #(vmKEYSDEF+((32*1)/2))	; VRAM Destination
	sta.w VMADDL
	lda.w #(1<<7)	; MDMAEN / HDMAEN
	sta.w MDMAEN
;
_RIBDrawA280:
	txa	; RED KEY?
	lsr a
	lsr a
	and.w #%00000011
	beq _RIBDrawA400	; No
	dec a
	beq _RIBDrawA300
	lda.w #32
_RIBDrawA300:
	clc
	adc.w #lo16(RLStatKeysDefRAM+(4*32))
	sta.w DMA7A1L
	lda.w #(1*32)	; 1 Character Wide
	sta.w DMA7NUML
	lda.w #(vmKEYSDEF+((32*2)/2))	; VRAM Destination
	sta.w VMADDL
	lda.w #(1<<7)	; MDMAEN / HDMAEN
	sta.w MDMAEN
;
;	>>>   TRANSFER STATUS BAR PLAYER WEAPON   <<<
;
_RIBDrawA400:
	ldx.w WeaponNext+!RLSNESGSUXVarsO	; Same Next Weapon as Last?
	cpx.b WeaponNextOld
	beq _RIBDrawA600	; Yes
	stx.b WeaponNextOld	; No!  Different!
;
	lda.w #vmARMSDEF	; VRAM Destination
	sta.w VMADDL
	lda.l RLStatArmsDefAddr,x	; Transfer FIRST Strip
	ldx.w #(1<<7)	; MDMAEN / HDMAEN
	ldy.w #(4*32)	; 4 Characters Wide
;
	sta.w DMA7A1L
	sty.w DMA7NUML
	stx.w MDMAEN
	clc	; Transfer SECOND Strip
	adc.w #(8*4*32)
	sta.w DMA7A1L
	sty.w DMA7NUML
	stx.w MDMAEN
;
;	>>>   TRANSFER DRAW A   <<<
;
_RIBDrawA600:
	lda.w #(1*2)	; IRQ Phase 1
	sta.b IRQTPhase
	sta.b IRQBPhase
	lda.w ViewB
	and.w #$0004
	tax
	lda.l _RLChrDefsA,x	; .A = VRAM Dest.
	jmp.w _RIBDrawXFer


;
;	* * * * * * *       DRAW B       * * * * * * *
;
	; mode 'AX'
_RIBDrawB:
;
;	>>>   TRANSFER RGB   <<<
;
	bit.w RLRGBLock	; RGB Palettes Locked?
	bmi _RIBDrawB200	; Yes!
	lda.w RLRGBPtr	; Any RGB to XFer?
	bmi _RIBDrawB200	; No
	sta.w DMA5A1L
	ora.w #$8000
	sta.w RLRGBPtr
	lda.w #(256*2)	; Transfer 256 RGB Colours
	sta.w DMA5NUML
	stz.w CGADD-1
	lda.w #(1<<5)
	sta.w MDMAEN
;
;	>>>   TRANSFER STATUS BAR OAMS   <<<
;
_RIBDrawB200:
	lda.w #rlfStatus	; STATUS Ready?
	tsb.b RLFlags
	bne _RIBDrawB400	; No
	lda.w #(23*2)	; Transfer OAM structure
	sta.w OAMADDL
	lda.w #lo16(OAMA+(23*4))
	sta.w DMA6A1L
	lda.w #(9*4)	; #Bytes to transfer
	sta.w DMA6NUML
	lda.w #(1<<6)
	sta.w MDMAEN
;
;	>>>   TRANSFER DRAW B   <<<
;
_RIBDrawB400:
	lda.w #(2*2)	; IRQ Phase 2
	sta.b IRQTPhase
	sta.b IRQBPhase
	lda.w ViewB
	and.w #$0004
	tax
	lda.l _RLChrDefsB,x	; .A = VRAM Dest.
	jmp.w _RIBDrawXFer


;
;	* * * * * * *       DRAW C       * * * * * * *
;
	; mode 'AX'
_RIBDrawC:
;
;	>>>   TURN OFF WEAPON SPRITES WHEN IN AUTOMAP MODE!   <<<
;
	sep #$20		; mode 'a!'
	lda.w AutoMapMode+!RLSNESGSUXVarsO	; AutoMap On?
	cmp.b AutoMapModeOld	; Changed?
	beq _RIBDrawC400	; No
	sta.b AutoMapModeOld
	ldx.w #lo16(OAMA+(32*4))	; WEAPON Sprites
	ldy.b WeaponOAMBytesOld	; #Bytes to transfer
	dec a
	bmi _RIBDrawC200
	ldx.w #lo16(OAMB)	; BLANK Sprites
	ldy.w #(RLMaxCutSprOAMs*4)-2	; #Bytes to transfer
_RIBDrawC200:
	jmp.w _RIBDrawC480
;
;	>>>   TRANSFER WEAPON OAM TABLE   <<<
;
_RIBDrawC400:
	lda.b #rlfWeaponOAM	; WEAPON OAM BUILT?
	tsb.b RLFlags
	bne _RIBDrawC600
	lda.b AutoMapModeOld	; AutoMap On?
	bne _RIBDrawC600	; Yes, don't transfer OAMs!
	ldy.b WeaponOAMBytes	; #Bytes to transfer
	tyx
	cpy.b WeaponOAMBytesOld	; More than last time?
	bcs _RIBDrawC420	; Yes
	ldy.b WeaponOAMBytesOld	; No, must send BLANKS
_RIBDrawC420:
	stx.b WeaponOAMBytesOld	; #Bytes Transferred
	ldx.w #lo16(OAMA+(32*4))
_RIBDrawC480:
	stx.w DMA6A1L
	sty.w DMA6NUML
	ldx.w #(32*2)
	stx.w OAMADDL
	lda.b #(1<<6)
	sta.w MDMAEN
;
;	>>>   FLIP VIEW BUFFERS   <<<
;
_RIBDrawC600:
	rep #$20		; mode 'A!'
	lda.w #(3*2)	; IRQ Phase 3
	sta.b IRQTPhase
	sta.b IRQBPhase
	lda.w View	; Flip Views
	xba
	sta.w View
	and.w #$0004
	tax
;
;	>>>   TRANSFER VRAM MAP   <<<
;
_RIBDrawC800:
	lda.w #vmMAP1	; VRAM Destination
	sta.w VMADDL
	lda.l _RLVMaps,x	; VRAM Map of the view to show
	sta.w DMA7A1L	; SourceData
	lda.w #(RLViewCharY*32*2)-((32-RLViewCharX)*2)	; #Bytes
	sta.w DMA7NUML
	lda.w #(1<<7)
	sta.w MDMAEN
;
;	>>>   TRANSFER DRAW C   <<<
;
	lda.w #vmCHRC
	jmp.w _RIBDrawXFer


;
;	* * * * * * *       DRAW D       * * * * * * *
;
	; mode 'AX'
_RIBDrawD0:
;
;	>>>   HANDLE REGULAR SOUND EFFECTS   <<<
;
	jsr.w _RLIRQUpdateSounds	; Update Regular Sound Effects
;	jmp	_RIB3000			; Convert 4-Phase to 3-Phase
;
;	(this port) No weapon to transfer (most frames): this blank is free, so
;	the next frame's third A goes now if it is drawn and the blank has
;	room for it (a third uses ~70 of its 86 lines): a frame takes 3 VBlanks
;	instead of 4 when the GSU keeps up.
;
	lda.w TQCount	; A third waiting in WRAM?
	beq _RIBDrawD090	; No
	sep #$20		; mode 'a!'
	lda.l _SLHV	; Latch Raster Position
	lda.l _STAT78	; (reset the OPVCT flip-flop)
	lda.l _OPVCT
	xba
	lda.l _OPVCT
	and.b #1
	xba
	rep #$20		; mode 'A!'
	cmp.w #(RLVIntBottom+4)	; Still at the start of the blank?
	bcs _RIBDrawD090	; No
	ldx.w #0	; Yes: phase A now
	jmp.w (_RIBPhaseCode,x)
_RIBDrawD090:
	jmp.w _RLIRQGSU

_RIBDrawD:
	if !DEBUGSCR != 0
;
;	>>>   UPDATE DEBUGGING SCREEN   <<<
;
	lda.w #rlfDebug	; DEBUGGING SCREEN UPDATE?
	tsb.b RLFlags
	bne _RIBDrawD120	; No
	jsr.w _RLDebugScreen	; YES!  Update Debugging Screen!
_RIBDrawD120:
	endif
;
;	>>>   TRANSFER DONE   <<<
;
	stz.b IRQBPhase	; IRQ Phase 0
;	stz	IRQTPhase			; IRQ Phase 0
;
;	>>>   TRANSFER WEAPON DEFS   <<<
;
	lda.w #rlfWeaponDEF	; WEAPON BUILT?
	bit.b RLFlags
	bne _RIBDrawD0	; No
;
;	(this port) A weapon to send: if the next frame's third A is drawn, it
;	goes first (phase A now, as with no weapon) and the weapon follows at
;	the end of a third upload with room left in its blank (_RIBDrawXFer);
;	only a weapon still waiting at the next phase D gets this blank.
;
	lda.w TQCount	; A third waiting in WRAM?
	beq _RIBDrawD050	; No: the weapon now
	lda.w WeaponWait	; Already waited a frame?
	bne _RIBDrawD050	; Yes: now
	jsr.w _RLLinesLeft	; Still at the start of the blank?
	cmp.w #(86-4)
	bcc _RIBDrawD050	; No
	inc.w WeaponWait
	jsr.w _RLIRQUpdateSounds	; Update Regular Sound Effects
	ldx.w #0	; Phase A now
	jmp.w (_RIBPhaseCode,x)
_RIBDrawD050:
	jsr.w _RIBWeaponUp
	jmp.w _RLIRQGSU
;
;	>>>   SEND THE WEAPON: ITS DEFS, THEN ITS OAM TABLE   <<<
;
;	(this port: a subroutine; the GDMA chain returns through the stack,
;	and the saved stack pointer includes this call's return address)
;
	; mode 'AX'
_RIBWeaponUp:
	stz.w WeaponWait
	lda.w #rlfWeaponDEF	; Weapon sent
	tsb.b RLFlags
	tsc	; Save NMI StackPointer
	sta.w _MCHRGDMASP
	lda.w #lo16(DMA0INC)	; Set DPR $4300
	tcd
	; dpr DMA0INC
;
;	>>>   TRANSFER WEAPON DEF STACK TO VRAM   <<<
;
	lda.w WeaponDEFGDMA	; DEF GDMA Stack
	sta.b DMA7A1L-DMA0INC
	lda.w #vmWEAPONDEF	; VRAM Address
	sta.w VMADDL
	lda.w WeaponDEFGDMABytes	; #Bytes to DMA
	sta.b DMA7NUML-DMA0INC
	sep #$10		; mode 'x!'
	ldy.b #(1<<7)
	sty.w MDMAEN
;
;	>>>   TRANSFER VRAM COPY OF WEAPON DEF STACK TO EXECUTABLE WRAM LOCATION   <<<
;
	lda.w #vmWEAPONDEF	; VRAM Address
	sta.w VMADDL
	lda.w _VMDATAL	; Take care of false read
	lda.w WeaponDEFGDMABytes	; #Bytes to DMA
	sta.b DMA7NUML-DMA0INC
	lda.w #_WeaponDEFGDMAStack	; MCHR_GDMA StackPointer
	sta.b DMA7A1L-DMA0INC
	ldx.b #bank(_WeaponDEFGDMAStack)
	stx.b DMA7A1B-DMA0INC
	ldx.b #%10000001	; B->A, Abs., Auto Inc,2-Add-WriteLH
	stx.b DMA7INC-DMA0INC
	ldx.b #lo16(_VMDATAL)	; _VMDATA
	stx.b DMA7DEST-DMA0INC
	sty.w MDMAEN
;
;	>>>   INITIALIZE ALL GDMA CHANNELS   <<<
;
	ldx.b #bank(_CharDef)	; Bank of CharacterDEF Data
	stx.b DMA0A1B-DMA0INC
	stx.b DMA1A1B-DMA0INC
	stx.b DMA2A1B-DMA0INC
	stx.b DMA3A1B-DMA0INC
	stx.b DMA4A1B-DMA0INC
	stx.b DMA5A1B-DMA0INC
	stx.b DMA6A1B-DMA0INC
	stx.b DMA7A1B-DMA0INC
	ldx.b #%00000001	; A->B, Abs., Auto Inc,2-Add-WriteLH
	stx.b DMA4INC-DMA0INC
	stx.b DMA5INC-DMA0INC
	stx.b DMA6INC-DMA0INC
	stx.b DMA7INC-DMA0INC
	ldx.b #lo16(VMDATAL)	; B Address
	stx.b DMA4DEST-DMA0INC
	stx.b DMA5DEST-DMA0INC
	stx.b DMA6DEST-DMA0INC
	stx.b DMA7DEST-DMA0INC
;
;	* * * * * * *       START THE GDMA       * * * * * * *
;
	lda.w #vmWEAPONDEF	; Starting Character#
	sta.w VMADDL
	lda.w #(_WeaponDEFGDMAStack-1)	; MCHR_GDMA StackPointer
	tcs
	ldy.b #(1*32)	; #Bytes to Transfer per Channel
	ldx.b #%11111111	; Start 8-Channel GDMA
	rts	; Call First GDMA Transfer!
;
;	* * * * * * *       RETURNS HERE AFTER GDMA COMPLETED       * * * * * * *
;
_WDMGEndCode:
	lda.w #0	; Set DPR $0000
	tcd
	; dpr 0
	lda.w _MCHRGDMASP	; Restore StackPointer
	tcs
;
;	>>>   TRANSFER WEAPON OAM TABLE   <<<
;
	ldx.b AutoMapModeOld	; AutoMap On?
	bne _RIBDrawD300	; Yes, don't transfer OAMs!
	lda.b WeaponOAMBytes	; #Bytes to transfer
	cmp.b WeaponOAMBytesOld	; More than last time?
	bcs _RIBDrawD220	; Yes
	lda.b WeaponOAMBytesOld	; No, must send BLANKS
_RIBDrawD220:
	sta.w DMA6NUML
	lda.w #lo16(OAMA+(32*4))
	sta.w DMA6A1L
	lda.w #(32*2)
	sta.w OAMADDL
	ldx.b #(1<<6)
	stx.w MDMAEN
_RIBDrawD300:
	lda.b WeaponOAMBytes	; #Bytes Transferred
	sta.b WeaponOAMBytesOld
;
_RIBDrawD400:
	rep #$10		; mode 'X!'
	rts
;
;	(this port) Lines left in the blank before the top IRQ (0 in the view).  mode 'AX'; A.
;
_RLLinesLeft:
	sep #$20		; mode 'a!'
	lda.l _SLHV	; Latch Raster Position
	lda.l _STAT78	; (reset the OPVCT flip-flop)
	lda.l _OPVCT
	xba
	lda.l _OPVCT
	and.b #1
	xba
	rep #$20		; mode 'A!'
	cmp.w #RLVIntTop	; Before the top IRQ line?
	bcs ._1
	eor.w #$FFFF	; RLVIntTop - line
	sec
	adc.w #RLVIntTop
	rts
._1:
	cmp.w #RLVIntBottom	; In the view?
	bcs ._2
	lda.w #0
	rts
._2:
	eor.w #$FFFF	; lines per frame - line + RLVIntTop
	sec
	if usePAL != 0
	adc.w #(312+RLVIntTop)
	else
	adc.w #(262+RLVIntTop)
	endif
	rts



;
;	* * * * * * *       REALITY_ENGINE IRQ AT TOP OF SCREEN       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLIRQTop:
	sep #$20		; mode 'a!'
	pha
	lda.l _SLHV	; Latch Raster Position
	lda.l _STAT78	; Update H/V Counters
	lda.l _OPVCT	; Get Low 8Bits VPos
	cmp.b #(RLVIntTop-1)	; (this port) From 1 scanline above to the
	bcc _RIT0900	; bottom IRQ's line: the top IRQ, maybe late (an IRQ
	cmp.b #(RLVIntBottom-1)	; handler ran into its line; the original took it for a GSU
	bcc _RIT1000	; IRQ: the display stayed off, a black frame)
_RIT0900:
	xba	; (GSU)
	pha
	phb	; Save .DBR
	lda.b #$00
	pha
	plb
	; dbr $00
	rep #$30		; mode 'AX!'
	phx
	phy
	jmp.w _RLIRQGSU

;
;	>>>   SCANLINE AT TOP OF DISPLAY   <<<
;
	; mode 'a'
_RIT1000:
	lda.b #(RLHIntR+0)	; Right Horizontal Interrupt
	sta.l HTIMEL
	lda.l sfxSFR+1	; Clear GSU Flag
	lda.l _TIMEUP	; Clear IRQ Flag
;	(this port) WAI waits for the IRQ at RLHIntR on this line.  When that
;	point has passed (the IRQ came late after a GSU IRQ handler), WAI would
;	wait up to a frame for the next GSU IRQ (display left blanked, or the
;	VRAM transfer lost): then no WAI.
	lda.l _SLHV	; Latch Raster Position
	lda.l _STAT78	; (reset the OPHCT/OPVCT flip-flops)
	lda.l _OPVCT
	cmp.b #RLVIntTop
	bcc _RIT1000W	; (a line early: the IRQ is still to come)
	bne _RIT1000L	; Past the line
	lda.l _OPHCT	; H (9 bits)
	pha
	lda.l _OPHCT
	lsr a
	pla
	bcs _RIT1000L
	cmp.b #(RLHIntR-16)	; (the IRQ comes when H reaches RLHIntR)
	bcs _RIT1000L
_RIT1000W:
	lda.l INIDISP_S	; Enable Display
	wai
	bra _RIT1000S
_RIT1000L:
	lda.l INIDISP_S	; Enable Display
_RIT1000S:
	sta.l INIDISP
;
	xba
	pha
	phb
	lda.b #$00
	pha
	plb
	; dbr $00
;
	lda.b #hi16(((256-1-((256-RLPixX)/2))<<8)+((256-RLPixX)/2))	; Set Window Masks
	sta.w WH1
	lda.b #lo16(((256-1-((256-RLPixX)/2))<<8)+((256-RLPixX)/2))	; Set Window Masks
	sta.w WH0
;
;	>>>   TIMERS/COUNTERS   <<<
;
	if (!DEBUG*WIRE) == 0
	inc.w VBlankCount	; VBlankCounter++
	if usePAL != 0
	lda.l VBlankCountF
	clc
	adc.b #hi16((60-50)*65536/50)
	sta.l VBlankCountF
	bcc _RIT1100
	inc.w VBlankCount
_RIT1100:
	endif
	endif
;
	lda.b #(rlfHalt>>8)	; RLEngine Halting?
	bit.b RLFlags+1
	beq _RIT2000	; Yes, Don't Count Time when Halted!
;
	inc.w VBlankTotal	; VBlankCountTotal++
;
	dec.w PlayerLevelCount	; #Ticks until 1 Second
	bne _RIT2000
	lda.b #60	; Count one more Second!
	sta.w PlayerLevelCount
	rep #$20		; mode 'A!'
	lda.w PlayerLevelTime	; At 59:59?
	cmp.w #(60*60)-1
	beq _RIT2000	; Yes, No Higher!
	inc.w PlayerLevelTime	; Player's LevelTimer++
;
_RIT2000:
	rep #$30		; mode 'AX!'
	phx
	phy
	lda.w #RLVIntBottom	; Initialize Interrupt Timer
	sta.w VTIMEL
	lda.w #RLHIntL	; Left Horizontal Interrupt
	sta.w HTIMEL
	lda.w #lo16(_RLIRQBottom)	; Set up Bottom IRQ
	sta.w GSUIRQRAM+1
	bit.w _TIMEUP	; Clear IRQ Flag
;	cli					; Release Interrupts for GSU
;
;	>>>   IRQ PHASE DISPATCH   <<<
;
_RIT3000:
	ldx.b IRQTPhase	; Get Current IRQ TOP Phase
	jmp.w (_RITPhaseCode,x)	; IRQ TOP PhaseCode
;
;	* * * * * * *       IRQ TOP PHASE CODE JUMP TABLE       * * * * * * *
;
_RITPhaseCode:
	dw lo16(_RIT5000)	; Idle
	dw lo16(_RITDrawA)	; Post Draw A
	dw lo16(_RITDrawB)	; Post Draw B (ConvertJoy)
	dw lo16(_RITDrawC)	; Post Draw C (Vars)
	dw lo16(_RITMenus)	; Menus


;
;	* * * * * * *       MENUS       * * * * * * *
;
	; mode 'AX'
_RITMenus:
	jsr.w ReadJOY	; Read JOYSTICK/MOUSE
	jsr.w ConvertJOY	; Convert JOYSTICK->MOUSE
	stz.w PlayerMouseTurn	; (no turning while in the menus)
	jmp.w _RIT10000


;
;	* * * * * * *       DRAW A       * * * * * * *
;
	; mode 'AX'
_RITDrawA:
;
;	>>>   SWAP ENGINE TRANSFER VARIABLES   <<<
;
	jsr.w _RLSwapRLXVars
	jmp.w _RIT9000


;
;	* * * * * * *       DRAW B       * * * * * * *
;
	; mode 'AX'
_RITDrawB:
;
;	>>>   HANDLE JOYSTICK/MOUSE   <<<
;
	jsr.w ConvertJOY	; Convert JOYSTICK->MOUSE
	jmp.w _RIT5000


;
;	* * * * * * *       DRAW C       * * * * * * *
;
	; mode 'AX'
_RITDrawC:
;
;	>>>   FRAME PROCESSING COMPLETED   <<<
;
	sep #$20		; mode 'a!'
	if !DEBUG != 0
	bit.b FrameDone	; Did GSU Catch up with SNES?
	bpl ._0	; No
	%HALT($22)	; YES!!!  ERROR!!!
._0:
	endif
	dec.b FrameDone	; Frame Completed!
;
;	>>>   CALCULATE FRAMES_PER_SECOND COUNT   <<<
;
	lda.w VBlankCount	; Get #VBlanks from Last Frame
	stz.w VBlankCount
	rep #$20		; mode 'A!'
	and.w #$00FF
	sta.w FPSCount	; #FramesPerSecond
;
;	>>>   SWAP ENGINE TRANSFER VARIABLES   <<<
;
	jsr.w _RLSwapRLXVars2
	inc.w TQMiscTokens	; (this port) the GSU may start one more frame
;
;	* * * * * * *       HANDLE PALETTE ANIMATION       * * * * * * *
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE   !!!
;
	; mode 'AX'
_RIT5000:
	bit.w RLRGBLock	; RGB Palettes Locked?
	bmi _RIT6000	; Yes!
	dec.w RLRGBCount	; Time for next RGB Cycle?
	bpl _RIT6000	; No!
	lda.w RLRGBPtr	; RGB XFer Ready?
	bpl _RIT6000	; No
	ldx.w RLRGBAnim	; Get Current RGB Anim Index
	lda.l RLRGBAnims,x	; Get Next Animation Palette
	bne _RIT5500	; Normal Animation Entry
	stz.w RLRGBPickCount	; ReStart Pick Counter
	stz.w RLRGBHitCount	; ReStart Hit Counter
	ldx.w RLRGBAnim0	; Get Base Animation Table
	lda.l RLRGBAnims,x	; Get Next Animation Palette
_RIT5500:
	sta.w RLRGBPtr	; Transfer this Palette
	lda.l RLRGBAnims+2,x	; Get Count
	sta.w RLRGBCount
	inx
	inx
	inx
	inx
	stx.w RLRGBAnim	; Save New AnimPointer
;
;	* * * * * * *       HANDLE WEAPON BUILDS       * * * * * * *
;
_RIT6000:
	ldx.b WeaponIRQBuildPhase	; Build Weapon Data!
	jsr.w (WeaponIRQBuildPhaseCode,x)
;
;	* * * * * * *       READ JOYSTICK/MOUSE       * * * * * * *
;
	jsr.w ReadJOY	; Read JOYSTICK/MOUSE
;
;	* * * * * * *       RESET TOP IRQ PHASE TO IDLE       * * * * * * *
;
_RIT9000:
	stz.b IRQTPhase	; IRQ Phase 0

;
;	* * * * * * *       HANDLE TURBO SOUND EFFECTS       * * * * * * *
;
_RIT10000:
	jsr.w RumbleFrame	; (this port) Rumble: mix and send (every frame)
	jsr.w _RLIRQUpdateTSounds	; Update Turbo Sound Effects

;
;	* * * * * * *       REALITY_ENGINE IRQ GSU START CODE       * * * * * * *
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE   !!!
;
	; mode 'AX'
_RLIRQGSU:
;	sei					; Lock out GSU Interrupts!
	jsr.w _RLCopyThird	; (this port) a drawn third to WRAM?
	jsr.w _RLGSUStart	; Start the GSU's next phase if it is halted and ready
	jmp.w _RLIRQDone
;
;	(this port) The GSU start as a subroutine: also called by the bottom IRQ
;	before a VRAM upload, so the GSU runs on during it (the upload reads WRAM)
;	instead of waiting until the IRQ ends.  mode 'AX', dbr $00, dpr 0; A, X.
;
	; mode 'AX'
_RLGSUStart:
	lda.w sfxSFR	; GSU Halted?
	and.w #%0000000000100000
	beq _RIG200	; Yes, Start It Up!
	rts
	; mode 'AX'
_RIG200:
;_RLIRQGSU2
	ldx.b GSUPhase	; Get Current GSU Phase
	lda.w #rlfPhasePending	; Phase Pending
	tsb.b RLFlags	; Already Adjusted Phase?
	bne _RLIRQGSU3	; Yes
;
	if !DEBUG != 0
	lda.l GSUERROR	; Any GSU Error?
	beq ._1	; No
	cmp.w #$524C	; Debugging Halt?
	beq ._0	; YES!
	%HALT($23)	; No, GSU Error!!!
._0:
	cop #'R'	; ***SNES HALTS HERE***
	lda.w #0	; ***RESUME EXECUTION***
	sta.l GSUERROR
._1:
	endif
;
	jsr.w (GSUPhasePostCode,x)	; GSU PostCode
	inx	; Get Next GSU Phase
	inx
	cpx.w #MaxGSUPhase
	bne _RIG400
	ldx.w #0	; Completed All Phases!
_RIG400:
	stx.b GSUPhase
_RLIRQGSU3:
	jsr.w _RLCopyThird	; (this port) the third just drawn to WRAM?
	ldx.b GSUPhase
;
;	>>>   START GSU RUNNING NEXT PHASE   <<<
;
	jsr.w (GSUPhaseReqCode,x)	; All Requirements Met?
	beq _RIG900	; No, can't start GSU
	if !DEBUG != 0
	lda.w #$524C	; GSU DEBUGGING HALT CODE
	sta.l GSUERROR
	endif
	txa	; (this port) starting a frame's tasks phase?
	bne ._2
	dec.w TQMiscTokens	; Yes, use up one token (_RLGSUReqMisc)
._2:
	lda.l GSUPhaseR15,x	; Get Starting PC
	sta.w sfxR15
	lda.w #rlfPhasePending	; Phase NOT Pending
	trb.b RLFlags
_RIG900:
	rts
;
;	* * * * * * *       REALITY_ENGINE IRQ COMPLETION CODE       * * * * * * *
;
_RLIRQDone:
	ply
	plx
	plb
	sep #$20		; mode 'a!'
	pla
	xba
	pla
	rti


;
;	* * * * * * *       COPY A DRAWN SCREEN THIRD TO WRAM       * * * * * * *
;
;	(this port) The GSU draws each third of the view into one buffer
;	(_RLGSUChrDef, 11 KB).  A drawn third is copied to one of two WRAM
;	buffers (DMA GSU RAM -> WMDATA, 9 strips of about 7 scanlines; the GSU's
;	RAM is taken meanwhile), so the GSU draws on while the bottom IRQ sends
;	it to VRAM.  The buffers ($7E:8000-$7E:D8FF) are SaveRaw, unused while a
;	level runs.
;
;	Called from _RLIRQGSU at every IRQ: copies strips while the GSU buffer
;	holds a drawn third (rlfDraw clear), a WRAM buffer is free and the
;	strip ends before the next top/bottom IRQ's scanline (else a later IRQ
;	copies the rest).
;
	; dbr 0
	; dpr 0
	; mode 'AX'
_RLCopyThird:
	lda.w TQNoCopy	; (the GSU start before a VRAM upload: the blank is the upload's)
	bne .no0
	lda.b RLFlags	; GSU buffer holds a drawn third?
	and.w #rlfDraw
	bne .no0	; No
	if !TQIDLE != 0
	lda.w sfxSFR	; (test build) only while the GSU is halted
	and.w #%0000000000100000
	bne .no0
	endif
	lda.w TQCount	; A WRAM buffer free?
	cmp.w #2
	bcc .strip	; Yes
.no0:
	rts
.strip:
	sep #$20		; mode 'a!'
	lda.l _SLHV	; Latch Raster Position
	lda.l _STAT78	; (reset the OPVCT flip-flop)
	lda.l _OPVCT
	xba
	lda.l _OPVCT
	and.b #1
	xba
	rep #$20		; mode 'A!'
	cmp.w #(RLVIntTop-TQStripLines)	; In the blank, ending before the top IRQ?
	bcc .blank
	cmp.w #RLVIntTop
	bcc .no
	cmp.w #(RLVIntBottom-TQStripLines)	; In the display, ending before the bottom IRQ?
	bcc .display
	cmp.w #(RLVIntBottom+1)
	bcc .no	; (after the bottom IRQ: the blank)
;
;	(this port) ... and only when that IRQ has come: an IRQ still waiting
;	(this IRQ came just before its line) would wait for the whole copy, and a
;	top IRQ that comes late is taken for a GSU IRQ (a black frame).
;
.blank:
	lda.w GSUIRQRAM+1	; The bottom IRQ done (the top one next)?
	cmp.w #lo16(_RLIRQTop)
	beq .copy
	bra .no
.display:
	lda.w GSUIRQRAM+1	; The top IRQ done (the bottom one next)?
	cmp.w #lo16(_RLIRQTop)
	beq .no
.copy:
	lda.w TQHead	; The tail of the queue
	clc
	adc.w TQCount
	and.w #1
	asl a
	tax
	lda.w TQStrip	; Strip * 1280 (= *256 + *1024)
	xba
	sta.w TQSrc
	asl a
	asl a
	clc
	adc.w TQSrc
	sta.w TQSrc
	clc
	adc.l _TQBufs,x
	sta.w WMADDL	; WRAM bank $7E (WMADDB = 0)
	lda.w TQSrc
	clc
	adc.w #lo16(_RLGSUChrDef)
	sta.w DMA4A1L	; (channel 4: GSU RAM -> WMDATA, _RLReInitDMA)
	lda.w #(RLViewCharY*64)	; (the 18 rows shown; rows 19-20 hold other data)
	sta.w DMA4NUML
	sep #$20		; mode 'a!'
	lda.b #%00010111	; 160 Pixels, GSU has ROM, SNES has RAM, 256 Colour
	sta.w sfxSCR
	lda.b #(1<<4)
	sta.w MDMAEN
	lda.b #%00011111	; 160 Pixels, GSU has ROM/RAM, 256 Colour
	sta.w sfxSCR
	rep #$20		; mode 'A!'
	inc.w TQStrip
	lda.w TQStrip
	cmp.w #9
	bcs ._1
	jmp.w .strip
._1:
	stz.w TQStrip	; Third copied
	inc.w TQCount
	lda.w #rlfDraw	; GSU buffer free again
	tsb.b RLFlags
.no:
	rts

	TQStripLines = 9	; (1152 bytes x 8 master clocks / 1364 per line, + margin)
	TQThirdBytes = $2C80	; (_RLGSUChrDefEnd-_RLGSUChrDef)
	TQBuf0 = $7E8000
	TQBuf1 = TQBuf0+TQThirdBytes
	assert (_RLGSUChrDefEnd-_RLGSUChrDef) == TQThirdBytes, "the screen third buffer changed size"
	assert TQBuf1+TQThirdBytes <= $7EF000, "screen thirds overlap the save text buffer"
_TQBufs:
	dw lo16(TQBuf0),lo16(TQBuf1)

;
;	* * * * * * *       VIEW MAP COMMON AREAS       * * * * * * *
;
_RLChrDefsA:
	dd vmCHRA,vmCHRD
_RLChrDefsB:
	dd vmCHRB,vmCHRE
_RLVMaps:
	dd RLVMap0,RLVMap1


;
;	* * * * * * *       SWAP ENGINE TRANSFER VARIABLES       * * * * * * *
;
	; dbr 0
	; dpr 0
	; mode 'AX'
_RLSwapRLXVars:
	sep #$10		; mode 'x!'
	ldx.b #%00010111	; 160 Pixels, GSU has ROM, SNES has RAM, 256 Colour
	ldy.b #%00011111	; 160 Pixels, GSU has ROM/RAM, 256 Colour
;	ifn	DEBUG
;	stx	SCR_XS				; XSLV Shadow
;	endif
	stx.w sfxSCR
;
;	>>>   GET GSU VARIABLES   <<<
;
	lda.w #lo16(RLGSUXVars)	; SourceData
	sta.w DMA4A1L
	lda.w #lo16(RLSNESGSUXVars)	; WRAM Address
	sta.w WMADDL
	lda.w #(RLGSUXVarsE-RLGSUXVars)	; #Bytes
	sta.w DMA4NUML
	ldx.b #(1<<4)
	stx.w MDMAEN
;
;	>>>   TRANSFER SOUND COMMAND BUFFER FROM GSU TO WRAM   <<<
;
	lda.w RLNumSounds+!RLSNESGSUXVarsO	; Any Sounds to Process?
	and.w _SoundsOn	; SoundEffects Enabled?
	beq _RLSwapRLXVarsB	; No!
	asl a	; Yes, Get the SoundEffects
	sta.w DMA4NUML
	lda.w #lo16(RLGSUSounds)	; SourceData
	sta.w DMA4A1L
	lda.w #lo16(RLSNESSounds)	; WRAM Address
	sta.w WMADDL
	stx.w MDMAEN
_RLSwapRLXVarsB:
;
;	>>>   TRANSFER RUMBLE REQUESTS FROM GSU TO WRAM (this port)   <<<
;
	lda.w #(2+MaxRLRumbles)	; (the count and the requests)
	sta.w DMA4NUML
	lda.w #lo16(RLNumRumbles)	; SourceData
	sta.w DMA4A1L
	lda.w #lo16(RLSNESRumbleN)	; WRAM Address
	sta.w WMADDL
	stx.w MDMAEN
;
;	>>>   CHECK FOR GSU ERROR   <<<
;
	if !DEBUG != 0
	lda.l GSUERROR	; ANY GSU ERROR?
	beq ._3	; No
	cmp.w #$524C	; DEBUGGING HALT?
	beq ._3	; Yes
	%HALT($24)	; NO, GSU ERROR!!!
._3:
	endif

;	ifn	DEBUG
;	sty	SCR_XS				; XSLV Shadow
;	endif
	sty.w sfxSCR
	rep #$10		; mode 'X!'
;
;	>>>   ADD RUMBLE REQUESTS (this port)   <<<
;
	lda.w RLSNESRumbleN
	beq ._r
	jsr.w RumbleQueue
._r:
;
;	>>>   UPDATE SOUND EFFECTS QUEUES   <<<
;
	lda.w RLNumSounds+!RLSNESGSUXVarsO	; Any New Sounds to Process?
	and.w _SoundsOn	; SoundEffects Enabled?
	beq _RLSwapRLXVarsC	; No
	jmp.w _RLIRQUpdateSoundQueues	; YES!  Add New SoundEffects to Queues
_RLSwapRLXVarsC:
	rts


;
;	* * * * * * *       SWAP ENGINE TRANSFER VARIABLES       * * * * * * *
;
	; dbr 0
	; dpr 0
	; mode 'AX'
_RLSwapRLXVars2:
	sep #$10		; mode 'x!'
	ldx.b #%00010111	; 160 Pixels, GSU has ROM, SNES has RAM, 256 Colour
	ldy.b #%00011111	; 160 Pixels, GSU has ROM/RAM, 256 Colour
;	ifn	DEBUG
;	stx	SCR_XS				; XSLV Shadow
;	endif
	stx.w sfxSCR
;
;	>>>   SEND SNES VARIABLES TO GSU   <<<
;
	lda.w FPSCount
	sta.l FPSCount+RLGSUSNESXVarsO
	lda.w WeaponTypeBuilt
	sta.l WeaponTypeBuilt+RLGSUSNESXVarsO
	lda.w PlayerJoy
	sta.l PlayerJoy+RLGSUSNESXVarsO
	lda.w PlayerMouseX
	sta.l PlayerMouseX+RLGSUSNESXVarsO
	lda.w PlayerMouseY
	sta.l PlayerMouseY+RLGSUSNESXVarsO
	lda.w PlayerMouseTurn	; Mouse turn since the last frame
	sta.l MouseTurn
	stz.w PlayerMouseTurn
	lda.w VBlankTotal
	sta.l VBlankTotal+RLGSUSNESXVarsO
;
;	>>>   DEBUGGING FPS COUNTER   <<<
;
	if (0*!DEBUG) != 0
	lda.w FPSCount
	sta.l PlayerArmor
	endif

;	ifn	DEBUG
;	sty	SCR_XS				; XSLV Shadow
;	endif
	sty.w sfxSCR
	rep #$10		; mode 'X!'
	rts
