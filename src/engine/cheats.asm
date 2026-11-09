	arch 65816
;**********************************************************************
;*                                                                    *
;*                 P R O J E C T :   REALITY_ENGINE                   *
;*                                                                    *
;*                   CHEATS MODULE (this port)                        *
;*                                                                    *
;**********************************************************************
;
;	The three button cheats of The Ultimate DOOM cartridge (FX3), with its
;	button sequences, entered in the pause menu: the main menu passes every
;	new joypad state to CheatPress (rlmenus.asm _RLM2500).  Each cheat
;	follows its own sequence; a wrong press starts it over.  A press that
;	continues a cheat already begun is taken by it and does nothing in the
;	menu (A and Down are menu buttons); the first presses (R, L, Right)
;	do nothing there anyway.  Not with the mouse, not while dead.
;
;	  R A Down Down Down Down Down A L        ammo to the maximum (doubled
;	                                          with the backpack), every
;	                                          weapon, every key, 200% armor,
;	                                          at least 100% health
;	  L Right Right Down Down Down Down Down  invulnerability for 60 seconds,
;	    Left Left Down Down Down Down         as the sphere
;	  Right Right Down Down Left Left Left    the whole map, and the monsters
;	    Left, twice                           on it, for this level
;	                                          (ComputerMap = 2, rlautomap.asm)
;
;	FX3 checks the sequences while playing; it gives its fixed ammo counts
;	(200/50/50/300) and sets the health to 100%.
;
	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/rlweapons.inc"

	if defined("RLNOPLASMABFG")	; (levels.inc: no plasma rifle/BFG, the shareware set)
	CHEATARMS = $FF&~(wtbPlasma|wtbBFG)
	else
	CHEATARMS = $FF
	endif
	if !RLDOOM2MONSTERS != 0	; (DOOM II: the Super Shotgun, pkSuperShotGun)
	CHEATKEYS = $3F|pkSuperShotGun
	else
	CHEATKEYS = $3F	; The 6 keys (bits 0-5)
	endif
	CHEATS = 3


	%section(CHEATS)

;
;	* * * * * * *       RESET (A NEW MENU)       * * * * * * *
;
	; dbr ?
	; dpr 0
CheatReset:
	php
	rep #$20		; mode 'A!'
	lda.w #0
	sta.l CheatStep
	sta.l CheatStep+2
	sta.l CheatStep+4
	plp
	rtl

;
;	* * * * * * *       A NEW JOYPAD STATE IN THE MENU       * * * * * * *
;
;	.A = the joypad bits (0 on a release).  C = 1: the press was taken by a
;	cheat.  mode 'AX' in and out; dpr 0, dbr ?; A, X, Temp.
;
CheatPress:
	rep #$30		; mode 'AX!'
	sta.b Temp	; The press
	stz.b Temp+2	; Not taken
	tax
	beq .done	; A release
	lda.l JOY1Stat	; Joypad ($00), not the mouse
	and.w #$00FF
	bne .done
	lda.b MenuData	; The main pause menu only
	cmp.w #lo16(_RLMainMenuData)
	bne .done
	ldx.w #0
.cheat:
	stx.b Temp+4	; Cheat*2
	lda.l CheatStep,x	; Its next press
	sta.b Temp+6
	clc
	adc.l CheatSeqOfs,x
	tax
	lda.l CheatSeqs,x
	cmp.b Temp	; This one?
	bne .miss
	lda.b Temp+6	; A cheat already begun: the menu ignores it
	beq +
	inc.b Temp+2
+
	lda.l CheatSeqs+2,x	; The last one?
	bne .next
	inc.b Temp+2
	ldx.b Temp+4	; YES!
	jsr.w (.apply,x)
	bra .first
.next:
	lda.b Temp+6
	inc a
	inc a
	bra .store
.miss:
	ldx.b Temp+4	; Start over: is it the first one?
	lda.l CheatSeqOfs,x
	tax
	lda.l CheatSeqs,x
	cmp.b Temp
	bne .first
	lda.w #2
	bra .store
.first:
	lda.w #0
.store:
	ldx.b Temp+4
	sta.l CheatStep,x
	inx
	inx
	cpx.w #(CHEATS*2)
	bne .cheat
.done:
	lda.b Temp+2	; C = taken
	cmp.w #1
	rtl

