	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                         LEVEL HANDLING MODULE                      *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snesmac.inc"
	incsrc "src/include/music.inc"
	incsrc "src/include/levels.inc"


	%section(LEVEL)

;
;	* * * * * * *       REALITY_ENGINE INITIALIZE LEVEL       * * * * * * *
;
;	.A = Level# to Initialize
;
	; dbr ?
	; dpr 0
	; mode 'AX'
_RLInitLevel:
	jsr.w _RLLoadLevelRAM	; Copy the level's RAM image to GSU RAM $71
	lda.w Level	; Get Level
	if useAUTOMAP != 0
	pha
	endif
	asl a	; Get WORD Index
	tax
;
	phk
	plb
	; dbr (^*)
;
	lda.w EMSONGTable,x	; Get Level Song
	sta.l _MDSong
;
	lda.w EMBSPRTable,x	; Initialize BSPROOT Pointer
	sta.l EMBSPR
;
	lda.w EMAREASTable,x	; Initialize AREAS Pointer
	sta.l EMAREAS
;
	lda.w EMVERTEXESTable,x	; Initialize VERTEXES Pointer
	sta.l EMVERTEXES
;
	lda.w EMNUMVERTEXESTable,x	; Initialize NUMVERTEXES
	sta.l EMNUMVERTEXES
;
	lda.w EMLINESTable,x	; Initialize LINES Pointer
	sta.l EMLINES
;
	lda.w EMNUMLINESTable,x	; Initialize NUMLINES
	sta.l EMNUMLINES
;
	lda.w EMSEGSTable,x	; Initialize SEGS Pointer
	sta.l EMSEGS
;
	lda.w EMSEGS2Table,x	; Initialize SEGS2 Pointer
	sta.l EMSEGS2
;
	lda.w EMREJECTTable,x	; Initialize REJECT Pointer
	sta.l EMREJECT
;
	lda.w EMFACESTable,x	; Initialize FACES Pointer
	sta.l EMFACES
;
	lda.w EMNUMSEGSTable,x	; Initialize NUMSEGS
	sta.l EMNUMSEGS
;
	lda.w EMNUMSECTORSTable,x	; Initialize NUMSECTORS
	sta.l EMNUMSECTORS
;
	lda.w EMOBJECTSTable,x	; Initialize OBJECTS Pointer
	sta.l EMOBJECTS
;
	lda.w EMBLOCKMAPTable,x	; Initialize BLOCKMAP Pointer
	sta.b Temp
	clc
	adc.w #rlkBlockOffsets
	sta.l EMBLOCKMAP
;
	lda.w EMDOORSTable,x	; Initialize DOORS Pointer
	sta.l EMDOORS
;
	lda.w EMFLOORSTable,x	; Initialize FLOORS Pointer
	sta.l EMFLOORS
;
	lda.w EMCEILINGSTable,x	; Initialize CEILINGS Pointer
	sta.l EMCEILINGS
;
	lda.w EMSTAIRSTable,x	; Initialize STAIRS Pointer
	sta.l EMSTAIRS
;
	lda.w EMLIFTSTable,x	; Initialize LIFTS Pointer
	sta.l EMLIFTS
;
	txa	; Get LONG Index
	asl a
	tax
;
	lda.w EMBSPTable,x	; Initialize BSP Pointer
	sta.l EMBSP
	lda.w EMBSPTable+2,x	; Initialize EM Data Bank (EMBSP+2) and REJECT Bank (EMBSP+3)
	sta.l EMBSP+2
;
	lda.w EMSECTORSTable,x	; Initialize SECTORS Pointer
	sta.l EMSECTORS
	lda.w EMSECTORSTable+2,x
	sta.l EMSECTORS+2
	lda.w #$0071	; BLOCKMAP is in the level RAM image (GSU RAM $71)
	sta.b Temp+2
;
;	ldy	#rlkX				; Get BLOCKMAP X Origin
	lda.b [Temp]
	sta.l EMBLOCKMAPORIGIN
	ldy.w #rlkY	; Get BLOCKMAP Y Origin
	lda.b [Temp],y
	sta.l EMBLOCKMAPORIGIN+2
	ldy.w #rlkDim	; Get BLOCKMAP Dimensions
	lda.b [Temp],y
	sta.l EMBLOCKMAPDIM
;
	if useAUTOMAP != 0
;
;	>>>   GENERATE LEVEL NAME FOR AUTOMAP   <<<
;
	plx	; Get Level#
	phx
	ldy.w #0	; Offset within Names
	sep #$20		; mode 'a!'
_RIL400:
	dex	; At Correct LevelName?
	bmi _RIL440	; Yes!
_RIL420:
	iny
	lda.w EMNames,y	; Next Character
	bne _RIL420	; Done?
	iny
	bra _RIL400	; Next LevelName
;
_RIL440:
	ldx.w #0
;
	if useID2 == 0
