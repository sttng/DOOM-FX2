	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                                  RAM2 MEMORY       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"

	; extern RAM2Start,RAM2End

	%section(RAM2)


;
;	* * * * * * *       RAM2 VARIABLES       * * * * * * *
;
RAM2Start:

;
;	* * * * * * *       START OF WRAM CODE       * * * * * * *
;
_RLRAMCode:


;
;	* * * * * * *       END OF RAM2 VARIABLES       * * * * * * *
;
RAM2End:
