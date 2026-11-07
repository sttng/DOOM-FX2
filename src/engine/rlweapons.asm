	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       WEAPONS HANDLING MODULE                      *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/snesmac.inc"
	incsrc "src/include/rlweapons.inc"
	incsrc "src/include/rlcut.inc"

	; public _RLInitWeapons
	; public _RLUpdateWeapon


	%section(LEVEL)
;
;	* * * * * * *       REALITY_ENGINE INITIALIZE WEAPONS       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitWeapons:
	sep #$20		; mode 'a!'
	lda.b #0	; LIGHT CREATED BY WEAPON
	sta.l WeaponLight
	rep #$30		; mode 'AX!'
	lda.w _PlayerWeapon	; #wtPistol	; PISTOL
	sta.l WeaponNext
	lda.w #-1	; FORCE UPDATE OF WEAPON TYPE/FRAME
	sta.b WeaponTypeOld
	sta.b WeaponNextOld
	sta.b WeaponXOld
	sta.b WeaponYOld
	sta.w WeaponTypeBuilt	; NO WEAPON BUILT YET!
	stz.b WeaponOAMBytesOld	; #OAM Bytes Sent Last
	lda.w #$7FFF	; LOCKED AT CURRENT (INVALID) STATE
	sta.l WeaponStateCount
	stz.b WeaponIRQBuildPhase	; DON'T BUILD NEW WEAPON!
;
	lda.w #0	; Build _WeaponOAMData OffsetTable
	tax
	ldy.w #MaxCutImages-1
_RIWS200:
	sta.l _WeaponOAMTable,x	; Save Index into _WeaponOAMData
	clc
	adc.w #(RLMaxCutSprOAMs*6)	; Move to next _WeaponOAMData
	inx
	inx
	inx
	inx
	dey	; Next Frame
	bpl _RIWS200
;
	lda.w #lo16(_WeaponDEFGDMAData)	; Build _WeaponDEFGDMAData AddressTable
	ldx.w #0
	ldy.w #MaxCutImages-1
_RIWS400:
	sta.l _WeaponDEFGDMATable,x	; Save Index into _WeaponDEFGDMAData
	clc
	adc.w #((RLMaxCutSprCHRs/8)+1)*((8*2)+2)
	inx
	inx
	inx
	inx
	dey	; Next Frame
	bpl _RIWS400
;
	rts



	%section(ENGINE_RAMCODE)
;
;	* * * * * * *       HANDLE WEAPONS CHANGES       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLUpdateWeapon:
	rep #$30		; mode 'AX!'
;
;	>>>   HANDLE WEAPON TYPE CHANGE   <<<
;
	ldx.w WeaponType+!RLSNESGSUXVarsO	; Same Weapon as Last?
	cpx.b WeaponTypeOld
	beq _RUW300	; Yes
	lda.w #(rlfWeaponOAM+rlfWeaponDEF)	; NO WEAPON BUILT!
	tsb.b RLFlags
	stz.b WeaponIRQBuildPhase	; DON'T BUILD NEW WEAPON!
	stx.b WeaponTypeOld
	lda.l WeaponNumFramesTable,x	; Get #Frames to Build
	sta.b WeaponBuildLeft
	lda.l WeaponFrameListsTable,x	; Get Starting Frame# to Build
	sta.b WeaponBuildList
	lda.w #-1	; WEAPON NOT BUILT!
	sta.w WeaponTypeBuilt
	sta.b WeaponFrameOld
	lda.w #0-4	; Start Building Frame#0
	sta.b WeaponBuildFrame
	stz.b WeaponBuildPhase
	lda.w #2	; BUILD NEW WEAPON!
	sta.b WeaponIRQBuildPhase
;
;	>>>   HANDLE BUILDING WEAPON FRAMES   <<<
;
_RUW300:
	ldx.b WeaponBuildPhase	; Still Building Frames?
	jmp.w (WeaponBuildPhaseCode,x)
;
;	>>>   DONE BUILDING WEAPON FRAMES   <<<
;
_RLBuildWeaponDone:	; NO!  BUILD COMPLETED!
	lda.b RLFlags	; WEAPON BUILT ALREADY (PENDING XFER)?
	and.w #(rlfWeaponOAM+rlfWeaponDEF)
	cmp.w #(rlfWeaponOAM+rlfWeaponDEF)
	bne _RUW900	; YES, CAN'T BUILD NEXT ONE YET!
;
;	>>>   HANDLE WEAPON FRAME CHANGE   <<<
;
_RUW500:
	ldx.w WeaponFrame+!RLSNESGSUXVarsO	; SAME FRAME?
	cpx.b WeaponFrameOld
	beq _RUW600	; Yes
	stx.b WeaponFrameOld	; Save NEW WeaponFrame#
	pea.w rlfWeaponDEF	; WEAPON DEF+OAM BUILT!
	lda.l _WeaponDEFGDMATable,x	; Get Address of DEFs GDMA Stack
	sta.b WeaponDEFGDMA
	lda.l _WeaponDEFGDMATable+2,x	; Get Size of DEFs GDMA Stack
	sta.b WeaponDEFGDMABytes
	lda.w WeaponX+!RLSNESGSUXVarsO
	jmp.w _RUW640
;
;	>>>   HANDLE WEAPON POSITION CHANGE   <<<
;
_RUW600:
	pea.w rlfWeaponOAM	; WEAPON OAM BUILT!
	lda.w WeaponX+!RLSNESGSUXVarsO	; SAME X COORDINATE?
	cmp.b WeaponXOld
	bne _RUW640	; No
	ldy.w InvisibleCount+!RLSNESGSUXVarsO	; INVISIBILITY?
	bne _RUW640	; YES!
	lda.w WeaponY+!RLSNESGSUXVarsO	; SAME Y COORDINATE?
	cmp.b WeaponYOld
	bne _RUW680	; No
	pla
	jmp.w _RUW900	; Yes
_RUW640:
	sta.b WeaponXOld	; Save NEW WeaponX
	lda.w WeaponY+!RLSNESGSUXVarsO
_RUW680:
	sta.b WeaponYOld	; Save NEW WeaponY
;
;	>>>   BUILD NEW WEAPON OAM TABLE   <<<
;
_RUW700:
	jsr.w _RLBuildWeaponOAM	; Build the OAM TransferLists
	pla	; WEAPON BUILT!
	trb.b RLFlags
;
;	>>>   WEAPONS CHANGES HANDLED   <<<
;
_RUW900:
;
;	>>>   EXIT WHILE STILL BUILDING WEAPON FRAMES   <<<
;
_RLBuildWeaponExit:	; STILL BUILDING FRAMES!
	rts

