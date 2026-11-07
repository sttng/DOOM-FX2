	arch 65816
;**********************************************************************
;*                                                                    *
;*                      P R O J E C T :   R A G E                     *
;*                                                                    *
;*                          OBJECT DATA MODULE                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlimages.inc"


	; public _ObjData


	%section(_OBJECTDATA)

;
;	* * * * * * *       OBJECT DATA       * * * * * * *
;

_ObjData:
;
;	>>>   PLAYER   <<<
;
	dw rlodfImage	; Player1Start
	db oddPlayer
	db odhPlayer
	db $52

	dw rlodfImage	; Player2Start
	db oddPlayer
	db odhPlayer
	db $52

	dw rlodfImage	; Player3Start
	db oddPlayer
	db odhPlayer
	db $52

	dw rlodfImage	; Player4Start
	db oddPlayer
	db odhPlayer
	db $52

	dw rlodfImage	; DeathMatchStart
	db oddPlayer
	db odhPlayer
	db $52

	dw 0	; TeleportSpot
	db 0
	db 0
	db $52

;
;	>>>   ENEMIES   <<<
;
	dw (rlodfImage|rlodfKill)	; Soldier
	db oddSoldier
	db odhSoldier
	db $52

	dw (rlodfImage|rlodfKill)	; Sergeant
	db oddSergeant
	db odhSergeant
	db $52

	dw (rlodfImage|rlodfKill)	; Trooper
	db oddTrooper
	db odhTrooper
	db $52

	dw (rlodfImage|rlodfKill)	; Demon
	db oddDemon
	db odhDemon
	db $52

	if !RLSPECTRE != 0
	dw (rlodfImage|rlodfKill|rlodfShadow)	; Spectre (Ultimate DOOM)
	db oddDemon
	db odhDemon
	db $52
	endif

	dw (rlodfImage|rlodfKill|rlodfFloat)	; CacoDemon
	db oddCacoDemon
	db odhCacoDemon
	db $52

	dw (rlodfImage|rlodfKill|rlodfFloat)	; LostSoul
	db oddLostSoul
	db odhLostSoul
	db $52

	dw (rlodfImage|rlodfKill)	; BaronOfHell
	db oddBaronOfHell
	db odhBaronOfHell
	db $52

	dw (rlodfImage|rlodfKill)	; CyberDemon
	db oddCyberDemon
	db odhCyberDemon
	db $52

	dw (rlodfImage|rlodfKill)	; SpiderDemon
	db oddSpiderDemon
	db odhSpiderDemon
	db $52

	if !RLDOOM2MONSTERS != 0
	dw (rlodfImage|rlodfKill|rlodfPage1)	; ChainGunner (DOOM II)
	db oddSergeant
	db odhSergeant
	db $52

	dw (rlodfImage|rlodfKill|rlodfPage1)	; WolfSS (DOOM II)
	db oddSoldier
	db odhSoldier
	db $52

	dw (rlodfImage|rlodfKill|rlodfPage1)	; HellKnight (DOOM II)
	db oddBaronOfHell
	db odhBaronOfHell
	db $52

	dw (rlodfImage|rlodfKill|rlodfPage1)	; Arachnotron (DOOM II)
	db oddArachnotron
	db odhArachnotron
	db $52

	dw (rlodfImage|rlodfKill|rlodfPage1)	; Mancubus (DOOM II)
	db oddMancubus
	db odhMancubus
	db $52

	dw (rlodfImage|rlodfKill|rlodfPage1)	; Revenant (DOOM II)
	db oddRevenant
	db odhRevenant
	db $52

	dw (rlodfImage|rlodfKill|rlodfFloat|rlodfPage1)	; PainElemental (DOOM II)
	db oddPainElemental
	db odhPainElemental
	db $52

	dw (rlodfImage|rlodfKill|rlodfPage1)	; ArchVile (DOOM II)
	db oddArchVile
	db odhArchVile
	db $52

	dw (rlodfImage|rlodfKill|rlodfFloat|rlodfPage1)	; Keen (DOOM II: hangs from the ceiling)
	db oddKeen
	db odhKeen
	db $52

	dw (rlodfImage|rlodfPage1)	; BossBrain (DOOM II MAP30)
	db oddBossBrain
	db odhBossBrain
	db $52

	dw (rlodfImage|rlodfPage1)	; BossShooter (DOOM II MAP30: not drawn)
	db oddKeen
	db odhKeen
	db $52

	dw (rlodfImage|rlodfPage1)	; BossTarget (DOOM II MAP30 spawn spot: not drawn)
	db oddKeen
	db odhBossTarget
	db $52
	endif

