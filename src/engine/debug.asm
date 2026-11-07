	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*              RL ENGINE DEBUGGING AND DIAGNOSTICS MODULE            *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/xfer.inc"
	incsrc "src/include/rlsound.inc"

	if !DEBUGSCR != 0
	; public _RLInitDebug


;
;	* * * * * * *       DEBUGGING SCREEN INFORMATION FORMAT       * * * * * * *
;
;	AAAA XXXX YYYY PPPPPP HC	A, X, Y, PC, HaltCode
;	0000 1111 2222 3333 4444	R0, R1, R2, R3, R4
;	5555 6666 7777 8888 9999	R5, R6, R7, R8, R9
;	AAAA BBBB CCCC DDDD EEEE	R10,R11,R12,R13,R14
;
;	P XXXXXX YYYYYY AAAA  DEBUG	PlayerX, PlayerY, PlayerA
;	  SS     ZZZZ         EEMML	PlayerS, PlayerZ, Episode/Mission/SkillLevel
;
;	B=BBBB Vvv Ooo Sss Ttt Mmm	AreaSeg,#VSegs,#VObjs,#VSecs,#Tasks,#MObjs
;	  ETxx EMxx EAxx EBxx PMxx	EnTargets,EnMoves,EnAttacks,EnBirths,ProjMoves
;	TS:FFI    FFI    FFI    FFI	TurboSounds: Flags/Index
;	PPEEBB PPEEBB PPEEBB PPEEBB	Priority,Effect,BWave
;
;	A CLZP PWLP WLLP OBJP FLRP	ClipZone,PreWallPlot,WallPlot,ObjPlot,FloorPlot
;	  F:FF				#Floors
;	B CLZP PWLP WLLP OBJP FLRP	ClipZone,PreWallPlot,WallPlot,ObjPlot,FloorPlot
;	  F:FF				#Floors
;	C CLZP PWLP WLLP OBJP FLRP	ClipZone,PreWallPlot,WallPlot,ObjPlot,FloorPlot
;	  F:FF				#Floors
;


	%section(DEBUG)

;
;	* * * * * * *       INITIALIZE DEBUGGING       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitDebug:
	rep #$20		; mode 'A!'

	if !DEBUG == 0
	lda.w #lo16(HALTERROR)	; HALT/HALTGSU ERROR VECTOR
	sta.w GSUBRKRAM+1
	endif

	lda.w #0	; DEBUGGING SCREEN OFF
	sta.l DebugScreen
	sta.l DebugScreenOld
	sep #$20
	rep #$10		; mode 'aX!'

	if !DEBUG == 0
	lda.b #bank(HALTERROR)	; HALT/HALTGSU ERROR VECTOR
	sta.w GSUBRKRAM+3
	lda.b #$5C	; JML
	sta.w GSUBRKRAM+0
	endif

	ldx.w #lo16(_RLDebugXFer)	; Transfer DEBUG DataBlocks
	lda.b #bank(_RLDebugXFer)
	jml.l XFer

;
;	* * * * * * *       DEBUG TRANSFER LIST       * * * * * * *
;
_RLDebugXFer:
	dw xftVRAM16	; Transfer DebugFont Def
	dd RLDebugFontDef
	dd vmCHR2C
	dw 0,0,0
;
	dw xftEND


	%section(ENGINE_RAMCODE)
;
;	* * * * * * *       UPDATE DEBUGGING SCREEN       * * * * * * *
;
	; dbr ?
	; dpr 0
_RUDG900:
	rep #$20		; mode 'A!'
	rts
_RLUpdateDebug:
	rep #$30		; mode 'AX!'
	lda.b RLFlags
	and.w #(rlfDebugSCR+rlfDebug)	; Debugging Updates Completed?
	cmp.w #(rlfDebugSCR+rlfDebug)
	bne _RUDG900	; No
;
	ldx.w #(rlfDebugSCR+rlfDebug)	; Debugging Screen Built
	sep #$20		; mode 'a!'
	lda.w DebugScreen+!RLSNESGSUXVarsO	; DebugScreen Status Change?
	cmp.l DebugScreenOld
	bne _RUDG120	; Yes!
	dec a	; Screen ON?
	bne _RUDG900	; NO!
	inc a
	ldx.w #rlfDebug	; Debugging Screen Update
_RUDG120:
	sta.l DebugScreenOld
	phx