;
;	* * * * * * *       JUMPTABLE OF WEAPON BUILD PHASES' CODE       * * * * * * *
;
WeaponBuildPhaseCode:
	dw lo16(_RLBuildWeaponExit)	; Wait for IRQ to Transfer Data
	dw lo16(_RLBuildWeaponDEFData)	; Build DEF Data
	dw lo16(_RLBuildWeaponOAMData)	; Build OAM Data
	dw lo16(_RLBuildWeaponDone)	; DONE!
;
;	* * * * * * *       JUMPTABLE OF WEAPON IRQ BUILD PHASES' CODE       * * * * * * *
;
WeaponIRQBuildPhaseCode:
	dw lo16(_RLBuildWeaponExit)	; Wait for New Weapon to Build
	dw lo16(_RLBuildWeaponIRQXFer1)	; Transfer _ImageTbl/_CharData/_MiscData
	dw lo16(_RLBuildWeaponIRQXFer2)	; Transfer _CharDef

;
;	* * * * * * *       NUMBER OF FRAMES IN EACH WEAPON       * * * * * * *
;
WeaponNumFramesTable:
	dw 4	; Fist
	dw 3	; Pistol
	dw 6	; ShotGun
	dw 4	; ChainSaw
	dw 3	; ChainGun
	dw 6	; Rocket Launcher
	dw 4	; Plasma Rifle
	dw 3	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw 6	; Super Shotgun (DOOM II)
	endif

;
;	* * * * * * *       LIST OF IMAGES FOR EACH FRAME IN EACH WEAPON       * * * * * * *
;
WeaponFrameListsTable:
	dw (WeaponFrameListFist-WeaponFrameLists)	; Fist
	dw (WeaponFrameListPistol-WeaponFrameLists)	; Pistol
	dw (WeaponFrameListShotGun-WeaponFrameLists)	; ShotGun
	dw (WeaponFrameListChainSaw-WeaponFrameLists)	; ChainSaw
	dw (WeaponFrameListChainGun-WeaponFrameLists)	; ChainGun
	dw (WeaponFrameListRocket-WeaponFrameLists)	; Rocket Launcher
	dw (WeaponFrameListPlasma-WeaponFrameLists)	; Plasma Rifle
	dw (WeaponFrameListBFG-WeaponFrameLists)	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw (WeaponFrameListSuperShotGun-WeaponFrameLists)	; Super Shotgun (DOOM II)
	endif

;
;	* * * * * * *       LIST OF IMAGES FOR EACH FRAME IN EACH WEAPON       * * * * * * *
;
WeaponFrameLists:
WeaponFrameListFist:
	dw 0,-1	; PUNGA0
	dw 4,-1	; PUNGB0
	dw 8,-1	; PUNGC0
	dw 12,-1	; PUNGD0
WeaponFrameListPistol:
	dw 0,-1	; PISGA0
	dw 4,12,-1	; PISGB0, PISFA0
	dw 8,-1	; PISGC0
WeaponFrameListShotGun:
	dw 0,-1	; SHTGA0
	dw 0,16,-1	; SHTGA0, SHTFA0
	dw 0,20,-1	; SHTGA0, SHTFB0
	dw 4,-1	; SHTGB0
	dw 8,-1	; SHTGC0
	dw 12,-1	; SHTGD0
WeaponFrameListChainSaw:
	dw 0,-1	; SAWGC0
	dw 4,-1	; SAWGD0
	dw 8,-1	; SAWGA0
	dw 12,-1	; SAWGB0
WeaponFrameListChainGun:
	dw 0,-1	; CHGGA0
	dw 4,12,-1	; CHGGB0, CHGFB0
	dw 0,8,-1	; CHGGA0, CHGFA0
WeaponFrameListRocket:
	dw 0,-1	; MISGA0
	dw 8,4,-1	; MISFA0, MISGB0
	dw 12,4,-1	; MISFB0, MISGB0
	dw 16,4,-1	; MISFC0, MISGB0
	dw 20,4,-1	; MISFD0, MISGB0
	dw 4,-1	; MISGB0
WeaponFrameListPlasma:
	dw 0,-1	; PLSGA0
	dw 8,-1	; PLSFA0
	dw 12,-1	; PLSFB0
	dw 4,-1	; PLSGB0
WeaponFrameListBFG:
	dw 0,-1	; BFGGA0
	dw 4,0,-1	; BFGFA0, BFGGA0
	dw 8,0,-1	; BFGFB0, BFGGA0
	if !RLDOOM2MONSTERS != 0
WeaponFrameListSuperShotGun:	; (tools/wad2cut.py)
	dw 0,-1	; SHT2A0
	dw 0,4,-1	; SHT2A0, SHT2I0
	dw 8,-1	; SHT2B0
	dw 12,-1	; SHT2D0
	dw 16,-1	; SHT2F0
	dw 20,-1	; SHT2H0
	endif

;
;	* * * * * * *       WEAPONS TYPE BITS       * * * * * * *
;
WeaponTypeBitsTable:
;	(GSU ROM address of this table: ROM offset + $400000)
	_WeaponTypeBitsTable = $5C0FFD
	assert (_WeaponTypeBitsTable&$FFFFFF) == ((((snestopc(realbase())&$00FFFFFF)+$400000))&$FFFFFF), "cached constant _WeaponTypeBitsTable is stale (tools/fixup.py)"
	dw wtbFist	; Fist
	dw wtbPistol	; Pistol
	dw wtbShotGun	; ShotGun
	dw wtbChainSaw	; ChainSaw
	dw wtbChainGun	; ChainGun
	dw wtbRocket	; Rocket Launcher
	dw wtbPlasma	; Plasma Rifle
	dw wtbBFG	; BFG9000
	dw wtbFist	; Fist (WrapAround Entry)

;
;	* * * * * * *       _IMAGETBL/_CHARDATA/_MISCDATA       * * * * * * *
;	* * * * * * *       _CHARDEF BANK FOR EACH WEAPON       * * * * * * *
;
WeaponImageTblBankTable:
;WeaponCharDefBankTable	equ	*+1
	dw ((bank(_CharDefFist)<<8)|bank(_ImageTblFist))	; Fist
	dw ((bank(_CharDefPistol)<<8)|bank(_ImageTblPistol))	; Pistol
	dw ((bank(_CharDefShotGun)<<8)|bank(_ImageTblShotGun))	; ShotGun
	dw ((bank(_CharDefChainSaw)<<8)|bank(_ImageTblChainSaw))	; ChainSaw
	dw ((bank(_CharDefChainGun)<<8)|bank(_ImageTblChainGun))	; ChainGun
	dw ((bank(_CharDefRocket)<<8)|bank(_ImageTblRocket))	; Rocket Launcher
	dw ((bank(_CharDefPlasma)<<8)|bank(_ImageTblPlasma))	; Plasma Rifle
	dw ((bank(_CharDefBFG)<<8)|bank(_ImageTblBFG))	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw ((bank(_CharDefSuperShotGun)<<8)|bank(_ImageTblSuperShotGun))	; Super Shotgun (DOOM II)
	endif
