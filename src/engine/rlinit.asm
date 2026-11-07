	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                     ENGINE INITIALIZATION MODULE                   *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/xfer.inc"

	; public _RLInit


	%section(ENGINE)
;
;	* * * * * * *       INITIALIZE REALITY_ENGINE       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInit:
;
;	>>>   INITIALIZE SNES HARDWARE   <<<
;
	jsr.w _RLInitPPU	; Initialize PPU
	jsr.w _RLInitRGB	; Initialize RGB
;
;	>>>   INITIALIZE SNES SOFTWARE   <<<
;
	jsr.w _RLInitRAMCode	; Initialize RL RAM Code
;
;	>>>   INITIALIZE ENGINE/SNES SOFTWARE   <<<
;
	if !DEBUGSCR != 0
	jsl.l _RLInitDebug	; Initialize DEBUG
	endif
	jsl.l _RLInitStatusBar	; Initialize Status Bar
	jsl.l _RLFinalDeComp	; Final DeCompression!
;
	; mode 'A'
	lda.w #$0201	; Initialize Single Bit Array
	sta.l SingleBitArray+0
	lda.w #$0804
	sta.l SingleBitArray+2
	lda.w #$2010
	sta.l SingleBitArray+4
	lda.w #$8040
	sta.l SingleBitArray+6
;
	jsr.w _RLInitVRAMMaps	; Initialize VRAM Maps
	jsr.w _RLInitOAM	; Initialize OAMs
	jsl.l _RLInitAutoMap	; Initialize AutoMap
	jsl.l _RLInitSound	; Initialize SOUND
	jsl.l _RLInitTasks	; Initialize TASKS
	jsl.l _RLInitPlats	; Initialize PLATFORMS
	jsl.l _RLInitMObjects	; Initialize MOVABLE OBJECTS
	jsl.l _RLInitToggles	; Initialize TOGGLES
;
;	>>>   INITIALIZE ENGINE<->SNES HARDWARE   <<<
;
	jsr.w _RLInitGSU	; Initialize GSU
	jsl.l _RLInitDMA	; Initialize DMA
;
;	>>>   INITIALIZE ENGINE<->SNES SOFTWARE   <<<
;
	jsr.w _RLInitView	; Initialize RL View
	jsl.l _RLInitIRQ	; Initialize RL IRQs
	jsl.l _RLInitNMI	; Initialize RL NMIs
;
	rep #$20		; mode 'A!'
	lda.w #~0	; RLEngine Running!
	sta.b RLFlags
	stz.b FrameDone	; Frame NOT Completed!
	lda.w #0	; Initialize Timer1
	sta.l Timer1
	stz.w FPSCount	; FPSCount = 0
	sta.l FPSRatio	; FPSRatio = 0
	sta.l RLCount	; Initialize RLEngineCount
	sta.l RLFrame	; Initialize RLFrameCount
	sta.l RLLineCount	; Initialize RLEngineLineCount
	sta.l RandomNumI	; Initialize RandomNumberIndex
;
	sta.l ExitLevel	; LEVEL NOT COMPLETED
;
	if IDLERESET != 0
	stz.w IdleCount	; Clear Idle TimeOut Reset
	endif
	rtl


;
;	* * * * * * *       INITIALIZE REALITY_ENGINE RAMCODE       * * * * * * *
;
;	Transfer Engine_RAMCode to WRAM
;
	; dbr ?
	; dpr 0
_RLInitRAMCode:
	rep #$30		; mode 'AX!'
	ldx.w #lo16(_RLRAMCodeROM)
	ldy.w #lo16(_RLRAMCode)
	lda.w #(_RLRAMCodeEnd-_RLRAMCode-1)
	phb
	mvn bank(_RLRAMCode),bank(_RLRAMCodeROM)	; src,dst = ^_RLRAMCodeROM,^_RLRAMCode
	plb
	rts


;
;	* * * * * * *       INITIALIZE REALITY_ENGINE PPU       * * * * * * *
;
;	Initialize SNES PPU Settings
;
	; dbr ?
	; dpr 0
