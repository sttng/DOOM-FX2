includeonce
;**********************************************************************
;*                                                                    *
;*              S U P E R   N I N T E N D O   S Y S T E M             *
;*                                                                    *
;*                   HARDWARE EQUATES/DEFINITIONS FILE                *
;*                                                                    *
;*                        Written by Randy Linden                     *
;*                                                                    *
;**********************************************************************


;
;	* * * * * * *       SUPER NINTENDO ENTERTAINMENT SYSTEM EQUATES       * * * * * * *
;

	if NOAICESE == 0
	endif



;
;	PPU EQUATES
;
	INIDISP = $2100
	OBJSEL = $2101
	OAMADDL = $2102
	OAMADDH = $2103
	OAMDATA = $2104
	BGMODE = $2105
	MOSAIC = $2106
	BG1SC = $2107
	BG2SC = $2108
	BG3SC = $2109
	BG4SC = $210A
	BG12NBA = $210B
	BG34NBA = $210C
	BG1HOFS = $210D
	BG1VOFS = $210E
	BG2HOFS = $210F
	BG2VOFS = $2110
	BG3HOFS = $2111
	BG3VOFS = $2112
	BG4HOFS = $2113
	BG4VOFS = $2114
	VMAINC = $2115
	VMADDL = $2116
	VMADDH = $2117
	VMDATAL = $2118
	VMDATAH = $2119
	M7SEL = $211A
	M7A = $211B
	M7B = $211C
	M7C = $211D
	M7D = $211E
	M7X = $211F
	M7Y = $2120
	CGADD = $2121
	CGDATA = $2122
	W12SEL = $2123
	W34SEL = $2124
	WOBJSEL = $2125
	WH0 = $2126
	WH1 = $2127
	WH2 = $2128
	WH3 = $2129
	WBGLOG = $212A
	WOBJLOG = $212B
	TM = $212C
	TS = $212D
	TMW = $212E
	TSW = $212F
	CGSWSEL = $2130
	CGADSUB = $2131
	COLDATA = $2132
	SETINI = $2133
	_MPYL = $2134
	_MPYM = $2135
	_MPYH = $2136
	_SLHV = $2137
	_OAMDATA = $2138
	_VMDATAL = $2139
	_VMDATAH = $213A
	_CGDATA = $213B
	_OPHCT = $213C
	_OPVCT = $213D
	_STAT77 = $213E
	_STAT78 = $213F
	APUIO0 = $2140
	APUIO1 = $2141
	APUIO2 = $2142
	APUIO3 = $2143
	WMDATA = $2180
	WMADDL = $2181
	WMADDH = $2182
	WMADDB = $2183

;
;	CPU EQUATES
;
	NMITIMEN = $4200
	WRIO = $4201
	WRMPYA = $4202
	WRMPYB = $4203
	WRDIVL = $4204
	WRDIVH = $4205
	WRDIVB = $4206
	HTIMEL = $4207
	HTIMEH = $4208
	VTIMEL = $4209
	VTIMEH = $420A
	MDMAEN = $420B
	HDMAEN = $420C
	MEMSEL = $420D
	_RDNMI = $4210
	_TIMEUP = $4211
	_HVBJOY = $4212
	_RDIO = $4213
	_RDDIVL = $4214
	_RDDIVH = $4215
	_RDMPYL = $4216
	_RDMPYH = $4217
	JOY1L = $4218
	JOY1H = $4219
	JOY2L = $421A
	JOY2H = $421B
	JOY3L = $421C
	JOY3H = $421D
	JOY4L = $421E
	JOY4H = $421F

;
;	DMA EQUATES
;
	DMA0INC = $4300
	DMA0DEST = $4301
	DMA0A1L = $4302
	DMA0A1H = $4303
	DMA0A1B = $4304
	DMA0NUML = $4305
	DMA0NUMH = $4306
	DMA0ADDL = $4305
	DMA0ADDH = $4306
	DMA0BANK = $4307
	DMA0A2L = $4308
	DMA0A2H = $4309
	DMA0LINE = $430A
;
	DMA1INC = $4310
	DMA1DEST = $4311
	DMA1A1L = $4312
	DMA1A1H = $4313
	DMA1A1B = $4314
	DMA1NUML = $4315
	DMA1NUMH = $4316
	DMA1ADDL = $4315
	DMA1ADDH = $4316
	DMA1BANK = $4317
	DMA1A2L = $4318
	DMA1A2H = $4319
	DMA1LINE = $431A
;
	DMA2INC = $4320
	DMA2DEST = $4321
	DMA2A1L = $4322
	DMA2A1H = $4323
	DMA2A1B = $4324
	DMA2NUML = $4325
	DMA2NUMH = $4326
	DMA2ADDL = $4325
	DMA2ADDH = $4326
	DMA2BANK = $4327
	DMA2A2L = $4328
	DMA2A2H = $4329
	DMA2LINE = $432A
;
	DMA3INC = $4330
	DMA3DEST = $4331
	DMA3A1L = $4332
	DMA3A1H = $4333
	DMA3A1B = $4334
	DMA3NUML = $4335
	DMA3NUMH = $4336
	DMA3ADDL = $4335
	DMA3ADDH = $4336
	DMA3BANK = $4337
	DMA3A2L = $4338
	DMA3A2H = $4339
	DMA3LINE = $433A
