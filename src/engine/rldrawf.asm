	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                      ENGINE FLOOR DRAW MODULE        SOLID FLOORS  *
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


	RLSKYROWSHIFT = 100-(RLViewPixY/2)	; (wall format 2) WAD sky row at the horizon (100) - the cartridge's (72)

	if useFLOORS == 0
;
;	* * * * * * *       REALITY_ENGINE DRAW FLOORS       * * * * * * *
;
;	In LOW-Detail mode, each 2-pixels wide are drawn
;

	!rColourMapB = r8	; Bank of ColourMaps
	!rColourMap = r9	; ColourMap
	!rSectorData = r10	; Pointer to SectorData
	!rPlotDataPtr = r11	; Ptr within Current FloorPlotData


	%align_pad(2, 16, (_RLDrawFloorsC-_RLDrawFloorsLowAlign)&$0F)	; align 16,(_RLDrawFloorsC-_RLDrawFloorsLowAlign)&$0f
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
;
	ibt !rColourMapB,#bank(RLColourMaps)
	from !rColourMapB
	romb
;
	lms !rPlotDataPtr,(TRFloorsEnd&$FFFF)	; Start of FloorPlotData (after the Floors/Ceilings)
;
;	* * * * * * *       DRAW FLOORS IN LOW DETAIL       * * * * * * *
;
_RLDrawFloorsLow:

	%CACHEB(_RLDrawFloorsLow)
_RLDrawFloorsLowAlign:
	iwt r13,#lo16(_DFL5400)	; Default Loop Address
	bra _DFL8000+1	; Start Drawing Floors
;	to	r0				; Get #Pixels To Draw/ColourMap
	ldw (!rPlotDataPtr)

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

;
;	>>>   NORMAL STRIP DITHERED   <<<
;
_DFL5000:
;	to	r0				; Get SectorData
	ldw (!rPlotDataPtr)
	inc !rPlotDataPtr	; Move to Next Pointer
	inc !rPlotDataPtr
;
	ldb (r0)	; Get PixelColour
;	from	r0
	to r14
	add !rColourMap
;
	if !useCHECKFLOORPLOTDATA != 0
	from r1
;	to	r0
	add r12
;	with	r0
	add r12
	ibt r4,#(RLViewPixX/3)
	from r4
;	to	r0
	sub r0
	bge ._0
	%HALTGSU($44)
._0:
	iwt r0,#(RLViewPixY-1)
;	with	r0
	sub r2
	bge ._1
	%HALTGSU($45)
._1:
	endif

	to r4	; Get FIRST Colour
	getb
	iwt r0,#$100	; Move to NEXT DARKEST Level
	with r14
	add r0
	from r2	; .C 0=Leave Order, 1=Swap Order
;	to	r0
	xor r1
	lsr
	bcc _DFL5200	; Leave or Change Order?
	to r0	; Leave
	move r0,r4	; Change
	to r4
_DFL5200:
	getb
;
;	>>>   BOTH DITHER COLOURS THE SAME?   <<<
;
;	(this port: in about 2/3 of the floor strips both colour map levels give
;	the same SNES colour: one COLOR, then only the 2 PLOTs per PixelPair)
;
;	from	r0
	cmp r4
	beq _DFL5500
	nop
_DFL5400:
;	from	r0
	color
	plot	; Draw the PixelPair
	from r4
	color
	loop
	plot
	bra _DFL8000+1
;	to	r0				; Get #Pixels To Draw/ColourMap
	ldw (!rPlotDataPtr)
;
;	>>>   ONE COLOUR   <<<
;
_DFL5500:
;	from	r0
	color
	iwt r13,#lo16(_DFL5600)	; Loop Address
_DFL5600:
	plot	; Draw the PixelPair
	loop
	plot
	iwt r13,#lo16(_DFL5400)	; Default Loop Address
