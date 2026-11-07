	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                  SUPER NINTENDO HARDWARE CODE MODULE               *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"

	; public InitSNES

	%section(SNES)

	PPUBase = $2100	; Base Address of PPU Hardware
	CPUBase = $4200	; Base Address of CPU Hardware

;
;	* * * * * * *       INITIALIZE SNES HARDWARE       * * * * * * *
;
	; dbr ?
	; dpr 0
InitSNES:
	sep #$30		; mode 'ax!'
	phd	; Save .DP
	pea.w PPUBase	; Set .DP to Base of PPU Hardware
	pld
	; dpr PPUBase
;
	ldx.b #$33
ClearSnesLoop:
	stz.b PPUBase-PPUBase,x	; Clear PPU Hardware $2101-$2133
	stz.b PPUBase-PPUBase,x	; (twice for the write-twice registers)
	cpx.b #$0C
	bcs NextClearSnes
	stz.w CPUBase+1,x	; Clear CPU Hardware $4202-$420C
NextClearSnes:
	dex
	bne ClearSnesLoop
;
;	>>>   INITIALIZE SPECIFIC PPU REGISTERS   <<<
;
	lda.b #$E0	; FixedColour
	sta.b COLDATA-PPUBase
;
	pld	; Restore .DP
	; dpr ?
	rtl
