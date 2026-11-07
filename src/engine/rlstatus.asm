	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                           STATUS BAR MODULE                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/rlstatus.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/xfer.inc"


	%section(ENGINE)
;
;	* * * * * * *       INITIALIZE STATUS BAR       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitStatusBar:
	rep #$30		; mode 'AX!'
	ldx.w #(MaxOAMs*2/8)-2	; Clear Sprites' OAMAux
	lda.w #0
_RISB100:
	sta.w OAMAA,x
	dex
	dex
	bpl _RISB100
;
	lda.w #%1000000000000000	; 2x2, HMsb=0
	sta.w OAMAA+4
	lda.w #%1010101010101010	; 2x2, HMsb=0
	sta.w OAMAA+6
;
	ldx.w #((3+8+(StatFaceCharX*StatFaceCharY)+3+3+3)*4)-2	; Initialize Fixed OAMs
_RISB200:
	lda.l _RLStatOAMs,x
	sta.w OAMA+(0*4),x
	dex
	dex
	bpl _RISB200
;
	sep #$20		; mode 'a!'
	ldx.w #lo16(StatusBarXFer)	; Transfer StatusBar DataBlock
	lda.b #bank(StatusBarXFer)
	jsl.l XFer
;
;	* * * * * * *       INITIALIZE STATUS BAR NUMBERS       * * * * * * *
;
	sep #$20		; mode 'a!'
	lda.b #%00000001	; A->B, Abs., Auto Inc,2-Add-WriteLH
	sta.w DMA0INC
	lda.b #lo16(VMDATAL)	; VMDATA
	sta.w DMA0DEST
	lda.b #bank(DeCompBuffer)
	sta.w DMA0A1B
	rep #$20		; mode 'A!'
	lda.w #10-1	; 10 Digits to Transfer
	sta.b Temp
	lda.w #lo16(DeCompBuffer)
	ldy.w #vmNUMDEF
_RISB400:
	sta.w DMA0A1L	; First Line
	sty.w VMADDL
	ldx.w #(StatNumCharX*32)
	stx.w DMA0NUML
	ldx.w #(0<<8)+1
	stx.w MDMAEN
;
	clc	; Second Line
	adc.w #(StatNumsX*StatNumCharX*32)
	sta.w DMA0A1L
	pha
	tya
	xba	; Add $100
	inc a
	xba
	sta.w VMADDL
	ldx.w #(StatNumCharX*32)
	stx.w DMA0NUML
	ldx.w #(0<<8)+1
	stx.w MDMAEN
;
	tya	; Next VRAM Address
	clc
	adc.w #$120
	and.w #$7EF0
	tay
	pla
	sec	; Next SOURCE Data
	sbc.w #((StatNumsX-1)*StatNumCharX)*32
	dec.b Temp	; Next Digit
	bpl _RISB400
	rtl

;
;	* * * * * * *       TABLE OF SPRITE OAMS       * * * * * * *
;
_RLStatOAMs:
	dw ((StatKeyBPosY+0)<<8)+(StatKeyBPosX+0),(%00111100<<8)+lo16(((vmKEYSDEF&$1FFF)>>4)+(0*1))
	dw ((StatKeyYPosY+0)<<8)+(StatKeyYPosX+0),(%00111110<<8)+lo16(((vmKEYSDEF&$1FFF)>>4)+(1*1))
	dw ((StatKeyRPosY+0)<<8)+(StatKeyRPosX+0),(%00111100<<8)+lo16(((vmKEYSDEF&$1FFF)>>4)+(2*1))
