	arch 65816
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                      VECTORS/REGISTRATION MODULE                   *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"


	if !DEBUG*(1-NOAICESE) == 0
;
;	* * * * * * *       REGISTRATION DATA       * * * * * * *
;
	%section(REGISTRATION)

	db "5D"	; Maker Code	($015D)
	db "AD8E"	; Game Code	($AD8E)
	db $00,$00,$00,$00,$00,$00,$00	; Fixed Value $00
	db $07	; Expansion RAM (GSU RAM 128 KB: $70 engine, $71 level RAM image + saves)
	db $00	; Special Version
	db $00	; Cartridge SubNumber
;
	db "DOOM                 "	; Title Registration
	db $20	; Map Mode          ($20)
	db $15	; Cartridge Type    (ROM+SFX+RAM+BATTERY: save games in GSU RAM)
	db $0B	; CPU ROM Size      (16MBits; tools/romcheck.py writes the padded size, $0C for 4 MB)
	db $00	; CPU RAM Size      (0KBytes)
	db $01	; Destination Code  (North America)
	db $33	; Fixed Value $33
	db 0	; Mask ROM Version  (0)
	dw $FFFF	; Complement Check	(both written by tools/romcheck.py)
	dw $0000	; CheckSum


;
;	* * * * * * *       65816 NATIVE VECTORS       * * * * * * *
;
	%section(VECTORS0)
	dw GSUCOPRAM	; COP
	dw GSUBRKRAM	; BRK
	dw GSUABORTRAM	; ABORT
	dw GSUNMIRAM	; NMI
	dw $4C52	; RESERVED
	dw GSUIRQRAM	; IRQ
;
;	* * * * * * *       6502 EMULATION VECTORS       * * * * * * *
;
	%section(VECTORS1)
	dw RESET0	; RESET
	endif
