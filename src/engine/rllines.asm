	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                         ENGINE LINES MODULE                        *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"


	%section(LEVEL)
;
;	* * * * * * *       INITIALIZE LINE DATA       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitLineData:
	rep #$30		; mode 'AX!'
	lda.l EMBSP+1	; (TEMP)  = LINE.FLAGS
	sta.b Temp+1
	sta.b Temp2+1
	lda.l EMLINES
	clc
	adc.w #rllFlags
	sta.b Temp
	sep #$20		; mode 'a!'
	lda.b #$71	; LINES are in the level RAM image (GSU RAM $71)
	sta.b Temp+2
	rep #$20		; mode 'A!'
;
	lda.l EMFACES	; (TEMP2) = FACE.SECTORFAR
	inc a	; + rlfSectorFar (= 1)
	sta.b Temp2
;
	lda.l EMSECTORS+1	; (TEMP3) = SECTOR.FLOORHEIGHT
	sta.b Temp3+1
	lda.l EMSECTORS
	clc
	adc.w #rlsFloorHeight
	sta.b Temp3
;
	sep #$20		; mode 'a!'
	lda.b #rlsSize
	sta.w WRMPYA
;
	rep #$20		; mode 'A!'
	lda.l EMNUMLINES	; Get #Lines
	tay
	phy
	ldx.w #0	; Get Index to LineFlags
_RILD200:
	sep #$20		; mode 'a!'
	lda.b [Temp]	; Get Line Flags
	bit.b #rllfDoor	; Is Line DOOR?
	beq _RILD240	; No
	bit.b #rllfSolid	; Is Line SOLID?
	bne _RILD240	; Yes
	rep #$20		; mode 'A!'
	phy
	ldy.w #(rllFace-rllFlags)	; Get LINE.FACE
	lda.b [Temp],y
	tay	; Get FACE.SECTORFAR
	sep #$20		; mode 'a!'
	lda.b [Temp2],y
	sta.w WRMPYB
	rep #$20		; mode 'A!'
	nop
	nop
	nop
	ldy.w _RDMPYL
	lda.b [Temp3],y	; FloorHeight = CeilingHeight?
	iny
	iny
	cmp.b [Temp3],y
	bne _RILD220	; NO, DOOR NOT CLOSED!
	lda.b [Temp]	; YES!  SOLID!
	ora.w #rllfSolid
	bra _RILD230
_RILD220:
	lda.b [Temp]	; Get Line Flags
_RILD230:
	sep #$20		; mode 'a!'
	ply
_RILD240:
	and.b #(rllfSolid|rllfMapped)
	sta.l _RLLineFlags,x	; Save Line Flags
	inx
	rep #$20		; mode 'A!'
	lda.b Temp	; Move to next Line
	clc
	adc.w #rllSize
	sta.b Temp
	dey	; One less Line
	bne _RILD200
;
	ply	; Get #Lines
	ldx.w #0	; Get Index to LineRLCounts
	txa
_RILD400:
	sta.l _RLLineRLCounts,x	; Initialize LineRLCount
	inx
	inx
	dey	; One less Line
	bne _RILD400
	rts