;
	lda.w DebugPlayerX+3+!RLSNESGSUXVarsO	; PLAYER X
	ldx.w #lo16(_RLDebugData1PX+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugPlayerX+2+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
	lda.w DebugPlayerX+1+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w DebugPlayerY+3+!RLSNESGSUXVarsO	; PLAYER Y
	ldx.w #lo16(_RLDebugData1PY+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugPlayerY+2+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
	lda.w DebugPlayerY+1+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w DebugPlayerA+1+!RLSNESGSUXVarsO	; PLAYER A
	ldx.w #lo16(_RLDebugData1PA+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugPlayerA+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w DebugPlayerS+!RLSNESGSUXVarsO	; PLAYER S
	ldx.w #lo16(_RLDebugData2PS+0)
	jsr.w _RLDebugScreenHex
;
	lda.w DebugPlayerZ+1+!RLSNESGSUXVarsO	; PLAYER Z
	ldx.w #lo16(_RLDebugData2PZ+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugPlayerZ+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w DebugClipZonePtrA+1+!RLSNESGSUXVarsO	; CLIPZONE PTR
	ldx.w #lo16(_RLDebugData3C+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugClipZonePtrA+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w DebugPreWallPtrA+1+!RLSNESGSUXVarsO	; PREWALL PLOT PTR
	ldx.w #lo16(_RLDebugData3P+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugPreWallPtrA+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w DebugWallPlotPtrA+1+!RLSNESGSUXVarsO	; WALL PLOT PTR
	ldx.w #lo16(_RLDebugData3W+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugWallPlotPtrA+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	ldx.w DebugFloorsSizeA+!RLSNESGSUXVarsO	; FLOORS SIZE
	stx.w WRDIVL
	lda.b #rlfdSize
	sta.w WRDIVB
;
	lda.w DebugObjPlotPtrA+1+!RLSNESGSUXVarsO	; OBJ PLOT PTR
	ldx.w #lo16(_RLDebugData3O+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugObjPlotPtrA+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w _RDDIVL	; FLOORS SIZE
	ldx.w #lo16(_RLDebugData3FD+0)
	jsr.w _RLDebugScreenHex
;
	lda.w DebugFloorPlotPtrA+1+!RLSNESGSUXVarsO	; FLOOR PLOT PTR
	ldx.w #lo16(_RLDebugData3F+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugFloorPlotPtrA+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w DebugClipZonePtrB+1+!RLSNESGSUXVarsO	; CLIPZONE PTR
	ldx.w #lo16(_RLDebugData4C+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugClipZonePtrB+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w DebugPreWallPtrB+1+!RLSNESGSUXVarsO	; PREWALL PLOT PTR
	ldx.w #lo16(_RLDebugData4P+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugPreWallPtrB+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w DebugWallPlotPtrB+1+!RLSNESGSUXVarsO	; WALL PLOT PTR
	ldx.w #lo16(_RLDebugData4W+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugWallPlotPtrB+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	ldx.w DebugFloorsSizeB+!RLSNESGSUXVarsO	; FLOORS SIZE
	stx.w WRDIVL
	lda.b #rlfdSize
	sta.w WRDIVB
;
	lda.w DebugObjPlotPtrB+1+!RLSNESGSUXVarsO	; OBJ PLOT PTR
	ldx.w #lo16(_RLDebugData4O+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugObjPlotPtrB+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w _RDDIVL	; FLOORS SIZE
	ldx.w #lo16(_RLDebugData4FD+0)
	jsr.w _RLDebugScreenHex
;
	lda.w DebugFloorPlotPtrB+1+!RLSNESGSUXVarsO	; FLOOR PLOT PTR
	ldx.w #lo16(_RLDebugData4F+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugFloorPlotPtrB+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w DebugClipZonePtrC+1+!RLSNESGSUXVarsO	; CLIPZONE PTR
	ldx.w #lo16(_RLDebugData5C+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugClipZonePtrC+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w DebugPreWallPtrC+1+!RLSNESGSUXVarsO	; PREWALL PLOT PTR
	ldx.w #lo16(_RLDebugData5P+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugPreWallPtrC+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	ldx.w DebugVObjSize+!RLSNESGSUXVarsO	; VOBJ SIZE
	stx.w WRDIVL
	lda.b #rloSize
	sta.w WRDIVB
