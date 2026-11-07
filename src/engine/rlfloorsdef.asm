	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                  FLOORS/CEILINGS TEXTURE DATA MODULE               *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"

	if useFLOORS != 0
	; public RLFloorsDef

	%section(FLOORSDEF)

;
;	* * * * * * *       FLOORS/CEILINGS PIXEL DEFINITIONS       * * * * * * *
;
;	PixelData for Floor/Ceiling Textures
;
RLFloorsDef:
	incbin "data/RLDATA/FLOORS/FLOORS.DEF"
	endif