;
	dw ((StatArmsPosY+0)<<8)+(StatArmsPosX+0),(%00110010<<8)+lo16(((vmARMSDEF&$1FFF)>>4)+(0*1))
	dw ((StatArmsPosY+0)<<8)+(StatArmsPosX+8),(%00110010<<8)+lo16(((vmARMSDEF&$1FFF)>>4)+(1*1))
	dw ((StatArmsPosY+0)<<8)+(StatArmsPosX+16),(%00110010<<8)+lo16(((vmARMSDEF&$1FFF)>>4)+(2*1))
	dw ((StatArmsPosY+0)<<8)+(StatArmsPosX+24),(%00110010<<8)+lo16(((vmARMSDEF&$1FFF)>>4)+(3*1))
	dw ((StatArmsPosY+8)<<8)+(StatArmsPosX+0),(%00110010<<8)+lo16(((vmARMSDEF&$1FFF)>>4)+(4*1))
	dw ((StatArmsPosY+8)<<8)+(StatArmsPosX+8),(%00110010<<8)+lo16(((vmARMSDEF&$1FFF)>>4)+(5*1))
	dw ((StatArmsPosY+8)<<8)+(StatArmsPosX+16),(%00110010<<8)+lo16(((vmARMSDEF&$1FFF)>>4)+(6*1))
	dw ((StatArmsPosY+8)<<8)+(StatArmsPosX+24),(%00110010<<8)+lo16(((vmARMSDEF&$1FFF)>>4)+(7*1))
;
	dw ((StatFacePosY+0)<<8)+(StatFacePosX+0),(%00110000<<8)+lo16(((vmFACEDEF&$1FFF)>>4)+(0*1))
	dw ((StatFacePosY+0)<<8)+(StatFacePosX+8),(%00110000<<8)+lo16(((vmFACEDEF&$1FFF)>>4)+(1*1))
	dw ((StatFacePosY+0)<<8)+(StatFacePosX+16),(%00110000<<8)+lo16(((vmFACEDEF&$1FFF)>>4)+(2*1))
	dw ((StatFacePosY+8)<<8)+(StatFacePosX+0),(%00110000<<8)+lo16(((vmFACEDEF&$1FFF)>>4)+(3*1))
	dw ((StatFacePosY+8)<<8)+(StatFacePosX+8),(%00110000<<8)+lo16(((vmFACEDEF&$1FFF)>>4)+(4*1))
	dw ((StatFacePosY+8)<<8)+(StatFacePosX+16),(%00110000<<8)+lo16(((vmFACEDEF&$1FFF)>>4)+(5*1))
	dw ((StatFacePosY+16)<<8)+(StatFacePosX+0),(%00110000<<8)+lo16(((vmFACEDEF&$1FFF)>>4)+(6*1))
	dw ((StatFacePosY+16)<<8)+(StatFacePosX+8),(%00110000<<8)+lo16(((vmFACEDEF&$1FFF)>>4)+(7*1))
	dw ((StatFacePosY+16)<<8)+(StatFacePosX+16),(%00110000<<8)+lo16(((vmFACEDEF&$1FFF)>>4)+(8*1))
	dw ((StatFacePosY+24)<<8)+(StatFacePosX+0),(%00110000<<8)+lo16(((vmFACEDEF&$1FFF)>>4)+(9*1))
	dw ((StatFacePosY+24)<<8)+(StatFacePosX+8),(%00110000<<8)+lo16(((vmFACEDEF&$1FFF)>>4)+(10*1))
	dw ((StatFacePosY+24)<<8)+(StatFacePosX+16),(%00110000<<8)+lo16(((vmFACEDEF&$1FFF)>>4)+(11*1))
;
	dw ((StatAmmoPosY+0)<<8)+(StatAmmoPosX+0),(%00111100<<8)
	dw ((StatAmmoPosY+0)<<8)+(StatAmmoPosX+15),(%00111100<<8)
	dw ((StatAmmoPosY+0)<<8)+(StatAmmoPosX+31),(%00111100<<8)
;
	dw ((StatHealthPosY+0)<<8)+(StatHealthPosX+0),(%00111100<<8)
	dw ((StatHealthPosY+0)<<8)+(StatHealthPosX+15),(%00111100<<8)
	dw ((StatHealthPosY+0)<<8)+(StatHealthPosX+31),(%00111100<<8)
