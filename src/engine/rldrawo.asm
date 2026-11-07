	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                      ENGINE OBJECT DRAW MODULE (SMALLER)           *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLDrawObjsA
	; public _RLDrawObjsB
	; public _RLDrawObjsC
	; public _RLDrawObjs


	%section(ENGINE_GSUCODE)
	arch superfx

;
;	* * * * * * *       REALITY_ENGINE DRAW OBJECTS       * * * * * * *
;
;	In LOW-Detail mode, each 2-pixels wide are from a single OBJECT PLOT
;	Strip.
;

	!rPixelCount = r3	; Pixel SkipCount/RepeatCount
;
	!rColourMapB = r4	; Bank of ColourMap Data
	!rColourMap = r5	; ColourMap
;
	!rPixScaleF = r6	; SCN->RL Scale Fraction
	!rPixScale = r7	; SCN->RL Scale Integer
;
	!rObjF = r8	; SCN->RL Obj Fraction
	!rObj = r9	; Pointer to ObjTextureData
	!rObjB = r10	; Bank of ObjTextureData
;
	!rPlotDataPtr = r11	; Ptr within Current ObjPlotData


	%align_pad(11, 16, (_RLDrawObjsC-_RLDrawObjsLowAlign)&$0F)	; align 16,(_RLDrawObjsC-_RLDrawObjsLowAlign)&$0f

_RLDrawObjsC:
	iwt r2,#lo16(_RLDrawMiscC)	; _RLDrawSpritesC
	bra _RLDrawObjs
	nop
_RLDrawObjsB:
	iwt r2,#lo16(_RLDrawMiscB)	; _RLDrawSpritesB
	bra _RLDrawObjs
	nop
_RLDrawObjsA:
	iwt r2,#lo16(_RLDrawMiscA)	; _RLDrawSpritesA
_RLDrawObjs:
	sms (RLNextCode&$FFFF),r2	; Save address of Next Code Jump
	ibt !rColourMapB,#bank(RLColourMaps)	; Bank of ColourMap Data
	lms !rPlotDataPtr,(TRObjPlotPtr&$FFFF)	; OBJ PLOT DATA END
;
	ibt r0,#%00000000	; Transp.On,NoDither,8-BitColour,NoSpr.
	cmode
;
	iwt r13,#lo16(_DOL3200)+1	; ImageOffset Address
;
	if !useCHECKOBJPLOTDATA != 0
	ibt r2,#0
	endif

;
;	* * * * * * *       DRAW OBJS IN LOW DETAIL       * * * * * * *
;
_RLDrawObjsLow:
	bra _DOL8000-1	; @SET UP CACHE@
	nop

;
;	>>>   DRAW OBJECTS COMPLETE   <<<
;
_DOL1000:
	lms r0,(RLNextCode&$FFFF)	; Begin Execution of Next Code
	ibt r8,#bank(_RLDrawMiscA)	; _RLDrawSpritesA
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop


	%CACHEB(_RLDrawObjsLow)
_RLDrawObjsLowAlign:
;
;	>>>   GET OBJPLOT GROUPHEADER   <<<
;
_DOL8000:
	dec !rPlotDataPtr	; Move to Scale
	dec !rPlotDataPtr
;	to	r0				; Get Scale
	ldw (!rPlotDataPtr)
	moves r0,r0
;	from	r0
	to !rPixScale
	beq _DOL1000	; End of ObjPlotData!
	hib
;	with	r0
	lob
;	from	r0
	to !rPixScaleF
	swap
	inc r0
	with !rPlotDataPtr
	sub #4
;
;	>>>   GET PIXELSTRIP PLOT INFORMATION   <<<
;
_DOL7000:
	dec !rPlotDataPtr	; Get WorldZFraction/#Pixels
	dec !rPlotDataPtr
;	to	r0
	ldw (!rPlotDataPtr)

	if !useCHECKOBJPLOTDATA != 0
	inc r2	; Error with ObjPlotData?
	bpl ._0
	%HALTGSU($21)	; YES!
._0:
	endif

;	from	r0				; R12 = #Pixels To Draw
	to r12
	hib
;	from	r0				; Get WorldZ DrawFraction
	to !rObjF
	beq _DOL8000	; End of ObjPlotGroup!
	lob
	with !rObjF
	swap
