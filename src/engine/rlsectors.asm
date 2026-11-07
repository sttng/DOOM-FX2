	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                         ENGINE SECTOR MODULE                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"


	; public _RLDoSectors


	%section(LEVEL)
;
;	* * * * * * *       INITIALIZE SECTORS/SECTORDATA       * * * * * * *
;
	; dbr ?
	; dpr 0
_RIS900:
	rts
_RLInitSectors:
	rep #$30		; mode 'AX!'
	lda.l EMSECTORS+1	; Get Pointer to Sectors
	sta.b Temp4+1
	lda.l EMSECTORS
	sta.b Temp4
	lda.w #lo16(_RLSectorData)	; Pointer to SectorData
	sta.b Temp3
	stz.b Temp3+2
;
;	>>>   COUNT LEVEL SECRET TOTALS   <<<
;
	lda.w #0	; Number of SECRETS
	sta.l EMTOTALSECRETS
	sta.l NumSecrets
;
;	>>>   INITIALIZE NEXT SECTOR   <<<
;
_RIS200:
	lda.b [Temp4]	; End marker ($524C)?
	cmp.w #$524C
	beq _RIS900	; No more Sectors!
	ldx.b Temp3
	sep #$20		; mode 'a!'
;
;	>>>   CALCULATE SECTORDATA FLAGS   <<<
;
	ldy.w #rlsCeilingTexture	; Get CeilingTexture
	lda.b [Temp4],y
;	cmp	#$ff					; SKY?
	inc a
	bne _RIS320	; No!
	lda.b #rlsdfCeilingSky	; Yes!
	jmp.w _RIS340
_RIS320:
	lda.b #0
_RIS340:
	sta.l RAM7AStart+rlsdFlags,x
;
;	>>>   COPY SECTOR PARAMETERS INTO SECTORDATA   <<<
;
	ldy.w #rlsLightLevel	; Get Light Level
	lda.b [Temp4],y
	sta.l RAM7AStart+rlsdLightLevel,x
	rep #$20		; mode 'A!'
	ldy.w #rlsCeilingHeight	; Get Ceiling Height
	lda.b [Temp4],y
	sta.l RAM7AStart+rlsdCeilingHeight,x
	ldy.w #rlsFloorHeight	; Get Floor Height
	lda.b [Temp4],y
	sta.l RAM7AStart+rlsdFloorHeight,x
	lda.w #1	; Default Counter
	sta.l RAM7AStart+rlsdData,x
	ldy.w #rlsFloorTexture	; Get Floor/Ceiling Texture
	lda.b [Temp4],y
	sta.l RAM7AStart+rlsdFloorTexture,x
	lda.w #0	; SectorData.RLEngineCount=0
	sta.l RAM7AStart+rlsdRLCount,x
;	lda	#0					; No Objects in this Sector Yet!
	sta.l RAM7AStart+rlsdObjects,x
;
;	>>>   ADD RLTASK FOR SPECIAL SECTORS   <<<
;
	lda.b [Temp4]	; Get SectorType
	and.w #$00FF
	beq _RIS800	; Normal Sector, NO TASKCODE!
;
	cmp.w #(9*4)	; SECRET?
	bne _RIS520
	pha
	lda.l EMTOTALSECRETS	; Yes, Total Secrets++
	inc a
	sta.l EMTOTALSECRETS
	pla
_RIS520:
;
	cmp.w #(5*4)	; RANDOM Lights?
	bcs _RIS700	; No
	pha
	txa	; Yes, RANDOM Counter
	and.w #$007F
	sta.l RAM7AStart+rlsdData,x
	pla
;
_RIS700:
	lsr a
	tax
	lda.l _RLSectorTaskCode-2,x	; Get Pointer to TaskCode
	beq _RIS800	; NO TASKCODE!
	tay
	ldx.b Temp3+2	; Sector#
	jsl.l __RLAddTaskSNES	; Add Sector Task
;
_RIS800:
	lda.b Temp4	; Move to next Sector
	clc
	adc.w #rlsSize
	sta.b Temp4
	lda.b Temp3	; Move to next SectorData
	clc
	adc.w #rlsdSize
	sta.b Temp3
	inc.b Temp3+2
	jmp.w _RIS200


