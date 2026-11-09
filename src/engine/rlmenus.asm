	arch 65816
;**********************************************************************
;*                                                                    *
;*                  P R O J E C T :   REALITY_ENGINE                  *
;*                                                                    *
;*                            MENUS MODULE                            *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/snesmac.inc"
	incsrc "src/include/rlmenus.inc"
	incsrc "src/include/rlplayer.inc"
	incsrc "src/include/rlweapons.inc"
	incsrc "src/include/rlsound.inc"
	incsrc "src/include/music.inc"
	incsrc "src/include/savegame.inc"
	incsrc "data/RLDATA/COMP/menus.inc"	; (tools/menus.py)


	%section(ENGINE)
;
;	* * * * * * *       MENUS       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLMenus:
;
;	>>>   INITIALIZE MENU OPERATIONS   <<<
;
	sep #$20		; mode 'a!'
	lda.b #(4*2)	; IRQ Phase 4 (Menus)
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	sta.b IRQBPhase
	sta.b IRQTPhase
;
;	>>>   MENU SKULLS DATA   <<<
;
	rep #$20		; mode 'A!'
	ldx.w #lo16(RLMenuSkullsDef)	; Menu Skulls Data
	lda.w #(bank(MenuDeCompBuffer)<<8)|bank(RLMenuSkullsDef)
	ldy.w #lo16(MenuDeCompBuffer)
	jsl.l DeCompress
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
;
;	>>>   WAIT UNTIL *ALL* TURBOSOUNDS FINISHED!   <<<
;
_RLM200:
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	; mode 'a'
	lda.b #$80
	!rlset #= 0
	for __rep = 0..MaxRLTSounds
	and.w TSounds+rlsetFlags+(!rlset*rlsetSize)	; TurboSound Active?
	!rlset #= !rlset+1
	endfor
	bpl _RLM200	; Yes -- Wait until Completed
;
;	>>>   FADE OUT MUSIC/SOUND EFFECTS   <<<
;
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	rep #$30		; mode 'AX!'
	if useSOUND != 0
	lda.w #DCOM_FADE_AND_STOP	; Fade out Music/Sound Effects
	ldy.w #$7F01
	jsl.l _SendDriverCommandL
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	; mode 'a'
	endif
;
;	>>>   TRANSFER MENU SKULLS DATA   <<<
;
	lda.b #$E8
	sta.w COLDATA
	lda.b #bank(MenuDeCompBuffer)
	sta.w DMA0A1B
	ldx.w #lo16(MenuDeCompBuffer)
	stx.w DMA0A1L
	ldx.w #$7F80
	stx.w VMADDL
	ldx.w #(8*32)
	stx.w DMA0NUML
	lda.b #1
	sta.w MDMAEN
;
;	>>>   DISPLAY MAIN MENU   <<<
;
	rep #$20		; mode 'A!'
	lda.w _SkillLevel	; Skill Level
	sta.w MenuSkillLevel
	lda.w #bank(_RLMainMenuData)	; MAIN MENUDATA
	sta.b MenuData+2
	lda.w #lo16(_RLMainMenuData)
	stz.b MenuItem	; First Item

;
;	* * * * * * *       CHANGE MENUS       * * * * * * *
;
;	.A = MENUDATA
;
_RLMenus2:
	sta.b MenuData	; MENUDATA
	jsl.l CheatReset	; (this port) cheats.asm: no cheat begun
;
;	>>>   INITIALIZE MENU HDMA   <<<
;
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	; mode 'a'
	ldx.w #lo16(_RLMenuHDMABG12NBAAB)	; DRAWA/B or DRAWD/E?
	lda.w ViewB
	beq _RLM1300	; DRAWA/B
	ldx.w #lo16(_RLMenuHDMABG12NBADE)	; DRAWD/E
_RLM1300:
	lda.b #lo16(BG12NBA)	; BG12NBA
	sta.w DMA5DEST
	stz.w DMA5INC
	stx.w DMA5A1L
	lda.b #bank(_RLMenuHDMABG12NBAAB)
	sta.w DMA5A1B
;
	lda.b #lo16(TM)	; TM
	sta.w DMA6DEST
	stz.w DMA6INC
	ldx.w #lo16(_RLMenuHDMATM)
	stx.w DMA6A1L
	lda.b #bank(_RLMenuHDMATM)
	sta.w DMA6A1B
;
	rep #$20		; mode 'A!'
	lda.w #(MaxViewScanLines<<8)	; Remove MenuSkull
	jsr.w _RLMenuSkull2
;
;	>>>   MENU CHARACTER DATA   <<<
;
	ldy.w #rlmdMenuDef	; Menu Character Data
	lda.b [MenuData],y
	tax
	iny
	iny
	sep #$20		; mode 'a!'
	lda.b #bank(MenuDeCompBuffer)
	xba
	lda.b [MenuData],y
	rep #$20		; mode 'A!'
	ldy.w #lo16(MenuDeCompBuffer)
	jsl.l DeCompress
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	; mode 'a'
	ldx.w #lo16(MenuDeCompBuffer)	; (DMA0A1B is still bank(MenuDeCompBuffer))
	stx.w DMA0A1L
	ldx.w #vmCHRA	; DRAWA/B
	lda.w ViewB
	beq _RLM1540
	ldx.w #vmCHRD	; DRAWD/E
_RLM1540:
	stx.w VMADDL
	sty.w DMA0NUML
	lda.b #1
	sta.w MDMAEN
;
;	>>>   MENU MAP DATA   <<<
;
	rep #$20		; mode 'A!'
	ldx.w #(((RLViewCharY-RLStatCharY)*32)-1)*2
	lda.w #0
