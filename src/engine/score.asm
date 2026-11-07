	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                           SCORE PAGE MODULE                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/xfer.inc"
	incsrc "src/include/music.inc"

;	(this port) Episodes with score screens in the ROM: levels.inc !RLEPISODES
;	(the shareware set), else 3, or 4 for Ultimate DOOM
;	DOOM II sets (levels.inc !RLEPISODELEN = 99): one picture for every level (ScoreE1,
;	the WAD's INTERPIC: wad2art.py --interpic), no splats, no "YOU ARE HERE", no episode
;	text between maps (only at the end of the game)
;	Level names above FINISHED (wad2art.py --level-names: COMP/ScoreName<level>.def0/.map0, tiles
;	at $6800 = BG2 tile 128, the map for BG2 rows 1-2, ART/ScoreName.rgb = BG palette 6)
	!__scorenames = 0
	if canreadfile1("data/RLDATA/ART/ScoreName.rgb", 0)
	!__scorenames = 1
	endif
	!__score1pic = 0
	if defined("RLEPISODELEN")
	if !RLEPISODELEN == 99
	!__score1pic = 1
	endif
	endif
	if !__score1pic != 0
	!__scoreeps = 1
	elseif defined("RLEPISODES")
	!__scoreeps = !RLEPISODES
	elseif !NUMLEVELS > 27
	!__scoreeps = 4
	else
	!__scoreeps = 3
	endif

	if useSCORE != 0

	; public Score


	%section(SCORE)
;
;	* * * * * * *       SCORE PAGE       * * * * * * *
;
	; dpr 0
	; dbr ?
	; mode 'Ax'
Score:
	jsl.l ScreenOff	; Turn Screen Off
	jsl.l InitSNES
;
;	>>>   SCORE MUSIC   <<<
;
	rep #$30		; mode 'AX!'
	if useSOUND != 0
	lda.w #((inter_sng_MODULE<<8)|inter_sng)	; INTER Song
	jsl.l _PlaySong
	endif
;
;	>>>   TRANSFER SCORE EPISODE-SPECIFIC DATA   <<<
;
	ldy.w Level	; NEXT LEVEL (picture of the episode just played)
	if defined("RLEPISODES")
	cpy.w #!NUMLEVELS	; Game over: the last episode kept was played
	bne +
	ldy.w #(!RLEPISODES*9)
+
	endif
	ldx.w #lo16(ScoreE1XFer)	; E1M1-E1M9
	lda.w #bank(ScoreE1XFer)
	if !__scoreeps >= 2
	cpy.w #10
	bcc SCR500
	ldx.w #lo16(ScoreE2XFer)	; E2M1-E2M9
	lda.w #bank(ScoreE2XFer)
	endif
	if !__scoreeps >= 3
	cpy.w #19
	bcc SCR500
	ldx.w #lo16(ScoreE3XFer)	; E3M1-E3M9
	lda.w #bank(ScoreE3XFer)
	endif
	if !__scoreeps >= 4
	cpy.w #28
	bcc SCR500
	ldx.w #lo16(ScoreE4XFer)	; E4M1-E4M9 (Ultimate DOOM)
	lda.w #bank(ScoreE4XFer)
	endif
SCR500:
	jsl.l XFer
;
;	>>>   TRANSFER SCORE COMMON DATA   <<<
;
	ldx.w #lo16(ScoreXFer)	; Transfer Common Score DataBlock
	lda.w #bank(ScoreXFer)
	jsl.l XFer
	lda.w #%000000000000000
	sta.w RGBData+(96*2)+(7*2)
	lda.w #%111101111011110
	sta.w RGBData+(96*2)+(11*2)
;
;	>>>   BUILD SCORE DIGITS   <<<
;
	sep #$20		; mode 'a!'
	lda.b #%00000001	; A->B, Abs., Auto Inc,2-Add-WriteLH
	sta.w DMA0INC
	lda.b #lo16(VMDATAL)	; VMDATA
	sta.w DMA0DEST
	lda.b #bank(DeCompBuffer)
	sta.w DMA0A1B
	rep #$20		; mode 'A!'
	lda.w #10-1	; 10 Digits to Transfer
	sta.b Temp
	lda.w #lo16(DeCompBuffer)
	ldy.w #$6C00
SCR1000:
	sta.w DMA0A1L	; First Line
	sty.w VMADDL
	ldx.w #(2*32)
	stx.w DMA0NUML
	ldx.w #(0<<8)+1
	stx.w MDMAEN
;
	clc	; Second Line
	adc.w #(10*2*32)
	sta.w DMA0A1L
	pha
	tya
	xba	; Add $100
	inc a
	xba
	sta.w VMADDL
	ldx.w #(2*32)
	stx.w DMA0NUML
	ldx.w #(0<<8)+1
	stx.w MDMAEN
;
	tya	; Next VRAM Address
	clc
	adc.w #$120
	and.w #$7EF0
	tay
	pla
	sec	; Next SOURCE Data
	sbc.w #((10-1)*2)*32
	dec.b Temp	; Next Digit
	bpl SCR1000
	if !__scorenames != 0
	lda.w ScoreLevelDone	; (this port) the finished level's name above FINISHED (after the
				;  digits: its unpacking uses DeCompBuffer)
	and.w #$00FF
	asl a
	asl a
	tax
	lda.l ScoreNameXFers+2,x
	pha
	lda.l ScoreNameXFers,x
	tax
	pla
	jsl.l XFer
	endif
