	arch 65816
;**********************************************************************
;*                                                                    *
;*                      P R O J E C T :   R A G E                     *
;*                                                                    *
;*                         OBJECT DATA MODULE 3                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlimages.inc"


	%section(_MOBJECTDATA)


;
;	* * * * * * *       PLAYER STATE TABLE       * * * * * * *
;
moaPLAYER_STAND:
	db 6	; A1
	db (inPlayerWalk+0)
	db 6	; B1
	db (inPlayerWalk+1)
	db $80
	dw lo16(moaPLAYER_STAND)

moaPLAYER_MOVE:
	db 6	; A1
	db (inPlayerWalk+0)
	db 6	; B1
	db (inPlayerWalk+1)
	db 6	; C1
	db (inPlayerWalk+2)
	db 6	; D1
	db (inPlayerWalk+3)
	db $80
	dw lo16(moaPLAYER_MOVE)

moaPLAYER_ATTACK:
	db 6	; E1
	db (inPlayerShoot+0)
	db 6	; F1
	db (inPlayerShoot+1)
	db 6	; E1
	db (inPlayerShoot+0)
	db $80
	dw lo16(moaPLAYER_MOVE)

moaPLAYER_DAMAGE:
	db 20	; G1
	db (inPlayerHit+0)
	db $80
	dw lo16(moaPLAYER_MOVE)

moaPLAYER_DIE:
	db 8	; H0
	db (inPlayerDie+0)
	db 8	; I0
	db (inPlayerDie+1)
	db 8	; J0
	db (inPlayerDie+2)
	db 8	; K0
	db (inPlayerDie+3)
	db $81	; L0
	dw lo16(_RLMAPlayerDie)
	db 1	; N0
	db (inPlayerDie+4)


;
;	* * * * * * *       SOLDIER STATE TABLE       * * * * * * *
;
mosSOLDIER_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaSOLDIER_MOVE),lo16(mosSOLDIER_AWAKE)
mosSOLDIER_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosSOLDIER_SLEEP)
moaSOLDIER_SLEEP:
	db 6	; A1
	db (inSoldierWalk+0)
	db 6	; B1
	db (inSoldierWalk+1)
	db $80
	dw lo16(moaSOLDIER_SLEEP)

mosSOLDIER_AWAKE:
	dw lo16(_RLMSEnemyAwake)
	dw lo16(_RLMSWait)
mosSOLDIER_MOVE:
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSEnemyMove),lo16(moaSOLDIER_ATTACK),lo16(mosSOLDIER_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSState),lo16(mosSOLDIER_MOVE)
moaSOLDIER_MOVE:
	db 6	; A1
	db (inSoldierWalk+0)
	db 6	; B1
	db (inSoldierWalk+1)
	db 6	; C1
	db (inSoldierWalk+2)
	db 6	; D1
	db (inSoldierWalk+3)
	db $80
	dw lo16(moaSOLDIER_MOVE)

mosSOLDIER_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosSOLDIER_MOVE)
moaSOLDIER_ATTACK:
	db 6	; E1
	db (inSoldierShoot+0)
	db $81	; F1
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEAShoot)
	db 6
	db (inSoldierShoot+1)
	db 6	; E1
	db (inSoldierShoot+0)
	db $80
	dw lo16(moaSOLDIER_MOVE)

mosSOLDIER_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaSOLDIER_DAMAGE),lo16(moaSOLDIER_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosSOLDIER_MOVE)
moaSOLDIER_DAMAGE:
	db 20	; G1
	db (inSoldierHit+0)
	db $80
	dw lo16(moaSOLDIER_MOVE)
moaSOLDIER_DIE:
	db 8	; H0
	db (inSoldierDie+0)
	db 8	; I0
	db (inSoldierDie+1)
	db 8	; J0
	db (inSoldierDie+2)
	db 8	; K0
	db (inSoldierDie+3)
	db $81	; L0
	dw lo16(_RLMASoldierDie)
	db 1
	db (inSoldierDie+4)


;
;	* * * * * * *       SERGEANT STATE TABLE       * * * * * * *
;
mosSERGEANT_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaSERGEANT_MOVE),lo16(mosSERGEANT_AWAKE)
mosSERGEANT_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosSERGEANT_SLEEP)
moaSERGEANT_SLEEP:
	db 6	; A1
	db (inSergeantWalk+0)
	db 6	; B1
	db (inSergeantWalk+1)
	db $80
	dw lo16(moaSERGEANT_SLEEP)

mosSERGEANT_AWAKE:
	dw lo16(_RLMSEnemyAwake)
	dw lo16(_RLMSWait)
mosSERGEANT_MOVE:
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSEnemyMove),lo16(moaSERGEANT_ATTACK),lo16(mosSERGEANT_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSState),lo16(mosSERGEANT_MOVE)
moaSERGEANT_MOVE:
	db 6	; A1
	db (inSergeantWalk+0)
	db 6	; B1
	db (inSergeantWalk+1)
	db 6	; C1
	db (inSergeantWalk+2)
	db 6	; D1
	db (inSergeantWalk+3)
	db $80
	dw lo16(moaSERGEANT_MOVE)

mosSERGEANT_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosSERGEANT_MOVE)
moaSERGEANT_ATTACK:
	db 6	; E1
	db (inSergeantShoot+0)
	db $81	; F1
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEAShoot)
	db 6
	db (inSergeantShoot+1)
	db 6	; E1
	db (inSergeantShoot+0)
	db $80
	dw lo16(moaSERGEANT_MOVE)

mosSERGEANT_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaSERGEANT_DAMAGE),lo16(moaSERGEANT_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosSERGEANT_MOVE)
moaSERGEANT_DAMAGE:
	db 20	; G1
	db (inSergeantHit+0)
	db $80
	dw lo16(moaSERGEANT_MOVE)
moaSERGEANT_DIE:
	db 8	; H0
	db (inSergeantDie+0)
	db 8	; I0
	db (inSergeantDie+1)
	db 8	; J0
	db (inSergeantDie+2)
	db 8	; K0
	db (inSergeantDie+3)
	db $81	; L0
	dw lo16(_RLMASergeantDie)
	db 1
	db (inSergeantDie+4)


;
;	* * * * * * *       TROOPER STATE TABLE       * * * * * * *
;
mosTROOPER_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaTROOPER_MOVE),lo16(mosTROOPER_MOVE)
mosTROOPER_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosTROOPER_SLEEP)
moaTROOPER_SLEEP:
	db 6	; A1
	db (inTrooperWalk+0)
	db 6	; B1
	db (inTrooperWalk+1)
	db $80
	dw lo16(moaTROOPER_SLEEP)

mosTROOPER_MOVE:
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSEnemyMove),lo16(moaTROOPER_ATTACK),lo16(mosTROOPER_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSState),lo16(mosTROOPER_MOVE)
moaTROOPER_MOVE:
	db 6	; A1
	db (inTrooperWalk+0)
	db 6	; B1
	db (inTrooperWalk+1)
	db 6	; C1
	db (inTrooperWalk+2)
	db 6	; D1
	db (inTrooperWalk+3)
	db $80
	dw lo16(moaTROOPER_MOVE)