_RLInitPPU:
	sep #$20
	rep #$10		; mode 'aX!'
	lda.b #(((vmCHR2>>12)<<4)|(vmCHR1>>12))
	sta.w BG12NBA	; Characters @$0000
	lda.b #lo16((RLPixX-256)/2)	; HOFS
	sta.w BG1HOFS
;	lda	#>((RLPixX-256)/2)
	stz.w BG1HOFS
	sta.w BG2HOFS
	stz.w BG2HOFS
	lda.b #((hi16(vmMAP1)&$FC)+%10)	; SC1
	sta.w BG1SC
	lda.b #((hi16(vmMAP2)&$FC)+%10)	; SC2
	sta.w BG2SC
	lda.b #lo16((((vmMAP1&$0FC0)-(vmMAP1&$0C00))/4)-((224-RLPixY)/2))
	sta.w BG1VOFS
	lda.b #hi16((((vmMAP1&$0FC0)-(vmMAP1&$0C00))/4)-((224-RLPixY)/2))
	sta.w BG1VOFS
	lda.b #lo16((((vmMAP2&$0FC0)-(vmMAP2&$0C00))/4)-((224-RLPixY)/2))
	sta.w BG2VOFS
;	lda	#>( (((vmMAP2&$0fc0)-(vmMAP2&$0c00)) / 4) - ((224-RLPixY)/2) )
	stz.w BG2VOFS
;
	ldx.w #(((256-1-((256-RLPixX)/2))<<8)+((256-RLPixX)/2))	; Set Window Masks
	stx.w WH0
	lda.b #%00110011	; Use Window1
	sta.w W12SEL
;	lda	#%00110011
	sta.w WOBJSEL
;	lda	#%00000000				; Window Logic is OR
	stz.w WBGLOG
	stz.w WOBJLOG
;
;	lda	#%00001000				; PseudoH512, 224Lines
	stz.w SETINI
	lda.b #$03	; Mode3 (BG1 256 Colour/BG2 16 Colour)
	sta.w BGMODE
	lda.b #%10100010	; SUB Colour Add Enable
	sta.w CGSWSEL
	lda.b #%01000001	; Enable 1/2 Addition on BG1
	sta.w CGADSUB
	lda.b #$13	; BG1+BG2+OBJ
	sta.w TM
	sta.w TMW	; BG1+BG2+OBJ Window
	lda.b #$10	; OBJ
	sta.w TS
	sta.w TSW	; OBJ Window
;
	lda.b #%00000000+(vmSPR>>13)	; (1x1,2x2) (8K contig.) (BaseAddr)
	sta.w OBJSEL
;
	lda.b #$80	; 16Bit VRAM Transfers
	sta.w VMAINC
	rts


;
;	* * * * * * *       INITIALIZE REALITY_ENGINE VRAM MAPS       * * * * * * *
;
;	Build and transfer MAPs for View0/View1 to VRAM
;
	; dbr ?
	; dpr 0
_RLInitVRAMMaps:
;
;	>>>   BUILD STATUS BAR MAP   <<<
;
	rep #$30		; mode 'AX!'
;
	lda.w #$524C	; BG1 Status Overlay
	ldx.w #((RLStatCharY*32)-1)*2
_RLIVM120:
	sta.l DeCompBuffer,x
	dex
	dex
	bpl _RLIVM120
;
	lda.w #((vmCHR2B-vmCHR2)/(32/2))+$2000	; BG2 View Overlay
	ldx.w #(((RLViewCharY-RLStatCharY)*32)-1)*2
_RLIVM140:
	sta.l DeCompBuffer+(RLStatCharY*32*2),x
	dex
	dex
	bpl _RLIVM140
;
	ldx.w #0	; Block "CHR2"
	lda.w #RLStatCharY
	sta.b Temp
	lda.w #((vmSTATDEF-vmCHR2)/(32/2))+$2000	; Force Priority of StatusBar BG2
_RLIVM200:
	ldy.w #RLStatCharX-1	; #Characters