;
;	>>>   INITIALIZE PPU   <<<
;
	jsl.l InitNormalNMI
	sep #$20		; mode 'a!'
	lda.b #$80	; Transfer RGB Palette to CGRAM
	sta.w RGBXFer
	lda.b #1	; Mode1 BG1:8x8
	sta.w BGMODE
	lda.b #$7C	; BG1 Screen at $7c00
	sta.w BG1SC
	lda.b #$78	; BG2 Screen at $7800
	sta.w BG2SC
	lda.b #$FF	; Offset $FFFF
	sta.w BG1VOFS
	sta.w BG1VOFS
	stz.w BG1HOFS	; Offset $0000
	stz.w BG1HOFS
	sta.w BG2VOFS	; Offset $FFFF
	sta.w BG2VOFS
	stz.w BG2HOFS	; Offset $0000
	stz.w BG2HOFS
	lda.b #((($6000>>12)<<4)|($0000>>12))	; BG1 Chars @$0000, BG2 Chars @$6000
	sta.w BG12NBA
	stz.w MOSAIC
	lda.b #%00001000	; PseudoH512, 224Lines
	sta.w SETINI
	lda.b #%00000010	; Colour Add Enable
	sta.w CGSWSEL
	lda.b #%01000001	; Add 1/2 Enable BG1
	sta.w CGADSUB
	lda.b #%00000000+($6C00>>13)	; (1x1,2x2) (8K contig.) (BaseAddr)
	sta.w OBJSEL
	rep #$10		; mode 'X!'
	ldx.w #$1313	; BG1+BG2+OBJ
	stx.w TM
;
	ldx.w PlayerLevelTime	; #Seconds in Level
	stx.w WRDIVL
	lda.b #60	; #Seconds in 1 Minute
	sta.w WRDIVB
;
;	>>>   INITIALIZE SPRITES   <<<
;
	ldy.w #MaxOAMs-1	; #OAMs total
	ldx.w #0	; Move All OAMs off-screen
	lda.b #MaxViewScanLines	; (256-32)
SCR1200:
	sta.w OAMA+oamsY,x
	inx
	inx
	inx
	inx
	dey
	bpl SCR1200
;
	rep #$20		; mode 'A!'
	ldx.w #(MaxOAMs*2/8)-2	; Set Sprites' OAMAux
	lda.w #%1010101010101010
SCR1400:
	sta.w OAMAA,x
	dex
	dex
	bpl SCR1400
;
	lda.w Level
	and.w #$00FF
	if defined("RLEPISODES")	; (levels.inc: fewer episodes than slots, the shareware set)
	cmp.w #!NUMLEVELS	; Game over: the last episode kept was finished
	bne +
	lda.w #(!RLEPISODES*9)
+
	endif
	if !__score1pic != 0
	ldx.w #lo16(ScoreE4Text)	; (this port) DOOM II: a text at the end of the game only
	cmp.w #!NUMLEVELS
	bne SCR1600
	jmp.w SCR2000
	else
	ldx.w #lo16(ScoreE1Text)	; Finished Episode E1?
	cmp.w #9
	beq SCR1500
	ldx.w #lo16(ScoreE2Text)	; Finished Episode E2?
	cmp.w #18
	beq SCR1500
	ldx.w #lo16(ScoreE3Text)	; Finished Episode E3?
	cmp.w #27
	if !NUMLEVELS > 27
	beq SCR1500
	ldx.w #lo16(ScoreE4Text)	; Finished Episode E4?
	cmp.w #36
	endif
	bne SCR1600
SCR1500:
	jmp.w SCR2000	; Yes, Finished an Episode!
	endif

;
;	>>>   PLAYER'S TIME   <<<
;
SCR1600:
	lda.w _RDMPYL	; #Seconds
	pha
	lda.w _RDDIVL	; #Minutes
	beq SCR1650
	ldx.w #(0*4)
	ldy.w #(188<<8)+141
	jsr.w ScoreOAMNum
SCR1650:
	pla	; #Seconds
	ldx.w #(2*4)
	ldy.w #(188<<8)+167
	jsr.w ScoreOAMNum2
;
;	>>>   %KILLS, %ITEMS, %SECRETS   <<<
;	(this port: ScorePct takes 16-bit counts; the original 8-bit multiply
;	failed past 255 kills or items)
;
	rep #$30		; mode 'AX!'
	lda.l EMTOTALKILLS
	tax
	lda.l NumKills
	jsr.w ScorePct
	ldx.w #(8*4)
	ldy.w #(64<<8)+189
	jsr.w ScoreOAMNum
	lda.l EMTOTALITEMS
	tax
	lda.l NumItems
	jsr.w ScorePct
	ldx.w #(11*4)
	ldy.w #(84<<8)+189
	jsr.w ScoreOAMNum
	lda.l EMTOTALSECRETS
	tax
	lda.l NumSecrets
	jsr.w ScorePct
	ldx.w #(14*4)
	ldy.w #(104<<8)+189
	jsr.w ScoreOAMNum
;
	jsr.w ScoreOAMXFer
	jsl.l FadeScreenOn
	; mode 'ax'
;
;	>>>   WAIT FOR JOYSTICK PRESS   <<<
;
	rep #$10		; mode 'X!'
SCR1900:
	ldx.w JOY1L	; Joystick pressed?
	bne SCR1900	; Yes, wait until released
SCR1950:
	ldx.w JOY1L	; Wait until pressed
	beq SCR1950
	jmp.w SCR4000

;
;	* * * * * * *       COMPLETED AN EPISODE?       * * * * * * *
;
;	>>>   DISPLAY EPISODE TEXT   <<<
;
	; mode 'AX'
SCR2000:
	phx	; Save EpisodeText
	ldx.w #lo16(ScoreXFer3)	; Transfer Score3 DataBlock
	lda.w #bank(ScoreXFer3)
	jsl.l XFer
	lda.w #4	; (TEMP4+4) = TextSpeed
	sta.b Temp4+4
	lda.w #$0303	; BG1+BG2
	sta.w TM
	jsl.l FadeScreenOn
	; mode 'ax'
;
	rep #$10		; mode 'X!'
	plx	; [TEMP4] = EpisodeText
	stx.b Temp4
	lda.b #bank(ScoreE1Text)
	sta.b Temp4+2
	ldy.w #-1	; .Y = TextIndex
SCR2200:
	lda.b Temp4+4	; Wait for VBlanks
