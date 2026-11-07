	arch 65816
	%section(WALLIMGDEF18)
	incbin "data/RLDATA/WALLIMG/BANK18.DEF"
	%section(WALLIMGDEF19)
	incbin "data/RLDATA/WALLIMG/BANK19.DEF"
	%section(WALLIMGDEF1A)
	incbin "data/RLDATA/WALLIMG/BANK1A.DEF"
	%section(WALLIMGDEF1B)
	incbin "data/RLDATA/WALLIMG/BANK1B.DEF"
	%section(WALLIMGDEF1C)
	incbin "data/RLDATA/WALLIMG/BANK1C.DEF"
	%section(WALLIMGDEF1D)
	incbin "data/RLDATA/WALLIMG/BANK1D.DEF"
	%section(WALLIMGDEF1E)
	if canreadfile1("data/RLDATA/WALLIMG/BANK1E.DEF", 0)	; (FX3 wall set: SKY4 needs an extra bank)
	incbin "data/RLDATA/WALLIMG/BANK1E.DEF"
	endif
	%section(WALLIMGDEF1F)
	if canreadfile1("data/RLDATA/WALLIMG/BANK1F.DEF", 0)	; (barrel explosion + PLAY* frames need one more bank)
	incbin "data/RLDATA/WALLIMG/BANK1F.DEF"
	endif
	%section(WALLIMGDEF36)
	if canreadfile1("data/RLDATA/WALLIMG/BANK36.DEF", 0)	; (DOOM II: more sprites)
	incbin "data/RLDATA/WALLIMG/BANK36.DEF"
	endif
	%section(WALLIMGDEF37)
	if canreadfile1("data/RLDATA/WALLIMG/BANK37.DEF", 0)	; (DOOM II: more sprites)
	incbin "data/RLDATA/WALLIMG/BANK37.DEF"
	endif
	%section(WALLIMGDEF3A)
	if canreadfile1("data/RLDATA/WALLIMG/BANK3A.DEF", 0)	; (DOOM II: more sprites)
	incbin "data/RLDATA/WALLIMG/BANK3A.DEF"
	endif
	%section(WALLIMGDEF3B)
	if canreadfile1("data/RLDATA/WALLIMG/BANK3B.DEF", 0)	; (DOOM II: more sprites)
	incbin "data/RLDATA/WALLIMG/BANK3B.DEF"
	endif
	%section(WALLIMGDEF3F)
	if canreadfile1("data/RLDATA/WALLIMG/BANK3F.DEF", 0)	; (DOOM II wall set, wad2gfx.py --map-walls --bank-3f)
	incbin "data/RLDATA/WALLIMG/BANK3F.DEF"
	endif
	%section(WALLIMGDEF3C)
	if canreadfile1("data/RLDATA/WALLIMG/BANK3C.DEF", 0)	; (wad2gfx.py --masked-banks: masked middle textures)
	incbin "data/RLDATA/WALLIMG/BANK3C.DEF"
	endif
	%section(WALLIMGDEF39)
	if canreadfile1("data/RLDATA/WALLIMG/BANK39.DEF", 0)	; (wad2gfx.py --masked-banks: masked middle textures)
	incbin "data/RLDATA/WALLIMG/BANK39.DEF"
	endif
	%section(WALLIMGDEF29)
	if canreadfile1("data/RLDATA/WALLIMG/BANK29.DEF", 0)	; (wad2gfx.py --masked-banks: masked middle textures)
	incbin "data/RLDATA/WALLIMG/BANK29.DEF"
	endif
	%section(WALLIMGDEF23)
	if canreadfile1("data/RLDATA/WALLIMG/BANK23.DEF", 0)	; (wad2gfx.py --masked-banks: masked middle textures)
	incbin "data/RLDATA/WALLIMG/BANK23.DEF"
	endif
	%section(WALLIMGDEF27)
	if canreadfile1("data/RLDATA/WALLIMG/BANK27.DEF", 0)	; (wad2gfx.py --masked-banks: masked middle textures)
	incbin "data/RLDATA/WALLIMG/BANK27.DEF"
	endif
	%section(WALLIMGDEF2B)
	if canreadfile1("data/RLDATA/WALLIMG/BANK2B.DEF", 0)	; (wad2gfx.py --masked-banks: masked middle textures)
	incbin "data/RLDATA/WALLIMG/BANK2B.DEF"
	endif