;
;	>>>   WEAPONS   <<<
;
	dw rlodfItem	; ShotGun
	db oddPickUp
	db odhPickUp
	db inShotGun

	dw rlodfItem	; ChainSaw
	db oddPickUp
	db odhPickUp
	db inChainSaw

	dw rlodfItem	; ChainGun
	db oddPickUp
	db odhPickUp
	db inChainGun

	dw rlodfItem	; RocketLauncher
	db oddPickUp
	db odhPickUp
	db inRocketLauncher

	dw rlodfItem	; PlasmaGun
	db oddPickUp
	db odhPickUp
	db inPlasmaGun

	dw rlodfItem	; BFG9000
	db oddPickUp
	db odhPickUp
	db inBFG9000
	if !RLDOOM2MONSTERS != 0
	dw (rlodfItem|rlodfPage1)	; SuperShotGun (DOOM II)
	db oddPickUp
	db odhPickUp
	db inSuperShotGunItem
	endif
;
;	>>>   KEYCARDS   <<<
;
	dw (rlodfItem|rlodfGlow)	; RedKeyCard
	db oddPickUp
	db odhPickUp
	db inRedKeyCard

	dw (rlodfItem|rlodfGlow)	; BlueKeyCard
	db oddPickUp
	db odhPickUp
	db inBlueKeyCard

	dw (rlodfItem|rlodfGlow)	; YellowKeyCard
	db oddPickUp
	db odhPickUp
	db inYellowKeyCard

	dw (rlodfItem|rlodfGlow)	; RedSkullKey
	db oddPickUp
	db odhPickUp
	db inRedSkullKey

	dw (rlodfItem|rlodfGlow)	; YellowSkullKey
	db oddPickUp
	db odhPickUp
	db inYellowSkullKey

	dw (rlodfItem|rlodfGlow)	; BlueSkullKey
	db oddPickUp
	db odhPickUp
	db inBlueSkullKey
;
;	>>>   WEAPON AMMO   <<<
;
	dw (rlodfItem|rlodfItemCount)	; BackPack
	db oddPickUp
	db odhPickUp
	db inBackPack

	dw rlodfItem	; Clip
	db oddPickUp
	db odhPickUp
	db inClip

	dw rlodfItem	; AmmoBox
	db oddPickUp
	db odhPickUp
	db inAmmoBox

	dw rlodfItem	; Shells
	db oddPickUp
	db odhPickUp
	db inShells

	dw rlodfItem	; ShellsBox
	db oddPickUp
	db odhPickUp
	db inShellsBox

	dw rlodfItem	; Rocket
	db oddPickUp
	db odhPickUp
	db inRocket

	dw rlodfItem	; RocketBox
	db oddPickUp
	db odhPickUp
	db inRocketBox

	dw rlodfItem	; Cell
	db oddPickUp
	db odhPickUp
	db inCell

	dw rlodfItem	; CellPack
	db oddPickUp
	db odhPickUp
	db inCellPack
;
;	>>>   HEALTH/ARMOR PICKUPS   <<<
;
	dw rlodfItem	; StimPak
	db oddPickUp
	db odhPickUp
	db inStimPak

	dw rlodfItem	; Medikit
	db oddPickUp
	db odhPickUp
	db inMedikit

	dw (rlodfItem|rlodfItemCount|rlodfAnim4)	; HealthBonus
	db oddPickUp
	db odhPickUp
	db inHealthBonus

	dw (rlodfItem|rlodfItemCount|rlodfAnim4)	; ArmorBonus
	db oddPickUp
	db odhPickUp
	db inArmorBonus

	dw (rlodfItem|rlodfGlow)	; ArmorGreen
	db oddPickUp
	db odhPickUp
	db inArmorGreen

	dw (rlodfItem|rlodfGlow)	; ArmorBlue
	db oddPickUp
	db odhPickUp
	db inArmorBlue
