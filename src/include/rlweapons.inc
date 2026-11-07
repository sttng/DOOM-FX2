includeonce
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                   WEAPONS STRUCTURE DEFINITIONS    *
;*                                                                    *
;**********************************************************************


;
;	* * * * * * *       DEFINITIONS       * * * * * * *
;
	WeaponSwayVBlanks = 64	; WeaponSway Cycle #VBlanks (Power of 2!)


;
;	* * * * * * *       WEAPONS TYPE TAGS       * * * * * * *
;
	wtFist = 0	; Fist
	wtPistol = 2	; Pistol
	wtShotGun = 4	; ShotGun
	wtChainSaw = 6	; ChainSaw
	wtChainGun = 8	; ChainGun
	wtRocket = 10	; Rocket Launcher
	wtPlasma = 12	; Plasma Rifle
	wtBFG = 14	; BFG9000
	wtSuperShotGun = 16	; (DOOM II) Super Shotgun: owned with PlayerKeys bit 7 (pkSuperShotGun)
	pkSuperShotGun = $80	; (keys are bits 0-5; the 8 weapon bits are all used)
;
;	* * * * * * *       WEAPONS TYPE BITS       * * * * * * *
;
	wtbFist = $01	; Fist
	wtbPistol = $02	; Pistol
	wtbShotGun = $04	; ShotGun
	wtbChainSaw = $08	; ChainSaw
	wtbChainGun = $10	; ChainGun
	wtbRocket = $20	; Rocket Launcher
	wtbPlasma = $40	; Plasma Rifle
	wtbBFG = $80	; BFG9000


;
;	* * * * * * *       WEAPONS DATA STRUCTURE       * * * * * * *
;
	!wd #= 0
	wdRaise = !wd	; Raise Weapon Address
	!wd #= !wd+2
	wdLower = !wd	; Lower Weapon Address
	!wd #= !wd+2
	wdReady = !wd	; Ready Weapon Address
	!wd #= !wd+2
	wdUse = !wd	; Use Weapon Address
	!wd #= !wd+2
	wdAmmo = !wd	; Ammunition Address
	!wd #= !wd+2
	wdSize = !wd


;
;	* * * * * * *       WEAPONS STATE STRUCTURE       * * * * * * *
;
	!ws #= 0
	wsCode = !ws	; CodeAddress in this State
	!ws #= !ws+2
	wsCount = !ws	; #Cycles in this State
	!ws #= !ws+1
	wsFrame = !ws	; Frame#
	!ws #= !ws+1
	wsNextState = !ws	; Address of Next State
	!ws #= !ws+2
	wsSize = !ws


;
;	* * * * * * *       WEAPON FRAME NUMBERS       * * * * * * *
;
;	>>>   FIST   <<<
;
	wfPUNGA0 = 0
	wfPUNFA0 = 4
	wfPUNFB0 = 8
	wfPUNFC0 = 12

;
;	>>>   PISTOL   <<<
;
	wfPISGA0 = 0
	wfPISFA0 = 4
	wfPISFB0 = 8

;
;	>>>   SHOTGUN   <<<
;
	wfSHTGA0 = 0
	wfSHTFA0 = 4
	wfSHTFB0 = 8
	wfSHTFC0 = 12
	wfSHTFD0 = 16
	wfSHTFE0 = 20

;
;	>>>   CHAINSAW   <<<
;
	wfSAWGA0 = 0
	wfSAWGB0 = 4
	wfSAWFA0 = 8
	wfSAWFB0 = 12

;
;	>>>   CHAINGUN   <<<
;
	wfCHGGA0 = 0
	wfCHGFA0 = 4
	wfCHGFB0 = 8

;
;	>>>   ROCKET LAUNCHER   <<<
;
	wfMISGA0 = 0
	wfMISFA0 = 4
	wfMISFB0 = 8
	wfMISFC0 = 12
	wfMISFD0 = 16
	wfMISFE0 = 20

;
;	>>>   PLASMA RIFLE   <<<
;
	wfPLSGA0 = 0
	wfPLSFA0 = 4
	wfPLSFB0 = 8
	wfPLSFC0 = 12

;
;	>>>   BFG9000   <<<
;
	wfBFGGA0 = 0
	wfBFGFA0 = 4
	wfBFGFB0 = 8

;
;	>>>   SUPER SHOTGUN (DOOM II)   <<<
;
	wfSHT2A0 = 0	; ready
	wfSHT2FA0 = 4	; ready + flash
	wfSHT2B0 = 8	; fired
	wfSHT2D0 = 12	; open
	wfSHT2F0 = 16	; shells in
	wfSHT2H0 = 20	; closing