;
	dec !rPlotDataPtr	; Get Bank of PixelData/ColourMap
	dec !rPlotDataPtr
;	to	r0
	ldw (!rPlotDataPtr)
	romb
	move !rObjB,r0
;	with	r0				; Get Address of ColourMap
	hib
;	from	r0
	to !rColourMap
	swap
;
	dec !rPlotDataPtr	; Get Address of PixelData
	dec !rPlotDataPtr
	to r14
	ldw (!rPlotDataPtr)
;
	dec !rPlotDataPtr	; Get Starting X/Y Coordinates
	dec !rPlotDataPtr
;	to	r0
	ldw (!rPlotDataPtr)
;	from	r0
	to r1
	lob
	with r1
	add r1
;	from	r0
	to r2
	hib

	if !useCHECKOBJPLOTDATA != 0
	iwt r0,#(RLViewPixY-1)
;	with	r0
	sub r2
	bge ._2
	%HALTGSU($23)
._2:
	endif

	if !RLSPECTRE != 0
	moves !rColourMap,!rColourMap	; SHADOW object? (colourmap page bit 7 clear)
	bmi _DOL7800	; No
	nop
	iwt r15,#lo16(_DOFEntry)	; Yes
	nop
_DOL7800:
	endif
	dec !rPlotDataPtr	; Get ImageOffset
	dec !rPlotDataPtr
;	to	r0
	ldb (!rPlotDataPtr)
	moves !rPixelCount,r0
	beq _DOL4200+1	; No ImageOffset
	getb
;
;	* * * * * * *       ADJUST FOR IMAGE OFFSET       * * * * * * *
;
_DOL3200:
	inc r14
;	with	r0				; <SKIP>/<REPEAT>/<UNIQUE>?
	lob
	beq _DOL3400	; <SKIP>/<REPEAT>
_DOL3300:
	dec !rPixelCount	; <UNIQUE>
	bne _DOL3200
	getb	; Get Next ImageByte
	bra _DOL4220
;	with	r0
	lob
;
;	>>>   SKIP   <<<
;
_DOL3400:
	getb	; <SKIP>/<REPEAT>?
	inc r14
;	with	r0
	sex
	bmi _DOL3600	; <REPEAT>
	with !rPixelCount	; <SKIP>
	beq _DOL4800	; <END>
	sub r0
	bmi _DOL3500	; <SKIP RUNNING/EXACTLY ENDED>
	inc !rPixelCount
	bra _DOL3200
	getb	; Get Next ImageByte
_DOL3500:
	with !rPixelCount
	beq _DOL4200	; <SKIP> ENDS EXACTLY
	not
	bra _DOL5400	; <SKIP> RUNNING
	inc !rPixelCount
;
;	>>>   REPEAT   <<<
;
_DOL3600:
	add r0	; ImageOffset -= RepeatCount
	bmi _DOL3700	; <REPEAT RUNNING/EXACTLY ENDED>
	inc !rPixelCount
	inc r14	; Skip RepeatColour
	bra _DOL3200
	getb	; Get Next ImageByte
_DOL3700:
	with !rPixelCount
	bne _DOL6200+1	; <REPEAT> RUNNING
	not

;
;	* * * * * * *       STRIP PIXEL SLOW       * * * * * * *
;
_DOL4200:
	getb	; <SKIP>/<REPEAT>/<UNIQUE>?
;	with	r0
	lob
_DOL4220:
	beq _DOL5200	; <SKIP>/<REPEAT>
;
;	>>>   UNIQUE   <<<
;
	from !rColourMapB
	romb
	move !rObj,r14
;	from	r0
	to r14
	add !rColourMap
	inc !rObj
	from !rObjB
	romb
	getc
_DOL4400:
	plot	; Draw the PixelBlock
	dec r12	; One less ScreenPixel to Draw
	beq _DOL4800
	plot
	dec r1	; Move back to correct X Coordinate
	dec r1
	with !rObjF	; Move to next Pixel
	add !rPixScaleF
	from !rPixScale
;	to	r0
	adc #0
	beq _DOL4400
	dec r2	; Move to next Y Coordinate
;
;	>>>   UNIQUE DONE   <<<
;
	move r14,!rObj
	with r0
	bra _DOL3300
	to !rPixelCount