;
	dw ((StatArmorPosY+0)<<8)+(StatArmorPosX+0),(%00111100<<8)
	dw ((StatArmorPosY+0)<<8)+(StatArmorPosX+15),(%00111100<<8)
	dw ((StatArmorPosY+0)<<8)+(StatArmorPosX+31),(%00111100<<8)


;
;	* * * * * * *       TRANSFER LISTS       * * * * * * *
;
	; mode '@A@X'
StatusBarXFer:
	dw xftVRAM16	; Transfer StatusBar Def
	dd RLStatusBarDef
	dd vmSTATDEF
	dw 0,0,0
;
	dw xftVRAMF16+xftRAW	; Transfer Blank Keys/Character Def
	dd StatusBarXFer0
	dd vmKEYSDEF
	dw (32*4)	; Fill 128 Bytes (4 Characters)
StatusBarXFer0:
	dw 0,0
;
	dw xftRAM	; Transfer StatNum Def
	dd RLStatNumDef
	dd DeCompBuffer
	dw 0,0,0
;
	dw xftEND



	%section(ENGINE_RAMCODE)
;
;	* * * * * * *       UPDATE STATUS BAR       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLUpdateStatusBar:
;
;	>>>   AMMO   <<<
;
	sep #$20
	rep #$10		; mode 'aX!'
	ldx.w PlayerAmmo+!RLSNESGSUXVarsO	; Get Player's Ammo Digits
	stx.w WRDIVL
	lda.b #10
	sta.w WRDIVB
	lda.b #StatAmmoPosY	; Normal Ammo?
	txy
	bpl _RLUSB200
	lda.b #MaxViewScanLines	; No, Fist/ChainSaw!
_RLUSB200:
	sta.w OAMA+(23*4)+oamsY
	sta.w OAMA+(24*4)+oamsY
	sta.w OAMA+(25*4)+oamsY
	ldx.w _RDMPYL
	lda.l _RLStatNumOAMs,x
	sta.w OAMA+(25*4)+oamsChr
	ldx.w _RDDIVL
	stx.w WRDIVL
	lda.b #10
	sta.w WRDIVB
	tay
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ldx.w _RDDIVL
	lda.l _RLStatNumOAMs,x
	sta.w OAMA+(23*4)+oamsChr
	ldx.w _RDMPYL
	lda.l _RLStatNumOAMs,x
	sta.w OAMA+(24*4)+oamsChr
;
;	>>>   HEALTH   <<<
;
	ldx.w PlayerHealth+!RLSNESGSUXVarsO	; Get Player's Health Digits
	stx.w WRDIVL
	tya
	sta.w WRDIVB
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ldx.w _RDMPYL
	lda.l _RLStatNumOAMs,x
	sta.w OAMA+(28*4)+oamsChr
	ldx.w _RDDIVL
	stx.w WRDIVL
	tya
	sta.w WRDIVB
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ldx.w _RDDIVL
	lda.l _RLStatNumOAMs,x
	sta.w OAMA+(26*4)+oamsChr
	ldx.w _RDMPYL
	lda.l _RLStatNumOAMs,x
	sta.w OAMA+(27*4)+oamsChr
;
;	>>>   ARMOR   <<<
;
	ldx.w PlayerArmor+!RLSNESGSUXVarsO	; Get Player's Armor Digits
	stx.w WRDIVL
	tya
	sta.w WRDIVB
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ldx.w _RDMPYL
	lda.l _RLStatNumOAMs,x
	sta.w OAMA+(31*4)+oamsChr
	ldx.w _RDDIVL
	stx.w WRDIVL
	tya
	sta.w WRDIVB
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ldx.w _RDDIVL
	lda.l _RLStatNumOAMs,x
	sta.w OAMA+(29*4)+oamsChr
	ldx.w _RDMPYL
	lda.l _RLStatNumOAMs,x
	sta.w OAMA+(30*4)+oamsChr
;
	lda.b #rlfStatus	; Status Built
	trb.b RLFlags
	rts