_RLIVM300:
	sta.l DeCompBuffer+(RLViewCharY*32*2),x
	inc a
	inx
	inx
	dey
	bpl _RLIVM300
	tay
	txa
	clc
	adc.w #(32-RLStatCharX)*2
	tax
	tya
	dec.b Temp
	bne _RLIVM200
;
;	>>>   TRANSFER STATUS BAR MAP TO VRAM   <<<
;
	sep #$20		; mode 'a!'
	lda.b #%00000001	; A->B, Abs., Auto Inc,2-Add-WriteLH
	sta.w DMA0INC
	lda.b #lo16(VMDATAL)	; VMDATA
	sta.w DMA0DEST
	lda.b #bank(DeCompBuffer)
	sta.w DMA0A1B
	rep #$20		; mode 'A!'
	lda.w #lo16(DeCompBuffer)
	sta.w DMA0A1L
	lda.w #vmMAP2
	sta.w VMADDL
	lda.w #(RLCharY*32*2)
	sta.w DMA0NUML
	lda.w #(0<<8)+1
	sta.w MDMAEN
;
;	>>>   BUILD MAP 0   <<<
;
	rep #$30		; mode 'AX!'
	ldx.w #((RLCharX/3)*0*2)	; Block "A"
;	lda	#((RLCharX/3)*0*RLViewCharY)
	txa
	jsr.w _RLBuildVRAMMapBlock
;	ldx	#((RLCharX/3)*1*2)			; Block "B"
	lda.w #((RLCharX/3)*1*RLViewCharY)
	jsr.w _RLBuildVRAMMapBlock
;	ldx	#((RLCharX/3)*2*2)			; Block "C"
	lda.w #((RLCharX/3)*2*RLViewCharY)
	jsr.w _RLBuildVRAMMapBlock
;
;	>>>   BUILD MAP 1   <<<
;
	ldx.w #((RLCharX/3)*0*2)+(RLVMap1-RLVMap0)	; Block "D"
	lda.w #((RLCharX/3)*3*RLViewCharY)
	jsr.w _RLBuildVRAMMapBlock
;	ldx	#((RLCharX/3)*1*2)+(RLVMap1-RLVMap0)	; Block "E"
	lda.w #((RLCharX/3)*4*RLViewCharY)
	jsr.w _RLBuildVRAMMapBlock
;	ldx	#((RLCharX/3)*2*2)+(RLVMap1-RLVMap0)	; Block "C"
	lda.w #((RLCharX/3)*2*RLViewCharY)
;	jmp	_RLBuildVRAMMapBlock
;
;	* * * * * * *       BUILD VRAM MAP BLOCK       * * * * * * *
;
;	.X = Character Offset within Map
;	.A = Starting Character#
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE   !!!
;
	; mode 'AX'
	; dbr ?
	; dpr 0
_RLBuildVRAMMapBlock:
	ldy.w #(RLCharX/3)-1	; #Strips
_RLBVMB200:
	sta.l RLVMap0+(0*32*2),x
	inc a
	sta.l RLVMap0+(1*32*2),x
	inc a
	sta.l RLVMap0+(2*32*2),x
	inc a
	sta.l RLVMap0+(3*32*2),x
	inc a
	sta.l RLVMap0+(4*32*2),x
	inc a
	sta.l RLVMap0+(5*32*2),x
	inc a
	sta.l RLVMap0+(6*32*2),x
	inc a
	sta.l RLVMap0+(7*32*2),x
	inc a
	sta.l RLVMap0+(8*32*2),x
	inc a
	sta.l RLVMap0+(9*32*2),x
	inc a
	sta.l RLVMap0+(10*32*2),x
	inc a
	sta.l RLVMap0+(11*32*2),x
	inc a
	sta.l RLVMap0+(12*32*2),x
	inc a
	sta.l RLVMap0+(13*32*2),x
	inc a
	sta.l RLVMap0+(14*32*2),x
	inc a
	sta.l RLVMap0+(15*32*2),x
	inc a
	sta.l RLVMap0+(16*32*2),x
	inc a
	sta.l RLVMap0+(17*32*2),x
	inc a
	inx	; Next Strip
	inx
	dey	; One less strip
	bpl _RLBVMB200
	rts


