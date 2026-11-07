	arch 65816
;**********************************************************************
;*                                                                    *
;*                  P R O J E C T :   REALITY_ENGINE                  *
;*                                                                    *
;*                     ENEMIES HANDLING MODULE 1                      *
;*                                                                    *
;*                        ENEMIES TARGETTING 1                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"
	incsrc "src/include/rlobjects.inc"
	incsrc "src/include/rlenemies.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


	!rNULL = r3	; $0000
	!rrloSector = r4	; Offset to rloSector
	!rrloHealth = r5	; Offset to rloHealth
	!rrloTObj = r6	; Offset to rloTObj
	!rSINGLEBITARRAY = r7	; Base of SingleBitArray
	!rREJECT = r8	; Base of REJECT
	!rNUMSECTORS = r9	; Number of SECTORS
;
	!rEnemyTargets = r10	; Pointer to Enemy Targetting List
	!rObjTObj = r11	; Pointer to RLObject.TObj
	!rObj = r12	; Pointer to RLObject
	!rTObj = r13	; Pointer to Target RLObject


;
;	* * * * * * *       ENEMIES TARGETTING       * * * * * * *
;
	%align_pad(11, 16, (_RLET10000-_RLEnemiesTargetAlign)&$0F)	; align 16,(_RLET10000-_RLEnemiesTargetAlign)&$0f
;
;	>>>   FINISHED ENEMIES TARGETTING   <<<
;
_RLET10000:
	iwt r0,#lo16(_RLEnemiesTarget2)	; HANDLE ENEMY TARGETTING 2
	ibt r8,#bank(_RLEnemiesTarget2)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop

