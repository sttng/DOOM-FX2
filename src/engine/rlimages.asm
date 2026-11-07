	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                       IMAGES DATA TABLES MODULE                    *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/rlimages.inc"

	%section(IMAGES)

;
;	* * * * * * *       IMAGES TABLE       * * * * * * *
;
;	Table of Offsets within ImagesData Structures
;
;	DC.W	Image0DataOffset
;	DC.W	Image1DataOffset
;	DC.W	ImagenDataOffset
;
RLImagesTable:
	incbin "data/RLDATA/IMAGES/IMAGES.TBL"
	if !RLDOOM2MONSTERS != 0
	assert filesize("data/RLDATA/IMAGES/IMAGES.TBL") == 2*(256+inMax1), "IMAGES.TBL lacks the DOOM II image page: wad2gfx.py convert --doom2-monsters"
	else
	assert filesize("data/RLDATA/IMAGES/IMAGES.TBL") == 2*inMax, "IMAGES.TBL: not the 232 images of the tags (DOOM II images without RLDOOM2MONSTERS = 1, or a data set made before the barrel-explosion fix: make data)"
	endif


;
;	* * * * * * *       IMAGES DATA TABLE       * * * * * * *
;
;	DC.B	Height
;	DC.B	Width
;
;	DC.W	Address		\ * Width Strips (24-bit pointer)
;	DC.B	Bank		/
;
;	(No Flags word: rle.inc rliFlags is commented out, rliHeight = 0.)
;
RLImagesData:
	incbin "data/RLDATA/IMAGES/IMAGES.DAT"

;
;	* * * * * * *       MASKED MIDDLE TEXTURES TABLE (this port)       * * * * * * *
;
;	DC.W	Offset within ImagesData of masked texture 0..n (face byte 4)
;
	if !RLMASKED
RLMaskedTable:
	incbin "data/RLDATA/IMAGES/MASKED.TBL"
	endif