;
;	* * * * * * *       SECTOR TASK CODE JUMP TABLE       * * * * * * *
;
_RLSectorTaskCode:
	dw lo16(_TLightOffRandom-1)	; (01) Light Blinks Off Randomly
	dw lo16(_TLightOnA0-1)	; (02) Light Blinks On Every 0.5 Seconds
	dw lo16(_TLightOnB-1)	; (03) Light Blinks On Every 1.0 Seconds
	dw lo16(_TLightOnA0-1)	; (04) Max.Damage10%/20% + LightBlink 0.5
	dw 0	; (05) Medium Damage 5%/10%
	dw 0	; (06) Normal Sector
	dw 0	; (07) Minimum Damage 2%/5%
	dw lo16(_TLightOsc-1)	; (08) Light Oscillates SYNC
	dw 0	; (09) Secret Sector
	dw 0	; (10) Normal Sector
	dw 0	; (11) Normal Sector
	dw lo16(_TLightOnB-1)	; (12) Light Blinks On Every 1.0 Seconds SYNC
	dw lo16(_TLightOnA0-1)	; (13) Light Blinks On Every 0.5 Seconds SYNC
	dw 0	; (14) Normal Sector
	dw 0	; (15) Normal Sector
	dw 0	; (16) Maximum Damage 10%/20%
	dw lo16(_TLightOffRandom-1)	; (17) Light Flickers Randomly (Ultimate DOOM)



	%section(ENGINE_GSUCODE)
	arch superfx


	!rSectorData0 = r9	; Pointer to SectorData Base
	!rSectorData = r8	; Pointer to SectorData
	!rFPSCount = r7	; FPS Counter
	!rFPSRatio = r5	; FPS Ratio


;
;	* * * * * * *       REALITY_ENGINE HANDLE SECTORS       * * * * * * *
;
_RLDoSectors:
	lms !rFPSCount,(FPSCount+RLGSUSNESXVarsO&$FFFF)	; Get FPSCount
	lms !rFPSRatio,(FPSRatio&$FFFF)	; Get FPSRatio
;
	iwt r0,#lo16(EMSECTORS+2)	; Bank of EM Data
	ldb (r0)
	romb	; Set ROM Bank
;
	if useMULTIPLAYER == 0
	iwt r0,#lo16(PlayerObject+rloSector)	; Get Player's Sector
	endif
	if useMULTIPLAYER != 0
	ibt r1,#rloSector
	lms r0,(MPPlayerObject&$FFFF)
;	with	r0
	add r1
	endif
;
;	to	r0
	ldb (r0)
	lms r1,(EMSECTORS&$FFFF)	; Base of SECTORS
;	from	r0				; SECTORDATA
	to !rSectorData0
	%umult_i(rlsdSize)
;	with	r0				; SECTOR
	%umult_i(rlsSize)
;	from	r0
	to r14
	add r1
	iwt r0,#lo16(_RLSectorData)
	with !rSectorData0
	add r0
	move !rSectorData,!rSectorData0
;
	iwt r1,#lo16(_RLDoSectorCode)	; Base Address of JumpTable
	getb	; Get Sector Type
;	from	r0
	to r13
	add r1
	link #2
	jmp r13	; Call SectorCode
	nop
;
;	>>>   HANDLE MISCELLANEOUS 2   <<<
;
	if usePATCH == 0
	iwt r0,#lo16(_RLMisc2)	; DO MISCELLANEOUS TASKS 2
	endif
	if usePATCH != 0
	lms r0,(PTRLMisc2&$FFFF)	; DO MISCELLANEOUS TASKS 2
	endif
	ibt r8,#bank(_RLMisc2)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop


