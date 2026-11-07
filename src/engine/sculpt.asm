	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                    SCULPTURED SOFTWARE LOGO MODULE                 *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/xfer.inc"
	incsrc "src/include/music.inc"


	if useSCULPT != 0	; (off in rage.inc: this module is not built)

	%section(SCULPT)

;
;	>>>   ARTWORK   <<<
;

SCULPT_CHRSET:
	incbin "data/RLDATA/COMP/SCULPT.def"

SCULPT_SCREEN:
	incbin "data/RLDATA/COMP/SCULPT.map"

SCULPT_PALSET:
SculptColorPallette:
	incbin "data/RLDATA/COMP/SCULPT.rgb":0..(16*4*2)


;*****************************************************************************
;
; 		These equates adjust the fade in rate, the fade out rate, and
;	the controller interruption keys.  Adjust at will.
;
;*****************************************************************************

	SculptFadeInRate = $0100	; $0100 fades up one increment
						;   each VBlank

	SculptFadeOutRate = $0100	; $0100 fades down one increment
						;   each VBlank


	SculptDelayToStart = 30	; Pause 1/2 sec. before animation

	SculptDelayAtEnd = 120	; Pause 2 sec. after animation


	SculptController1 = %1011000010000000	; Buttons (B, Select, Start, A) that
						; would interrupt the demo; unused:
	SculptController2 = %1011000010000000	; .InterruptDemo is disabled, the
						; demo always runs to the end

;*****************************************************************************
;
; 		Just a precautionary setup.
;
;*****************************************************************************


	; dpr 0
	; dbr 0
	; mode 'AX'


;*****************************************************************************
;
;  	External ram locations
;
;*****************************************************************************

;**** VRam

	SculptLogoCharAddr = $3000	; BG1 character address

	SculptLogoMapAddr = $5800	; BG1 map address
	SculptLightMapAddr = $5C00	; BG2 map address
	SculptLightCharAddr = $6000	; BG2 character address
	SculptClearLeft = $7000	;
	SculptClearCenter = $7200	; These equates MUST remain
	SculptClearRight = $7400	; at contiguous addresses.
	SculptWindowXfer = $7600	;

;** CgRam

	SculptPallette = $0

;*****************************************************************************
;
;  	Zero Page Variables (The zero page is allocated from the stack)
;	(NOTE: only [SculptRead] is accessed through .DP; the other accesses
;	are absolute/long, i.e. $00:0000-$0055)
;
;*****************************************************************************

	SculptPacked = 1
	SculptCount = 4
	SculptTemp = 6
	SculptSourceY = 8
	SculptSourceX = 10
	SculptColumn = 12
	SculptCurrentColumn = 14
	SculptCurrentRow = 16
	SculptAndMask = 18
	SculptOrMask = 20
	SculptBits = 22
	SculptPoints = 26
	SculptPointCount = 46
	SculptDeltaY = 48
	SculptDeltaX = 50
	SculptAddStep = 52
	SculptCompareStep = 54
	SculptStepValue = 56
	SculptByteOffset = 58
	SculptSetA = 60
	SculptSetX = 62
	SculptSetY = 64
	SculptRead = 66
	SculptPackedBits = 69
	SculptPackedLength = 70
	SculptPackedOffset = 72
	SculptRightLeft = 74
	SculptCharIndex = 76
	SculptZpSize = 86

;*****************************************************************************
;
;   	Work ram usage
;
;*****************************************************************************

	SculptCharBuffer = $7E6000

	SculptBitMap1 = $7E6000
	SculptBitMap2 = $7EA800

	SculptLogoMap = $7EE000
	SculptLightMap = $7EE800
	SculptMapBuffer = $7EF000

	SculptWindowEdges = $7EF800
	SculptDmaWindowSpace = $7EFC00


;*****************************************************************************
;
;   	Constants
;
;*****************************************************************************

SculptWindowHDmaTable:
	db 128+112
	dw lo16(SculptDmaWindowSpace)
	db 128+112
	dw lo16(SculptDmaWindowSpace)+448
	db 0

SculptMaskTable:
	dw $8080,$4040,$2020,$1010,$0808,$0404,$0202,$0101

SculptClearValues:
	dw $FEFF,$FF00,$0001


;
;	* * * * * * *       SCULPTURED LIGHT DEMO       * * * * * * *
;
	; dbr ?
	; dpr 0
SculpturedLightDemo:
	rep #$30		; mode 'AX!'
	if useSOUND != 0
	lda.w #logo1_eff_MODULE	; Load SoundEffect Module
	jsl.l _LoadModule
	endif
