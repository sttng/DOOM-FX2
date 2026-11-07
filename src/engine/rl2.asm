	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                   ENGINE CODE SECTION FOOTER MODULE                *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"

;
;	* * * * * * *       REALITY_ENGINE GSUCODE END       * * * * * * *
;
	%section(ENGINE_GSUCODE)
_RLGSUCodeEnd:


;
;	* * * * * * *       ENGINE 65816 CODE END       * * * * * * *
;
	%section(ENGINE)
_RLCodeEnd:


;
;	* * * * * * *       REALITY_ENGINE RAMCODE END       * * * * * * *
;
	%section(ENGINE_RAMCODE)
_RLRAMCodeEnd:

	; ltext "RAM7DEnd $%08lx ($%04lx Free), RAM7DEnd2 $%08lx ($%04lx Free)",RAM7DEnd,($710000-RAM7DEnd),RAM7DEnd2,($710000-RAM7DEnd2)
	; ltext "RLG=$%08lx, RLE=$%08lx, RLR=$%08lx",(_RLGSUCodeEnd-_RLGSUCode),(_RLRAMCodeEnd-_RLRAMCode),(_RLCodeEnd-_RLCode)