;
;	>>>   OBJDATA STRIP DONE   <<<
;
_DOL4800:
	iwt r15,#lo16(_DOL7000)+1	; Next ObjectPlot
	dec !rPlotDataPtr	; Get WorldZFraction/#Pixels

;
;	>>>   SKIP   <<<
;
_DOL5200:
	inc r14	; SkipCount/RepeatCount
	getb
	inc r14
;	from	r0				; <SKIP>/<REPEAT>?
	to !rPixelCount
	sex
	bmi _DOL6200	; <REPEAT>
	with !rPixelCount
	beq _DOL4800	; <END>
_DOL5400:
	dec r12	; One less ScreenPixel to Draw
	beq _DOL4800
	with !rObjF	; Move to next Pixel
	add !rPixScaleF
	from !rPixScale
;	to	r0
	adc #0
	beq _DOL5400
	dec r2	; Move to next Y Coordinate
	with !rPixelCount
	sub r0
	dec !rPixelCount
	bpl _DOL5400
	inc !rPixelCount
;
;	>>>   SKIP DONE   <<<
;
	beq _DOL4200+1
	getb	; Get Next ImageByte
	inc r14
	with !rPixelCount
	not
	jmp r13
	inc !rPixelCount

;
;	>>>   REPEAT   <<<
;
_DOL6200:
	not	; RepeatCount
	inc !rPixelCount
	move !rObj,r14
	from !rColourMapB
	romb
	getb	; Get RepeatColour
;	from	r0
	to r14
	add !rColourMap
	inc !rObj
	from !rObjB
	romb
	getc
_DOL6400:
	plot	; Draw the PixelBlock
	dec r12	; One less ScreenPixel to Draw
	beq _DOL4800
	plot
	dec r1	; Move back to correct X Coordinate
	dec r1
	with !rObjF	; Move to next Pixel
	add !rPixScaleF
	from !rPixScale
;	to	r0
	adc #0
	beq _DOL6400
	dec r2	; Move to next Y Coordinate
	with !rPixelCount
	sub r0
	dec !rPixelCount
	bpl _DOL6400
	inc !rPixelCount
;
;	>>>   REPEAT DONE   <<<
;
	move r14,!rObj
	beq _DOL4200+1
	getb	; Get Next ImageByte
	inc r14
	with !rPixelCount
	not
	jmp r13
	inc !rPixelCount


	%CACHEE(_RLDrawObjsLow)
;
;	* * * * * * *       SHADOW OBJECTS (Spectre, this port)       * * * * * * *
;
;	The sprite's texels only give the shape: every pixel it covers is the
;	pixel already on screen, darkened through the object's colourmap
;	(rltraceo2.asm marks shadow objects by a colourmap page with bit 7 clear).
;	Same strip decoder as _DOL3200-_DOL6400 (copied), run from ROM.
;
	if !RLSPECTRE != 0
_DOFEntry:
	iwt !rPixelCount,#$8000	; Real ColourMap address
	with !rColourMap
	or !rPixelCount
	dec !rPlotDataPtr	; Get ImageOffset
	dec !rPlotDataPtr
;	to	r0
	ldb (!rPlotDataPtr)
	moves !rPixelCount,r0
	beq _DOF4200+1	; No ImageOffset
	getb
_DOF3200:
	inc r14
;	with	r0				; <SKIP>/<REPEAT>/<UNIQUE>?
	lob
	beq _DOF3400	; <SKIP>/<REPEAT>
_DOF3300:
	dec !rPixelCount	; <UNIQUE>
	bne _DOF3200
	getb	; Get Next ImageByte
	bra _DOF4220
;	with	r0
	lob
;
;	>>>   SKIP   <<<
;
_DOF3400:
	getb	; <SKIP>/<REPEAT>?
	inc r14
;	with	r0
	sex
	bmi _DOF3600	; <REPEAT>
	with !rPixelCount	; <SKIP>
	beq _DOF4800	; <END>
	sub r0
	bmi _DOF3500	; <SKIP RUNNING/EXACTLY ENDED>
	inc !rPixelCount
	bra _DOF3200
	getb	; Get Next ImageByte
_DOF3500:
	with !rPixelCount
	beq _DOF4200	; <SKIP> ENDS EXACTLY
	not
	bra _DOF5400	; <SKIP> RUNNING
	inc !rPixelCount