SCR2220:
	wai
	dec a
	bpl SCR2220
SCR2300:
	iny	; Next Byte
	lda.b [Temp4],y
	bmi SCR2900	; End?
	bne SCR2500	; Character?
	iny	; VRAM Address
	lda.b [Temp4],y	; Next Byte
	sta.b Temp4+6
	iny
	lda.b [Temp4],y	; Next Byte
	sta.b Temp4+6+1
	bra SCR2300
SCR2500:
	sec	; Character#
	sbc.b #$20
	xba
	lda.b #$38	; Priority,Palette#6
	xba
	tax
	phy
	ldy.b Temp4+6
	sty.w VMADDL	; VRAM Address
	stx.w VMDATAL	; Character
	iny
	sty.b Temp4+6
	ply
	ldx.w JOY1L	; Joystick Pressed?
	beq SCR2200
	stz.b Temp4+4	; Yes, TextSpeed=0!
	bra SCR2200
;
;	>>>   WAIT FOR JOYSTICK PRESS   <<<
;
SCR2900:
	ldx.w JOY1L	; Joystick pressed?
	bne SCR2900	; Yes, wait until released
SCR2950:
	ldx.w JOY1L	; Wait until pressed
	beq SCR2950
;
;	>>>   TRANSFER SCORE EPISODE-SPECIFIC DATA   <<<
;
SCR3000:
	lda.w Level	; Get Next Level
	cmp.b #!NUMLEVELS	; Finished the last Episode?
	bne SCR3100	; No, Change Score Screen
	rep #$20		; mode 'A!'
	jmp.w SCR6000	; Yes, GAME OVER!
	; mode 'a'
SCR3100:
	jsl.l FadeScreenOff
	rep #$10		; mode 'X!'
	ldx.w #$0101	; BG1
	stx.w TM
	lda.b #$80	; Transfer RGB Palette to CGRAM
	sta.w RGBXFer
	ldy.w Level
	if !__scoreeps >= 2
	ldx.w #lo16(ScoreE2XFer)	; E2M1?
	lda.b #bank(ScoreE2XFer)
	else
	ldx.w #lo16(ScoreE1XFer)	; (one episode: not reached, game over)
	lda.b #bank(ScoreE1XFer)
	endif
	cpy.w #9
	beq SCR3800	; Yes, Change Score Screen
	if !__scoreeps >= 3
	ldx.w #lo16(ScoreE3XFer)	; E3M1?
	lda.b #bank(ScoreE3XFer)
	endif
	if !__scoreeps >= 4
	cpy.w #18
	beq SCR3800	; Yes, Change Score Screen
	ldx.w #lo16(ScoreE4XFer)	; E4M1 (Ultimate DOOM)
	lda.b #bank(ScoreE4XFer)
	endif
SCR3800:
	jsl.l XFer
	; mode 'AX'
	stz.w ScoreSecret	; Player Didn't Get Episode Secret
	jsl.l FadeScreenOn
	rep #$10		; mode 'X!'

;
;	* * * * * * *       SHOW SPLATS       * * * * * * *
;
SCR4000:
	rep #$20		; mode 'A!'
	if !__score1pic != 0
	ldy.w #0	; (this port) DOOM II: no map, every OAM off screen
	jmp.w SCR4500
	endif
	lda.w Level	; NEXT LEVEL: splat the levels played before it
	if !NUMLEVELS > 27
	cmp.w #27	; Episode 4 has no map: no splats (as FX3)
	bcc +
	ldy.w #0	; (this port) every OAM off screen, no "YOU ARE HERE"
	jmp.w SCR4500
+
	endif
	asl a
	tax
	ldy.w #(12*4)	; .Y = Starting OAM Offset
;
;	>>>   NEXT SPLAT   <<<
;
SCR4200:
	lda.l NextSplatI,x	; Move to Next Splat (the level before)
	asl a
	bmi SCR4250	; No More Splats!
	tax
	bcc SCR4300	; Regular Level (else secret: only with ScoreSecret)
	lda.w ScoreSecret	; Got Secret Level?
	beq SCR4200	; No!
	bra SCR4300
SCR4250:
	jmp.w SCR4500
;
;	>>>   DRAW A SPLAT   <<<
;
SCR4300:
	lda.l EMNUMVERTEXESTable,x	; Is this Level Valid?
	beq SCR4200	; NO!  DON'T DRAW A SPLAT!
;
	lda.l ScoreE1Splats,x	; Get X/Y Coordinates
	sec
	sbc.w #((14<<8)+12)
	sta.w OAMA+(0*4)+oamsX,y
	clc
	adc.w #8
	sta.w OAMA+(1*4)+oamsX,y
	clc
	adc.w #8
	sta.w OAMA+(2*4)+oamsX,y
	clc
	adc.w #$0800
	sta.w OAMA+(5*4)+oamsX,y
	sec
	sbc.w #8
	sta.w OAMA+(4*4)+oamsX,y
	sec
	sbc.w #8
	sta.w OAMA+(3*4)+oamsX,y
	clc
	adc.w #$0800
	sta.w OAMA+(6*4)+oamsX,y
	clc
	adc.w #8
	sta.w OAMA+(7*4)+oamsX,y
	clc
	adc.w #8
	sta.w OAMA+(8*4)+oamsX,y
	lda.w #$30C0	; Priority|Colour|Char#
	sta.w OAMA+(0*4)+oamsChr,y
	inc a
	sta.w OAMA+(1*4)+oamsChr,y
	inc a
	sta.w OAMA+(2*4)+oamsChr,y
	inc a
	sta.w OAMA+(3*4)+oamsChr,y
	inc a
	sta.w OAMA+(4*4)+oamsChr,y
	inc a
	sta.w OAMA+(5*4)+oamsChr,y
	inc a
	sta.w OAMA+(6*4)+oamsChr,y
	inc a
	sta.w OAMA+(7*4)+oamsChr,y
	inc a
	sta.w OAMA+(8*4)+oamsChr,y
	tya	; Next Splat OAM
	clc
	adc.w #(9*4)
	tay
	jmp.w SCR4200