mosTROOPER_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosTROOPER_MOVE)
moaTROOPER_ATTACK:
	db 6	; E1
	db (inTrooperShoot+0)
	db 6	; F1
	db (inTrooperShoot+1)
	db $81	; G1
	dw lo16(_RLMAQEnemyDAttack),lo16(_RLEAFight),lo16(_RLEALaunchFireBall1)
	db 6
	db (inTrooperShoot+2)
	db $80
	dw lo16(moaTROOPER_MOVE)

mosTROOPER_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaTROOPER_DAMAGE),lo16(moaTROOPER_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosTROOPER_MOVE)
moaTROOPER_DAMAGE:
	db 20	; H1
	db (inTrooperHit+0)
	db $80
	dw lo16(moaTROOPER_MOVE)
moaTROOPER_DIE:
	db 8	; I0
	db (inTrooperDie+0)
	db 8	; J0
	db (inTrooperDie+1)
	db 8	; K0
	db (inTrooperDie+2)
	db 8	; L0
	db (inTrooperDie+3)
	db $81	; M0
	dw lo16(_RLMAEnemyDie)
	db 1
	db (inTrooperDie+4)


;
;	* * * * * * *       DEMON STATE TABLE       * * * * * * *
;
mosDEMON_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaDEMON_MOVE),lo16(mosDEMON_MOVE)
mosDEMON_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosDEMON_SLEEP)
moaDEMON_SLEEP:
	db 6	; A1
	db (inDemonWalk+0)
	db 6	; B1
	db (inDemonWalk+1)
	db $80
	dw lo16(moaDEMON_SLEEP)

mosDEMON_MOVE:
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSEnemyMove0),lo16(moaDEMON_ATTACK),lo16(mosDEMON_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSState),lo16(mosDEMON_MOVE)
moaDEMON_MOVE:
	db 6	; A1
	db (inDemonWalk+0)
	db 6	; B1
	db (inDemonWalk+1)
	db 6	; C1
	db (inDemonWalk+2)
	db 6	; D1
	db (inDemonWalk+3)
	db $80
	dw lo16(moaDEMON_MOVE)

mosDEMON_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosDEMON_MOVE)
moaDEMON_ATTACK:
	db 6	; E1
	db (inDemonBite+0)
	db 6	; F1
	db (inDemonBite+1)
	db $81	; G1
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEAFight)
	db 6
	db (inDemonBite+2)
	db $80
	dw lo16(moaDEMON_MOVE)

mosDEMON_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaDEMON_DAMAGE),lo16(moaDEMON_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosDEMON_MOVE)
moaDEMON_DAMAGE:
	db 20	; H1
	db (inDemonHit+0)
	db $80
	dw lo16(moaDEMON_MOVE)
moaDEMON_DIE:
	db 8	; I0
	db (inDemonDie+0)
	db 8	; K0
	db (inDemonDie+1)
	db 8	; L0
	db (inDemonDie+2)
	db $81	; N0
	dw lo16(_RLMAEnemyDie)
	db 1
	db (inDemonDie+3)


;
;	* * * * * * *       CACODEMON STATE TABLE       * * * * * * *
;
mosCACODEMON_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaCACODEMON_MOVE),lo16(mosCACODEMON_MOVE)
mosCACODEMON_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosCACODEMON_SLEEP)

mosCACODEMON_MOVE:
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSEnemyMove),lo16(moaCACODEMON_ATTACK),lo16(mosCACODEMON_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSState),lo16(mosCACODEMON_MOVE)
moaCACODEMON_SLEEP:
moaCACODEMON_MOVE:
	db 127	; A1
	db (inCacoDemonFloat+0)
	db $80
	dw lo16(moaCACODEMON_MOVE)

mosCACODEMON_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosCACODEMON_MOVE)
moaCACODEMON_ATTACK:
	db 6	; B1
	db (inCacoDemonBite+0)
	db 6	; C1
	db (inCacoDemonBite+1)
	db $81	; D1
	dw lo16(_RLMAQEnemyDAttack),lo16(_RLEAFight),lo16(_RLEALaunchFireBall2)
	db 6
	db (inCacoDemonBite+2)
	db $80
	dw lo16(moaCACODEMON_MOVE)

mosCACODEMON_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaCACODEMON_DAMAGE),lo16(moaCACODEMON_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosCACODEMON_MOVE)
moaCACODEMON_DAMAGE:
	db 8	; E1
	db (inCacoDemonHit+0)
	db 20	; F1
	db (inCacoDemonHit+1)
	db $80
	dw lo16(moaCACODEMON_MOVE)
moaCACODEMON_DIE:
	db 9	; H0
	db (inCacoDemonDie+0)
	db 9	; J0
	db (inCacoDemonDie+1)
	db 9	; K0
	db (inCacoDemonDie+2)
	db $81	; L0
	dw lo16(_RLMAEnemyFall)
	db 1
	db (inCacoDemonDie+3)


;
;	* * * * * * *       LOSTSOUL STATE TABLE       * * * * * * *
;
mosLOSTSOUL_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaLOSTSOUL_MOVE),lo16(mosLOSTSOUL_MOVE)
mosLOSTSOUL_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosLOSTSOUL_SLEEP)

mosLOSTSOUL_MOVE:
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSEnemyMove),lo16(moaLOSTSOUL_ATTACK),lo16(mosLOSTSOUL_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSState),lo16(mosLOSTSOUL_MOVE)
moaLOSTSOUL_SLEEP:
moaLOSTSOUL_MOVE:
	db 6	; A1
	db (inLostSoulFloat+0)
	db 6	; B1
	db (inLostSoulFloat+1)
	db $80
	dw lo16(moaLOSTSOUL_MOVE)

mosLOSTSOUL_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosLOSTSOUL_MOVE)
moaLOSTSOUL_ATTACK:
	db 6	; C1
	db (inLostSoulBite+0)
	db 6	; D1
	db (inLostSoulBite+1)
	db $81	; C1
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEAFight)
	db 6
	db (inLostSoulBite+0)
	db 6	; D1
	db (inLostSoulBite+1)
	db $80
	dw lo16(moaLOSTSOUL_MOVE)

mosLOSTSOUL_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaLOSTSOUL_DAMAGE),lo16(moaLOSTSOUL_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosLOSTSOUL_MOVE)
moaLOSTSOUL_DAMAGE:
	db 8	; E1
	db (inLostSoulHit+0)
	db $80
	dw lo16(moaLOSTSOUL_MOVE)
moaLOSTSOUL_DIE:
	db 8	; F0
	db (inLostSoulDie+0)
	db 8	; H0
	db (inLostSoulDie+1)
	db 8	; I0
	db (inLostSoulDie+2)
	db $81
	dw lo16(_RLMAEnemyDie2)
	db 1	; I0
	db (inLostSoulDie+2)


