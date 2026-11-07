	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   R A G E                        *
;*                                                                    *
;*                   SAVE GAMES (battery backed GSU RAM)              *
;*                                                                    *
;**********************************************************************
;
;	(this port) Saving works like the PC version (three slots here), each
;	holding the whole state of the level being played (sectors, doors and
;	lifts, every object and monster, line flags, the player, the automap)
;	plus the player's inventory, skill and level time.
;
;	The cartridge's GSU RAM (128 KB) is battery backed (cartridge type
;	$15, as Yoshi's Island).  The top of bank $71 ($71:D000-$FFFF, 12 KB)
;	is reserved for saves: the level RAM image at $71:0000 ends below
;	RAMIMAGEEND (EXMYMAC), the walls' band buffer and colour maps above it
;	below SAVEBASE (rlram7.asm).  A save holds the level blocks XORed with the freshly set-up
;	level (_SaveXor) and the RL variables and WRAM part as they are, packed
;	with a small LZ77 (about 1-3 KB per save); the slots are stored back to back.
;
;	SAVEBASE+0	"DSAV"
;	SAVEBASE+4	build id (a save only loads into the ROM build that wrote it)
;	SAVEBASE+8	SAVESLOTS (3) * { size.w, level.b, skill.b, checksum.w, rawsize.w }
;	SAVEDATA	slot data, slot 0 first
;
;	Packed format: $01-$7F n = n literal bytes follow;
;	$80+(len-3), dist.b = copy len (3-66) bytes from dist (1-255) bytes back;
;	$C0+(len-3), dist.w = the same with a 16-bit distance; $00 = end.
;
;	All routines are called with jsl at power-on, from the menus or between
;	levels (the GSU is stopped, the CPU owns the GSU RAM).  They use
;	Temp..Temp4 and the work areas of savegame.inc (WRAM $7E:6000-$7E:F01F,
;	SaveComp in bank $7F), which are not used while a level runs.
;
	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/savegame.inc"
	incsrc "src/buildid.inc"

	%section(SAVEGAME)

;
;	* * * * * * *       WHAT IS SAVED       * * * * * * *
;
;	dl address / dw length.  The WRAM part comes first: it is restored
;	before the level is started, the GSU RAM part after it.
;
_SaveBlocks:
	dl Level
	dw 2
	dl _PlayerBullets	; Bullets..BackPack (inventory at level start)
	dw (_PlayerBackPack+2)-_PlayerBullets
	dl _SkillLevel
	dw 2
	dl ScoreSecret
	dw 2
	dl PlayerLevelCount	; Level time
	dw (PlayerLevelTime+2)-PlayerLevelCount
_SaveBlocksGSU:
	dl RAM7AStart	; RL variables: player, weapons, counters, EM pointers
	dw RAM7BEnd-RAM7AStart
	dl _RLSectorData	; Sector data (heights, lights, object lists), movable + fixed objects
	dw _RLVertexes-_RLSectorData
	dl _RLTasks	; Tasks + line flags (used switches, automap)
	dw _RLLineRLCounts-_RLTasks
	dl _RLPlatTasks	; Platforms, toggles, movable object list
	dw RAM7DEnd-_RLPlatTasks
	dl 0
	!SaveRawWRAM = (2+((_PlayerBackPack+2)-_PlayerBullets)+2+2+((PlayerLevelTime+2)-PlayerLevelCount))
	!SaveRawSize = (!SaveRawWRAM+(RAM7BEnd-RAM7AStart)+(_RLVertexes-_RLSectorData)+(_RLLineRLCounts-_RLTasks)+(RAM7DEnd-_RLPlatTasks))
	assert !SaveRawSize <= SaveRawMax, "save state does not fit SaveRaw"

;
;	* * * * * * *       INITIALIZE (power on / reset)       * * * * * * *
;
;	A RAM that does not hold our header (new battery, other ROM build)
;	is formatted: every slot empty.
;
SaveInit:
	php
	rep #$30		; mode 'AX!'
	lda.w #0
	sta.l SaveLoadPending
	sta.l SaveSavePending	; (WRAM is random at power-on)
	sta.l SaveMsgPending
