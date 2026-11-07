;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*        ASAR SUPPORT MACROS (replace the xa/xl assembler features)  *
;*                                                                    *
;**********************************************************************
;
;	The original sources were assembled with Sculptured Software's
;	Amiga "xa" assembler and "xl" linker.  These macros provide the
;	equivalent functionality for asar:
;
;	  %section(name)	named, re-enterable sections (xl SECTIONs).
;				Placement comes from src/layout.inc
;	  %ds(n)		reserve n bytes (skip in RAM, zero-fill in ROM)
;	  %align_pad(p,n,o)	GSU cache-line alignment: emit p pad bytes
;				(the pad is kept current by tools/fixup.py,
;				an assert checks it)
;	  %<op>_i(n)		GSU "op #n" with a symbolic 4-bit immediate
;	  %LMS/%LM/%SMS/%SM	GSU RAM access with a complex address expr
;
;	Plus asar versions of the original project macros (HALT,
;	HALTGSU, CACHEB/CACHEE, inMAC, otMAC, mvMAC, EXMYMAC ...)
;

includeonce

function lo16(x) = x&$FFFF
function hi16(x) = (x>>8)&$FFFF

;
;	* * * * * * *       SECTIONS       * * * * * * *
;
!cur = none

macro section(name)
	if stringsequal("!cur", "none") == 0
		!{sec_!{cur}_real} #= realbase()
		!{sec_!{cur}_pc} #= pc()
	endif
	!cur = <name>
	org !{sec_<name>_real}
	base !{sec_<name>_pc}
endmacro

macro section_close()
	if stringsequal("!cur", "none") == 0
		!{sec_!{cur}_real} #= realbase()
		!{sec_!{cur}_pc} #= pc()
	endif
	!cur = none
	base off
endmacro

macro ds(n)
	if !{sec_!{cur}_ram} != 0
		skip <n>
	else
		fillbyte $00
		fill <n>
	endif
endmacro

;
;	>>>   GSU CACHE ALIGNMENT   <<<
;
;	align n,o : pad until (pc % n) == o.  The pad count is stored in the
;	source (asar can not size data from forward references); the assert
;	verifies it.  tools/fixup.py (run by tools/build.sh) rewrites stale
;	pads after GSU code changes.
;
macro align_pad(pad, n, o)
	if <pad> > 0
		fillbyte $00
		fill <pad>
	endif
	!__alignpc #= pc()
	assert (!__alignpc-(<o>))%<n> == 0, "GSU align pad out of date (tools/fixup.py)"
endmacro

;
;	>>>   GSU 4-BIT IMMEDIATES WITH SYMBOLIC OPERANDS   <<<
;
macro gsu_imm(prefix, op, n)
	assert <n> >= 0, "GSU immediate out of range"
	assert <n> <= 15, "GSU immediate out of range"
	db <prefix>,<op>|(<n>)
endmacro
macro add_i(n)
	%gsu_imm($3E, $50, <n>)
endmacro
macro sub_i(n)
	%gsu_imm($3E, $60, <n>)
endmacro
macro and_i(n)
	%gsu_imm($3E, $70, <n>)
endmacro
macro mult_i(n)
	%gsu_imm($3E, $80, <n>)
endmacro
macro or_i(n)
	%gsu_imm($3E, $C0, <n>)
endmacro
macro adc_i(n)
	%gsu_imm($3F, $50, <n>)
endmacro
macro bic_i(n)
	%gsu_imm($3F, $70, <n>)
endmacro
macro umult_i(n)
	%gsu_imm($3F, $80, <n>)
endmacro
macro xor_i(n)
	%gsu_imm($3F, $C0, <n>)
endmacro

;
;	>>>   GSU RAM ACCESS WITH COMPLEX ADDRESS EXPRESSIONS   <<<
;
macro LMS(reg, addr)
	!__gsuaddr #= (<addr>)&$FFFF
	lms <reg>,(!__gsuaddr)
endmacro
macro LM(reg, addr)
	!__gsuaddr #= (<addr>)&$FFFF
	lm <reg>,(!__gsuaddr)
endmacro
macro SMS(reg, addr)
	!__gsuaddr #= (<addr>)&$FFFF
	sms (!__gsuaddr),<reg>
endmacro
macro SM(reg, addr)
	!__gsuaddr #= (<addr>)&$FFFF
	sm (!__gsuaddr),<reg>
endmacro

;
;	* * * * * * *       PROJECT MACROS       * * * * * * *
;

;
;	>>>   HALT THE CPU   <<<
;
macro HALT(n)
	if NOAICESE == 0
		brk #<n>
	else
		jsl.l HALTERROR
		db <n>
	endif
endmacro

;
;	>>>   COLOURFLASH   <<<
;
macro COLOURFLASH()
	php
	sep #$30
	lda.b #$0f
	sta.w INIDISP
	lda.b #0
	ldx.b #32
?T:
	stz.w CGADD
	sta.w CGDATA
	sta.w CGDATA
	inc a
	bne ?T
	dex
	bne ?T
	lda.b #$80
	sta.w INIDISP
	plp