;
;	* * * * * * *       BARONOFHELL STATE TABLE       * * * * * * *
;
mosBARONOFHELL_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaBARONOFHELL_MOVE),lo16(mosBARONOFHELL_MOVE)
mosBARONOFHELL_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosBARONOFHELL_SLEEP)
moaBARONOFHELL_SLEEP:
	db 6	; A1
	db (inBaronOfHellWalk+0)
	db 6	; B1
	db (inBaronOfHellWalk+1)
	db $80
	dw lo16(moaBARONOFHELL_SLEEP)

mosBARONOFHELL_MOVE:
	dw lo16(_RLMSEnemyMove),lo16(moaBARONOFHELL_ATTACK),lo16(mosBARONOFHELL_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosBARONOFHELL_MOVE)
moaBARONOFHELL_MOVE:
	db 6	; A1
	db (inBaronOfHellWalk+0)
	db 6	; B1
	db (inBaronOfHellWalk+1)
	db 6	; C1
	db (inBaronOfHellWalk+2)
	db 6	; D1
	db (inBaronOfHellWalk+3)
	db $80
	dw lo16(moaBARONOFHELL_MOVE)

mosBARONOFHELL_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosBARONOFHELL_MOVE)
moaBARONOFHELL_ATTACK:
	db 6	; E1
	db (inBaronOfHellShoot+0)
	db 6	; F1
	db (inBaronOfHellShoot+1)
	db $81	; G1
	dw lo16(_RLMAQEnemyDAttack),lo16(_RLEAFight),lo16(_RLEALaunchFireBall7)
	db 6
	db (inBaronOfHellShoot+2)
	db $80
	dw lo16(moaBARONOFHELL_MOVE)

mosBARONOFHELL_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaBARONOFHELL_DAMAGE),lo16(moaBARONOFHELL_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosBARONOFHELL_MOVE)
moaBARONOFHELL_DAMAGE:
	db 20	; H1
	db (inBaronOfHellHit+0)
	db $80
	dw lo16(moaBARONOFHELL_MOVE)
moaBARONOFHELL_DIE:
	db 8	; J0
	db (inBaronOfHellDie+0)
	db 8	; K0
	db (inBaronOfHellDie+1)
	db 8	; L0
	db (inBaronOfHellDie+2)
	db $81	; M0
	dw lo16(_RLMABaronOfHellDie)
	db 1
	db (inBaronOfHellDie+3)


;
;	* * * * * * *       CYBERDEMON STATE TABLE       * * * * * * *
;
mosCYBERDEMON_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaCYBERDEMON_MOVE),lo16(mosCYBERDEMON_MOVE)
mosCYBERDEMON_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosCYBERDEMON_SLEEP)
moaCYBERDEMON_SLEEP:
	db 8	; A1
	db (inCyberDemonWalk+0)
	db 8	; B1
	db (inCyberDemonWalk+1)
	db $80
	dw lo16(moaCYBERDEMON_SLEEP)

mosCYBERDEMON_MOVE:
	dw lo16(_RLMSEnemyMove),lo16(moaCYBERDEMON_ATTACK),lo16(mosCYBERDEMON_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosCYBERDEMON_MOVE)
moaCYBERDEMON_MOVE:
	db 8	; A1
	db (inCyberDemonWalk+0)
	db 8	; B1
	db (inCyberDemonWalk+1)
	db 8	; C1
	db (inCyberDemonWalk+2)
	db 8	; D1
	db (inCyberDemonWalk+3)
	db $80
	dw lo16(moaCYBERDEMON_MOVE)

mosCYBERDEMON_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosCYBERDEMON_MOVE)
moaCYBERDEMON_ATTACK:
	db 8	; E1
	db (inCyberDemonShoot+0)
	db 8	; F1
	db (inCyberDemonShoot+1)
	db $81	; E1
	dw lo16(_RLMAQEnemyDAttack),lo16(_RLEAFight),lo16(_RLEALaunchMissile)
	db 8
	db (inCyberDemonShoot+0)
;
	db 8	; E1
	db (inCyberDemonShoot+0)
	db 8	; F1
	db (inCyberDemonShoot+1)
	db $81	; E1
	dw lo16(_RLMAQEnemyDAttack),lo16(_RLEAFight),lo16(_RLEALaunchMissile)
	db 8
	db (inCyberDemonShoot+0)
;
	db $80
	dw lo16(moaCYBERDEMON_MOVE)

mosCYBERDEMON_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaCYBERDEMON_DAMAGE),lo16(moaCYBERDEMON_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosCYBERDEMON_MOVE)
moaCYBERDEMON_DAMAGE:
	db 20	; G1
	db (inCyberDemonHit+0)
	db $80
	dw lo16(moaCYBERDEMON_MOVE)
moaCYBERDEMON_DIE:
	db 8	; I0
	db (inCyberDemonDie+0)
	db 8	; J0
	db (inCyberDemonDie+1)
	db 8	; K0
	db (inCyberDemonDie+2)
	db 8	; O0
	db (inCyberDemonDie+3)
	db $81	; P0
	dw lo16(_RLMACyberDemonDie)
	db 1
	db (inCyberDemonDie+4)


;
;	* * * * * * *       SPIDERDEMON STATE TABLE       * * * * * * *
;
mosSPIDERDEMON_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaSPIDERDEMON_MOVE),lo16(mosSPIDERDEMON_MOVE)
mosSPIDERDEMON_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosSPIDERDEMON_SLEEP)
moaSPIDERDEMON_SLEEP:
	db 8	; A1
	db (inSpiderDemonWalk+0)
	db $80
	dw lo16(moaSPIDERDEMON_SLEEP)

mosSPIDERDEMON_MOVE:
	dw lo16(_RLMSEnemyMove),lo16(moaSPIDERDEMON_ATTACK),lo16(mosSPIDERDEMON_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosSPIDERDEMON_MOVE)
moaSPIDERDEMON_MOVE:
	db 8	; A1
	db (inSpiderDemonWalk+0)
	db 8	; B1
	db (inSpiderDemonWalk+1)
	db 8	; A1
	db (inSpiderDemonWalk+0)
	db 8	; C1
	db (inSpiderDemonWalk+2)
	db $80
	dw lo16(moaSPIDERDEMON_MOVE)

mosSPIDERDEMON_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosSPIDERDEMON_MOVE)
moaSPIDERDEMON_ATTACK:
	db 8	; G1
	db (inSpiderDemonShoot+0)
	db $81	; H1
	dw lo16(_RLMAQEnemyDAttack),lo16(_RLEAFight),lo16(_RLEAShoot)
	db 8
	db (inSpiderDemonShoot+1)
;
	db 8	; G1
	db (inSpiderDemonShoot+0)
	db $81	; H1
	dw lo16(_RLMAQEnemyDAttack),lo16(_RLEAFight),lo16(_RLEAShoot)
	db 8
	db (inSpiderDemonShoot+1)
;
	db $80
	dw lo16(moaSPIDERDEMON_MOVE)