;
SCR4500:
	lda.w #MaxViewScanLines	; Move Remaining OAMs OffScreen
SCR4520:
	sta.w OAMA+oamsY,y
	iny
	iny
	iny
	iny
	cpy.w #(MaxOAMs*4)
	bne SCR4520
;
	ldx.w #(MaxOAMs*2/8)-2	; Set Sprites' OAMAux
	lda.w #%0000000000000000
SCR4600:
	sta.w OAMAA,x
	dex
	dex
	bpl SCR4600
;
;	>>>   YOU ARE HERE   <<<
;
	if !__score1pic != 0
	jmp.w SCR4900	; (this port) DOOM II: no map, no marker
	endif
	lda.w Level	; NEXT LEVEL
	if !NUMLEVELS > 27
	cmp.w #27	; (this port) Episode 4: no map, no marker
	bcc +	; (the splat tables end with E3)
	jmp.w SCR4900
+
	endif
	asl a
	tax
	lda.l ScoreE1Splats,x	; Get X Coordinate
	and.w #$00FF
	ldy.w #$30D0	; Priority|Colour|Char#
	cmp.w #256-64
	lda.w #-((14<<8)+0)
	bcc SCR4800
	ldy.w #$30D2	; Priority|Colour|Char#
	lda.w #-((14<<8)+48)
SCR4800:
	phy
	clc	; Adjust Coordinates
	adc.l ScoreE1Splats,x
	sta.w OAMA+(0*4)+oamsX
	clc
	adc.w #8
	sta.w OAMA+(1*4)+oamsX
	clc
	adc.w #8
	sta.w OAMA+(2*4)+oamsX
	clc
	adc.w #8
	sta.w OAMA+(3*4)+oamsX
	clc
	adc.w #8
	sta.w OAMA+(4*4)+oamsX
	clc
	adc.w #8
	sta.w OAMA+(5*4)+oamsX
	clc
	adc.w #$0800
	sta.w OAMA+(11*4)+oamsX
	sec
	sbc.w #8
	sta.w OAMA+(10*4)+oamsX
	sec
	sbc.w #8
	sta.w OAMA+(9*4)+oamsX
	sec
	sbc.w #8
	sta.w OAMA+(8*4)+oamsX
	sec
	sbc.w #8
	sta.w OAMA+(7*4)+oamsX
	sec
	sbc.w #8
	sta.w OAMA+(6*4)+oamsX
	pla	; Priority|Colour|Char#
	pha
	sta.w OAMA+(0*4)+oamsChr
	inc a
	sta.w OAMA+(1*4)+oamsChr
	inc a
	sta.w OAMA+(2*4)+oamsChr
	inc a
	sta.w OAMA+(3*4)+oamsChr
	inc a
	sta.w OAMA+(4*4)+oamsChr
	inc a
	sta.w OAMA+(5*4)+oamsChr
	pla	; Priority|Colour|Char#
	clc
	adc.w #$0008
	sta.w OAMA+(6*4)+oamsChr
	inc a
	sta.w OAMA+(7*4)+oamsChr
	inc a
	sta.w OAMA+(8*4)+oamsChr
	inc a
	sta.w OAMA+(9*4)+oamsChr
	inc a
	sta.w OAMA+(10*4)+oamsChr
	inc a
	sta.w OAMA+(11*4)+oamsChr
;
SCR4900:
	lda.w #$0101	; BG1
	sta.w TM
	sep #$20
	rep #$10		; mode 'aX!'
	lda.b #-1	; NASTY Transfers
	sta.w XFerNasty
	ldx.w #lo16(ScoreXFer2)	; Transfer Score2 DataBlock
	lda.b #bank(ScoreXFer2)
	jsl.l XFer
	sep #$20		; mode 'a!'
	stz.w XFerNasty	; NICE Transfers
	jsr.w ScoreOAMXFer
	; mode 'AX'
	lda.w #$1111	; BG1+OBJ
	sta.w TM
;
;	>>>   WAIT FOR JOYSTICK PRESS   <<<
;
SCR5000:
	ldy.w JOY1L	; Joystick Pressed?
	jmp.w SCR5300
SCR5200:
	lda.w OAMAA	; Blink "YOU ARE HERE"
	eor.w #%0101010101010101
	sta.w OAMAA
	lda.w OAMAA+2
	eor.w #%0000000001010101
	sta.w OAMAA+2
	phy
	jsr.w ScoreOAMXFer
	ply
SCR5300:
	ldx.w #20
SCR5400:
	wai
	tya	; Wait until Pressed
	eor.w JOY1L
	and.w JOY1L
	bne SCR6000
	ldy.w JOY1L
	dex
	bne SCR5400
	bra SCR5200
;
;	>>>   FADE MUSIC OUT   <<<
;
SCR6000:
	if useSOUND != 0
	lda.w #DCOM_FADE_AND_STOP	; Fade out Music
	ldy.w #$0201
	jsl.l __SendDriverCommand
	endif
	jml.l FadeScreenOff


;
;	>>>   PERCENTAGE (this port)   <<<
;	mode 'AX!': .A = count, .X = total -> .A = count*100/total (a total of 0
;	counts as 1, as on the PC).  The hardware multiplies 8 x 8 and divides
;	16 / 8 bits: both are halved until the total is below 256 (within 1 %);
;	a count still above 255 (more than the total) is taken as 255.
;
ScorePct:
	sta.b Temp
	txa
	bne SPCT100
	inc a
SPCT100:
	sta.b Temp+2
SPCT200:
	lda.b Temp+2	; Total >= 256?
	cmp.w #256
	bcc SPCT300
	lsr.b Temp+2	; Yes: halve both
	lsr.b Temp
	bra SPCT200
SPCT300:
	lda.b Temp	; Count
	cmp.w #256
	bcc SPCT400
	lda.w #255
