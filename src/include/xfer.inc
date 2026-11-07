includeonce
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                                 TRANSFER STRUCTURE DEFINITIONS     *
;*                                                                    *
;**********************************************************************



;
;	* * * * * * *       GENERAL FLAGS AND EQUATES       * * * * * * *
;
	xferNastyMax = (5*1024)	; 5K Maximum per NastyTransfer

;
;	* * * * * * *       TRANSFER STRUCTURE       * * * * * * *
;
	!xfs #= 0
	xfsType = !xfs	; Type of Transfer
	!xfs #= !xfs+2
	xfsSource = !xfs	; Source Address
	!xfs #= !xfs+4
	xfsDest = !xfs	; Destination Address
	!xfs #= !xfs+4
	xfsLen = !xfs	; Length (used for fill)
	xfsData0 = !xfs	; Data0  (AND Mask)
	!xfs #= !xfs+2
	xfsData1 = !xfs	; Data1  (ORA Mask)
	!xfs #= !xfs+2
	xfsData2 = !xfs	; Data2  (Pointer to ADD Value)
	!xfs #= !xfs+2
	xfsSize = !xfs
;
;	>>>   TRANSFER STRUCTURE TYPES   <<<
;
	xftEND = $8000	; End
	xftRAW = $4000	; Data is NOT Compressed
	xftNODATA = $2000	; NO DATA associated with this XFER
	xftCODE = (0*2)	; Code Execution
	xftRAM = (1*2)	; XFer Source->Dest RAM
	xftVRAM8L = (2*2)	; XFer Source->Dest VRAM 8L
	xftVRAM8H = (3*2)	; XFer Source->Dest VRAM 8H
	xftVRAM16 = (4*2)	; XFer Source->Dest VRAM 16
	xftCGRAM = (5*2)	; XFer Source->Dest CGRAM
	xftVRAMF8L = (6*2)	; Fill Source->Dest VRAM 8L
	xftVRAMF8H = (7*2)	; Fill Source->Dest VRAM 8H
	xftVRAMF16 = (8*2)	; Fill Source->Dest VRAM 16
	xftVRAMM8L = (9*2)	; Mask Source->Dest VRAM 8L
	xftVRAMM8H = (10*2)	; Mask Source->Dest VRAM 8H
	xftVRAMM16 = (11*2)	; Mask Source->Dest VRAM 16
	xftVRAMD16 = (12*2)	; XFer Source->Dest VRAM 16 (Add Base to Dest)
	xftVRAM8HC = (13*2)	; XFer Source->Dest VRAM 8H (Continuation)