mosSPIDERDEMON_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaSPIDERDEMON_DAMAGE),lo16(moaSPIDERDEMON_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosSPIDERDEMON_MOVE)
moaSPIDERDEMON_DAMAGE:
	db 20	; I1
	db (inSpiderDemonHit+0)
	db $80
	dw lo16(moaSPIDERDEMON_MOVE)
moaSPIDERDEMON_DIE:
	db 8	; K0
	db (inSpiderDemonDie+0)
	db 8	; M0
	db (inSpiderDemonDie+1)
	db 8	; O0
	db (inSpiderDemonDie+2)
	db $81	; S0
	dw lo16(_RLMASpiderDie)
	db 1
	db (inSpiderDemonDie+3)


	if !RLDOOM2MONSTERS != 0
;
;	* * * * * * *       CHAINGUNNER STATE TABLE (DOOM II)       * * * * * * *
;
mosCHAINGUNNER_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaCHAINGUNNER_MOVE),lo16(mosCHAINGUNNER_AWAKE)
mosCHAINGUNNER_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosCHAINGUNNER_SLEEP)
moaCHAINGUNNER_SLEEP:
	db 6	; A1
	db (inChainGunnerWalk+0)
	db 6	; B1
	db (inChainGunnerWalk+1)
	db $80
	dw lo16(moaCHAINGUNNER_SLEEP)

mosCHAINGUNNER_AWAKE:
	dw lo16(_RLMSEnemyAwake)
	dw lo16(_RLMSWait)
mosCHAINGUNNER_MOVE:
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSEnemyMove),lo16(moaCHAINGUNNER_ATTACK),lo16(mosCHAINGUNNER_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSState),lo16(mosCHAINGUNNER_MOVE)
moaCHAINGUNNER_MOVE:
	db 6	; A1
	db (inChainGunnerWalk+0)
	db 6	; B1
	db (inChainGunnerWalk+1)
	db 6	; C1
	db (inChainGunnerWalk+2)
	db 6	; D1
	db (inChainGunnerWalk+3)
	db $80
	dw lo16(moaCHAINGUNNER_MOVE)

;
;	(PC: E aim, then F fire / E / F fire ... while it sees the player.  Here
;	 four shots, each through the attack check, as the Spider Demon's burst)
;
mosCHAINGUNNER_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosCHAINGUNNER_MOVE)
moaCHAINGUNNER_ATTACK:
	db 6	; E1
	db (inChainGunnerShoot+0)
	db $81	; F1
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEAShoot)
	db 3
	db (inChainGunnerShoot+1)
	db 3	; E1
	db (inChainGunnerShoot+0)
	db $81	; F1
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEAShoot)
	db 3
	db (inChainGunnerShoot+1)
	db 3	; E1
	db (inChainGunnerShoot+0)
	db $81	; F1
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEAShoot)
	db 3
	db (inChainGunnerShoot+1)
	db 3	; E1
	db (inChainGunnerShoot+0)
	db $81	; F1
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEAShoot)
	db 3
	db (inChainGunnerShoot+1)
	db 6	; E1
	db (inChainGunnerShoot+0)
	db $80
	dw lo16(moaCHAINGUNNER_MOVE)

mosCHAINGUNNER_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaCHAINGUNNER_DAMAGE),lo16(moaCHAINGUNNER_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosCHAINGUNNER_MOVE)
moaCHAINGUNNER_DAMAGE:
	db 20	; G1
	db (inChainGunnerHit+0)
	db $80
	dw lo16(moaCHAINGUNNER_MOVE)
moaCHAINGUNNER_DIE:
	db 8	; H0
	db (inChainGunnerDie+0)
	db 8	; J0
	db (inChainGunnerDie+1)
	db 8	; L0
	db (inChainGunnerDie+2)
	db $81	; N0
	dw lo16(_RLMASoldierDie)	; (now an item: its chaingun)
	db 1
	db (inChainGunnerDie+3)

;
;	* * * * * * *       WOLFENSTEIN SS STATE TABLE (DOOM II)       * * * * * * *
;
mosWOLFSS_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaWOLFSS_MOVE),lo16(mosWOLFSS_AWAKE)
mosWOLFSS_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosWOLFSS_SLEEP)
moaWOLFSS_SLEEP:
	db 6	; A1
	db (inWolfSSWalk+0)
	db 6	; B1
	db (inWolfSSWalk+1)
	db $80
	dw lo16(moaWOLFSS_SLEEP)

mosWOLFSS_AWAKE:
	dw lo16(_RLMSEnemyAwake)
	dw lo16(_RLMSWait)
mosWOLFSS_MOVE:
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSEnemyMove),lo16(moaWOLFSS_ATTACK),lo16(mosWOLFSS_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSState),lo16(mosWOLFSS_MOVE)
moaWOLFSS_MOVE:
	db 6	; A1
	db (inWolfSSWalk+0)
	db 6	; B1
	db (inWolfSSWalk+1)
	db 6	; C1
	db (inWolfSSWalk+2)
	db 6	; D1
	db (inWolfSSWalk+3)
	db $80
	dw lo16(moaWOLFSS_MOVE)

mosWOLFSS_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosWOLFSS_MOVE)
moaWOLFSS_ATTACK:
	db 8	; E0 (aim)
	db (inWolfSSShoot+0)
	db 4	; F0
	db (inWolfSSShoot+1)
	db $81	; G0
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEAShoot)
	db 4
	db (inWolfSSShoot+2)
	db 4	; F0
	db (inWolfSSShoot+1)
	db $81	; G0
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEAShoot)
	db 4
	db (inWolfSSShoot+2)
	db 6	; F0
	db (inWolfSSShoot+1)
	db $80
	dw lo16(moaWOLFSS_MOVE)

mosWOLFSS_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaWOLFSS_DAMAGE),lo16(moaWOLFSS_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosWOLFSS_MOVE)
moaWOLFSS_DAMAGE:
	db 20	; H0
	db (inWolfSSHit+0)
	db $80
	dw lo16(moaWOLFSS_MOVE)
moaWOLFSS_DIE:
	db 10	; I0
	db (inWolfSSDie+0)
	db 10	; K0
	db (inWolfSSDie+1)
	db $81	; M0
	dw lo16(_RLMASoldierDie)	; (now an item: a clip)
	db 1
	db (inWolfSSDie+2)

;
;	* * * * * * *       HELL KNIGHT STATE TABLE (DOOM II)       * * * * * * *
;
mosHELLKNIGHT_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaHELLKNIGHT_MOVE),lo16(mosHELLKNIGHT_MOVE)
mosHELLKNIGHT_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosHELLKNIGHT_SLEEP)
moaHELLKNIGHT_SLEEP:
	db 6	; A1
	db (inHellKnightWalk+0)
	db 6	; B1
	db (inHellKnightWalk+1)
	db $80
	dw lo16(moaHELLKNIGHT_SLEEP)

mosHELLKNIGHT_MOVE:
	dw lo16(_RLMSEnemyMove),lo16(moaHELLKNIGHT_ATTACK),lo16(mosHELLKNIGHT_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosHELLKNIGHT_MOVE)
