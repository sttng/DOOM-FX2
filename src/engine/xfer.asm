	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*             G E N E R A L I Z E D   T R A N S F E R S   MODULE     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/xfer.inc"

	; public XFer

	; public DeCompress


	%section(XFER)


;
;	* * * * * * *       TRANSFER       * * * * * * *
;
;	.X/.A = Address of TransferTable
;
	; dbr ?
	; dpr 0
	; mode 'aX'
XFer:
	stx.b XFerPtr	; Save Pointer to Source XFer Data
	sta.b XFerPtr+2
	rep #$20		; mode 'A!'
XFer200:
	lda.b [XFerPtr]	; Flags
	bmi XFer900	; End
	bit.w #xftNODATA	; No Data associated with this XFER?
	bne XFer800	; Yes!  Don't DeCompress it!
	bit.w #xftRAW	; Is data RAW?
	bne XFer300	; Yes!  Don't DeCompress it!
	cmp.w #xftRAM	; Going to RAM?
	beq XFer800	; Yes!  Don't DeCompress it!
;
;	>>>   COMPRESSED DATA   <<<
;
	pha
	ldy.w #xfsSource	; .L/.H
	lda.b [XFerPtr],y
	tax
	ldy.w #xfsSource+2	; .B
	lda.b [XFerPtr],y
	ora.w #(bank(DeCompBuffer)<<8)
	ldy.w #lo16(DeCompBuffer)
	jsl.l DeCompress	; DeCompress the Data
	pla
	jmp.w XFer800
;
;	>>>   RAW DATA   <<<
;
XFer300:
	pha
	ldy.w #xfsSource	; .L/.H
	lda.b [XFerPtr],y
	sta.b Temp
	ldy.w #xfsSource+2	; .B
	lda.b [XFerPtr],y
	sta.b Temp+2
	ldy.w #xfsLen	; Length
	lda.b [XFerPtr],y
	sta.b Temp2
	pla
;
;	>>>   TRANSFER THE DATA   <<<
;
XFer800:
	and.w #$00FF	; Discard Flags
	tax
	phk	; To fake a JSL
	jsr.w (XFerJumps,x)	; Call the routine
	rep #$30		; mode 'AX!'
	lda.b XFerPtr	; Move to next XFerBlock
	clc
	adc.w #xfsSize
	sta.b XFerPtr
	jmp.w XFer200
XFer900:
	rtl
;
;	* * * * * * *       TRANSFER JUMPS       * * * * * * *
;
XFerJumps:
	dw lo16(XFerCode)	; Exec Code
	dw lo16(XFerRAM)	; XFer RAM
	dw lo16(XFerVRAM8L)	; XFer VRAM 8L
	dw lo16(XFerVRAM8H)	; XFer VRAM 8H
	dw lo16(XFerVRAM16)	; XFer VRAM 16
	dw lo16(XFerCGRAM)	; XFer CGRAM
	dw lo16(XFerVRAMF8L)	; Fill VRAM 8L
	dw lo16(XFerVRAMF8H)	; Fill VRAM 8H
	dw lo16(XFerVRAMF16)	; Fill VRAM 16
	dw lo16(XFerVRAMM8L)	; Mask VRAM 8L
	dw lo16(XFerVRAMM8H)	; Mask VRAM 8H
	dw lo16(XFerVRAMM16)	; Mask VRAM 16
	dw lo16(XFerVRAMD16)	; XFer VRAM 16 (Add base to dest)
	dw lo16(XFerVRAM8HC)	; XFer VRAM 8H Continue

;
;	* * * * * * *       XFER CODE       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
XFerCode:
	ldy.w #xfsSource	; .L/.H Source
	lda.b [XFerPtr],y
	tax
	ldy.w #xfsSource+2	; .B Source
	lda.b [XFerPtr],y
	sep #$20		; mode 'a!'
	pha		; Jump to Source+1 via rtl (Source = routine-1);
	phx		; the routine's rtl returns to XFer800
	rtl