;
;	>>>   REPEAT   <<<
;
_DOF3600:
	add r0	; ImageOffset -= RepeatCount
	bmi _DOF3700	; <REPEAT RUNNING/EXACTLY ENDED>
	inc !rPixelCount
	inc r14	; Skip RepeatColour
	bra _DOF3200
	getb	; Get Next ImageByte
_DOF3700:
	with !rPixelCount
	bne _DOF6200+1	; <REPEAT> RUNNING
	not

;
;	* * * * * * *       STRIP PIXEL SLOW       * * * * * * *
;
_DOF4200:
	getb	; <SKIP>/<REPEAT>/<UNIQUE>?
;	with	r0
	lob
_DOF4220:
	beq _DOF5200	; <SKIP>/<REPEAT>
;
;	>>>   UNIQUE   <<<
;
	from !rColourMapB
	romb
	move !rObj,r14
	rpix	; SHADOW: the pixel already drawn behind the sprite
	to r14
	add !rColourMap
	inc !rObj
	from !rObjB
	romb
	getc
_DOF4400:
	plot	; Draw the PixelBlock
	dec r12	; One less ScreenPixel to Draw
	beq _DOF4800
	plot
	dec r1	; Move back to correct X Coordinate
	dec r1
	with !rObjF	; Move to next Pixel
	add !rPixScaleF
	from !rPixScale
;	to	r0
	adc #0
	beq _DOF4400
	dec r2	; Move to next Y Coordinate
;
;	>>>   UNIQUE DONE   <<<
;
	move r14,!rObj
	with r0
	bra _DOF3300
	to !rPixelCount
;
;	>>>   OBJDATA STRIP DONE   <<<
;
_DOF4800:
	iwt r15,#lo16(_DOL7000)+1	; Next ObjectPlot
	dec !rPlotDataPtr	; Get WorldZFraction/#Pixels

;
;	>>>   SKIP   <<<
;
_DOF5200:
	inc r14	; SkipCount/RepeatCount
	getb
	inc r14
;	from	r0				; <SKIP>/<REPEAT>?
	to !rPixelCount
	sex
	bmi _DOF6200	; <REPEAT>
	with !rPixelCount
	beq _DOF4800	; <END>
_DOF5400:
	dec r12	; One less ScreenPixel to Draw
	beq _DOF4800
	with !rObjF	; Move to next Pixel
	add !rPixScaleF
	from !rPixScale
;	to	r0
	adc #0
	beq _DOF5400
	dec r2	; Move to next Y Coordinate
	with !rPixelCount
	sub r0
	dec !rPixelCount
	bpl _DOF5400
	inc !rPixelCount
;
;	>>>   SKIP DONE   <<<
;
	beq _DOF4200+1
	getb	; Get Next ImageByte
	inc r14
	with !rPixelCount
	not
	iwt r15,#lo16(_DOF3200)+1	; (ImageOffset re-entry of the shadow loop)
	inc !rPixelCount

;
;	>>>   REPEAT   <<<
;
_DOF6200:
	not	; RepeatCount
	inc !rPixelCount
	move !rObj,r14
	from !rColourMapB
	romb
	rpix	; SHADOW: the pixel already drawn behind the sprite
;	from	r0
	to r14
	add !rColourMap
	inc !rObj
	from !rObjB
	romb
	getc
_DOF6400:
	plot	; Draw the PixelBlock
	dec r12	; One less ScreenPixel to Draw
	beq _DOF4800
	plot
	dec r1	; Move back to correct X Coordinate
	dec r1
	with !rObjF	; Move to next Pixel
	add !rPixScaleF
	from !rPixScale
;	to	r0
	adc #0
	beq _DOF6400
	dec r2	; Move to next Y Coordinate
	with !rPixelCount
	sub r0
	dec !rPixelCount
	bpl _DOF6400
	inc !rPixelCount
;
;	>>>   REPEAT DONE   <<<
;
	move r14,!rObj
	beq _DOF4200+1
	getb	; Get Next ImageByte
	inc r14
	with !rPixelCount
	not
	iwt r15,#lo16(_DOF3200)+1	; (ImageOffset re-entry of the shadow loop)
	inc !rPixelCount


	endif