;
;	* * * * * * *       TABLE OF SPRITE NUMBERS FOR STATUS DIGITS       * * * * * * *
;
_RLStatNumOAMs:
	db lo16(((((vmNUMDEF&$1FFF)>>4)+(0*2))+$10)&$1EE)
	db lo16(((((vmNUMDEF&$1FFF)>>4)+(1*2))+$10)&$1EE)
	db lo16(((((vmNUMDEF&$1FFF)>>4)+(2*2))+$10)&$1EE)
	db lo16(((((vmNUMDEF&$1FFF)>>4)+(3*2))+$10)&$1EE)
	db lo16(((((vmNUMDEF&$1FFF)>>4)+(4*2))+$10)&$1EE)
	db lo16(((((vmNUMDEF&$1FFF)>>4)+(5*2))+$10)&$1EE)
	db lo16(((((vmNUMDEF&$1FFF)>>4)+(6*2))+$10)&$1EE)
	db lo16(((((vmNUMDEF&$1FFF)>>4)+(7*2))+$10)&$1EE)
	db lo16(((((vmNUMDEF&$1FFF)>>4)+(8*2))+$10)&$1EE)
	db lo16(((((vmNUMDEF&$1FFF)>>4)+(9*2))+$10)&$1EE)



	%section(ENGINE_GSUCODE)
	arch superfx

;
;	* * * * * * *       ADD TO HEALTH SCORE       * * * * * * *
;
;	Add VALUE to HEALTH SCORE
;
;	R4	= Health to Add
;	R11     = Return Address
;
_RLAddHealth:
	if useMULTIPLAYER == 0
	lm r0,(PlayerObject+rloHealth&$FFFF)	; Get Player's Health
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloHealth	; Get Player's Health
	lms r1,(MPPlayerObject&$FFFF)
;	with	r0
	add r1
;	to	r0
	ldw (r0)
	endif
;	with	r0
	add r4
	iwt r1,#(200+1)
;	from	r0
	cmp r1
	blt _RAHH200
	moves r0,r1
_RAHH200:
	bra _RLCalcFaceAnim	; ReCalculate Face Animation
;	from	r0
	sbk

;
;	* * * * * * *       SUBTRACT FROM HEALTH SCORE       * * * * * * *
;
;	Subtract VALUE from HEALTH SCORE
;
;	R4	= Health to Subtract
;	R11     = Return Address
;
_RLSubHealth:
	if useMULTIPLAYER == 0
	lm r0,(PlayerObject+rloHealth&$FFFF)	; Get Player's Health
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloHealth	; Get Player's Health
	lms r1,(MPPlayerObject&$FFFF)
;	with	r0
	add r1
;	to	r0
	ldw (r0)
	endif
;	with	r0
	sub r4
	bpl _RSHH200
	nop
;	with	r0
	sub r0
_RSHH200:
;	from	r0
	sbk
;
;	* * * * * * *       DETERMINE FACE ANIMATION       * * * * * * *
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE!!!
;
_RLCalcFaceAnim:
;
;	>>>   FACEANIM FOR INVULNERABLE   <<<
;
	iwt r4,#lo16(_FacesInvulnerableList)	; Use Invulnerable Animation
	lms r0,(InvulnerableCount&$FFFF)	; Does Player have Invulnerable?
	dec r0
	bpl _RCFA800	; Yes!
	nop
;
;	>>>   FACEANIM BASED ON HEALTH   <<<
;
	if useMULTIPLAYER == 0
	lm r0,(PlayerObject+rloHealth&$FFFF)	; Get Player's Health
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloHealth	; Get Player's Health
	lms r1,(MPPlayerObject&$FFFF)
;	with	r0
	add r1
;	to	r0
	ldw (r0)
	endif
;	with	r0				; /16
	lsr
;	with	r0
	lsr
;	with	r0
	lsr
;	with	r0
	lsr
	ibt r1,#5