;
	pea.w 0
	plb
	phb
	pld
	ldx.w #lo16(SCULPT_CHRSET)	; Unpack the character set and the map
	ldy.w #lo16(SculptCharBuffer)
	lda.w #((SculptCharBuffer>>8)&$FF00)|bank(SCULPT_CHRSET)
	jsl.l DeCompress

	ldx.w #lo16(SCULPT_SCREEN)
	ldy.w #lo16(SculptMapBuffer)
	lda.w #((SculptMapBuffer>>8)&$FF00)|bank(SCULPT_CHRSET)
	jsl.l DeCompress
;
	tsc	; Create a ZP on the stack (86 bytes)
	sec
	sbc.w #SculptZpSize
	tcs
	pha	; And point to it
	pld
	pea.w 0	; Initial data bank = $00
	plb
	plb
	sei	; No IRQs allowed

;
; Reset the PPU and CPU registers
;

	sep #$20		; mode 'a!'
	stz.w HDMAEN	; Shut off all HDMA
	lda.b #1
	sta.w NMITIMEN	; Disable all interrupts (auto joypad read only)
	phd
	pea.w $2100	; Point direct page to PPU
	pld
	; dpr $2100
	sta.b BGMODE-$2100	; Set display mode 1
	lda.b #$80
	sta.b INIDISP-$2100	; Force blanking for setup
	stz.b MOSAIC-$2100
	ldx.w #SculptLightMapAddr|(SculptLogoMapAddr>>8)
	stx.b BG1SC-$2100	; Set up map addresses
	lda.b #(SculptLightCharAddr|(SculptLogoCharAddr>>4))>>8
	sta.b BG12NBA-$2100	; Set up character base addresses
	lda.b #-1
	stz.b BG1HOFS-$2100	; Reset offsets
	stz.b BG1HOFS-$2100
	sta.b BG1VOFS-$2100
	stz.b BG1VOFS-$2100
	stz.b BG2HOFS-$2100
	stz.b BG2HOFS-$2100
	sta.b BG2VOFS-$2100
	stz.b BG2VOFS-$2100
	lda.b #$80
	sta.b VMAINC-$2100	; Standard inc sequence
	lda.b #$F0
	sta.b W12SEL-$2100
	stz.b WOBJSEL-$2100
	ldy.w #$0004	; Set up window enables and logic
	sty.b WBGLOG-$2100
	ldx.w #$0201
	stx.b TM-$2100	; Set up TM and TS
	dex
	stx.b TMW-$2100	; Set up TMW and TSW
	ldx.w #$2102
	stx.b CGSWSEL-$2100	; Enable BG addition
	ldx.w #$00E0
	stx.b COLDATA-$2100	; Fixed colour black, SETINI = 0
	pld
	; dpr $0000

	pea.w $007E	; Data bank to $7e0000
	plb
	; dbr $7e

;
; Create a map for BG2 which has a repeating light pattern.  The pattern is
;  created from a small block located in the lower left of the unpacked 
;  map data.
;

	rep #$20		; mode 'A!'
	lda.w #10
	sta.l SculptCount
	ldx.w #0
.BuildMapLoop:
	ldy.w #-2
.BuildMapRow1:	; Repeat it vertically
	iny
	iny
	lda.w SculptMapBuffer+(64*25),y
	sta.l SculptLightMap,x
	lda.w SculptMapBuffer+(64*26),y
	sta.l SculptLightMap+64,x
	lda.w SculptMapBuffer+(64*27),y
	sta.l SculptLightMap+128,x
	inx
	inx
	cpy.w #30
	bcc .BuildMapRow1
.BuildMapRow2:	; Flip it horizontally
	lda.w SculptMapBuffer+(64*25),y
	eor.w #$4000
	sta.l SculptLightMap,x
	lda.w SculptMapBuffer+(64*26),y
	eor.w #$4000
	sta.l SculptLightMap+64,x
	lda.w SculptMapBuffer+(64*27),y
	eor.w #$4000
	sta.l SculptLightMap+128,x
	inx
	inx
	dey
	dey
	bpl .BuildMapRow2
	txa
	adc.w #128-1
	tax
	dec.w SculptCount
	bne .BuildMapLoop

;
; Create a map for BG1 which will simply be an incrementing series for
;   the first 18 lines (except the first 10 characters).  The rest point
;   to character 0.  This will facilitate bit mapping.
;

	ldx.w #$7FE
.SculptMapLoop:
	txa
	lsr a
	cpx.w #20
	bcc .ClearSculptMap
	cpx.w #1152
	bcc .SetSculptMap
.ClearSculptMap:
	lda.w #0
