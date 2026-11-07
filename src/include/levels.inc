includeonce
;
;	* * * * * * *       LEVEL LIST       * * * * * * *
;
;	The level list belongs to the data set: data/RLLEV/levels.inc defines
;	!NUMLEVELS, !lvlN (name = data directory and label prefix; N = Level
;	number, E1M1 = 0), !lvlsongN, !lvlnameN, !lvlnextN, !lvlsecretN,
;	!use<name>, the !RLMAX... limits and !RLVERTEXBASE (the _RLVertexes
;	address the vertex pointers in LINES/SEGS were built for).
;
	incsrc "../../data/RLLEV/levels.inc"
;
;	DOOM II monsters (data set: !RLDOOM2MONSTERS = 1, wad2gfx.py --doom2-monsters):
;	their object types after the Spider Demon, their images in image page 1.
;	!RLMAP07/30/32: EMNUM of the slots with the boss specials (wadlevels.py
;	--profile doom2: mission.B/sky.B; 0 = none)
;
	if not(defined("RLDOOM2MONSTERS"))
	!RLDOOM2MONSTERS = 0
	endif
;
;	Wall format 2 (data set: RLDATA/WALLS/WALLS.FMT exists; wad2gfx.py convert
;	--map-walls, DOOM II): faces name walls by index (0-255) instead of index*2,
;	TEXTURE2.TBL holds alternate indexes, and each wall header has a third byte,
;	the column step (+$80: half height): column pointer offset =
;	((u AND modulo) * step) >> 2 with step 12, 6 or 3 (every column, every 2nd,
;	every 4th stored; the modulo has the skipped low bits cleared)
;	(rltracew5.asm).  Also set for wall format 3.
;
	if canreadfile1("data/RLDATA/WALLS/WALLS.FMT", 0)
	!RLWALLFMT2 = 1
	else
	!RLWALLFMT2 = 0
	endif
;
;	Visibility table in the GamePak ROM (this port): data/RLLEV/<level>/REJROM
;	exists (wad2rl.py: the level RAM image would not fit with it)
;
	!__k #= 0
	while !__k < !NUMLEVELS
	if canreadfile1("data/RLLEV/!{lvl!__k}/REJROM", 0)
	!{rejrom!{lvl!__k}} = 1
	else
	!{rejrom!{lvl!__k}} = 0
	endif
	!__k #= !__k+1
	endwhile
;
;	Masked middle textures (IMAGES/MASKED.TBL exists; wad2gfx.py --map-walls):
;	two-sided lines with seg flag $08 (rlgfClear) have a see-through middle
;	texture (grates, bars), face bytes 4/5 = MASKED.TBL index and y offset; the
;	texture is an image, drawn with the objects (rlvsegs4.asm, rltraceo.asm)
;
	if canreadfile1("data/RLDATA/IMAGES/MASKED.TBL", 0)
	!RLMASKED = 1
	else
	!RLMASKED = 0
	endif
;
;	Wall format 3 (WALLS.FMT holds "3"; wad2gfx.py --vq, tools/wallvq.py): wall
;	format 2's wall indexes, but every wall is blocks of 2x4 texels, one index
;	byte per block into a codebook of 256 blocks (2048 bytes) in the wall's bank.
;	Header: height, modulo, flags ($80 half size: every 2nd column and row),
;	bank, codebook address, index address, index bytes per block column
;
	!RLWALLFMT3 = 0
	if !RLWALLFMT2
	if readfile1("data/RLDATA/WALLS/WALLS.FMT", 0) == $33
	!RLWALLFMT3 = 1
	endif
	endif
	if not(defined("RLMAP07"))
	!RLMAP07 = 0
	endif
	if not(defined("RLMAP30"))
	!RLMAP30 = 0
	endif
	if not(defined("RLMAP32"))
	!RLMAP32 = 0
	endif
