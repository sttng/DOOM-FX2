	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                           TITLE PAGE MODULE                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rl.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/xfer.inc"
	incsrc "src/include/music.inc"
	incsrc "src/include/savegame.inc"
	incsrc "data/RLDATA/COMP/titlemenu.inc"	; (tools/titlemenus.py)

	if useTITLE != 0

	; public Title


	%section(TITLE)
;
;	* * * * * * *       TITLE PAGE       * * * * * * *
;
	; dpr 0
	; dbr ?
Title:
	jsl.l ScreenOff	; Turn Screen Off
	jsl.l InitSNES
	; mode 'ax'
;
	rep #$10		; mode 'X!'
	ldx.w #lo16(TitleXFer)	; Transfer Title DataBlock
	lda.b #bank(TitleXFer)
	jsl.l XFer
	; mode 'AX'
;
	if useSOUND != 0
	lda.w #((intro_sng_MODULE<<8)|intro_sng)	; INTRO Song
	jsl.l _PlaySong
	endif
;
	if usePAL == 0
	; mode 'AX'
	inc.w _TitleCount	; Title Count++
	jsl.l CheckSumVars
	endif
;
	stz.w TitleLevel	; (this port) no title menu choice yet: E1M1
	stz.w TitleLoad
;
	jsl.l InitNormalNMI
	sep #$30		; mode 'ax!'
	lda.b #$80	; Transfer RGB Palette to CGRAM
	sta.w RGBXFer
	lda.b #1	; Mode1 BG1:8x8
	sta.w BGMODE
	lda.b #$42	; BG1 Screen at $4000, 32x64 (this port: lower half blank, for the melt)
	sta.w BG1SC
	lda.b #$73	; BG2 Screen at $7000, 64x64 (this port: SC2/SC3 blank, for the melt)
	sta.w BG2SC
	lda.b #$48	; (this port) BG3 Screen at $4800: Mode 2's offset-per-tile table (melt)
	sta.w BG3SC
	lda.b #$FF	; Offset $FFFF
	sta.w BG1VOFS
	sta.w BG1VOFS
	stz.w BG1HOFS	; Offset $0000
	stz.w BG1HOFS
	stz.w MOSAIC
	lda.b #$02	; (this port) OBJ Chars @$4000 (title menu skull: $5F00)
	sta.w OBJSEL
	jsr.w TTLRegs	; BG2, colour maths, layers
;
	rep #$10		; mode 'X!'
	ldx.w #lo16(TitleSText)	; Show Title Text
	lda.w _TitleCount	; Every 4th Title
	and.b #$03
	bne TTL150
	ldx.w #lo16(CreditsSText)	; Show Credits Text
TTL150:
	lda.b #bank(CreditsSText)
	jsl.l SystemText
;
	jsl.l ScreenOn
;
	rep #$30		; mode 'AX!'
	if useDEMO != 0
	stz.w DemoIndex	; NOT Using Demo
	endif
TTL200:
	lda.w PlayerJoy	; Joystick pressed?
	bne TTL200	; Yes, wait until released
	ldx.w #(60*6)-1
	if usePAL != 0
	lda.w _TitleCount
	and.w #$03
	bne TTL300
	ldx.w #(60*10)-1
	endif
TTL300:
	if usePAL != 0
	lda.w _TitleCount
	and.w #$03
	beq TTL320
	endif
	lda.w PlayerJoy	; Wait until pressed
	bne TTL400
TTL320:
	wai
	dex
	bpl TTL300
	if useDEMO != 0
	inc.w DemoIndex	; Use Demo!
	lda.w #1
	sta.l DemoCount
	endif
TTL400:
	stx.w MeltRnd	; (this port) the melt's random seed: when the title was left
	cpx.w #$FFFF	; (this port) a button: the title menus (as on the FX3
	beq TTL410	;  cartridge); the time out: the attract mode
	jsr.w TTLMenus
	rep #$30		; mode 'AX!'
	bcc TTL410	; New Game / Load Game chosen
	jmp.w TTL200	; Back to the plain title
TTL410:
;	lda	PlayerJoy			; Joystick pressed?
;	bne	TTL400				; Yes, wait until released

;
;	>>>   FADE MUSIC OUT   <<<
;
	if useSOUND != 0
	lda.w #DCOM_FADE_AND_STOP	; Fade out Music
	ldy.w #$0201
	jsl.l __SendDriverCommand
	endif

;
;	>>>   MELT SCREEN TO BLACK   <<<
;
;	(this port; original: a 15 step fade) The screen melt of the FX3 cartridge
;	and PC DOOM: the title switches to Mode 2, whose offset-per-tile table (the
;	BG3 map) gives each 8 pixel column its own vertical scroll (BG1 and BG2);
;	the maps' lower halves are blank.  The leftmost column uses BG1/BG2VOFS.
;
	MeltMaxDelay = 19	; Frames
TTL2000:
	rep #$30		; mode 'AX!'
	jsr TTLMeltRand	; Column delays: a random walk, 0..19 frames
	and.w #$000F
	sta.b Temp	; Shortest delay
	ldy.w #0
TTL2010:
	sta.w MeltY,y
	cmp.b Temp
	bcs TTL2015
	sta.b Temp
TTL2015:
	pha
	lda.w #$63FF	; VOFS -1 (unmoved), BG1+BG2
	sta.w MeltV,y
	jsr TTLMeltRand
	and.w #$0007
	asl a
	tax
	pla
	clc
	adc.l TTLMeltStep,x
	bpl TTL2020	; < 0: 0
	lda.w #0
	bra TTL2030
TTL2020:
	cmp.w #MeltMaxDelay+1	; > Max: Max
	bcc TTL2030
	lda.w #MeltMaxDelay
