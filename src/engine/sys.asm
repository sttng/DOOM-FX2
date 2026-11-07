	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                  SYSTEM O/S AND DIAGNOSTICS MODULE                 *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/xfer.inc"

	; public InitSystem


	%section(SYS)
;
;	* * * * * * *       INITIALIZE SYSTEM       * * * * * * *
;
	; dpr 0
	; dbr ?
	; mode '@A@X'
InitSystem:
	jsl.l InitNormalIRQ	; Initialize IRQ Code
	jsl.l InitNormalNMI	; Initialize NMI Code
	jsl.l InitSNES	; Initialize SuperNES
;	mode	'a'
	stz.w XFerNasty	; Transfers are NOT NASTY
	if useXBAND != 0
	jml.l InitXBAND	; Initialize XBAND Hardware
	endif
	if useXBAND == 0
	rtl
	endif


;
;	* * * * * * *       SYSTEM TEXT       * * * * * * *
;
;	.X/.A	= pointer to SysTextStructure
;
;	dw	VRAMPointer (or -1 for End)
;	dl	ADDRESS of Text
;	db	Size of Text
;
	; dbr ?
	; dpr 0
	; mode 'aX'
SystemText:
	stx.b Temp	; Save pointer to SysTextStruct
	sta.b Temp+2
	lda.b #$80
	sta.w VMAINC
STT200:
	rep #$20		; mode 'A!'
	ldy.w #0
	lda.b [Temp],y	; VRAM PTR
	bmi STT900	; No, done!
	sta.w VMADDL
	iny
	iny
	lda.b [Temp],y
	sta.b Temp2
	iny
	iny
	lda.b [Temp],y
	sta.b Temp2+2
	xba
	and.w #$00FF	; .X = Length
	tax
	lda.b Temp	; Bump SysTextPtr
	clc
	adc.w #6
	sta.b Temp
	sep #$20		; mode 'a!'
	ldy.w #0
STT300:
	lda.b [Temp2],y	; Get next character
	sta.w VMDATAL	; Send to VRAM
	lda.b #$3C
	sta.w VMDATAH
	iny
	dex
	bne STT300
	bra STT200	; Handle next text piece
STT900:
	rtl


	if useSYSINFO != 0
;
;	* * * * * * *       SYSTEM INFORMATION       * * * * * * *
;
	; dpr 0
	; dbr ?
DebugWarnInfo:
	sep #$20
	rep #$10		; mode 'aX!'
	ldx.w #lo16(DebugWarnInfoSText)	; Show DebugWarn Text
	lda.b #bank(DebugWarnInfoSText)
	ldy.w #%000000000011111
	jmp.w SystemInfo2
SystemInfo:
	sep #$20
	rep #$10		; mode 'aX!'
	ldx.w #lo16(SysInfoSText)	; Show System Text
	lda.b #bank(SysInfoSText)
	ldy.w #%000000000000000
SystemInfo2:
	phx
	pha
	phy
;
	jsl.l ScreenOff	; Turn Screen Off
	jsl.l InitNormalNMI
;
	sep #$20
	rep #$10		; mode 'aX!'
	ldx.w #lo16(SysInfoXFer)	; Transfer SysInfo DataBlock
	lda.b #bank(SysInfoXFer)
	jsl.l XFer
;
	; mode 'AX'
	ldx.w #%001110011100111
	ldy.w #%111111111111111
	pla	; System Info/Debug Warn?
	beq SIO100	; System Info
	ldx.w #%000000000011111
	ldy.w #%000000000000000
SIO100:
	sta.w RGBData+(0*2)
	stx.w RGBData+(7*16*2)+(7*2)
	sty.w RGBData+(7*16*2)+(11*2)
;
	sep #$20		; mode 'a!'
	lda.b #$80	; Transfer RGB Palette to CGRAM
	sta.w RGBXFer
	lda.b #1	; Mode1 BG1:8x8
	sta.w BGMODE
	lda.b #$20	; BG1 Screen at $2000
	sta.w BG1SC
	lda.b #$FF	; Offset $FFFF
	sta.w BG1VOFS
	sta.w BG1VOFS
	stz.w BG1HOFS	; Offset $0000
	stz.w BG1HOFS
	stz.w BG12NBA	; BG1 @$0000
	stz.w MOSAIC
;
	lda.b #%00001000	; PseudoH512, 224Lines
	sta.w SETINI
	lda.b #%00000010	; Colour Add Enable
	sta.w CGSWSEL
	lda.b #%01000001	; Add 1/2 Enable BG1
	sta.w CGADSUB
	ldx.w #$0101	; BG1 Only
	stx.w TM
