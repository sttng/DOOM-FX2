	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                      ENGINE FLOOR DRAW MODULE     TEXTURED FLOORS  *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLDrawFloorsA
	; public _RLDrawFloorsB
	; public _RLDrawFloorsC
	; public _RLDrawFloors


	%section(ENGINE_GSUCODE)
	arch superfx


	if useFLOORS != 0
;
;	* * * * * * *       REALITY_ENGINE DRAW FLOORS       * * * * * * *
;
;	In LOW-Detail mode, each 2-pixels wide are drawn
;

	!rPixScaleXF = r3	; SCN->RL X Scale Fraction
	!rPixScaleYF = r4	; SCN->RL Y Scale Fraction
	!rPixScaleXY = r5	; SCN->RL X/Y Scale Integer
;
	!rTemp = r6	; Temporary
	!rFloorXY = r7	; Y.B / X.B Texture Offsets
	!rFloorXF = r8	; SCN->RL X Fraction
	!rFloorYF = r9	; SCN->RL Y Fraction
;
	!rPlotDataPtr = r10	; Ptr within Current FloorPlotData
	!rColourMap = r11	; Base Address of ColourMap


	%align_pad(0, 16, (_RLDrawFloorsC-_RLDrawFloorsLowAlign)&$0F)	; align 16,(_RLDrawFloorsC-_RLDrawFloorsLowAlign)&$0f  (inactive: pad unknown)

_RLDrawFloorsC:
	iwt r2,#lo16(_RLDrawObjsC)
	bra _RLDrawFloors
	nop
_RLDrawFloorsB:
	iwt r2,#lo16(_RLDrawObjsB)
	bra _RLDrawFloors
	nop
_RLDrawFloorsA:
	iwt r2,#lo16(_RLDrawObjsA)
_RLDrawFloors:
	sms (RLNextCode&$FFFF),r2	; Save address of Next Code Jump
	lms !rPlotDataPtr,(TRFloorsEnd&$FFFF)	; FLOOR PLOT DATA START (after the Floors/Ceilings)

;
;	* * * * * * *       DRAW FLOORS IN LOW DETAIL       * * * * * * *
;
_RLDrawFloorsLow:
	iwt r13,#(($3F<<8)|$3F)	; TextureMask
	bra _DFL8000-1	; @SET UP CACHE@
	nop

;
;	>>>   DRAW FLOORS COMPLETE   <<<
;
_DFL1000:
	lms r0,(RLNextCode&$FFFF)	; Begin Execution of Next Code
	ibt r8,#bank(_RLDrawFloorsA)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop


	%CACHEB(_RLDrawFloorsLow)
_RLDrawFloorsLowAlign:
;
;	>>>   GET PIXELSTRIP PLOT INFORMATION   <<<
;
_DFL8000:
;	to	r0				; Get #Pixels To Draw / ColourMap
	ldw (!rPlotDataPtr)
;	from	r0				; #Pixels to Draw
	to r12	; End of FloorPlotData?
	lob
	beq _DFL1000	; Yes!
;
	inc !rPlotDataPtr
;	from	r0				; Get HighByte of ColourMap
	to !rColourMap
	hib
	with !rColourMap	; Get Address of ColourMap
	swap
	beq _DFL8500	; SKY!
	inc !rPlotDataPtr
;
;	to	r0				; Get X Scaling Value
	ldw (!rPlotDataPtr)
	inc !rPlotDataPtr
	inc !rPlotDataPtr
;	from	r0
	to !rPixScaleXY
	hib
;	with	r0
	lob
;	from	r0
	to !rPixScaleXF
	swap
;
;	to	r0				; Get Y Scaling Value
	ldw (!rPlotDataPtr)
	inc !rPlotDataPtr
	inc !rPlotDataPtr
;	from	r0
	to !rPixScaleYF
	lob
	with !rPixScaleYF
	swap
;	with	r0
	hib
;	with	r0
	swap
	with !rPixScaleXY
	add r0
;
	iwt r0,#bank(RLFloorsDef)	; Bank of PixelData
	romb
	to !rFloorXY	; Get Texture X/Y Offsets
	ldw (!rPlotDataPtr)
	inc !rPlotDataPtr
	inc !rPlotDataPtr
;
	from !rFloorXY	; Calculate TextureData Pointer
;	to	r0
	hib
;	with	r0
	swap
;	with	r0
	lsr
;	with	r0
	lsr
	from !rFloorXY
	to r1
	lob
;	from	r0				; (Y << 6) | (X)
	to r14
	add r1
;
;	to	r0				; Get X/Y Fraction Values
	ldw (!rPlotDataPtr)
	inc !rPlotDataPtr
	inc !rPlotDataPtr
;	from	r0				; X Fraction
	to !rFloorXF
	lob
	with !rFloorXF
	swap
;	with	r0				; Y Fraction
	hib
;	from	r0
	to !rFloorYF
	swap
;
	ibt r0,#bank(RLColourMaps)	; Bank of ColourMap Data
	romb
	getb	; Get PixelColour
;	from	r0
	to r14
	add !rColourMap
;
;	to	r0				; Get Starting X/Y Coordinates
	ldw (!rPlotDataPtr)
	inc !rPlotDataPtr	; Move to Next FloorPlotData
	inc !rPlotDataPtr