_RIL450:
	lda.w AMLevelTextPrefix,x	; Copy LevelText Prefix
	beq _RIL460
	sta.l AMLevelText,x
	inx
	bra _RIL450
	endif
;
_RIL460:
	lda.w EMNames,y	; Copy LevelName
	beq _RIL470
	sta.l AMLevelText,x
	iny
	inx	; At Draw Boundary?
	cpx.w #((RLCharX/3)*1)
	beq _RIL465
	cpx.w #((RLCharX/3)*2)+1
	bne _RIL460	; No
_RIL465:
	lda.b #0	; Yes!  Pad Text Strips
	sta.l AMLevelText,x
	inx
	bra _RIL460
;
_RIL470:
	cpx.w #(RLCharX+3)	; Pad with $00s
	beq _RIL490
	sta.l AMLevelText,x
	inx
	bra _RIL470
;
_RIL490:
	sep #$10
	rep #$20		; mode 'Ax!'
	pla	; .A = Level#
	ldy.b #'1'	; Episode 1
_RIL492:
	cmp.w #9	; Found Correct Episode?
	bcc _RIL495	; Yes!
	iny	; Next Episode
;	sec
	sbc.w #9
	bra _RIL492
_RIL495:
	sep #$20		; mode 'a!'
	; MISSION
	clc
	adc.b #'1'
	if useID2 == 0
	sta.l AMLevelText+3
	endif
	if !DEBUGSCR != 0
	sta.l DI1Txt+3
	endif
	if useSKY != 0
	and.b #$0F	; MISSION.B
	xba
	endif
	tya	; EPISODE
	if useID2 == 0
	sta.l AMLevelText+1
	endif
	if !DEBUGSCR != 0
	sta.l DI1Txt+1
	endif
	if useSKY != 0
	if defined("lvlsky0")
	lda.l Level	; (levels.inc !lvlskyN: the sky of each level, 1..4; DOOM II)
	tax
	lda.w EMSKYTable,x
	else
	and.b #$07	; EPISODE.B (this port: 1..4, one sky per Ultimate DOOM episode; original: #$03)
	endif
;
	pha	; ENSURE ACCESS TO HARDWARE FOR MUSICDRIVER
	plb
	; dbr 0
;
	rep #$20		; mode 'A!'
	sta.l EMNUM
	endif
	lda.l SkillLevel	; SKILL LEVEL
	clc
	adc.w #'A'
	sep #$20		; mode 'a!'
	if !DEBUGSCR != 0
	sta.l DI1Txt+4
	endif
	endif
;
	jsr.w _RLInitSectors	; Initialize SECTORS/SECTORDATA
;
	jsr.w _RLInitLineData	; Initialize LINE DATA
;
	jsr.w _RLInitObjects	; Initialize RL OBJECTS
;
	jsr.w _RLInitPlayer	; Initialize PLAYER
;
	jsr.w _RLInitWeapons	; Initialize WEAPONS
	; mode 'AX'
;
	if useSOUND != 0
	lda.w _MDSong	; Load Level Song
	pha	; Save Song# to Play
	jsl.l _LoadSong
;
	ldy.w #1	; "BEST" MODE (Don't Steal Equal Priority!)
	lda.w #DCOM_ALLOCATION_MODE
	jsl.l _SendDriverCommandL
;
	ply	; Get Song# to Play
	lda.w _MusicOn	; Music Enabled?
	beq ._0	; No, don't Start Song!
	lda.w #DCOM_START_SONG
	jsl.l _SendDriverCommandL
._0:
	lda.w #DCOM_FADEIN	; Fade in Music
	ldy.w #$1001
	jml.l _SendDriverCommandL
	endif

	if useSOUND == 0
	rtl	; LEVEL INITIALIZED!
	endif


;
;	* * * * * * *       COPY LEVEL RAM IMAGE TO GSU RAM $71       * * * * * * *
;
;	(this port) The part of a level the GSU reads from RAM (see EXMYMAC) is
;	stored in the Super NES ROM (the GamePak ROM in the 2 MB builds) and
;	copied to $71:0000 (the GSU is stopped here).
;
_RLLoadLevelRAM:
	php
	rep #$30		; mode 'AX!'
	lda.w Level
	asl a
	tax
	lda.l EMRAMSIZETable,x	; #Bytes
	beq .done
	sta.b Temp2
	txa
	asl a
	tax
	lda.l EMRAMSRCTable,x	; Source (ROM)
	sta.b Temp
	lda.l EMRAMSRCTable+2,x
	sta.b Temp+2
	ldy.w #0
.copy:
	lda.b [Temp],y
	tyx
	sta.l $710000,x
	iny
	iny
	cpy.b Temp2
	bcc .copy
.done:
;
;	(this port) The walls' colour maps: a copy in GSU RAM ($71, RAMWALLCMAPS),
;	read by the wall pixel loops instead of the ROM (no bank switch a pixel)
;
	ldx.w #(33*256)-2