;
;	* * * * * * *       SECTOR CODE JUMP TABLE       * * * * * * *
;
_RLDoSectorCode:
	iwt r15,#lo16(_RLDSNormal)	; (00) Normal Sector
	nop
	iwt r15,#lo16(_RLDSNormal)	; (01) Light Blinks Off Randomly
	nop
	iwt r15,#lo16(_RLDSNormal)	; (02) Light Blinks On Every 0.5 Seconds
	nop
	iwt r15,#lo16(_RLDSNormal)	; (03) Light Blinks On Every 1.0 Seconds
	nop
	iwt r15,#lo16(_RLDSDamageMax)	; (04) Max.Damage10%/20% + LightBlink 0.5
	nop
	iwt r15,#lo16(_RLDSDamageMed)	; (05) Medium Damage 5%/10%
	nop
	iwt r15,#lo16(_RLDSNormal)	; (06) Normal Sector
	nop
	iwt r15,#lo16(_RLDSDamageMin)	; (07) Minimum Damage 2%/5%
	nop
	iwt r15,#lo16(_RLDSNormal)	; (08) Light Oscillates
	nop
	iwt r15,#lo16(_RLDSSecret)	; (09) Secret Sector
	nop
	iwt r15,#lo16(_RLDSNormal)	; (10) Normal Sector
	nop
	iwt r15,#lo16(_RLDSDamageMaxExit)	; (11) Maximum Damage 10%/20% and EXIT!
	nop
	iwt r15,#lo16(_RLDSNormal)	; (12) Light Blinks On Every 1.0 Seconds
	nop
	iwt r15,#lo16(_RLDSNormal)	; (13) Light Blinks On Every 0.5 Seconds
	nop
	iwt r15,#lo16(_RLDSNormal)	; (14) Normal Sector
	nop
	iwt r15,#lo16(_RLDSNormal)	; (15) Normal Sector
	nop
	iwt r15,#lo16(_RLDSDamageMax)	; (16) Maximum Damage 10%/20%
	nop
	iwt r15,#lo16(_RLDSNormal)	; (17) Light Flickers Randomly (Ultimate DOOM)
	nop


;
;	* * * * * * *       NORMAL SECTOR       * * * * * * *
;
_RLDSNormal:
;	to	r0				; Is Sector now NUKAGE?
	ldb (!rSectorData)
;	with	r0
	%and_i(rlsdfTypeNukage)
	bne _RLDSDamageMed	; Yes, now Causes Damage!
	nop
	jmp r11	; Return to Caller
	nop

;
;	* * * * * * *       DAMAGE AND EXIT       * * * * * * *
;
_RLDSDamageMaxExit:
	move r13,r11	; Save Return Address
	link #3
	bra _RLDSDamageMax
	nop
_RLDSDamageMaxExit2:
;
	if useMULTIPLAYER == 0
	lm r0,(PlayerObject+rloHealth&$FFFF)	; Get Player's Health
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloHealth
	lms r1,(MPPlayerObject&$FFFF)
;	with	r0
	add r1
;	to	r0
	ldw (r0)
	endif
;
	ibt r1,#11	; < 11% Health?
;	with	r0
	sub r1
	bge _RLDSDamageMaxExit9	; No, keep dying!
	nop
	sms (ExitLevel&$FFFF),r1	; 11=GO TO NEXT LEVEL!
;	dec	r1
;	move	(<(PlayerObject+rloHealth)),r1	; Player's Health = 10%
_RLDSDamageMaxExit9:
	jmp r13	; Return to Caller
	nop
;
;	* * * * * * *       DAMAGE TO HEALTH       * * * * * * *
;
_RLDSDamageMax:
	ibt r4,#20	; 20% Health
	bra _RLDSDamage
	nop
_RLDSDamageMed:
	ibt r4,#10	; 10% Health
	bra _RLDSDamage
	nop
_RLDSDamageMin:
	ibt r4,#5	; 5% Health
_RLDSDamage:
	lms r0,(PlayerOnGround&$FFFF)	; Player ON Ground ($FFFF)?
	inc r0
	lms r1,(RadCount&$FFFF)	; Radiation Suit?
;	with	r0
	or r1
	lms r1,(PlayerDead&$FFFF)	; Is Player Dead?
;	with	r0
	or r1
	bne _RLDSDamage800	; Can't be hurt!
	nop
;	to	r0				; Is Sector now NORMAL?
	ldb (!rSectorData)
;	with	r0
	%and_i(rlsdfTypeNormal)
	bne _RLDSDamage800	; Yes, doesn't cause damage!
	nop
	lms r0,(Timer1&$FFFF)	; 1 Second Timer Expired?
	dec r0
	bpl _RLDSDamage800	; No, don't add Damage!
	nop
	iwt r15,#lo16(_RLDamagePlayer)
	nop
_RLDSDamage800:
	jmp r11	; Return to Caller
	nop


;
;	* * * * * * *       SECRET SECTOR       * * * * * * *
;
_RLDSSecret:
;	to	r0				; Get SectorData.Flags
	ldb (!rSectorData0)
;	from	r0				; Secret already found?
	to r1
	%and_i(rlsdfSecret)
	bne _RLDSDamage800	; Yes
	nop
;	with	r0				; NO!  Found it now!
	%or_i(rlsdfSecret)
;	from	r0
	stb (!rSectorData0)
	lms r0,(NumSecrets&$FFFF)	; #Secrets Found++
	inc r0
	jmp r11
;	from	r0
	sbk