moaHELLKNIGHT_MOVE:
	db 6	; A1
	db (inHellKnightWalk+0)
	db 6	; B1
	db (inHellKnightWalk+1)
	db 6	; C1 (= A1)
	db (inHellKnightWalk+0)
	db 6	; D1 (= B1)
	db (inHellKnightWalk+1)
	db $80
	dw lo16(moaHELLKNIGHT_MOVE)

mosHELLKNIGHT_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosHELLKNIGHT_MOVE)
moaHELLKNIGHT_ATTACK:
	db 6	; E1
	db (inHellKnightShoot+0)
	db 6	; F1
	db (inHellKnightShoot+1)
	db $81	; G1
	dw lo16(_RLMAQEnemyDAttack),lo16(_RLEAFight),lo16(_RLEALaunchFireBall7)
	db 6
	db (inHellKnightShoot+2)
	db $80
	dw lo16(moaHELLKNIGHT_MOVE)

mosHELLKNIGHT_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaHELLKNIGHT_DAMAGE),lo16(moaHELLKNIGHT_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosHELLKNIGHT_MOVE)
moaHELLKNIGHT_DAMAGE:
	db 20	; H1
	db (inHellKnightHit+0)
	db $80
	dw lo16(moaHELLKNIGHT_MOVE)
moaHELLKNIGHT_DIE:
	db 8	; I0
	db (inHellKnightDie+0)
	db 8	; K0
	db (inHellKnightDie+1)
	db 8	; M0
	db (inHellKnightDie+2)
	db $81	; O0
	dw lo16(_RLMAEnemyDie)
	db 1
	db (inHellKnightDie+3)

;
;	* * * * * * *       ARACHNOTRON STATE TABLE (DOOM II)       * * * * * * *
;
mosARACHNOTRON_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaARACHNOTRON_MOVE),lo16(mosARACHNOTRON_AWAKE)
mosARACHNOTRON_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosARACHNOTRON_SLEEP)
moaARACHNOTRON_SLEEP:
	db 8	; A1
	db (inArachnotronWalk+0)
	db 8	; B1
	db (inArachnotronWalk+1)
	db $80
	dw lo16(moaARACHNOTRON_SLEEP)

mosARACHNOTRON_AWAKE:
	dw lo16(_RLMSEnemyAwake)
	dw lo16(_RLMSWait)
mosARACHNOTRON_MOVE:
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSEnemyMove),lo16(moaARACHNOTRON_ATTACK),lo16(mosARACHNOTRON_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSState),lo16(mosARACHNOTRON_MOVE)
moaARACHNOTRON_MOVE:
	db 5	; A1
	db (inArachnotronWalk+0)
	db 5	; B1
	db (inArachnotronWalk+1)
	db 5	; C1
	db (inArachnotronWalk+2)
	db 5	; D1 (= A1)
	db (inArachnotronWalk+0)
	db 5	; E1
	db (inArachnotronWalk+1)
	db 5	; F1
	db (inArachnotronWalk+2)
	db $80
	dw lo16(moaARACHNOTRON_MOVE)

mosARACHNOTRON_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosARACHNOTRON_MOVE)
moaARACHNOTRON_ATTACK:
	db 20	; G1 (aim)
	db (inArachnotronShoot+0)
	db $81	; H1 fire
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEALaunchArachPlasma)
	db 4
	db (inArachnotronShoot+1)
	db 4	; G1
	db (inArachnotronShoot+0)
	db $81	; H1 fire
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEALaunchArachPlasma)
	db 4
	db (inArachnotronShoot+1)
	db 4	; G1
	db (inArachnotronShoot+0)
	db $81	; H1 fire
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEALaunchArachPlasma)
	db 4
	db (inArachnotronShoot+1)
	db 4	; G1
	db (inArachnotronShoot+0)
	db $81	; H1 fire
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEALaunchArachPlasma)
	db 8
	db (inArachnotronShoot+1)
	db $80
	dw lo16(moaARACHNOTRON_MOVE)

mosARACHNOTRON_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaARACHNOTRON_DAMAGE),lo16(moaARACHNOTRON_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosARACHNOTRON_MOVE)
moaARACHNOTRON_DAMAGE:
	db 20	; I1
	db (inArachnotronHit+0)
	db $80
	dw lo16(moaARACHNOTRON_MOVE)
moaARACHNOTRON_DIE:
	db 8	; J0
	db (inArachnotronDie+0)
	db 8	; L0
	db (inArachnotronDie+1)
	db 8	; N0
	db (inArachnotronDie+2)
	db $81	; P0
	dw lo16(_RLMAArachnotronDie)
	db 1
	db (inArachnotronDie+3)

;
;	* * * * * * *       MANCUBUS STATE TABLE (DOOM II)       * * * * * * *
;
mosMANCUBUS_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaMANCUBUS_MOVE),lo16(mosMANCUBUS_AWAKE)
mosMANCUBUS_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosMANCUBUS_SLEEP)
moaMANCUBUS_SLEEP:
	db 10	; A1
	db (inMancubusWalk+0)
	db 10	; B1
	db (inMancubusWalk+1)
	db $80
	dw lo16(moaMANCUBUS_SLEEP)

mosMANCUBUS_AWAKE:
	dw lo16(_RLMSEnemyAwake)
	dw lo16(_RLMSWait)
mosMANCUBUS_MOVE:
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSEnemyMove),lo16(moaMANCUBUS_ATTACK),lo16(mosMANCUBUS_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSState),lo16(mosMANCUBUS_MOVE)
moaMANCUBUS_MOVE:
	db 8	; A1
	db (inMancubusWalk+0)
	db 8	; B1
	db (inMancubusWalk+1)
	db 8	; C1
	db (inMancubusWalk+2)
	db $80
	dw lo16(moaMANCUBUS_MOVE)

mosMANCUBUS_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosMANCUBUS_MOVE)
moaMANCUBUS_ATTACK:
	db 20	; G1 (aim)
	db (inMancubusShoot+0)
	db $81	; H1 fire left
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEALaunchMancubusL)
	db 1
	db (inMancubusShoot+1)
	db $81	; H1 fire right
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEALaunchMancubusR)
	db 8
	db (inMancubusShoot+1)
	db 10	; G1
	db (inMancubusShoot+0)
	db $81	; H1 fire left
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEALaunchMancubusL)
	db 1
	db (inMancubusShoot+1)
	db $81	; H1 fire right
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEALaunchMancubusR)
	db 8
	db (inMancubusShoot+1)
	db 10	; G1
	db (inMancubusShoot+0)
	db $81	; H1 fire left
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEALaunchMancubusL)
	db 1
	db (inMancubusShoot+1)
	db $81	; H1 fire right
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEALaunchMancubusR)
	db 8
	db (inMancubusShoot+1)
	db 10	; G1
	db (inMancubusShoot+0)
	db $80
	dw lo16(moaMANCUBUS_MOVE)