.cmaps:
	lda.l RLColourMaps,x
	sta.l RAMWALLCMAPS,x
	dex
	dex
	bpl .cmaps
	plp
	rts

EMRAMSRCTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dd !{sec_!{lvl!__i}_R_cpu}
	!__i #= !__i+1
	endwhile
EMRAMSIZETable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw !{lvl!__i}RIMAGEE-!{lvl!__i}RIMAGE
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       BINARY SPACE PARTITION TREES       * * * * * * *
;
EMBSPTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	if !{rejrom!{lvl!__i}} != 0
	dd !{lvl!__i}BSP|(bank(!{lvl!__i}REJECTR)<<24)	; BSP Tree Array; EMBSP+3 = bank of REJECT in the GamePak ROM
	else
	dd !{lvl!__i}BSP	; BSP Tree Array (EMBSP+3 = 0: REJECT in the level RAM image)
	endif
	!__i #= !__i+1
	endwhile
EMBSPRTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw (!{lvl!__i}BSPE-!{lvl!__i}BSP-rlbSize)	; BSP Root Node Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       AREAS       * * * * * * *
;
EMAREASTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw (lo16(!{lvl!__i}AREAS)-$8000)	; AREAS Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       VERTEXES       * * * * * * *
;
EMVERTEXESTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw lo16(!{lvl!__i}VERTEXES-_RLVertexes)	; VERTEXES Array
	!__i #= !__i+1
	endwhile
EMNUMVERTEXESTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw (!{lvl!__i}VERTEXESE-!{lvl!__i}VERTEXES)/rlxSize	; NUMBER OF VERTEXES Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       LINES       * * * * * * *
;
EMLINESTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw lo16(!{lvl!__i}LINES)	; LINES Array
	!__i #= !__i+1
	endwhile
EMNUMLINESTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw (!{lvl!__i}LINESE-!{lvl!__i}LINES)/rllSize	; NUMBER OF LINES Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       SEGMENTS       * * * * * * *
;
EMSEGSTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw lo16(!{lvl!__i}SEGS-rlgSize)	; SEGMENTS Array
	!__i #= !__i+1
	endwhile

	!emsegs2o = (0+rlgLine-(rlgSize-(rlgLine+1)+rlgLine))
EMSEGS2Table:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw lo16(!{lvl!__i}SEGS+!emsegs2o)	; SEGMENTS2 Array
	!__i #= !__i+1
	endwhile
EMNUMSEGSTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw (!{lvl!__i}SEGSE-!{lvl!__i}SEGS)/rlgSize	; NUMBER OF SEGS Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       REJECT       * * * * * * *
;
EMREJECTTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	if !{rejrom!{lvl!__i}} != 0
	dw lo16(!{lvl!__i}REJECTR)	; REJECT Array (GamePak ROM)
	else
	dw lo16(!{lvl!__i}REJECT)	; REJECT Array
	endif
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       FACES       * * * * * * *
;
EMFACESTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw lo16(!{lvl!__i}FACES)	; FACES Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       SECTORS       * * * * * * *
;
EMSECTORSTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dd !{lvl!__i}SECTORS	; SECTORS Array
	!__i #= !__i+1
	endwhile
EMNUMSECTORSTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw (!{lvl!__i}SECTORSE-!{lvl!__i}SECTORS)/rlsSize	; NUMBER OF SECTORS Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       OBJECTS       * * * * * * *
;
EMOBJECTSTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw lo16(!{lvl!__i}OBJECTS)	; OBJECTS Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       BLOCKMAPS       * * * * * * *
;
EMBLOCKMAPTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw lo16(!{lvl!__i}BLOCKMAP)	; BLOCKMAP Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       DOORS       * * * * * * *
;
EMDOORSTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw lo16(!{lvl!__i}DOORS)	; DOORS Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       FLOORS       * * * * * * *
;
EMFLOORSTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw lo16(!{lvl!__i}FLOORS)	; FLOORS Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       CEILINGS       * * * * * * *
;
EMCEILINGSTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw lo16(!{lvl!__i}CEILINGS)	; CEILINGS Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       STAIRS       * * * * * * *
;
EMSTAIRSTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw lo16(!{lvl!__i}STAIRS)	; STAIRS Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       LIFTS       * * * * * * *
;
EMLIFTSTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw lo16(!{lvl!__i}LIFTS)	; LIFTS Array
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       SKIES (DOOM II) AND SONGS       * * * * * * *
;
	if defined("lvlsky0")
EMSKYTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	db !{lvlsky!__i}
	!__i #= !__i+1
	endwhile
	endif
;
EMSONGTable:
	!__i #= 0
	while !__i < !NUMLEVELS
	dw !{lvlsong!__i}
	!__i #= !__i+1
	endwhile

;
;	* * * * * * *       LEVEL NAMES       * * * * * * *
;
EMNames:
	!__i #= 0
	while !__i < !NUMLEVELS
	db "!{lvlname!__i}",0
	!__i #= !__i+1
	endwhile

	if useID2 == 0
AMLevelTextPrefix:
	db "ERML: ",0
	endif
