	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                       CUTTER DATA BLOCK MODULE                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"

	; public _ImageTblFist
	; public _CharDataFist
	; public _MiscDataFist

	; public _ImageTblPistol
	; public _CharDataPistol
	; public _MiscDataPistol

	; public _ImageTblShotGun
	; public _CharDataShotGun
	; public _MiscDataShotGun

	; public _ImageTblChainSaw
	; public _CharDataChainSaw
	; public _MiscDataChainSaw

	; public _ImageTblChainGun
	; public _CharDataChainGun
	; public _MiscDataChainGun

	; public _ImageTblRocket
	; public _CharDataRocket
	; public _MiscDataRocket

	; public _ImageTblPlasma
	; public _CharDataPlasma
	; public _MiscDataPlasma

	; public _ImageTblBFG
	; public _CharDataBFG
	; public _MiscDataBFG


;
;	* * * * * * *       CUTTER IMAGE/MISC/CHARDATA TABLES       * * * * * * *
;

	%section(_CUTDATAFIST)
_ImageTblFist:
	incbin "data/RLDATA/CUT/Fist/.imagetbl"
_ImageTblFistE:

_MiscDataFist:
	incbin "data/RLDATA/CUT/Fist/.miscdata"
_MiscDataFistE:

_CharDataFist:
	incbin "data/RLDATA/CUT/Fist/.chardata"
_CharDataFistE:


	%section(_CUTDATAPISTOL)
_ImageTblPistol:
	incbin "data/RLDATA/CUT/Pistol/.imagetbl"
_ImageTblPistolE:

_MiscDataPistol:
	incbin "data/RLDATA/CUT/Pistol/.miscdata"
_MiscDataPistolE:

_CharDataPistol:
	incbin "data/RLDATA/CUT/Pistol/.chardata"
_CharDataPistolE:


	%section(_CUTDATASHOTGUN)
_ImageTblShotGun:
	incbin "data/RLDATA/CUT/ShotGun/.imagetbl"
_ImageTblShotGunE:

_MiscDataShotGun:
	incbin "data/RLDATA/CUT/ShotGun/.miscdata"
_MiscDataShotGunE:

_CharDataShotGun:
	incbin "data/RLDATA/CUT/ShotGun/.chardata"
_CharDataShotGunE:


	%section(_CUTDATACHAINSAW)
_ImageTblChainSaw:
	incbin "data/RLDATA/CUT/ChainSaw/.imagetbl"
_ImageTblChainSawE:

_MiscDataChainSaw:
	incbin "data/RLDATA/CUT/ChainSaw/.miscdata"
_MiscDataChainSawE:

_CharDataChainSaw:
	incbin "data/RLDATA/CUT/ChainSaw/.chardata"
_CharDataChainSawE:


	%section(_CUTDATACHAINGUN)
_ImageTblChainGun:
	incbin "data/RLDATA/CUT/ChainGun/.imagetbl"
_ImageTblChainGunE:

_MiscDataChainGun:
	incbin "data/RLDATA/CUT/ChainGun/.miscdata"
_MiscDataChainGunE:

_CharDataChainGun:
	incbin "data/RLDATA/CUT/ChainGun/.chardata"
_CharDataChainGunE:


	%section(_CUTDATAROCKET)
_ImageTblRocket:
	incbin "data/RLDATA/CUT/Rocket/.imagetbl"
_ImageTblRocketE:

_MiscDataRocket:
	incbin "data/RLDATA/CUT/Rocket/.miscdata"
_MiscDataRocketE:

_CharDataRocket:
	incbin "data/RLDATA/CUT/Rocket/.chardata"
_CharDataRocketE:


	%section(_CUTDATAPLASMA)
_ImageTblPlasma:
	if not(defined("RLNOPLASMABFG"))	; (levels.inc: no plasma rifle/BFG, the shareware set)
	incbin "data/RLDATA/CUT/Plasma/.imagetbl"
	endif
_ImageTblPlasmaE:

_MiscDataPlasma:
	if not(defined("RLNOPLASMABFG"))	; (levels.inc: no plasma rifle/BFG, the shareware set)
	incbin "data/RLDATA/CUT/Plasma/.miscdata"
	endif
_MiscDataPlasmaE:

_CharDataPlasma:
	if not(defined("RLNOPLASMABFG"))	; (levels.inc: no plasma rifle/BFG, the shareware set)
	incbin "data/RLDATA/CUT/Plasma/.chardata"
	endif
_CharDataPlasmaE:


	%section(_CUTDATABFG)
_ImageTblBFG:
	if not(defined("RLNOPLASMABFG"))	; (levels.inc: no plasma rifle/BFG, the shareware set)
	incbin "data/RLDATA/CUT/BFG/.imagetbl"
	endif
_ImageTblBFGE:

_MiscDataBFG:
	if not(defined("RLNOPLASMABFG"))	; (levels.inc: no plasma rifle/BFG, the shareware set)
	incbin "data/RLDATA/CUT/BFG/.miscdata"
	endif
_MiscDataBFGE:

_CharDataBFG:
	if not(defined("RLNOPLASMABFG"))	; (levels.inc: no plasma rifle/BFG, the shareware set)
	incbin "data/RLDATA/CUT/BFG/.chardata"
	endif
_CharDataBFGE:


	%section(_CUTDATASUPERSHOTGUN)
	if !RLDOOM2MONSTERS != 0	; (DOOM II: tools/wad2cut.py)
_ImageTblSuperShotGun:
	incbin "data/RLDATA/CUT/SuperShotGun/.imagetbl"
_ImageTblSuperShotGunE:

_MiscDataSuperShotGun:
	incbin "data/RLDATA/CUT/SuperShotGun/.miscdata"
_MiscDataSuperShotGunE:

_CharDataSuperShotGun:
	incbin "data/RLDATA/CUT/SuperShotGun/.chardata"
_CharDataSuperShotGunE:
	endif
