	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                       TEXTURE DATA TABLES MODULE                   *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"


	%section(TEXTURES)

	if useTEXTURES != 0
;
;	* * * * * * *       TEXTURES TABLE       * * * * * * *
;
;	Table of Offsets within TextureData Structures
;
;	DC.W	Texture0DataOffset
;	DC.W	Texture1DataOffset
;	DC.W	TexturenDataOffset
;
RLTextureTable:
	incbin "data/RLDATA/WALLS/TEXTURE.TBL"


;
;	* * * * * * *       TEXTURE DATA TABLE       * * * * * * *
;
;	DC.W	TextureWidth
;	DC.W	TextureHeight
;	DC.B	NumberOfPatches
;
;	DC.W	PatchXOffset
;	DC.W	PatchYOffset
;	DC.W	WallNumber
;
RLTextureData:
	incbin "data/RLDATA/WALLS/TEXTURE.DAT"
	endif

;
;	* * * * * * *       TEXTURE -> ALTERNATE TEXTURE TRANSLATION       * * * * * * *
;
RLTextureXLatTable:
	incbin "data/RLDATA/WALLS/TEXTURE2.TBL"
RLTextureXLatTableE:
