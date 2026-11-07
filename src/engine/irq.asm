	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                       INTERRUPT REQUEST MODULE                     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"

	; public InitIRQ,InitNormalIRQ
	; public NormalIRQ

	%section(IRQ)

;
;	* * * * * * *       INITIALIZE NORMAL IRQS       * * * * * * *
;
	; dbr ?
	; dpr 0
InitNormalIRQ:
	sep #$20
	rep #$10		; mode 'aX!'
	ldx.w #lo16(NormalIRQ)	; NORMAL IRQ Code
	lda.b #bank(NormalIRQ)
;
;	* * * * * * *       INITIALIZE IRQ       * * * * * * *
;
;	!!!   DANGER!!!   FALLS THROUGH FROM ABOVE!!!
;
	; dbr ?
	; dpr 0
	; mode 'aX'
InitIRQ:
	sta.w GSUIRQRAM+3
	lda.b #$5C	; JML
	sta.w GSUIRQRAM+0
	stx.w GSUIRQRAM+1	; Save pointer to IRQ Code
	rep #$20		; mode 'A!'
	bit.w _TIMEUP	; Clear Pending Interrupts
;	cli				; Enable Interrupts
	rtl

;
;	* * * * * * *       NORMAL IRQ CODE       * * * * * * *
;
	; dpr ?
	; dbr ?
NormalIRQ:
	rep #$20		; mode 'A!'
	pha	; Save .A
	sep #$20		; mode 'a!'
	lda.l _TIMEUP	; Clear IRQ Flag
	rep #$20		; mode 'A!'
	pla	; Restore .A
	rti	; Restore .SR/.PC
