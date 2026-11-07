	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                     NON-MASKABLE INTERRUPT MODULE                  *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"

	; public InitNMI,InitNormalNMI
	; public NormalNMI

	%section(NMI)

;
;	* * * * * * *       INITIALIZE NORMAL NMIS       * * * * * * *
;
	; dbr ?
	; dpr 0
InitNormalNMI:
	sep #$20
	rep #$10		; mode 'aX!'
	ldx.w #lo16(NormalNMI)	; NORMAL NMI Code
	lda.b #bank(NormalNMI)
	if NOAICESE == 0
	ldy.w #$81	; ENABLE NMI+JOYREAD (FOR WIRE)
	endif
	if NOAICESE != 0
	ldy.w #$81	; ENABLE NMI+JOYREAD
	endif
;
;	* * * * * * *       INITIALIZE NMI       * * * * * * *
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE!!!
;
	; dbr ?
	; dpr 0
	; mode 'aX'
InitNMI:
	sta.w GSUNMIRAM+3
	lda.b #$5C	; JML
	sta.w GSUNMIRAM+0
	stx.w GSUNMIRAM+1	; Save pointer to NMI Code
	stz.w RGBXFer	; No RGB XFer
	tya
	if (!DEBUG*WIRE) != 0
	sta.l NMITIMEN_XS
	endif
	sta.w NMITIMEN
	rep #$20		; mode 'A!'
	; Clear JOYSticks
	stz.w JOY1
	dec a	; Force JOY1/2 Status to INVALID
	sta.w JOY1Stat
	sta.w JOY2Stat	; (port 2 mouse: not set up yet)
	rtl

;
;	* * * * * * *       NORMAL NMI CODE       * * * * * * *
;
	; dpr ?
	; dbr ?
NormalNMI:
	if (WIRE*!DEBUG) != 0
	jsl.l $7FFD00	; MONITOR
	endif
NormalNMI2:
	rep #$30		; mode 'AX!'
	pha	; Save .A
	phx	; Save .X
	phy	; Save .Y
	tdc	; Save DPR
	pha
	lda.w #0	; Set DPR $0000
	tcd
	; dpr 0
	phb	; Save DB
	pha
	plb	; Set DB
	; dbr 0
;
;	>>>   TRANSFER RGB PALETTE DATA?   <<<
;
NNMI3000:
	bit.w RGBXFer-1	; Time to transfer RGB Data?
	bpl NNMI9000	; No
	sep #$10		; mode 'x!'
	ldx.b #%00000010	; A->B, Abs., Auto Inc,1-Add-Write2x
	stx.w DMA0INC
	ldx.b #lo16(CGDATA)	; CGDATA
	stx.w DMA0DEST
	lda.w #lo16(RGBData)
	sta.w DMA0A1L
	lda.w #512	; 512 bytes to transfer
	sta.w DMA0NUML
	ldx.b #0
	stx.w CGADD	; Transfer 256 RGB Colours
	stx.w DMA0A1B
	stx.w RGBXFer	; RGB Data Transferred
	inx	; Enable/Start Channel#0
	stx.w MDMAEN
;
;	>>>   READ JOYSTICK DATA   <<<
;
NNMI9000:

NNMI9020:
	lda.w _HVBJOY	; Auto Joypad Read still busy?
	lsr a
	bcs NNMI9020	; Yes, wait
	rep #$30		; mode 'AX!'
	jsl.l __ReadJOY
	jsl.l RumbleOffL	; (this port) Rumble: motors off (outside the levels)

;
;	* * * * * * *       NNMI COMPLETE       * * * * * * *
;
NNMI10000:
	sep #$20		; mode 'a!'
	bit.w _RDNMI	; Clear NMI Flag
	pla	; Discard Extra DB
	rep #$30		; mode 'AX!'
	plb	; Restore DB
	pla	; Restore DPR
	tcd
	ply	; Restore .Y
	plx	; Restore .X
	pla	; Restore .A
	rti	; Restore .SR/.PC