endmacro

;
;	>>>   HALT THE GSU   <<<
;
macro HALTGSU(n)
	nop
	iwt r0,#<n>
	if GSUERROR&$FFFF <= $1FE
		sms (GSUERROR&$FFFF),r0
	else
		sm (GSUERROR&$FFFF),r0
	endif
	stop
	nop
endmacro

;
;	>>>   GSU CACHE BLOCKS   <<<
;
macro CACHER()
endmacro

macro CACHEB(name)
	cache
	!__cacheb #= pc()
	assert !__cacheb&$0F == 0, "Cache MisAligned in <name>"
endmacro

macro CACHEE(name)
	!__cachee #= pc()
	if !__cachee-!__cacheb > 512	; (legal, the rest runs from ROM: only slower)
		warn "Cache block <name> is larger than the 512-byte GSU cache"
	endif
	if defined("SHOW_CACHE_SIZES")
		print "Cache block <name> size $", hex(!__cachee-!__cacheb), " from $", hex(!__cacheb), " to $", hex(!__cachee)
	endif
endmacro

macro CACHEP(name)
endmacro

;
;	>>>   IMAGE NUMBER TAGS   <<<
;
macro inMAC(name, count)
	<name> = !in
	!in #= !in+(<count>)
	assert MaxRLImages-!in >= 0, "MAXRLIMAGES INVALID!"
endmacro

;
;	>>>   OBJECT TYPE TAGS   <<<
;
macro otMAC(name)
	<name> = !ot
	!ot #= !ot+1
endmacro

;
;	>>>   VELOCITY TABLES FOR MOVEMENT   <<<
;
macro mvMAC(v)
	dw ((((<v>)*0/10000)<<8)&$FF00)|(((<v>)*10000/10000)&$FF)	; 0
	dw ((((<v>)*3827/10000)<<8)&$FF00)|(((<v>)*9239/10000)&$FF)	; 22.5
	dw ((((<v>)*7071/10000)<<8)&$FF00)|(((<v>)*7071/10000)&$FF)	; 45
	dw ((((<v>)*9239/10000)<<8)&$FF00)|(((<v>)*3827/10000)&$FF)	; 67.5
	dw ((((<v>)*10000/10000)<<8)&$FF00)|((-(<v>)*0/10000)&$FF)	; 90
	dw ((((<v>)*9239/10000)<<8)&$FF00)|((-(<v>)*3827/10000)&$FF)	; 112.5
	dw ((((<v>)*7071/10000)<<8)&$FF00)|((-(<v>)*7071/10000)&$FF)	; 135
	dw ((((<v>)*3827/10000)<<8)&$FF00)|((-(<v>)*9239/10000)&$FF)	; 157.5
	dw (((-(<v>)*0/10000)<<8)&$FF00)|((-(<v>)*10000/10000)&$FF)	; 180
	dw (((-(<v>)*3827/10000)<<8)&$FF00)|((-(<v>)*9239/10000)&$FF)	; 202.5
	dw (((-(<v>)*7071/10000)<<8)&$FF00)|((-(<v>)*7071/10000)&$FF)	; 225
	dw (((-(<v>)*9239/10000)<<8)&$FF00)|((-(<v>)*3827/10000)&$FF)	; 247.5
	dw (((-(<v>)*10000/10000)<<8)&$FF00)|(((<v>)*0/10000)&$FF)	; 270
	dw (((-(<v>)*9239/10000)<<8)&$FF00)|(((<v>)*3827/10000)&$FF)	; 292.5
	dw (((-(<v>)*7071/10000)<<8)&$FF00)|(((<v>)*7071/10000)&$FF)	; 315
	dw (((-(<v>)*3827/10000)<<8)&$FF00)|(((<v>)*9239/10000)&$FF)	; 337.5
endmacro

;
;	>>>   VERSION TAG   <<<
;
macro VERSTAG()
	db 0,"$VER: RL 1.5934 (14.6.95)",0
endmacro

;
;	>>>   EPISODE x, MISSION y LEVEL DATA   <<<
;
macro EXMYMAC(lvl)
;
;	BSP, AREAS, VERTEXES, SEGS, FACES (GamePak ROM, one bank)
;
	%section(<lvl>_A)
<lvl>BSP:
	if !{use<lvl>} != 0
		incbin "data/RLLEV/<lvl>/BSP"
	endif
<lvl>BSPE:
<lvl>AREAS:
	if !{use<lvl>} != 0
		incbin "data/RLLEV/<lvl>/AREAS"
	endif
	assert (<lvl>BSPE-<lvl>BSP)/rlbSize <= MaxRLVisNodes, "<lvl>: too many BSP nodes (MaxRLVisNodes)"
	assert (pc()-<lvl>AREAS)/rlaSize <= MaxRLVisAreas, "<lvl>: too many AREAS (MaxRLVisAreas)"
<lvl>VERTEXES:
	if !{use<lvl>} != 0
		incbin "data/RLLEV/<lvl>/VERTEXES"
	endif
