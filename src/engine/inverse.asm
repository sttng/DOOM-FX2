	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                         INVERSE TABLE MODULE                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"

	; public InvTable


	%section(INVERSE)

;
;	* * * * * * *       INVERSE TABLE       * * * * * * *
;
;	Format:	1/n	->	  1 <= n <= 128		         .0FFFFFFFFFFFFFFF
;				128 <= n <= 16384	.00000000 0FFFFFFFFFFFFFFF
;
	incbin "data/SRC/InverseTable.bin":0..2
InvTable:
	incbin "data/SRC/InverseTable.bin":2..2+32768-2