mosMANCUBUS_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaMANCUBUS_DAMAGE),lo16(moaMANCUBUS_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosMANCUBUS_MOVE)
moaMANCUBUS_DAMAGE:
	db 20	; J1
	db (inMancubusHit+0)
	db $80
	dw lo16(moaMANCUBUS_MOVE)
moaMANCUBUS_DIE:
	db 8	; K0
	db (inMancubusDie+0)
	db 8	; M0
	db (inMancubusDie+1)
	db 8	; O0
	db (inMancubusDie+2)
	db $81	; T0
	dw lo16(_RLMAMancubusDie)
	db 1
	db (inMancubusDie+3)

;
;	* * * * * * *       REVENANT STATE TABLE (DOOM II)       * * * * * * *
;
mosREVENANT_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaREVENANT_MOVE),lo16(mosREVENANT_AWAKE)
mosREVENANT_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosREVENANT_SLEEP)
moaREVENANT_SLEEP:
	db 8	; A1
	db (inRevenantWalk+0)
	db 8	; B1
	db (inRevenantWalk+1)
	db $80
	dw lo16(moaREVENANT_SLEEP)

mosREVENANT_AWAKE:
	dw lo16(_RLMSEnemyAwake)
	dw lo16(_RLMSWait)
mosREVENANT_MOVE:
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSEnemyMove),lo16(moaREVENANT_ATTACK),lo16(mosREVENANT_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSState),lo16(mosREVENANT_MOVE)
moaREVENANT_MOVE:
	db 4	; A1
	db (inRevenantWalk+0)
	db 4	; B1
	db (inRevenantWalk+1)
	db 4	; C1
	db (inRevenantWalk+2)
	db $80
	dw lo16(moaREVENANT_MOVE)

mosREVENANT_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosREVENANT_MOVE)
moaREVENANT_ATTACK:
	db 10	; J1 (aim)
	db (inRevenantShoot+0)
	db $81	; K1 punch or missile
	dw lo16(_RLMAQEnemyDAttack),lo16(_RLEAFight),lo16(_RLEALaunchRevenantShot)
	db 10
	db (inRevenantShoot+1)
	db $80
	dw lo16(moaREVENANT_MOVE)

mosREVENANT_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaREVENANT_DAMAGE),lo16(moaREVENANT_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosREVENANT_MOVE)
moaREVENANT_DAMAGE:
	db 10	; L1
	db (inRevenantHit+0)
	db $80
	dw lo16(moaREVENANT_MOVE)
moaREVENANT_DIE:
	db 8	; M0
	db (inRevenantDie+0)
	db 8	; O0
	db (inRevenantDie+1)
	db $81	; Q0
	dw lo16(_RLMAEnemyDie)
	db 1
	db (inRevenantDie+2)

;
;	* * * * * * *       PAIN ELEMENTAL STATE TABLE (DOOM II)       * * * * * * *
;
mosPAINELEMENTAL_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaPAINELEMENTAL_MOVE),lo16(mosPAINELEMENTAL_AWAKE)
mosPAINELEMENTAL_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosPAINELEMENTAL_SLEEP)
moaPAINELEMENTAL_SLEEP:
	db 10	; A1
	db (inPainElemWalk+0)
	db 10	; B1
	db (inPainElemWalk+1)
	db $80
	dw lo16(moaPAINELEMENTAL_SLEEP)

mosPAINELEMENTAL_AWAKE:
	dw lo16(_RLMSEnemyAwake)
	dw lo16(_RLMSWait)
mosPAINELEMENTAL_MOVE:
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSEnemyMove),lo16(moaPAINELEMENTAL_ATTACK),lo16(mosPAINELEMENTAL_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSState),lo16(mosPAINELEMENTAL_MOVE)
moaPAINELEMENTAL_MOVE:
	db 6	; A1
	db (inPainElemWalk+0)
	db 6	; B1
	db (inPainElemWalk+1)
	db 6	; C1
	db (inPainElemWalk+2)
	db $80
	dw lo16(moaPAINELEMENTAL_MOVE)

mosPAINELEMENTAL_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosPAINELEMENTAL_MOVE)
moaPAINELEMENTAL_ATTACK:
	db 10	; E1
	db (inPainElemShoot+0)
	db $81	; F1 spit a lost soul
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEALaunchLostSoul)
	db 10
	db (inPainElemShoot+1)
	db $80
	dw lo16(moaPAINELEMENTAL_MOVE)

mosPAINELEMENTAL_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaPAINELEMENTAL_DAMAGE),lo16(moaPAINELEMENTAL_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosPAINELEMENTAL_MOVE)
moaPAINELEMENTAL_DAMAGE:
	db 12	; G1
	db (inPainElemHit+0)
	db $80
	dw lo16(moaPAINELEMENTAL_MOVE)
moaPAINELEMENTAL_DIE:
	db 8	; H0
	db (inPainElemDie+0)
	db 8	; J0
	db (inPainElemDie+1)
	db $81	; L0 (gone: PC A_PainDie)
	dw lo16(_RLMAEnemyDie2)
	db 1
	db (inPainElemDie+2)

;
;	* * * * * * *       ARCH-VILE STATE TABLE (DOOM II)       * * * * * * *
;
mosARCHVILE_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaARCHVILE_MOVE),lo16(mosARCHVILE_AWAKE)
mosARCHVILE_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosARCHVILE_SLEEP)
moaARCHVILE_SLEEP:
	db 10	; A1
	db (inArchVileWalk+0)
	db 10	; B1
	db (inArchVileWalk+1)
	db $80
	dw lo16(moaARCHVILE_SLEEP)

mosARCHVILE_AWAKE:
	dw lo16(_RLMSEnemyAwake)
	dw lo16(_RLMSWait)
mosARCHVILE_MOVE:
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSEnemyMove),lo16(moaARCHVILE_ATTACK),lo16(mosARCHVILE_ATTACK)
	dw lo16(_RLMSQEnemyMove)
	dw lo16(_RLMSState),lo16(mosARCHVILE_MOVE)
moaARCHVILE_MOVE:
	db 3	; A1
	db (inArchVileWalk+0)
	db 3	; B1
	db (inArchVileWalk+1)
	db 3	; C1
	db (inArchVileWalk+2)
	db $80
	dw lo16(moaARCHVILE_MOVE)

mosARCHVILE_ATTACK:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosARCHVILE_MOVE)
moaARCHVILE_ATTACK:
	db 12	; G1
	db (inArchVileShoot+0)
	db 12	; J1
	db (inArchVileShoot+1)
	db $81	; O1 fire
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEAVileAttack)
	db 12
	db (inArchVileShoot+2)
	db $80
	dw lo16(moaARCHVILE_MOVE)

mosARCHVILE_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaARCHVILE_DAMAGE),lo16(moaARCHVILE_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosARCHVILE_MOVE)
moaARCHVILE_DAMAGE:
	db 10	; Q1
	db (inArchVileHit+0)
	db $80
	dw lo16(moaARCHVILE_MOVE)