;
	lda.w DebugWallPlotPtrC+1+!RLSNESGSUXVarsO	; WALL PLOT PTR
	ldx.w #lo16(_RLDebugData5W+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugWallPlotPtrC+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w _RDDIVL	; VOBJ SIZE
	ldx.w #lo16(_RLDebugData6O+0)
	jsr.w _RLDebugScreenHex
;
	ldx.w DebugFloorsSizeC+!RLSNESGSUXVarsO	; FLOORS SIZE
	stx.w WRDIVL
	lda.b #rlfdSize
	sta.w WRDIVB
;
	lda.w DebugObjPlotPtrC+1+!RLSNESGSUXVarsO	; OBJ PLOT PTR
	ldx.w #lo16(_RLDebugData5O+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugObjPlotPtrC+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w _RDDIVL	; FLOORS SIZE
	ldx.w #lo16(_RLDebugData5FD+0)
	jsr.w _RLDebugScreenHex
;
	ldx.w DebugVSegSize+!RLSNESGSUXVarsO	; VSEG SIZE
	stx.w WRDIVL
	lda.b #rlvSize
	sta.w WRDIVB
;
	lda.w DebugFloorPlotPtrC+1+!RLSNESGSUXVarsO	; FLOOR PLOT PTR
	ldx.w #lo16(_RLDebugData5F+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugFloorPlotPtrC+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w _RDDIVL	; VSEG SIZE
	ldx.w #lo16(_RLDebugData6V+0)
	jsr.w _RLDebugScreenHex
;
	lda.w DebugVSecNum+!RLSNESGSUXVarsO	; VSECS
	ldx.w #lo16(_RLDebugData6S+0)
	jsr.w _RLDebugScreenHex
;
	lda.w DebugRLNumTasks+!RLSNESGSUXVarsO	; RLTASKS
	ldx.w #lo16(_RLDebugData6T+0)
	jsr.w _RLDebugScreenHex
;
	lda.w DebugRLNumMObjs+!RLSNESGSUXVarsO	; RLMOBJS
	ldx.w #lo16(_RLDebugData6M+0)
	jsr.w _RLDebugScreenHex
;
	lda.w DebugBSPPtr+1+!RLSNESGSUXVarsO	; BSP SIZE
	ldx.w #lo16(_RLDebugData6B+0)
	jsr.w _RLDebugScreenHex
	lda.w DebugBSPPtr+0+!RLSNESGSUXVarsO
	jsr.w _RLDebugScreenHex
;
	lda.w DebugEnemyTargets+!RLSNESGSUXVarsO	; ENEMY TARGETS
	ldx.w #lo16(_RLDebugData7ET+0)
	jsr.w _RLDebugScreenHex
;
	lda.w DebugEnemyMoves+!RLSNESGSUXVarsO	; ENEMY MOVES
	ldx.w #lo16(_RLDebugData7EM+0)
	jsr.w _RLDebugScreenHex
;
	lda.w DebugEnemyAttacks+!RLSNESGSUXVarsO	; ENEMY ATTACKS
	ldx.w #lo16(_RLDebugData7EA+0)
	jsr.w _RLDebugScreenHex
;
	lda.w DebugEnemyBirths+!RLSNESGSUXVarsO	; ENEMY BIRTHS
	ldx.w #lo16(_RLDebugData7EB+0)
	jsr.w _RLDebugScreenHex
;
	lda.w DebugProjectileMoves+!RLSNESGSUXVarsO	; PROJECTILE MOVES
	ldx.w #lo16(_RLDebugData7PM+0)
	jsr.w _RLDebugScreenHex
;
	rep #$20		; mode 'A!'
	; TURBOSOUND0
	ldy.w #(0*rlsetSize)
	ldx.w #lo16(_RLDebugData8T0+0)
	lda.w #lo16(_RLDebugData9T0+0)
	jsr.w _RLDebugTurboSound
;
	rep #$20		; mode 'A!'
	; TURBOSOUND1
	ldy.w #(1*rlsetSize)
	ldx.w #lo16(_RLDebugData8T1+0)
	lda.w #lo16(_RLDebugData9T1+0)
	jsr.w _RLDebugTurboSound
;
	rep #$20		; mode 'A!'
	; TURBOSOUND2
	ldy.w #(2*rlsetSize)
	ldx.w #lo16(_RLDebugData8T2+0)
	lda.w #lo16(_RLDebugData9T2+0)
	jsr.w _RLDebugTurboSound