;
;	* * * * * * *       _IMAGETBL FOR EACH WEAPON       * * * * * * *
;
WeaponImageTblTable:
	dw lo16(_ImageTblFist)	; Fist
	dw lo16(_ImageTblPistol)	; Pistol
	dw lo16(_ImageTblShotGun)	; ShotGun
	dw lo16(_ImageTblChainSaw)	; ChainSaw
	dw lo16(_ImageTblChainGun)	; ChainGun
	dw lo16(_ImageTblRocket)	; Rocket Launcher
	dw lo16(_ImageTblPlasma)	; Plasma Rifle
	dw lo16(_ImageTblBFG)	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw lo16(_ImageTblSuperShotGun)	; Super Shotgun (DOOM II)
	endif
;
;	* * * * * * *       _IMAGETBL SIZES FOR EACH WEAPON       * * * * * * *
;
WeaponImageTblSizeTable:
	dw (_ImageTblFistE-_ImageTblFist)	; Fist
	dw (_ImageTblPistolE-_ImageTblPistol)	; Pistol
	dw (_ImageTblShotGunE-_ImageTblShotGun)	; ShotGun
	dw (_ImageTblChainSawE-_ImageTblChainSaw)	; ChainSaw
	dw (_ImageTblChainGunE-_ImageTblChainGun)	; ChainGun
	dw (_ImageTblRocketE-_ImageTblRocket)	; Rocket Launcher
	dw (_ImageTblPlasmaE-_ImageTblPlasma)	; Plasma Rifle
	dw (_ImageTblBFGE-_ImageTblBFG)	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw (_ImageTblSuperShotGunE-_ImageTblSuperShotGun)	; Super Shotgun (DOOM II)
	endif
;
;	* * * * * * *       _CHARDATA FOR EACH WEAPON       * * * * * * *
;
WeaponCharDataTable:
	dw lo16(_CharDataFist)	; Fist
	dw lo16(_CharDataPistol)	; Pistol
	dw lo16(_CharDataShotGun)	; ShotGun
	dw lo16(_CharDataChainSaw)	; ChainSaw
	dw lo16(_CharDataChainGun)	; ChainGun
	dw lo16(_CharDataRocket)	; Rocket Launcher
	dw lo16(_CharDataPlasma)	; Plasma Rifle
	dw lo16(_CharDataBFG)	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw lo16(_CharDataSuperShotGun)	; Super Shotgun (DOOM II)
	endif
;
;	* * * * * * *       _CHARDATA SIZES FOR EACH WEAPON       * * * * * * *
;
WeaponCharDataSizeTable:
	dw (_CharDataFistE-_CharDataFist)	; Fist
	dw (_CharDataPistolE-_CharDataPistol)	; Pistol
	dw (_CharDataShotGunE-_CharDataShotGun)	; ShotGun
	dw (_CharDataChainSawE-_CharDataChainSaw)	; ChainSaw
	dw (_CharDataChainGunE-_CharDataChainGun)	; ChainGun
	dw (_CharDataRocketE-_CharDataRocket)	; Rocket Launcher
	dw (_CharDataPlasmaE-_CharDataPlasma)	; Plasma Rifle
	dw (_CharDataBFGE-_CharDataBFG)	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw (_CharDataSuperShotGunE-_CharDataSuperShotGun)	; Super Shotgun (DOOM II)
	endif
;
;	* * * * * * *       _MISCDATA FOR EACH WEAPON       * * * * * * *
;
WeaponMiscDataTable:
	dw lo16(_MiscDataFist)	; Fist
	dw lo16(_MiscDataPistol)	; Pistol
	dw lo16(_MiscDataShotGun)	; ShotGun
	dw lo16(_MiscDataChainSaw)	; ChainSaw
	dw lo16(_MiscDataChainGun)	; ChainGun
	dw lo16(_MiscDataRocket)	; Rocket Launcher
	dw lo16(_MiscDataPlasma)	; Plasma Rifle
	dw lo16(_MiscDataBFG)	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw lo16(_MiscDataSuperShotGun)	; Super Shotgun (DOOM II)
	endif
;
;	* * * * * * *       _MISCDATA SIZES FOR EACH WEAPON       * * * * * * *
;
WeaponMiscDataSizeTable:
	dw (_MiscDataFistE-_MiscDataFist)	; Fist
	dw (_MiscDataPistolE-_MiscDataPistol)	; Pistol
	dw (_MiscDataShotGunE-_MiscDataShotGun)	; ShotGun
	dw (_MiscDataChainSawE-_MiscDataChainSaw)	; ChainSaw
	dw (_MiscDataChainGunE-_MiscDataChainGun)	; ChainGun
	dw (_MiscDataRocketE-_MiscDataRocket)	; Rocket Launcher
	dw (_MiscDataPlasmaE-_MiscDataPlasma)	; Plasma Rifle
	dw (_MiscDataBFGE-_MiscDataBFG)	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw (_MiscDataSuperShotGunE-_MiscDataSuperShotGun)	; Super Shotgun (DOOM II)
	endif
;
;	* * * * * * *       _CHARDEF FOR EACH WEAPON       * * * * * * *
;
WeaponCharDefTable:
	dw lo16(_CharDefFist)	; Fist
	dw lo16(_CharDefPistol)	; Pistol
	dw lo16(_CharDefShotGun)	; ShotGun
	dw lo16(_CharDefChainSaw)	; ChainSaw
	dw lo16(_CharDefChainGun)	; ChainGun
	dw lo16(_CharDefRocket)	; Rocket Launcher
	dw lo16(_CharDefPlasma)	; Plasma Rifle
	dw lo16(_CharDefBFG)	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw lo16(_CharDefSuperShotGun)	; Super Shotgun (DOOM II)
	endif
