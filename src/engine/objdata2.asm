	arch 65816
;**********************************************************************
;*                                                                    *
;*                      P R O J E C T :   R A G E                     *
;*                                                                    *
;*                         OBJECT DATA MODULE 2                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlimages.inc"


	; public _MObjData


	%section(_MOBJECTDATA)

;
;	* * * * * * *       MOVABLE OBJECT DATA       * * * * * * *
;

_MObjData:
;
;	>>>   PLAYER   <<<
;
modPlayer:
	dw 100	; PLAYER
	dw 0
	dw 0	; NO STATE INFORMATION!
;
;	>>>   SOLDIER   <<<
;
modSoldier:
	dw 20	; SOLDIER
	dw lo16(_RLMVSoldier)
	dw lo16(mosSOLDIER_SLEEP0)
	dw lo16(moaSOLDIER_SLEEP)
	db (85*256/100)
	dw lo16(mosSOLDIER_DAMAGE)
	dw 0
	dw ((3<<8)|3)
	dw lo16(sxSoldierAwake)
	dw 0
	dw lo16(sxSoldierShoot)
	dw lo16(sxSoldierDamage)
	dw lo16(sxSoldierDie)
;
;	>>>   SERGEANT   <<<
;
modSergeant:
	dw 30	; SERGEANT
	dw lo16(_RLMVSergeant)
	dw lo16(mosSERGEANT_SLEEP0)
	dw lo16(moaSERGEANT_SLEEP)
	db (85*256/100)
	dw lo16(mosSERGEANT_DAMAGE)
	dw 0
	dw ((4<<8)|3)
	dw lo16(sxSergeantAwake)
	dw 0
	dw lo16(sxSergeantShoot)
	dw lo16(sxSergeantDamage)
	dw lo16(sxSergeantDie)
;
;	>>>   TROOPER   <<<
;
modTrooper:
	dw 60	; 50				; TROOPER
	dw lo16(_RLMVTrooper)
	dw lo16(mosTROOPER_SLEEP0)
	dw lo16(moaTROOPER_SLEEP)
	db (75*256/100)
	dw lo16(mosTROOPER_DAMAGE)
	dw ((3<<8)|7)
	dw 0
	dw lo16(sxTrooperAwake)
	dw lo16(sxTrooperFight)
	dw lo16(sxTrooperLaunch)
	dw lo16(sxTrooperDamage)
	dw lo16(sxTrooperDie)
;
;	>>>   DEMON   <<<
;
modDemon:
	dw 140	; 120			; DEMON
	dw lo16(_RLMVDemon)
	dw lo16(mosDEMON_SLEEP0)
	dw lo16(moaDEMON_SLEEP)
	db (70*256/100)
	dw lo16(mosDEMON_DAMAGE)
	dw ((4<<8)|7)
	dw 0
	dw lo16(sxDemonAwake)
	dw lo16(sxDemonFight)
	dw 0
	dw lo16(sxDemonDamage)
	dw lo16(sxDemonDie)
;
;	>>>   CACODEMON   <<<
;
modCacoDemon:
	dw 550	; 450			; CACODEMON
	dw lo16(_RLMVCacoDemon)
	dw lo16(mosCACODEMON_SLEEP0)
	dw lo16(moaCACODEMON_SLEEP)
	db (60*256/100)
	dw lo16(mosCACODEMON_DAMAGE)
	dw ((4<<8)|15)
	dw 0
	dw lo16(sxCacoDemonAwake)
	dw lo16(sxCacoDemonFight)
	dw 1
	dw lo16(sxCacoDemonDamage)
	dw lo16(sxCacoDemonDie)
;
;	>>>   LOST SOUL   <<<
;
modLostSoul:
	dw 100	; LOSTSOUL
	dw lo16(_RLMVLostSoul)
	dw lo16(mosLOSTSOUL_SLEEP0)
	dw lo16(moaLOSTSOUL_SLEEP)
	db (95*256/100)
	dw lo16(mosLOSTSOUL_DAMAGE)
	dw ((3<<8)|7)
	dw 0
	dw lo16(sxLostSoulAwake)
	dw lo16(sxLostSoulFight)
	dw 0
	dw lo16(sxLostSoulDamage)
	dw lo16(sxLostSoulDie)
