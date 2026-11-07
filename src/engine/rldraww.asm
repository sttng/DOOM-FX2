	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       ENGINE WALL DRAW MODULE                      *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLDrawWallsA
	; public _RLDrawWallsB
	; public _RLDrawWallsC
	; public _RLDrawWalls


	%section(ENGINE_GSUCODE)
	arch superfx

;
;	* * * * * * *       REALITY_ENGINE DRAW WALLS       * * * * * * *
;
;	In LOW-Detail mode, each 2-pixels wide are from a single WALL PLOT
;	Strip.
;
;	BAND DRAWING (this port):  The screen is 8 bits per pixel, and the GSU
;	pixel cache holds one row of an 8-pixel block.  Plotting 2-pixel strips
;	column by column flushes partly filled blocks: a read-merge-write of 8
;	bitplanes (80 cycles) per row, a quarter of all GSU time.  So the walls
;	are drawn in bands of 4 strips (8 pixels): the strips' pixels go to a
;	byte buffer (one byte per strip pixel, column by column), then the band
;	is plotted row by row, 8 pixels at a time (plain 8-bitplane writes).
;	Rows no wall touches are skipped; a strip pixel without a wall inside
;	the band's Y range gets an old buffer byte, which the floors/ceilings
;	drawn next cover (the original filled them with the band's first strip).
;

	!rColour = r1	; Colour of the current texel (band buffer byte)
	!rPixelCount = r3	; Pixel SkipCount/RepeatCount (this port; the band
				; buffer column is in DWBandBase)
	!rColourMap = r5	; ColourMap
;
	!rPixScaleF = r6	; SCN->RL Scale Fraction
	!rPixScale = r7	; SCN->RL Scale Integer
;
	!rWallF = r8	; SCN->RL Wall Fraction
	!rWall = r9	; Pointer to WallTextureData
;
	!rPlotDataPtr = r11	; Ptr within Current WallPlotData
				; (r13: the address of the current pixel LOOP)
;
;	wall format 3 (this port, !RLWALLFMT3): blocks of 2x4 texels from a codebook
;	(tools/wallvq.py).
;
	!rCB = r3	; Codebook + 1024 * (stored column AND 1)
	!rIdx = r9	; Indices of the column's block column
	!rRow = r4	; Texel row (from the bottom of the stored texture)

	assert (_RLBandBuffer>>16) == $71, "the band buffer is in bank $71, with the walls' colour maps (RAMB 1)"


	%align_pad(5, 16, (_RLDrawWallsC-_RLDrawWallsLowAlign)&$0F)	; align 16,(_RLDrawWallsC-_RLDrawWallsLowAlign)&$0f

_RLDrawWallsC:
	iwt r2,#lo16(_RLDrawFloorsC)
	bra _RLDrawWalls
	nop
_RLDrawWallsB:
	iwt r2,#lo16(_RLDrawFloorsB)
	bra _RLDrawWalls
	nop
_RLDrawWallsA:
	iwt r2,#lo16(_RLDrawFloorsA)
_RLDrawWalls:
	sms (RLNextCode&$FFFF),r2	; Save address of Next Code Jump
;
;	>>>   THE PLOT DATA MUST END BELOW _RLPlotDataEnd   <<<
;
	iwt r1,#lo16(_RLPlotDataEnd)
	lms r0,(TRWallPlotPtr&$FFFF)
	cmp r1
	bcs _RLDWOverflow	; (never seen: skip the walls of this third)
	nop
	lms r0,(TRFloorPlotPtr&$FFFF)
	cmp r1
	bcs _RLDWOverflow
	nop
	lms r0,(TRObjPlotPtr&$FFFF)
	cmp r1
	bcc _RLDrawWallsLow
	nop
_RLDWOverflow:
	iwt r15,#lo16(_DWL1200)
	nop

;
;	* * * * * * *       DRAW WALLS IN LOW DETAIL       * * * * * * *
;
_RLDrawWallsLow:
	iwt r0,#lo16(_RLWallPlots-2)	; WALL PLOT DATA START
	sms (DWPlotPtr&$FFFF),r0
	ibt r0,#0	; First band at X=0
	sms (DWBandX&$FFFF),r0
;
	%CACHEB(_RLDrawWallsLow)
_RLDrawWallsLowAlign:
;
;	>>>   START NEXT BAND OF 4 PIXELSTRIPS   <<<
;
_DWB1000:
	iwt r0,#$00FF	; MinY = 255
	sms (DWMinY&$FFFF),r0
	ibt r0,#-1	; MaxY = -1 (nothing drawn yet)
	sms (DWMaxY&$FFFF),r0
	iwt r0,#lo16(_RLBandBuffer-RLViewPixY)
	sms (DWBandBase&$FFFF),r0
;
;	>>>   DO NEXT PIXELSTRIP   <<<
;
_DWL1000:
	lms r0,(DWBandBase&$FFFF)	; Next strip's buffer column
	iwt r1,#RLViewPixY
	add r1
	sbk
	iwt r1,#lo16(_RLBandBuffer+(4*RLViewPixY))	; Past the 4th column?
	cmp r1
	beq _DWC000	; Yes: plot the band
	nop
	lms !rPlotDataPtr,(DWPlotPtr&$FFFF)	; Get WallPlotDataPtr
	inc !rPlotDataPtr	; Move to Next WallPlotDataPtr
	inc !rPlotDataPtr
	from !rPlotDataPtr	; Save Updated WallPlotDataPtr
	sbk
	iwt r15,#lo16(_DWL9000)+1
;	to	r0				; Get Next WallPlotPtr
	ldw (!rPlotDataPtr)


;
;	>>>   PLOT THE BAND, ROW BY ROW, 8 PIXELS AT A TIME   <<<
;
_DWC000:
	lms r2,(DWMaxY&$FFFF)	; Anything drawn in this band?
	moves r2,r2
	bmi _DWC800	; No
	nop
	lms r0,(DWMinY&$FFFF)
	from r2	; #Rows = MaxY-MinY+1
	to r12
	sub r0
	inc r12
	move r2,r0	; Y = MinY
	iwt r3,#lo16(_RLBandBuffer+(0*RLViewPixY))
	with r3
	add r0
	iwt r4,#lo16(_RLBandBuffer+(1*RLViewPixY))
	with r4
	add r0
	iwt r5,#lo16(_RLBandBuffer+(2*RLViewPixY))
	with r5
	add r0
	iwt r6,#lo16(_RLBandBuffer+(3*RLViewPixY))
	with r6
	add r0
	lms r7,(DWBandX&$FFFF)
	move r1,r7	; X = Band X
	ibt r9,#1	; (this port) The buffer: GSU RAM $71
	from r9
	ramb
	iwt r13,#lo16(_DWC100)
_DWC100:
	ldb (r3)	; Strip 0
	color
	plot
	plot
	inc r3
	ldb (r4)	; Strip 1
	color
	plot
	plot
	inc r4
	ldb (r5)	; Strip 2
	color
	plot
	plot
	inc r5
	ldb (r6)	; Strip 3
	color
	plot
	plot
	inc r6
	move r1,r7	; Back to the band's X
	loop
	inc r2	; Next row
;
;	>>>   NEXT BAND   <<<
;
_DWC800:
	sub r0	; (this port) The variables: GSU RAM $70
	ramb
	lms r0,(DWBandX&$FFFF)
	%add_i(8)
	sms (DWBandX&$FFFF),r0
	ibt r1,#(RLViewPixX/3)	; Past the last band?
	cmp r1
	bne _DWC900
	nop
	iwt r15,#lo16(_DWL1200)	; Yes, done
	nop
_DWC900:
	iwt r15,#lo16(_DWB1000)
	nop

;	(this port, wall format 3, tools/wallvq.py)
;
;	texel = codebook + 1024 * (column AND 1) + 256 * (row AND 3) + index[row >> 2]
;
;	r4 = row in 8.8 fixed point: the WallPlot's TextureOffset/WallF word as it is,
;	and the bits 8-9 masked are the codebook plane of the row.  A wall plot
;	with at least one texel per screen pixel (PixScale >= 1) takes a new texel
;	every pixel: one loop adding the 8.8 PixScale in r6 (LOOP, r13 = _DWVM+1,
;	r7 = $0300); a magnified one keeps the colour while the fraction (r8) does
;	not carry (LOOP to _DWV600+1; r4 = the integer texel row, r7 = 3).
;
	if !RLWALLFMT3
;
;	>>>   MINIFIED: A NEW TEXEL EVERY PIXEL   <<<
;
_DWVM:
	from !rRow	; Index of the block
	hib
	lsr
	lsr
	to r14
	add !rIdx
	from !rRow	; R1 = Codebook plane of the column and row
	to r1
	and r7
	with r1
	add !rCB
	getb	; Index
	to r14	; Texel
	add r1
	with !rRow	; Move to next Pixel (while the texel is read)
	add r6
	getb	; Texel
	add !rColourMap	; Colour (the RAM copy of the colour maps)
	ldb (r0)
;	from	r0				; Store the strip pixel in the band buffer
	stb (r2)
	dec r2	; Move to next Y Coordinate
	loop	; One less ScreenPixel to Draw
	from !rRow	; (the first instruction of the loop)
	bra _DWL8990
	nop
;
;	>>>   MAGNIFIED: NEW TEXEL   <<<
;
_DWV300:
	from !rRow	; Index of the block (r4 = texel row here, integer)
	lsr
	lsr
	to r14
	add !rIdx
	from !rRow	; R1 = Codebook plane of the column and row
	to r1
	and r7	; (r7 = 3)
	with r1
	swap
	with r1
	add !rCB
	getb	; Index
	to r14	; Texel
	add r1
	getb	; Texel
	add !rColourMap	; Colour (the RAM copy of the colour maps)
	to !rColour
	ldb (r0)
_DWV600:
	from !rColour	; Store the strip pixel in the band buffer
	stb (r2)
	with !rWallF	; Move to next Pixel
	add r6
	bcs _DWV700	; Next texel
	dec r2	; Move to next Y Coordinate
	loop	; Same texel: one less ScreenPixel to Draw (r13 = _DWV600+1)
	from !rColour
	bra _DWL8990
	nop
_DWV700:
	dec r12	; One less ScreenPixel to Draw
	beq _DWL8990
	nop
	bra _DWV300
	inc !rRow	; Next texel row
	else
;
;	>>>   ADJUST FOR IMAGE OFFSET   <<<
;
_DWL3200:
	getb	; <REPEAT>/<UNIQUE>?
_DWL3220:
;	with	r0
	sex
	bmi _DWL3600	; <REPEAT>
	inc r14
;
;	>>>   UNIQUE   <<<
;
	with r14
	add r0
	with !rPixelCount
	sub r0
	dec !rPixelCount
	bpl _DWL3200
	inc !rPixelCount
	beq _DWL4100
	with !rPixelCount
	not
	inc !rPixelCount
	with r14
	bra _DWL4400
	sub !rPixelCount
;
;	>>>   REPEAT   <<<
;
_DWL3600:
	inc r14
	with !rPixelCount	; PixelCount += -RepeatCount
	add r0
	dec !rPixelCount
	bpl _DWL3200
	inc !rPixelCount
	bne _DWL5200	; <REPEAT> RUNNING
;
;	>>>   STRIP PIXEL   <<<
;
;	(this port) PixScale >= 1 here (the magnified wall plots are below):
;	a new texel every pixel.  The pixels of a run are a LOOP (r13 = its
;	address + 1): store, step, the run's count; the run's end leaves the
;	loop (and counts that pixel).  25 cycles a unique pixel instead of 36.
;
_DWL4100:
	nop	; @FLUSH WITH IN PIPELINE@
_DWL4200:
	getb	; <REPEAT>/<UNIQUE>?
	inc r14
;	from	r0				; UniqueCount/RepeatCount
	to !rPixelCount
	sex
	bmi _DWL5400	; <REPEAT>
	nop
;
;	>>>   UNIQUE   <<<
;
_DWL4400:
	dec !rPixelCount	; (the loop tests PixelCount-1)
	iwt r13,#lo16(_DWU)+1
_DWU:
	getb	; Texel
	add !rColourMap	; Colour (the RAM copy of the colour maps)
	to !rColour
	ldb (r0)
	from !rColour	; Store the strip pixel in the band buffer
	stb (r2)
	with !rWallF	; Move to next Pixel
	add !rPixScaleF
	from !rPixScale	; R0 = texels to step (>= 1)
;	to	r0
	adc #0
	with r14	; The next texel
	add r0
	with !rPixelCount
	sub r0
	bmi _DWU800	; Unique run done
	dec r2	; Move to next Y Coordinate
	loop	; One less ScreenPixel to Draw
	getb	; (the loop's first byte)
_DWU900:
	iwt r15,#lo16(_DWL8990)
	nop
_DWU800:
	dec r12	; One less ScreenPixel to Draw
	beq _DWU900
	inc !rPixelCount	; PixelCount -= Texels
;
;	>>>   UNIQUE DONE   <<<
;
	beq _DWL4100
	with !rPixelCount
	not
	inc !rPixelCount
	with r14
	bra _DWL3200
	sub !rPixelCount

;
;	>>>   REPEAT   <<<
;
_DWL5200:
	dec r14
_DWL5400:
	iwt r13,#lo16(_DWR)+1
	getb	; Texel
	add !rColourMap	; Colour (the RAM copy of the colour maps)
	to !rColour
	ldb (r0)
	inc r14	; The next control byte
_DWR:
	from !rColour	; Store the strip pixel in the band buffer
	stb (r2)
	with !rWallF	; Move to next Pixel
	add !rPixScaleF
	from !rPixScale	; R0 = texels to step (>= 1)
;	to	r0
	adc #0
	with !rPixelCount
	add r0
	bpl _DWR800	; Repeat run done
	dec r2	; Move to next Y Coordinate
	loop	; One less ScreenPixel to Draw
	from !rColour
	bra _DWU900
	nop
_DWR800:
	dec r12	; One less ScreenPixel to Draw
	beq _DWU900
	nop
;
;	>>>   REPEAT DONE   <<<
;
	moves !rPixelCount,!rPixelCount
	beq _DWL4200
	getb	; <REPEAT>/<UNIQUE>?
	iwt r15,#lo16(_DWL3220)+1
;	with	r0
	sex
	endif


;
;	* * * * * * *       NEXT STRIP       * * * * * * *
;
_DWL9090:
	iwt r15,#lo16(_DWL1000)	; Next PixelStrip!
	nop
;
;	* * * * * * *       NEXT WALLPLOT OF THIS STRIP       * * * * * * *
;
_DWL8990:
	sub r0	; (this port, after the pixels) The plot data: GSU RAM $70
	ramb
_DWL9000:
;	to	r0				; Get Next WallPlotPtr
	ldw (!rPlotDataPtr)
	moves !rPlotDataPtr,r0	; Any Next?
	beq _DWL9090	; No!
;	to	r0				; Get #Pixels To Draw / ColourMap
	ldw (!rPlotDataPtr)
	inc !rPlotDataPtr
	inc !rPlotDataPtr
;
;	from	r0				; #Pixels To Draw
	to r12
	lob
;	with	r0				; Get HighByte of ColourMap
	hib
;	from	r0
	to !rColourMap
	swap
;
;	to	r0				; Get Scaling Value
	if !RLWALLFMT3
	to r6	; (8.8)
	ldw (!rPlotDataPtr)
	else
	ldw (!rPlotDataPtr)
;	from	r0
	to !rPixScale
	hib
;	with	r0
	lob
;	from	r0
	to !rPixScaleF
	swap
	endif
;
	inc !rPlotDataPtr
	inc !rPlotDataPtr
;
;	to	r0				; Starting Y Coordinate / Bank of PixelData
	ldw (!rPlotDataPtr)
	inc !rPlotDataPtr
	inc !rPlotDataPtr
;
;	from	r0				; Get Starting Y Coordinate
	to r2
	lob
;	with	r0				; Get Bank of PixelData
	hib
	romb
;
;	>>>   BAND Y RANGE: rows StartY-#Pixels+1 .. StartY   <<<
;
	lms r1,(DWMaxY&$FFFF)
	from r2
	cmp r1
	blt _DWL9100
	nop
	sms (DWMaxY&$FFFF),r2
_DWL9100:
	from r2
	sub r12
	inc r0
	lms r1,(DWMinY&$FFFF)
	cmp r1
	bge _DWL9150
	nop
	sms (DWMinY&$FFFF),r0
_DWL9150:
	if !RLWALLFMT3
	lms r0,(DWBandBase&$FFFF)	; Y -> band buffer address
	with r2
	add r0
;
	to !rIdx	; Indices of the block column
	ldw (!rPlotDataPtr)
	inc !rPlotDataPtr
	inc !rPlotDataPtr
	to !rRow	; Row: TextureOffset.WallF
	ldw (!rPlotDataPtr)
	inc !rPlotDataPtr
	inc !rPlotDataPtr
	to !rCB	; Codebook + 1024 * (column AND 1)
	ldw (!rPlotDataPtr)
	with !rPlotDataPtr	; Move to next WallPlot
	%add_i((plwNext-plwVSegTextureH))
	ibt r1,#1	; (this port) The band buffer and colour maps: GSU RAM $71
	from r1
	ramb
	from r6	; At least one texel per pixel?
	hib
	bne _DWL9160
	nop
	with r6	; No, magnified: PixScale fraction << 8
	swap
	from !rRow	; WallF << 8
	to !rWallF
	lob
	with !rWallF
	swap
	with !rRow	; The texel row (integer)
	hib
	ibt r7,#3
	iwt r13,#lo16(_DWV600)+1
	iwt r15,#lo16(_DWV300)
	nop
_DWL9160:
	iwt r7,#$0300	; Yes: a new texel every pixel
	iwt r13,#lo16(_DWVM)+1
	iwt r15,#lo16(_DWVM)
	nop
	else
	lms r0,(DWBandBase&$FFFF)	; Y -> band buffer address
	with r2
	add r0
;
	to r14	; Get Address of PixelData
	ldw (!rPlotDataPtr)
	inc !rPlotDataPtr
	inc !rPlotDataPtr
;
;	to	r0				; Get WallFraction
	ldw (!rPlotDataPtr)
;	from	r0
	to !rWallF
	lob
	with !rWallF
	swap
;
	with !rPlotDataPtr	; Move to next WallPlot
	%add_i((plwNext-plwWallF))
	ibt r1,#1	; (this port) The band buffer and colour maps: GSU RAM $71
	from r1
	ramb
;
	moves !rPixScale,!rPixScale	; (this port) Magnified (less than a texel per pixel)?
	beq _DWM000	; Yes
	nop
;
;	>>>   STRIP PIXEL   <<<
;
;	from	r0				; Any ImageOffset?
	to !rPixelCount
	hib
	bne _DWL9200+1	; Yes!
	iwt r15,#lo16(_DWL4200)+1
	getb	; <REPEAT>/<UNIQUE>?
_DWL9200:
	iwt r15,#lo16(_DWL3200)+1
	getb	; <REPEAT>/<UNIQUE>?

;
;	* * * * * * *       MAGNIFIED WALLPLOT (this port)       * * * * * * *
;
;	PixScale = 0: a texel covers one or more pixels.  The same decoding as
;	above, with the pixels of one texel in a LOOP (r13 = _DWMI+1): store,
;	add the fraction, next pixel; 9 cycles a pixel instead of 15.  A carry
;	(a new texel) goes to the unique or repeat code (in r10).  Here r7 is the
;	PixelCount.
;
_DWM000:
	iwt r13,#lo16(_DWMI)+1	; The pixel loop
;	from	r0				; Any ImageOffset?
	to r7
	hib
	beq _DWM4200+1	; No
	getb	; <REPEAT>/<UNIQUE>?
;	(yes: fall into _DWM3200, which reads the same byte again)
;
;	>>>   ADJUST FOR IMAGE OFFSET   <<<
;
_DWM3200:
	getb	; <REPEAT>/<UNIQUE>?
_DWM3220:
;	with	r0
	sex
	bmi _DWM3600	; <REPEAT>
	inc r14
	with r14	; UNIQUE
	add r0
	with r7
	sub r0
	dec r7
	bpl _DWM3200
	inc r7
	beq _DWM4100
	with r7
	not
	inc r7
	with r14
	bra _DWM4400
	sub r7
_DWM3600:
	inc r14	; REPEAT
	with r7	; PixelCount += -RepeatCount
	add r0
	dec r7
	bpl _DWM3200
	inc r7
	bne _DWM5200	; <REPEAT> RUNNING
;
;	>>>   STRIP PIXEL   <<<
;
_DWM4100:
	nop	; @FLUSH WITH IN PIPELINE@
_DWM4200:
	getb	; <REPEAT>/<UNIQUE>?
	inc r14
;	from	r0				; UniqueCount/RepeatCount
	to r7
	sex
	bmi _DWM5400+1	; <REPEAT>
;
;	>>>   UNIQUE   <<<
;
_DWM4400:
	move !rWall,r14
	iwt r10,#lo16(_DWMU)	; New texels: unique
	getb	; Texel
	add !rColourMap	; Colour (the RAM copy of the colour maps)
	to !rColour
	ldb (r0)
	bra _DWMI+1
	from !rColour
;
;	>>>   REPEAT   <<<
;
_DWM5200:
	dec r14
_DWM5400:
	move !rWall,r14
	iwt r10,#lo16(_DWMR)	; New texels: repeat
	getb	; Texel
	add !rColourMap	; Colour (the RAM copy of the colour maps)
	to !rColour
	ldb (r0)
	inc r14	; The next control byte
;
;	>>>   THE PIXELS OF ONE TEXEL   <<<
;
_DWMI:
	from !rColour	; Store the strip pixel in the band buffer
	stb (r2)
	with !rWallF	; Move to next Pixel
	add !rPixScaleF
	bcs _DWMN	; Next texel
	dec r2	; Move to next Y Coordinate
	loop	; Same texel: one less ScreenPixel to Draw
	from !rColour
_DWMX:
	iwt r15,#lo16(_DWL8990)
	nop
_DWMN:
	dec r12	; One less ScreenPixel to Draw
	beq _DWMX
	sub r0
	jmp r10	; Unique or repeat, with r0 = 1 texel
	inc r0
;
_DWMU:
;	from	r0				; UNIQUE: next texel
	to r14
	add !rWall
	with r7
	sub r0
	dec r7
	bpl _DWM4400
	inc r7
	beq _DWM4100
	with r7
	not
	inc r7
	with r14
	bra _DWM3200
	sub r7
;
_DWMR:
	with r7	; REPEAT: one texel less
	add r0
	bmi _DWMI+1
	from !rColour
	beq _DWM4200
	getb	; <REPEAT>/<UNIQUE>?
	bra _DWM3220+1
;	with	r0
	sex
	endif


	%CACHEE(_RLDrawWallsLow)
;
;	>>>   ALL BANDS DONE   <<<
;
;	(this port: outside the cache block, which is full)
;
_DWL1200:
	lms r0,(RLNextCode&$FFFF)	; Begin Execution of Next Code
	ibt r8,#bank(_RLDrawFloorsA)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