;
;	* * * * * * *       INITIALIZE REALITY_ENGINE OAM SPRITES       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitOAM:
	sep #$20
	rep #$10		; mode 'aX!'
	ldy.w #MaxOAMs-(3+8+12+3+3+3)-1	; #OAMs total
	ldx.w #(3+8+12+3+3+3)*4	; Move All OAMs off-screen
	lda.b #MaxViewScanLines	; (256-32)
_RIO200:
	sta.w OAMA+oamsY,x
	sta.w OAMB+oamsY-((3+8+12+3+3+3)*4),x
	inx
	inx
	inx
	inx
	dey
	bpl _RIO200
;
	sep #$10
	rep #$20		; mode 'Ax!'
	stz.w OAMADDL	; Transfer OAM structure
	lda.w #lo16(OAMA)	; Start Channel#0
	sta.w DMA0A1L
	lda.w #(MaxOAMs+(MaxOAMs/16))*4	; #Bytes to transfer
	sta.w DMA0NUML
	ldx.b #lo16(OAMDATA)	; OAMDATA
	stx.w DMA0DEST
	ldx.b #%00000010	; A->B, Abs., Auto Inc,1-Add-Write2x
	stx.w DMA0INC
	ldx.b #bank(OAMA)
	stx.w DMA0A1B
	ldx.b #1	; Enable/Start Channel#0
	stx.w MDMAEN
	rts


;
;	* * * * * * *       INITIALIZE REALITY_ENGINE RGB PALETTE       * * * * * * *
;
;	Transfer RGB Palette
;
	; dbr ?
	; dpr 0
_RLInitRGB:
	rep #$20		; mode 'A!'
	lda.w #lo16(RLRGBNormalAnim-RLRGBAnims)	; Start with Normal RGB Animation
	sta.w RLRGBAnim0
	sta.w RLRGBAnim
	stz.w RLRGBCount	; ReCycle Anim Immediately!
	stz.w RLRGBPickCount	; No PickUps Yet
	stz.w RLRGBHitCount	; No Hits Yet
	stz.w RLRGBLock	; UnLock RGB Palettes
	lda.w #-1	; No RGB Table to Xfer Yet
	sta.w RLRGBPtr
	sta.l RLRGB	; No PaletteAnim Request
	rts


;
;	* * * * * * *       INITIALIZE VIEW       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitView:
	sep #$20		; mode 'a!'
	lda.b #$80	; Disable Display
	sta.w INIDISP_S
	stz.w HDMAEN_S
	rep #$20		; mode 'A!'
	lda.w #(4<<8)+0	; View being DISPLAYED/BUILT
	sta.w View
	if useHIGHDETAIL != 0
	lda.w #1	; LOW Detail
	sta.l DetailLevel
	lda.w #(RLViewPixX/2)	; Maximum View X
	sta.l RLViewPixX2
	endif
	rts


;
;	* * * * * * *       INITIALIZE REALITY_ENGINE DMA       * * * * * * *
;
;	Channel#0	XRAM 70	-> VRAM		(Draw)
;	Channel#1	XRAM 70	-> VRAM		(Draw)
;	Channel#2	XRAM 70	-> VRAM		(Draw)
;	Channel#3	XRAM 70	-> VRAM		(Draw)
;	Channel#4	XRAM 70	-> WRAM 7E	(XVars, screen thirds)
;	Channel#5	WRAM 7E	-> CGRAM	(RGB)
;	Channel#6	WRAM 00	-> OAMRAM	(OAM)
;	Channel#7	WRAM 7F	-> VRAM		(OAM/VMaps)
;
;	(this port) The screen thirds go to VRAM from WRAM 7E on channels 0-3
;	and 7; rlirq.asm _RIBDrawXFer sets their banks back afterwards.
;
	; dbr ?
	; dpr 0