.SetSculptMap:
	sta.l SculptLogoMap,x	; Store character name
	dex
	dex
	bpl .SculptMapLoop

;
; Set up DMA registers for the duration of this program
;

	plb	; Data bank back to $000000
	; dbr $0
	sep #$20		; mode 'a!'
	phd
	pea.w $4300	; Point direct page to DMA
	pld
	; dpr $4300
	lda.b #1
	sta.b DMA0INC-$4300
	sta.b DMA1INC-$4300	; Used for sending to VRam
	lda.b #$81
	sta.b DMA5INC-$4300	; Used for reading from VRam
	stz.b DMA6INC-$4300	; Used for sending to CgRam
	lda.b #$44
	sta.b DMA7INC-$4300	; Used for HDMA
	lda.b #lo16(VMDATAL)
	sta.b DMA0DEST-$4300
	sta.b DMA1DEST-$4300
	lda.b #lo16(_VMDATAL)
	sta.b DMA5DEST-$4300
	lda.b #lo16(CGDATA)
	sta.b DMA6DEST-$4300
	lda.b #lo16(WH0)
	sta.b DMA7DEST-$4300	; HDMA changes the window edges

;
; Send the maps for BG1 and BG2 and the unpacked character set to VRam
;

	lda.b #bank(SculptLogoMap)
	ldx.w #lo16(SculptLogoMap)
	sta.b DMA0A1B-$4300
	stx.b DMA0A1L-$4300
	lda.b #bank(SculptCharBuffer)
	ldx.w #lo16(SculptCharBuffer)
	sta.b DMA1A1B-$4300
	stx.b DMA1A1L-$4300
	ldx.w #$1000
	stx.b DMA0NUML-$4300
	ldx.w #$2000
	stx.b DMA1NUML-$4300
	ldx.w #SculptLogoMapAddr
	stx.w VMADDL
	lda.b #$3
	sta.w MDMAEN
	pld	; Restore direct page
	; dpr $0000

;
; Send default window edge values to VRam so that when the edge table needs
;   to be reset, it can quickly be reset by DMAing the defaults from VRam.
;

	rep #$20		; mode 'A!'
	ldx.w #4
.SetClearVram:
	lda.l SculptClearValues,x	; Get a default value
	ldy.w #$200
.SetClearLoop:
	sta.w VMDATAL	; Store directly to VRam
	dey
	bne .SetClearLoop
	dex
	dex
	bpl .SetClearVram

;
; Change the map buffer values from character names to Vram character
;   addresses.  This will facilitate the construction of a bit map for
;   BG1.
;

	ldx.w #$6FE
.CalcVramAddrs:
	lda.l SculptMapBuffer,x
	and.w #$3FF
	asl a
	asl a
	asl a
	asl a
	adc.w #SculptLightCharAddr
	sta.l SculptMapBuffer,x	; Store vram address
	dex
	dex
	bpl .CalcVramAddrs

;
; Read back from VRam the characters which form BG1.  Read them back in the
;   order in which they occur on the screen.  This will create a bit map for
;   the top	18 lines of BG1 ($4800 long).
;

	sep #$10		; mode 'x!'
	lda.w #lo16(SculptMapBuffer)
	ldx.b #bank(SculptMapBuffer)
	sta.l SculptRead	; Set up indirection
	stx.w SculptRead+2
	lda.w #lo16(SculptBitMap1)
	ldx.b #bank(SculptBitMap1)
	sta.w DMA5A1L
	stx.w DMA5A1B	; Set up DMA destination
	rep #$10		; mode 'X!'
	ldx.w #$0020
	jsr.w .ReadBackChars	; Reads back 576 characters

;
; Read back another bit map of the top 18 lines.  Some information stays set
;   up from above.  Before reading back, clear a few spots on the screen.
;   These characters are read back to SculptBitMap2 ($4800 long).
;

	lda.l SculptMapBuffer
	sta.l SculptMapBuffer+(13*64)+2	; Clear these characters
	sta.l SculptMapBuffer+(14*64)+2
	sta.l SculptMapBuffer+(13*64)+60
	sta.l SculptMapBuffer+(14*64)+60
	jsr.w .ReadBackChars	; Reads back 576 characters

;
; On the second bit map (SculptBitMap2), wipe all text from the box in the
;   center.  (Convert it all to one color of blue.)
;

	ldx.w #32*((10*32)+2)	; Point to row of chars to clear
	stz.w SculptTemp	; Top row flag
.ClearSculptLoop:
	lda.w #28
	sta.l SculptCount	; Number of chars per row
.ClearRowLoop:
	ldy.w #8	; Number of pixel rows per char
	bit.w SculptTemp
	bmi .ClearCharLoop
	dey	; If top row of chars, skip top
	inx	;   pixel row
	inx
