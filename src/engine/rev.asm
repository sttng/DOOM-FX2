	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                        VERSION/REVISION MODULE                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rl.inc"

	%section(REV)

	VerTxt = $47FFC6
	assert (VerTxt&$FFFFFF) == ((pc()+1)&$FFFFFF), "cached constant VerTxt is stale (tools/fixup.py)"
	%VERSTAG()	; Insert Version Tag Text
VerTxtE:
	VerTxtL = $19
	assert (VerTxtL&$FFFFFF) == ((VerTxtE-VerTxt-1)&$FFFFFF), "cached constant VerTxtL is stale (tools/fixup.py)"

	if useSYSINFO != 0

TtlTxt:
;	dc.b	'$TTL: ""'
	db $24,$54,$54,$4C,$3A,$20,$22,$52,$41,$47,$45,$2F,$52,$45,$41,$4C,$49,$54,$59,$45,$4E,$47,$49,$4E,$45,$22
	TtlTxtL = pc()-TtlTxt

CPUTxt:
	db "$CPU: SNES RF5A22 (65816)"
	CPUTxtL = pc()-CPUTxt

CPUTxt2:
	db "      SFX GSU2 (SUPER FX2)"
	CPUTxt2L = pc()-CPUTxt2

CFGTxt:
	db "$CFG: SHVC-4RB3B7S/SHVC-1C0N6S"
	CFGTxtL = pc()-CFGTxt
CFHTxt:
	db "      (16MBit/GSU2/512KBitXRAM)"
	CFHTxtL = pc()-CFHTxt

PRGTxt:
	db "$PRG: PrgROM $200000"
	PRGTxtL = pc()-PRGTxt

RAMTxt:
	db "$RAM: GSURAM $10000"
	RAMTxtL = pc()-RAMTxt

	DATTxt0 = snestopc(realbase())
DATTxt:
	incbin "data/SRC/SysDate"
	DATTxtL = snestopc(realbase())-DATTxt0-1

	endif