;
;	>>>   START ENEMIES TARGETTING   <<<
;
_RLEnemiesTarget:
	ibt r0,#lo16(EMBSP+2)	; Bank of EM Data
	assert (lo16(EMBSP+2))&$FFFF < $80 || (lo16(EMBSP+2))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	ldb (r0)
	romb
	iwt !rEnemyTargets,#lo16(_RLEnemyTargets-2)	; Pointer to Enemy TargetList
	lms !rREJECT,(EMREJECT&$FFFF)	; Get Base of REJECT
	lms !rNUMSECTORS,(EMNUMSECTORS&$FFFF)	; Get #SECTORS
	if !RLREJECTPVS != 0
	with !rNUMSECTORS		; FX3 visibility rows: (#SECTORS+7)>>3 bytes
	%add_i(7)
	with !rNUMSECTORS
	lsr
	with !rNUMSECTORS
	lsr
	with !rNUMSECTORS
	lsr
	endif
	iwt !rSINGLEBITARRAY,#lo16(SingleBitArray)	; Get Base of SINGLEBITARRAY
	ibt !rrloTObj,#rloTObj	; Offset to TObj
	ibt !rrloHealth,#rloHealth	; Offset to Target's Health
	ibt !rrloSector,#rloSector	; Offset to Target's Sector
	ibt !rNULL,#0	; $0000

	%CACHEB(_RLEnemiesTarget)
_RLEnemiesTargetAlign:
;
;	>>>   PROCESS NEXT ENEMY   <<<
;
_RLET2000:
	inc !rEnemyTargets	; Move to Next Enemy
	inc !rEnemyTargets
	to !rObj	; Get Next Enemy
	ldw (!rEnemyTargets)
	from !rObj	; Get TargetObject
	to !rObjTObj
	add !rrloTObj
	bmi _RLET10000	; No More Enemies!
	inc !rEnemyTargets	; Move to Next Enemy
;
;	>>>   ACQUIRE CURRENT TARGET / ACQUIRE PLAYER   <<<
;
	to !rTObj	; Get Target RLObject
	ldw (!rObjTObj)
	dec !rTObj	; Any Target?
	bmi _RLET2400	; No
;
;	>>>   ACQUIRE CURRENT TARGET   <<<
;
	from !rNULL	; Assume Sight Blocked
	sbk
	bra _RLET2500
	inc !rTObj
;
;	>>>   ACQUIRE PLAYER   <<<
;
_RLET2400:
	if useMULTIPLAYER == 0
	iwt !rTObj,#lo16(PlayerObject)	; No Target -- Acquire the Player!
	endif
	if useMULTIPLAYER != 0
	lms !rTObj,(MPEnemyTarget&$FFFF)	; No Target -- Acquire the Player!
	endif
;
;	>>>   IS LINE-OF-SIGHT POSSIBLE?   <<<
;
_RLET2500:
	from !rObj	; Get Enemy Sector
;	to	r0
	add !rrloSector
;	to	r0
	ldb (r0)
	from !rrloSector	; Get Target Sector
	to r1
	add !rTObj
	to r1
	ldb (r1)
	if !RLREJECTPVS == 0
;	with	r0				; (EnemySector*NumSectors)+TargetSector
	umult !rNUMSECTORS
	with r1
	add r0
	from r1	; Get Byte Offset
;	to	r0
	lsr
;	with	r0
	lsr
;	with	r0
	lsr
;	from	r0				; Get REJECT Byte
	to r2
	add !rREJECT
	else
	umult !rNUMSECTORS		; EnemySector*RowBytes
	to r2
	add !rREJECT
	from r1				; + (TargetSector>>3)
	lsr
	lsr
	lsr
	with r2
	add r0
	endif
	with r1
	and #7
	from !rSINGLEBITARRAY
;	to	r0
	add r1
	to r1
	ldb (r0)
	ibt r0,#lo16(EMBSP+3)	; (this port) REJECT in the GamePak ROM?
	ldb (r0)
	moves r0,r0
	beq _RLET2600	; No
	nop
	romb	; Yes: its bank
	move r14,r2
	ibt r0,#lo16(EMBSP+2)	; (then back to the EM bank)
	ldb (r0)
	to r2
	getb
	romb
	bra _RLET2700
	from r2
_RLET2600:
	ibt r0,#1			; REJECT is in the level RAM image (GSU RAM $71)
	ramb
	ldb (r2)
	from !rNULL			; Back to GSU RAM $70
	ramb
_RLET2700:
;	with	r0				; CAN ENEMY SEE TARGET?
	and r1
	if !RLREJECTPVS == 0
	bne _RLET3000	; NO!
	else
	beq _RLET3000	; NO! (visibility bit clear)
	endif
	inc !rEnemyTargets	; Move to Next Enemy
;
;	>>>   TARGET STILL ALIVE?   <<<
;
	from !rrloHealth	; Get Target's Health
;	to	r0
	add !rTObj
;	to	r0
	ldw (r0)
	dec r0	; Any Health?
	bmi _RLET3000	; NO!
;
;	>>>   SAVE TARGET   <<<
;
	from !rTObj	; YES!
	bra _RLET2000+2
	stw (!rObjTObj)

;
;	>>>   VERY FAR AWAY FROM TARGET?   <<<
;
_RLET3000:
	ibt r0,#(rloX+2)	; Get |DeltaX|
;	from	r0
	to r1
	add !rTObj
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
	to r1
	ldw (r1)
;	with	r0
	sub r1
	bpl _RLET3200
	nop
;	with	r0
	not
	inc r0
_RLET3200:
;	with	r0				; >= 1024 Units?
	hib
;	with	r0
	sub #4
	bpl _RLET3800	; YES!  TOO FAR TO SEE -- SLEEP!
	nop
	ibt r0,#(rloY+2)	; Get |DeltaY|
;	from	r0
	to r1
	add !rTObj
;	with	r0
	add !rObj
;	to	r0
	ldw (r0)
	to r1
	ldw (r1)
;	with	r0
	sub r1
	bpl _RLET3400
	nop
;	with	r0
	not
	inc r0
_RLET3400:
;	with	r0				; >= 1024 Units?
	hib
;	with	r0
	sub #4
	bmi _RLET4000-1	; No, Keep Moving!
;
;	>>>   TARGET VERY FAR AWAY -- SLEEP   <<<
;
_RLET3800:
	ibt r0,#bank(_MObjData)	; MObjData Bank
	romb
	ibt r1,#rloMData	; Get MObjData
	with r1
	add !rObj
;	to	r0
	ldw (r1)
;	from	r0				; Move to SleepState
	to r14
	%add_i(rlmodSleepS)
	dec r1	; Move to State
	dec r1
	getb	; Get SleepState
	inc r14
	getbh
;	from	r0
	stw (r1)
	ibt r0,#lo16(EMBSP+2)	; Bank of EM Data
	assert (lo16(EMBSP+2))&$FFFF < $80 || (lo16(EMBSP+2))&$FFFF >= $FF80, "ibt: value does not fit a signed byte"
	ldb (r0)
	romb
_RLET4000:
	iwt r15,#lo16(_RLET2000)+2
	nop

	%CACHEE(_RLEnemiesTarget)