<lvl>VERTEXESE:
<lvl>SEGS:
	if !{use<lvl>} != 0
		incbin "data/RLLEV/<lvl>/SEGS"
	endif
<lvl>SEGSE:
<lvl>FACES:
	if !{use<lvl>} != 0
		incbin "data/RLLEV/<lvl>/FACES"
	endif
;
;	SECTORS, DOORS, STAIRS, FLOORS, CEILINGS, LIFTS
;
	%section(<lvl>_B)
<lvl>SECTORS:
	if !{use<lvl>} != 0
		incbin "data/RLLEV/<lvl>/SECTORS"
	endif
<lvl>SECTORSE:
	if !{use<lvl>} != 0
		dw $524C
	endif
<lvl>DOORS:
	if !{use<lvl>} != 0
		incbin "data/RLLEV/<lvl>/DOORS"
		db $FF
	endif
<lvl>STAIRS:
	if !{use<lvl>} != 0
		incbin "data/RLLEV/<lvl>/STAIRS"
	endif
<lvl>FLOORS:
	if !{use<lvl>} != 0
		incbin "data/RLLEV/<lvl>/FLOORS"
	endif
<lvl>CEILINGS:
	if !{use<lvl>} != 0
		incbin "data/RLLEV/<lvl>/CEILINGS"
	endif
<lvl>LIFTS:
	if !{use<lvl>} != 0
		incbin "data/RLLEV/<lvl>/LIFTS"
	endif
;
;	LEVEL RAM IMAGE: LINES, BLOCKMAP, OBJECTS (+$0000), REJECT; copied to
;	GSU RAM $71:0000 when the level starts (rllevels.asm _RLLoadLevelRAM).
;	Stored in the CPU-only Super NES ROM (the 2 MB builds: the GamePak ROM),
;	assembled for its RAM address.
;
	%section(<lvl>_R)
	check bankcross off	; (layout.py keeps the image inside one 64 KB bank)
<lvl>RIMAGE:
<lvl>LINES:
	if !{use<lvl>} != 0
		incbin "data/RLLEV/<lvl>/LINES"
	endif
<lvl>LINESE:
<lvl>BLOCKMAP:
	if !{use<lvl>} != 0
		incbin "data/RLLEV/<lvl>/BLOCKMAP"
	endif
<lvl>OBJECTS:
	if !{use<lvl>} != 0
		if !useTESTTARGET != 0
			db $c7,$00			; PLAYER1START
			db $20,$04,$e0,$f1,$00,$40
			db $c7,$06			; CACODEMON
			db $20,$04,$e0,$f2,$00,$c0
		endif
		if !useTESTLEVELOBJ != 0
			db $c7,$00			; PLAYER1START
			db $00,$f8,$30,$04,$00,$40	; E1M2 (ChainSaw)
			incbin "data/RLLEV/<lvl>/OBJECTS":8..filesize("data/RLLEV/<lvl>/OBJECTS")
		endif
		if (!useTESTLEVELOBJ|!useTESTTARGET) == 0
			incbin "data/RLLEV/<lvl>/OBJECTS"
		endif
		dw 0
	endif
<lvl>REJECT:
	if !{use<lvl>} != 0
		if !{rejrom<lvl>} == 0
			incbin "data/RLLEV/<lvl>/REJECT"
		endif
	endif
<lvl>RIMAGEE:
	check bankcross full
	assert <lvl>RIMAGEE-<lvl>RIMAGE <= (RAMIMAGEEND&$FFFF), "level RAM image runs into the walls' band buffer and colour maps (savegame.inc)"
;
;	(this port) REJECT in the GamePak ROM instead, when the RAM image would
;	not fit with it (wad2rl.py writes the marker file REJROM, levels.inc
;	rejrom<lvl>).  Its bank is in EMBSP+3 (0 = in the level RAM image).
;
	%section(<lvl>_J)
<lvl>REJECTR:
	if !{use<lvl>} != 0
		if !{rejrom<lvl>} != 0
			incbin "data/RLLEV/<lvl>/REJECT"
		endif
	endif
endmacro

;
;	>>>   LEVEL RAM IMAGE (GSU RAM BANK $71)   <<<
;
;	The engine works in GSU RAM bank $70; the level RAM image (LINES,
;	BLOCKMAP, OBJECTS, REJECT, see EXMYMAC) is in bank $71.
;	RAMB takes bit 0 of the source register.
;	Between %RAMB71() and %RAMB70() only level data may be accessed in RAM
;	(lms/sms/ldw/stw all use RAMBR).
;
macro RAMB71(reg)
	ibt <reg>,#1
	from <reg>
	ramb
endmacro
macro RAMB70(reg)
	ibt <reg>,#0
	from <reg>
	ramb
endmacro

;
;	>>>   POSITION-INDEPENDENT jsr (code that runs both from ROM and copied to WRAM)   <<<
;
macro rcall(label)
	per ?ret-1
	brl <label>
?ret:
endmacro