.ClearCharLoop:
	lda.w #$FF00	; Set pixel row to blue
	sta.l SculptBitMap2+16,x
	lda.w #$0000
	sta.l SculptBitMap2,x
	inx
	inx
	dey
	bne .ClearCharLoop
	txa	; Advance to next character
	clc
	adc.w #16
	tax
	dec.w SculptCount
	bne .ClearRowLoop
	dec.w SculptTemp
	adc.w #128	; Advance to next row
	tax
	cmp.w #(32*((14*32)+2))+1
	bcc .ClearSculptLoop	; Until 5 rows are done

;
; Dma the characters for BG1 (the second bit map) and the first 32 colors
;   in the pallette to their respective destinations.
;

	sep #$20		; mode 'a!'
	ldx.w #SculptLogoCharAddr
	stx.w VMADDL
	lda.b #bank(SculptBitMap2)
	ldx.w #lo16(SculptBitMap2)
	sta.w DMA0A1B
	stx.w DMA0A1L
	ldx.w #$4800
	stx.w DMA0NUML
	stz.w CGADD
	lda.b #bank(SculptColorPallette)
	ldx.w #lo16(SculptColorPallette)
	sta.w DMA6A1B
	stx.w DMA6A1L
	ldx.w #64
	stx.w DMA6NUML
	lda.b #$41
	sta.w MDMAEN

;
; Reset the window edges, redraw the rightmost edge of the blue box (all
;   drawing occurs in the second bit map), and send the redrawn	data.
;

	rep #$20		; mode 'A!'
	stz.w SculptSourceY
	jsr.w .TransferAndClearWindow	; Clear window edges
	jsr.w .TransferAndClearWindow	;   and move them to HDMA table
	lda.w #239
	sta.l SculptColumn
	jsr.w .TransferRow
	ldx.w #8
	jsr.w .DmaChars

;
; Wait for a VBlank and then enable HDMA of the window edges.  Fade on the
;   screen.  Pause for a short time.
;

	sep #$10		; mode 'x!'
	lda.w #lo16(SculptWindowHDmaTable)
	ldx.b #bank(SculptWindowHDmaTable)
	sta.w DMA7A1L
	stx.w DMA7A1B
	ldx.b #bank(SculptDmaWindowSpace)
	stx.w DMA7BANK
	ldx.b #$80
	stx.w HDMAEN	; Enable HDMA
	lda.w #0
	clc
.FadeUpLoop:
	jsr.w .WaitVBlank
	adc.w #SculptFadeInRate	; Increase intensity
	cmp.w #$0F00
	bcc .SetFadeIn	; Clip intensity
	lda.w #$0F00
.SetFadeIn:
	xba
	tax	; Put high byte of intensity in X
	xba
	stx.w INIDISP	; Store the fade value
	bcc .FadeUpLoop
	rep #$10		; mode 'X!'
	ldx.w #SculptDelayToStart
	jsr.w .WaitX	; Pause x seconds

;
; Make the call to initialize the sound
;
	if useSOUND != 0
	ldy.w #logo1_eff
	lda.w #DCOM_START_EFFECT
	jsl.l __SendDriverCommand
	endif

;
; Starting from the left, draw one column of the logo, calculate the window
;   of light, and update.  Do this all the way across the screen.
;

	lda.w #101
	sta.l SculptSourceY	; Light source at 101 vertically
	lda.w #16
	sta.l SculptColumn	; Start at "row" 16
.CutLoop:
;	jsr .InterruptDemo		; Check for button press
	jsr.w .SetSource
	jsr.w .TransferRow	; Draw one column
	jsr.w .DrawDust	; Calculate windows
	ldx.w #8
	jsr.w .WaitDmaChars	; Send character changes
	jsr.w .TransferAndClearWindow	; Update and reset windows
	inc.w SculptColumn
	lda.l SculptColumn
	cmp.w #239
	bcc .CutLoop

;
; Move some special case characters from the upper left of the first bit map
;   to their final locations.
;

	ldx.w #30
.CopyChangeLoop:
	lda.l SculptBitMap1+32,x
	sta.l SculptBitMap1+(32*((32*13)+14)),x
	lda.l SculptBitMap1+64,x
	sta.l SculptBitMap1+(32*((32*13)+29)),x
	lda.l SculptBitMap1+96,x
	sta.l SculptBitMap1+(32*((32*14)+29)),x
	dex
	dex
	bpl .CopyChangeLoop