;
;	>>>   BARON OF HELL   <<<
;
modBaronOfHell:
	dw 1200	; 1000			; BARONOFHELL
	dw lo16(_RLMVBaronOfHell)
	dw lo16(mosBARONOFHELL_SLEEP0)
	dw lo16(moaBARONOFHELL_SLEEP)
	db (64*256/100)
	dw lo16(mosBARONOFHELL_DAMAGE)
	dw ((7<<8)|15)
	dw 0
	dw lo16(sxBaronOfHellAwake)
	dw lo16(sxBaronOfHellFight)
	dw lo16(sxBaronOfHellLaunch)
	dw lo16(sxBaronOfHellDamage)
	dw lo16(sxBaronOfHellDie)
;
;	>>>   CYBERDEMON   <<<
;
modCyberDemon:
	dw 4000	; CYBERDEMON
	dw lo16(_RLMVCyberDemon)
	dw lo16(mosCYBERDEMON_SLEEP0)
	dw lo16(moaCYBERDEMON_SLEEP)
	db (32*256/100)
	dw lo16(mosCYBERDEMON_DAMAGE)
	dw ((9<<8)|15)
	dw 0
	dw lo16(sxCyberDemonAwake)
	dw lo16(sxCyberDemonFight)
	dw lo16(sxCyberDemonLaunch)
	dw lo16(sxCyberDemonDamage)
	dw lo16(sxCyberDemonDie)
;
;	>>>   SPIDERDEMON   <<<
;
modSpiderDemon:
	dw 3500	; 3000			; SPIDERDEMON
	dw lo16(_RLMVSpiderDemon)
	dw lo16(mosSPIDERDEMON_SLEEP0)
	dw lo16(moaSPIDERDEMON_SLEEP)
	db (12*256/100)
	dw lo16(mosSPIDERDEMON_DAMAGE)
	dw ((25<<8)|7)
	dw ((4<<8)|7)
	dw lo16(sxSpiderDemonAwake)
	dw lo16(sxSpiderDemonFight)
	dw lo16(sxSpiderDemonShoot)
	dw lo16(sxSpiderDemonDamage)
	dw lo16(sxSpiderDemonDie)
	if !RLDOOM2MONSTERS != 0
;
;	>>>   CHAINGUNNER (DOOM II)   <<<
;
;	PC: 70 HP (zombieman 20), pain chance 170/256, A_CPosAttack: one bullet of
;	3*(1..5) per shot, keeps firing while it sees the player (A_CPosRefire);
;	sounds of the zombieman, the shotgun's when firing
;
modChainGunner:
	dw 70	; CHAINGUNNER
	dw lo16(_RLMVSergeant)
	dw lo16(mosCHAINGUNNER_SLEEP0)
	dw lo16(moaCHAINGUNNER_SLEEP)
	db (72*256/100)
	dw lo16(mosCHAINGUNNER_DAMAGE)
	dw 0
	dw ((3<<8)|3)
	dw lo16(sxSoldierAwake)
	dw 0
	dw lo16(sxSergeantShoot)
	dw lo16(sxSoldierDamage)
	dw lo16(sxSoldierDie)
;
;	>>>   WOLFENSTEIN SS (DOOM II)   <<<
;
;	PC: 50 HP, pain chance 170/256, the chaingunner's attack
;
modWolfSS:
	dw 50	; WOLFSS
	dw lo16(_RLMVSoldier)
	dw lo16(mosWOLFSS_SLEEP0)
	dw lo16(moaWOLFSS_SLEEP)
	db (72*256/100)
	dw lo16(mosWOLFSS_DAMAGE)
	dw 0
	dw ((3<<8)|3)
	dw lo16(sxSoldierAwake)
	dw 0
	dw lo16(sxSergeantShoot)
	dw lo16(sxSoldierDamage)
	dw lo16(sxSoldierDie)