_RLM1600:
	sta.l MenuDeCompBuffer,x
	dex
	dex
	bpl _RLM1600
;
	ldy.w #rlmdMenuMap	; Menu Map Data
	lda.b [MenuData],y
	tax
	iny
	iny
	sep #$20		; mode 'a!'
	lda.b #bank(MenuDeCompBuffer)
	xba
	lda.b [MenuData],y
	rep #$20		; mode 'A!'
	ldy.w #lo16(MenuDeCompBuffer)
	jsl.l DeCompress
	lda.w ViewB	; DRAWA/B?
	and.w #$00FF
	beq _RLM1640	; Yes, Don't Adjust Characters
	ldx.w #(((RLViewCharY-RLStatCharY)*32)-1)*2	; Adjust Base of Characters
_RLM1620:
	lda.l MenuDeCompBuffer,x
	clc
	adc.w #((vmCHRD-((vmCHRD>>12)<<12))/(32/2))
	sta.l MenuDeCompBuffer,x
	dex
	dex
	bpl _RLM1620
_RLM1640:
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	; mode 'a'
	ldx.w #lo16(MenuDeCompBuffer)
	stx.w DMA0A1L
	ldx.w #(vmMAP2+(4*32*2/2))
	stx.w VMADDL
	ldx.w #((RLViewCharY-RLStatCharY)*32*2)
	stx.w DMA0NUML
	lda.b #1
	sta.w MDMAEN
	lda.b #%01100000	; Enable HDMAs
	sta.w HDMAEN_S
	sta.w HDMAEN
;
	ldy.w #rlmdItems	; Maximum Item#
	lda.b [MenuData],y
	sta.b MenuMaxItem
;
;	>>>   INITIALIZE HDMA TM   <<<
;
	rep #$20		; mode 'A!'
	ldy.w #rlmdMenuHDMATM	; MENUDATA HDMATM Table
	lda.b [MenuData],y
	sta.b Temp
	iny
	iny
	lda.b [MenuData],y
	sta.b Temp+2
	ldy.w #128-2	; Copy HDMATM Table to RAM
	tyx
_RLM1720:
	lda.b [Temp],y
	sta.l MenuHDMATM,x
	dey
	dey
	dex
	dex
	bpl _RLM1720
;
	pea.w lo16(_RLM1800-1)	; Return Address
	ldy.w #rlmdInitCode	; MENUINIT CODE
	lda.b [MenuData],y
	pha
	rts
;
;	>>>   DISPLAY MENU!   <<<
;
_RLM1800:
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	; mode 'a'
	ldx.w #lo16(MenuHDMATM)
	stx.w DMA6A1L
	lda.b #bank(MenuHDMATM)
	sta.w DMA6A1B
_RLM1900:
	ldx.w PlayerJoy	; Wait for PAUSE Released
	bne _RLM1900
	stx.b MenuJoyOld	; Old Joystick Bits

;
;	* * * * * * *       MENU OPERATION       * * * * * * *
;
_RLM2000:
	rep #$20		; mode 'A!'
	lda.b MenuItem	; Position MenuSkull
	jsr.w _RLMenuSkull
	lda.w JOY1Stat	; JOY1Status
	and.w #$00FF
	beq _RLM2200	; Joystick ($00)?  Else MOUSE
	lda.w PlayerJoy	; Mouse Buttons: USE = Back, FIRE = Accept
	cmp.w #pjUSE
	bne _RLM2100
	lda.w #joyB
_RLM2100:
	cmp.w #pjFIRE
	bne _RLM2120
	lda.w #joyA
_RLM2120:
	ldx.w PlayerMouseY	; Menu Selection Change?
	bne _RLM2500
	bra _RLM2400
_RLM2200:
	lda.w JOY1
_RLM2400:
	cmp.b MenuJoyOld	; Same as Last?
	beq _RLM2000	; Yes, Wait for Change!
_RLM2500:
	sta.b MenuJoyOld
	jsl.l CheatPress	; (this port) cheats.asm: taken by a cheat?
	bcs _RLM2000	; Yes, Wait for Change!
	lda.b MenuJoyOld

;
;	* * * * * * *       ESCAPE       * * * * * * *
;
_RLM3000:
	bit.w #joySTART	; ESCAPE?
	bne _RLM3800	; YES!
;
;	* * * * * * *       ITEM USE       * * * * * * *
;
	lda.b MenuJoyOld	; ACCEPT?
	bit.w #joyA
	beq _RLM4000
	lda.b MenuItem	; MENUITEM * 8
	asl a
	asl a
	asl a
;	clc					; Move to MENUITEM DATA
	adc.w #rlmdItemData
	tay
_RLM3500:
	pea.w lo16(_RLM3600-1)	; Return Address
	lda.b [MenuData],y	; MENUITEM CODE
	pha
	rts
_RLM3600:
	bcc _RLM2000	; MENU EXIT?
_RLM3800:
	jmp.w _RLM9000	; EXIT MENUS!

;
;	* * * * * * *       MENU BACK       * * * * * * *
;
_RLM4000:
	bit.w #joyB	; MENU BACK?
	beq _RLM5000
	ldy.w #rlmdBackCode	; MENUBACK CODE
	lda.b [MenuData],y
	pha
	rts

;
;	* * * * * * *       MENU KEYS       * * * * * * *
;
_RLM5000:
	sta.b Temp	; Save Joystick Bits
	ldy.w #rlmdItems	; Move to MenuKeys
	lda.b [MenuData],y
	and.w #$00FF
	asl a
	asl a
	asl a
;	clc					; Move to MENUKEYS DATA
	adc.w #rlmdItemData
	tay
