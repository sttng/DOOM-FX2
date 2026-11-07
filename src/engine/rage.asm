	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                            MAIN CODE MODULE                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/snesmac.inc"
	incsrc "src/include/rlweapons.inc"

	; public RAGE

	%section(MAIN)

;
;	* * * * * * *       PROJECT: RAGE SNES/SFX       * * * * * * *
;
	; dbr ?
	; dpr 0
RAGE:
;
;	* * * * * * *       ATTRACT MODE       * * * * * * *
;
RAGE2000:
	jsl.l InitSNES	; Initialize SNES
	jsl.l SaveInit	; (this port) Check/format the save game area (battery RAM)
	jsl.l RumbleResetL	; (this port) No rumble effects (WRAM is random at power-on)
	if usePAL != 0
	rep #$20		; mode 'A!'
	lda.w #1
	sta.w _TitleCount
	endif
	if useTITLE != 0
	jsl.l Title	; Display Title Page
	endif

;
;	* * * * * * *       NEW GAME       * * * * * * *
;
RAGE3000:
	rep #$20		; mode 'A!'
	lda.w #0	; Start at Level E1M1
	if useTITLE != 0
	lda.w TitleLoad	; (this port) the title menu: Load Game?
	beq RAGE3100	; (LoadGame has set level, inventory and skill)
	jsl.l SavePrepare
	jmp.w RAGE5000
RAGE3100:
	lda.w TitleLevel	; New Game: the episode chosen (E1M1/E2M1/..)
	if defined("RLORDERSCREEN")	; (the shareware set lists every episode: one it
	cmp.w #(!RLEPISODES*9)	;  does not have shows the order screen, then
	bcc RAGE3200	;  the title)
	jsl.l OrderScreen
	jmp.w RAGE9200
RAGE3200:
	endif
	endif
;
;	* * * * * * *       NEXT EPISODE       * * * * * * *
;
RAGE4000:
	sta.w Level	; CURRENT LEVEL
RAGE4100:
	lda.w #100	; Player's Health
	sta.w _PlayerHealth
	stz.w _PlayerArmor	; Player's Armor
	lda.w #50	; Player's Bullets
	sta.w _PlayerBullets
	stz.w _PlayerShells	; Player's Shells
	stz.w _PlayerRockets	; Player's Rockets
	stz.w _PlayerCells	; Player's Cells
	lda.w #((wtbFist|wtbPistol)<<8)	; Pistol/Fist / No Keys
	sta.w _PlayerKeys
	lda.w #wtPistol	; Player's Weapon
	sta.w _PlayerWeapon
	stz.w _PlayerBackPack	; No BackPack
	stz.w ScoreSecret	; Player Didn't Get Episode Secret
;
	if RECORDDEMO != 0
	lda.w #-1	; Force Change of JOYData
	sta.l DemoJOY
	stz.w DemoIndex
	lda.w #1
	sta.l DemoCount
	endif
;
;	* * * * * * *       NEXT LEVEL       * * * * * * *
;
RAGE5000:
	sep #$20		; mode 'a!'
	if !RLDOOM2MONSTERS != 0
	lda.w _PlayerKeys	; No Keys (DOOM II: the Super Shotgun stays, pkSuperShotGun)
	and.b #pkSuperShotGun
	sta.w _PlayerKeys
	else
	stz.w _PlayerKeys	; No Keys
	endif