_RLInitDMA:
	sep #$10		; mode 'x!'
	ldx.b #%00000001	; A->B, Abs., Auto Inc,2-Add-WriteLH
	stx.w DMA0INC
	stx.w DMA1INC
	stx.w DMA2INC
	stx.w DMA3INC
	stx.w DMA7INC
	ldx.b #lo16(VMDATAL)	; B Address
	stx.w DMA0DEST
	stx.w DMA1DEST
	stx.w DMA2DEST
	stx.w DMA3DEST
	stx.w DMA7DEST
	ldx.b #$7F	; A Bank
	stx.w DMA7A1B
	ldx.b #0	; WM Bank
	stx.w WMADDB
	rep #$20		; mode 'A!'
	stz.w DMA0NUML	; PreClear SIZE HighByte
	stz.w DMA1NUML
	stz.w DMA2NUML
	stz.w DMA3NUML
	stz.w DMA4NUML
	stz.w DMA5NUML
	stz.w DMA6NUML
	stz.w DMA7NUML
	jml.l __RLReInitDMA	; Initialize Remaining Channels


	%section(ENGINE_RAMCODE)
;
;	* * * * * * *       RE-INITIALIZE REALITY_ENGINE DMA       * * * * * * *
;
;	Called after a WEAPON MCHR STACK GDMA
;
	; mode 'x'
__RLReInitDMA:
	jsr.w _RLReInitDMA
	rtl
_RLReInitDMA:
	ldx.b #$70	; A Bank
	stx.w DMA0A1B
	stx.w DMA1A1B
	stx.w DMA2A1B
	stx.w DMA3A1B
	stx.w DMA4A1B
	ldx.b #$7E
	stx.w DMA5A1B
	ldx.b #$00
	stx.w DMA6A1B
;
	ldx.b #%00000000	; A->B, Abs., Auto Inc,1-Add-Write1x
	stx.w DMA4INC
	ldx.b #%00000010	; A->B, Abs., Auto Inc,1-Add-Write2x
	stx.w DMA5INC
	stx.w DMA6INC
;
	ldx.b #lo16(WMDATA)	; B Address
	stx.w DMA4DEST
	ldx.b #lo16(CGDATA)
	stx.w DMA5DEST
	ldx.b #lo16(OAMDATA)
	stx.w DMA6DEST
	rts


	%section(ENGINE)
;
;	* * * * * * *       FINAL DECOMPRESSION/TRANSFERS       * * * * * * *
;
;	Final DeComp/Transfers overtop of DeComp Buffer
;
	; dbr ?
	; dpr 0
_RLFinalDeComp:
	sep #$20
	rep #$10		; mode 'aX!'
	ldx.w #lo16(_RLFinalDeCompXFer)	; Transfer Final DataBlocks
	lda.b #bank(_RLFinalDeCompXFer)
	jml.l XFer
;
;	* * * * * * *       FINAL DECOMP TRANSFER LIST       * * * * * * *
;
_RLFinalDeCompXFer:
	dw xftRAM	; Transfer FACESDEF
	dd RLStatFacesDef
	dd RLStatFacesDefRAM
	dw 0,0,0
;
	dw xftRAM	; Transfer KEYSDEF
	dd RLStatKeysDef
	dd RLStatKeysDefRAM
	dw 0,0,0
;
	dw xftRAM	; Transfer STATARMSDEF
	dd RLStatArmsDef
	dd RLStatArmsDefRAM
	dw 0,0,0
;
	dw xftRAM+xftRAW	; Transfer SlopeYInvTable to RAM
	dd SlopeYInvTable
	dd _RLSlopeYInvTable
	dw (RLViewPixY*2)
	dw 0,0
;
	dw xftRAM+xftRAW	; Transfer RLTextureXLatTable to RAM
	dd RLTextureXLatTable
	dd _RLTextureXLatTable
	dw lo16(RLTextureXLatTableE-RLTextureXLatTable)
	dw 0,0
;
	dw xftEND