_RLM5200:
	lda.b [MenuData],y	; End of MenuKeys?
	beq _RLM6000	; Yes
	iny
	iny
	cmp.b Temp	; Match?
	beq _RLM3500	; Yes!
	iny	; No, Check Next MenuKeys
	iny
	bra _RLM5200

;
;	* * * * * * *       ITEM UP       * * * * * * *
;
_RLM6000:
	sep #$20		; mode 'a!'
	lda.b MenuItem	; Current MenuItem
	ldx.w PlayerMouseY	; UP?
	bmi _RLM6200
	cpx.w #(($03C0<<1)/2)
	bcc _RLM7800
	dec a
	bpl _RLM7000
	lda.b MenuMaxItem
	dec a
	bra _RLM7000
;
;	* * * * * * *       ITEM DOWN       * * * * * * *
;
_RLM6200:
	cpx.w #-(($03C0<<1)/2)+1	; DOWN?
	bcs _RLM7800
	inc a
	cmp.b MenuMaxItem
	bne _RLM7000
	lda.b #0
;
;	* * * * * * *       ITEM UP/DOWN       * * * * * * *
;
_RLM7000:
	sta.b MenuItem	; New MenuItem
_RLM7800:
	jmp.w _RLM2000	; NEXT MENU OPERATION

;
;	* * * * * * *       FINISHED WITH MENUS       * * * * * * *
;
_RLM9000:
	rep #$30		; mode 'AX!'
_RLM9020:
	lda.w PlayerJoy	; Wait for Buttons Released
	bne _RLM9020
;
;	>>>   START MUSIC/SOUND EFFECTS   <<<
;
	if useSOUND != 0
	lda.w _MusicOn	; Music Enabled?
	beq _RLM9100	; No
	ldy.w _MDSong	; Get Song# to Play
	lda.w #DCOM_START_SONG
	jsl.l _SendDriverCommandL
	jsr.w _RLMenuWaitVBlank
	jsr.w _RLMenuWaitVBlank
	rep #$20		; mode 'A!'
_RLM9100:
	lda.w #DCOM_FADEIN	; Fade in Music/Sound Effects
	ldy.w #$7F01
	jsl.l _SendDriverCommandL
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	jsr.w _RLMenuWaitVBlank
	rep #$20		; mode 'A!'
	endif
;
;	>>>   UPDATE VARIABLES   <<<
;
	lda.w WeaponNext+!RLSNESGSUXVarsO	; Next Weapon
	sta.l WeaponNext
	lda.w ExitLevel+!RLSNESGSUXVarsO	; Level Completed
	sta.l ExitLevel
	jsl.l CheckSumVars	; ReCalculate VARS CheckSum
	jsl.l RestoreVars	; Set VARS
;
;	>>>   REBUILD STATUS BAR OVERLAY   <<<
;
	lda.w #((vmCHR2B-vmCHR2)/(32/2))+$2000	; BG2 View Overlay
	ldx.w #(((RLViewCharY-RLStatCharY)*32)-1)*2
_RLM9200:
	sta.l MenuDeCompBuffer,x
	dex
	dex
	bpl _RLM9200
;
	lda.w #(MaxViewScanLines<<8)	; Remove MenuSkull
	jsr.w _RLMenuSkull2
	sep #$20		; mode 'a!'
	stz.w HDMAEN_S	; Disable HDMAs
	stz.w HDMAEN	; Stop Active HDMAs before GDMA!
	ldx.w #lo16(MenuDeCompBuffer)
	ldy.w #(vmMAP2+(4*32*2/2))
	lda.b #$E0
	sta.w COLDATA
	lda.b #$13
	sta.w TM
	lda.b #(((vmCHR2>>12)<<4)|(vmCHR1>>12))
	sta.w BG12NBA
	stx.w DMA0A1L
	sty.w VMADDL
	ldx.w #((RLViewCharY-RLStatCharY)*32*2)
	stx.w DMA0NUML
	lda.b #1
	sta.w MDMAEN
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	; mode 'a'
;
;	>>>   RESTORE HARDWARE   <<<
;
	jml.l _RLInitDMA	; ReInitialize GDMA Channels


;
;	* * * * * * *       MENU WAIT FOR VERTICAL BLANK       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLMenuWaitVBlank:
	sep #$20		; mode 'a!'
_RLMWVB200:
	bit.w _HVBJOY	; Wait for NOT VBlank
	bmi _RLMWVB200
_RLMWVB400:
	bit.w _HVBJOY	; Wait for VBlank
	bpl _RLMWVB400
	rts


;
;	* * * * * * *       MENU SKULL       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
_RLMenuSkull:
	asl a
	asl a
	asl a
;	clc					; Move to MENUITEM DATA
	adc.w #(rlmdItemData+6)
	tay
	lda.b [MenuData],y	; MENUITEM SPRITE POSITION
_RLMenuSkull2:
	pha
	lda.w VBlankCount	; Animate MenuSkull
	lsr a
	lsr a
	lsr a
	and.w #$0002
	clc
	adc.w #$00F8
	tax
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	rep #$20		; mode 'A!'
	pla
	jsl.l MenuSkullSprites
	rep #$30		; mode 'AX!'
	rts

;
;	* * * * * * *       MENU SKULL SPRITES (PAUSE MENU AND TITLE MENU)       * * * * * * *
;
;	(this port: shared with title.asm) in VBlank: the skull as sprites 124-127,
;	.A = (Y<<8)|X of its top left, .X = the top left tile (the tiles: +0 +1 / +4 +5;
;	name table 1, palette 0, priority 3).
;
	; dbr ?
	; mode 'AX'