;
;	>>>   POWERUPS   <<<
;
	dw (rlodfItem|rlodfAnim4|rlodfGlow)	; SoulSphere
	db oddPickUp
	db odhPickUp
	db inSoulSphere

	dw (rlodfItem|rlodfItemCount|rlodfAnim4|rlodfGlow)	; Invulnerable
	db oddPickUp
	db odhPickUp
	db inInvulnerable

	dw (rlodfItem|rlodfItemCount|rlodfGlow)	; Berserk
	db oddPickUp
	db odhPickUp
	db inBerserk

	dw (rlodfItem|rlodfItemCount|rlodfAnim4|rlodfGlow)	; Invisible
	db oddPickUp
	db odhPickUp
	db inInvisible

	dw (rlodfItem|rlodfItemCount|rlodfGlow)	; RadiationSuit
	db oddPickUp
	db odhPickUp
	db inRadiationSuit

	dw (rlodfItem|rlodfItemCount|rlodfAnim4|rlodfGlow)	; ComputerMap
	db oddPickUp
	db odhPickUp
	db inComputerMap

	dw (rlodfItem|rlodfItemCount|rlodfAnim2|rlodfGlow)	; LightGoggles
	db oddPickUp
	db odhPickUp
	db inLightGoggles
;
;	>>>   MISCELLANEOUS   <<<
;
	dw rlodfAnim2	; Barrel
	db oddObstacle
	db odhObstacle
	db inBarrel

	dw 0	; FloorLamp
	db oddObstacle
	db odhObstacle
	db inFloorLamp

	dw 0	; BloodyMess
	db oddObstacle
	db odhObstacle
	db inBloodyMess

	dw 0	; DeadTrooper
	db oddObstacle
	db odhObstacle
	db inBloodyMess2

	dw 0	; DeadDemon
	db oddObstacle
	db odhObstacle
	db (inDemonDie+3)

	dw 0	; SkullOnPole
	db oddObstacle
	db odhObstacle
	db inSkullOnPole

	dw 0	; PillarShortGreen
	db oddObstacle
	db odhObstacle
	db inPillarShortGreen

	dw 0	; Candle
	db oddObstacle
	db odhObstacle
	db inCandle

	dw 0	; Candelabra
	db oddObstacle
	db odhObstacle
	db inCandelabra

	dw rlodfAnim4	; FlamingSkullRock
	db oddObstacle
	db odhObstacle
	db inFlamingSkullRock

	dw 0	; TreeGray
	db oddObstacle
	db odhObstacle
	db inTreeGray

	dw rlodfAnim4	; FireStickTallRed
	db oddObstacle
	db odhObstacle
	db inFireStickTallRed

	dw 0	; ShrubBrown
	db oddObstacle
	db odhObstacle
	db inShrubBrown

	dw 0	; ColumnTechTall
	db oddObstacle
	db odhObstacle
	db inColumnTechTall

	dw rlodfAnim4	; FireStickShortBlue
	db oddObstacle
	db odhObstacle
	db inFireStickShortBlue
;
;	>>>   PROJECTILES   <<<
;
	dw (rlodfImage|rlodfProjectile|rlodfGlow|rlodfShine)	; FireBall 1
	db oddFireBall1
	db odhFireBall1
	db $52

	dw (rlodfImage|rlodfProjectile|rlodfGlow|rlodfShine)	; FireBall 2
	db oddFireBall2
	db odhFireBall2
	db $52

	dw (rlodfImage|rlodfProjectile|rlodfGlow|rlodfShine)	; FireBall 7
	db oddFireBall7
	db odhFireBall7
	db $52

	dw (rlodfImage|rlodfProjectile|rlodfGlow|rlodfShine)	; Missile
	db oddMissile
	db odhMissile
	db $52

	dw (rlodfImage|rlodfProjectile|rlodfGlow|rlodfShine)	; Plasma
	db oddPlasma
	db odhPlasma
	db $52
;
;	>>>   MISCELLANEOUS 2   <<<
;
	dw rlodfImage	; Barrel Explosion
	db oddObstacle
	db odhObstacle
	db $52
	if !RLDOOM2MONSTERS != 0
;
;	>>>   DOOM II PROJECTILES AND EFFECTS (image page 1)   <<<
;
	dw (rlodfImage|rlodfProjectile|rlodfGlow|rlodfShine|rlodfPage1)	; Arachnotron Plasma
	db oddArachPlasma
	db odhArachPlasma
	db $52

	dw (rlodfImage|rlodfProjectile|rlodfGlow|rlodfShine|rlodfPage1)	; Mancubus Shot
	db oddMancubusShot
	db odhMancubusShot
	db $52

	dw (rlodfImage|rlodfProjectile|rlodfGlow|rlodfShine|rlodfPage1)	; Revenant Shot
	db oddRevenantShot
	db odhRevenantShot
	db $52

	dw (rlodfImage|rlodfGlow|rlodfShine|rlodfPage1)	; ArchVile Fire
	db oddObstacle
	db odhObstacle
	db $52

	endif

	assert (((pc()-_ObjData)/rlodSize)-otMax) == 0, "***  WARNING!  _OBJDATA INVALID!   ***"