SPCT400:
	sep #$20		; mode 'a!'
	sta.w WRMPYA
	lda.b #100
	sta.w WRMPYB
	nop		; (wait for the multiply: 8 cycles)
	nop
	nop
	nop
	rep #$20		; mode 'A!'
	lda.w _RDMPYL
	sta.w WRDIVL	; Count*100
	sep #$20		; mode 'a!'
	lda.b Temp+2
	sta.w WRDIVB	; / Total
	rep #$20		; mode 'A!'
	nop		; (wait for the divide: 16 cycles)
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	lda.w _RDDIVL
	rts

;
;	* * * * * * *       GENERATE SCORE DIGITS INTO OAMS       * * * * * * *
;
;	.A = Integer to Generate
;	.X = OAM Offset
;	.Y = OAM Coordinates
;
;	Enter at ScoreOAMNum2 to ALWAYS Show 2 Digits
;
	; mode 'AX'
ScoreOAMNum2:
	sty.b Temp	; (TEMP) = X.B/Y.B
	ldy.w #2
	bra SOAN200
ScoreOAMNum:
	sty.b Temp	; (TEMP) = X.B/Y.B
	ldy.w #3	; #Digits to Process
	cmp.w #100	; >=100?
	bcs SOAN200
	dey
	cmp.w #10
	bcs SOAN200
	dey
SOAN200:
	sta.w WRDIVL	; Dividend
	sep #$20		; mode 'a!'
	lda.b #10	; Divisor
	sta.w WRDIVB
	rep #$20		; mode 'A!'
	lda.b Temp	; X/Y Coordinates
	sta.w OAMA+oamsX,x
	sec
	sbc.w #10
	sta.b Temp
	lda.w _RDMPYL	; Next Digit
	cmp.w #8
	bcc SOAN400
;	sec
	adc.w #($10-8-1)
SOAN400:
	asl a
	ora.w #$30C0	; Priority|Colour|Char#
	sta.w OAMA+oamsChr,x
	inx
	inx
	inx
	inx
	lda.w _RDDIVL
	dey	; One less digit
	bne SOAN200
	rts

;
;	* * * * * * *       TRANSFER SCORE OAMS       * * * * * * *
;
ScoreOAMXFer:
	jsl.l WaitVBlank	; Wait for VBlank
	sep #$10
	rep #$20		; mode 'Ax!'
	stz.w OAMADDL	; Transfer OAM structure
	lda.w #lo16(OAMA)	; Start Channel#0
	sta.w DMA0A1L
	lda.w #(MaxOAMs+(MaxOAMs/16))*4	; #Bytes to transfer
	sta.w DMA0NUML
	ldx.b #lo16(OAMDATA)	; OAMDATA
	stx.w DMA0DEST
	ldx.b #%00000010	; A->B, Abs., Auto Inc,1-Add-Write2x
	stx.w DMA0INC
	ldx.b #bank(OAMA)
	stx.w DMA0A1B
	ldx.b #1	; Enable/Start Channel#0
	stx.w MDMAEN
	rep #$30		; mode 'AX!'
	rts