MenuSkullSprites:
	php
	ldy.w #((128-4)*2)
	sty.w OAMADDL
	sep #$30		; mode 'ax!'
;
	sta.w OAMDATA	; Top left
	xba
	sta.w OAMDATA
	xba
	stx.w OAMDATA
	ldy.b #$31
	sty.w OAMDATA
;
	clc	; Top right
	adc.b #8
	sta.w OAMDATA
	xba
	sta.w OAMDATA
	clc
	adc.b #8
	xba
	inx
	stx.w OAMDATA
	sty.w OAMDATA
;
	sta.w OAMDATA	; Bottom right
	xba
	sta.w OAMDATA
	xba
	inx
	inx
	inx
	inx
	stx.w OAMDATA
	sty.w OAMDATA
;
	sec	; Bottom left
	sbc.b #8
	sta.w OAMDATA
	xba
	sta.w OAMDATA
	dex
	stx.w OAMDATA
	sty.w OAMDATA
;
	plp
	rtl


;
;	* * * * * * *       MENU TOGGLE       * * * * * * *
;
	; mode 'AX'
_RLMenuToggle:
	iny	; Get Variable to Toggle
	iny
	lda.b [MenuData],y
	sta.b Temp
	lda.b (Temp)
	eor.w #$FFFF
	sta.b (Temp)
_RLMenuToggle2:
	lda.b [MenuData],y	; Get Variable to Update
	sta.b Temp
	lda.b (Temp)
	and.w #$0001	; Off: tiles 0-5, On: tiles 6-11
	beq ._1
	lda.w #(6*2)
._1:
	tax
	lda.w ViewB	; DRAWD/E? Adjust Base of Characters
	and.w #$00FF
	beq ._0
	lda.w #((vmCHRD-((vmCHRD>>12)<<12))/(32/2))
._0:
	sta.b Temp
	iny	; Get VRAM Address to Update
	iny
	lda.b [MenuData],y
	clc
	adc.w #(vmMAP2+(4*32*2/2))
	sta.b Temp+2
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	rep #$20		; mode 'A!'
	lda.b Temp+2	; 3x2 tiles (tools/menus.py, tools/wad2art.py)
	sta.w VMADDL
	lda.l _RLMenuToggleTiles+0,x
	clc
	adc.b Temp
	sta.w VMDATAL
	lda.l _RLMenuToggleTiles+2,x
	clc
	adc.b Temp
	sta.w VMDATAL
	lda.l _RLMenuToggleTiles+4,x
	clc
	adc.b Temp
	sta.w VMDATAL
	lda.b Temp+2
	clc
	adc.w #((32*2)/2)
	sta.w VMADDL
	lda.l _RLMenuToggleTiles+6,x
	clc
	adc.b Temp
	sta.w VMDATAL
	lda.l _RLMenuToggleTiles+8,x
	clc
	adc.b Temp
	sta.w VMDATAL
	lda.l _RLMenuToggleTiles+10,x
	clc
	adc.b Temp
	sta.w VMDATAL
	clc
	rts


;
;	>>>   ON/OFF GLYPHS: 3x2 tiles each (row 0 col 0-2, row 1 col 0-2)   <<<
;
_RLMenuToggleTiles:
	dw !MENUTOG_off00,!MENUTOG_off01,!MENUTOG_off02,!MENUTOG_off10,!MENUTOG_off11,!MENUTOG_off12
	dw !MENUTOG_on00,!MENUTOG_on01,!MENUTOG_on02,!MENUTOG_on10,!MENUTOG_on11,!MENUTOG_on12


;	* * * * * * *       MAIN MENU CODE       * * * * * * *
;
;	>>>   INITIALIZE   <<<
;
	; mode 'AX'
_RLMMCInit:
	ldy.w #(_RLMainMenuMusicData-_RLMainMenuData)	; Music On/Off
	jsr.w _RLMenuToggle2
	ldy.w #(_RLMainMenuSoundsData-_RLMainMenuData)	; Sounds On/Off
	jsr.w _RLMenuToggle2
	ldy.w #(_RLMainMenuRumbleData-_RLMainMenuData)	; Rumble On/Off
	jmp.w _RLMenuToggle2
;
;	>>>   RESTART LEVEL   <<<
;
	; mode 'AX'
_RLMMCReStartLevel:
	lda.w #-1	; RESTART LEVEL!
	sta.w ExitLevel+!RLSNESGSUXVarsO
	sec
	rts

	if (0*!DEBUG) != 0
;
;	>>>   NEXT LEVEL   <<<
;
	; mode 'AX'
_RLMMCNextLevel:
	lda.w #11	; NEXT LEVEL!
	sta.w ExitLevel+!RLSNESGSUXVarsO
;	sec
;	rts
;
;	>>>   HEALTH 100%   <<<
;
	; mode 'AX'
_RLMMCHealth:
	lda.w #500	; HEALTH 100%
	sta.l PlayerObject+rloHealth
	sec
	rts
	endif

;
;	>>>   NEW GAME   <<<
;
	; mode 'AX'
_RLMMCNewGame:
	pla	; Fix Stack
_RLEMCSkillMenu:
	lda.w MenuSkillLevel	; Item
	sta.b MenuItem
	lda.w #lo16(_RLSkillMenuData)	; SKILL MENU!
	jmp.w _RLMenus2
;
;	>>>   WEAPON CYCLE   <<<
;
	; mode 'AX'