;
; At the next VBlank, change the light beam to red by DMAing a red pallette
;   to the appropriate location.
;

	jsr.w .WaitVBlank
	sep #$20		; mode 'a!'
	stz.w HDMAEN
	lda.b #$10
	sta.w CGADD
	asl a
	sta.w DMA6NUML
	asl a
	sta.w MDMAEN
	asl a
	sta.w HDMAEN
;
; Starting from the right, draw one character column of the slash, calculate
;   the window of light, and update.  Do this all the way across the screen.
;


	rep #$20		; mode 'A!'
	lda.w #105
	sta.l SculptSourceY	; Light source at 105 vertically
	lda.w #240
	sta.l SculptColumn	; Start at "row" 240
.CutSlashLoop:
;	jsr .InterruptDemo		; Check for button press
	jsr.w .SetSource
	jsr.w .TransferSlash	; Draw one column of characters
	jsr.w .DrawDust	; Calculate windows
	ldx.w #2
	jsr.w .WaitDmaChars	; Send character changes
	jsr.w .TransferAndClearWindow	; Update and reset windows
	lda.l SculptColumn
	sec
	sbc.w #8
	and.w #$FFF8
	sta.l SculptColumn
	bpl .CutSlashLoop

;
; Now that the demo is complete, pause a short time, fade off, and disable
;   HDMA.  Then restore registers and stack and return to the caller.
;

	ldx.w #SculptDelayAtEnd
	jsr.w .WaitX	; Pause x seconds
.RudeExit:
	sep #$10		; mode 'x!'
	lda.w #$0F00
	sec
.FadeDownLoop:
	jsr.w .WaitVBlank
	sbc.w #SculptFadeOutRate	; Decrease intensity
	bcc .ForceOff
	cmp.w #$100
	bcs .SetFadeOut	; Clip intensity
.ForceOff:
	lda.w #$8000
.SetFadeOut:
	xba
	tax	; Put high byte of intensity in X
	xba
	stx.w INIDISP	; Store the fade value
	bcs .FadeDownLoop
	rep #$10		; mode 'X!'
	stz.w MDMAEN	; Shut off HDMA (NOTE: clears MDMAEN, not HDMAEN)
	tsc
	clc
	adc.w #SculptZpSize	; Restore stack
	tcs
;
	pea.w 0
	plb
	phb
	pld
;
	rtl	; Return to caller

;*****************************************************************************
;
;	Support routines
;
;*****************************************************************************

;
; This routine has two entry points.  WaitX waits X VBLanks.  WaitVBlank
;   keeps control until the next VBlank.
;

.WaitXLoop:
	jsr.w .WaitVBlank
;	ply				; Remove Caller Return Address
;	jsr .InterruptDemo		; Check for button presses
;	phy				; Restore Caller Return Address
.WaitX:
	dex
	bne .WaitXLoop
.WaitVBlank:	; Carry, X and Y preserved
	sep #$20		; mode 'a!'
.WaitOutBlankLoop:	; Wait until we are out of VBlank
	bit.w _HVBJOY
	bmi .WaitOutBlankLoop
.WaitInBlankLoop:	; Wait until we transition back
	bit.w _HVBJOY	;   into VBlank
	bpl .WaitInBlankLoop
	rep #$20		; mode 'A!'
	rts

;
; This routine checks keys on the controllers to see if the user has pressed
;   a valid interruption key.  If so, this routine forces an immediate exit.
;

	if 0 != 0
.InterruptDemo:
	lda.w _HVBJOY	; Wait for valid data
	lsr a
	bcs .InterruptDemo
	lda.w #SculptController1	; Check for button press
	and.w JOY1L
	bne .GoRudeExit
	lda.w #SculptController2
	and.w JOY2L
	bne .GoRudeExit
	rts
.GoRudeExit:
	pla	; Pop return address
	jmp.w .RudeExit
	endif


;
; This routine is used in the setup area to read back 576 characters from
;   VRam.  It assumes that everything is properly set up for the DMA activity.
;

.ReadBackChars:
	ldy.w #0
.ReadBackLoop:
	lda.b [SculptRead],y
	sta.w VMADDL	; Set source address
	lda.w _VMDATAL	; Take care of false read
	stx.w DMA5NUML
	stx.w MDMAEN	; Read back one character
	iny
	iny
	cpy.w #576*2
	bne .ReadBackLoop
	rts

;
; This routine waits until the next VBlank and then DMAs the character changes
;   from the second bit map to the appropriate places in VRam.  X is passed
;   to this routine and X indicates how many characters have changed times 2.
; DmaChars is an alternate entry point.
;

.WaitDmaChars:
	jsr.w .WaitVBlank