;
;	>>>   CLEAR THE REST OF THE GSU RAM ($70:0000-$71:CFFF)   <<<
;	(it is battery backed: without this the engine would start with the
;	variables of the last session, e.g. the screen size, instead of zeros)
;
	tax
-
	sta.l $700000,x
	inx
	inx
	bne -
-
	sta.l $710000,x
	inx
	inx
	cpx.w #(SAVEBASE&$FFFF)
	bcc -
	lda.l SAVEBASE+0
	cmp.w #$5344	; "DS"
	bne .format
	lda.l SAVEBASE+2
	cmp.w #$5641	; "AV"
	bne .format
	lda.l SAVEBASE+4
	cmp.w #(!BUILDID&$FFFF)
	bne .format
	lda.l SAVEBASE+6
	cmp.w #((!BUILDID>>16)&$FFFF)
	beq .ok
.format:
	ldx.w #$3E
	lda.w #0
-
	sta.l SAVEBASE,x
	dex
	dex
	bpl -
	lda.w #$5344
	sta.l SAVEBASE+0
	lda.w #$5641
	sta.l SAVEBASE+2
	lda.w #(!BUILDID&$FFFF)
	sta.l SAVEBASE+4
	lda.w #((!BUILDID>>16)&$FFFF)
	sta.l SAVEBASE+6
.ok:
	plp
	rtl

;
;	* * * * * * *       SAVE GAME (first part)       * * * * * * *
;
;	.A = slot (0-2).  Packs the state into SaveComp (bank $7F, which the
;	level set-up does not touch) and marks the save as pending; returns
;	.C = 0, and the menu restarts the level as Load Game does.  .C = 1:
;	the state does not pack into SaveComp (not saved).
;
;	A save stores what changed since the level started: after the level
;	is set up again (rage.asm RAGE5000), SaveRestore XORs the fresh level
;	state into the saved one, packs that (mostly zeros: 1-3 KB instead of
;	3-10 KB) into the slot and XORs it back, so the game goes on exactly
;	as after loading that save.  Loading XORs it over the fresh level.
;
SaveGame:
	php
	phb
	rep #$30		; mode 'AX!'
	and.w #$00FF
	sta.b Temp4	; (TEMP4) = slot
	pea.w $7E7E
	plb
	plb
	; dbr $7E
	jsr.w _SaveGather	; SaveRaw = state
	jsr.w _SaveCompress	; SaveComp = packed state
	bcs .full	; (more than SaveComp holds)
	lda.b Temp4
	inc a
	sta.l SaveSavePending	; slot+1: finish once the level is set up again
	plb
	plp
	clc
	rtl
.full:
	plb
	plp
	sec
	rtl