_RLMMCWeaponCycle:
	lda.w PlayerHealth+!RLSNESGSUXVarsO	; Player Dead?
	beq _RLMMCW400	; Yes, Don't Switch Weapon!
	ldx.w WeaponNext+!RLSNESGSUXVarsO	; Next Weapon
	if !RLDOOM2MONSTERS != 0
	cpx.w #wtSuperShotGun	; (DOOM II: on from the Shotgun's place)
	bne _RLMMCW150
	ldx.w #wtShotGun
_RLMMCW150:
	endif
	lda.l PlayerArms	; Player's Weapon
	sta.b Temp
_RLMMCW200:
	inx	; Cycle Next Weapon
	inx
	lda.l _WeaponTypeBitsTable,x	; Does Player have this Weapon?
	bit.b Temp
	beq _RLMMCW200	; No
	txa	; New Next Weapon
	and.w #15	; Limit to Maximum Weapons
	sta.w WeaponNext+!RLSNESGSUXVarsO
_RLMMCW300:
	cmp.b WeaponNextOld	; Wait for WeaponChange
	bne _RLMMCW300
_RLMMCW400:
	clc
	rts


;
;	* * * * * * *       SKILL MENU CODE       * * * * * * *
;
;	>>>   INITIALIZE   <<<
;
	; mode 'AX'
_RLSMCInit:
	rts
;
;	>>>   SKILL LEVEL   <<<
;
	; mode 'AX'
_RLSMCSkillLevel:
	!__d2 #= 0
	if defined("RLEPISODELEN")	; (levels.inc)
	if !RLEPISODELEN == 99
	!__d2 #= 1
	endif
	endif
	if !__d2 != 0	; (DOOM II/TNT/Plutonia: no episodes, as on the PC:
	lda.b MenuItem	;  the skill starts MAP01, see _RLEMCEpisode)
	sta.w MenuSkillLevel
	sta.w _SkillLevel
	lda.w #($4C52&$00FF)	; NEW GAME! (level 0)
	sta.w ExitLevel+!RLSNESGSUXVarsO
	sec
	rts
	endif
	pla	; Fix Stack
	lda.b MenuItem	; Remember Skill Level
	sta.w MenuSkillLevel
	stz.b MenuItem
	lda.w #lo16(_RLEpisodeMenuData)	; EPISODE MENU!
	jmp.w _RLMenus2
;
;	>>>   MAIN MENU   <<<
;
	; mode 'AX'
_RLSMCMainMenu:
	stz.b MenuItem
	lda.w #lo16(_RLMainMenuData)	; MAIN MENU!
	jmp.w _RLMenus2


;
;	* * * * * * *       SAVE/LOAD GAME (this port: PC style slots)       * * * * * * *
;
;	>>>   MAIN MENU ITEMS   <<<
;
	; mode 'AX'
_RLMMCSaveGame:
	lda.w PlayerHealth+!RLSNESGSUXVarsO	; Player Dead?
	beq _RLSMC900	; Yes, can't save
	pla	; Fix Stack
	stz.b MenuItem
	lda.w #lo16(_RLSaveMenuData)	; SAVE MENU!
	jmp.w _RLMenus2
_RLMMCLoadGame:
	pla	; Fix Stack
	stz.b MenuItem
	lda.w #lo16(_RLLoadMenuData)	; LOAD MENU!
	jmp.w _RLMenus2
_RLSMC900:
	clc
	rts
;
;	>>>   SLOT MENU: WRITE THE SLOT LINES (SAVESLOTS)   <<<
;
	; mode 'AX'
_RLSlotMenuInit:
	lda.w ViewB	; DRAWD/E? Adjust Base of Characters
	and.w #$00FF
	beq ._0
	lda.w #((vmCHRD-((vmCHRD>>12)<<12))/(32/2))
._0:
	ora.w #!SLOTFONT_PAL
	ldx.w #lo16(MenuDeCompBuffer)+((((3*32)+6)*2))	; Into the menu's map (row 3, column 6)
	ldy.w #0	; Blank: entry 0
	jsl.l SlotMenuLines
	jsr.w _RLMenuWaitVBlank	; Wait for VBlank
	; mode 'a'
	lda.b #$80	; Map rows 3.. to VRAM
	sta.w VMAINC
	ldx.w #(vmMAP2+(4*32*2/2))+(3*32)
	stx.w VMADDL
	lda.b #%00000001	; A->B, 1-Add-Write2x
	sta.w DMA0INC
	lda.b #lo16(VMDATAL)
	sta.w DMA0DEST
	ldx.w #lo16(MenuDeCompBuffer)+(3*32*2)
	stx.w DMA0A1L
	lda.b #bank(MenuDeCompBuffer)
	sta.w DMA0A1B
	ldx.w #(SAVESLOTS*2*32*2)
	stx.w DMA0NUML
	lda.b #1
	sta.w MDMAEN
	rep #$30		; mode 'AX!'
	rts
