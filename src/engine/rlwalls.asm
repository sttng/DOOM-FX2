	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                        WALLS DATA TABLES MODULE                    *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"

	%section(WALLS)

;
;	* * * * * * *       WALLS TABLE       * * * * * * *
;
;	Table of Offsets within WallsData Structures
;
;	DC.W	Wall0DataOffset
;	DC.W	Wall1DataOffset
;	DC.W	WallnDataOffset
;
RLWallsTable:
	incbin "data/RLDATA/WALLS/WALLS.TBL"


;
;	* * * * * * *       WALLS DATA TABLE       * * * * * * *
;
;	DC.B	Height
;	DC.B	Modulo (Width-1)
;
;	DC.W	Address		\ * Width Strips
;	DC.B	Bank		/
;
;	(this port) Wall format 2: a third header byte, the column step (+$80
;	half height; levels.inc).  Wall format 3: a 9-byte header, no strip
;	pointers (rltracew5.asm).
;
RLWallsData:
	incbin "data/RLDATA/WALLS/WALLS.DAT"