TTL2030:
	iny
	iny
	cpy.w #(33*2)
	bcc TTL2010
	ldy.w #0	; y = -(delay - shortest delay)
TTL2040:
	lda.b Temp
	sec
	sbc.w MeltY,y
	sta.w MeltY,y
	iny
	iny
	cpy.w #(33*2)
	bcc TTL2040
;
TTL2100:
	wai		; VBlank: offset-per-tile table to VRAM
	sep #$20		; mode 'a!'
	lda.b #$80	; Increment after $2119
	sta.w VMAINC
	ldx.w #$4800+32	; BG3 map row 1: the vertical offsets
	stx.w VMADDL
	ldx.w #$1801	; A->B, 1-Add-Write2x, VMDATAL
	stx.w DMA1INC
	ldx.w #lo16(MeltV+2)	; Columns 1..32
	stx.w DMA1A1L
	stz.w DMA1A1B
	ldx.w #(32*2)
	stx.w DMA1NUML
	lda.b #%00000010	; Start Channel#1
	sta.w MDMAEN
	lda.w MeltV+0	; Column 0: the BGs' own scroll
	sta.w BG1VOFS
	lda.w MeltV+1
	sta.w BG1VOFS
	lda.w MeltV+0
	sta.w BG2VOFS
	lda.w MeltV+1
	sta.w BG2VOFS
	lda.b #2	; Mode2 BG1/BG2:8x8, offset-per-tile
	sta.w BGMODE
;
	rep #$30		; mode 'AX!'
	ldx.w #0	; #Columns not gone yet
	ldy.w #0
TTL2110:
	lda.w MeltY,y
	cmp.w #224	; Gone?
	beq TTL2160
	inx
	cmp.w #$8000	; Still waiting?
	bcc TTL2120
	inc a
	bra TTL2140
TTL2120:
	cmp.w #4	; Accelerate: y+y+1
	bcs TTL2130
	asl a
	inc a
	bra TTL2140
TTL2130:
	adc.w #4-1	; Then 4 lines per frame (carry set)
	cmp.w #224
	bcc TTL2140
	lda.w #224
TTL2140:
	sta.w MeltY,y
	cmp.w #$8000	; Waiting: VOFS -1
	bcc TTL2150
	lda.w #0
TTL2150:
	eor.w #$FFFF	; VOFS = -1-y
	and.w #$03FF
	ora.w #$6000	; Entry applies to BG1+BG2
	sta.w MeltV,y
TTL2160:
	iny
	iny
	cpy.w #(33*2)
	bcc TTL2110
	txa		; Columns still moving?
	beq TTL2170
	jmp TTL2100
TTL2170:
	jml.l ScreenOff