;
	pla	; Pointer to SystemText
	plx
	jsl.l SystemText
;
	jsl.l ScreenOn
;
	rep #$30		; mode 'AX!'
SIO200:
	lda.w JOY1L	; Joystick pressed?
	bne SIO200	; Yes, wait until released
	ldx.w #(60*2)-1
SIO300:
	lda.w JOY1L	; Joystick pressed?
	bne SIO400	; Yes, exit now
	wai
	dex
	bpl SIO300
	lda.w RGBData	; Debug Warning?
	bne SIO300	; Yes, Don't Time Out!
SIO400:
	lda.w JOY1L	; Wait until released
	bne SIO400
	jml.l ScreenOff


;
;	* * * * * * *       TRANSFER LIST       * * * * * * *
;
	; mode '@A@X'
SysInfoXFer:
	dw xftVRAMF16+xftRAW	; Fill $0000W-$2FFFW with $00
	dd SysInfoXferA
	dd $0000
	dw ($3000*2)
SysInfoXferA:
	dw 0,0
;
	dw xftVRAM16	; Transfer SysFontDef to $0200W
	dd SysFontDef
	dd $0200
	dw 0,0,0
;
	dw xftEND


;
;	* * * * * * *       SYSTEM TEXTS       * * * * * * *
;
SysInfoSText:
	dw ($2000+(3*32)+((32-SI0TxtL)/2))
	dl SI0Txt
	db SI0TxtL

	dw ($2000+(7*32)+((32-CFGTxtL)/2))
	dl TtlTxt
	db TtlTxtL

	dw ($2000+(9*32)+((32-CFGTxtL)/2))
	dl VerTxt
	db VerTxtL

	dw ($2000+(11*32)+((32-CFGTxtL)/2))
	dl CPUTxt
	db CPUTxtL

	dw ($2000+(12*32)+((32-CFGTxtL)/2))
	dl CPUTxt2
	db CPUTxt2L

	dw ($2000+(14*32)+((32-CFGTxtL)/2))
	dl CFGTxt
	db CFGTxtL

	dw ($2000+(15*32)+((32-CFGTxtL)/2))
	dl CFHTxt
	db CFHTxtL

	dw ($2000+(17*32)+((32-CFGTxtL)/2))
	dl PRGTxt
	db PRGTxtL

	dw ($2000+(19*32)+((32-CFGTxtL)/2))
	dl RAMTxt
	db RAMTxtL

	dw ($2000+(23*32)+((32-DATTxtL)/2))
	dl DATTxt
	db DATTxtL

;	dc.w	($2000+(25*32)+((32-CP0TxtL)/2))
;	dc.l	CP0Txt
;	dc.b	CP0TxtL

;	dc.w	($2000+(26*32)+((32-CP1TxtL)/2))
;	dc.l	CP1Txt
;	dc.b	CP1TxtL

	dw -1

SI0Txt:
	db "System Information"
	SI0TxtL = pc()-SI0Txt
CP0Txt:
	db 127,"1994/5 Entertainment Dynamics"
	CP0TxtL = pc()-CP0Txt
CP1Txt:
	db "All Rights Reserved."
	CP1TxtL = pc()-CP1Txt

;
;	* * * * * * *       DEBUG WARNING TEXTS       * * * * * * *
;
DebugWarnInfoSText:
	dw ($2000+(7*32)+((32-DWI0TxtL)/2))
	dl DWI0Txt
	db DWI0TxtL

	dw ($2000+(10*32)+((32-DWI1TxtL)/2))
	dl DWI1Txt
	db DWI1TxtL

	dw ($2000+(11*32)+((32-DWI1TxtL)/2))
	dl DWI2Txt
	db DWI2TxtL

	dw ($2000+(14*32)+((32-DWI3TxtL)/2))
	dl DWI3Txt
	db DWI3TxtL

	dw -1

DWI0Txt:
	db "* * *  W A R N I N G  * * *"
	DWI0TxtL = pc()-DWI0Txt
DWI1Txt:
	db "This version for Sculptured"
	DWI1TxtL = pc()-DWI1Txt
DWI2Txt:
	db "Internal Test/Debug ONLY!"
	DWI2TxtL = pc()-DWI2Txt
DWI3Txt:
	db "DO NOT DISTRIBUTE!"
	DWI3TxtL = pc()-DWI3Txt
	endif


;
;	* * * * * * *       SYSTEM FONT DATA       * * * * * * *
;
	%section(TEXTFONT_DATA)
RLDebugFontDef:
SysFontDef:
TextFontDef:
	incbin "data/RLDATA/COMP/TextFont.def0"