;
;	* * * * * * *       SCORE COMMON TRANSFER LISTS       * * * * * * *
;
ScoreXFer:
	dw xftVRAM16	; Transfer ScoreDef to $6000W
	dd ScoreDef
	dd $6000
	dw 0,0,0
	dw xftVRAMM16	; Transfer ScoreMap to $7800W
	dd ScoreMap
	dd $7800
	dw $FFFF,$3C00,$0000	; AND,OR(BGPri,Palette#7),ADD
	dw xftRAM+xftRAW	; Transfer RGB
	dd ScoreRGB
	dd RGBData+(112*2)
	dw (8*2)
	dw 0,0
	dw xftRAM+xftRAW	; Transfer RGB
	dd ScoreNumRGB
	dd RGBData+(128*2)
	dw (8*2)
	dw 0,0
	dw xftRAM	; Transfer ScoreNumDef to DeCompBuffer
	dd ScoreNumDef
	dd DeCompBuffer
	dw 0,0,0
	dw xftEND
;
ScoreXFer2:
	dw xftVRAM16	; Transfer ScoreSplatDef to $6C00W
	dd ScoreSplatDef
	dd $6C00
	dw 0,0,0
	dw xftVRAM16	; Transfer ScoreHereDef to $6D00W
	dd ScoreHereDef
	dd $6D00
	dw 0,0,0
	dw xftEND
;
ScoreXFer3:
	dw xftVRAMF16+xftRAW	; Fill BG2 Map
	dd ScoreXFer3A
	dd $7800
	dw (28*32*2)
ScoreXFer3A:
	dw 0,0
	dw xftVRAM16	; Transfer TextFontDef to $6000W
	dd TextFontDef
	dd $6000
	dw 0,0,0
	dw xftEND

;
;	* * * * * * *       SCORE E1 TRANSFER LIST       * * * * * * *
;
ScoreE1XFer:
	dw xftVRAM16	; Transfer ScoreE1Def0 to $0000W
	dd ScoreE1Def0
	dd $0000
	dw 0,0,0
	dw xftVRAM16	; Transfer ScoreE1Def1 to $2000W
	dd ScoreE1Def1
	dd $2000
	dw 0,0,0
	dw xftVRAM16	; Transfer ScoreE1Map to $7c00W
	dd ScoreE1Map
	dd $7C00
	dw 0,0,0
	dw xftRAM+xftRAW	; Transfer RGB
	dd ScoreE1RGB
	dd RGBData
	dw (96*2)
	dw 0,0
	dw xftEND
;
;	* * * * * * *       SCORE E2 TRANSFER LIST       * * * * * * *
;
	if !__scoreeps >= 2
ScoreE2XFer:
	dw xftVRAM16	; Transfer ScoreE2Def0 to $0000W
	dd ScoreE2Def0
	dd $0000
	dw 0,0,0
	dw xftVRAM16	; Transfer ScoreE2Def1 to $2000W
	dd ScoreE2Def1
	dd $2000
	dw 0,0,0
	dw xftVRAM16	; Transfer ScoreE2Map to $7c00W
	dd ScoreE2Map
	dd $7C00
	dw 0,0,0
	dw xftRAM+xftRAW	; Transfer RGB
	dd ScoreE2RGB
	dd RGBData
	dw (96*2)
	dw 0,0
	dw xftEND
	endif
;
;	* * * * * * *       SCORE E3 TRANSFER LIST       * * * * * * *
;
	if !__scoreeps >= 3
ScoreE3XFer:
	dw xftVRAM16	; Transfer ScoreE3Def0 to $0000W
	dd ScoreE3Def0
	dd $0000
	dw 0,0,0
	dw xftVRAM16	; Transfer ScoreE3Def1 to $2000W
	dd ScoreE3Def1
	dd $2000
	dw 0,0,0
	dw xftVRAM16	; Transfer ScoreE3Map to $7c00W
	dd ScoreE3Map
	dd $7C00
	dw 0,0,0
	dw xftRAM+xftRAW	; Transfer RGB
	dd ScoreE3RGB
	dd RGBData
	dw (96*2)
	dw 0,0
	dw xftEND
	endif

	if !__scoreeps >= 4
ScoreE4XFer:
	dw xftVRAM16	; Transfer ScoreE4Def0 to $0000W
	dd ScoreE4Def0
	dd $0000
	dw 0,0,0
	dw xftVRAM16	; Transfer ScoreE4Def1 to $2000W
	dd ScoreE4Def1
	dd $2000
	dw 0,0,0
	dw xftVRAM16	; Transfer ScoreE4Map to $7c00W
	dd ScoreE4Map
	dd $7C00
	dw 0,0,0
	dw xftRAM+xftRAW	; Transfer RGB
	dd ScoreE4RGB
	dd RGBData
	dw (96*2)
	dw 0,0
	dw xftEND
	endif

;
;	* * * * * * *       INDEX TO NEXT SPLAT       * * * * * * *
;
;	Per level: the level played before it (-1 = none; $8000+n = secret
;	level n, splatted only with ScoreSecret)
;
NextSplatI:
	dw -1,0,1,$8000+8,3,4,5,6,2	; E1
	dw -1,9,10,$8000+17,12,13,14,15,11	; E2
	dw -1,18,19,20,21,22,$8000+26,24,23	; E3
;
;	* * * * * * *       SCORE E1 SPLAT LIST       * * * * * * *
;
;	X,Y per level: PC intermission coordinates scaled 320x200 -> 256x224
;	(*0.8, *1.12); E2-E3 follow directly (indexed by Level*2)
;
ScoreE1Splats:
	db ($B9*$CCCC)>>16,($A4*$11EB8)>>16	; E1M1
	db ($94*$CCCC)>>16,($8F*$11EB8)>>16	; E1M2
	db ($45*$CCCC)>>16,($7A*$11EB8)>>16	; E1M3
	db ($D5*$CCCC)>>16,($66*$11EB8)>>16	; E1M4
	db ($74*$CCCC)>>16,($59*$11EB8)>>16	; E1M5
	db ($A6*$CCCC)>>16,($37*$11EB8)>>16	; E1M6
	db ($49*$CCCC)>>16,($3A*$11EB8)>>16	; E1M7
	db ($87*$CCCC)>>16,($1D*$11EB8)>>16	; E1M8
	db ($47*$CCCC)>>16,($18*$11EB8)>>16	; E1M9
;
;	* * * * * * *       SCORE E2 SPLAT LIST       * * * * * * *
;
ScoreE2Splats:
	db ($FE*$CCCC)>>16,($19*$11EB8)>>16	; E2M1
	db ($61*$CCCC)>>16,($32*$11EB8)>>16	; E2M2
	db ($BE*$CCCC)>>16,($42*$11EB8)>>16	; E2M3
	db ($80*$CCCC)>>16,($56*$11EB8)>>16	; E2M4
	db ($D6*$CCCC)>>16,($5C*$11EB8)>>16	; E2M5
	db ($85*$CCCC)>>16,($82*$11EB8)>>16	; E2M6
	db ($D0*$CCCC)>>16,($88*$11EB8)>>16	; E2M7
	db 126,182	; E2M8
;	dc.b	($94*$CCCC)>>16,($8c*$11eb8)>>16	; E2M8
	db 172,135	; E2M9
;	dc.b	($eb*$CCCC)>>16,($9e*$11eb8)>>16	; E2M9
;
;	* * * * * * *       SCORE E3 SPLAT LIST       * * * * * * *
;
ScoreE3Splats:
	db ($09C*$CCCC)>>16,($A8*$11EB8)>>16	; E3M1
	db ($030*$CCCC)>>16,($9A*$11EB8)>>16	; E3M2
	db ($0AE*$CCCC)>>16,($5F*$11EB8)>>16	; E3M3
	db ($109*$CCCC)>>16,($4B*$11EB8)>>16	; E3M4
	db ($082*$CCCC)>>16,($30*$11EB8)>>16	; E3M5
	db ($117*$CCCC)>>16,($17*$11EB8)>>16	; E3M6
	db ($0C6*$CCCC)>>16,($30*$11EB8)>>16	; E3M7
	db ($08C*$CCCC)>>16,($19*$11EB8)>>16	; E3M8
	db ($119*$CCCC)>>16,($88*$11EB8)>>16	; E3M9

;
;	* * * * * * *       EPISODE E1 END TEXT       * * * * * * *
;
	if useIMAGINEER == 0
ScoreE1Text:
	db 0
	dw ($7800+(4*32)+1)
	db "Once you beat the big badasses"
	db 0
	dw ($7800+(5*32)+1)
	db "and cleaned out the moon base"
	db 0
	dw ($7800+(6*32)+1)
	db "you're supposed to win, aren't"
	db 0
	dw ($7800+(7*32)+1)
	db "you?  Aren't you?"

	db 0
	dw ($7800+(9*32)+1)
	db "Where's your fat reward and"
	db 0
	dw ($7800+(10*32)+1)
	db "ticket home?  What the hell"
	db 0
	dw ($7800+(11*32)+1)
	db "is this?  It's not supposed"
	db 0
	dw ($7800+(12*32)+1)
	db "to end this way!"

	db 0
	dw ($7800+(14*32)+1)
	db "It stinks like rotten meat,"
	db 0
	dw ($7800+(15*32)+1)
	db "but looks like the lost Deimos"
	db 0
	dw ($7800+(16*32)+1)
	db "base.  Looks like you're stuck"
	db 0
	dw ($7800+(17*32)+1)
	db "on The Shores of Hell.  The"
	db 0
	dw ($7800+(18*32)+1)
	db "only way out is through."

	db 0
	dw ($7800+(20*32)+1)
	db "Continue the DOOM experience"
	db 0
	dw ($7800+(21*32)+1)
	db "and play The Shores of Hell"
	db 0
	dw ($7800+(22*32)+1)
	db "and its sequel, Inferno!"
	db -1
	endif

	if useIMAGINEER != 0
ScoreE1Text:
	db 0
	dw ($7800+(4*32)+1)
	db "You have won over the Knee-"
	db 0
	dw ($7800+(5*32)+1)
	db "Deep in the Dead boss."
	db 0
	dw ($7800+(7*32)+1)
	db "This is not the end."
	db 0
	dw ($7800+(9*32)+1)
	db "You will now enter The Shores"
	db 0
	dw ($7800+(10*32)+1)
	db "of Hell."
	db -1
	endif

;
;	* * * * * * *       EPISODE E2 END TEXT       * * * * * * *
;
	if useIMAGINEER == 0
ScoreE2Text:
	db 0
	dw ($7800+(4*32)+1)
	db "You've done it!  The hideous"
	db 0
	dw ($7800+(5*32)+1)
	db "cyberdemon lord that ruled"
	db 0
	dw ($7800+(6*32)+1)
	db "the lost Deimos moon base has"
	db 0
	dw ($7800+(7*32)+1)
	db "been slain and now you are"
	db 0
	dw ($7800+(8*32)+1)
	db "triumphant!  But...where are"
	db 0
	dw ($7800+(9*32)+1)
	db "you?  You clamber to the edge"
	db 0
	dw ($7800+(10*32)+1)
	db "of the moon and look down to"
	db 0
	dw ($7800+(11*32)+1)
	db "see the awful truth."

	db 0
	dw ($7800+(13*32)+1)
	db "Deimos floats above Hell"
	db 0
	dw ($7800+(14*32)+1)
	db "itself!  You've never heard"
	db 0
	dw ($7800+(15*32)+1)
	db "of anyone escaping from Hell,"
	db 0
	dw ($7800+(16*32)+1)
	db "but you'll make them sorry"
	db 0
	dw ($7800+(17*32)+1)
	db "they ever heard of you!"
	db 0
	dw ($7800+(18*32)+1)
	db "Quickly, you rappel down to"
	db 0
	dw ($7800+(19*32)+1)
	db "the surface of Hell."

	db 0
	dw ($7800+(21*32)+1)
	db "Now, it's on to the final"
	db 0
	dw ($7800+(22*32)+1)
	db "chapter of DOOM! -- Inferno."
	db -1
	endif

	if useIMAGINEER != 0
ScoreE2Text:
	db 0
	dw ($7800+(4*32)+1)
	db "You have won over The Shores"
	db 0
	dw ($7800+(5*32)+1)
	db "of Hell boss."
	db 0
	dw ($7800+(7*32)+1)
	db "This is not the end."
	db 0
	dw ($7800+(9*32)+1)
	db "You will now enter Inferno."
	db -1
	endif


;
;	* * * * * * *       EPISODE E3 END TEXT       * * * * * * *
;
	if useIMAGINEER == 0
ScoreE3Text:
	db 0
	dw ($7800+(4*32)+1)
	db "The loathsome spiderdemon that"
	db 0
	dw ($7800+(5*32)+1)
	db "masterminded the invasion of"
	db 0
	dw ($7800+(6*32)+1)
	db "the moon bases and caused so"
	db 0
	dw ($7800+(7*32)+1)
	db "much death has been beaten for"
	db 0
	dw ($7800+(8*32)+1)
	db "all time."

	db 0
	dw ($7800+(10*32)+1)
	db "A hidden doorway opens and you"
	db 0
	dw ($7800+(11*32)+1)
	db "enter.  You've proven far too"
	db 0
	dw ($7800+(12*32)+1)
	db "tough for Hell to contain, and"
	db 0
	dw ($7800+(13*32)+1)
	db "now Hell at last plays fair --"
	db 0
	dw ($7800+(14*32)+1)
	db "for you emerge from the door"
	db 0
	dw ($7800+(15*32)+1)
	db "to see the green fields of"
	db 0
	dw ($7800+(16*32)+1)
	db "Earth!  Home at last."

	db 0
	dw ($7800+(18*32)+1)
	db "I wonder what's been happening"
	db 0
	dw ($7800+(19*32)+1)
	db "on Earth while you battled the"
	db 0
	dw ($7800+(20*32)+1)
	db "evil unleashed.  It's a good"
	db 0
	dw ($7800+(21*32)+1)
	db "thing that no Hell-spawn could"
	db 0
	dw ($7800+(22*32)+1)
	db "have come through that door"
	db 0
	dw ($7800+(23*32)+1)
	db "with you ..."
	db -1
	endif

	if useIMAGINEER != 0
ScoreE3Text:
	db 0
	dw ($7800+(4*32)+1)
	db "Congratulations!  You have"
	db 0
	dw ($7800+(5*32)+1)
	db "won over the final boss."
	db 0
	dw ($7800+(7*32)+1)
	db "You have now cleared all the"
	db 0
	dw ($7800+(8*32)+1)
	db "levels."
	db 0
	dw ($7800+(10*32)+1)
	db "Because you are now the Super"
	db 0
	dw ($7800+(11*32)+1)
	db "Soldier, you can finish here."
	db -1
	endif

	if !NUMLEVELS > 27
ScoreE4Text:	; (this port, from the data set: Ultimate DOOM E4; DOOM II sets: the end)
	incbin "data/RLDATA/ART/ScoreE4.txt"
	endif


;
;	* * * * * * *       SCORE DATA       * * * * * * *
;
	%section(SCORE_DATA)
ScoreDef:
	incbin "data/RLDATA/COMP/Score.def0"
ScoreMap:
	incbin "data/RLDATA/COMP/Score.map0"
ScoreRGB:
	incbin "data/RLDATA/ART/Score.rgb":(0*2)..(0*2)+(8*2)
ScoreNumDef:
	incbin "data/RLDATA/COMP/ScoreNum.def0"
ScoreNumRGB:
	incbin "data/RLDATA/ART/ScoreNum.rgb":(0*2)..(0*2)+(8*2)
ScoreSplatDef:
	incbin "data/RLDATA/COMP/ScoreSplat.def0"
ScoreHereDef:
	incbin "data/RLDATA/COMP/ScoreHere.def0"

;
;	* * * * * * *       SCORE E1 DATA       * * * * * * *
;
	%section(SCOREE1_DATA_0)
ScoreE1Def0:
	incbin "data/RLDATA/COMP/ScoreE1.def.0"

	%section(SCOREE1_DATA_1)
ScoreE1Def1:
	incbin "data/RLDATA/COMP/ScoreE1.def.1"

	%section(SCOREE1_DATA_2)
ScoreE1Map:
	incbin "data/RLDATA/COMP/ScoreE1.map0"
ScoreE1RGB:
	incbin "data/RLDATA/ART/ScoreE1.rgb":(0*2)..(0*2)+(96*2)
;
;	* * * * * * *       SCORE E2 DATA       * * * * * * *
;
	if !__scoreeps >= 2
	%section(SCOREE2_DATA_0)
ScoreE2Def0:
	incbin "data/RLDATA/COMP/ScoreE2.def.0"

	%section(SCOREE2_DATA_1)
ScoreE2Def1:
	incbin "data/RLDATA/COMP/ScoreE2.def.1"

	%section(SCOREE2_DATA_2)
ScoreE2Map:
	incbin "data/RLDATA/COMP/ScoreE2.map0"
ScoreE2RGB:
	incbin "data/RLDATA/ART/ScoreE2.rgb":(0*2)..(0*2)+(96*2)
	endif
;
;	* * * * * * *       SCORE E3 DATA       * * * * * * *
;
	if !__scoreeps >= 3
	%section(SCOREE3_DATA_0)
ScoreE3Def0:
	incbin "data/RLDATA/COMP/ScoreE3.def.0"

	%section(SCOREE3_DATA_1)
ScoreE3Def1:
	incbin "data/RLDATA/COMP/ScoreE3.def.1"

	%section(SCOREE3_DATA_2)
ScoreE3Map:
	incbin "data/RLDATA/COMP/ScoreE3.map0"
ScoreE3RGB:
	incbin "data/RLDATA/ART/ScoreE3.rgb":(0*2)..(0*2)+(96*2)
	endif
;
;	* * * * * * *       LEVEL NAMES (this port)       * * * * * * *
;
	if !__scorenames != 0
	%section(SCORENAME_DATA)
ScoreNameRGB:
	incbin "data/RLDATA/ART/ScoreName.rgb"
ScoreNameNone:
	dw xftEND
	!__i #= 0
	while !__i < !NUMLEVELS
	if canreadfile1("data/RLDATA/COMP/ScoreName!{__i}.def0", 0)
ScoreNameX!{__i}:
	dw xftVRAM16	; Name tiles to $6800W (BG2 tile 128)
	dd ScoreNameD!{__i}
	dd $6800
	dw 0,0,0
	dw xftVRAM16	; BG2 rows 1-2
	dd ScoreNameM!{__i}
	dd $7800+(1*32)
	dw 0,0,0
	dw xftRAM+xftRAW	; BG palette 6 (its colours 7 and 11: the text font's, as set in Score)
	dd ScoreNameRGB
	dd RGBData+(96*2)
	dw (16*2)
	dw 0,0
	dw xftEND
ScoreNameD!{__i}:
	incbin "data/RLDATA/COMP/ScoreName!{__i}.def0"
ScoreNameM!{__i}:
	incbin "data/RLDATA/COMP/ScoreName!{__i}.map0"
	endif
	!__i #= !__i+1
	endwhile
ScoreNameXFers:	; per level: XFer list, bank
	!__i #= 0
	while !__i < !NUMLEVELS
	if canreadfile1("data/RLDATA/COMP/ScoreName!{__i}.def0", 0)
	dw lo16(ScoreNameX!{__i}),bank(ScoreNameX!{__i})
	else
	dw lo16(ScoreNameNone),bank(ScoreNameNone)
	endif
	!__i #= !__i+1
	endwhile
	endif

;
;	* * * * * * *       SCORE E4 DATA (Ultimate DOOM)       * * * * * * *
;
	if !__scoreeps >= 4
	%section(SCOREE4_DATA_0)
ScoreE4Def0:
	incbin "data/RLDATA/COMP/ScoreE4.def.0"

	%section(SCOREE4_DATA_1)
ScoreE4Def1:
	incbin "data/RLDATA/COMP/ScoreE4.def.1"

	%section(SCOREE4_DATA_2)
ScoreE4Map:
	incbin "data/RLDATA/COMP/ScoreE4.map0"
ScoreE4RGB:
	incbin "data/RLDATA/ART/ScoreE4.rgb":(0*2)..(0*2)+(96*2)
	endif

	endif