;
;	>>>   INITIALIZE RLENGINE   <<<
;
	jsl.l _RLInit	; Initialize RLEngine
	php
	rep #$20
	lda.w _SkillLevel	; (this port) The chosen skill -> the engine's copy in GSU RAM
	sta.l SkillLevel	; (every level start: SaveInit's GSU RAM clear runs after RestoreVars)
	stz.w PlayerMouseTurn	; No mouse turn from before (WRAM is not cleared at
	plp	;  power-on: the first level started at a random angle)
	jsl.l _RLInitLevel	; Initialize RLLevel
	jsl.l SaveRestore	; Loading a saved game? Restore its level state
	if !RLREJECTPVS != 0
	php
	rep #$20
	lda.w #$FFFF	; BSP visibility bits: rebuild for the new level
	sta.l NVSector
	lda.w #0	; No mouse turn left from before
	sta.l MouseTurn
	plp
	endif
;
;	>>>   INITIALIZE AUTODEMO   <<<
;
	if useDEMO != 0
	ldx.w #0
RAGE5200:
	lda.l E1M1DEMO,x
	sta.l DemoData,x
	inx
	inx
	cpx.w #(E1M1DEMOE-E1M1DEMO)
	bne RAGE5200
	endif

;
;	* * * * * * *       PLAY LEVEL       * * * * * * *
;
Stop:
	jsl.l _RLMain0	; Run Reality_Engine
	jsl.l RumbleResetL	; (this port) Level over: rumble effects stop

;
;	* * * * * * *       IDLE TIMEOUT RESET?       * * * * * * *
;
RAGE5500:
	if IDLERESET != 0
	rep #$20		; mode 'A!'
	lda.l IdleCount	; Idling for Approx. 30 Seconds?
	cmp.w #((60/4)*30)
	bcc RAGE7000	; No
	jml.l WarmBoot	; YES!  RESET MACHINE!
	endif

;
;	* * * * * * *       FINISHED THIS LEVEL       * * * * * * *
;
RAGE7000:
	sep #$30		; mode 'ax!'
	ldy.w Level	; CURRENT LEVEL
;
;	>>>   RESTART/DIED   <<<
;
	lda.l ExitLevel	; NEXT, RESTART, DIED, SECRET?
	bpl RAGE7200
	if useID2 == 0
	inc a	; -1 = RESTART, -2 = DIED
	beq RAGE5000	; RESTART
	endif
	rep #$20		; mode 'A!'
	lda.w #100	; DIED -- RESTART WITH 100% HEALTH
	sta.w _PlayerHealth
	bra RAGE5000	; RESTART LEVEL
;
;	>>>   NEW GAME   <<<
;
	; mode 'a'
RAGE7200:
	cmp.b #lo16($4C52)	; NEW GAME
	bne RAGE7300
	rep #$20		; mode 'A!'
	lda.w _SkillLevel	; New skill -> the engine's copy in GSU RAM (original bug:
	sta.l SkillLevel	; it kept the old skill until the console was reset)
	sep #$20		; mode 'a!'
	lda.l ExitLevel+1
	rep #$20		; mode 'A!'
	and.w #$00FF
	if defined("RLORDERSCREEN")	; (this port, the shareware set: an episode it does not
	cmp.w #(!RLEPISODES*9)	;  have shows the order screen, then the title)
	bcc RAGE7250
	jsl.l OrderScreen
	jmp.w RAGE9200
RAGE7250:
	endif
	jmp.w RAGE4000
	; mode 'a'
RAGE7300:
	cmp.b #$4C	; LOAD GAME (rlmenus: Level, inventory and skill are set)
	bne RAGE7350	;  or SAVE GAME (the level restarts, then SaveRestore saves)
	rep #$20		; mode 'A!'
	jsl.l SavePrepare	; Saving? Inventory/skill of the saved state back
	lda.w _SkillLevel
	sta.l SkillLevel
	jmp.w RAGE5000
	; mode 'a'
RAGE7350:
	cmp.b #51	; SECRET LEVEL
	beq RAGE7700
;
;	>>>   NORMAL EXIT   <<<
;
RAGE7500:
	tyx	; NEXT LEVEL
	lda.l NextLevelI,x
	bra RAGE7800
;
;	>>>   SECRET EXIT   <<<
;
RAGE7700:
	sta.w ScoreSecret	; Player Got Episode Secret
	tyx	; SECRET LEVEL (data set: levels.inc !lvlsecretN)
	lda.l SecretLevelI,x
;
;	>>>   NEXT LEVEL VALID?   <<<
;
RAGE7800:
	tay	; New Level#
	cmp.b #!NUMLEVELS	; Past the last level? (game over: not a table entry)
	beq RAGE7850
	asl a	; Level Valid?
	tax
	lda.l EMNUMVERTEXESTable,x
	beq RAGE7500	; NO!  SKIP IT!
RAGE7850:
	lda.w Level	; (this port) the level just finished, for the score page
	sta.w ScoreLevelDone
	stz.w ScoreLevelDone+1
	sty.w Level	; Save Level#

	!__skillep #= 0
	if useIMAGINEER == 0
	if !RLSKILLEPISODES != 0	; (levels.inc; 0 for Ultimate DOOM: every skill plays every episode)
	!__skillep #= 1
	endif
	endif
	if !__skillep != 0
	lda.w _SkillLevel	; Player's Skill Level
	cmp.b #2	; Hurt Me Plenty/Ultra-Violence/Nightmare?
	bcs RAGE7900	; Yes
	cpy.b #18	; Stop at end of Episode 2 for Skill 2
	beq RAGE9200
	dec a
	beq RAGE7900
	cpy.b #9	; Stop at end of Episode 1 for Skill 1
RAGE7820:
	beq RAGE9200
	endif

;
;	>>>   UPDATE PLAYER VARIABLES   <<<
;
RAGE7900:
	rep #$20		; mode 'A!'
	lda.l PlayerObject+rloHealth	; Player's Health
	sta.w _PlayerHealth
	lda.l PlayerArmor	; Player's Armor
	sta.w _PlayerArmor
	lda.l PlayerKeys	; Player's Keys/Arms
	sta.w _PlayerKeys
	lda.l WeaponBullets	; Player's Bullets
	sta.w _PlayerBullets
	lda.l WeaponShells	; Player's Shells
	sta.w _PlayerShells
	lda.l WeaponRockets	; Player's Rockets
	sta.w _PlayerRockets
	lda.l WeaponCells	; Player's Cells
	sta.w _PlayerCells
	lda.l WeaponType	; Player's Weapon
	sta.w _PlayerWeapon
	lda.l BackPack	; Player's BackPack
	and.w #$00FF
	sta.w _PlayerBackPack

;
;	* * * * * * *       SCORE SCREEN       * * * * * * *
;
RAGE8000:
	if useSCORE != 0
	jsl.l Score	; Score Screen
	endif
	rep #$20		; mode 'A!'
	lda.w Level	; Current Level
	cmp.w #!NUMLEVELS	; GAME OVER?
	beq RAGE9000	; YES!
	if not(defined("RLEPISODELEN"))
	!RLEPISODELEN = 9	; (levels.inc: DOOM II has one 32-map sequence)
	endif
	!__i #= !RLEPISODELEN
	while !__i < !NUMLEVELS
	cmp.w #!__i	; First level of the next episode?
	beq RAGE8500
	!__i #= !__i+!RLEPISODELEN
	endwhile
	jmp.w RAGE5000	; Next Level
RAGE8500:
	jmp.w RAGE4100	; Next Episode

;
;	* * * * * * *       GAME OVER       * * * * * * *
;
RAGE9000:
	if defined("RLORDERSCREEN")	; (this port, the shareware set: after the end text
	jsl.l OrderScreen	;  the order screen, as on the PC)
	endif
	if usePAL != 0
	rep #$20		; mode 'A!'
	lda.w #4	; Display Credits Page 1
	sta.w _TitleCount
	jsl.l Title
	rep #$20		; mode 'A!'
	lda.w #8	; Display Credits Page 2
	sta.w _TitleCount
	jsl.l Title
	endif
RAGE9200:
	rep #$20		; mode 'A!'
	stz.w _ResetCount	; Force Credits Display
	jsl.l CheckSumVars
	jmp.w RAGE2000


;
;	* * * * * * *       NEXT LEVEL INDEX       * * * * * * *
;
NextLevelI:	; (data set: levels.inc !lvlnextN)
	!__i #= 0
	while !__i < !NUMLEVELS
	db !{lvlnext!__i}
	!__i #= !__i+1
	endwhile
SecretLevelI:	; (data set: levels.inc !lvlsecretN)
	!__i #= 0
	while !__i < !NUMLEVELS
	db !{lvlsecret!__i}
	!__i #= !__i+1
	endwhile
