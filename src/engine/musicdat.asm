	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       SOUND/MUSIC DATA MODULE                      *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/music.inc"


	if useSOUND != 0

	%section(MUSIC_C)

;
;	* * * * * * *       MUSIC CHUNKS       * * * * * * *
;
_MusicChunks:
	check bankcross off		; chunks are addressed with 24-bit pointers
	incbin "data/RLDATA/MUSIC/MUSIC_C"
	check bankcross full

;
;	* * * * * * *       RELOCATE THE TURBO SOUND DATA POINTERS       * * * * * * *
;
;	(this port) The tables are built for the chunks at $47:0000 (the original
;	link); _MusicChunks may be placed anywhere (4 MB ROMs: in the Super NES
;	ROM, tools/regions.json).
;
_DeCompressTurbo:
	jsl.l DeCompress
	rep #$30		; mode 'AX!'
	phx
	phy
	ldx.w #0
_RMT:
	lda.l _MusicTurboTable+rlsettData+2,x	; Bank of Data Address
	and.w #$00FF
	beq _RMTNext	; Unused entry
	lda.l _MusicTurboTable+rlsettData,x
	clc
	adc.w #(_MusicChunks-$470000)&$FFFF
	sta.l _MusicTurboTable+rlsettData,x
	sep #$20
	lda.l _MusicTurboTable+rlsettData+2,x
	adc.b #((_MusicChunks-$470000)>>16)&$FF
	sta.l _MusicTurboTable+rlsettData+2,x
	rep #$20
_RMTNext:
	txa
	clc
	adc.w #rlsettSize
	tax
	cpx.w #128*rlsettSize
	bcc _RMT
	ply
	plx
	rtl

	endif