;
	rep #$20		; mode 'A!'
	; TURBOSOUND3
	ldy.w #(3*rlsetSize)
	ldx.w #lo16(_RLDebugData8T3+0)
	lda.w #lo16(_RLDebugData9T3+0)
	jsr.w _RLDebugTurboSound
;
	rep #$20		; mode 'A!'
	pla
	trb.b RLFlags
	rts


;
;	* * * * * * *       TURBOSOUND INFORMATION 1       * * * * * * *
;
;	.Y = TurboSound Index
;	.X = RAM Offset to Store Characters1
;	.A = RAM Offset to Store Characters2
;
	; mode 'AX'
	; dbr 0
	; dpr 0
_RLDebugTurboSound:
	pha	; Save Characters2 RAM Offset
	sep #$20		; mode 'a!'
;
	lda.w TSounds+rlsetFlags,y	; FLAGS
	jsr.w _RLDebugScreenHex
;
	lda.b #'D'	; PRIORITYINDEX
	!rlset #= 0
	for __rep = 0..(MaxRLTSounds-1)
	cpy.b TSoundsI+(!rlset*2)	; Found Priority?
	beq _RLDebugTurboSound2	; Yes!
	dec a	; No, Keep Looking
	!rlset #= !rlset+1
	endfor
_RLDebugTurboSound2:
	clc	; PRIORITYINDEX (A-D)
	adc.b #lo16(((vmCHR2C-vmCHR2)/(32/2))-$20)
	sta.l +(bank(_RLDebugData1)<<16)+0,x
	lda.b #hi16((((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
	sta.l +(bank(_RLDebugData1)<<16)+1,x
;
	plx	; Get Characters2 RAM Offset
	lda.w TSounds+rlsetPriority,y	; PRIORITY
	jsr.w _RLDebugScreenHex
	lda.w TSounds+rlsetEffect,y	; EFFECT
	jsr.w _RLDebugScreenHex
	lda.w TSounds+rlsetBWave,y	; BWAVE
;
;	* * * * * * *       HEX BYTE TO SCREEN CHARACTERS       * * * * * * *
;
;	!!!   DANGER!   FALLS THROUGH FROM ABOVE!!!
;
;	.A = Byte
;	.X = RAM Offset to Store Characters
;
	; mode 'aX'
	; dbr 0
	; dpr 0
_RLDebugScreenHex:
	pha
	lsr a
	lsr a
	lsr a
	lsr a
	jsr.w _RLDebugScreenNibble
	pla
	and.b #$0F
_RLDebugScreenNibble:
	clc
	adc.b #'0'
	cmp.b #'9'+1
	bcc _DSNB200
;	sec
	adc.b #'A'-('9'+1)-1
_DSNB200:
	clc
	adc.b #lo16(((vmCHR2C-vmCHR2)/(32/2))-$20)
	sta.l +(bank(_RLDebugData1)<<16)+0,x
	lda.b #hi16((((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
	sta.l +(bank(_RLDebugData1)<<16)+1,x
	inx
	inx
	rts


;
;	* * * * * * *       TRANSFER DEBUGGING SCREEN TO VRAM       * * * * * * *
;
	; mode 'AX'
	; dbr 0
	; dpr 0
_RLDebugScreen:
	lda.w #rlfDebugSCR	; Update Debugging Screen?
	tsb.b RLFlags
	bne _RDS200	; NO
	sep #$20		; mode 'a!'
	lda.l DebugScreenOld	; ON/OFF?
	bne _RDS100
	jmp.w _RDS800	; OFF
;
;	>>>   TURN ON DEBUGGING SCREEN   <<<
;
_RDS100:
	ldx.w #lo16(DebugInfoDText)	; Show DebugInfo Text
	lda.b #bank(DebugInfoDText)
	jsl.l _RLDebugText
;
;	>>>   UPDATE DEBUGGING SCREEN   <<<
;
	; mode 'AX'