;	from	r0				; Starting Y Coordinate
	to r2
	hib
;	with	r0				; Starting X Coordinate
	lob
;	from	r0
	to r1
	add r0
;
	dec r12	; Only 1 Pixel?
	bne _DFL3100	; No
	inc r12	; Yes!
;
;	>>>   STRIP PIXEL FAST   <<<
;
	getc
	plot	; Plot the PixelPair
	plot
	bra _DFL8000+1	; Next FloorPlot
;	to	r0				; Get #Pixels To Draw / ColourMap
	ldw (!rPlotDataPtr)

;
;	>>>   STRIP PIXEL SLOW   <<<
;
_DFL3100:
	with !rFloorXF	; Move to next X Pixel
	add !rPixScaleXF
	from !rPixScaleXY
;	to	r0
	adc !rFloorXY
;	from	r0				; Mask around Texture
	to !rTemp
	and r13
;
	ibt r0,#bank(RLColourMaps)	; Bank of ColourMap Data
	romb
	getb	; Get TextureColour
;	from	r0
	to r14
	add !rColourMap
;
	with !rFloorYF	; Move to next Y Pixel
	add !rPixScaleYF
;	with	r0				; Get 0/1 Carry
	sub r0
;	with	r0
	rol
;	with	r0				; $0000 / $0100
	swap
;	with	r0
	add !rFloorXY
;	with	r0				; Mask around Texture
	and r13
;	with	r0
	hib
;
	getc	; Get PixelColour
;
;	with	r0				; Update Floor
	swap
;	from	r0
	to !rFloorXY
	add !rTemp
;
	iwt r14,#bank(RLFloorsDef)	; Bank of PixelData
	from r14
	romb
;
;	with	r0				; Calculate TextureData Pointer
	lsr
;	with	r0
	lsr
;	from	r0				; (Y << 6) | (X)
	to r14
	add !rTemp
;
	plot	; Plot the PixelPair
	dec r12
	bne _DFL3100
	plot
;
	bra _DFL8000+1	; Next FloorPlot
;	to	r0				; Get #Pixels To Draw / ColourMap
	ldw (!rPlotDataPtr)


;
;	>>>   GET SKY PIXELSTRIP PLOT INFORMATION   <<<
;
_DFL8500:
	with !rPlotDataPtr	; Move to X/Y Coordinates
	%add_i((plfPixX-plfPixScaleX))
;	to	r0				; Get Starting X/Y Coordinates
	ldw (!rPlotDataPtr)
	inc !rPlotDataPtr	; Move to Next FloorPlotData
	inc !rPlotDataPtr
;	from	r0				; Starting Y Coordinate
	to r2
	hib
;	with	r0				; Starting X Coordinate
	lob
;	from	r0
	to r1
	add r0
;
;	>>>   SKY   <<<
;
_DFL7000:
	iwt r13,#lo16(_DFL7200)	; Reset Loop Address
	lms r5,(EMNUM&$FFFF)	; Get Episode/Mission
	from r5	; Bank $01 for E1/E2, Bank $02 for E3
;	to	r0
	lob
	dec r0
;	with	r0
	lsr
	inc r0
	romb
	lms r0,(ViewAngle&$FFFF)	; Get ViewAngle
;	with	r0				; (0-ViewAngle)
	not
	inc r0
;	with	r0				; (ViewAngle << 2)
	add r0
;	with	r0
	add r0
;	with	r0				; $00-$FF
	hib
	lms r4,(RLMinPixX&$FFFF)	; Add Base X Coordinate
	with r4
	add r4
;	with	r0
	add r4
;	with	r0				; Add X Coordinate
	add r1
;	with	r0				; Get $00-$FF
	lob
;	with	r0				; Get $00-$7F
	lsr
;	with	r0				; *128 Pixels per Strip
	swap
;	with	r0
	lsr
;	with	r0				; Sub Y Coordinate
	sub r2
	ibt r14,#lo16($007F)	; Base Address of Walls (SKY1 FIRST)
	assert (lo16($007F))&$FFFF < $80 || (lo16($007F))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	with r14
	add r0
;
	iwt r3,#$0080	; R3=Distance to next PixelStrip
	iwt r4,#$BFFF	; R4=WallData .AND. Value
	dec r5	; 0=E1/E3, 1=E2
	from r5
;	to	r0
	lsr
	ibt r0,#0	; $0000=E1/E3, $4000=E2
;	with	r0
	ror
;	with	r0
	lsr
	with r4
	add r0
	iwt r5,#$8000	; R5=WallData .OR.  Value
	with r5
	add r0
	from r14	; Wrap around SKY WallData
;	to	r0
	and r4
;	from	r0
	to r14
	or r5
;
_DFL7200:
	getc	; Get Next Pixel
;
	from r14	; Move to next Pixel
;	to	r0
	add r3
;	with	r0				; Wrap around SKY WallData
	and r4
;	from	r0
	to r14
	or r5
;
	plot	; Draw the PixelPair
	loop
	plot
;
	iwt r13,#(($3F<<8)|$3F)	; TextureMask
	iwt r15,#lo16(_DFL8000)+1	; Next FloorPlot
;	to	r0				; Get #Pixels To Draw / ColourMap
	ldw (!rPlotDataPtr)


	%CACHEE(_RLDrawFloorsLow)
	endif