;
;	>>>   HELL KNIGHT (DOOM II)   <<<
;
;	PC: the Baron of Hell (A_BruisAttack: claw or green fireball) with 500 HP
;	instead of 1000 (here 600: the Baron has 1200); no E1M8 death trigger
;
modHellKnight:
	dw 600	; HELLKNIGHT
	dw lo16(_RLMVBaronOfHell)
	dw lo16(mosHELLKNIGHT_SLEEP0)
	dw lo16(moaHELLKNIGHT_SLEEP)
	db (64*256/100)
	dw lo16(mosHELLKNIGHT_DAMAGE)
	dw ((7<<8)|15)
	dw 0
	dw lo16(sxBaronOfHellAwake)
	dw lo16(sxBaronOfHellFight)
	dw lo16(sxBaronOfHellLaunch)
	dw lo16(sxBaronOfHellDamage)
	dw lo16(sxBaronOfHellDie)
;
;	(PC values where the engine allows; sounds from the cartridge's set)
;
;	>>>   ARACHNOTRON (DOOM II)   <<<
;
;	PC: 500 HP, pain 128/256, A_BspiAttack: plasma 5*(1..8) while it sees the player
;
modArachnotron:
	dw 500
	dw lo16(_RLMVBaronOfHell)
	dw lo16(mosARACHNOTRON_SLEEP0)
	dw lo16(moaARACHNOTRON_SLEEP)
	db (50*256/100)
	dw lo16(mosARACHNOTRON_DAMAGE)
	dw 0
	dw 0
	dw lo16(sxSpiderDemonAwake)
	dw 0
	dw lo16(sxPlasmaLaunch)
	dw lo16(sxDemonDamage)
	dw lo16(sxSpiderDemonDie)
;
;	>>>   MANCUBUS (DOOM II)   <<<
;
;	PC: 600 HP, pain 80/256, A_FatAttack1-3: two fireballs 8*(1..8) per volley, spread
;
modMancubus:
	dw 600
	dw lo16(_RLMVSoldier)
	dw lo16(mosMANCUBUS_SLEEP0)
	dw lo16(moaMANCUBUS_SLEEP)
	db (31*256/100)
	dw lo16(mosMANCUBUS_DAMAGE)
	dw 0
	dw 0
	dw lo16(sxBaronOfHellAwake)
	dw 0
	dw lo16(sxFireBall1Launch)
	dw lo16(sxDemonDamage)
	dw lo16(sxCacoDemonDie)
;
;	>>>   REVENANT (DOOM II)   <<<
;
;	PC: 300 HP, pain 100/256, A_SkelFist 6*(1..10) close, A_SkelMissile (homing: not here)
;
modRevenant:
	dw 300
	dw lo16(_RLMVBaronOfHell)
	dw lo16(mosREVENANT_SLEEP0)
	dw lo16(moaREVENANT_SLEEP)
	db (39*256/100)
	dw lo16(mosREVENANT_DAMAGE)
	dw ((6<<8)|7)
	dw 0
	dw lo16(sxSergeantAwake)
	dw lo16(sxTrooperFight)
	dw lo16(sxMissileLaunch)
	dw lo16(sxDemonDamage)
	dw lo16(sxTrooperDie)
;
;	>>>   PAIN ELEMENTAL (DOOM II)   <<<
;
;	PC: 400 HP, pain 128/256, A_PainAttack: a lost soul
;
modPainElemental:
	dw 400
	dw lo16(_RLMVSoldier)
	dw lo16(mosPAINELEMENTAL_SLEEP0)
	dw lo16(moaPAINELEMENTAL_SLEEP)
	db (50*256/100)
	dw lo16(mosPAINELEMENTAL_DAMAGE)
	dw 0
	dw 0
	dw lo16(sxCacoDemonAwake)
	dw 0
	dw lo16(sxLostSoulAwake)
	dw lo16(sxCacoDemonDamage)
	dw lo16(sxCacoDemonDie)
;
;	>>>   ARCH-VILE (DOOM II)   <<<
;
;	PC: 700 HP, pain 10/256, A_VileAttack: 20 + fire on the target (here: no 70 radius);
;	A_VileChase raises corpses (here: rlenemies5.asm _RLEAVileSeek)
;
modArchVile:
	dw 700
	dw lo16(_RLMVDemon)
	dw lo16(mosARCHVILE_SLEEP0)
	dw lo16(moaARCHVILE_SLEEP)
	db (4*256/100)
	dw lo16(mosARCHVILE_DAMAGE)
	dw 0
	dw ((20<<8)|0)
	dw lo16(sxBaronOfHellAwake)
	dw lo16(sxVileRaise)	; (this port: no close attack; a corpse it raises, rlenemies5.asm)
	dw lo16(sxBarrelExplode)
	dw lo16(sxDemonDamage)
	dw lo16(sxBaronOfHellDie)
;
;	>>>   COMMANDER KEEN (DOOM II)   <<<
;
;	PC: 100 HP, pain 256/256; MAP32: the door tagged 666 opens when all are dead
;
modKeen:
	dw 100
	dw 0
	dw lo16(mosKEEN_SLEEP0)
	dw lo16(moaKEEN_SLEEP)
	db 255
	dw lo16(mosKEEN_DAMAGE)
	dw 0
	dw 0
	dw 0
	dw 0
	dw 0
	dw lo16(sxSoldierDamage)
	dw lo16(sxSoldierDie)
;
;	>>>   BOSS BRAIN (DOOM II)   <<<
;
;	PC: 250 HP, pain 256/256; MAP30: the level ends when it dies
;
modBossBrain:
	dw 250
	dw 0
	dw lo16(mosBOSSBRAIN_SLEEP0)
	dw lo16(moaBOSSBRAIN_SLEEP)
	db 255
	dw lo16(mosBOSSBRAIN_DAMAGE)
	dw 0
	dw 0
	dw 0
	dw 0
	dw 0
	dw lo16(sxCyberDemonDamage)
	dw lo16(sxCyberDemonDie)
;
;	>>>   BOSS SHOOTER (DOOM II)   <<<
;
;	MAP30: shoots spawn cubes at the spawn spots once the player is seen
;
modBossShooter:
	dw 30000
	dw 0
	dw lo16(mosBOSSSHOOTER_SLEEP0)
	dw lo16(moaBOSSSHOOTER_SLEEP)
	db (0*256/100)
	dw lo16(mosBOSSSHOOTER_DAMAGE)
	dw 0
	dw 0
	dw 0
	dw 0
	dw lo16(sxFireBall7Launch)
	dw 0
	dw 0
;
;	A lost soul from a pain elemental: born awake
;
modLostSoulPE:
	dw 100	; LOSTSOUL (pain elemental)
	dw lo16(_RLMVLostSoul)
	dw lo16(mosLOSTSOUL_MOVE)
	dw lo16(moaLOSTSOUL_MOVE)
	db (95*256/100)
	dw lo16(mosLOSTSOUL_DAMAGE)
	dw ((3<<8)|7)
	dw 0
	dw lo16(sxLostSoulAwake)
	dw lo16(sxLostSoulFight)
	dw 0
	dw lo16(sxLostSoulDamage)
	dw lo16(sxLostSoulDie)
	db (rlpfMovable|rlpfActive|rlpfSolid|rlpfTarget)
	db otLostSoul
;
;	MAP30: the monsters the boss shooter spawns (born awake; awake sound: the teleport sound)
;
modSpawnTrooper:
	dw 60	; 50				; TROOPER
	dw lo16(_RLMVTrooper)
	dw lo16(mosTROOPER_MOVE)
	dw lo16(moaTROOPER_MOVE)
	db (75*256/100)
	dw lo16(mosTROOPER_DAMAGE)
	dw ((3<<8)|7)
	dw 0
	dw lo16(sxTeleport)
	dw lo16(sxTrooperFight)
	dw lo16(sxTrooperLaunch)
	dw lo16(sxTrooperDamage)
	dw lo16(sxTrooperDie)
	db (rlpfMovable|rlpfActive|rlpfSolid|rlpfTarget)
	db otTrooper
modSpawnDemon:
	dw 140	; 120			; DEMON
	dw lo16(_RLMVDemon)
	dw lo16(mosDEMON_MOVE)
	dw lo16(moaDEMON_MOVE)
	db (70*256/100)
	dw lo16(mosDEMON_DAMAGE)
	dw ((4<<8)|7)
	dw 0
	dw lo16(sxTeleport)
	dw lo16(sxDemonFight)
	dw 0
	dw lo16(sxDemonDamage)
	dw lo16(sxDemonDie)
	db (rlpfMovable|rlpfActive|rlpfSolid|rlpfTarget)
	db otDemon
modSpawnCacoDemon:
	dw 550	; 450			; CACODEMON
	dw lo16(_RLMVCacoDemon)
	dw lo16(mosCACODEMON_MOVE)
	dw lo16(moaCACODEMON_MOVE)
	db (60*256/100)
	dw lo16(mosCACODEMON_DAMAGE)
	dw ((4<<8)|15)
	dw 0
	dw lo16(sxTeleport)
	dw lo16(sxCacoDemonFight)
	dw 1
	dw lo16(sxCacoDemonDamage)
	dw lo16(sxCacoDemonDie)
	db (rlpfMovable|rlpfActive|rlpfSolid|rlpfTarget)
	db otCacoDemon
modSpawnHellKnight:
	dw 600	; HELLKNIGHT
	dw lo16(_RLMVBaronOfHell)
	dw lo16(mosHELLKNIGHT_MOVE)
	dw lo16(moaHELLKNIGHT_MOVE)
	db (64*256/100)
	dw lo16(mosHELLKNIGHT_DAMAGE)
	dw ((7<<8)|15)
	dw 0
	dw lo16(sxTeleport)
	dw lo16(sxBaronOfHellFight)
	dw lo16(sxBaronOfHellLaunch)
	dw lo16(sxBaronOfHellDamage)
	dw lo16(sxBaronOfHellDie)
	db (rlpfMovable|rlpfActive|rlpfSolid|rlpfTarget)
	db otHellKnight
modSpawnRevenant:
	dw 300
	dw lo16(_RLMVBaronOfHell)
	dw lo16(mosREVENANT_MOVE)
	dw lo16(moaREVENANT_MOVE)
	db (39*256/100)
	dw lo16(mosREVENANT_DAMAGE)
	dw ((6<<8)|7)
	dw 0
	dw lo16(sxTeleport)
	dw lo16(sxTrooperFight)
	dw lo16(sxMissileLaunch)
	dw lo16(sxDemonDamage)
	dw lo16(sxTrooperDie)
	db (rlpfMovable|rlpfActive|rlpfSolid|rlpfTarget)
	db otRevenant
modSpawnMancubus:
	dw 600
	dw lo16(_RLMVSoldier)
	dw lo16(mosMANCUBUS_MOVE)
	dw lo16(moaMANCUBUS_MOVE)
	db (31*256/100)
	dw lo16(mosMANCUBUS_DAMAGE)
	dw 0
	dw 0
	dw lo16(sxTeleport)
	dw 0
	dw lo16(sxFireBall1Launch)
	dw lo16(sxDemonDamage)
	dw lo16(sxCacoDemonDie)
	db (rlpfMovable|rlpfActive|rlpfSolid|rlpfTarget)
	db otMancubus
modSpawnArachnotron:
	dw 500
	dw lo16(_RLMVBaronOfHell)
	dw lo16(mosARACHNOTRON_MOVE)
	dw lo16(moaARACHNOTRON_MOVE)
	db (50*256/100)
	dw lo16(mosARACHNOTRON_DAMAGE)
	dw 0
	dw 0
	dw lo16(sxTeleport)
	dw 0
	dw lo16(sxPlasmaLaunch)
	dw lo16(sxDemonDamage)
	dw lo16(sxSpiderDemonDie)
	db (rlpfMovable|rlpfActive|rlpfSolid|rlpfTarget)
	db otArachnotron
modSpawnPainElemental:
	dw 400
	dw lo16(_RLMVSoldier)
	dw lo16(mosPAINELEMENTAL_MOVE)
	dw lo16(moaPAINELEMENTAL_MOVE)
	db (50*256/100)
	dw lo16(mosPAINELEMENTAL_DAMAGE)
	dw 0
	dw 0
	dw lo16(sxTeleport)
	dw 0
	dw lo16(sxLostSoulAwake)
	dw lo16(sxCacoDemonDamage)
	dw lo16(sxCacoDemonDie)
	db (rlpfMovable|rlpfActive|rlpfSolid|rlpfTarget)
	db otPainElemental
;
;	MAP30: what the boss shooter spawns (PC A_SpawnFly: imp 50, demon 40, spectre 30, pain
;	elemental 10, cacodemon 30, arch-vile 2, revenant 10, arachnotron 20, mancubus 30,
;	hell knight 24, baron 10 of 256): 16 slots
;
_RLBrainSpawnMods:
	dw lo16(modSpawnTrooper),lo16(modSpawnTrooper),lo16(modSpawnTrooper)
	dw lo16(modSpawnDemon),lo16(modSpawnDemon),lo16(modSpawnDemon),lo16(modSpawnDemon)
	dw lo16(modSpawnCacoDemon),lo16(modSpawnCacoDemon)
	dw lo16(modSpawnMancubus),lo16(modSpawnMancubus)
	dw lo16(modSpawnArachnotron)
	dw lo16(modSpawnHellKnight),lo16(modSpawnHellKnight)
	dw lo16(modSpawnRevenant)
	dw lo16(modSpawnPainElemental)
;
;	MAP30 spawn spot
;
modBossTarget:
	dw 0
	dw 0
	dw lo16(mosBOSSTARGET_SLEEP0)
	dw lo16(moaBOSSTARGET_SLEEP)
	db 0
	dw lo16(mosBOSSTARGET_DAMAGE)
	dw 0
	dw 0
	dw 0
	dw 0
	dw 0
	dw 0
	dw 0
	endif
;
;	>>>   FIREBALL 1   <<<
;
modFireBall1:
	dw 0	; FIREBALL1
	dw 0
	dw lo16(mosFIREBALL1_MOVE)
	dw lo16(moaFIREBALL1_MOVE)
	db 0
	dw lo16(mosFIREBALL1_DIE)
	dw 0
	dw ((4<<8)|3)
	dw lo16(sxFireBall1Launch)
	dw 0
	dw 0
	dw 0
	dw lo16(sxFireBall1Die)
	db (rlpfMovable|rlpfActive|rlpfProjectileFast)
	db otFireBall1
;
;	>>>   FIREBALL 2   <<<
;
modFireBall2:
	dw 0	; FIREBALL2
	dw 0
	dw lo16(mosFIREBALL2_MOVE)
	dw lo16(moaFIREBALL2_MOVE)
	db 0
	dw lo16(mosFIREBALL2_DIE)
	dw 0
	dw ((6<<8)|3)
	dw lo16(sxFireBall2Launch)
	dw 0
	dw 0
	dw 0
	dw lo16(sxFireBall2Die)
	db (rlpfMovable|rlpfActive|rlpfProjectileFast)
	db otFireBall2
;
;	>>>   FIREBALL 7   <<<
;
modFireBall7:
	dw 0	; FIREBALL7
	dw 0
	dw lo16(mosFIREBALL7_MOVE)
	dw lo16(moaFIREBALL7_MOVE)
	db 0
	dw lo16(mosFIREBALL7_DIE)
	dw 0
	dw ((4<<8)|7)
	dw lo16(sxFireBall7Launch)
	dw 0
	dw 0
	dw 0
	dw lo16(sxFireBall7Die)
	db (rlpfMovable|rlpfActive)
	db otFireBall7
;
;	>>>   MISSILE   <<<
;
modMissile:
	dw 0	; MISSILE
	dw 0
	dw lo16(mosMISSILE_MOVE)
	dw lo16(moaMISSILE_MOVE)
	db 0
	dw lo16(mosMISSILE_DIE)
	dw 0
	if useID2 == 0
	dw ((64<<8)|3)
	endif
	if useID2 != 0
	dw ((48<<8)|7)
	endif
	dw lo16(sxMissileLaunch)
	dw 0
	dw 0
	dw 0
	dw lo16(sxMissileDie)
	db (rlpfMovable|rlpfActive)
	db otMissile
;
;	>>>   BFG   <<<
;
modBFG:
	dw 0	; BFG
	dw 0
	dw lo16(mosBFG_MOVE)
	dw lo16(moaBFG_MOVE)
	db 0
	dw lo16(mosBFG_DIE)
	dw 0
	dw ((127<<8)|7)
	dw lo16(sxBFGLaunch)
	dw 0
	dw 0
	dw 0
	dw lo16(sxBFGDie)
	db (rlpfMovable|rlpfActive)
	db otFireBall7
;
;	>>>   PLASMA   <<<
;
modPlasma:
	dw 0	; PLASMA
	dw 0
	dw lo16(mosPLASMA_MOVE)
	dw lo16(moaPLASMA_MOVE)
	db 0
	dw lo16(mosPLASMA_DIE)
	dw 0
	dw ((32<<8)|3)
	dw lo16(sxPlasmaLaunch)
	dw 0
	dw 0
	dw 0
	dw lo16(sxPlasmaDie)
	db (rlpfMovable|rlpfActive)
	db otPlasma

;
;	>>>   BARREL EXPLOSION   <<<
;
modBarrelExp:
	dw 0	; BARREL EXPLOSION
	dw 0
	dw lo16(mosBARRELEXP_DIE)
	dw lo16(moaBARRELEXP_DIE)
	db 0
	dw 0
	dw 0
	if useID2 == 0
	dw ((16<<8)|3)
	endif
	if useID2 != 0
	if !RLSPECTRE != 0
	dw ((80<<8)|3)	; (Ultimate DOOM: 80; PC DOOM 128)
	else
	dw ((32<<8)|3)
	endif
	endif
	dw lo16(sxBarrelExplode)
	dw 0
	dw 0
	dw 0
	dw 0
	db (rlpfMovable|rlpfActive)
	db otBarrelExp

	if !RLDOOM2MONSTERS != 0
;
;	>>>   ARACHNOTRON PLASMA (DOOM II)   <<<
;
modArachPlasma:
	dw 0
	dw 0
	dw lo16(mosARACHPLASMA_MOVE)
	dw lo16(moaARACHPLASMA_MOVE)
	db 0
	dw lo16(mosARACHPLASMA_DIE)
	dw 0
	dw ((5<<8)|7)
	dw lo16(sxPlasmaLaunch)
	dw 0
	dw 0
	dw 0
	dw lo16(sxPlasmaDie)
	db (rlpfMovable|rlpfActive|rlpfProjectileFast)
	db otArachPlasma
;
;	>>>   MANCUBUS FIREBALL (DOOM II)   <<<
;
modMancubusShot:
	dw 0
	dw 0
	dw lo16(mosMANCUBUSSHOT_MOVE)
	dw lo16(moaMANCUBUSSHOT_MOVE)
	db 0
	dw lo16(mosMANCUBUSSHOT_DIE)
	dw 0
	dw ((8<<8)|7)
	dw lo16(sxFireBall1Launch)
	dw 0
	dw 0
	dw 0
	dw lo16(sxFireBall1Die)
	db (rlpfMovable|rlpfActive|rlpfProjectileFast)
	db otMancubusShot
;
;	>>>   REVENANT MISSILE (DOOM II, not homing)   <<<
;
modRevenantShot:
	dw 0
	dw 0
	dw lo16(mosREVENANTSHOT_MOVE)
	dw lo16(moaREVENANTSHOT_MOVE)
	db 0
	dw lo16(mosREVENANTSHOT_DIE)
	dw 0
	dw ((10<<8)|7)
	dw lo16(sxMissileLaunch)
	dw 0
	dw 0
	dw 0
	dw lo16(sxMissileDie)
	db (rlpfMovable|rlpfActive)
	db otRevenantShot
;
;	>>>   ARCH-VILE FIRE (DOOM II): flames that only play   <<<
;
modVileFire:
	dw 0
	dw 0
	dw lo16(mosVILEFIRE_DIE)
	dw lo16(moaVILEFIRE_DIE)
	db 0
	dw 0
	dw 0
	dw 0
	dw lo16(sxVileFire)	; Birth Sound (PC: DSFLAMST, then DSFLAME)
	dw 0
	dw 0
	dw 0
	dw 0
	db (rlpfMovable|rlpfActive)
	db otVileFire
	endif
