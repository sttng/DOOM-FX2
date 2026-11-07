includeonce
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                    CUTTER DEFINITIONS AND EQUATES                  *
;*                                                                    *
;**********************************************************************


;
;	* * * * * * *       DEFINITIONS       * * * * * * *
;
	MaxCutImages = 6	; Maximum RESIDENT CUTTER Images
	MaxCutCharData = 128	; Maximum #BYTES for _CharData
	MaxCutMiscData = 704	; Maximum #BYTES for _MiscData
	MaxCutCharDef = 7168	; Maximum #BYTES for _CharDef


;
;	* * * * * * *       IMAGE TABLE       * * * * * * *
;
;	n *	/	DC.W	CHARDATA INDEX
;		\	DC.W	MISCDATA INDEX
;
	!its #= 0
	itsCharData = !its	; Character Data Index
	!its #= !its+2
	itsMiscData = !its	; Miscellaneous Data Index
	!its #= !its+2
	itsSize = !its


;
;	* * * * * * *       MISCELLANEOUS IMAGE DATA TABLES       * * * * * * *
;
;			DC.B	#OAMs_Required
;
;	DataListTable:
;			DC.B	%vh00ccc1
;				v	(Vertical Flipping)
;				h	(Horizontal Flipping)
;				ccc	(Colour Palette)
;			DC.B	OAM_X_Pixel_Offset
;			DC.B	OAM_Y_Pixel_Offset
;
	!imd #= 0
	imdOAMNum = !imd	; Number of OAMs Required Total
	!imd #= !imd+1
	imdDataList = !imd	; DataList Table Starting
;
	!imdl #= 0
	imdlFlags = !imdl	; Flags
	!imdl #= !imdl+1
	imdlOAMXOfs = !imdl	; OAM X_Offset
	!imdl #= !imdl+1
	imdlOAMYOfs = !imdl	; OAM Y_Offset
	!imdl #= !imdl+1
	imdlSize = !imdl
;
;	Image_MiscData_Flags:
;
;			DC.B	%vhppccc1
;				v	(Vertical Flipping)
;				h	(Horizontal Flipping)
;				p	(Priority)
;				ccc	(Colour Palette)
;
	imdfVFlip = $80	; Vertical Flipping
	imdfHFlip = $40	; Horizontal Flipping
	imdfPri = $30	; Priority
	imdfColour = $0E	; Colour Palette
