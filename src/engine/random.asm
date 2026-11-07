	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                      RANDOM NUMBER TABLE MODULE                    *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"

	; public RandomTable


	%section(RANDOM)
;	SECTION	RANDOM,LOAD=$801F0000,ORG=$005F0000,SIZE=$100

;
;	* * * * * * *       RANDOM TABLE       * * * * * * *
;
RandomTable:
	incbin "data/SRC/RandomTable.bin":0..256