.DmaChars:
	lda.w #SculptBitMap2>>8	; Set up source bank
	sta.w DMA0A1H
	sep #$20		; mode 'a!'
	stz.w HDMAEN
	rep #$20		; mode 'A!'
	ldy.w #$8001
.DrawCharsLoop:
	lda.l SculptCharIndex,x	; Get index into bit map
	lsr a
	adc.w #SculptLogoCharAddr
	sta.w VMADDL	; Set source
	lda.l SculptCharIndex,x
	adc.w #lo16(SculptBitMap2)
	sta.w DMA0A1L	; Set destination
	lda.w #$20
	sta.w DMA0NUML
	sty.w MDMAEN	; Send changed character
	dex
	dex
	bpl .DrawCharsLoop
	sep #$20		; mode 'a!'
	lda.b #$80
	sta.w HDMAEN
	rep #$20		; mode 'A!'
	rts

;
; This routine moves the calculated window parameters to the HDMA space
;   via a DMA to and then from VRam (for speed).  It then, based on current
;   conditions, resets the window edge calculation space.
;

.TransferAndClearWindow:
	sep #$10		; mode 'x!'
	ldx.b #bank(SculptWindowEdges)
	stx.w DMA0A1B	; Set up all DMA stuff in advance
	stx.w DMA5A1B
	lda.w #lo16(SculptWindowEdges)
	sta.w DMA0A1L
	lda.w #lo16(SculptDmaWindowSpace)
	sta.w DMA5A1L
	lda.w #896
	sta.w DMA0NUML
	sta.w DMA5NUML
	ldx.b #1
	ldy.b #$20
	lda.w #SculptWindowXfer
	sta.w VMADDL
	stx.w MDMAEN	; Transfer window edges to VRam
	sta.w VMADDL
	sty.w MDMAEN	; Transfer window edges from VRam
	lda.w #lo16(SculptWindowEdges)
	sta.w DMA5A1L
	lda.w #896
	sta.w DMA5NUML
	ldx.w SculptSourceY	; Identify values to clear to
	beq .BeginningClear
	cpx.b #102
	bcs .SkipForSlash
	lda.w #SculptClearCenter
	ldx.w SculptCompareStep
	cpx.b #-1	; Super bright center
	beq .ClearAddr
.SkipForSlash:
	lda.w #SculptClearLeft	; Windows cut to left
	ldx.w SculptColumn
	cpx.w SculptSourceX
	bcc .ClearAddr
.BeginningClear:
	lda.w #SculptClearRight	; Windows cut to right
.ClearAddr:
	sta.w VMADDL
	sty.w MDMAEN	; Read from VRam, clearing windows
	rep #$10		; mode 'X!'
	rts

;
; This routine sets up the X position of the light source and also sets up
;   related values for the light window calculations.
;

.SetSource:
	stz.w SculptPointCount	; Clear light edge counter
	lda.l SculptColumn
	asl a
	adc.l SculptColumn
	asl a
	adc.l SculptColumn
	adc.w #128
	lsr a
	lsr a
	lsr a
	sta.l SculptSourceX	; Set x position of the light
	ldy.w #1
	lda.l SculptColumn	; Calculate delta x
	sec
	sbc.l SculptSourceX
	bpl .SetDeltaX
	eor.w #$FFFF
	inc a
	ldy.w #-1
.SetDeltaX:
	dec a	; Save delta and step values
	sta.l SculptCompareStep
	sty.w SculptDeltaX
	rts

;
; This routine moves one pixel "row" (column) of data from the source bit
;   map to the second bit map.  It also identifies the transitions from
;   background to letter colors and stores these transition points in a table
;   so that light windows can be calculated.
;

.TransferRow:
	pea.w $007E	; Data bank set to $7e0000
	plb
	; dbr $7e
	lda.l SculptColumn	; Calculate which bit contains
	and.w #$7	;   data
	asl a
	tax
	lda.l SculptMaskTable,x
	sta.l SculptAndMask	; Set up masks to extract this
	eor.w #$FFFF	;   bit
	sta.l SculptOrMask
	lda.l SculptColumn	; Identify index of first
	and.w #$FFF8	;   character to draw from/to
	asl a
	asl a
	clc
	adc.w #(32*32)*10
	tay
	lda.w #80	; Keep track of vertical pixel row
	sta.l SculptCount
.TransferCharLoop:
	lsr a
	lsr a
	sbc.w #20-1
	tax
	tya	; Save index of changed character
	sta.l SculptCharIndex,x	;   so that it may be DMAed.