;
;	* * * * * * *       XFER RAM       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
XFerRAM:
	lda.b [XFerPtr]	; RAW Data?
	and.w #xftRAW
	bne XFerRAM200	; Yes, don't decompress!
	ldy.w #xfsSource	; .L/.H Source
	lda.b [XFerPtr],y
	tax
	ldy.w #xfsDest	; .L/.H Dest
	lda.b [XFerPtr],y
	pha
	ldy.w #xfsSource+2	; .B Source
	lda.b [XFerPtr],y
	sep #$20		; mode 'a!'
	xba
	ldy.w #xfsDest+2	; .B Dest
	lda.b [XFerPtr],y
	xba
	rep #$20		; mode 'A!'
	ply
	jsl.l DeCompress	; DeCompress the Data to RAM
	lda.b Temp2+2	; Was the data compressed?
	bne XFerRAM900	; Yes, it was transferred
XFerRAM200:
	ldy.w #xfsDest	; .L/.H Dest
	lda.b [XFerPtr],y
	sta.b Temp+4
	ldy.w #xfsDest+2	; .B Dest
	lda.b [XFerPtr],y
	sta.b Temp+6
	ldy.b Temp2	; .Y = #Bytes to Transfer
	dey
	sep #$20		; mode 'a!'
XFerRAM500:
	lda.b [Temp],y	; Source Data
	sta.b [Temp+4],y
	dey
	bpl XFerRAM500
XFerRAM900:
	rtl


;
;	* * * * * * *       XFER VRAM 8L       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
XFerVRAMM8L:
XFerVRAM8L:
	if 0 != 0
	bit.w XFerNasty-1	; NASTY Transfer?
	bmi XFerVRAM8LNasty	; Yes
	lda.b Temp2	; [TEMP2] = DataSize
	sta.w DMA0NUML
	lda.b Temp	; [TEMP] = SourceData
	sta.w DMA0A1L
	ldy.w #xfsDest	; .L/.H Dest
	lda.b [XFerPtr],y
	sta.w VMADDL
	sep #$20
	rep #$10		; mode 'aX!'
	lda.b Temp+2	; [TEMP] = SourceData
	sta.w DMA0A1B
	stz.w VMAINC
;	lda	#%00000000		; A->B, Abs., Auto Inc,1-Add
	stz.w DMA0INC
	lda.b #lo16(VMDATAL)	; VMDATA
	sta.w DMA0DEST
	lda.b #$01	; Enable/Start Channel#0
	sta.w MDMAEN
	rtl
;
	; mode 'AX'
XFerVRAM8LNasty:
	stz.b Temp3+2	; [TEMP3+2] = #Bytes transferred so far
XFerVRAM8LNasty200:
	jsl.l WaitVBlank	; Wait until IN VBlank
	lda.w #xferNastyMax
	cmp.b Temp2	; [TEMP2] = DataSize
	bcc XFerVRAM8LNasty400
	lda.b Temp2
XFerVRAM8LNasty400:
	sta.b Temp3	; [TEMP3] = BlockSize
	sta.w DMA0NUML
	lda.b Temp	; [TEMP] = SourceData
	sta.w DMA0A1L
	ldy.w #xfsDest	; .L/.H Dest
	lda.b [XFerPtr],y
	clc
	adc.b Temp3+2
	sta.w VMADDL
	sep #$20		; mode 'a!'
	lda.b Temp+2	; [TEMP] = SourceData
	sta.w DMA0A1B
	stz.w VMAINC
;	lda	#%00000000		; A->B, Abs., Auto Inc,1-Add
	stz.w DMA0INC
	lda.b #lo16(VMDATAL)	; VMDATA
	sta.w DMA0DEST
	lda.b #$01	; Enable/Start Channel#0
	sta.w MDMAEN
	rep #$20		; mode 'A!'
	lda.b Temp	; Move forward through data
	clc
	adc.b Temp3
	sta.b Temp
	lda.b Temp3+2	; Update VRAM Destination Pointer
	clc
	adc.b Temp3
	sta.b Temp3+2
	lda.b Temp2	; Less data remaining to transfer
	sec
	sbc.b Temp3
	sta.b Temp2
	bne XFerVRAM8LNasty200	; Not done yet
	endif
	rtl

;
;	* * * * * * *       XFER VRAM 8H       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
XFerVRAM8HC:
	if 0 != 0
	jmp.w XFerVRAM8H200	; Don't retransfer VMADDL
	endif
