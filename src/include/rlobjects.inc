includeonce
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                   OBJECTS STRUCTURE DEFINITIONS    *
;*                                                                    *
;**********************************************************************


;
;	* * * * * * *       OBJECT DATA STRUCTURE       * * * * * * *
;
	!rlod #= 0
	rlodFlags = !rlod	; Flags
	!rlod #= !rlod+2
	rlodDiameter = !rlod	; Diameter
	!rlod #= !rlod+1
	rlodHeight = !rlod	; Height
	!rlod #= !rlod+1
	rlodImage = !rlod	; Image#
	!rlod #= !rlod+1
	rlodSize = !rlod
;
;	>>>   OBJECT DATA FLAGS   <<<
;
	rlodfKill = $0002	; Object counts as "KILL"
	rlodfFloat = $0004	; Object FLOATS
	rlodfProjectile = $0008	; Object is PROJECTILE
	rlodfItem = $0010	; Object can be PICKED UP
	rlodfItemCount = $0020	; Object counts in ITEM TOTALS
	rlodfAnim2 = $0100	; ANIMATED 2-Frame
	rlodfAnim4 = $0200	; ANIMATED 4-Frame
	rlodfImage = $0400	; RLObject has IMAGE#
	rlodfGlow = $0800	; Object GLOWS
	rlodfShine = $1000	; Object SHINES
	rlodfPage1 = $2000	; Image#s are in image page 1 (DOOM II monsters, rlimages.inc)
	rlodfShadow = $4000	; Object drawn as a SHADOW (Spectre, Ultimate DOOM)


;
;	* * * * * * *       MOVABLE OBJECT DATA STRUCTURE       * * * * * * *
;
	!rlmod #= 0
	rlmodHealth = !rlmod	; Health
	!rlmod #= !rlmod+2
	rlmodMoveVelocities = !rlmod	; MoveVelocities Table
	!rlmod #= !rlmod+2
	rlmodSleepS = !rlmod	; Sleep State
	rlmodBirthS = !rlmod	; Birth State
	!rlmod #= !rlmod+2
	rlmodSleepA = !rlmod	; Sleep Animation
	rlmodBirthA = !rlmod	; Birth Animation
	!rlmod #= !rlmod+2
	rlmodDamageChance = !rlmod	; Chance of Damage interrupting State
	!rlmod #= !rlmod+1
	rlmodDamageS = !rlmod	; Damage State
	!rlmod #= !rlmod+2
	rlmodAttackCloseDamage = !rlmod	; Attack Close Damage/Multiplier
	!rlmod #= !rlmod+2
	rlmodAttackFarDamage = !rlmod	; Attack Far Damage/Multiplier
	!rlmod #= !rlmod+2
	rlmodAwakeSound = !rlmod	; Awake Sound Effect
	rlmodBirthSound = !rlmod	; Birth Sound Effect
	!rlmod #= !rlmod+2
	rlmodAttackCloseSound = !rlmod	; Attack Close Sound Effect
	!rlmod #= !rlmod+2
	rlmodAttackFarSound = !rlmod	; Attack Far Sound Effect
	!rlmod #= !rlmod+2
	rlmodDamageSound = !rlmod	; Damage Sound Effect
	!rlmod #= !rlmod+2
	rlmodDieSound = !rlmod	; Die Sound Effect
	!rlmod #= !rlmod+2
	rlmodBirthFlags = !rlmod	; Birth Flags
	!rlmod #= !rlmod+1
	rlmodBirthType = !rlmod	; Birth Type
	!rlmod #= !rlmod+1
	rlmodSize = !rlmod


;
;	* * * * * * *       OBJECT TYPE TAGS MACRO       * * * * * * *
;
; macro otMAC -> see src/macros.inc

;
;	* * * * * * *       OBJECT TYPE TAGS       * * * * * * *
;
	!ot #= 0	; OBJECT# 0
	%otMAC(otPlayer1Start)
	%otMAC(otPlayer2Start)
	%otMAC(otPlayer3Start)
	%otMAC(otPlayer4Start)
	%otMAC(otDeathMatchStart)
	%otMAC(otTeleportSpot)
	otAngular = !ot-1	; LAST ANGULAR OBJECT#
;
	%otMAC(otSoldier)
	%otMAC(otSergeant)
	%otMAC(otTrooper)
	%otMAC(otDemon)
	if !RLSPECTRE != 0
	%otMAC(otSpectre)	; (Ultimate DOOM) Spectre: Demon drawn as a shadow
	endif
	%otMAC(otCacoDemon)
	%otMAC(otLostSoul)
	%otMAC(otBaronOfHell)
	%otMAC(otCyberDemon)
	%otMAC(otSpiderDemon)
	if !RLDOOM2MONSTERS != 0
	%otMAC(otChainGunner)	; (DOOM II)
	%otMAC(otWolfSS)
	%otMAC(otHellKnight)
	%otMAC(otArachnotron)
	%otMAC(otMancubus)
	%otMAC(otRevenant)
	%otMAC(otPainElemental)
	%otMAC(otArchVile)
	%otMAC(otKeen)
	%otMAC(otBossBrain)
	%otMAC(otBossShooter)	; (MAP30 spawn shooter: not drawn)
	%otMAC(otBossTarget)	; (MAP30 spawn spot: not drawn)
	endif
	otMObj = !ot-1	; LAST MOVABLE OBJECT#
;
;	>>>   WEAPONS   <<<
;
	otIObj = !ot	; FIRST ITEM OBJECT#
	%otMAC(otShotGun)
	%otMAC(otChainSaw)
	%otMAC(otChainGun)
	%otMAC(otRocketLauncher)
	%otMAC(otPlasmaGun)
	%otMAC(otBFG9000)
	if !RLDOOM2MONSTERS != 0
	%otMAC(otSuperShotGun)	; (DOOM II)
	endif
