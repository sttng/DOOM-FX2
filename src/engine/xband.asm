	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                     XBAND HARDWARE SUPPORT MODULE                  *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/snesmac.inc"
	incsrc "src/include/xband.inc"


	if useXBAND != 0
	%section(XBAND)

;
;	* * * * * * *       INITIALIZE XBAND HARDWARE       * * * * * * *
;
	; dbr ?
	; dpr 0
InitXBAND:
;
;	>>>   CHECK FOR XBAND HARDWARE   <<<
;
	rep #$20		; mode 'A!'
	lda.l $D0FFB2	; XBAND Hardware Present?
	cmp.w #$4258
	bne IXD900
	lda.l $D0FFB4
	cmp.w #$444E
	bne IXD900	; NO!
;
;	>>>   INITIALIZE XBAND HARDWARE   <<<
;
	if 0 != 0
	sep #$20
	rep #$10		; mode 'aX!'
	phb
	lda.b #bank(FRED)
	pha
	plb
	; dbr ^FRED
	ldx.w #(($13<<8)|$08)	; (EnFixedInternal|EnSafeROM|EnTwoRAM) / (Force)
	stx.w KILL
	ldx.w #((RANDY>>1)>>8)	; MagicAddress = RANDY
	stx.w magic_address+2
	ldx.w #((RANDY>>1)&$FFFF)
	stx.w magic_address
	ldx.w #((XBANDRAM>>6)&$FFFF)	; RAM Base
	stx.w ram_base
	ldx.w #(((XBANDRAM+$10000)>>6)&$FFFF)	; RAM Bound
	stx.w ram_bound
	ldx.w #$8000	; HitEnables (VectorEnable)
	stx.w hit_enables
	ldx.w #(($00<<8)|((%11<<2)|%11))	; (ROMHiBits | RAMHiBits) / (SRAM Protect)
	stx.w snes_control
	lda.b #((XBANDROM>>14)&$FF)	; ROM Base
	sta.w rom_base
	lda.b #(((XBANDROM+$100000)>>14)&$FF)	; ROM Bound
	sta.w rom_bound
	lda.l RANDY	; Hit Magic Address
	plb
	endif

	if !DEBUG != 0
	rep #$20		; mode 'A!'
	lda.w #(($AA<<8)|$FF)	; Enable LEDs (On,On,On)
	sta.w led_data
	lda.w #(12000/2400)	; 2400 Baud
	sta.w baud_count_divisor
	sep #$20		; mode 'a!'
	lda.b #0	; Guard Count = 0
	sta.w guard_count
;	lda	#%00000000			; Modem Control 2
	sta.w modem_control_2
	lda.b #(mc1b_ONESTOP|mc1b_ENABLESTOP|mc1b_BIT8|mc1b_RESETSERIAL|mc1b_ENABLESERIAL)
	sta.w modem_control_1
	lda.b #(mc1b_ONESTOP|mc1b_ENABLESTOP|mc1b_BIT8|mc1b_ENABLESERIAL)
	sta.w modem_control_1
	lda.b #'R'
	sta.w modem_transmit_buffer
	lda.b #'L'
	sta.w modem_transmit_buffer
	endif
IXD900:
	rtl

	endif
