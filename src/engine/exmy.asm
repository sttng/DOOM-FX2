	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                          LEVEL DATA MODULE                         *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/exmy.inc"

;
;	* * * * * * *       ALL LEVELS OF THE DATA SET       * * * * * * *
;
	!__e #= 0
	while !__e < !NUMLEVELS
	%EXMYMAC(!{lvl!__e})
	!__e #= !__e+1
	endwhile