.apply:
	dw .ammo,.god,.map

;
;	>>>   VERY HAPPY AMMO   <<<
;
.ammo:
	jsr.w .alive	; (returns from here when dead)
	ldx.w #0	; The maxima, doubled with the backpack
	sep #$20		; mode 'a!'
	lda.l BackPack
	rep #$20		; mode 'A!'
	and.w #$00FF
	beq +
	ldx.w #4*2
+
	lda.l CheatAmmo+0,x
	sta.l WeaponBullets
	lda.l CheatAmmo+2,x
	sta.l WeaponShells
	lda.l CheatAmmo+4,x
	sta.l WeaponRockets
	lda.l CheatAmmo+6,x
	sta.l WeaponCells
	lda.w #(CHEATARMS<<8)|CHEATKEYS	; Every weapon and key (PlayerArms follows)
	sta.l PlayerKeys
	lda.w #200	; 200% Armor
	sta.l PlayerArmor
	lda.l PlayerObject+rloHealth	; At least 100% Health
	cmp.w #100
	bcs +
	lda.w #100
	sta.l PlayerObject+rloHealth
+
	lda.w #lo16(CHEATAMMOMSGA)	; "VERY HAPPY AMMO ADDED"
	ldx.w #lo16(CHEATAMMOMSGB)
	ldy.w #lo16(CHEATAMMOMSGC)
	bra .msg
;
;	>>>   INVULNERABILITY   <<<
;
.god:
	jsr.w .alive	; (returns from here when dead)
	lda.w #(60*60)	; #VBlanks, as the sphere (rlmove8.asm)
	sta.l InvulnerableCount
	lda.w #lo16(INVULNERABLEMSGA)	; "INVULNERABILITY!"
	ldx.w #lo16(INVULNERABLEMSGB)
	ldy.w #lo16(NULL)
	bra .msg
;
;	>>>   THE WHOLE MAP AND THE MONSTERS   <<<
;
.map:
	jsr.w .alive	; (returns from here when dead)
	sep #$20		; mode 'a!'
	lda.b #2	; ComputerMap 2: also every monster (rlautomap.asm)
	sta.l ComputerMap
	rep #$20		; mode 'A!'
	lda.w #lo16(COMPUTERMAPMSGA)	; "COMPUTER AREA MAP"
	ldx.w #lo16(COMPUTERMAPMSGB)
	ldy.w #lo16(NULL)
;
;	>>>   THE MESSAGE, SHOWN WHEN THE GAME GOES ON   <<<
;
.msg:
	sta.l MsgDataA
	txa
	sta.l MsgDataB
	tya
	sta.l MsgDataC
	lda.w #(3*60)	; Display Message for 3 Seconds
	sta.l MsgCount
	rts
;
;	>>>   DEAD (HEALTH <= 0): RETURN FROM THE CHEAT   <<<
;
.alive:
	lda.l PlayerHealth+!RLSNESGSUXVarsO
	dec a
	bpl +
	pla	; Drop this return address
+
	rts


;
;	>>>   THE SEQUENCES (0 = THE END)   <<<
;
CheatSeqOfs:
	dw CheatSeqAmmo-CheatSeqs,CheatSeqGod-CheatSeqs,CheatSeqMap-CheatSeqs
CheatSeqs:
CheatSeqAmmo:
	dw joyR,joyA,joyDOWN,joyDOWN,joyDOWN,joyDOWN,joyDOWN,joyA,joyL,0
CheatSeqGod:
	dw joyL,joyRIGHT,joyRIGHT,joyDOWN,joyDOWN,joyDOWN,joyDOWN,joyDOWN
	dw joyLEFT,joyLEFT,joyDOWN,joyDOWN,joyDOWN,joyDOWN,0
CheatSeqMap:
	dw joyRIGHT,joyRIGHT,joyDOWN,joyDOWN,joyLEFT,joyLEFT,joyLEFT,joyLEFT
	dw joyRIGHT,joyRIGHT,joyDOWN,joyDOWN,joyLEFT,joyLEFT,joyLEFT,joyLEFT,0
;
CheatAmmo:	; Bullets, Shells, Rockets, Cells (rlmove8.asm)
	dw 200,50,50,300
	dw 400,100,100,600	; With the backpack