;
;	* * * * * * *       SAVE GAME (second part, before the level restarts)       * * * * * * *
;
;	rage.asm (Load Game exit, before the level is set up again), saving or
;	loading: the level blocks _SaveXor compares are cleared, so the bytes
;	the level set-up does not write (sectors, objects, tasks and line
;	flags past the level's own, idle platforms/toggles) are the same zeros
;	when the save is made and when it is loaded.  A pending save then puts
;	the WRAM part of the saved state back, as LoadGame does, so the level
;	is set up from the same inventory/skill as when this save is loaded.
;
SavePrepare:
	php
	phb
	rep #$30		; mode 'AX!'
	pea.w $7E7E
	plb
	plb
	; dbr $7E
	lda.l SaveSavePending
	ora.l SaveLoadPending
	beq .none
	jsr.w _SaveClear
	lda.l SaveSavePending
	beq .none
	jsr.w _SaveCompSrc
	jsr.w _SaveDecompress	; SaveRaw = state (SaveComp)
	ldx.w #0
	ldy.w #0
	lda.w #(_SaveBlocksGSU-_SaveBlocks)
	sta.b Temp3+6
	jsr.w _SaveScatter	; the WRAM blocks
.none:
	plb
	plp
	rtl

;
;	>>>   SLOT (Temp4) = SaveComp, (Temp+6) bytes; .C = 1 no room   <<<
;
_SaveWriteSlot:
;
;	>>>   ROOM?   <<<
;
	jsr.w _SaveSlotInfo	; (Temp3) offset, (Temp3+2) old size, (Temp3+4) total
	lda.b Temp3+4	; total - old + new <= capacity?
	sec
	sbc.b Temp3+2
	clc
	adc.b Temp+6
	bcs .full
	cmp.w #(SAVEEND-SAVEDATA)+1
	bcc .room
.full:
	sec
	rts
.room:
;
;	>>>   MOVE THE SLOTS BEHIND THIS ONE   <<<
;
	lda.b Temp3	; tail = [offset+old, total)
	clc
	adc.b Temp3+2
	sta.b Temp2	; (TEMP2) = tail source
	lda.b Temp3
	clc
	adc.b Temp+6
	sta.b Temp2+2	; (TEMP2+2) = tail destination
	lda.b Temp3+4
	sec
	sbc.b Temp2
	sta.b Temp2+4	; (TEMP2+4) = tail length
	beq .copy
	lda.b Temp2+2
	cmp.b Temp2
	beq .copy
	bcc .down
;	>>>   TAIL MOVES UP: COPY FROM THE END   <<<
	lda.b Temp2
	clc
	adc.b Temp2+4
	tax	; X = source end
	lda.b Temp2+2
	clc
	adc.b Temp2+4
	tay	; Y = destination end
-
	dex
	dey
	sep #$20
	lda.l SAVEDATA,x
	phx
	tyx
	sta.l SAVEDATA,x
	plx
	rep #$20
	dec.b Temp2+4
	bne -
	bra .copy
;	>>>   TAIL MOVES DOWN: COPY FROM THE START   <<<
.down:
	ldx.b Temp2
	ldy.b Temp2+2
-
	sep #$20
	lda.l SAVEDATA,x
	phx
	tyx
	sta.l SAVEDATA,x
	plx
	rep #$20
	inx
	iny
	dec.b Temp2+4
	bne -
;
;	>>>   COPY THE NEW SAVE, CHECKSUM   <<<
;
.copy:
	ldx.w #0
	ldy.b Temp3	; destination offset
	stz.b Temp2+6	; checksum
-
	lda.l SaveComp,x
	and.w #$00FF
	pha
	clc
	adc.b Temp2+6
	sta.b Temp2+6
	pla
	phx
	tyx
	sep #$20
	sta.l SAVEDATA,x
	rep #$20
	plx
	inx
	iny
	cpx.b Temp+6
	bcc -
;
;	>>>   SLOT HEADER   <<<
;
	lda.b Temp4	; slot*8
	asl a
	asl a
	asl a
	tax
	lda.b Temp+6
	sta.l SAVEBASE+8+0,x	; size
	lda.l _SkillLevel	; level / skill
	xba
	and.w #$FF00
	sta.b Temp2
	lda.l Level
	and.w #$00FF
	ora.b Temp2
	sta.l SAVEBASE+8+2,x
	lda.b Temp2+6
	sta.l SAVEBASE+8+4,x	; checksum
	lda.w #!SaveRawSize
	sta.l SAVEBASE+8+6,x	; raw size
	clc
	rts

;
;	* * * * * * *       LOAD GAME (first part)       * * * * * * *
;
;	.A = slot.  Checks and unpacks the slot and restores the WRAM part
;	(level#, inventory, skill, secret flag, time).  Returns .C = 1 if the slot is empty
;	or damaged.  The caller then starts the level; SaveRestore copies the
;	GSU RAM part over it.
;
LoadGame:
	php
	phb
	rep #$30		; mode 'AX!'
	and.w #$00FF
	sta.b Temp4
	pea.w $7E7E
	plb
	plb
	; dbr $7E
	jsr.w _SaveUnpack
	bcs .bad
	ldx.w #0
	ldy.w #0
	lda.w #(_SaveBlocksGSU-_SaveBlocks)
	sta.b Temp3+6
	jsr.w _SaveScatter	; restore the WRAM blocks
	lda.b Temp4
	inc a
	sta.l SaveLoadPending	; slot+1: restore the rest once the level is set up
	plb
	plp
	clc
	rtl
.bad:
	plb
	plp
	sec
	rtl

;
;	* * * * * * *       LOAD GAME (second part)       * * * * * * *
;
;	Called after _RLInitLevel.  A pending save: the state XORed with the
;	fresh level goes to its slot, then the state is put back.  A pending
;	load: unpacks the slot again (the level set-up may have used the WRAM),
;	XORs the level blocks over the fresh level and copies the RL variables.
;
SaveRestore:
	php
	phb
	rep #$30		; mode 'AX!'
	pea.w $7E7E
	plb
	plb
	; dbr $7E
	lda.l SaveSavePending
	beq .load
;
;	>>>   SAVE: STATE XOR FRESH LEVEL -> SLOT, THEN THE STATE BACK   <<<
;
	dec a
	sta.b Temp4
	lda.w #0
	sta.l SaveSavePending
	jsr.w _SaveCompSrc
	jsr.w _SaveDecompress	; SaveRaw = state
	stz.b Temp3	; SaveRaw ^= GSU RAM (the fresh level)
	jsr.w _SaveXor
	jsr.w _SaveCompress	; SaveComp = packed changes
	bcs .nofit
	jsr.w _SaveWriteSlot
.nofit:
	lda.w #0
	rol a
	pha	; 1 = no room
	lda.w #1	; GSU RAM ^= SaveRaw: the state again
	sta.b Temp3
	jsr.w _SaveXor
	jsr.w _SaveRLVars
	pla
	inc a
	sta.l SaveMsgPending	; 1 = saved, 2 = no room (SaveMessage)
	bra .end
;
;	>>>   LOAD: CHANGES XOR FRESH LEVEL   <<<
;
.load:
	lda.l SaveLoadPending
	beq .end
	dec a
	sta.b Temp4
	lda.w #0
	sta.l SaveLoadPending
	jsr.w _SaveUnpack
	bcs .end
	lda.w #1	; GSU RAM ^= SaveRaw
	sta.b Temp3
	jsr.w _SaveXor
	jsr.w _SaveRLVars
.end:
	plb
	plp
	rtl

;
;	* * * * * * *       SAVE MESSAGE       * * * * * * *
;
;	rlmain.asm, once the GSU has set up the level (which clears the
;	message): "GAME SAVED." or "NOT ENOUGH ROOM TO SAVE." after a save.
;
SaveMessage:
	php
	rep #$30		; mode 'AX!'
	lda.l SaveMsgPending
	beq .end
	cmp.w #1
	bne .full
	lda.w #lo16(GAMESAVEDMSGA)	; "GAME SAVED."
	ldx.w #lo16(GAMESAVEDMSGB)
	ldy.w #lo16(NULL)
	bra .msg
.full:
	lda.w #lo16(NOROOMMSGA)	; "NOT ENOUGH ROOM TO SAVE."
	ldx.w #lo16(NOROOMMSGB)
	ldy.w #lo16(NOROOMMSGC)
.msg:
	sta.l MsgDataA
	txa
	sta.l MsgDataB
	tya
	sta.l MsgDataC
	lda.w #(3*60)	; Display Message for 3 Seconds
	sta.l MsgCount
	lda.w #0
	sta.l SaveMsgPending
.end:
	plp
	rtl

;
;	* * * * * * *       SLOT TEXT       * * * * * * *
;
;	.A = slot.  Writes "E1M3 TOXIN REFINERY" or "EMPTY SLOT" to
;	SaveText (zero terminated, at most 26 characters).  ExMy is
;	Level/9+1, Level mod 9+1; the DOOM II level sets (!RLMAP07 set)
;	show "MAP01 ENTRYWAY" (level n = MAPn+1).
;
	if !RLMAP07 != 0
	SVNAMEOFS = 6	; "MAP01 " + name
	else
	SVNAMEOFS = 5	; "E1M3 " + name
	endif
SaveSlotText:
	php
	rep #$30		; mode 'AX!'
	and.w #$00FF
	asl a
	asl a
	asl a
	tax
	lda.w #0
	sta.l SaveText+26
	lda.l SAVEBASE+8+0,x	; size
	bne .used
	ldx.w #0
-
	lda.l _SaveEmptyText,x
	sta.l SaveText,x
	inx
	inx
	cpx.w #12
	bcc -
	plp
	rtl
.used:
	lda.l SAVEBASE+8+2,x	; level
	and.w #$00FF
	sta.b Temp
	if !RLMAP07 != 0
;	(level n is MAPn+1 -> "MAP01 ")
	inc a
	ldy.w #'0'	; Tens
-
	cmp.w #10
	bcc +
	sbc.w #10
	iny
	bra -
+
	clc
	adc.w #'0'	; Ones
	sep #$20
	sta.l SaveText+4
	tya
	sta.l SaveText+3
	lda.b #'M'
	sta.l SaveText+0
	lda.b #'A'
	sta.l SaveText+1
	lda.b #'P'
	sta.l SaveText+2
	lda.b #' '
	sta.l SaveText+5
	rep #$20
	else
	ldy.w #'1'	; Episode
-
	cmp.w #9
	bcc +
	sbc.w #9
	iny
	bra -
+
	clc
	adc.w #'1'	; Mission
	sep #$20
	sta.l SaveText+3
	tya
	sta.l SaveText+1
	lda.b #'E'
	sta.l SaveText+0
	lda.b #'M'
	sta.l SaveText+2
	lda.b #' '
	sta.l SaveText+4
	rep #$20
	endif
	ldx.w #0	; find the level name
	ldy.b Temp
.skip:
	dey
	bmi .found
.skip2:
	lda.l EMNames,x
	inx
	and.w #$00FF
	bne .skip2
	bra .skip
.found:
	txa	; (Temp2) = long pointer to the name
	clc
	adc.w #EMNames&$FFFF
	sta.b Temp2
	sep #$20
	lda.b #bank(EMNames)
	sta.b Temp2+2
	ldy.w #0
-
	tyx
	lda.b [Temp2],y
	sta.l SaveText+SVNAMEOFS,x
	beq .end
	iny
	cpy.w #(26-SVNAMEOFS)	; (SaveText+26 ends the text)
	bcc -
.end:
	plp
	rtl

_SaveEmptyText:
	db "EMPTY SLOT",0,0

;
;	* * * * * * *       HELPERS (dbr $7E, mode AX)       * * * * * * *
;
;	>>>   STATE -> SaveRaw   <<<
;
_SaveGather:
	ldx.w #0
	ldy.w #0
.blk:
	lda.l _SaveBlocks+0,x
	sta.b Temp
	lda.l _SaveBlocks+1,x
	sta.b Temp+1
	beq .done
	lda.l _SaveBlocks+3,x
	sta.b Temp+4
	phx
-
	sep #$20
	lda.b [Temp]
	tyx
	sta.w SaveRaw&$FFFF,x
	rep #$20
	inc.b Temp
	iny
	dec.b Temp+4
	bne -
	plx
	txa
	clc
	adc.w #5
	tax
	bra .blk
.done:
	rts

;
;	>>>   SaveRaw -> blocks from table index X (raw index Y) up to index (Temp3+6)   <<<
;
_SaveScatter:
.blk:
	lda.l _SaveBlocks+0,x
	sta.b Temp
	lda.l _SaveBlocks+1,x
	sta.b Temp+1
	beq .done
	cpx.b Temp3+6	; last block?
	bcs .done
	lda.l _SaveBlocks+3,x
	sta.b Temp+4
	phx
-
	tyx
	sep #$20
	lda.w SaveRaw&$FFFF,x
	sta.b [Temp]
	rep #$20
	inc.b Temp
	iny
	dec.b Temp+4
	bne -
	plx
	txa
	clc
	adc.w #5
	tax
	bra .blk
.done:
	rts

;
;	>>>   XOR THE LEVEL BLOCKS WITH SaveRaw   <<<
;	(Temp3) = 0: SaveRaw ^= GSU RAM; else GSU RAM ^= SaveRaw.
;	Only the blocks the level set-up fills completely (sectors, objects,
;	tasks, line flags, platforms...); the WRAM part and the RL variables
;	(which also hold renderer temporaries and settings the set-up leaves
;	as they were) are stored as they are (_SaveRLVars).
;
_SaveXor:
	ldx.w #(_SaveBlocksGSU-_SaveBlocks)+5
	ldy.w #(!SaveRawWRAM+(RAM7BEnd-RAM7AStart))
.blk:
	lda.l _SaveBlocks+0,x
	sta.b Temp
	lda.l _SaveBlocks+1,x
	sta.b Temp+1
	beq .done
	lda.l _SaveBlocks+3,x
	sta.b Temp+4
	phx
-
	tyx
	sep #$20
	lda.b Temp3
	bne .mem
	lda.b [Temp]
	eor.w SaveRaw&$FFFF,x
	sta.w SaveRaw&$FFFF,x
	bra .next
.mem:
	lda.w SaveRaw&$FFFF,x
	eor.b [Temp]
	sta.b [Temp]
.next:
	rep #$20
	inc.b Temp
	iny
	dec.b Temp+4
	bne -
	plx
	txa
	clc
	adc.w #5
	tax
	bra .blk
.done:
	rts

;
;	>>>   CLEAR THE LEVEL BLOCKS (those _SaveXor compares)   <<<
;
_SaveClear:
	ldx.w #(_SaveBlocksGSU-_SaveBlocks)+5
.blk:
	lda.l _SaveBlocks+0,x
	sta.b Temp
	lda.l _SaveBlocks+1,x
	sta.b Temp+1
	beq .done
	lda.l _SaveBlocks+3,x
	sta.b Temp+4
	ldy.w #0
	sep #$20
-
	lda.b #0
	sta.b [Temp],y
	iny
	cpy.b Temp+4
	bne -
	rep #$20
	txa
	clc
	adc.w #5
	tax
	bra .blk
.done:
	rts

;
;	>>>   SaveRaw -> RL VARIABLES (the first GSU RAM block, stored as it is)   <<<
;
_SaveRLVars:
	ldx.w #(_SaveBlocksGSU-_SaveBlocks)
	ldy.w #!SaveRawWRAM
	lda.w #(_SaveBlocksGSU-_SaveBlocks)+5
	sta.b Temp3+6
	jmp.w _SaveScatter

;
;	>>>   (Temp2) = long pointer to SaveComp   <<<
;
_SaveCompSrc:
	lda.w #SaveComp&$FFFF
	sta.b Temp2
	sep #$20
	lda.b #bank(SaveComp)
	sta.b Temp2+2
	rep #$20
	rts

;
;	>>>   SLOT OFFSET/SIZE/TOTAL   <<<
;	(Temp3) = offset of slot (Temp4), (Temp3+2) = its size, (Temp3+4) = total
;
_SaveSlotInfo:
	stz.b Temp3
	stz.b Temp3+4
	ldx.w #0
	ldy.w #0
-
	lda.l SAVEBASE+8+0,x
	cpy.b Temp4
	bne +
	sta.b Temp3+2
+
	bcs +	; slots below this one
	pha
	clc
	adc.b Temp3
	sta.b Temp3
	pla
+
	clc
	adc.b Temp3+4
	sta.b Temp3+4
	txa
	clc
	adc.w #8
	tax
	iny
	cpy.w #SAVESLOTS
	bcc -
	rts

;
;	>>>   CHECK AND UNPACK SLOT (Temp4) -> SaveRaw; .C = 1 if bad   <<<
;
_SaveUnpack:
	lda.b Temp4
	cmp.w #SAVESLOTS
	bcs .bad
	jsr.w _SaveSlotInfo
	lda.b Temp3+2	; empty?
	beq .bad
	lda.b Temp4
	asl a
	asl a
	asl a
	tax
	lda.l SAVEBASE+8+6,x	; same state layout?
	cmp.w #!SaveRawSize
	bne .bad
	lda.b Temp3	; (Temp2) = long pointer to the packed data
	clc
	adc.w #SAVEDATA&$FFFF
	sta.b Temp2
	sep #$20
	lda.b #bank(SAVEDATA)
	sta.b Temp2+2
	rep #$20
	ldy.w #0	; checksum
	stz.b Temp2+4
-
	lda.b [Temp2],y
	and.w #$00FF
	clc
	adc.b Temp2+4
	sta.b Temp2+4
	iny
	cpy.b Temp3+2
	bcc -
	lda.l SAVEBASE+8+4,x
	cmp.b Temp2+4
	bne .bad
	jsr.w _SaveDecompress
	bcs .bad
	cpx.w #!SaveRawSize
	bne .bad
	clc
	rts
.bad:
	sec
	rts

;
;	>>>   UNPACK [Temp2] -> SaveRaw, X = unpacked size; .C = 1 if bad   <<<
;
_SaveDecompress:
	ldy.w #0
	ldx.w #0
.next:
	cpx.w #!SaveRawSize+1
	bcs .bad
	lda.b [Temp2],y
	iny
	and.w #$00FF
	beq .end
	cmp.w #$0080
	bcs .match
	sta.b Temp+4	; literals
-
	lda.b [Temp2],y
	sep #$20
	sta.w SaveRaw&$FFFF,x
	rep #$20
	iny
	inx
	dec.b Temp+4
	bne -
	bra .next
.match:
	pha
	and.w #$003F
	clc
	adc.w #3
	sta.b Temp+4	; length
	pla
	cmp.w #$00C0
	lda.b [Temp2],y	; distance
	bcs .long
	and.w #$00FF	; 8-bit distance
	iny
	bra .dist
.long:
	iny
	iny
.dist:
	sta.b Temp+6
	phy
	txa
	sec
	sbc.b Temp+6
	bcc .bad2
	tay
-
	sep #$20
	lda.w SaveRaw&$FFFF,y
	sta.w SaveRaw&$FFFF,x
	rep #$20
	iny
	inx
	dec.b Temp+4
	bne -
	ply
	bra .next
.end:
	clc
	rts
.bad2:
	ply
.bad:
	sec
	rts

;
;	>>>   PACK SaveRaw -> SaveComp, (Temp+6) = packed size   <<<
;
;	Greedy LZ77, 3-byte hash -> last position (4096 entries).
;	(Temp) pos, (Temp+2) literal start, (Temp+6) output index,
;	(Temp2) candidate, (Temp2+2) length, (Temp2+4) distance / run count,
;	(Temp2+6) overflow flag
;
_SaveCompress:
	ldx.w #$1FFE
	lda.w #$FFFF
-
	sta.w SaveHash&$FFFF,x
	dex
	dex
	bpl -
	stz.b Temp
	stz.b Temp+2
	stz.b Temp+6
	stz.b Temp2+6	; overflow flag
.loop:
	lda.b Temp
	clc
	adc.w #3
	cmp.w #!SaveRawSize+1	; at least 3 bytes left?
	bcc +
	jmp.w .done
+
	ldx.b Temp
	lda.w (SaveRaw+1)&$FFFF,x	; hash
	asl a
	asl a
	asl a
	eor.w SaveRaw&$FFFF,x
	and.w #$1FFE
	tay
	lda.w SaveHash&$FFFF,y
	sta.b Temp2
	txa
	sta.w SaveHash&$FFFF,y
	lda.b Temp2
	cmp.w #$FFFF
	beq ._lit
	tay	; Y = candidate, X = pos
	txa	; (a 3-byte match is only worth it with a short distance)
	sec
	sbc.b Temp2
	cmp.w #256
	bcc ._near
	lda.w (SaveRaw+2)&$FFFF,y	; far: needs 4 bytes
	cmp.w (SaveRaw+2)&$FFFF,x
	beq ._near
	jmp.w ._lit
._near:
	lda.w SaveRaw&$FFFF,y
	cmp.w SaveRaw&$FFFF,x
	bne ._lit
	lda.w (SaveRaw+1)&$FFFF,y
	cmp.w (SaveRaw+1)&$FFFF,x
	bne ._lit
	lda.w #3	; match: extend it
	sta.b Temp2+2
	bra .ext
._lit:
	inc.b Temp
	jmp.w .loop
.ext:
	lda.b Temp2+2
	cmp.w #66
	bcs .emit
	clc
	adc.b Temp
	cmp.w #!SaveRawSize
	bcs .emit
	tax
	lda.b Temp2+2
	clc
	adc.b Temp2
	tay
	sep #$20
	lda.w SaveRaw&$FFFF,y
	cmp.w SaveRaw&$FFFF,x
	rep #$20
	bne .emit
	inc.b Temp2+2
	bra .ext
.emit:
	jsr.w .flushlit
	lda.b Temp2+6	; literal run did not fit?
	bne .ovf
	ldx.b Temp+6
	cpx.w #SaveCompMax-4	; room for a token and the END byte?
	bcs .ovf
	lda.b Temp	; distance
	sec
	sbc.b Temp2
	sta.b Temp2+4
	lda.b Temp2+2	; token
	sec
	sbc.w #3
	ora.w #$0080
	ldy.b Temp2+4
	cpy.w #256
	bcc ._short
	ora.w #$0040	; 16-bit distance
	sep #$20
	sta.l SaveComp,x
	rep #$20
	lda.b Temp2+4
	sta.l SaveComp+1,x
	inx
	inx
	inx
	bra ._emitted
._short:
	sep #$20
	sta.l SaveComp,x
	lda.b Temp2+4
	sta.l SaveComp+1,x
	rep #$20
	inx
	inx
._emitted:
	stx.b Temp+6
	lda.b Temp
	clc
	adc.b Temp2+2
	sta.b Temp
	sta.b Temp+2
	jmp.w .loop
.lit:			; (unused: ._lit is the one branched to)
	inc.b Temp
	jmp.w .loop
.done:
	lda.w #!SaveRawSize
	sta.b Temp
	jsr.w .flushlit
	ldx.b Temp+6
	lda.b Temp2+6
	bne .ovf
	lda.w #0
	sep #$20
	sta.l SaveComp,x	; END
	rep #$20
	inx
	stx.b Temp+6
	clc
	rts
.ovf:
	sec	; packed state does not fit SaveComp
	rts
;
;	>>>   LITERALS [Temp+2, Temp) in runs of up to 127 bytes   <<<
;
.flushlit:
	lda.b Temp
	sec
	sbc.b Temp+2
	beq .fl9
	ldx.b Temp+6	; room for a run (128 bytes) + a token + END?
	cpx.w #SaveCompMax-132
	bcc +
	inc.b Temp2+6	; no: overflow
	rts
+
	lda.b Temp
	sec
	sbc.b Temp+2
	cmp.w #128
	bcc +
	lda.w #127
+
	sta.b Temp2+4
	ldx.b Temp+6
	sep #$20
	sta.l SaveComp,x
	rep #$20
	inx
	ldy.b Temp+2
-
	sep #$20
	lda.w SaveRaw&$FFFF,y
	sta.l SaveComp,x
	rep #$20
	inx
	iny
	dec.b Temp2+4
	bne -
	stx.b Temp+6
	sty.b Temp+2
	bra .flushlit
.fl9:
	rts
