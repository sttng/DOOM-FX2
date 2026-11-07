	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                      CUTTER CHARDEF BLOCKS MODULE                  *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"

	; public _CharDefFist
	; public _CharDefPistol
	; public _CharDefShotGun
	; public _CharDefChainSaw
	; public _CharDefChainGun
	; public _CharDefRocket
	; public _CharDefPlasma
	; public _CharDefBFG


;
;	* * * * * * *       CUTTER IMAGERY PIXEL DEFINITIONS       * * * * * * *
;
;	Blocks of 8x8 Character Data (32 Bytes per character)
;

	%section(_CHARDEFFIST)
_CharDefFist:
	incbin "data/RLDATA/CUT/Fist/.chardef"
_CharDefFistE:


	%section(_CHARDEFPISTOL)
_CharDefPistol:
	incbin "data/RLDATA/CUT/Pistol/.chardef"
_CharDefPistolE:


	%section(_CHARDEFSHOTGUN)
_CharDefShotGun:
	incbin "data/RLDATA/CUT/ShotGun/.chardef"
_CharDefShotGunE:


	%section(_CHARDEFCHAINSAW)
_CharDefChainSaw:
	incbin "data/RLDATA/CUT/ChainSaw/.chardef"
_CharDefChainSawE:


	%section(_CHARDEFCHAINGUN)
_CharDefChainGun:
	incbin "data/RLDATA/CUT/ChainGun/.chardef"
_CharDefChainGunE:


	%section(_CHARDEFROCKET)
_CharDefRocket:
	incbin "data/RLDATA/CUT/Rocket/.chardef"
_CharDefRocketE:


	%section(_CHARDEFPLASMA)
_CharDefPlasma:
	if not(defined("RLNOPLASMABFG"))	; (levels.inc: no plasma rifle/BFG, the shareware set)
	incbin "data/RLDATA/CUT/Plasma/.chardef"
	endif
_CharDefPlasmaE:


	%section(_CHARDEFBFG)
_CharDefBFG:
	if not(defined("RLNOPLASMABFG"))	; (levels.inc: no plasma rifle/BFG, the shareware set)
	incbin "data/RLDATA/CUT/BFG/.chardef"
	endif
_CharDefBFGE:


	%section(_CHARDEFSUPERSHOTGUN)
	if !RLDOOM2MONSTERS != 0	; (DOOM II: tools/wad2cut.py)
_CharDefSuperShotGun:
	incbin "data/RLDATA/CUT/SuperShotGun/.chardef"
_CharDefSuperShotGunE:
	endif
