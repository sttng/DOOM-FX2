	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                   ENGINE CODE SECTION HEADER MODULE                *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"


;
;	* * * * * * *       ENGINE GSU CODE       * * * * * * *
;
	%section(ENGINE_GSUCODE)
_RLGSUCode:
	%CACHER()


;
;	* * * * * * *       ENGINE 65816 CODE       * * * * * * *
;
	%section(ENGINE)
_RLCode:


;
;	* * * * * * *       ENGINE 65816 RAMCODE       * * * * * * *
;
	%section(ENGINE_RAMCODE)
_RLRAMCodeROM:
	base _RLRAMCode