moaARCHVILE_DIE:
	db 7	; R0
	db (inArchVileDie+0)
	db 7	; T0
	db (inArchVileDie+1)
	db 7	; V0
	db (inArchVileDie+2)
	db 7	; X0
	db (inArchVileDie+3)
	db $81	; Z0
	dw lo16(_RLMAEnemyDie)
	db 1
	db (inArchVileDie+4)

;
;	* * * * * * *       COMMANDER KEEN STATE TABLE (DOOM II)       * * * * * * *
;
mosKEEN_SLEEP:
mosKEEN_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosKEEN_SLEEP0)
moaKEEN_SLEEP:
	db 1	; A0
	db (inKeen+0)
	db $81	; hang from the ceiling
	dw lo16(_RLMAHang)
	db 1
	db (inKeen+0)
moaKEEN_STAND:
	db 127	; A0
	db (inKeen+0)
	db $80
	dw lo16(moaKEEN_STAND)
mosKEEN_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaKEEN_DAMAGE),lo16(moaKEEN_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosKEEN_SLEEP0)
moaKEEN_DAMAGE:
	db 8	; M0
	db (inKeenHit+0)
	db $80
	dw lo16(moaKEEN_STAND)
moaKEEN_DIE:
	db 6	; B0
	db (inKeenDie+0)
	db 6	; E0
	db (inKeenDie+1)
	db 6	; H0
	db (inKeenDie+2)
	db $81	; L0
	dw lo16(_RLMAKeenDie)
	db 1
	db (inKeenDie+3)

;
;	* * * * * * *       BOSS BRAIN STATE TABLE (DOOM II MAP30)       * * * * * * *
;
mosBOSSBRAIN_SLEEP:
mosBOSSBRAIN_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosBOSSBRAIN_SLEEP0)
moaBOSSBRAIN_SLEEP:
	db 127	; A0
	db (inBossBrain+0)
	db $80
	dw lo16(moaBOSSBRAIN_SLEEP)
mosBOSSBRAIN_DAMAGE:
	dw lo16(_RLMSEnemyDamage),lo16(moaBOSSBRAIN_DAMAGE),lo16(moaBOSSBRAIN_DIE)
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosBOSSBRAIN_SLEEP0)
moaBOSSBRAIN_DAMAGE:
	db 36	; B0
	db (inBossBrain+1)
	db $80
	dw lo16(moaBOSSBRAIN_SLEEP)
moaBOSSBRAIN_DIE:
	db 50	; B0
	db (inBossBrain+1)
	db $81	; (the level ends)
	dw lo16(_RLMASpiderDemonDie)
	db 1
	db (inBossBrain+1)

;
;	* * * * * * *       BOSS SHOOTER STATE TABLE (DOOM II MAP30)       * * * * * * *
;
;	Once it sees the player: a monster at one of the spawn spots every 240 VBlanks
;	(PC: a spawn cube flies there; here the monster appears at once, teleport sound)
;
mosBOSSSHOOTER_SLEEP:
	dw lo16(_RLMSEnemySleep),lo16(moaBOSSSHOOTER_MOVE),lo16(mosBOSSSHOOTER_MOVE)
mosBOSSSHOOTER_SLEEP0:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSQEnemyTarget)
	dw lo16(_RLMSState),lo16(mosBOSSSHOOTER_SLEEP)
mosBOSSSHOOTER_MOVE:
mosBOSSSHOOTER_ATTACK:
mosBOSSSHOOTER_DAMAGE:
	dw lo16(_RLMSWait)
	dw lo16(_RLMSState),lo16(mosBOSSSHOOTER_MOVE)
moaBOSSSHOOTER_SLEEP:
	db 1
	db (inBossBrain+0)
	db $81
	dw lo16(_RLMATargetPlayer)
	db 127
	db (inBossBrain+0)
	db $80
	dw lo16(moaBOSSSHOOTER_SLEEP)
moaBOSSSHOOTER_MOVE:
moaBOSSSHOOTER_ATTACK:
	db 120
	db (inBossBrain+0)
	db $81
	dw lo16(_RLMAQEnemyAttack),lo16(_RLEABrainSpit)
	db 120
	db (inBossBrain+0)
	db $80
	dw lo16(moaBOSSSHOOTER_MOVE)
moaBOSSSHOOTER_DAMAGE:
moaBOSSSHOOTER_DIE:
	db 127
	db (inBossBrain+0)
	db $80
	dw lo16(moaBOSSSHOOTER_DIE)

;
;	* * * * * * *       BOSS TARGET (DOOM II MAP30 SPAWN SPOT)       * * * * * * *
;
mosBOSSTARGET_SLEEP:
mosBOSSTARGET_SLEEP0:
mosBOSSTARGET_DAMAGE:
	dw lo16(_RLMSHalt)
moaBOSSTARGET_SLEEP:
	db 127
	db (inBossBrain+0)
	db $80
	dw lo16(moaBOSSTARGET_SLEEP)

;
;	* * * * * * *       DOOM II PROJECTILE STATE TABLES       * * * * * * *
;
mosARACHPLASMA_MOVE:
	dw lo16(_RLMSQProjectileMove)
	dw lo16(_RLMSState),lo16(mosARACHPLASMA_MOVE)
moaARACHPLASMA_MOVE:
	db 5	; APLS A
	db (inArachPlasma+0)
	db 5	; APLS B
	db (inArachPlasma+1)
	db $80
	dw lo16(moaARACHPLASMA_MOVE)
mosARACHPLASMA_DIE:
	dw lo16(_RLMSProjectileDamage),lo16(moaARACHPLASMA_DIE)
	dw lo16(_RLMSWait)
moaARACHPLASMA_DIE:
	db 5	; APBX A
	db (inArachPlasma+2)
	db 5	; APBX B
	db (inArachPlasma+3)
	db $81	; APBX C
	dw lo16(_RLMAProjectileDie)
	db 1
	db (inArachPlasma+4)

mosMANCUBUSSHOT_MOVE:
	dw lo16(_RLMSQProjectileMove)
	dw lo16(_RLMSState),lo16(mosMANCUBUSSHOT_MOVE)
moaMANCUBUSSHOT_MOVE:
	db 4	; MANF A
	db (inMancubusShot+0)
	db 4	; MANF B
	db (inMancubusShot+1)
	db $80
	dw lo16(moaMANCUBUSSHOT_MOVE)
mosMANCUBUSSHOT_DIE:
	dw lo16(_RLMSProjectileDamage),lo16(moaMANCUBUSSHOT_DIE)
	dw lo16(_RLMSWait)
moaMANCUBUSSHOT_DIE:
	db 6	; MISL B
	db (inMancubusShot+2)
	db 6	; MISL C
	db (inMancubusShot+3)
	db $81	; MISL D
	dw lo16(_RLMAProjectileDie)
	db 1
	db (inMancubusShot+4)

mosREVENANTSHOT_MOVE:
	dw lo16(_RLMSQProjectileMove)
	dw lo16(_RLMSState),lo16(mosREVENANTSHOT_MOVE)