;
;	>>>   TITLE REGISTERS (BG2, COLOUR MATHS, LAYERS)   <<<
;
;	(this port: the title's set-up, also used when the title menus close)
;
TTLRegs:
	php
	sep #$30		; mode 'ax!'
	lda.b #$FF	; BG2 Offset $FFFF/$0000
	sta.w BG2VOFS
	sta.w BG2VOFS
	stz.w BG2HOFS
	stz.w BG2HOFS
	lda.b #((($6000>>12)<<4)|($0000>>12))	; BG1 Chars @$0000, BG2 Chars @$6000
	sta.w BG12NBA
	lda.b #%00001000	; PseudoH512, 224Lines
	sta.w SETINI
	lda.b #%01000001	; Add 1/2 Enable BG1
	sta.w CGADSUB
;
	ldx.b #%00000010	; Colour Add Enable SUB
	ldy.b #$03	; BG1+BG2
;	ldy	#$01				; BG1
	lda.w _TitleCount	; Every 4th Title
	and.b #$03
	bne TTL100
	ldx.b #%10000000	; Colour Sub Enable FIXED
	lda.b #%11000001	; Sub 1/2 Enable BG1
	sta.w CGADSUB
	ldy.b #$03	; BG1+BG2
	lda.w _TitleCount	; Every 8th Title
	and.b #$04
	bne TTL100
	stz.w BG2HOFS	; Offset $0100
	lda.b #1
	sta.w BG2HOFS
TTL80:
	lda.b #$2C
	sta.w COLDATA
	lda.b #$C7
	sta.w COLDATA
TTL100:
	stx.w CGSWSEL
	sty.w TM
	sty.w TS
	plp
	rts

;
;	* * * * * * *       TITLE MENUS       * * * * * * *
;
;	(this port, as on the FX3 cartridge) A button on the title opens a menu over
;	the darkened title picture: New Game / Load Game (the cartridge: Enter Code).
;	New Game: the skill menu, then (DOOM sets) the episode menu; Load Game: the
;	pause menu's slot menu.  The menu is BG2 (characters at $4000 while shown,
;	tools/titlemenus.py; each menu's tiles are loaded when it is shown), the
;	skull four sprites (rlmenus.asm), the title picture halved by colour maths.
;	Returns .C = 0: a game chosen (TitleLevel, or TitleLoad after LoadGame),
;	.C = 1: B on the first menu, back to the plain title.
;
	!__tmep #= !NUMLEVELS/9	; the episode menu's items (0: none, DOOM II sets)
	if defined("RLEPISODELEN")
	if !RLEPISODELEN == 99
	!__tmep #= 0
	endif
	endif
	if !__tmep != 0
	if defined("RLEPISODES")
	if not(defined("RLORDERSCREEN"))	; (the shareware set lists every episode; one it
	!__tmep #= !RLEPISODES	;  does not have shows the order screen, rage.asm)
	endif
	endif
	endif
	TMI_MAP = 0	; TTLMenuData: map (24 bit)
	TMI_DEF = 3	; tiles (24 bit; menu 0: loaded with the title)
	TMI_CUR = 6	; skull positions (this bank)
	TMI_N = 8	; #items
	TMI_HOFS = 10	; BG2 HOFS/VOFS
	TMI_VOFS = 12
	TMI_SIZE = 14

	; mode 'AX'
TTLMenus:
	rep #$30		; mode 'AX!'
	jsr.w TTLMenuRelease	; Buttons released
	jsr.w TTLMenuOpen	; Darken, menu colours, sprites
	stz.w TMenuItem	; New Game
	lda.w #0	; TITLE MENU
	jsr.w TTLMenuShow
;
TTLM100:
	rep #$30		; mode 'AX!'
	wai
	jsr.w TTLMenuSkull	; (VBlank) the skull
	rep #$30		; mode 'AX!'
	lda.w JOY1	; Buttons newly pressed?
	tax
	eor.w TMenuJoy
	stx.w TMenuJoy
	and.w TMenuJoy
	beq TTLM100
	bit.w #joyUP	; UP
	beq TTLM210
	lda.w TMenuItem
	dec a
	bpl TTLM200
	lda.w TMenuMax
	dec a
TTLM200:
	sta.w TMenuItem
	bra TTLM100
TTLM210:
	bit.w #joyDOWN	; DOWN
	beq TTLM230
	lda.w TMenuItem
	inc a
	cmp.w TMenuMax
	bcc TTLM220
	lda.w #0
TTLM220:
	sta.w TMenuItem
	bra TTLM100
TTLM230:
	bit.w #(joyA|joySTART)	; ACCEPT
	beq TTLM240
	lda.w TMenuNum
	asl a
	tax
	jmp.w (TTLMAccept,x)
TTLM240:
	bit.w #joyB	; BACK
	beq TTLM100
	lda.w TMenuNum
	asl a
	tax
	jmp.w (TTLMBack,x)

TTLMAccept:
	dw TTLMA0,TTLMA1,TTLMA2,TTLMA3
TTLMBack:
	dw TTLMB0,TTLMB1,TTLMB2,TTLMB3
;
;	>>>   TITLE MENU: NEW GAME / LOAD GAME   <<<
;
TTLMA0:
	lda.w TMenuItem
	bne TTLMA05
	lda.w _SkillLevel	; NEW GAME: the skill menu
	sta.w TMenuItem
	lda.w #1
	jsr.w TTLMenuShow
	jmp.w TTLM100
TTLMA05:
	stz.w TMenuItem	; LOAD GAME: the slot menu
	lda.w #3
	jsr.w TTLMenuShow
	jmp.w TTLM100
TTLMB0:
	jsr.w TTLMenuClose	; Back to the plain title
	jsr.w TTLMenuRelease
	sec
	rts
;
;	>>>   SKILL MENU   <<<
;
TTLMA1:
	lda.w TMenuItem	; The skill
	sta.w _SkillLevel
	phb
	jsl.l CheckSumVars
	plb
	rep #$30		; mode 'AX!'
	if !__tmep != 0
	stz.w TMenuItem	; The episode menu
	lda.w #2
	jsr.w TTLMenuShow
	jmp.w TTLM100
	else
	stz.w TitleLevel	; (DOOM II sets: MAP01)
	jmp.w TTLMExit
	endif
TTLMB1:
	stz.w TMenuItem	; Back: the title menu, New Game
	lda.w #0
	jsr.w TTLMenuShow
	jmp.w TTLM100
;
;	>>>   EPISODE MENU   <<<
;
TTLMA2:
	lda.w TMenuItem	; Episode*9
	asl a
	asl a
	asl a
	clc
	adc.w TMenuItem
	sta.w TitleLevel
	jmp.w TTLMExit
TTLMB2:
	lda.w _SkillLevel	; Back: the skill menu
	sta.w TMenuItem
	lda.w #1
	jsr.w TTLMenuShow
	jmp.w TTLM100
;
;	>>>   LOAD GAME: THE SLOT MENU   <<<
;
TTLMA3:
	lda.w TMenuItem	; Slot: level, inventory and skill (savegame.asm)
	phb
	jsl.l LoadGame
	plb
	rep #$30		; mode 'AX!'
	bcc TTLMA35
	jmp.w TTLM100	; Empty/damaged slot: stay in the menu
TTLMA35:
	lda.w #1
	sta.w TitleLoad
	phb
	jsl.l CheckSumVars
	plb
	rep #$30		; mode 'AX!'
	jmp.w TTLMExit
TTLMB3:
	lda.w #1	; Back: the title menu, Load Game
	sta.w TMenuItem
	lda.w #0
	jsr.w TTLMenuShow
	jmp.w TTLM100
;
TTLMExit:
	jsr.w TTLMenuClose
	clc
	rts

;
;	>>>   WAIT UNTIL NO BUTTON IS PRESSED   <<<
;
	; mode 'AX'
TTLMenuRelease:
	wai
	lda.w JOY1
	bne TTLMenuRelease
	stz.w TMenuJoy
	rts

;
;	>>>   OPEN: DARKEN THE TITLE, MENU COLOURS, SPRITES OFF   <<<
;
	; mode 'AX'
TTLMenuOpen:
	ldx.w #(16-1)*2	; BG palette 7: the pause menu's palette 2 (the
TTLMO100:	;  in-game palette) with the title menu reds
	lda.l _RLRGBs+(32*2),x	;  as colours 13 and 15; OBJ palette 0: the
	sta.w RGBData+(112*2),x	;  in-game one (menu skull)
	lda.l _RLRGBs+(128*2),x
	sta.w RGBData+(128*2),x
	dex
	dex
	bpl TTLMO100
	lda.w #$001F	; 255,0,0
	sta.w RGBData+(125*2)
	lda.w #$1093	; 156,33,33
	sta.w RGBData+(127*2)
	stz.w TMenuFrame
	sep #$20		; mode 'a!'
	lda.b #$80	; Transfer RGB Palette to CGRAM
	sta.w RGBXFer
	wai
	ldx.w #0	; (VBlank) all sprites off screen
	stx.w OAMADDL
	lda.b #%00001000	; A->B, Fixed, 1-Write
	sta.w DMA1INC
	lda.b #lo16(OAMDATA)
	sta.w DMA1DEST
	ldx.w #lo16(TTLByteF0)
	stx.w DMA1A1L
	lda.b #bank(TTLByteF0)
	sta.w DMA1A1B
	ldx.w #544
	stx.w DMA1NUML
	lda.b #%00000010
	sta.w MDMAEN
	lda.b #$80	; BG2 Map SC1: blank (tile $084: $8484)
	sta.w VMAINC
	ldx.w #$7400
	stx.w VMADDL
	lda.b #%00001001	; A->B, Fixed, 1-Add-Write2x
	sta.w DMA1INC
	lda.b #lo16(VMDATAL)
	sta.w DMA1DEST
	ldx.w #lo16(TTLByte84)
	stx.w DMA1A1L
	lda.b #bank(TTLByte84)
	sta.w DMA1A1B
	ldx.w #(32*32*2)
	stx.w DMA1NUML
	lda.b #%00000010
	sta.w MDMAEN
	lda.b #$01	; BG1 only until the menu is set up
	sta.w TM
	stz.w TS
	stz.w SETINI	; No PseudoH512
	stz.w CGSWSEL	; Colour Sub 1/2 FIXED (black): BG1, back
	lda.b #%11100001
	sta.w CGADSUB
	lda.b #$E0
	sta.w COLDATA
	rep #$30		; mode 'AX!'
	rts

;
;	>>>   CLOSE: THE PLAIN TITLE AGAIN (NO TEXT ON BG2)   <<<
;
	; mode 'AX'
TTLMenuClose:
	ldx.w #(16-1)*2	; BG palette 7 back
TTLMC100:
	lda.l TitleRGB+(112*2),x
	sta.w RGBData+(112*2),x
	dex
	dex
	bpl TTLMC100
	sep #$20		; mode 'a!'
	wai
	lda.b #$01	; (VBlank) BG1 only
	sta.w TM
	stz.w TS
	lda.b #$80	; BG2 Map SC0: spaces ($2020, as the title fills it)
	sta.w VMAINC
	ldx.w #$7000
	stx.w VMADDL
	lda.b #%00001001	; A->B, Fixed, 1-Add-Write2x
	sta.w DMA1INC
	lda.b #lo16(VMDATAL)
	sta.w DMA1DEST
	ldx.w #lo16(TTLByte20)
	stx.w DMA1A1L
	lda.b #bank(TTLByte20)
	sta.w DMA1A1B
	ldx.w #(32*32*2)
	stx.w DMA1NUML
	lda.b #%00000010
	sta.w MDMAEN
	lda.b #$80	; Transfer RGB Palette to CGRAM
	sta.w RGBXFer
	wai
	ldx.w #$7400	; (VBlank) BG2 Map SC1: spaces
	stx.w VMADDL
	ldx.w #lo16(TTLByte20)
	stx.w DMA1A1L
	ldx.w #(32*32*2)
	stx.w DMA1NUML
	lda.b #%00000010
	sta.w MDMAEN
	ldx.w #(124*2)	; Skull off screen
	stx.w OAMADDL
	lda.b #$F0
	ldx.w #16
TTLMC200:
	sta.w OAMDATA
	dex
	bne TTLMC200
	jsr.w TTLRegs	; The title's registers
	rep #$30		; mode 'AX!'
	rts

;
;	>>>   SHOW MENU .A   <<<
;
	; mode 'AX'
TTLMenuShow:
	sta.w TMenuNum
	asl a	; *TMI_SIZE (14)
	sta.w TMenuPtr
	asl a
	asl a
	asl a
	sec
	sbc.w TMenuPtr
	sta.w TMenuPtr
	tax
	lda.l TTLMenuData+TMI_N,x
	sta.w TMenuMax
	sep #$20		; mode 'a!'
	wai
	lda.b #$01	; (VBlank) BG1 only while the menu changes
	sta.w TM
	rep #$20		; mode 'A!'
;
	lda.l TTLMenuData+TMI_DEF+1,x	; Tiles to load?  (menus 1-3)
	beq TTLMS300
	phb
	lda.l TTLMenuData+TMI_DEF+2,x	; DeCompress them
	and.w #$00FF
	ora.w #(bank(MenuDeCompBuffer)<<8)
	pha
	lda.l TTLMenuData+TMI_DEF,x
	tax
	pla
	ldy.w #lo16(MenuDeCompBuffer)
	jsl.l DeCompress
	plb
	rep #$30		; mode 'AX!'
	sty.w TMenuTmp	; Size
	stz.w TMenuTmp2	; Offset
TTLMS200:
	lda.w TMenuTmp	; 2 KB per VBlank (the screen is on)
	sec
	sbc.w TMenuTmp2
	beq TTLMS300
	bcc TTLMS300
	cmp.w #2048
	bcc TTLMS210
	lda.w #2048
TTLMS210:
	tay	; Bytes
	lda.w TMenuTmp2	; VRAM word address
	lsr a
	clc
	adc.w #!TITLEMENU_VRAMN
	tax
	sep #$20		; mode 'a!'
	wai
	lda.b #$80	; (VBlank)
	sta.w VMAINC
	stx.w VMADDL
	lda.b #%00000001	; A->B, 1-Add-Write2x
	sta.w DMA1INC
	lda.b #lo16(VMDATAL)
	sta.w DMA1DEST
	rep #$20		; mode 'A!'
	lda.w TMenuTmp2
	clc
	adc.w #lo16(MenuDeCompBuffer)
	sta.w DMA1A1L
	sty.w DMA1NUML
	sep #$20		; mode 'a!'
	lda.b #bank(MenuDeCompBuffer)
	sta.w DMA1A1B
	lda.b #%00000010
	sta.w MDMAEN
	rep #$20		; mode 'A!'
	lda.w TMenuTmp2
	clc
	adc.w #2048
	sta.w TMenuTmp2
	bra TTLMS200
;
TTLMS300:
	rep #$30		; mode 'AX!'
	phb	; The map -> DeCompBuffer
	ldx.w TMenuPtr
	lda.l TTLMenuData+TMI_MAP+2,x
	and.w #$00FF
	ora.w #(bank(DeCompBuffer)<<8)
	pha
	lda.l TTLMenuData+TMI_MAP,x
	tax
	pla
	ldy.w #lo16(DeCompBuffer)
	jsl.l DeCompress
	plb
	rep #$30		; mode 'AX!'
	lda.w TMenuNum	; The slot menu: its lines (rlmenus.asm, as the pause menu)
	cmp.w #3
	bne TTLMS500
	assert bank(DeCompBuffer) == bank(MenuDeCompBuffer)
	lda.w #!TITLEMENU_SLOT0	; Slot font tiles
	ldx.w #lo16(DeCompBuffer)+((((!TITLEMENU_LOADROW+3)*32)+6)*2)
	ldy.w #!TITLEMENU_BLANK
	jsl.l SlotMenuLines
TTLMS500:
	rep #$30		; mode 'AX!'
	ldx.w TMenuPtr
	lda.l TTLMenuData+TMI_HOFS,x
	sta.w TMenuTmp
	lda.l TTLMenuData+TMI_VOFS,x
	tay
	sep #$20		; mode 'a!'
	wai
	lda.b #$80	; (VBlank) the map to SC0
	sta.w VMAINC
	ldx.w #$7000
	stx.w VMADDL
	lda.b #%00000001	; A->B, 1-Add-Write2x
	sta.w DMA1INC
	lda.b #lo16(VMDATAL)
	sta.w DMA1DEST
	ldx.w #lo16(DeCompBuffer)
	stx.w DMA1A1L
	lda.b #bank(DeCompBuffer)
	sta.w DMA1A1B
	ldx.w #(32*32*2)
	stx.w DMA1NUML
	lda.b #%00000010
	sta.w MDMAEN
	lda.w TMenuTmp	; BG2 offsets
	sta.w BG2HOFS
	lda.w TMenuTmp+1
	sta.w BG2HOFS
	tya
	sta.w BG2VOFS
	xba
	sta.w BG2VOFS
	lda.b #((($4000>>12)<<4)|($0000>>12))	; BG2 Chars @$4000
	sta.w BG12NBA
	lda.b #$13	; BG1+BG2+OBJ
	sta.w TM
	rep #$30		; mode 'AX!'
	lda.w JOY1	; (no new press from the buttons held now)
	sta.w TMenuJoy
	rts

;
;	>>>   THE SKULL (IN VBLANK)   <<<
;
	; mode 'AX'
TTLMenuSkull:
	inc.w TMenuFrame
	ldx.w TMenuPtr	; Position: (y<<8)|x
	lda.l TTLMenuData+TMI_CUR,x
	sta.w TMenuTmp
	lda.w TMenuItem
	asl a
	clc
	adc.w TMenuTmp
	tax
	lda.l (bank(TTLMenus)<<16),x	; (the cursor tables are in this bank)
	sta.w TMenuTmp	; TMenuTmp = X, TMenuTmp+1 = Y
	lda.w TMenuFrame	; Frame: tiles $F0/$F2 (animated as in rlmenus.asm)
	lsr a
	lsr a
	lsr a
	and.w #$0002
	clc
	adc.w #$00F0
	tax	; Top left tile
	lda.w TMenuTmp	; (Y<<8)|X
	jsl.l MenuSkullSprites	; (rlmenus.asm, as the pause menu)
	sep #$20		; mode 'a!'
	ldx.w #($100+(120/8))	; High table: sprites 120-127 small, X < 256
	stx.w OAMADDL
	stz.w OAMDATA
	stz.w OAMDATA
	rep #$30		; mode 'AX!'
	rts

;
;	>>>   MENUS   <<<
;
TTLMenuData:
	dl TitleMenu0Map	; New Game / Load Game
	dl 0
	dw lo16(TTLMC0),2,0,$03FF
	dl TitleMenu1Map	; Skill
	dl TitleMenu1Def
	dw lo16(TTLMC1),5,0,$03FF
	dl TitleMenu2Map	; Episode
	dl TitleMenu2Def
	dw lo16(TTLMC2),!__tmep,0,$03FF
	dl TitleMenu3Map	; Load Game slots (where the pause menu shows them:
	dl TitleMenu3Def	;  20 pixels right, menu line 0 on screen line 55)
	dw lo16(TTLMC3),SAVESLOTS,$03EC,$0000
;
;	Skull positions (y<<8)|x, as on the FX3 cartridge (Load Game: as its Enter Code;
;	the slots: as the pause menu's)
;
TTLMC0:
	dw (94<<8)|56,(115<<8)|51
TTLMC1:
	dw (76<<8)|12,(94<<8)|14,(112<<8)|36,(130<<8)|32,(148<<8)|56
TTLMC2:
	dw (87<<8)|0,(105<<8)|8,(123<<8)|70,(141<<8)|4
TTLMC3:
	!__i #= 0
	while !__i < SAVESLOTS
	dw (((3+(2*!__i))*8+52)<<8)|51
	!__i #= !__i+1
	endwhile
TTLByteF0:
	db $F0
TTLByte84:
	db $84
TTLByte20:
	db $20

;
;	>>>   MELT RANDOM NUMBER   <<<
;
	; mode 'AX'
TTLMeltRand:
	lda.w MeltRnd
	inc a
	and.w #$00FF
	sta.w MeltRnd
	tax
	lda.l RandomTable,x
	and.w #$00FF
	rts

TTLMeltStep:
	dw -3,-2,-1,0,0,1,2,3	; Delay difference to the column on the left


;
;	* * * * * * *       TRANSFER LIST       * * * * * * *
;
	; mode '@A@X'
TitleXFer:
	dw xftVRAM16	; Transfer TitleDef0 to $0000W
	dd TitleDef0
	dd $0000
	dw 0,0,0
;
	dw xftVRAM16	; Transfer TitleDef1 to $2000W
	dd TitleDef1
	dd $2000
	dw 0,0,0
;
	dw xftVRAM16	; Transfer TitleMap to $4000W
	dd TitleMap
	dd $4000
	dw 0,0,0
;
	dw xftVRAMF16+xftRAW	; (this port) Blank character $3FF for the melt
	dd TitleXFerB
	dd $3FF0
	dw 16*2
TitleXFerB:
	dw $0000,0
;
	dw xftVRAMF16+xftRAW	; (this port) BG1 Map rows 28..63: blank ($FFFF:
	dd TitleXFerC	; the fill writes the same byte to both halves)
	dd $4000+(28*32)
	dw (64-28)*32*2
TitleXFerC:
	dw $FFFF,0
;
	dw xftVRAMF16+xftRAW	; (this port) Offset-per-tile table: no offsets
	dd TitleXFerB
	dd $4800
	dw 64*2
	dw 0,0
;
	dw xftRAM	; Transfer RGB
	dd TitleRGB
	dd RGBData
	dw 512
	dw 0,0
;
	dw xftVRAMF16+xftRAW	; Fill BG2 Maps (this port: 4, SC2/SC3 for the melt)
	dd TitleXFerA
	dd $7000
	dw (32*32*2)*4
TitleXFerA:
	dw $0020,0
	dw xftVRAM16	; Transfer TextFontDef to $6200W
	dd TextFontDef
	dd $6200
	dw 0,0,0
;
	dw xftVRAM16	; (this port) Title menu: New Game / Load Game tiles
	dd TitleMenu0Def
	dd !TITLEMENU_VRAM0
	dw 0,0,0
;
	dw xftVRAM16	; (this port) Title menu skull (OBJ tiles $1F0-$1F7)
	dd RLMenuSkullsDef
	dd $5F00
	dw 0,0,0
;
	dw xftEND


;
;	* * * * * * *       TITLE TEXTS       * * * * * * *
;
TitleSText:
	if 0 != 0
	dw ($7000+(24*32)+21)
	dl TTLTxt0A
	db TTLTxt0AL
	dw ($7000+(25*32)+21)
	dl (VerTxt-1)+7
	db 9
	endif
	dw -1

;TTLTxt0A	dc.b	'E3 BETA'
;TTLTxt0A	dc.b	'PROTO'
TTLTxt0A:	db "RELEASE"
	TTLTxt0AL = 7
	assert (TTLTxt0AL&$FFFFFF) == ((pc()-TTLTxt0A)&$FFFFFF), "cached constant TTLTxt0AL is stale (tools/fixup.py)"


;
;	* * * * * * *       CREDITS TEXTS       * * * * * * *
;
CreditsSText:
	dw ($7000+(2*32)+9)
	dl CRDTxt2A
	db CRDTxt2AL
	dw ($7000+(3*32)+9)
	dl CRDTxt1A
	db CRDTxt2AL
	dw ($7000+(4*32)+9)
	dl CRDTxt0A
	db CRDTxt0AL
;
	dw ($7000+(6*32)+9)
	dl CRDTxt2B
	db CRDTxt2BL
	dw ($7000+(7*32)+9)
	dl CRDTxt1A
	db CRDTxt2BL
	dw ($7000+(8*32)+9)
	dl CRDTxt0A
	db CRDTxt0AL
	dw ($7000+(9*32)+9)
	dl CRDTxt0E
	db CRDTxt0EL
	dw ($7000+(10*32)+9)
	dl CRDTxt0F
	db CRDTxt0FL
;
	dw ($7000+(12*32)+9)
	dl CRDTxt2C
	db CRDTxt2CL
	dw ($7000+(13*32)+9)
	dl CRDTxt1A
	db CRDTxt2CL
	dw ($7000+(14*32)+9)
	dl CRDTxt0A
	db CRDTxt0AL
	dw ($7000+(15*32)+9)
	dl CRDTxt0D
	db CRDTxt0DL
;
	dw ($7000+(17*32)+9)
	dl CRDTxt2D
	db CRDTxt2DL
	dw ($7000+(18*32)+9)
	dl CRDTxt1A
	db CRDTxt2DL
	dw ($7000+(19*32)+9)
	dl CRDTxt0G
	db CRDTxt0GL
	dw ($7000+(20*32)+9)
	dl CRDTxt0I
	db CRDTxt0IL
	dw ($7000+(21*32)+9)
	dl CRDTxt0J
	db CRDTxt0JL
;
	dw ($7000+(23*32)+9)
	dl CRDTxt2E
	db CRDTxt2EL
	dw ($7000+(24*32)+9)
	dl CRDTxt1A
	db CRDTxt2EL
	dw ($7000+(25*32)+9)
	dl CRDTxt0K
	db CRDTxt0KL
	dw ($7000+(26*32)+9)
	dl CRDTxt0L
	db CRDTxt0LL
;
	dw ($7400+(2*32)+8)
	dl CRDTxt2F
	db CRDTxt2FL
	dw ($7400+(3*32)+8)
	dl CRDTxt1A
	db CRDTxt2FL
	dw ($7400+(4*32)+8)
	dl CRDTxt0D
	db CRDTxt0DL
;
	dw ($7400+(6*32)+8)
	dl CRDTxt2G
	db CRDTxt2GL
	dw ($7400+(7*32)+8)
	dl CRDTxt1A
	db CRDTxt2GL
	dw ($7400+(8*32)+8)
	dl CRDTxt0F
	db CRDTxt0FL
	dw ($7400+(10*32)+8)
	dl CRDTxt0M
	db CRDTxt0ML
	dw ($7400+(11*32)+8)
	dl CRDTxt0N
	db CRDTxt0NL
	dw ($7400+(12*32)+8)
	dl CRDTxt0O
	db CRDTxt0OL
	dw ($7400+(13*32)+8)
	dl CRDTxt0P
	db CRDTxt0PL
	dw ($7400+(14*32)+8)
	dl CRDTxt0Q
	db CRDTxt0QL
;
	dw ($7400+(16*32)+8)
	dl CRDTxt2H
	db CRDTxt2HL
	dw ($7400+(17*32)+8)
	dl CRDTxt1A
	db CRDTxt2HL
	dw ($7400+(18*32)+8)
	dl CRDTxt0R
	db CRDTxt0RL
;
	dw ($7400+(20*32)+8)
	dl CRDTxt2I
	db CRDTxt2IL
	dw ($7400+(21*32)+8)
	dl CRDTxt1A
	db CRDTxt2IL
	dw ($7400+(22*32)+8)
	dl CRDTxt0B
	db CRDTxt0BL
	dw ($7400+(23*32)+8)
	dl CRDTxt0C
	db CRDTxt0CL
	dw ($7400+(24*32)+8)
	dl CRDTxt0H
	db CRDTxt0HL
	dw ($7400+(25*32)+8)
	dl CRDTxt0S
	db CRDTxt0SL
;
	dw -1

CRDTxt0A:	db "Randy Linden"
	CRDTxt0AL = 12
	assert (CRDTxt0AL&$FFFFFF) == ((pc()-CRDTxt0A)&$FFFFFF), "cached constant CRDTxt0AL is stale (tools/fixup.py)"
CRDTxt0B:	db "Jodi Harvey"
	CRDTxt0BL = 11
	assert (CRDTxt0BL&$FFFFFF) == ((pc()-CRDTxt0B)&$FFFFFF), "cached constant CRDTxt0BL is stale (tools/fixup.py)"
CRDTxt0C:	db "George Metos"
	CRDTxt0CL = 12
	assert (CRDTxt0CL&$FFFFFF) == ((pc()-CRDTxt0C)&$FFFFFF), "cached constant CRDTxt0CL is stale (tools/fixup.py)"
CRDTxt0D:	db "Ron Stagg"
	CRDTxt0DL = 9
	assert (CRDTxt0DL&$FFFFFF) == ((pc()-CRDTxt0D)&$FFFFFF), "cached constant CRDTxt0DL is stale (tools/fixup.py)"
CRDTxt0E:	db "Kelly Zmak"
	CRDTxt0EL = 10
	assert (CRDTxt0EL&$FFFFFF) == ((pc()-CRDTxt0E)&$FFFFFF), "cached constant CRDTxt0EL is stale (tools/fixup.py)"
CRDTxt0F:	db "Vince Bracken"
	CRDTxt0FL = 13
	assert (CRDTxt0FL&$FFFFFF) == ((pc()-CRDTxt0F)&$FFFFFF), "cached constant CRDTxt0FL is stale (tools/fixup.py)"
CRDTxt0G:	db "Michael Hunter"
	CRDTxt0GL = 14
	assert (CRDTxt0GL&$FFFFFF) == ((pc()-CRDTxt0G)&$FFFFFF), "cached constant CRDTxt0GL is stale (tools/fixup.py)"
CRDTxt0H:	db "Kevin Kralian"
	CRDTxt0HL = 13
	assert (CRDTxt0HL&$FFFFFF) == ((pc()-CRDTxt0H)&$FFFFFF), "cached constant CRDTxt0HL is stale (tools/fixup.py)"
CRDTxt0I:	db "Bryan Jacobs"
	CRDTxt0IL = 12
	assert (CRDTxt0IL&$FFFFFF) == ((pc()-CRDTxt0I)&$FFFFFF), "cached constant CRDTxt0IL is stale (tools/fixup.py)"
CRDTxt0J:	db "Virginia Sargent"
	CRDTxt0JL = $10
	assert (CRDTxt0JL&$FFFFFF) == ((pc()-CRDTxt0J)&$FFFFFF), "cached constant CRDTxt0JL is stale (tools/fixup.py)"
CRDTxt0K:	db "Paul Webb"
	CRDTxt0KL = 9
	assert (CRDTxt0KL&$FFFFFF) == ((pc()-CRDTxt0K)&$FFFFFF), "cached constant CRDTxt0KL is stale (tools/fixup.py)"
CRDTxt0L:	db "Bob Dayley"
	CRDTxt0LL = 10
	assert (CRDTxt0LL&$FFFFFF) == ((pc()-CRDTxt0L)&$FFFFFF), "cached constant CRDTxt0LL is stale (tools/fixup.py)"
CRDTxt0M:	db "Gary Rowberry"
	CRDTxt0ML = 13
	assert (CRDTxt0ML&$FFFFFF) == ((pc()-CRDTxt0M)&$FFFFFF), "cached constant CRDTxt0ML is stale (tools/fixup.py)"
CRDTxt0N:	db "Chris Olson"
	CRDTxt0NL = 11
	assert (CRDTxt0NL&$FFFFFF) == ((pc()-CRDTxt0N)&$FFFFFF), "cached constant CRDTxt0NL is stale (tools/fixup.py)"
CRDTxt0O:	db "Chandler Holbrook"
	CRDTxt0OL = $11
	assert (CRDTxt0OL&$FFFFFF) == ((pc()-CRDTxt0O)&$FFFFFF), "cached constant CRDTxt0OL is stale (tools/fixup.py)"
CRDTxt0P:	db "Garon Galloway"
	CRDTxt0PL = 14
	assert (CRDTxt0PL&$FFFFFF) == ((pc()-CRDTxt0P)&$FFFFFF), "cached constant CRDTxt0PL is stale (tools/fixup.py)"
CRDTxt0Q:	db "Ben Nielson"
	CRDTxt0QL = 11
	assert (CRDTxt0QL&$FFFFFF) == ((pc()-CRDTxt0Q)&$FFFFFF), "cached constant CRDTxt0QL is stale (tools/fixup.py)"
CRDTxt0R:	db "John Coffey"
	CRDTxt0RL = 11
	assert (CRDTxt0RL&$FFFFFF) == ((pc()-CRDTxt0R)&$FFFFFF), "cached constant CRDTxt0RL is stale (tools/fixup.py)"
CRDTxt0S:	db "John Morgan"
	CRDTxt0SL = 11
	assert (CRDTxt0SL&$FFFFFF) == ((pc()-CRDTxt0S)&$FFFFFF), "cached constant CRDTxt0SL is stale (tools/fixup.py)"

CRDTxt1A:	db "_______________"

CRDTxt2A:	db "Architect"
	CRDTxt2AL = 9
	assert (CRDTxt2AL&$FFFFFF) == ((pc()-CRDTxt2A)&$FFFFFF), "cached constant CRDTxt2AL is stale (tools/fixup.py)"
CRDTxt2B:	db "Foremen"
	CRDTxt2BL = 7
	assert (CRDTxt2BL&$FFFFFF) == ((pc()-CRDTxt2B)&$FFFFFF), "cached constant CRDTxt2BL is stale (tools/fixup.py)"
CRDTxt2C:	db "Carpenters"
	CRDTxt2CL = 10
	assert (CRDTxt2CL&$FFFFFF) == ((pc()-CRDTxt2C)&$FFFFFF), "cached constant CRDTxt2CL is stale (tools/fixup.py)"
CRDTxt2D:	db "Electricians"
	CRDTxt2DL = 12
	assert (CRDTxt2DL&$FFFFFF) == ((pc()-CRDTxt2D)&$FFFFFF), "cached constant CRDTxt2DL is stale (tools/fixup.py)"
CRDTxt2E:	db "Plumbing"
	CRDTxt2EL = 8
	assert (CRDTxt2EL&$FFFFFF) == ((pc()-CRDTxt2E)&$FFFFFF), "cached constant CRDTxt2EL is stale (tools/fixup.py)"
CRDTxt2F:	db "Renovations"
	CRDTxt2FL = 11
	assert (CRDTxt2FL&$FFFFFF) == ((pc()-CRDTxt2F)&$FFFFFF), "cached constant CRDTxt2FL is stale (tools/fixup.py)"
CRDTxt2G:	db "Masons"
	CRDTxt2GL = 6
	assert (CRDTxt2GL&$FFFFFF) == ((pc()-CRDTxt2G)&$FFFFFF), "cached constant CRDTxt2GL is stale (tools/fixup.py)"
CRDTxt2H:	db "Doom Is My Life"
	CRDTxt2HL = 15
	assert (CRDTxt2HL&$FFFFFF) == ((pc()-CRDTxt2H)&$FFFFFF), "cached constant CRDTxt2HL is stale (tools/fixup.py)"
CRDTxt2I:	db "Special Thanks"
	CRDTxt2IL = 14
	assert (CRDTxt2IL&$FFFFFF) == ((pc()-CRDTxt2I)&$FFFFFF), "cached constant CRDTxt2IL is stale (tools/fixup.py)"
	db 'R'


;
;	* * * * * * *       TITLE DATA       * * * * * * *
;
	%section(TITLE_DATA_0)
TitleDef0:
	incbin "data/RLDATA/COMP/title.def.0"

	%section(TITLE_DATA_1)
TitleDef1:
	incbin "data/RLDATA/COMP/title.def.1"

	%section(TITLE_DATA_2)
TitleMap:
	incbin "data/RLDATA/COMP/title.map0"

	%section(TITLE_DATA_3)
TitleRGB:
	incbin "data/RLDATA/COMP/title.rgb"
;
;	(this port) the title menus (tools/titlemenus.py)
;
TitleMenu0Def:
	incbin "data/RLDATA/COMP/TitleMenu0.def0"
TitleMenu1Def:
	incbin "data/RLDATA/COMP/TitleMenu1.def0"
TitleMenu2Def:
	incbin "data/RLDATA/COMP/TitleMenu2.def0"
TitleMenu3Def:
	incbin "data/RLDATA/COMP/TitleMenu3.def0"
TitleMenu0Map:
	incbin "data/RLDATA/COMP/TitleMenu0.map0"
TitleMenu1Map:
	incbin "data/RLDATA/COMP/TitleMenu1.map0"
TitleMenu2Map:
	incbin "data/RLDATA/COMP/TitleMenu2.map0"
TitleMenu3Map:
	incbin "data/RLDATA/COMP/TitleMenu3.map0"

	endif