;
;	>>>   GET PIXELSTRIP PLOT INFORMATION   <<<
;
_DFL8000:
;	to	r0				; Get #Pixels To Draw/ColourMap
	ldw (!rPlotDataPtr)
;	from	r0
	to r12
	lob
	beq _DFL1000	; End of FloorPlotData!
;
;	with	r0				; Get ColourMap
	hib
;	from	r0
	to !rColourMap
	swap
;
	inc !rPlotDataPtr	; Get Starting X/Y Coordinates
	inc !rPlotDataPtr
;	to	r0
	ldw (!rPlotDataPtr)
;
;	from	r0				; Starting Y Coordinate
	to r2
	hib
;	with	r0				; Starting X Coordinate
	lob
;	from	r0
	to r1
	add r0
;
	inc !rPlotDataPtr
	moves !rColourMap,!rColourMap	; SKY has ColourMap=0
	bne _DFL5000	; No, Normal Floor/Ceiling!
	inc !rPlotDataPtr

;
;	>>>   SKY   <<<
;
_DFL7000:
	inc !rPlotDataPtr	; Move to Next Pointer
	inc !rPlotDataPtr
;
	iwt r13,#lo16(_DFL7200)	; Reset Loop Address
	lms r5,(EMNUM&$FFFF)	; Get Episode/Mission
	if !RLSKY4 == 0
	ibt r0,#1	; Bank $01 for _SKY1/_SKY2
	else
	from r5	; Bank = 1 + (((E+1)>>2)&1): E1/E2 $01, E3/E4 $02 (Ultimate DOOM)
	%add_i(1)
	lsr
	lsr
	%and_i(1)
	%add_i(1)
	endif
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
	if !RLWALLFMT2
;	(this port, skies from a WAD: row 100 of the picture at the horizon, as on
;	the PC; the cartridge's own skies have row 72 there)
	ibt r14,#lo16($007F-RLSKYROWSHIFT)	; Base Address of Walls (SKY1 FIRST)
	else
	ibt r14,#lo16($007F)	; Base Address of Walls (SKY1 FIRST)
	endif
	with r14
	add r0
;
	iwt r3,#$0080	; R3=Distance to next PixelStrip
	iwt r4,#$BFFF	; R4=WallData .AND. Value
	if !RLSKY4 == 0
	from r5	; 0=E1, 1=E2, 1=E3
;	to	r0
	lsr
;	with	r0
	lsr
	else
	from r5	; $4000 for E2/E4: carry = (E-1)&1 (Ultimate DOOM)
	%sub_i(1)
	%and_i(1)
	lsr
	endif
	ibt r0,#0	; $0000 = 1st sky of the bank, $4000 = 2nd
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
;	>>>   DOES THE STRIP STAY INSIDE THE SKY PICTURE?   <<<
;
;	(this port: then no wrap per PixelPair: 3 instructions fewer)
;
	from r12	; #PixelPairs * $80
;	to	r0
	swap
;	with	r0
	lsr
	move r6,r0
	iwt r0,#$3FFF	; Offset within the 16 KB picture
;	with	r0
	and r14
;	with	r0
	add r6
	iwt r6,#$4000	; Past its end?
;	with	r0
	and r6
	bne _DFL7200	; Yes, wrap each PixelPair
	nop
	iwt r13,#lo16(_DFL7600)	; Loop Address
_DFL7600:
	getc	; Get Next Pixel
	with r14	; Move to next Pixel
	add r3
	plot	; Draw the PixelPair
	loop
	plot
	bra _DFL7900
	nop
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
_DFL7900:
	from !rColourMapB
	romb
;
	iwt r13,#lo16(_DFL5400)	; Default Loop Address
;
	iwt r15,#lo16(_DFL8000)+1
;	to	r0				; Get #Pixels To Draw/ColourMap
	ldw (!rPlotDataPtr)


	%CACHEE(_RLDrawFloorsLow)
	endif