moaREVENANTSHOT_MOVE:
	db 127	; FATB A
	db (inRevenantShot+0)
	db $80
	dw lo16(moaREVENANTSHOT_MOVE)
mosREVENANTSHOT_DIE:
	dw lo16(_RLMSProjectileDamage),lo16(moaREVENANTSHOT_DIE)
	dw lo16(_RLMSWait)
moaREVENANTSHOT_DIE:
	db 6	; FBXP A
	db (inRevenantShot+1)
	db 6	; FBXP B
	db (inRevenantShot+2)
	db $81	; FBXP C
	dw lo16(_RLMAProjectileDie)
	db 1
	db (inRevenantShot+3)

mosVILEFIRE_DIE:
	dw lo16(_RLMSHalt)
moaVILEFIRE_DIE:
	db 5	; FIRE A
	db (inArchVileFire+0)
	db 5	; FIRE C
	db (inArchVileFire+1)
	db 5	; FIRE E
	db (inArchVileFire+2)
	db 5	; FIRE G
	db (inArchVileFire+3)
	db $81
	dw lo16(_RLMAProjectileDie)
	db 1
	db (inArchVileFire+3)
	endif


;
;	* * * * * * *       FIREBALL 1 STATE TABLE       * * * * * * *
;
mosFIREBALL1_MOVE:
	dw lo16(_RLMSQProjectileMove)
	dw lo16(_RLMSState),lo16(mosFIREBALL1_MOVE)
moaFIREBALL1_MOVE:
	db 8	; A1
	db (inFireBall1+0)
	db 8	; B1
	db (inFireBall1+1)
	db $80
	dw lo16(moaFIREBALL1_MOVE)

mosFIREBALL1_DIE:
	dw lo16(_RLMSProjectileDamage),lo16(moaFIREBALL1_DIE)
	dw lo16(_RLMSWait)
moaFIREBALL1_DIE:
	db 6	; C1
	db (inFireBall1+2)
	db 6	; D1
	db (inFireBall1+3)
	db $81	; E1
	dw lo16(_RLMAProjectileDie)
	db 1
	db (inFireBall1+4)


;
;	* * * * * * *       FIREBALL 2 STATE TABLE       * * * * * * *
;
mosFIREBALL2_MOVE:
	dw lo16(_RLMSQProjectileMove)
	dw lo16(_RLMSState),lo16(mosFIREBALL2_MOVE)
moaFIREBALL2_MOVE:
	db 8	; A1
	db (inFireBall2+0)
	db 8	; B1
	db (inFireBall2+1)
	db $80
	dw lo16(moaFIREBALL2_MOVE)

mosFIREBALL2_DIE:
	dw lo16(_RLMSProjectileDamage),lo16(moaFIREBALL2_DIE)
	dw lo16(_RLMSWait)
moaFIREBALL2_DIE:
	db 6	; C1
	db (inFireBall2+2)
	db 6	; D1
	db (inFireBall2+3)
	db $81	; E1
	dw lo16(_RLMAProjectileDie)
	db 1
	db (inFireBall2+4)


;
;	* * * * * * *       FIREBALL 7 STATE TABLE       * * * * * * *
;
mosFIREBALL7_MOVE:
	dw lo16(_RLMSQProjectileMove)
	dw lo16(_RLMSState),lo16(mosFIREBALL7_MOVE)
moaFIREBALL7_MOVE:
	db 8	; A1A5
	db (inFireBall7+0)
	db 8	; B1B5
	db (inFireBall7+1)
	db $80
	dw lo16(moaFIREBALL7_MOVE)

mosFIREBALL7_DIE:
	dw lo16(_RLMSProjectileDamage),lo16(moaFIREBALL7_DIE)
	dw lo16(_RLMSWait)
moaFIREBALL7_DIE:
	db 6	; C1
	db (inFireBall7+2)
	db 6	; D1
	db (inFireBall7+3)
	db $81	; E1
	dw lo16(_RLMAProjectileDie)
	db 1
	db (inFireBall7+4)


;
;	* * * * * * *       BFG STATE TABLE       * * * * * * *
;
mosBFG_MOVE:
	dw lo16(_RLMSQProjectileMove)
	dw lo16(_RLMSState),lo16(mosBFG_MOVE)
moaBFG_MOVE:
	db 8	; A1A5
	db (inFireBall7+0)
	db 8	; B1B5
	db (inFireBall7+1)
	db $80
	dw lo16(moaBFG_MOVE)

mosBFG_DIE:
	dw lo16(_RLMSProjectileDamage),lo16(moaBFG_DIE)
	dw lo16(_RLMSWait)
moaBFG_DIE:
	db 6	; C1
	db (inFireBall7+2)
	db 6	; D1
	db (inFireBall7+3)
	db $81	; E1
	dw lo16(_RLMABFGDie)
	db 1
	db (inFireBall7+4)


;
;	* * * * * * *       MISSILE STATE TABLE       * * * * * * *
;
mosMISSILE_MOVE:
	dw lo16(_RLMSQProjectileMove)
	dw lo16(_RLMSState),lo16(mosMISSILE_MOVE)
moaMISSILE_MOVE:
	db 127	; A5
	db (inMissile+0)
	db $80
	dw lo16(moaMISSILE_MOVE)

mosMISSILE_DIE:
	dw lo16(_RLMSProjectileDamage),lo16(moaMISSILE_DIE)
	dw lo16(_RLMSWait)
moaMISSILE_DIE:
	db 6	; B0
	db (inMissile+1)
	db 6	; C0
	db (inMissile+2)
	db $81	; D0
	dw lo16(_RLMAMissileDie)
	db 1
	db (inMissile+3)


;
;	* * * * * * *       PLASMA STATE TABLE       * * * * * * *
;
mosPLASMA_MOVE:
	dw lo16(_RLMSQProjectileMove)
	dw lo16(_RLMSState),lo16(mosPLASMA_MOVE)
moaPLASMA_MOVE:
	db 127	; A0
	db (inPlasma+0)
	db $80
	dw lo16(moaPLASMA_MOVE)

mosPLASMA_DIE:
	dw lo16(_RLMSProjectileDamage),lo16(moaPLASMA_DIE)
	dw lo16(_RLMSWait)
moaPLASMA_DIE:
	db 6	; B0
	db (inPlasma+1)
	db 6	; C0
	db (inPlasma+2)
	db 6	; D0
	db (inPlasma+3)
	db 6	; E0
	db (inPlasma+4)
	db $81	; E0
	dw lo16(_RLMAProjectileDie)
	db 1
	db (inPlasma+4)


;
;	* * * * * * *       BARREL EXPLOSION STATE TABLE       * * * * * * *
;
mosBARRELEXP_DIE:
	dw lo16(_RLMSHalt)
moaBARRELEXP_DIE:
	db 8	; C0
	db (inBarrelExp+0)
	db 8	; D0
	db (inBarrelExp+1)
	db 8	; E0
	db (inBarrelExp+2)
	db $81	; E0
	dw lo16(_RLMABarrelDie)
	db 1
	db (inBarrelExp+2)