_RDS200:
	ldx.w #lo16(_RLDebugData1)	; PLAYER INFO (X,Y,A)
	stx.w DMA0A1L
	ldx.w #bank(_RLDebugData1)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(4*32*2/2)+0)
	stx.w VMADDL
	sep #$20		; mode 'a!'
	lda.b #_RLDebugData1L
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLDebugData2)	; PLAYER INFO2 (SECTOR)
	stx.w DMA0A1L
	ldx.w #bank(_RLDebugData2)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(5*32*2/2)+2)
	stx.w VMADDL
	lda.b #_RLDebugData2L
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLDebugData3)	; RLENGINE A
	stx.w DMA0A1L
	ldx.w #bank(_RLDebugData3)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(12*32*2/2)+0)
	stx.w VMADDL
	lda.b #_RLDebugData3L
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLDebugData3B)	; RLENGINE AB
	stx.w DMA0A1L
	ldx.w #bank(_RLDebugData3B)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(13*32*2/2)+2)
	stx.w VMADDL
	lda.b #_RLDebugData3BL
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLDebugData4)	; RLENGINE B
	stx.w DMA0A1L
	ldx.w #bank(_RLDebugData4)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(14*32*2/2)+0)
	stx.w VMADDL
	lda.b #_RLDebugData4L
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLDebugData4B)	; RLENGINE BB
	stx.w DMA0A1L
	ldx.w #bank(_RLDebugData4B)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(15*32*2/2)+2)
	stx.w VMADDL
	lda.b #_RLDebugData4BL
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLDebugData5)	; RLENGINE C
	stx.w DMA0A1L
	ldx.w #bank(_RLDebugData5)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(16*32*2/2)+0)
	stx.w VMADDL
	lda.b #_RLDebugData5L
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLDebugData5B)	; RLENGINE CB
	stx.w DMA0A1L
	ldx.w #bank(_RLDebugData5B)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(17*32*2/2)+2)
	stx.w VMADDL
	lda.b #_RLDebugData5BL
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLDebugData6)	; RLENGINE S
	stx.w DMA0A1L
	ldx.w #bank(_RLDebugData6)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(7*32*2/2)+0)
	stx.w VMADDL
	lda.b #_RLDebugData6L
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLDebugData7)	; RLENGINE Q
	stx.w DMA0A1L
	ldx.w #bank(_RLDebugData7)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(8*32*2/2)+2)
	stx.w VMADDL
	lda.b #_RLDebugData7L
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLDebugData8)	; RLENGINE TA
	stx.w DMA0A1L
	ldx.w #bank(_RLDebugData8)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(9*32*2/2))
	stx.w VMADDL
	lda.b #_RLDebugData8L
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLDebugData9)	; RLENGINE TB
	stx.w DMA0A1L
	ldx.w #bank(_RLDebugData9)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(10*32*2/2))
	stx.w VMADDL
	lda.b #_RLDebugData9L
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	lda.b #$70	; A Bank
	sta.w DMA0A1B
	rep #$20		; mode 'A!'
	rts
;
;	>>>   REMOVE DEBUGGING SCREEN   <<<
;
	; mode 'aX'
_RDS800:
	ldx.w #((RLCharY-4-4)*32*2)
	stx.w DMA0NUML
	ldx.w #lo16(_RLDebugBlankChar)
	stx.w DMA0A1L
	ldx.w #(vmMAP2+(4*32*2/2))
	stx.w VMADDL
	lda.b #bank(_RLDebugBlankChar)
	sta.w DMA0A1B
	lda.b #%00001001	; A->B, Abs., Fixed,2-Add-WriteLH
	sta.w DMA0INC
	lda.b #$01	; Enable/Start Channel#0
	sta.w MDMAEN
	lda.b #%00000001	; A->B, Abs., Auto Inc,2-Add-WriteLH
	sta.w DMA0INC
	lda.b #$70	; A Bank
	sta.w DMA0A1B
	rep #$30		; mode 'AX!'
	stz.w DMA0NUML	; PreClear SIZE HighByte
	rts

_RLDebugBlankChar:
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000

