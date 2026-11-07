	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                          ENGINE NMI MODULE                         *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"

	; public _RLNMI


	%section(ENGINE)
;
;	* * * * * * *       INITIALIZE REALITY_ENGINE NMIS       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLInitNMI:
	sep #$20
	rep #$10		; mode 'aX!'
	ldx.w #lo16(_RLNMI)	; ENGINE NMI Code
	lda.b #bank(_RLNMI)
	if WIRE != 0
	ldy.w #$81	; ENABLE NMI+JOYREAD (FOR WIRE)
	endif
	if WIRE == 0
	ldy.w #$01	; ENABLE JOYREAD
	endif
	jml.l InitNMI	; Initialize NMIs


	%section(ENGINE_RAMCODE)
;
;	* * * * * * *       REALITY_ENGINE NMI       * * * * * * *
;
	; dbr ?
	; dpr 0
_RLNMI:
	if (WIRE*!DEBUG) != 0
	jsl.l $7FFD00	; MONITOR
	endif
_RLNMI2:
	sep #$20		; mode 'a!'
	pha
	lda.l _RDNMI	; Clear NMI Flag
	if WIRE != 0
	lda.l VBlankCount
	inc a
	sta.l VBlankCount
	endif
	pla
	rti