;
	DMA4INC = $4340
	DMA4DEST = $4341
	DMA4A1L = $4342
	DMA4A1H = $4343
	DMA4A1B = $4344
	DMA4NUML = $4345
	DMA4NUMH = $4346
	DMA4ADDL = $4345
	DMA4ADDH = $4346
	DMA4BANK = $4347
	DMA4A2L = $4348
	DMA4A2H = $4349
	DMA4LINE = $434A
;
	DMA5INC = $4350
	DMA5DEST = $4351
	DMA5A1L = $4352
	DMA5A1H = $4353
	DMA5A1B = $4354
	DMA5NUML = $4355
	DMA5NUMH = $4356
	DMA5ADDL = $4355
	DMA5ADDH = $4356
	DMA5BANK = $4357
	DMA5A2L = $4358
	DMA5A2H = $4359
	DMA5LINE = $435A
;
	DMA6INC = $4360
	DMA6DEST = $4361
	DMA6A1L = $4362
	DMA6A1H = $4363
	DMA6A1B = $4364
	DMA6NUML = $4365
	DMA6NUMH = $4366
	DMA6ADDL = $4365
	DMA6ADDH = $4366
	DMA6BANK = $4367
	DMA6A2L = $4368
	DMA6A2H = $4369
	DMA6LINE = $436A
;
	DMA7INC = $4370
	DMA7DEST = $4371
	DMA7A1L = $4372
	DMA7A1H = $4373
	DMA7A1B = $4374
	DMA7NUML = $4375
	DMA7NUMH = $4376
	DMA7ADDL = $4375
	DMA7ADDH = $4376
	DMA7BANK = $4377
	DMA7A2L = $4378
	DMA7A2H = $4379
	DMA7LINE = $437A

;
;	* * * * * * *       GENERAL EQUATES       * * * * * * *
;
	MaxViewScanLines = 224	; 224 ScanLines Maximum
	MaxOAMs = 128	; MaxObjectAttributeMemories
	MaxCHRs = 512	; MaxSpriteCharacters

;
;	* * * * * * *       OAM STRUCTURE       * * * * * * *
;
	oamsX = 0	; X Coordinate
	oamsY = 1	; Y Coordinate
	oamsChr = 2	; Character# (Name)
	oamsFlags = 3	; Flags
;
;	>>>   OAM FLAGS   <<<
;
	oamfVFlip = $80	; VFlip
	oamfHFlip = $40	; HFlip
	oamfPri = $30	; Priority $00,$10,$20,$30
	oamfPri0 = $00	; Priority 0
	oamfPri1 = $10	; Priority 1
	oamfPri2 = $20	; Priority 2
	oamfPri3 = $30	; Priority 3
	oamfColour = $0E	; Colour (%000-%111)
	oamfChrH = $01	; Character# HighBit (Name)

;
;	* * * * * * *       JOYSTICK CONTROLLER EQUATES       * * * * * * *
;
	joyR = %0000000000010000	; <R>
	joyL = %0000000000100000	; <L>
	joyX = %0000000001000000	; <X>
	joyA = %0000000010000000	; <A>
	joyRIGHT = %0000000100000000	; <RIGHT>
	joyLEFT = %0000001000000000	; <LEFT>
	joyDOWN = %0000010000000000	; <DOWN>
	joyUP = %0000100000000000	; <UP>
	joySTART = %0001000000000000	; <START>
	joySELECT = %0010000000000000	; <SELECT>
	joyY = %0100000000000000	; <Y>
	joyB = %1000000000000000	; <B>


;
;	* * * * * * *       SUPER F/X (GSU) EQUATES       * * * * * * *
;
	sfxR0 = $3000
	sfxR1 = $3002
	sfxR2 = $3004
	sfxR3 = $3006
	sfxR4 = $3008
	sfxR5 = $300A
	sfxR6 = $300C
	sfxR7 = $300E
	sfxR8 = $3010
	sfxR9 = $3012
	sfxR10 = $3014
	sfxR11 = $3016
	sfxR12 = $3018
	sfxR13 = $301A
	sfxR14 = $301C
	sfxR15 = $301E
	sfxSFR = $3030
	sfxPCB = $3034
	sfxSCR = $303A
	sfxCONFIG = $3037
	sfxSCBR = $3038
	sfxCLK = $3039
	GSUBRKRAM = $000100	; SNES BRK RAM Vector for GSU
	GSUCOPRAM = $000104	; SNES COP RAM Vector for GSU
	GSUABORTRAM = $000100	; SNES ABORT RAM Vector for GSU
	GSUNMIRAM = $000108	; SNES NMI RAM Vector for GSU
	GSUIRQRAM = $00010C	; SNES IRQ RAM Vector for GSU

;
;	* * * * * * *       DEBUGGER SHADOWS       * * * * * * *
;
	if SFX2 != 0
	NMITIMEN_XS = $40FF40	; SNES NMITIMEN Register Shadow
	SCR_XS = $40FF43	; SFX SCR Register Shadow
	endif
	if WIRE != 0
	NMITIMEN_XS = $7FFF40	; SNES NMITIMEN Register Shadow
	SCR_XS = $7FFF43	; SFX SCR Register Shadow
;NMI_XS		equ	$7fffc0			; SNES NMI RAM Vector for XSLV
;IRQ_XS		equ	$7fffc4			; SNES IRQ RAM Vector for XSLV
	endif
	if NOAICESE != 0
;SCR_XS		equ	$003943			; SFX SCR Register Shadow
	SCR_XS = $7FFF43	; SFX SCR Register Shadow
	endif
