	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       COLOUR REMAPPING MODULE                      *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"


	; public RLColourMaps


;
;	* * * * * * *       COLOUR MAPS       * * * * * * *
;
	%section(COLOUR_MAPS)
RLColourMaps:
	assert (hi16(RLColourMaps)&$FF) >= $80, "colourmap page bit 7 marks normal (set) / shadow (clear) objects (tools/sections.json min_in_bank)"
	assert (hi16(RLColourMaps)&$FF)+32 <= $FF, "colourmaps must not cross the bank"
	incbin "data/RLDATA/COLOUR/COLOURMAPS":0..(33*256)
	incbin "data/RLDATA/COLOUR/COLOURMAPS":(32*256)..(32*256)+256