XFerVRAMM8H:
XFerVRAM8H:
	if 0 != 0
	bit.w XFerNasty-1	; NASTY Transfer?
	bmi XFerVRAM8HNasty	; Yes
	ldy.w #xfsDest	; .L/.H Dest
	lda.b [XFerPtr],y
	sta.w VMADDL
XFerVRAM8H200:
	lda.b Temp2	; [TEMP2] = DataSize
	beq XFerVRAM8H800	; No data to transfer!
	sta.w DMA0NUML
	lda.b Temp	; [TEMP] = SourceData
	sta.w DMA0A1L
	sep #$20
	rep #$10		; mode 'aX!'
	lda.b Temp+2	; [TEMP] = SourceData
	sta.w DMA0A1B
	lda.b #$80
	sta.w VMAINC
;	lda	#%00000000		; A->B, Abs., Auto Inc,1-Add
	stz.w DMA0INC
	lda.b #lo16(VMDATAH)	; VMDATA
	sta.w DMA0DEST
	lda.b #$01	; Enable/Start Channel#0
	sta.w MDMAEN
XFerVRAM8H800:
	rtl
;
	; mode 'AX'
XFerVRAM8HNasty:
	stz.b Temp3+2	; [TEMP3+2] = #Bytes transferred so far
XFerVRAM8HNasty200:
	jsl.l WaitVBlank	; Wait until IN VBlank
	lda.w #xferNastyMax
	cmp.b Temp2	; [TEMP2] = DataSize
	bcc XFerVRAM8HNasty400
	lda.b Temp2
XFerVRAM8HNasty400:
	sta.b Temp3	; [TEMP3] = BlockSize
	sta.w DMA0NUML
	lda.b Temp	; [TEMP] = SourceData
	sta.w DMA0A1L
	ldy.w #xfsDest	; .L/.H Dest
	lda.b [XFerPtr],y
	clc
	adc.b Temp3+2
	sta.w VMADDL
	sep #$20		; mode 'a!'
	lda.b Temp+2	; [TEMP] = SourceData
	sta.w DMA0A1B
	lda.b #$80
	sta.w VMAINC
;	lda	#%00000000		; A->B, Abs., Auto Inc,1-Add
	stz.w DMA0INC
	lda.b #lo16(VMDATAH)	; VMDATA
	sta.w DMA0DEST
	lda.b #$01	; Enable/Start Channel#0
	sta.w MDMAEN
	rep #$20		; mode 'A!'
	lda.b Temp	; Move forward through data
	clc
	adc.b Temp3
	sta.b Temp
	lda.b Temp3+2	; Update VRAM Destination Pointer
	clc
	adc.b Temp3
	sta.b Temp3+2
	lda.b Temp2	; Less data remaining to transfer
	sec
	sbc.b Temp3
	sta.b Temp2
	bne XFerVRAM8HNasty200	; Not done yet
	endif
	rtl


;
;	* * * * * * *       XFER VRAM MASK 16       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
XFerVRAMM16:
	ldy.w #xfsData0	; AND Mask
	lda.b [XFerPtr],y
	sta.b Temp3
	ldy.w #xfsData1	; ORA Mask
	lda.b [XFerPtr],y
	sta.b Temp3+2
	ldy.w #xfsData2	; ADD Value (Indirect Pointer)
	lda.b [XFerPtr],y
	sta.b Temp3+4
;	lda	(Temp3+4)
;	sta	Temp3+4
	ldy.b Temp2	; [TEMP2] = DataSize
	beq XVM16P	; Nothing to transfer
	jmp.w XVM16J
XVM16E:
	lda.b [Temp],y	; Get Data
	and.b Temp3	; AND Mask
	ora.b Temp3+2	; ORA Mask
	clc
	adc.b Temp3+4	; ADD Value
	sta.b [Temp],y
XVM16J:
	dey
	dey
	bpl XVM16E
XVM16P:
;
;	* * * * * * *       XFER VRAM 16       * * * * * * *
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE   !!!
;
	; dbr ?
	; dpr 0
	; mode 'AX'