;	from	r0				; Health >= 80?
	cmp r1
	iwt r4,#lo16(_FacesNormalList)	; Base of FacesNormalList
	bge _RCFA200
	from r1	; Get FaceList Offset (0-4)
;	to	r0
	sub r0
	ibt r1,#(_FacesNormalList0-_FacesNormalList)
;	with	r0
	umult r1
	with r4
	add r0
_RCFA200:
;
;	>>>   CHECK IF PLAYER IS NOW DEAD   <<<
;
	if useMULTIPLAYER == 0
	lm r0,(PlayerObject+rloHealth&$FFFF)	; Get Player's Health
	endif
	if useMULTIPLAYER != 0
	ibt r0,#rloHealth	; Get Player's Health
	lms r1,(MPPlayerObject&$FFFF)
;	with	r0
	add r1
;	to	r0
	ldw (r0)
	endif
	moves r0,r0
	bne _RCFA300
;	with	r0				; Player is NOT Dead
	sub r0
	inc r0	; Player IS Dead!
;
;	>>>   FACEANIM FOR DEAD PLAYER   <<<
;
	iwt r4,#lo16(_FacesDeadList)
_RCFA300:
	sms (PlayerDead&$FFFF),r0
;
_RCFA800:
	lms r1,(PlayerFaceAnim0&$FFFF)	; Already using correct FaceAnim?
	from r4	; @CMP@
;	to	r0
	sub r1
	beq _RCFA900	; Yes, don't restart it!
	nop
	sms (PlayerFaceAnim0&$FFFF),r4	; Update FaceAnims
	sms (PlayerFaceAnim&$FFFF),r4
	ibt r0,#1	; Force FaceAnim Update Immediately!
	sms (PlayerFaceCount&$FFFF),r0
_RCFA900:
	jmp r11	; Return to Caller
	nop


;
;	* * * * * * *       ANIMATE PLAYER FACE       * * * * * * *
;
_RLAnimFace:
	lms r1,(FPSCount+RLGSUSNESXVarsO&$FFFF)
	lms r0,(PlayerFaceCount&$FFFF)	; #Ticks for Current Face
;	with	r0
	sub r1
	dec r0
	bmi _RAF400	; Change Face
	inc r0	; Current Face Still Valid
_RAF100:
	jmp r11
	sbk
_RAF400:
	ibt r0,#bank(_FacesGetItemList)	; Base Address of FaceAnims
	romb
	lms r14,(PlayerFaceAnim&$FFFF)	; Pointer to FaceAnim
	getb	; Get next FaceNumber
	inc r14
;	with	r0
	sex
	bpl _RAF500	; Not done yet
	nop
	lms r14,(PlayerFaceAnim0&$FFFF)	; Done -- Return to "Normal"
	sms (PlayerFaceAnim&$FFFF),r14
	getb	; Get First Face
	inc r14
_RAF500:
	sms (PlayerFace&$FFFF),r0	; Save new Face
	getb	; Get #Ticks for Face
	sms (PlayerFaceCount&$FFFF),r0	; Save new Count
	inc r14
	sms (PlayerFaceAnim&$FFFF),r14	; Save Updated AnimPointer
_RAF800:
	jmp r11	; Return to Caller
	nop


;
;	* * * * * * *       LIST OF ANIMATION FOR INVULNERABLE       * * * * * * *
;
_FacesInvulnerableList:
	db (1*2),10,-1	; Invulnerable
;
;	* * * * * * *       LIST OF ANIMATION FOR GETTING ITEM       * * * * * * *
;
_FacesGetItemList:
	db (7*2),10,-1	; Get at 81%-100%
	db (8*2),10,-1	; Get at 61%-80%
	db (9*2),10,-1	; Get at 41%-60%
	db (10*2),10,-1	; Get at 21%-40%
	db (11*2),10,-1	; Get at  1%-20%
