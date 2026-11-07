includeonce
;**********************************************************************
;*                                                                    *
;*                 RUMBLE (this port, rumble.asm)                     *
;*                                                                    *
;**********************************************************************
;
;	LRG rumble controller in port 1 (github.com/LimitedRunGames-Tech/
;	snes-rumble, its docs/RumbleTech.pdf): after the joypad read, 16 bits on
;	the port's IO bit (WRIO bit 6), each clocked by a read of $4016:
;	%01110010, then the right (low frequency) and left (high frequency)
;	motor strengths, 4 bits each.  The effects and their strengths are
;	those of the FX3 cartridge (DOOM SNES 2025).
;
	MaxRumbles = 4	; effects playing at once
	MaxRLRumbles = 4	; requests from the GSU per frame
;
;	>>>   REQUEST = EFFECT# | COMMAND   <<<
;
	recAddLoop = $40	; start a looping effect (unless it plays)
	recRemLoop = $80	; stop a looping effect
	reMask = $3F	; effect# bits
;
	reDamage1 = 1	; player damage <= 10
	reDamage2 = 2	; <= 20
	reDamage3 = 3	; more
	reFireFist = 4	; fire: reFireFist + WeaponType/2
	reFirePistol = 5
	reFireShotGun = 6
	reFireChainSaw = 7
	reFireChainGun = 8
	reFireRocket = 9
	reFirePlasma = 10
	reFireBFG = 11
	reFireSuperShotGun = 12	; (DOOM II; the shotgun's waves)
	reIdleChainSaw = 13	; loops while the chainsaw is ready
	reNum = 14