XFerVRAM16:
	bit.w XFerNasty-1	; NASTY Transfer?
	bmi XFerVRAM16Nasty	; Yes
	lda.b Temp2	; [TEMP2] = DataSize
	sta.w DMA0NUML
	lda.b Temp	; [TEMP] = SourceData
	sta.w DMA0A1L
	ldy.w #xfsDest	; .L/.H Dest
	lda.b [XFerPtr],y
	sta.w VMADDL
	sep #$20
	rep #$10		; mode 'aX!'
	lda.b Temp+2	; [TEMP] = SourceData
	sta.w DMA0A1B
	lda.b #$80
	sta.w VMAINC
	lda.b #%00000001	; A->B, Abs., Auto Inc,2-Add-WriteLH
	sta.w DMA0INC
	lda.b #lo16(VMDATAL)	; VMDATA
	sta.w DMA0DEST
	lda.b #$01	; Enable/Start Channel#0
	sta.w MDMAEN
	rtl
;
	; mode 'AX'
XFerVRAM16Nasty:
	stz.b Temp3+2	; [TEMP3+2] = #Words transferred so far
XFerVRAM16Nasty200:
	jsl.l WaitVBlank	; Wait until IN VBlank
	lda.w #xferNastyMax
	cmp.b Temp2	; [TEMP2] = DataSize
	bcc XFerVRAM16Nasty400
	lda.b Temp2
XFerVRAM16Nasty400:
	sta.b Temp3	; [TEMP3] = BlockSize
	sta.w DMA0NUML
	lda.b Temp	; [TEMP] = SourceData
	sta.w DMA0A1L
	ldy.w #xfsDest	; .L/.H Dest
	lda.b [XFerPtr],y
	clc
	adc.b Temp3+2
	sta.w VMADDL
	sep #$20		; mode 'a!'
	lda.b Temp+2	; [TEMP] = SourceData
	sta.w DMA0A1B
	lda.b #$80
	sta.w VMAINC
	lda.b #%00000001	; A->B, Abs., Auto Inc,2-Add-WriteLH
	sta.w DMA0INC
	lda.b #lo16(VMDATAL)	; VMDATA
	sta.w DMA0DEST
	lda.b #$01	; Enable/Start Channel#0
	sta.w MDMAEN
	rep #$20		; mode 'A!'
	lda.b Temp	; Move forward through data
	clc
	adc.b Temp3
	sta.b Temp
	lda.b Temp3	; Update VRAM Destination Pointer
	lsr a
	clc
	adc.b Temp3+2
	sta.b Temp3+2
	lda.b Temp2	; Less data remaining to transfer
	sec
	sbc.b Temp3
	sta.b Temp2
	bne XFerVRAM16Nasty200	; Not done yet
	rtl


;
;	* * * * * * *       XFER VRAM 16 ADJUST_DEST       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
XFerVRAMD16:
	if 0 != 0
	lda.b Temp2	; [TEMP2] = DataSize
	sta.w DMA0NUML
	lda.b Temp	; [TEMP] = SourceData
	sta.w DMA0A1L
	ldy.w #xfsData0	; Add Base Value Indirect
	lda.b [XFerPtr],y
	sta.b Temp3
	lda.b (Temp3)
	ldy.w #xfsDest	; .L/.H Dest
	clc
	adc.b [XFerPtr],y
	sta.w VMADDL
	sep #$20
	rep #$10		; mode 'aX!'
	lda.b Temp+2	; [TEMP] = SourceData
	sta.w DMA0A1B
	lda.b #$80
	sta.w VMAINC
	lda.b #%00000001	; A->B, Abs., Auto Inc,2-Add-WriteLH
	sta.w DMA0INC
	lda.b #lo16(VMDATAL)	; VMDATA
	sta.w DMA0DEST
	lda.b #$01	; Enable/Start Channel#0
	sta.w MDMAEN
	endif
	rtl


;
;	* * * * * * *       XFER CGRAM       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
XFerCGRAM:
	rtl		; (not implemented)


;
;	* * * * * * *       XFER VRAM FILL 8L       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
XFerVRAMF8L:
	if 0 != 0
	lda.b Temp2	; [TEMP2] = DataSize
	sta.w DMA0NUML
	lda.b Temp	; [TEMP] = SourceData
	sta.w DMA0A1L
	ldy.w #xfsDest	; .L/.H Dest
	lda.b [XFerPtr],y
	sta.w VMADDL
	sep #$20
	rep #$10		; mode 'aX!'
	lda.b Temp+2	; [TEMP] = SourceData
	sta.w DMA0A1B
	stz.w VMAINC
	lda.b #%00001000	; A->B, Abs., Fixed,1-Add
	sta.w DMA0INC
	lda.b #lo16(VMDATAL)	; VMDATA
	sta.w DMA0DEST
	lda.b #$01	; Enable/Start Channel#0
	sta.w MDMAEN
	endif
	rtl