;
;	* * * * * * *       LIST OF ANIMATION FOR GETTING "GOOD" ITEM       * * * * * * *
;
_FacesGetItem2List:
	db (2*2),10,-1	; Get at 81%-100%
	db (3*2),10,-1	; Get at 61%-80%
	db (4*2),10,-1	; Get at 41%-60%
	db (5*2),10,-1	; Get at 21%-40%
	db (6*2),10,-1	; Get at  1%-20%
;
;	* * * * * * *       LIST OF ANIMATION FOR GETTING HIT       * * * * * * *
;
_FacesHitList:
	db (12*2),10,-1	; Hit at 81%-100%
	db (13*2),10,-1	; Hit at 61%-80%
	db (14*2),10,-1	; Hit at 41%-60%
	db (15*2),10,-1	; Hit at 21%-40%
	db (16*2),10,-1	; Hit at  1%-20%
;
;	* * * * * * *       LIST OF ANIMATION FOR NORMAL       * * * * * * *
;
_FacesNormalList:
	db (18*2),15,(17*2),20,(18*2),20,(19*2),20,(18*2),20,(17*2),25,(18*2),9,(17*2),20
	db (18*2),20,(19*2),15,(18*2),20,(17*2),15,(18*2),25,(19*2),20,(18*2),9,(19*2),25,-1
_FacesNormalList0:
	db (21*2),15,(20*2),20,(21*2),20,(22*2),20,(21*2),20,(20*2),25,(21*2),9,(20*2),20
	db (21*2),20,(22*2),15,(21*2),20,(20*2),15,(21*2),25,(22*2),20,(21*2),9,(22*2),25,-1
;
	db (24*2),15,(23*2),20,(24*2),20,(25*2),20,(24*2),20,(23*2),25,(24*2),9,(23*2),20
	db (24*2),20,(25*2),15,(24*2),20,(23*2),15,(24*2),25,(25*2),20,(24*2),9,(25*2),25,-1
;
	db (27*2),15,(26*2),20,(27*2),20,(28*2),20,(27*2),20,(26*2),25,(27*2),9,(26*2),20
	db (27*2),20,(28*2),15,(27*2),20,(26*2),15,(27*2),25,(28*2),20,(27*2),9,(28*2),25,-1
;
	db (30*2),15,(29*2),20,(30*2),20,(31*2),20,(30*2),20,(29*2),25,(30*2),9,(29*2),20
	db (30*2),20,(31*2),15,(30*2),20,(29*2),15,(30*2),25,(31*2),20,(30*2),9,(31*2),25,-1
;
	db (30*2),15,(29*2),20,(30*2),20,(31*2),20,(30*2),20,(29*2),25,(30*2),9,(29*2),20
	db (30*2),20,(31*2),15,(30*2),20,(29*2),15,(30*2),25,(31*2),20,(30*2),9,(31*2),25,-1
_FacesDeadList:
	db (0*2),1,-1	; Dead


;
;	* * * * * * *       STATUS BAR DATA       * * * * * * *
;
	%section(RL_STATUSBAR_DATA)
RLStatusBarDef:
	incbin "data/RLDATA/COMP/Status.def0"


;
;	* * * * * * *       STATUS BAR NUMBERS DATA       * * * * * * *
;
	%section(RL_STATUSNUM_DATA)
RLStatNumDef:
	incbin "data/RLDATA/COMP/StatNum.def0"

;
;	* * * * * * *       STATUS BAR FACES DATA       * * * * * * *
;
	%section(RL_STATUSFACES_DATA)
RLStatFacesDef:
	incbin "data/RLDATA/COMP/StatFaces.def0"

;
;	* * * * * * *       STATUS BAR KEYS DATA       * * * * * * *
;
	%section(RL_STATUSKEYS_DATA)
RLStatKeysDef:
	incbin "data/RLDATA/COMP/StatKeys.def0"

;
;	* * * * * * *       STATUS BAR ARMS DATA       * * * * * * *
;
	%section(RL_STATUSARMS_DATA)
RLStatArmsDef:
	incbin "data/RLDATA/COMP/StatArms.def0"