;
;	* * * * * * *       SLOT MENU LINES (PAUSE MENU AND TITLE MENU)       * * * * * * *
;
;	(this port: shared with title.asm) writes the SAVESLOTS slot lines ("E1M3 TOXIN
;	REFINERY" / "EMPTY SLOT", savegame.asm SaveSlotText) into a 32-wide BG map in
;	bank(MenuDeCompBuffer): .X = the entry of slot 0's first character, .A = added
;	to the slot font's tile# (tile base, palette, priority), .Y = the entry of a
;	blank.  The lines are two map rows apart; each ends with its text.
;
	; dbr ?
	; dpr 0
	; mode 'AX'
SlotMenuLines:
	php
	rep #$30		; mode 'AX!'
	sta.b Temp4+4	; Tile base
	sty.b Temp4+2	; Blank
	stx.b Temp4+0	; Slot 0's line
	stz.b Temp4+6	; Slot#
.slot:
	lda.b Temp4+6
	jsl.l SaveSlotText	; SaveText = "E1M3 TOXIN REFINERY" / "EMPTY SLOT"
	rep #$30		; mode 'AX!'
	ldx.b Temp4+0
	ldy.w #0
.char:
	phx
	tyx
	lda.l SaveText,x	; Next Character
	plx
	and.w #$00FF
	beq .next
	sec
	sbc.w #32
	cmp.w #(91-32)
	bcc ._1
	lda.w #0	; (space)
._1:
	phx
	tax
	lda.l _RLSlotFontTable,x
	plx
	and.w #$00FF
	beq ._2	; blank stays blank
	clc
	adc.b Temp4+4
	bra ._3
._2:
	lda.b Temp4+2
._3:
	sta.l (bank(MenuDeCompBuffer)<<16),x
	inx
	inx
	iny
	cpy.w #26
	bcc .char
.next:
	lda.b Temp4+0	; Next line: two map rows down
	clc
	adc.w #(2*32*2)
	sta.b Temp4+0
	inc.b Temp4+6
	lda.b Temp4+6
	cmp.w #SAVESLOTS
	bcc .slot
	plp
	rtl
;
;	>>>   SAVE INTO THE SELECTED SLOT   <<<
;
	; mode 'AX'
_RLSMCSave:
	lda.b MenuItem	; Slot
	jsl.l SaveGame	; State packed; the save is finished after the level
	rep #$30		; mode 'AX!'	;  is set up again (savegame.asm SaveRestore;
	bcs ._full	;  SaveMessage shows "GAME SAVED.")
	lda.w #$004C	; Restart the level as LOAD GAME does
	sta.w ExitLevel+!RLSNESGSUXVarsO
	sec	; Back to the game
	rts
._full:
	lda.w #lo16(NOROOMMSGA)	; "NOT ENOUGH ROOM TO SAVE."
	ldx.w #lo16(NOROOMMSGB)
	ldy.w #lo16(NOROOMMSGC)
_RLSMC800:
	sta.l MsgDataA
	txa
	sta.l MsgDataB
	tya
	sta.l MsgDataC
	lda.w #(3*60)	; Display Message for 3 Seconds
	sta.l MsgCount
	sec	; Back to the game
	rts
;
;	>>>   LOAD THE SELECTED SLOT   <<<
;
	; mode 'AX'
_RLSMCLoad:
	lda.b MenuItem	; Slot
	jsl.l LoadGame	; Level, inventory and skill are set
	rep #$30		; mode 'AX!'
	bcc ._ok
	clc	; empty/damaged slot: stay in the menu
	rts
._ok:
	lda.w #$004C	; LOAD GAME! (rage.asm restarts the level, then
	sta.w ExitLevel+!RLSNESGSUXVarsO	; SaveRestore puts its saved state back)
	sec
	rts


;
;	* * * * * * *       EPISODE MENU CODE       * * * * * * *
;
;	>>>   INITIALIZE   <<<
;
	; mode 'AX'