;
;	* * * * * * *       XFER VRAM FILL 8H       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
XFerVRAMF8H:
	if 0 != 0
	lda.b Temp2	; [TEMP2] = DataSize
	sta.w DMA0NUML
	lda.b Temp	; [TEMP] = SourceData
	sta.w DMA0A1L
	ldy.w #xfsDest	; .L/.H Dest
	lda.b [XFerPtr],y
	sta.w VMADDL
	sep #$20
	rep #$10		; mode 'aX!'
	lda.b Temp+2	; [TEMP] = SourceData
	sta.w DMA0A1B
	lda.b #$80
	sta.w VMAINC
	lda.b #%00001000	; A->B, Abs., Fixed,1-Add
	sta.w DMA0INC
	lda.b #lo16(VMDATAH)	; VMDATA
	sta.w DMA0DEST
	lda.b #$01	; Enable/Start Channel#0
	sta.w MDMAEN
	endif
	rtl

;
;	* * * * * * *       XFER VRAM FILL 16       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
XFerVRAMF16:
	bit.w XFerNasty-1	; NASTY Transfer?
	bmi XFerVRAMF16Nasty	; Yes
	lda.b Temp2	; [TEMP2] = DataSize
	sta.w DMA0NUML
	lda.b Temp	; [TEMP] = SourceData
	sta.w DMA0A1L
	ldy.w #xfsDest	; .L/.H Dest
	lda.b [XFerPtr],y
	sta.w VMADDL
	sep #$20
	rep #$10		; mode 'aX!'
	lda.b Temp+2	; [TEMP] = SourceData
	sta.w DMA0A1B
	lda.b #$80
	sta.w VMAINC
	lda.b #%00001001	; A->B, Abs., Fixed,2-Add-WriteLH
	sta.w DMA0INC
	lda.b #lo16(VMDATAL)	; VMDATA
	sta.w DMA0DEST
	lda.b #$01	; Enable/Start Channel#0
	sta.w MDMAEN
	rtl
;
	; mode 'AX'
XFerVRAMF16Nasty:
	stz.b Temp3+2	; [TEMP3+2] = #Words transferred so far
XFerVRAMF16Nasty200:
	jsl.l WaitVBlank	; Wait until IN VBlank
	lda.w #xferNastyMax
	cmp.b Temp2	; [TEMP2] = DataSize
	bcc XFerVRAMF16Nasty400
	lda.b Temp2
XFerVRAMF16Nasty400:
	sta.b Temp3	; [TEMP3] = BlockSize
	sta.w DMA0NUML
	lda.b Temp	; [TEMP] = SourceData
	sta.w DMA0A1L
	ldy.w #xfsDest	; .L/.H Dest
	lda.b [XFerPtr],y
	clc
	adc.b Temp3+2
	sta.w VMADDL
	sep #$20		; mode 'a!'
	lda.b Temp+2	; [TEMP] = SourceData
	sta.w DMA0A1B
	lda.b #$80
	sta.w VMAINC
	lda.b #%00001001	; A->B, Abs., Fixed,2-Add-WriteLH
	sta.w DMA0INC
	lda.b #lo16(VMDATAL)	; VMDATA
	sta.w DMA0DEST
	lda.b #$01	; Enable/Start Channel#0
	sta.w MDMAEN
	rep #$20		; mode 'A!'
	lda.b Temp	; Move forward through data
	clc		; (NOTE: wrong for a fixed-source fill; no caller
	adc.b Temp3	; fills more than xferNastyMax while NASTY)
	sta.b Temp
	lda.b Temp3	; Update VRAM Destination Pointer
	lsr a
	clc
	adc.b Temp3+2
	sta.b Temp3+2
	lda.b Temp2	; Less data remaining to transfer
	sec
	sbc.b Temp3
	sta.b Temp2
	bne XFerVRAMF16Nasty200	; Not done yet
	rtl
