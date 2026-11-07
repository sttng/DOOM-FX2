	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                          ENGINE TEXT MODULE                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLText


	%section(ENGINE_GSUCODE)
	arch superfx

;
;	* * * * * * *       REALITY_ENGINE TEXT       * * * * * * *
;
;	Draw FONT Data into BitMap
;
;	R1      = X Coordinate
;	R2      = Y Coordinate
;	R12	= Text Address (ASCII terminated with $00)
;	R11     = Return Address
;
	!rLineCount = r3	; Line# Counter
	!rFontBase0 = r9	; Base Address of FontData
	!rFontBase = r10	; Base Address of FontData (Adjusted)
	!rTextData = r12	; Address of Text
	!rTextDataB = r13	; Bank of Text


	%align_pad(14, 16, (_RLText-_RLTextAlign)&$0F)	; align 16,(_RLText-_RLTextAlign)&$0f
_RLText:
	ibt r0,#%00000000	; Transp.On,NoDither,8-BitColour,NoSpr.
	cmode
	iwt !rFontBase,#lo16(RLFontDef-(33*64))	; Base Address of FontData (Adjusted)
	iwt !rFontBase0,#lo16(RLFontDef)	; Base Address of FontData
	ibt !rTextDataB,#bank(_RLMsgs)	; Bank of MessageTexts

	%CACHEB(_RLText)
_RLTextAlign:
;
;	>>>   GET NEXT CHARACTER   <<<
;
_TXT200:
	moves !rLineCount,!rTextData	; ROM/RAM?
	bmi _TXT300	; ROM
	nop
;	to	r0				; RAM
	ldb (!rLineCount)
	bra _TXT350
	inc !rTextData	; Move to next Character
_TXT300:
	from !rTextDataB
	romb
	move r14,!rTextData	; Get next Character
	inc !rTextData	; Move to next Character
	getb
_TXT350:
;	with	r0				; Finished?
	swap	; Multiply by 64
	beq _TXT900	; Yes!
;	with	r0
	asr
;	from	r0
	to !rLineCount
	asr
	ibt r0,#bank(RLFontDef)	; Bank of FontData
	romb
	from !rFontBase	; Address of FontData
	to r14
	add !rLineCount
	from r14	; SPACE?
;	to	r0
	sub !rFontBase0
	ibt !rLineCount,#8	; 8 Lines of FontData
	bpl _TXT420	; No
	with r1	; YES!  DON'T DRAW!
	bra _TXT200
	add !rLineCount
;
;	>>>   PLOT A SINGLE CHARACTER TO THE BITMAP   <<<
;
_TXT400:
	with r1	; Move back to left-edge of Character
	sub #8
_TXT420:
	getc	; Pixel0
	inc r14
	plot
	getc	; Pixel1
	inc r14
	plot
	getc	; Pixel2
	inc r14
	plot
	getc	; Pixel3
	inc r14
	plot
	getc	; Pixel4
	inc r14
	plot
	getc	; Pixel5
	inc r14
	plot
	getc	; Pixel6
	inc r14
	plot
	getc	; Pixel7
	inc r14
	plot
	inc r2	; One Line Down
	dec !rLineCount	; One Less Line
	bne _TXT400+1
	with r1	; Move back to left-edge of Character
	with r2	; Move back to top line
	sub #8
	bra _TXT200+1	; Handle next character
	with !rLineCount	; ROM/RAM?
_TXT900:
	jmp r11	; Return to Caller
	nop

	%CACHEE(_RLText)


;
;	* * * * * * *       RLENGINE FONT DATA       * * * * * * *
;
	%section(RL_FONT_DATA)
RLFontDef:
	incbin "data/RLDATA/ART/rlfont.def0":(1*64)..(1*64)+(58*64)
