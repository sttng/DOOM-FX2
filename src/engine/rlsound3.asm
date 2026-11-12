	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                        ENGINE SOUND MODULE 3                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlsound.inc"
	incsrc "src/include/music.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


;
;	* * * * * * *       SOUND EFFECT DATA       * * * * * * *
;
_RLSoundEffects:
;
;	>>>   DOORS   <<<
;
sxDoorOpen:
	db $80	; Door Opening
	db doorope3_eff
	db $D0
	db doorope2_eff
	db $FF
	db dooropen_eff

sxDoorClose:
	db $80	; Door Closing
	db doorclo3_eff
	db $D0
	db doorclo2_eff
	db $FF
	db doorclos_eff

;
;	>>>   PLATFORMS   <<<
;
sxLiftStart:
	db $80	; Lift Start
	db pstart3_eff
	db $D0
	db pstart2_eff
	db $FF
	db pstart_eff

sxLiftStop:
	db $80	; Lift Stop
	db pstop3_eff
	db $D0
	db pstop2_eff
	db $FF
	db pstop_eff

sxStnMove:
	db $80	; Standard Move
	db stnmov3_eff
	db $D0
	db stnmov2_eff
	db $FF
	db stnmov_eff

;
;	>>>   TELEPORT   <<<
;
sxTeleport:
	db $80	; Teleporter
	db telept3_eff
	db $D0
	db telept2_eff
	db $FF
	db telept_eff

;
;	>>>   SOLDIER   <<<
;
sxSoldierAwake:
sxSergeantAwake:
	db $80	; Soldier Awake
	db posit13_eff
	db $D0
	db posit12_eff
	db $FF
	db posit1_eff
sxSoldierShoot:
	db $80	; Soldier Shoot
	db pistol3_eff
	db $D0
	db pistol2_eff
	db $FF
	db pistol_eff

;
;	>>>   SERGEANT   <<<
;
sxSergeantShoot:
	db $80	; Sergeant Shoot
	db shotgn3_eff
	db $D0
	db shotgn2_eff
	db $FF
	db shotgn_eff
sxSoldierDamage:
sxSergeantDamage:
sxTrooperDamage:
sxDemonDamage:
	db $80	; Sergeant Damage
	db popain3_eff
	db $D0
	db popain2_eff
	db $FF
	db popain_eff
sxSoldierDie:
sxSergeantDie:
	db $80	; Sergeant Die
	db podth33_eff
	db $D0
	db podth32_eff
	db $FF
	db podth3_eff

;
;	>>>   TROOPER   <<<
;
sxTrooperAwake:
	db $80	; Trooper Awake
	db bgsit13_eff
	db $D0
	db bgsit12_eff
	db $FF
	db bgsit1_eff

;
;	>>>   DEMON   <<<
;
sxDemonAwake:
	db $80	; Demon Awake
	db sgtsit3_eff
	db $D0
	db sgtsit2_eff
	db $FF
	db sgtsit_eff
sxTrooperDie:
sxDemonDie:
	db $80	; Demon Die
	db bgdth13_eff
	db $D0
	db bgdth12_eff
	db $FF
	db bgdth1_eff

;
;	>>>   CACODEMON   <<<
;
sxCacoDemonAwake:
	db $80	; CacoDemon Awake
	db cacsit3_eff
	db $D0
	db cacsit2_eff
	db $FF
	db cacsit_eff
sxTrooperFight:
sxDemonFight:
sxBaronOfHellFight:
sxCyberDemonFight:
sxCacoDemonFight:
	db $80	; CacoDemon Fight
	db claw3_eff
	db $D0
	db claw2_eff
	db $FF
	db claw_eff
sxCacoDemonDie:
	db $80	; CacoDemon Die
	db cacdth3_eff
	db $D0
	db cacdth2_eff
	db $FF
	db cacdth_eff

;
;	>>>   LOST SOUL   <<<
;
sxLostSoulAwake:
	db $80	; LostSoul Awake
	db dmact3_eff
	db $D0
	db dmact2_eff
	db $FF
	db dmact_eff
sxLostSoulFight:
	db $80	; LostSoul Fight
	db sklatk3_eff
	db $D0
	db sklatk2_eff
	db $FF
	db sklatk_eff
sxLostSoulDie:
	db $80	; LostSoul Die
	db skldth3_eff
	db $D0
	db skldth2_eff
	db $FF
	db skldth_eff

;
;	>>>   BARON OF HELL   <<<
;
sxBaronOfHellAwake:
	db $80	; BaronOfHell Awake
	db brssit3_eff
	db $D0
	db brssit2_eff
	db $FF
	db brssit_eff

;
;	>>>   CYBERDEMON   <<<
;
sxCyberDemonAwake:
	db $80	; CyberDemon Awake
	db cybsit3_eff
	db $D0
	db cybsit2_eff
	db $FF
	db cybsit_eff

;
;	>>>   SPIDERDEMON   <<<
;
sxSpiderDemonAwake:
sxSpiderDemonFight:
	db $80	; SpiderDemon Fight
	db spisit3_eff
	db $D0
	db spisit2_eff
	db $FF
	db spisit_eff
sxSpiderDemonShoot:
	db $80	; SpiderDemon Shoot
	db pistol3_eff
	db $D0
	db pistol2_eff
	db $FF
	db pistol_eff
sxCacoDemonDamage:
sxLostSoulDamage:
sxBaronOfHellDamage:
sxCyberDemonDamage:
sxSpiderDemonDamage:
	db $80	; SpiderDemon Damage
	db dmpain3_eff
	db $D0
	db dmpain2_eff
	db $FF
	db dmpain_eff
sxBaronOfHellDie:
sxCyberDemonDie:
sxSpiderDemonDie:
	db $80	; SpiderDemon Die
	db brsdth3_eff
	db $D0
	db brsdth2_eff
	db $FF
	db brsdth_eff

sxTrooperLaunch:
sxBaronOfHellLaunch:
sxCyberDemonLaunch:
sxFireBall1Launch:
sxFireBall2Launch:
sxFireBall7Launch:
sxBFGLaunch:
sxMissileLaunch:
sxPlasmaLaunch:
	db $80	; Plasma Launch
	db firsht3_eff
	db $D0
	db firsht2_eff
	db $FF
	db firsht_eff
sxFireBall1Die:
sxFireBall2Die:
sxFireBall7Die:
sxBFGDie:
sxBarrelExplode:
sxPlasmaDie:
sxMissileDie:
	db $80	; Plasma Die
	db firxpl3_eff
	db $D0
	db firxpl2_eff
	db $FF
	db firxpl_eff

	if !RLDOOM2MONSTERS != 0
;
;	>>>   ARCH-VILE FIRE (DOOM II)   <<<
;
sxVileFire:
	db $80	; Arch-Vile Fire (DSFLAMST, DSFLAME)
	db vilefire3_eff
	db $D0
	db vilefire2_eff
	db $FF
	db vilefire_eff
sxVileRaise:
	db $D0	; A Corpse Rising (DSSLOP: the arch-vile's resurrection)
	db vileraise2_eff
	db $FF
	db vileraise_eff
	endif