_RLEMCInit:
	sep #$20		; mode 'a!'

	!__epgate #= 0
	if useIMAGINEER == 0
	if !RLSKILLEPISODES != 0
	!__epgate #= 1
	endif
	endif
	if !__epgate != 0
	lda.b #1	; Episode1 Only
	ldy.w #(((RLViewCharY-(5+4))*8)<<8)|(RLVIntTop+((5+4)*8))
	ldx.w MenuSkillLevel	; Skill Level
	cpx.w #2
	bcc _RLEMCInit2
	inc a	; Episode1/2
	ldy.w #(((RLViewCharY-(7+4))*8)<<8)|(RLVIntTop+((7+4)*8))
	cpx.w #3
	bcc _RLEMCInit2
	inc a	; Episode1/2/3
	endif
	if !__epgate == 0
	!__epmenu #= 0
	if defined("RLEPISODES")	; (levels.inc: fewer episodes than slots, 1-3)
	!__epmenu #= 1
	if defined("RLORDERSCREEN")	; (the shareware set: every episode in the menu; one
	!__epmenu #= 0	;  it does not have shows the order screen, rage.asm)
	endif
	endif
	if !__epmenu != 0
	assert !RLEPISODES >= 1 && !RLEPISODES <= 3, "RLEPISODES: 1-3"
	lda.b #!RLEPISODES
	ldy.w #(((RLViewCharY-((3+2*!RLEPISODES)+4))*8)<<8)|(RLVIntTop+(((3+2*!RLEPISODES)+4)*8))
	bra _RLEMCInit2
	endif
	lda.b #(!NUMLEVELS/9)	; Every Episode (Ultimate DOOM: every skill)
	endif
	ldy.w #(((RLViewCharY-(9+4))*8)<<8)|(RLVIntTop+((9+4)*8))
	if !__epgate == 0
	if !NUMLEVELS > 27	; 4 episodes: the menu is 2 rows taller; an HDMA line
	sta.b MenuMaxItem	; count is 7 bits, so the top part takes two entries
	rep #$20		; mode 'A!'
	lda.w #$1300|$7F	; 127 lines BG1+BG2+OBJ
	sta.l MenuHDMATM+0
	lda.w #$1300|(RLVIntTop+((12+4)*8)-$7F)	; and the rest of the menu
	sta.l MenuHDMATM+2
	lda.w #$1100|((RLViewCharY-(12+4))*8)	; BG1+OBJ below the menu
	sta.l MenuHDMATM+4
	lda.w #$1301	; BG1+BG2+OBJ at StatusBar
	sta.l MenuHDMATM+6
	lda.w #$0000	; END
	sta.l MenuHDMATM+8
	rts
	endif
	endif

_RLEMCInit2:
	sta.b MenuMaxItem
	rep #$20		; mode 'A!'
	tya
	sep #$20		; mode 'a!'
	sta.l MenuHDMATM+0
	xba
	sta.l MenuHDMATM+2
	rep #$20		; mode 'A!'
	rts
;
;	>>>   EPISODE   <<<
;
	; mode 'AX'
_RLEMCEpisode:
	lda.w MenuSkillLevel	; Skill Level
	sta.w _SkillLevel
	lda.b MenuItem	; Episode*9
	asl a
	asl a
	asl a
;	clc
	adc.b MenuItem
	xba
	ora.w #($4C52&$00FF)	; NEW GAME!
	sta.w ExitLevel+!RLSNESGSUXVarsO
	sec
	rts


;
;	* * * * * * *       MENU SKULLS       * * * * * * *
;
RLMenuSkullsDef:
	incbin "data/RLDATA/COMP/MenuSkulls.def0"


;
;	* * * * * * *       MENU HDMA TABLES       * * * * * * *
;
_RLMenuHDMATM:
	db 127	; BG1+OBJ at Top
	db $11
	db (RLVIntBottom-RLStatPixY-127)
	db $11
	db $01	; BG1+BG2+OBJ at StatusBar
	db $13
	db $00	; END

_RLMenuHDMABG12NBAAB:
	db 127	; Overwrite CHRA/CHRB
	db (((vmCHRA>>12)<<4)|(vmCHR1>>12))
	db (RLVIntBottom-RLStatPixY-127)
	db (((vmCHRA>>12)<<4)|(vmCHR1>>12))
	db $01
	db (((vmCHR2>>12)<<4)|(vmCHR1>>12))
	db $00	; END
_RLMenuHDMABG12NBADE:
	db 127	; Overwrite CHRD/CHRE
	db (((vmCHRD>>12)<<4)|(vmCHR1>>12))
	db (RLVIntBottom-RLStatPixY-127)
	db (((vmCHRD>>12)<<4)|(vmCHR1>>12))
	db $01
	db (((vmCHR2>>12)<<4)|(vmCHR1>>12))
	db $00	; END


;
;	* * * * * * *       MENUDATA TABLES       * * * * * * *
;

;
;	* * * * * * *       SAVE/LOAD MENUS       * * * * * * *
;
_RLSaveMenuData:
	dl RLSaveMenuMap	; Menu VRAM Map
	dl RLSlotMenuDef	; Menu VRAM Def
	dl RLSlotMenuHDMATM	; Menu HDMATM Table
	dw lo16(_RLSlotMenuInit-1)	; Menu InitCode
	dw lo16(_RLSMCMainMenu-1)	; Menu BackCode
	db SAVESLOTS	; #Items
	!__i #= 0
	while !__i < SAVESLOTS
	dw lo16(_RLSMCSave-1)	; Slot
	dw 0,0,(((3+(2*!__i))*8+52)<<8)+51
	!__i #= !__i+1
	endwhile
	dw 0	; MenuKeys Terminator

_RLLoadMenuData:
	dl RLLoadMenuMap	; Menu VRAM Map
	dl RLSlotMenuDef	; Menu VRAM Def
	dl RLSlotMenuHDMATM	; Menu HDMATM Table
	dw lo16(_RLSlotMenuInit-1)	; Menu InitCode
	dw lo16(_RLSMCMainMenu-1)	; Menu BackCode
	db SAVESLOTS	; #Items
	!__i #= 0
	while !__i < SAVESLOTS
	dw lo16(_RLSMCLoad-1)	; Slot
	dw 0,0,(((3+(2*!__i))*8+52)<<8)+51
	!__i #= !__i+1
	endwhile
	dw 0	; MenuKeys Terminator


;
;	* * * * * * *       MAIN MENU       * * * * * * *
;
_RLMainMenuData:
	dl RLMainMenuMap	; Menu VRAM Map
	dl RLMainMenuDef	; Menu VRAM Def
	dl RLMainMenuHDMATM	; Menu HDMATM Table
	dw lo16(_RLMMCInit-1)	; Menu InitCode
	dw lo16(_RLM9000-1)	; Menu BackCode
;
	db 7	; #Items (cursor y: line top + 54; (this port) Music/Sounds/Rumble
	;	one lower than tools/menus.py PAUSE_TOP, as in tools/menus/PauseMenu.png)
	dw lo16(_RLMMCReStartLevel-1)	; ReStart Level
	dw 0,0,(56<<8)+64
	dw lo16(_RLMMCNewGame-1)	; New Game
	dw 0,0,(71<<8)+64
	dw lo16(_RLMMCSaveGame-1)	; Save Game
	dw 0,0,(86<<8)+64
	dw lo16(_RLMMCLoadGame-1)	; Load Game
	dw 0,0,(101<<8)+64
	dw lo16(_RLMenuToggle-1)	; Music On/Off
_RLMainMenuMusicData:
	dw _MusicOn,!MENUTOG_MUSIC,(118<<8)+64
	dw lo16(_RLMenuToggle-1)	; Sounds On/Off
_RLMainMenuSoundsData:
	dw _SoundsOn,!MENUTOG_SOUNDS,(134<<8)+64
	dw lo16(_RLMenuToggle-1)	; (this port) Rumble On/Off (rumble.asm)
_RLMainMenuRumbleData:
	dw _RumbleOn,!MENUTOG_RUMBLE,(150<<8)+64
