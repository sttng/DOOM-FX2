	arch 65816
;**********************************************************************
;*                                                                    *
;*                      P R O J E C T :   R A G E                     *
;*                                                                    *
;*                        BANK00 SLOWCODE MODULE                      *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/snesmac.inc"

	; public RESET0,RESET
	; extern BANK00End


	%section(BANK00)

;
;	* * * * * * *       RESET VECTOR INTERRUPT       * * * * * * *
;
	; dbr ?
	; dpr 0
	if (!DEBUGSCR|(1-ROM)) == 0
HALTERROR:
	endif
RESET0:
	sei
	cld
	clc
	xce
	sep #$30		; mode 'Eax!'
	; Native Mode

;
;	* * * * * * *       MEMORY TEST       * * * * * * *
;
	if !MEMTEST != 0
MemTestC:
	%MEMTESTMAC($C8000)
MemTestD:
	%MEMTESTMAC($D8000)
MemTestE:
	%MEMTESTMAC($E8000)
MemTestF:
	%MEMTESTMAC($F8000)
	%HALT(0)
	endif

	if !DEBUG != 0
	lda.b #$00	; Disable NMIs
	if NOAICESE == 0
	sta.l NMITIMEN_XS
	endif
	sta.l NMITIMEN
	lda.b #$80	; Disable DISPLAY (Prevent Glitch)
	sta.l INIDISP
	jml.l RESET
	endif
;
	if !DEBUG == 0
;	stz	NMITIMEN		; Disable NMIs
	lda.b #$80	; Disable DISPLAY (Prevent Glitch)
	sta.w INIDISP
	jml.l RESET
	endif


	db "Rage/Reality Engine written by Randy Linden.",0
	db "Special thanks to my loving wife, Jodi Harvey.",0


;
;	* * * * * * *       MEMORY TEST MACRO       * * * * * * *
;
	if !MEMTEST != 0
; (the original's MemTestMac macro was not translated: !MEMTEST must stay 0)
	endif

;
;	* * * * * * *       END OF BANK00       * * * * * * *
;
BANK00End:
