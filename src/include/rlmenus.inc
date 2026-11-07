includeonce
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                     MENUS STRUCTURE DEFINITIONS    *
;*                                                                    *
;**********************************************************************


;
;	* * * * * * *       MENU DATA STRUCTURE       * * * * * * *
;
	!rlmd #= 0
	rlmdMenuMap = !rlmd	; Menu VRAM Map
	!rlmd #= !rlmd+3
	rlmdMenuDef = !rlmd	; Menu VRAM Def
	!rlmd #= !rlmd+3
	rlmdMenuHDMATM = !rlmd	; Menu HDMATM Table
	!rlmd #= !rlmd+3
	rlmdInitCode = !rlmd	; InitCode-1
	!rlmd #= !rlmd+2
	rlmdBackCode = !rlmd	; BackCode-1
	!rlmd #= !rlmd+2
	rlmdItems = !rlmd	; Number of Menu Items
	!rlmd #= !rlmd+1
	rlmdItemData = !rlmd	; ItemData
;rlmdSize		equ	rlmd
;
;	>>>   MENU ITEM DATA SUBSTRUCTURE   <<<
;
	!rlmid #= 0
	rlmidCode = !rlmid	; ItemCode-1
	!rlmid #= !rlmid+2
	rlmid0 = !rlmid
	rlmidSize = rlmid0+6
;
;	>>>   MENU ITEM "NORMAL" SUBSTRUCTURE   <<<
;
	!rlmid #= rlmid0
;
;	>>>   MENU ITEM "TOGGLE" SUBSTRUCTURE   <<<
;
	!rlmid #= rlmid0
	rlmidtVar = !rlmid	; Address of Toggle Variable
	!rlmid #= !rlmid+2
;
;	>>>   MENU KEY DATA SUBSTRUCTURE   <<<
;
	!rlmkd #= 0
	rlmkdKeys = !rlmkd	; KeyBits (Terminated with $0000)
	!rlmkd #= !rlmkd+2
	rlmkdCode = !rlmkd	; KeyCode-1
	!rlmkd #= !rlmkd+2