;
;	>>>   PLAYER INFORMATION   <<<
;
_RLDebugData1:
	dw ('P'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; P XXXXXX XXXXXX XXXX
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData1PX:
	dw 0,0,0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData1PY:
	dw 0,0,0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData1PA:
	dw 0,0,0,0
	_RLDebugData1L = pc()-_RLDebugData1

;
;	>>>   PLAYER INFORMATION 2   <<<
;
_RLDebugData2:
_RLDebugData2PS:
	dw 0,0	;   XX
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData2PZ:
	dw 0,0,0,0	;   XXXX
	_RLDebugData2L = pc()-_RLDebugData2

;
;	>>>   RLENGINE INFORMATION A   <<<
;
_RLDebugData3:
	dw ('A'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; A XXXX XXXX XXXX XXXX XXXX
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData3C:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData3P:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData3W:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData3O:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData3F:
	dw 0,0,0,0
	_RLDebugData3L = pc()-_RLDebugData3

_RLDebugData3B:
	dw ('F'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; F:XX
	dw ($3A+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
_RLDebugData3FD:
	dw 0,0
	_RLDebugData3BL = pc()-_RLDebugData3B


;
;	>>>   RLENGINE INFORMATION B   <<<
;
_RLDebugData4:
	dw ('B'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; B XXXX XXXX XXXX XXXX XXXX
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData4C:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData4P:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData4W:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData4O:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData4F:
	dw 0,0,0,0
	_RLDebugData4L = pc()-_RLDebugData4

_RLDebugData4B:
	dw ('F'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; F:XX
	dw ($3A+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
_RLDebugData4FD:
	dw 0,0
	_RLDebugData4BL = pc()-_RLDebugData4B


;
;	>>>   RLENGINE INFORMATION C   <<<
;
_RLDebugData5:
	dw ('C'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; C XXXX XXXX XXXX XXXX XXXX
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData5C:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData5P:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData5W:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData5O:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData5F:
	dw 0,0,0,0
	_RLDebugData5L = pc()-_RLDebugData5

_RLDebugData5B:
	dw ('F'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; F:XX
	dw ($3A+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
_RLDebugData5FD:
	dw 0,0
	_RLDebugData5BL = pc()-_RLDebugData5B


;
;	>>>   RLENGINE INFORMATION S   <<<
;
_RLDebugData6:
	dw ('B'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; B=XXXX
	dw ($3D+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
_RLDebugData6B:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ('V'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; VXX
_RLDebugData6V:
	dw 0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ('O'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; OXX
_RLDebugData6O:
	dw 0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ('S'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; SXX
_RLDebugData6S:
	dw 0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ('T'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; TXX
_RLDebugData6T:
	dw 0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ('M'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; MXX
_RLDebugData6M:
	dw 0,0
	_RLDebugData6L = pc()-_RLDebugData6


;
;	>>>   RLENGINE INFORMATION Q   <<<
;
_RLDebugData7:
	dw ('E'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; ETxx
	dw ('T'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
_RLDebugData7ET:
	dw 0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ('E'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; EMxx
	dw ('M'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
_RLDebugData7EM:
	dw 0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ('E'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; EAxx
	dw ('A'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
_RLDebugData7EA:
	dw 0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ('E'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; EBxx
	dw ('B'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
_RLDebugData7EB:
	dw 0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ('P'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; PMxx
	dw ('M'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
_RLDebugData7PM:
	dw 0,0
	_RLDebugData7L = pc()-_RLDebugData7


;
;	>>>   RLENGINE INFORMATION TA   <<<
;
_RLDebugData8:
	dw ('T'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)	; TS:
	dw ('S'+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
	dw ($3A+(((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
_RLDebugData8T0:
	dw 0,0	; FF
	dw 0	; I
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData8T1:
	dw 0,0	; FF
	dw 0	; I
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData8T2:
	dw 0,0	; FF
	dw 0	; I
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData8T3:
	dw 0,0	; FF
	dw 0	; I
	_RLDebugData8L = pc()-_RLDebugData8


;
;	>>>   RLENGINE INFORMATION TB   <<<
;
_RLDebugData9:
_RLDebugData9T0:
	dw 0,0	; PP
	dw 0,0	; EE
	dw 0,0	; BB
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData9T1:
	dw 0,0	; PP
	dw 0,0	; EE
	dw 0,0	; BB
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData9T2:
	dw 0,0	; PP
	dw 0,0	; EE
	dw 0,0	; BB
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLDebugData9T3:
	dw 0,0	; PP
	dw 0,0	; EE
	dw 0,0	; BB
	_RLDebugData9L = pc()-_RLDebugData9



;
;	* * * * * * *       DEBUG TEXT       * * * * * * *
;
;	.X/.A	= pointer to DebugTextStructure
;
;	DC.W	VRAMPointer (or -1 for End)
;	DC.L	ADDRESS of Text
;	DC.B	Size of Text
;
	; dbr 0
	; dpr 0
	; mode 'aX'
_RLDebugText:
	jsr.w RLDebugText
	rtl
RLDebugText:
	stx.b Temp	; Save pointer to DebugTextStruct
	sta.b Temp+2
	lda.b #$80
	sta.w VMAINC
RDT200:
	rep #$20		; mode 'A!'
	ldy.w #0
	lda.b [Temp],y	; VRAM PTR
	bmi RDT900	; No, done!
	sta.w VMADDL
	iny
	iny
	lda.b [Temp],y
	sta.b Temp2
	iny
	iny
	lda.b [Temp],y
	sta.b Temp2+2
	xba
	and.w #$00FF	; .X = Length
	tax
	lda.b Temp	; Bump DebugTextPtr
	clc
	adc.w #6
	sta.b Temp
	sep #$20		; mode 'a!'
	ldy.w #0
RDT300:
	lda.b [Temp2],y	; Get next character
	clc
	adc.b #lo16(((vmCHR2C-vmCHR2)/(32/2))-$20)
	sta.w VMDATAL	; Send to VRAM
	lda.b #hi16((((vmCHR2C-vmCHR2)/(32/2))-$20)+$2C00)
	sta.w VMDATAH
	iny
	dex
	bne RDT300
	bra RDT200	; Handle next text piece
RDT900:
	rts

;
;	* * * * * * *       DEBUG INFORMATION TEXTS       * * * * * * *
;
DebugInfoDText:
	dw (vmMAP2+(4*32)+(27-DI0TxtL))
	dl DI0Txt
	db DI0TxtL

	dw (vmMAP2+(5*32)+(27-DI0TxtL))
	dl DI1Txt
	db DI1TxtL

	dw -1

DI0Txt:
	db "DEBUG"
	DI0TxtL = pc()-DI0Txt

DI1Txt:
	db "ERMLR"
	DI1TxtL = pc()-DI1Txt


;
;	* * * * * * *       HALT ERROR       * * * * * * *
;
HALTERROR:
	sei
	rep #$30		; mode 'AX!'
	pha
;
;	>>>   LOCK SYSTEM INTERRUPTS   <<<
;
	sep #$20		; mode 'a!'
;	lda	#$80				; Disable Display
;	sta	INIDISP_S
;	sta	INIDISP
	lda.b #$01	; DISABLE NMI,VIRQ,HIRQ
	if (!DEBUG*WIRE) != 0
	sta.l NMITIMEN_XS
	lda.b #$81
	endif
	sta.w NMITIMEN
	bit.w _TIMEUP	; Clear IRQ Flag
;
;	>>>   HALT GSU   <<<
;
	rep #$20		; mode 'A!'
	stz.w sfxSFR	; Clear GO bit (Halt GSU)
._0:
	lda.w sfxSFR	; GSU Halted?
	and.w #%0000000000100000
	bne ._0	; No, keep waiting
;
;	>>>   SAVE REGISTERS   <<<
;
	pla
	sta.b Temp2
	stx.b Temp2+2
	sty.b Temp2+4
;
	lda.b 1,s	; Get Error Address
	inc a
	sta.b Temp
	lda.b 3,s
	sta.b Temp+2
	lda.b [Temp]	; Get Error Code
	sta.b Temp+4
;
;	>>>   UPDATE HALT ERROR SCREEN   <<<
;
	jsr.w _RLUpdateHaltError
;
;	>>>   UPDATE AND FORCE DEBUGGING SCREEN ACTIVE   <<<
;
	rep #$20		; mode 'A!'
	lda.w #(rlfDebugSCR|rlfDebug)
	sta.b RLFlags
	lda.w #1
	sta.l DebugScreen+!RLSNESGSUXVarsO
	jsr.w _RLUpdateDebug
	lda.w #~rlfDebugSCR
	sta.b RLFlags
	jsl.l WaitVBlank
	jsr.w _RLDebugScreen
;
;	>>>   TOGGLE SCREEN DISPLAY ON/OFF WITH ANY JOYSTICK BUTTON   <<<
;
	sep #$10
	rep #$20		; mode 'Ax!'
	lda.w #$0F	; Enable Display
	sta.w INIDISP
	stz.w TS	; and TMW
	ldx.b #$02
	jmp.w HER850
HER800:
	jsl.l WaitVBlank
HER810:
	bit.w _HVBJOY-1	; Wait for NOT in VBlank Period
	bmi HER810
	lda.w JOY1L
	beq HER800
	txa
	eor.w #$01	; $11
	tax
HER850:
	stx.w TM
HER860:
	jsl.l WaitVBlank
HER870:
	bit.w _HVBJOY-1	; Wait for NOT in VBlank Period
	bmi HER870
	lda.w JOY1L
	bne HER860
	jmp.w HER800

;
;	* * * * * * *       UPDATE HALT ERROR SCREEN       * * * * * * *
;
_RLUpdateHaltError:
	sep #$20
	rep #$10		; mode 'aX!'
	lda.b Temp2+1	; A
	ldx.w #lo16(_RLHaltErrData0A)
	jsr.w _RLDebugScreenHex
	lda.b Temp2
	jsr.w _RLDebugScreenHex
;
	lda.b Temp2+3	; X
	ldx.w #lo16(_RLHaltErrData0X)
	jsr.w _RLDebugScreenHex
	lda.b Temp2+2
	jsr.w _RLDebugScreenHex
;
	lda.b Temp2+5	; Y
	ldx.w #lo16(_RLHaltErrData0Y)
	jsr.w _RLDebugScreenHex
	lda.b Temp2+4
	jsr.w _RLDebugScreenHex
;
	lda.b Temp+2	; PC
	ldx.w #lo16(_RLHaltErrData0PC)
	jsr.w _RLDebugScreenHex
	lda.b Temp+1
	jsr.w _RLDebugScreenHex
	lda.b Temp
	jsr.w _RLDebugScreenHex
;
	lda.b Temp+4	; HALT CODE
	ldx.w #lo16(_RLHaltErrData0HC)
	jsr.w _RLDebugScreenHex
;
	ldy.w #0
	ldx.w #lo16(_RLHaltErrData1R)
_RUHE400:
	lda.w sfxR0+1,y	; GSU Register
	jsr.w _RLDebugScreenHex
	lda.w sfxR0+0,y
	jsr.w _RLDebugScreenHex
	inx
	inx
	iny	; Next GSU Register
	iny
	cpy.w #(5*2)	; R5?
	bne _RUHE420
	ldx.w #lo16(_RLHaltErrData2R)
_RUHE420:
	cpy.w #(10*2)	; R10?
	bne _RUHE440
	ldx.w #lo16(_RLHaltErrData3R)
_RUHE440:
	cpy.w #(15*2)
	bne _RUHE400
;
	jsl.l WaitVBlank
;
	ldx.w #lo16(_RLHaltErrData0)	; A,X,Y,PC,HC
	stx.w DMA0A1L
	ldx.w #bank(_RLHaltErrData0)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(0*32*2/2)+0)
	stx.w VMADDL
	lda.b #_RLHaltErrData0L
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLHaltErrData1)	; R0,R1,R2,R3,R4
	stx.w DMA0A1L
	ldx.w #bank(_RLHaltErrData1)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(1*32*2/2)+0)
	stx.w VMADDL
	lda.b #_RLHaltErrData1L
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLHaltErrData2)	; R5,R6,R7,R8,R9
	stx.w DMA0A1L
	ldx.w #bank(_RLHaltErrData2)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(2*32*2/2)+0)
	stx.w VMADDL
	lda.b #_RLHaltErrData2L
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	ldx.w #lo16(_RLHaltErrData3)	; R10,R11,R12,R13,R14
	stx.w DMA0A1L
	ldx.w #bank(_RLHaltErrData3)
	stx.w DMA0A1B
	ldx.w #(vmMAP2+(3*32*2/2)+0)
	stx.w VMADDL
	lda.b #_RLHaltErrData3L
	sta.w DMA0NUML
	lda.b #$01
	sta.w MDMAEN
;
	rts


;
;	>>>   HALT ERROR INFORMATION 0   <<<
;
_RLHaltErrData0:
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLHaltErrData0A:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLHaltErrData0X:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLHaltErrData0Y:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLHaltErrData0PC:
	dw 0,0,0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLHaltErrData0HC:
	dw 0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	_RLHaltErrData0L = pc()-_RLHaltErrData0


;
;	>>>   HALT ERROR INFORMATION 1   <<<
;
_RLHaltErrData1:
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLHaltErrData1R:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	_RLHaltErrData1L = pc()-_RLHaltErrData1


;
;	>>>   HALT ERROR INFORMATION 2   <<<
;
_RLHaltErrData2:
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLHaltErrData2R:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	_RLHaltErrData2L = pc()-_RLHaltErrData2


;
;	>>>   HALT ERROR INFORMATION 3   <<<
;
_RLHaltErrData3:
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
_RLHaltErrData3R:
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	dw 0,0,0,0
	dw ((vmCHR2B-vmCHR2)/(32/2))+$2000
	_RLHaltErrData3L = pc()-_RLHaltErrData3

	endif