;
;	* * * * * * *       _CHARDEF SIZES FOR EACH WEAPON       * * * * * * *
;
WeaponCharDefSizeTable:
	dw (_CharDefFistE-_CharDefFist)	; Fist
	dw (_CharDefPistolE-_CharDefPistol)	; Pistol
	dw (_CharDefShotGunE-_CharDefShotGun)	; ShotGun
	dw (_CharDefChainSawE-_CharDefChainSaw)	; ChainSaw
	dw (_CharDefChainGunE-_CharDefChainGun)	; ChainGun
	dw (_CharDefRocketE-_CharDefRocket)	; Rocket Launcher
	dw (_CharDefPlasmaE-_CharDefPlasma)	; Plasma Rifle
	dw (_CharDefBFGE-_CharDefBFG)	; BFG9000
	if !RLDOOM2MONSTERS != 0
	dw (_CharDefSuperShotGunE-_CharDefSuperShotGun)	; Super Shotgun (DOOM II)
	endif


;
;	* * * * * * *       BUILD WEAPON IRQ XFER 1       * * * * * * *
;
;	TRANSFER WEAPONDATA _IMAGETBL/_CHARDATA/_MISCDATA
;
	; dbr 0
	; dpr 0
	; mode 'AX'
_RLBuildWeaponIRQXFer1:
;
;	>>>   INITIALIZE WEAPON _IMAGETBL/_CHARDATA/_MISCDATA TRANSFERS   <<<
;
	sep #$10		; mode 'x!'
	ldx.b WeaponTypeOld	; Get WeaponType to Build
	lda.l WeaponImageTblBankTable,x	; Bank of WeaponData _ImageTbl/_MiscData/_CharData
	sta.w DMA4A1B
;
	sta.b WeaponCharDefAddr+1	; Bank of WeaponData _CharDef
	lda.l WeaponCharDefTable,x	; Address of WeaponData _CharDef
	sta.b WeaponCharDefAddr
	lda.l WeaponCharDefSizeTable,x	; #Bytes .CHARDEF to Transfer
	sta.b WeaponCharDefSize
	lda.w #lo16(_CharDef)	; Destination
	sta.b WeaponCharDefWAddr
;
	lda.l WeaponMiscDataTable,x	; _MiscData
	pha
	lda.l WeaponMiscDataSizeTable,x
	pha
	lda.l WeaponCharDataTable,x	; _CharData
	pha
	lda.l WeaponCharDataSizeTable,x
	pha
;
;	>>>   TRANSFER WEAPON _IMAGETBL FROM ROM TO WRAM   <<<
;
	lda.l WeaponImageTblTable,x	; Source
	sta.w DMA4A1L
	lda.w #lo16(_ImageTbl)	; Destination
	sta.w WMADDL
	lda.l WeaponImageTblSizeTable,x	; #Bytes
	sta.w DMA4NUML
	ldx.b #1	; WM Bank
	stx.w WMADDB
;
;	>>>   STEAL ROM AWAY FROM GSU   <<<
;
	ldx.b #%00001111	; 160 Pixels, GSU has RAM, SNES has ROM, 256 Colour
	ldy.b #%00011111	; 160 Pixels, GSU has ROM/RAM, 256 Colour
;	ifn	DEBUG
;	stx	SCR_XS				; XSLV Shadow
;	endif
	stx.w sfxSCR
;
;	>>>   TRANSFER WEAPON _IMAGETBL FROM ROM TO WRAM   <<<
;
	ldx.b #(1<<4)
	stx.w MDMAEN
;
;	>>>   TRANSFER WEAPON _CHARDATA FROM ROM TO WRAM   <<<
;
	pla	; #Bytes
	sta.w DMA4NUML
	pla	; Source
	sta.w DMA4A1L
	lda.w #lo16(_CharData)	; Destination
	sta.w WMADDL
	stx.w MDMAEN
;
;	>>>   TRANSFER WEAPON _MISCDATA FROM ROM TO WRAM   <<<
;
	pla	; #Bytes
	sta.w DMA4NUML
	pla	; Source
	sta.w DMA4A1L
	lda.w #lo16(_MiscData)	; Destination
	sta.w WMADDL
	stx.w MDMAEN
;
;	>>>   RELEASE ROM TO GSU   <<<
;
;	ifn	DEBUG
;	sty	SCR_XS				; XSLV Shadow
;	endif
	sty.w sfxSCR
	ldx.b #$70	; A Bank
	stx.w DMA4A1B
	ldx.b #0	; WM Bank
	stx.w WMADDB
	rep #$10		; mode 'X!'
;
	lda.w #4	; TRANSFER WEAPON .CHARDEF
	sta.b WeaponIRQBuildPhase
	rts


;
;	* * * * * * *       BUILD WEAPON IRQ XFER 2       * * * * * * *
;
;	TRANSFER NEXT BLOCK OF WEAPONDATA .CHARDEF
;
	; dbr 0
	; dpr 0
	; mode 'AX'
_RLBuildWeaponIRQXFer2:
;
;	>>>   INITIALIZE WEAPON .CHARDEF TRANSFER   <<<
;
	sep #$10		; mode 'x!'
	ldx.b WeaponCharDefAddr+2	; Bank of WeaponData _CharDef
	stx.w DMA4A1B
	lda.b WeaponCharDefAddr	; Source
	sta.w DMA4A1L
	lda.b WeaponCharDefWAddr	; Destination
	sta.w WMADDL
	ldx.b #1	; WM Bank
	stx.w WMADDB
	lda.w #RLMaxCharDefXFer	; Maximum Bytes to Transfer
	cmp.b WeaponCharDefSize
	bcc _RBWIX200	; Only Transfer Maximum!
	lda.b WeaponCharDefSize
_RBWIX200:
	sta.b ITemp	; #Bytes Transferred
	sta.w DMA4NUML
	lda.w #(1<<4)	; MDMAEN / HDMAEN
;
;	>>>   STEAL ROM AWAY FROM GSU   <<<
;
	ldx.b #%00001111	; 160 Pixels, GSU has RAM, SNES has ROM, 256 Colour
	ldy.b #%00011111	; 160 Pixels, GSU has ROM/RAM, 256 Colour
;	ifn	DEBUG
;	stx	SCR_XS				; XSLV Shadow
;	endif
	stx.w sfxSCR
;
;	>>>   TRANSFER WEAPON _CHARDEF FROM ROM TO WRAM   <<<
;
	sta.w MDMAEN	; Start Transfer
;
;	>>>   RELEASE ROM TO GSU   <<<
;
;	ifn	DEBUG
;	sty	SCR_XS				; XSLV Shadow
;	endif
	sty.w sfxSCR
	ldx.b #$70	; A Bank
	stx.w DMA4A1B
	ldx.b #0	; WM Bank
	stx.w WMADDB
	rep #$10		; mode 'X!'