.TransferBitLoop:
	ldx.w SculptAndMask
	txa	; Extract one pixel from source
	and.w SculptBitMap1,y
	sta.l SculptBits
	txa
	and.w SculptBitMap1+16,y
	sta.l SculptBits+2
	txa	; Determine its color value
	and.w #$FF00
	dec a
	tax
	cpx.w SculptBits+2
	rol a
	cpx.w SculptBits+1
	rol a
	cpx.w SculptBits
	rol a
	cpx.w SculptBits-1
	rol a
	and.w #$000F	; Got (15 - color) value
	tax
	cpx.w #5	; Detect color transitions and
	lda.l SculptPointCount	;  color types
	bit.w #2
	bne .CheckEndPoint
	bcc .SetPoint
	cpx.w #7
	bcc .DrawOnly
	bra .NextPixel
.CheckEndPoint:
	bcc .DrawOnly
	cpx.w #7
.SetPoint:
	tax
	lda.l SculptCount	; If transition was detected,
	sta.l SculptPoints,x	;   store current vertical pos.
	inx
	inx
	stx.w SculptPointCount
	bcs .NextPixel
.DrawOnly:
	lda.l SculptOrMask	; If color was a text color,
	and.w SculptBitMap2,y	;   then store it to the second
	ora.l SculptBits	;   bit map
	sta.w SculptBitMap2,y
	lda.l SculptOrMask
	and.w SculptBitMap2+16,y
	ora.l SculptBits+2
	sta.w SculptBitMap2+16,y
.NextPixel:
	iny	; Advance to next vertical pixel
	iny
	inc.w SculptCount
	tya
	bit.w #$000E
	bne .TransferBitLoop
	clc	; Advance to next character
	adc.w #(32*32)-16
	tay
	lda.l SculptCount
	cmp.w #120	; Do 5 characters (40 pixels)
	bcc .TransferCharLoop
	plb	; Data Bank set to $00000
	; dbr $0
	rts

;
; This routine moves one character column of data from the source bit
;   map to the second bit map.  It also identifies the transitions from
;   background to slash colors and stores these transition points in a table
;   so that light windows can be calculated.
;

.TransferSlash:
	pea.w $007E	; Data bank set to $7e0000
	plb
	; dbr $7e
	lda.l SculptColumn	; Identify index of first
	and.w #$FFF8	;   character to draw to/from
	asl a
	asl a
	adc.w #(32*32)*13
	tay
	sta.l SculptCharIndex	; Save character indexes so that
	adc.w #1024	;   the changed characters may
	sta.l SculptCharIndex+2	;   be DMAed
	lda.w #104
	sta.l SculptCount	; Keep track of vertical row
.TransferBitSlashLoop:
	lda.w SculptBitMap1,y	; Move whole words of the
	sta.w SculptBitMap2,y	;   character
	and.w #$8080
	sta.l SculptBits
	lda.w SculptBitMap1+16,y
	sta.w SculptBitMap2+16,y
	and.w #$8080
	sta.l SculptBits+2	; Keep track of far left color
	ldx.w #$7FFF
	cpx.w SculptBits+2	; Identify far left color number
	rol a
	cpx.w SculptBits+1
	rol a
	cpx.w SculptBits
	rol a
	cpx.w SculptBits-1
	rol a
	and.w #$000F	; Got (15 - color) value
	tax
	lda.l SculptPointCount	; Detect color transitions
	bit.w #2
	bne .CheckEndSlash
	cpx.w #11
	bcs .NextSlash
	cpx.w #8
	bcc .NextSlash
	bcs .SetSlash
.CheckEndSlash:
	cpx.w #8
	bcc .SetSlash
	cpx.w #11
	bcc .NextSlash
.SetSlash:
	tax
	lda.l SculptCount	; If transition detected,
	sta.l SculptPoints,x	;   store current vertical pos.
	inx
	inx
	stx.w SculptPointCount
.NextSlash:
	iny	; Advance to next vertical row
	iny
	inc.w SculptCount
	tya
	bit.w #$000E
	bne .TransferBitSlashLoop
	clc	; Advance to next character
	adc.w #(32*32)-16
	tay
	lda.l SculptCount
	cmp.w #120	; Do 2 characters (16 rows)
	bcc .TransferBitSlashLoop
	plb	; Data bank set to $000000
	; dbr 0
	rts

;
; This routine takes the transition positions determined above and calls
;   a routine to draw light windows.
;