;
	dw pjWEAPON,lo16(_RLMMCWeaponCycle-1)	; Weapon Cycle
	if (0*!DEBUG) != 0
	dw (joyL|joyR),lo16(_RLMMCNextLevel-1)	; Next Level
	dw joySELECT,lo16(_RLMMCHealth-1)	; Health 100%
	endif
	dw 0	; MenuKeys Terminator


;
;	* * * * * * *       SKILL MENU       * * * * * * *
;
_RLSkillMenuData:
	dl RLSkillMenuMap	; Menu VRAM Map
	dl RLSkillMenuDef	; Menu VRAM Def
	dl RLSkillMenuHDMATM	; Menu HDMATM Table
	dw lo16(_RLSMCInit-1)	; Menu InitCode
	dw lo16(_RLSMCMainMenu-1)	; Menu BackCode
;
	db 5	; #Items
	dw lo16(_RLSMCSkillLevel-1)	; I'm Too Young to Die
	dw 0,0,(71<<8)+44
	dw lo16(_RLSMCSkillLevel-1)	; Not Too Rough
	dw 0,0,(86<<8)+44
	dw lo16(_RLSMCSkillLevel-1)	; Hurt Me Plenty
	dw 0,0,(101<<8)+44
	dw lo16(_RLSMCSkillLevel-1)	; Ultra-Violence
	dw 0,0,(116<<8)+44
	dw lo16(_RLSMCSkillLevel-1)	; Nightmare
	dw 0,0,(132<<8)+44
;
	dw 0	; MenuKeys Terminator


;
;	* * * * * * *       EPISODE MENU       * * * * * * *
;
_RLEpisodeMenuData:
	dl RLEpisodeMenuMap	; Menu VRAM Map
	dl RLEpisodeMenuDef	; Menu VRAM Def
	dl RLEpisodeMenuHDMATM	; Menu HDMATM Table
	dw lo16(_RLEMCInit-1)	; Menu InitCode
	dw lo16(_RLEMCSkillMenu-1)	; Menu BackCode
;
	db (!NUMLEVELS/9)	; #Items
	dw lo16(_RLEMCEpisode-1)	; Knee-Deep In The Dead
	dw 0,0,(80<<8)+36
	dw lo16(_RLEMCEpisode-1)	; The Shores Of Hell
	dw 0,0,(97<<8)+36
	dw lo16(_RLEMCEpisode-1)	; Inferno
	dw 0,0,(114<<8)+36
	if !NUMLEVELS > 27
	dw lo16(_RLEMCEpisode-1)	; Thy Flesh Consumed (Ultimate DOOM)
	dw 0,0,(131<<8)+36
	endif
;
	dw 0	; MenuKeys Terminator


;
;	* * * * * * *       MAIN MENU DATA       * * * * * * *
;
	%section(RL_MAINMENU_DATA)
RLMainMenuMap:	; Restart Level/New Game/Save Game/Load Game/Music/Sounds/Rumble
	incbin "data/RLDATA/COMP/PauseMenu.map0"	; (tools/menus.py)
RLMainMenuDef:
	incbin "data/RLDATA/COMP/PauseMenu.def0"
RLMainMenuHDMATM:
	db 127	; BG1+BG2+OBJ at Top
	db $13
	db (RLVIntTop+(RLViewCharY*8))-127	; (this port: the 7 lines use every row, as the slot menu)
	db $13
	db $01	; BG1+BG2+OBJ at StatusBar
	db $13
	db $00	; END
;
;	* * * * * * *       SAVE/LOAD SLOT MENU DATA       * * * * * * *
;
RLSaveMenuMap:
	incbin "data/RLDATA/COMP/SaveMenu.map0"
RLLoadMenuMap:
	incbin "data/RLDATA/COMP/LoadMenu.map0"
RLSlotMenuDef:
	incbin "data/RLDATA/COMP/SlotMenu.def0"
RLSlotMenuHDMATM:
	db 127	; BG1+BG2+OBJ at Top
	db $13
	db (RLVIntTop+(RLViewCharY*8))-127	; (the slot menu uses every row)
	db $13
	db $01	; BG1+BG2+OBJ at StatusBar
	db $13
	db $00	; END
_RLSlotFontTable:	; ASCII 32-90 -> tile# (tools/menus.py)
	%slotfont_table()

;
;	* * * * * * *       SKILL MENU DATA       * * * * * * *
;
	%section(RL_SKILLMENU_DATA)
RLSkillMenuMap:
	incbin "data/RLDATA/COMP/SkillMenu.map0"
RLSkillMenuDef:
	incbin "data/RLDATA/COMP/SkillMenu.def0"
RLSkillMenuHDMATM:
	db 127	; BG1+BG2+OBJ at Top
	db $13
	db (RLVIntTop+((12+4)*8))-127
	db $13
	db ((RLViewCharY-(12+4))*8)	; BG1+OBJ below Bottom of Menu
	db $11
	db $01	; BG1+BG2+OBJ at StatusBar
	db $13
	db $00	; END

;
;	* * * * * * *       EPISODE MENU DATA       * * * * * * *
;
	%section(RL_EPISODEMENU_DATA)
RLEpisodeMenuMap:
	incbin "data/RLDATA/COMP/EpisodeMenu.map0"
RLEpisodeMenuDef:
	incbin "data/RLDATA/COMP/EpisodeMenu.def0"
RLEpisodeMenuHDMATM:
	db (RLVIntTop+((10+4)*8))	; BG1+BG2+OBJ at Top
	db $13
	db ((RLViewCharY-(10+4))*8)	; BG1+OBJ below Bottom of Menu
	db $11
	db $01	; BG1+BG2+OBJ at StatusBar
	db $13
	db $00	; END