;
;	>>>   UPDATE TRANSFER SIZE/ADDRESSES   <<<
;
	lda.b WeaponCharDefSize	; Update Remaining Bytes
	sec
	sbc.b ITemp
	beq _RBWIX800	; Nothing Remaining!
	sta.b WeaponCharDefSize
	lda.b ITemp	; Update Transfer Address
	tax
	clc
	adc.b WeaponCharDefAddr
	sta.b WeaponCharDefAddr
	txa	; Update Transfer WRAM Address
	clc
	adc.b WeaponCharDefWAddr
	sta.b WeaponCharDefWAddr
	rts
;
;	>>>   FINISHED TRANSFERRING THE WEAPONDATA!   <<<
;
_RBWIX800:
	lda.w #2	; BUILD NEW WEAPON!
	sta.b WeaponBuildPhase
	stz.b WeaponIRQBuildPhase	; FINISHED TRANSFERRING WEAPON .CHARDEF
	rts


;
;	* * * * * * *       BUILD WEAPON DEF DATA       * * * * * * *
;
;	BUILD PRECOMPUTED WEAPON_MCHR_DEF_GDMA STACK DATA FOR ONE FRAME
;
	; dbr ?
	; dpr 0
	; mode 'X'
_RLBuildWeaponDEFData:
	phb	; Save .DBR
	sep #$20		; mode 'a!'
	lda.b #bank(_ImageTbl)	; Set .DBR to ImageTable
	pha
	plb
	; dbr ^_ImageTbl
;
	rep #$20		; mode 'A!'
	lda.b WeaponBuildFrame	; Build Next Frame
	clc
	adc.w #4
	sta.b WeaponBuildFrame
	tax
;
	ldy.w _WeaponDEFGDMATable,x	; Get Pointer to WeaponDEFGDMAData
	phy	; Save Initial StackPointer
;
	ldx.b WeaponBuildList	; Get FrameList Index
;
;	+++   BUILD NEXT FRAME   +++
;
_RBWDD1200:
	lda.l WeaponFrameLists,x	; Get Image# to Build
	bmi _RBWDD8000	; End of FrameList
	phx
	tax	; .X = Image Index
;
;	+++   ADD NEXT FRAME DATA   +++
;
	phy	; Save Stack Index
	ldy.w _ImageTbl+itsMiscData,x	; Get Image's MiscData Index
	lda.w _MiscData+imdOAMNum,y	; Get #OAMs TOTAL
	and.w #$00FF
	sta.b Temp	; #OAMs to Process
	lda.w _ImageTbl+itsCharData,x	; Get Image's CharData Index
	tax	; .X = CharData Index
	ply	; .Y = Stack Index
;
;	+++   INITIALIZE THE CHARDATA DECOMPRESSION DATA   +++
;
	lda.w #(_CDStackEnd-_CDStack)	; Start Stack
	sta.b _CDSP
	stz.b _CDMode	; In Mode0
	lda.w #-1	; No Duplicates
	sta.b _CDNumDups
	stz.b _CDCharNumNT	; Last Non-Transparent Character
;
;	+++   PROCESS NEXT GROUP OF MASTER_CHARACTERS   <<<
;
_RBWDD2200:
	stx.b _CDOfst	; Save Index into CharData
	lda.b Temp	; <=8 MasterCharacters Left?
	cmp.w #9
	bcc _RBWDD2240	; Yes
	lda.w #8	; No, Only do 8 maximum!
_RBWDD2240:
	sta.b Temp+2	; (TEMP+2) = #MCHRs in GROUP
	tax
	lda.b Temp	; Reduce #Remaining MCHRs
	sec
	sbc.b Temp+2
	sta.b Temp
	txa
	asl a	; .X = #MCHRs in GROUP * 2
	tax
	lda.l _WDMGCode-2,x	; DMA Routine
;
	_WeaponDEFGDMABase = $7F0000
	assert (_WeaponDEFGDMABase&$FFFFFF) == (((bank(_WeaponDEFGDMAData)<<16))&$FFFFFF), "cached constant _WeaponDEFGDMABase is stale (tools/fixup.py)"
;
	sta.w _WeaponDEFGDMABase,y	; Return Address
	ldx.b _CDOfst	; Get CharData Index