.DrawDust:
	pea.w $007E	; Data bank set to $7e0000
	plb
	; dbr $7e
	lda.l SculptWindowEdges	; If center is bright, quit early
	cmp.w #$FF00
	beq .DoneDrawDust
	ldx.w SculptPointCount	; Terminate the list properly
	stz.w SculptPoints,x
	ldx.w SculptPoints	; If transition pair #1 exists,
	beq .DoneDrawDust
	ldy.w SculptPoints+2	;  draw a window for it
	lda.w #0
	jsr.w .SetWindow
	ldx.w SculptPoints+4	; If transition pair #2 exists,
	beq .DoneDrawDust
	ldy.w SculptPoints+6	;  draw a window for it
	lda.w #2
	jsr.w .SetWindow
	ldx.w SculptPoints+8	; If transition pair #3 exists,
	beq .DoneDrawDust
	ldy.w SculptPoints+10	;  draw a window for it
	lda.w #0
	jsr.w .SetWindow
.DoneDrawDust:
	plb	; Data bank set to $000000
	; dbr $0
	rts

;
; This routine draws a light window.  A is the (display window *2) to modify. 
;   X and Y are the vertical values of each transition location.  Each light
;   window is a trapezoid.  The outside edge is created when the window space
;   is cleared.  The inside edge and the angled lines are created below.
;

	; dbr $7e

.SetWindow:
	sta.l SculptSetA	; Save the input values for later
	sty.w SculptSetY
	stx.w SculptSetX
	txa	; Calculate the position in the
	asl a	;   window edge buffer to draw
	asl a	;   the inside edge to
	adc.l SculptSetA
	tax
	tya
	asl a
	asl a
	adc.l SculptSetA
	sta.l SculptTemp
	ldy.w #0	; Is inside edge to left or right?
	lda.l SculptColumn
	cmp.l SculptSourceX
	xba
	bcc .ColumnLoop
	iny	; Offset accordingly
	xba
	ora.w #$FF00
.ColumnLoop:
	sta.l SculptWindowEdges,x	; Set one portion of inside edge
	inx
	inx
	inx
	inx
	cpx.w SculptTemp	; Loop until inside edge is done
	bcc .ColumnLoop
	beq .ColumnLoop
	sty.w SculptRightLeft	; Inside edge was left or right
.StartLine1:
	ldx.w SculptSetX	; Set up to draw first angled edge
	tya
	cpx.w SculptSourceY
	beq .StartLine2
	bcs .DoLine1	; Set appropriate offsets
	eor.w #1
.DoLine1:
	ora.l SculptSetA
	jsr.w .LineFromX	; Draw angled window edge
.StartLine2:
	ldx.w SculptSetY	; Set up to draw other angled edge
	lda.l SculptRightLeft
	cpx.w SculptSourceY
	beq .DoneLine
	bcc .DoLine2	; Set opposing offsets
	eor.w #1
.DoLine2:
	ora.l SculptSetA
;	jmp .LineFromX  		; Falls through to below (draw it)

;
; This routine uses the source of light coordinates, the current column, the 
;   current row (specified in X), and a byte offset (specified in A) to draw
;   one edge of a light window.  The edge is drawn directly to the window
;   edge buffer.  This routine has similarities to a line drawing routine.
;

.LineFromX:
	sta.l SculptByteOffset	; Save offset to window space
	lda.l SculptColumn
	sta.l SculptCurrentColumn	; Initialize a local counter
	txa
	asl a
	asl a
	adc.l SculptByteOffset	; Calculate index to window space
	sta.l SculptCurrentRow
	ldy.w #4-1
	txa
	sec
	sbc.l SculptSourceY	; Calculate Delta Y and step Y
	bpl .SetDeltaY
	eor.w #$FFFF
	inc a
	ldy.w #-5	; Same as -4-1
.SetDeltaY:
	sta.l SculptAddStep
	lsr a
	tax
	sty.w SculptDeltaY
	ldy.w SculptCurrentRow
	bra .LineEntry	; Jump into edge draw loop
.AdvanceLine:
	txa	; Carry is clear
	adc.l SculptAddStep	; Adjust for a horizontal step
	tax
.OverflowLoop:	; Carry is clear
	sbc.l SculptCompareStep
	bcc .DoneOverflow	; Check for vertical step
	tax
	tya
	adc.l SculptDeltaY	; Take vertical step
	cmp.w #224*4
	bcs .DoneLine	; Clip at top/bottom
	tay
.LineEntry:
	lda.w SculptWindowEdges,y	; Set window edge for this
	and.w #$FF00	;   vertical row
	ora.l SculptCurrentColumn
	sta.w SculptWindowEdges,y
	txa
	bra .OverflowLoop
.DoneOverflow:
	lda.l SculptCurrentColumn	; Take horizontal step
	adc.l SculptDeltaX
	sta.l SculptCurrentColumn
	cmp.w #256	; Clip at Left/Right
	bcc .AdvanceLine
.DoneLine:
	rts

	endif
