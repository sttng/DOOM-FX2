includeonce
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                STATUS BAR STRUCTURE DEFINITIONS    *
;*                                                                    *
;**********************************************************************


;
;	* * * * * * *       STATUS BAR DEFINITIONS       * * * * * * *
;
;	>>>   FACE DEFINITIONS   <<<
;
	StatFacesX = 8	; #Faces per Line in Imagery
	StatFacePixX = 24	; X Pixels Wide
	StatFacePixY = 32	; Y Pixels Tall
	StatFaceCharX = StatFacePixX/8	; X Characters Wide
	StatFaceCharY = StatFacePixY/8	; Y Characters Tall
	StatFacePosX = RLStatStartPixX+103	; X Coordinate of Face
	StatFacePosY = RLStatStartPixY+0	; Y Coordinate of Face
;
;	>>>   STATNUM DEFINITIONS   <<<
;
	StatNumsX = 10	; #Digits per Line in Imagery
	StatNumPixX = 16	; X Pixels Wide
	StatNumPixY = 16	; Y Pixels Tall
	StatNumCharX = StatNumPixX/8	; X Characters Wide
	StatNumCharY = StatNumPixY/8	; Y Characters Tall
;
;	>>>   AMMO STATNUM DEFINITIONS   <<<
;
	StatAmmoPosX = RLStatStartPixX+2	; X Coordinate of Ammo
	StatAmmoPosY = RLStatStartPixY+3	; Y Offset of Ammo
;
;	>>>   HEALTH STATNUM DEFINITIONS   <<<
;
	StatHealthPosX = RLStatStartPixX+52	; X Coordinate of Health
	StatHealthPosY = RLStatStartPixY+3	; Y Offset of Health
;
;	>>>   ARMOR STATNUM DEFINITIONS   <<<
;
	StatArmorPosX = RLStatStartPixX+168	; X Coordinate of Armor
	StatArmorPosY = RLStatStartPixY+3	; Y Offset of Armor
;
;	>>>   KEYS DEFINITIONS   <<<
;
	StatKeyRPosX = RLStatStartPixX+133	; X Coordinate of Red Key
	StatKeyRPosY = RLStatStartPixY+2	; Y Coordinate of Red Key
	StatKeyYPosX = RLStatStartPixX+145	; X Coordinate of Yellow Key
	StatKeyYPosY = RLStatStartPixY+2	; Y Coordinate of Yellow Key
	StatKeyBPosX = RLStatStartPixX+156	; X Coordinate of Blue Key
	StatKeyBPosY = RLStatStartPixY+2	; Y Coordinate of Blue Key
;
;	>>>   ARMS DEFINITIONS   <<<
;
	StatArmsPosX = RLStatStartPixX+133	; X Coordinate of Arms
	StatArmsPosY = RLStatStartPixY+14	; Y Coordinate of Arms