_RBWDD3000:
	sty.b _DEFGDMASP	; Save .SP
	jsr.w _GetCharDataMChr	; Get CharData MasterCharNum
	asl a	; (Char# << 5)
	asl a
	asl a
	asl a
	asl a
;	clc					; Add Base Address of _CharDef
	adc.w #lo16(_CharDef)
	ldy.b _DEFGDMASP
	iny
	iny
	sta.w _WeaponDEFGDMABase,y
	dec.b Temp+2	; Next MasterCharacter
	bne _RBWDD3000
	iny
	iny
	lda.b Temp	; Any Remaining MCHRs?
	bne _RBWDD2200	; Yes, process them now
;
;	+++   BUILD NEXT WEAPON FRAME IMAGE   +++
;
	plx	; Get FrameList Index
	inx
	inx
	jmp.w _RBWDD1200	; Build Next Image
;
;	+++   FINISHED BUILDING WEAPON FRAME IMAGES   +++
;
_RBWDD8000:
	lda.w #lo16(_RLReInitDMA-1)	; ReInitialize GDMA Channels
	sta.w _WeaponDEFGDMABase,y
	iny
	iny
	lda.w #lo16(_WDMGEndCode-1)
	sta.w _WeaponDEFGDMABase,y
	iny
	iny
;
	tya	; Calculate #Bytes to Transfer
	ply	; .Y = Starting StackAddress
	sty.b Temp
	sec
	sbc.b Temp
	ldx.b WeaponBuildFrame	; Get Frame#
	sta.w _WeaponDEFGDMATable+2,x	; Save #Bytes to DMA
;
	plb	; Restore .DBR
	lda.w #4	; Move to next Phase
	sta.b WeaponBuildPhase
	jmp.w _RLBuildWeaponExit

;
;	* * * * * * *       TABLE OF WEAPON DEF MCHR_GDMA ROUTINES       * * * * * * *
;
_WDMGCode:
	dw lo16(_WDMG1-1)	; 1 Character
	dw lo16(_WDMG2-1)	; 2 Characters
	dw lo16(_WDMG3-1)	; 3 Characters
	dw lo16(_WDMG4-1)	; 4 Characters
	dw lo16(_WDMG5-1)	; 5 Characters
	dw lo16(_WDMG6-1)	; 6 Characters
	dw lo16(_WDMG7-1)	; 7 Characters
	dw lo16(_WDMG8-1)	; 8 Characters


	; mode 'Ax'
	; dbr 0
	; dpr DMA0INC

;
;	>>>   WEAPON DEF MCHR_GDMA 8 CHARACTERS   <<<
;
_WDMG8:
	pla	; Source0
	sta.b DMA0A1L-DMA0INC
	pla	; Source1
	sta.b DMA1A1L-DMA0INC
	pla	; Source2
	sta.b DMA2A1L-DMA0INC
	pla	; Source3
	sta.b DMA3A1L-DMA0INC
	pla	; Source4
	sta.b DMA4A1L-DMA0INC
	pla	; Source5
	sta.b DMA5A1L-DMA0INC
	pla	; Source6
	sta.b DMA6A1L-DMA0INC
	pla	; Source7
	sta.b DMA7A1L-DMA0INC
	sty.b DMA0NUML-DMA0INC	; Size
	sty.b DMA1NUML-DMA0INC
	sty.b DMA2NUML-DMA0INC
	sty.b DMA3NUML-DMA0INC
	sty.b DMA4NUML-DMA0INC
	sty.b DMA5NUML-DMA0INC
	sty.b DMA6NUML-DMA0INC
	sty.b DMA7NUML-DMA0INC
	stx.w MDMAEN	; Start GDMA
	rts
;
;	>>>   WEAPON DEF MCHR_GDMA 7 CHARACTERS   <<<
;
_WDMG7:
	pla	; Source0
	sta.b DMA0A1L-DMA0INC
	pla	; Source1
	sta.b DMA1A1L-DMA0INC
	pla	; Source2
	sta.b DMA2A1L-DMA0INC
	pla	; Source3
	sta.b DMA3A1L-DMA0INC
	pla	; Source4
	sta.b DMA4A1L-DMA0INC
	pla	; Source5
	sta.b DMA5A1L-DMA0INC
	pla	; Source6
	sta.b DMA6A1L-DMA0INC
	sty.b DMA0NUML-DMA0INC	; Size
	sty.b DMA1NUML-DMA0INC
	sty.b DMA2NUML-DMA0INC
	sty.b DMA3NUML-DMA0INC
	sty.b DMA4NUML-DMA0INC
	sty.b DMA5NUML-DMA0INC
	sty.b DMA6NUML-DMA0INC
	ldx.b #%01111111	; Start GDMA
	stx.w MDMAEN
	ldx.b #%11111111	; Start 8-Channel GDMA
	rts
;
;	>>>   WEAPON DEF MCHR_GDMA 6 CHARACTERS   <<<
;
_WDMG6:
	pla	; Source0
	sta.b DMA0A1L-DMA0INC
	pla	; Source1
	sta.b DMA1A1L-DMA0INC
	pla	; Source2
	sta.b DMA2A1L-DMA0INC
	pla	; Source3
	sta.b DMA3A1L-DMA0INC
	pla	; Source4
	sta.b DMA4A1L-DMA0INC
	pla	; Source5
	sta.b DMA5A1L-DMA0INC
	sty.b DMA0NUML-DMA0INC	; Size
	sty.b DMA1NUML-DMA0INC
	sty.b DMA2NUML-DMA0INC
	sty.b DMA3NUML-DMA0INC
	sty.b DMA4NUML-DMA0INC
	sty.b DMA5NUML-DMA0INC
	ldx.b #%00111111	; Start GDMA
	stx.w MDMAEN
	ldx.b #%11111111	; Start 8-Channel GDMA
	rts
;
;	>>>   WEAPON DEF MCHR_GDMA 5 CHARACTERS   <<<
;
_WDMG5:
	pla	; Source0
	sta.b DMA0A1L-DMA0INC
	pla	; Source1
	sta.b DMA1A1L-DMA0INC
	pla	; Source2
	sta.b DMA2A1L-DMA0INC
	pla	; Source3
	sta.b DMA3A1L-DMA0INC
	pla	; Source4
	sta.b DMA4A1L-DMA0INC
	sty.b DMA0NUML-DMA0INC	; Size
	sty.b DMA1NUML-DMA0INC
	sty.b DMA2NUML-DMA0INC
	sty.b DMA3NUML-DMA0INC
	sty.b DMA4NUML-DMA0INC
	ldx.b #%00011111	; Start GDMA
	stx.w MDMAEN
	ldx.b #%11111111	; Start 8-Channel GDMA
	rts
;
;	>>>   WEAPON DEF MCHR_GDMA 4 CHARACTERS   <<<
;
_WDMG4:
	pla	; Source0
	sta.b DMA0A1L-DMA0INC
	pla	; Source1
	sta.b DMA1A1L-DMA0INC
	pla	; Source2
	sta.b DMA2A1L-DMA0INC
	pla	; Source3
	sta.b DMA3A1L-DMA0INC
	sty.b DMA0NUML-DMA0INC	; Size
	sty.b DMA1NUML-DMA0INC
	sty.b DMA2NUML-DMA0INC
	sty.b DMA3NUML-DMA0INC
	ldx.b #%00001111	; Start GDMA
	stx.w MDMAEN
	ldx.b #%11111111	; Start 8-Channel GDMA
	rts
;
;	>>>   WEAPON DEF MCHR_GDMA 3 CHARACTERS   <<<
;
_WDMG3:
	pla	; Source0
	sta.b DMA0A1L-DMA0INC
	pla	; Source1
	sta.b DMA1A1L-DMA0INC
	pla	; Source2
	sta.b DMA2A1L-DMA0INC
	sty.b DMA0NUML-DMA0INC	; Size
	sty.b DMA1NUML-DMA0INC
	sty.b DMA2NUML-DMA0INC
	ldx.b #%00000111	; Start GDMA
	stx.w MDMAEN
	ldx.b #%11111111	; Start 8-Channel GDMA
	rts
;
;	>>>   WEAPON DEF MCHR_GDMA 2 CHARACTERS   <<<
;
_WDMG2:
	pla	; Source0
	sta.b DMA0A1L-DMA0INC
	pla	; Source1
	sta.b DMA1A1L-DMA0INC
	sty.b DMA0NUML-DMA0INC	; Size
	sty.b DMA1NUML-DMA0INC
	ldx.b #%00000011	; Start GDMA
	stx.w MDMAEN
	ldx.b #%11111111	; Start 8-Channel GDMA
	rts
;
;	>>>   WEAPON DEF MCHR_GDMA 1 CHARACTERS   <<<
;
_WDMG1:
	pla	; Source0
	sta.b DMA0A1L-DMA0INC
	sty.b DMA0NUML-DMA0INC
	ldx.b #%00000001	; Start GDMA
	stx.w MDMAEN
	ldx.b #%11111111	; Start 8-Channel GDMA
	rts



;
;	* * * * * * *       BUILD WEAPON OAM DATA       * * * * * * *
;
;	BUILD PRECOMPUTED WEAPON_OAM TABLE FOR ONE FRAME
;
;	DC.W	X_OFFSET
;	DC.W	Y_OFFSET
;	DC.B	CHAR#
;	DC.B	FLAGS
;
	; dbr ?
	; dpr 0
	; mode 'X'
_RLBuildWeaponOAMData:
	phb	; Save .DBR
	sep #$20		; mode 'a!'
	lda.b #bank(_ImageTbl)	; Set .DBR to ImageTable
	pha
	plb
	; dbr ^_ImageTbl
;
	rep #$20		; mode 'A!'
	ldx.b WeaponBuildFrame	; Build Next Frame
	lda.w _WeaponOAMTable,x	; .Y = Pointer to WeaponOAMData
	tay
;
	lda.w #0	; #OAMs TOTAL
	sta.w _WeaponOAMTable+2,x
;
	lda.w #((vmWEAPONDEF&$1FFF)>>4)	; Starting Character#
	sta.b _CHRNum
;
	ldx.b WeaponBuildList	; Get FrameList Index
;
;	+++   BUILD NEXT FRAME   +++
;
_RBWOD1200:
	inx	; Get Image# to Build
	inx
	lda.l WeaponFrameLists-2,x
	bmi _RBWOD8000	; End of FrameList
	phx	; Save FrameList Index
;
	tax	; .X = Image Index
	phy	; Save OAM Index
	ldy.w _ImageTbl+itsMiscData,x	; Get Image's MiscData Index
	lda.w _MiscData+imdOAMNum,y	; Get #OAMs TOTAL
	and.w #$00FF
	sta.b Temp	; #OAMs to Process
	ldx.b WeaponBuildFrame	; Update #OAMs TOTAL
	clc
	adc.w _WeaponOAMTable+2,x
	sta.w _WeaponOAMTable+2,x
	iny	; Move to first ImgMiscDataList
	plx	; .X = OAM Index
;
;	+++   CHARACTER# / FLAGS   +++
;
_RBWOD2100:
	sep #$20		; mode 'a!'
	lda.w _MiscData+imdlFlags,y	; OAM Flags
	xba
	lda.b _CHRNum	; Current Character#
	rep #$20		; mode 'A!'
	sta.w _WeaponOAMData+4,x
;
;	+++   X COORDINATE   +++
;
	lda.w #$FFFF	; Default X Offset HighByte
	sep #$20		; mode 'a!'
	lda.w _MiscData+imdlOAMXOfs,y	; OAM X Offset
	bmi _RBWOD2200
	rep #$20		; mode 'A!'
	and.w #$00FF
_RBWOD2200:
	rep #$20		; mode 'A!'
	sta.w _WeaponOAMData+0,x	; SAVE X OFFSET
;
;	+++   Y COORDINATE   +++
;
	lda.w #$FFFF	; Default Y Offset HighByte
	sep #$20		; mode 'a!'
	lda.w _MiscData+imdlOAMYOfs,y	; OAM Y Offset
	bmi _RBWOD2400
	rep #$20		; mode 'A!'
	and.w #$00FF
_RBWOD2400:
	rep #$20		; mode 'A!'
	sta.w _WeaponOAMData+2,x	; SAVE Y OFFSET
;
;	+++   NEXT OAM   +++
;
	iny	; Move to next MiscData
	iny
	iny
	txa	; Move to next WeaponOAMData
	clc
	adc.w #6
	tax
	inc.b _CHRNum	; Next Character#
;
	dec.b Temp	; One less OAM to handle
	bne _RBWOD2100
;
;	+++   BUILD NEXT WEAPON FRAME IMAGE   +++
;
	txy	; .Y = OAM Index
	plx	; Get FrameList Index
	bra _RBWOD1200	; Build Next Image
;
;	+++   FINISHED BUILDING WEAPON FRAME IMAGES   +++
;
_RBWOD8000:
	stx.b WeaponBuildList	; Update Weapon FrameList Index
	lda.w #2
	dec.b WeaponBuildLeft	; Any more Frames left to Build?
	bne _RBWOD8800	; Yes
	lda.b WeaponTypeOld	; WEAPON TYPE BUILT!
	sta.l WeaponTypeBuilt
	lda.w #6	; NO!  FINISHED BUILDING!
_RBWOD8800:
	sta.b WeaponBuildPhase
	plb	; Restore .DBR
	jmp.w _RLBuildWeaponExit


;
;	* * * * * * *       BUILD WEAPON OAM TABLE       * * * * * * *
;
;	.X	= (MasterFrame# * 4)
;
	; dbr ?
	; dpr 0
	; mode 'X'
_RLBuildWeaponOAM:
	rep #$20		; mode 'A!'
	ldy.w #$FFFF	; Leave at Priority2
	lda.w InvisibleCount+!RLSNESGSUXVarsO	; INVISIBILITY?
	beq _RBWO1000
	lsr a	; <8?
	lsr a
	lsr a
	beq _RBWO1000	; Yes, About to Stop
	ldy.w #$CFFF	; Change to Priority0
	cmp.w #(3*60/8)	; Running out?
	bcs _RBWO1000	; No
	lsr a
	bcc _RBWO1000	; Toggle between Normal and Invisible
	ldy.w #$FFFF
_RBWO1000:
	sty.w WeaponPriMask
;
	phb	; Save .DBR
	sep #$20		; mode 'a!'
	lda.b #bank(_ImageTbl)	; Set .DBR to ImageTable
	pha
	plb
	; dbr ^_ImageTbl
	rep #$20		; mode 'A!'
;
	lda.w _WeaponOAMTable+2,x	; Get #OAMs Required
	sta.b Temp
	ldy.w _WeaponOAMTable,x	; Get Image's OAMData Index
	ldx.w #(32*4)	; Starting Available OAM
	jmp.w _RBWO2200
_RBWO2000:
	inx	; Move to Next OAM
	inx
	inx
	inx
	tya	; Move to Next OAMData
	clc
	adc.w #6
	tay
_RBWO2200:
	lda.w _WeaponOAMData+0,y	; Get X Coordinate
	clc
	adc.b WeaponXOld
	sta.l OAMA+0,x
	lda.w _WeaponOAMData+2,y	; Get Y Coordinate
	clc
	adc.b WeaponYOld
	cmp.w #RLStatStartPixY	; Below Top of StatusBar?
	bcc _RBWO2400	; No!
	lda.w #0	; Yes, Mask off Screen!
_RBWO2400:
	sta.l OAMA+1,x
	lda.w _WeaponOAMData+4,y	; Get Character#/Flags
	and.l WeaponPriMask
_RBWO2500:
	sta.l OAMA+2,x
_RBWO2800:
	dec.b Temp	; One less OAM to handle
	bne _RBWO2000
	txa	; Get #Bytes to DMA
	sec
	sbc.w #((32*4)-4)	; Starting Available OAM
	sta.b WeaponOAMBytes
	cmp.b WeaponOAMBytesOld	; Sending MORE this time?
	bcs _RBWO3800	; Yes
	lda.b WeaponOAMBytesOld	; Get #OAMs we need to FILL
	sec
	sbc.b WeaponOAMBytes
	lsr a
	lsr a
	tay
	lda.w #MaxViewScanLines	; (256-32)
_RBWO3200:
	inx	; Move to next Free Sprite
	inx
	inx
	inx
	sta.l OAMA+1,x	; Move Extra Sprites off bottom
	dey
	bne _RBWO3200
_RBWO3800:
	plb	; Restore .DBR
	rts


;
;	* * * * * * *       GET CHAR_DATA MASTER_CHARACTER_NUMBER       * * * * * * *
;
;	.X = Index into _CHARDATA
;
;	.A = MasterCharacterNumber
;
	; dbr ^_ImageTbl
	; dpr 0
	; mode 'AX'
_GetCharDataMChr:
	lda.b _CDMode	; In middle of a command?
	beq _GCMC1000	; No
	jmp.w _GCMC8000	; Yes
_GCMC1000:
	ldy.b _CDNumDups	; Finished this Dup.Subroutine?
	bne _GCMC2000	; No
	ldy.b _CDSP
	ldx.w _CDStack,y
	lda.w _CDStack+2,y
	sta.b _CDNumDups
	tya
	clc
	adc.w #4
	sta.b _CDSP
	jmp.w _GCMC1000
;
_GCMC2000:
	sep #$20		; mode 'a!'
	lda.w _CharData,x	; Get <FormatCode>
	cmp.b #$C0	; >>> UNIQUE <<<
	bcs _GCMC3000
	xba
	lda.w _CharData+1,x	; Get MasterChar#
	rep #$20		; mode 'A!'
	sta.b _CDCharNumNT
	cpy.w #$8000	; If NumDups >= 0, NumDups--
	bcs _GCMC2200
	dey
	sty.b _CDNumDups
_GCMC2200:
	inx
	inx
	rts
;
	; mode 'a'
_GCMC3000:
	cmp.b #$E0	; >>> DUPLICATE <<<
	bcs _GCMC4000
	rep #$20		; mode 'A!'
	and.w #$001F	; .A = #Duplicates
;	clc
	adc.w #2
	inx
	bra _GCMC7200
;
	; mode 'a'
_GCMC4000:
	cmp.b #$F0	; >>> SEQUENTIAL <<<
	bcs _GCMC5000
	rep #$20		; mode 'A!'
	and.w #$000F	; .A = #Repeats
	ldy.w #1	; In Sequential Mode
_GCMC4200:
	sty.b _CDMode
;	clc
	adc.w #1
	ldy.b _CDNumDups
	bmi _GCMC4600
	cmp.b _CDNumDups	; NumReps < NumDups?
	bcc _GCMC4400	; Yes
	tya	; No, NumReps = NumDups
_GCMC4400:
	sta.b _CDNumReps
	tya	; NumDups -= NumReps
	sec
	sbc.b _CDNumReps
	sta.b _CDNumDups
	inx
	jmp.w _GCMC9000
_GCMC4600:
	sta.b _CDNumReps
	inx
	bra _GCMC9000
;
	; mode 'a'
_GCMC5000:
	cmp.b #$F8	; >>> REPEAT 1:8 <<<
	bcs _GCMC6000
	rep #$20		; mode 'A!'
	and.w #$0007
	ldy.w #2	; In Repeat Mode
	jmp.w _GCMC4200
;
	; mode 'a'
_GCMC6000:
	cmp.b #$FC	; >>> TRANSPARENT 1:4 <<<
	bcs _GCMC7000
	rep #$20		; mode 'A!'
	and.w #$0003
	ldy.w #3	; In Transparent Mode
	jmp.w _GCMC4200
;
	; mode 'a'
_GCMC7000:
	and.b #$03	; .A = #Duplicates
	xba
	lda.w _CharData+1,x
	rep #$20		; mode 'A!'
	clc
	adc.w #34
	inx
	inx
_GCMC7200:
	sta.b _CDNumReps
	ldy.b _CDNumDups
	bmi _GCMC7600
	cmp.b _CDNumDups	; NumReps < NumDups?
	bcc _GCMC7400	; Yes
	tya	; No, NumReps = NumDups
_GCMC7400:
	sta.b _CDNumReps
	tya	; NumDups -= NumReps
	sec
	sbc.b _CDNumReps
	sta.b _CDNumDups
_GCMC7600:
	ldy.b _CDSP	; Get _CD Stack Pointer
	lda.b _CDNumDups
	sta.w _CDStack-2,y	; Save Number of Duplicates Remaining
	txa
	inc a
	inc a
	sta.w _CDStack-4,y	; Save Offset into CharData
	tya
	sec
	sbc.w #4
	if !DEBUG != 0
	bpl ._0
	%HALT($10)
._0:
	endif
	sta.b _CDSP
	lda.b _CDNumReps	; NumDups = NumReps
	sta.b _CDNumDups
	lda.w _CharData,x	; Get Offset for Duplicated Characters
	tax
	jmp.w _GCMC1000
;
	; mode 'A'
_GCMC8000:
	lda.b _CDNumReps	; End of Command causing Mode?
	bne _GCMC9000
	stz.b _CDMode
	jmp.w _GCMC1000
;
_GCMC9000:
	dec.b _CDNumReps	; NumReps--
	lda.b _CDMode
	dec a	; Mode1 (Sequential)
	bne _GCMC10000
	inc.b _CDCharNumNT
	lda.b _CDCharNumNT
	rts
_GCMC10000:
	dec a	; Mode2 (Repeat)
	bne _GCMC11000
	lda.b _CDCharNumNT
	rts
_GCMC11000:
	lda.w #0	; Mode3 (Transparent)
	rts