;
;	>>>   KEYCARDS   <<<
;
	%otMAC(otRedKeyCard)
	%otMAC(otBlueKeyCard)
	%otMAC(otYellowKeyCard)
	%otMAC(otRedSkullKey)
	%otMAC(otBlueSkullKey)
	%otMAC(otYellowSkullKey)
;
;	>>>   WEAPON AMMO   <<<
;
	%otMAC(otBackPack)
	%otMAC(otClip)
	%otMAC(otAmmoBox)
	%otMAC(otShells)
	%otMAC(otShellsBox)
	%otMAC(otRocket)
	%otMAC(otRocketBox)
	%otMAC(otCell)
	%otMAC(otCellPack)
;
;	>>>   HEALTH/ARMOR PICKUPS   <<<
;
	%otMAC(otStimPak)
	%otMAC(otMedikit)
	%otMAC(otHealthBonus)
	%otMAC(otArmorBonus)
	%otMAC(otArmorGreen)
	%otMAC(otArmorBlue)
;
;	>>>   POWERUPS   <<<
;
	%otMAC(otSoulSphere)
	%otMAC(otInvulnerable)
	%otMAC(otBerserk)
	%otMAC(otInvisible)
	%otMAC(otRadiationSuit)
	%otMAC(otComputerMap)
	%otMAC(otLightGoggles)
;
;	>>>   MISCELLANEOUS   <<<
;
	%otMAC(otBarrel)
	%otMAC(otFloorLamp)
	%otMAC(otBloodyMess)
	%otMAC(otDeadTrooper)
	%otMAC(otDeadDemon)
	%otMAC(otSkullOnPole)
	%otMAC(otPillarShortGreen)
	%otMAC(otCandle)
	%otMAC(otCandelabra)
	%otMAC(otFlamingSkullRock)
	%otMAC(otTreeGray)
	%otMAC(otFireStickTallRed)
	%otMAC(otShrubBrown)
	%otMAC(otColumnTechTall)
	%otMAC(otFireStickShortBlue)
;
;	>>>   PROJECTILES   <<<
;
	otPObj = !ot	; FIRST PROJECTILE OBJECT#
	%otMAC(otFireBall1)
	%otMAC(otFireBall2)
	%otMAC(otFireBall7)
	%otMAC(otMissile)
	%otMAC(otPlasma)
;
;	>>>   MISCELLANEOUS 2   <<<
;
	%otMAC(otBarrelExp)
	if !RLDOOM2MONSTERS != 0
	%otMAC(otArachPlasma)	; (DOOM II projectiles and effects)
	%otMAC(otMancubusShot)
	%otMAC(otRevenantShot)
	%otMAC(otVileFire)
	endif
;
	otMax = !ot	; MAXIMUM OBJECT TYPE


;
;	* * * * * * *       OBJECT DIMENSIONS       * * * * * * *
;
;	>>>   HEIGHT   <<<
;
	odhPlayer = 56	; Player
	odhPlayerEye = 42	; View Eye
;
	odhSoldier = 56	; Enemies
	odhSergeant = 56
	odhTrooper = 56
	odhDemon = 56
	odhCacoDemon = 56
	odhLostSoul = 56
	odhBaronOfHell = 56
	odhCyberDemon = 96
	odhSpiderDemon = 88
	odhArachnotron = 64	; (DOOM II)
	odhMancubus = 64
	odhRevenant = 56
	odhPainElemental = 56
	odhArchVile = 56
	odhKeen = 72
	odhBossBrain = 56	; (PC 16: the brain is shot through the wall)
	odhBossTarget = 0	; (monsters appear on the floor)
;
	odhPickUp = 16	; Pickup Items
	odhObstacle = 16	; Obstacles
;
	odhFireBall1 = 16	; FireBall1
	odhFireBall2 = 16	; FireBall2
	odhFireBall7 = 16	; FireBall7
	odhMissile = 14	; Missile
	odhPlasma = 24	; Plasma
	odhArachPlasma = 16	; (DOOM II)
	odhMancubusShot = 16
	odhRevenantShot = 16
;
	odhTarget = 56	; Height of Objects for Targetting


;
;	>>>   DIAMETER   <<<
;
	oddPlayer = 32	; Player
;
	oddSoldier = 40	; Enemies
	oddSergeant = 40
	oddTrooper = 40
	oddDemon = 60
	oddCacoDemon = 62
	oddLostSoul = 32
	oddBaronOfHell = 48
	oddCyberDemon = 70
	oddSpiderDemon = 192
	oddArachnotron = 128	; (DOOM II)
	oddMancubus = 96
	oddRevenant = 40
	oddPainElemental = 62
	oddArchVile = 40
	oddKeen = 32
	oddBossBrain = 32
;
	oddPickUp = 64	; 40		; Pickup Items
	oddObstacle = 48	; 32		; Obstacles
;
	oddFireBall1 = 16	; FireBall1 (Red)
	oddFireBall2 = 16	; FireBall2 (Purple)
	oddFireBall7 = 18	; FireBall7 (Green)
	oddMissile = 14	; Missile
	oddPlasma = 24	; Plasma
	oddArachPlasma = 26	; (DOOM II)
	oddMancubusShot = 12
	oddRevenantShot = 22


;
;	>>>   RADIUS   <<<
;
	odrPlayer = (oddPlayer/2)	; Player Radius
	odrMoveXY = odrPlayer	; Player<->Line Movement Collision Radius
	odrMoveLineXY = odrPlayer	; Line<->Player Movement Collision Radius
	odrUseXY = (odrPlayer*3)	; Use/Operate Intersection Radius
