# DOOM for the Super Nintendo / Super FX 2 (GSU-2) with The Ultimate DOOM
#
# One ROM per game (after make data; each in its own copy gamedata-<game>, written to roms/):
#   make doomfx WAD=<DOOM.WAD>          make doom2 WAD=<DOOM2.WAD>        make tnt WAD=<TNT.WAD>
#   make plutonia WAD=<PLUTONIA.WAD>    make shareware WAD=<DOOM1.WAD>
#   make doom2demo WAD=<DOOM2.WAD>      (after make doom2: the DOOM II demo, MAP01-MAP03)
#
# The steps:
#   make data FX3=<THE ULTIMATE DOOM.sfc> WAD=<DOOM.WAD> [SRC=<DOOM-FX source>] [LEARN=1]
#                        - the data set (tools/mkdata.py) -> gamedata-fx3, linked as data; the DOOM-FX
#                          source files it needs come from tools/doomfx-src unless SRC= names another copy
#                          (the WAD conversion rules from tools/rules; LEARN=1: learned from the cartridge)
#   make                 - assemble build/doom.sfc (tools/build.sh)
#   make wadlevels WAD=<DOOM.WAD> [PWAD=<x.wad>] [MAPS="E1M1 E1M2"] [PROFILE=doom2]
#                        - levels converted from a WAD (tools/wadlevels.py, tools/wad2rl.py), then build
#                          (ZokumBSP rebuilds the nodes of every map)
#   make fx3levels       - back to the FX3 levels
#   make wadgfx WAD=<DOOM.WAD> [PWAD=<x.wad>]
#                        - walls and sprites converted from a WAD (tools/wad2gfx.py), then build
#   make fx3gfx          - back to the cartridge walls and sprites
#   make wadart WAD=<DOOM.WAD> [PWAD=<x.wad>]
#                        - title screen, menus and fonts from a WAD (tools/wad2art.py), then build
#   make fx3art          - back to the cartridge title, menus and fonts
#   make wadsfx WAD=<DOOM.WAD> [PWAD=<x.wad>] [FULL=1]
#                        - sound effects converted from a WAD (tools/wad2soundfx.py), then build
#   make fx3sfx          - back to the cartridge sound effects
#   make doom2set WAD=<DOOM2.WAD|TNT.WAD|PLUTONIA.WAD> [NAMES=tnt|plutonia] [BANK3F=n] [MASKED=n]
#              [MASKEDBANKS=3C,..] [MASKEDMAPS=MAP01,..] [WALLS=vq|rle]
#                        - DOOM II / TNT / Plutonia on a copy of a data set (see the doom2set target)
#   make swset WAD=<DOOM1.WAD>
#                        - the shareware set (Episode 1, 2 MB) on a copy of a DOOM data set
#   make demo WAD=<DOOM2.WAD>
#                        - DOOM II demo: MAP01-MAP03, 2 MB ROM, with the WAD's music converted
#                          (on a copy of a DOOM II data set)
#   make wadmusic WAD=<x.WAD>
#                        - the WAD's music (title, intermission, the levels' songs) converted for
#                          the SPC700 driver (tools/music/wad2music.py), then build
#   make skypng SKY=<1-4> PNG=<128x128.png>
#                        - a picture as one of the skies (tools/skypng.py; after wadgfx, doom2, shareware), then build
#   make clean           - remove build/;  make distclean: also data, gamedata-* and roms/
#
# wadart, fx3art, doom2set and swset then put in the retouched Pause/Save/Load menus
# (tools/menus/*.png via tools/menus.py retouch; PNGMENUS= leaves them out).
# The WAD levels (wadlevels, doom2set, swset) need ZokumBSP: ZOKUMBSP=<path> if it is not on the PATH.
#
PYTHON ?= python3
ZOKUMBSP ?= zokumbsp
PNGMENUS ?= 1
MENUS = $(if $(PNGMENUS),$(PYTHON) tools/menus.py retouch --data data,@true)

.PHONY: doomfx doom2 tnt plutonia shareware doom2demo skypng swset demo doom2set all rom data wadlevels fx3levels wadgfx fx3gfx wadart fx3art wadsfx fx3sfx wadmusic clean distclean

all: rom

rom:
	@test -e data/RLLEV/levels.inc || { echo "Game data missing - run: make data FX3=... WAD=..."; exit 1; }
	@mkdir -p build
	bash tools/build.sh

data:
	$(PYTHON) tools/mkdata.py --fx3 "$(FX3)" --wad "$(WAD)" $(if $(SRC),--src "$(SRC)") $(if $(LEARN),--learn) --out gamedata-fx3
	ln -sfn gamedata-fx3 data

wadlevels:
	@test -n "$(WAD)" || { echo "usage: make wadlevels WAD=<DOOM.WAD> [PWAD=<x.wad>] [MAPS=...]"; exit 1; }
	@mkdir -p build
	$(PYTHON) tools/wadlevels.py --wad "$(WAD)" $(if $(PWAD),--wad "$(PWAD)") --zokumbsp "$(ZOKUMBSP)" $(if $(PROFILE),--profile $(PROFILE)) $(MAPS)

# DOOM II / TNT / Plutonia: levels (MAP01-MAP32), walls, sprites, super shotgun, title/menus and
# sound effects from the WAD into the data set, then build (tools/wadlevels.py does).  Work on a copy
# of the data set; make fx3levels fx3gfx fx3art fx3sfx goes back.  NAMES: level names (default doom2).
# BANK3F: bytes of GamePak bank $3F for wall strips (empty: none, the levels get it; Plutonia)
BANK3F ?= 0x7E00
# MASKED: bytes of strips for the middle textures of two-sided lines (grates, bars, windows; drawn
# masked, also those without holes).  The default suits DOOM II (no bank to spare: the walls give
# up the rest); TNT and Plutonia use MASKED=65536 with MASKEDBANKS (see the README).
# MASKEDBANKS: GamePak banks filled with them first (of 3C 39 29 23 27 2B: the ones the set's levels
# leave emptiest; TNT 3C, Plutonia 29)
# MASKEDMAPS: masked middle textures for these maps only (the ones that fit; TNT and Plutonia)
MASKED ?= 49152
MASKEDBANKS ?=
MASKEDMAPS ?=
# WALLS: vq = wall format 3, 252 walls as 2x4 texel blocks from codebooks (tools/wallvq.py);
#        rle = wall format 2, 128 walls as run-length strips
WALLS ?= vq
doom2set:
	@test -n "$(WAD)" || { echo "usage: make doom2set WAD=<DOOM2.WAD or TNT.WAD> [NAMES=tnt|plutonia] [BANK3F=] [MASKED=n] [MASKEDBANKS=3C,27] [WALLS=vq|rle]"; exit 1; }
	$(PYTHON) tools/wad2gfx.py convert --data data --wad "$(WAD)" --doom2-monsters --bank-1f --extra-banks --map-walls \
		$(if $(BANK3F),--bank-3f --bank-3f-size $(BANK3F)) --slots-by likeness --boost tools/doom2_wallboost.json \
		--masked-opaque --masked-budget $(MASKED) $(if $(MASKEDBANKS),--masked-banks "$(MASKEDBANKS)") $(if $(MASKEDMAPS),--masked-maps "$(MASKEDMAPS)") \
		$(if $(filter rle,$(WALLS)),--half-height --half-iter 3 --restep --target-blur 0.5 --dat-budget 40000 --wall-slots 128,--vq --wall-slots 252)
	$(PYTHON) tools/wad2cut.py --data data --wad "$(WAD)"
	@test -e data/wad2art.json || $(PYTHON) tools/wad2art.py learn --data data
	$(PYTHON) tools/wad2art.py convert --data data --wad "$(WAD)" --interpic --level-names --cart skill
	$(MENUS)
	$(PYTHON) tools/wad2soundfx.py convert --data data --wad "$(WAD)"
	$(PYTHON) tools/wadlevels.py --profile doom2 --names $(or $(NAMES),doom2) --wad "$(WAD)" --zokumbsp "$(ZOKUMBSP)"

# DOOM shareware: Episode 1 only, 2 MB ROM (tools/mk2mb.py shareware), with the levels, walls, sprites,
# title/menus, intermission picture, sound effects and weapons of the shareware DOOM1.WAD.  Only the
# art the set needs: walls the nine maps show, sprites the WAD has (wad2gfx.py --drop-unused), no
# other score screens or plasma/BFG frames (levels.inc).  The episode menu keeps every episode:
# Episodes 2-4 and E1M8's ending show the WAD's order screen HELP2 (!RLORDERSCREEN, --order HELP2).
# Work on a copy of a DOOM data set (make data ...); wadlevels.py starts from the cartridge levels
# (all 36 slots), so mk2mb.py shareware runs after it.
SWMAPS = E1M1 E1M2 E1M3 E1M4 E1M5 E1M6 E1M7 E1M8 E1M9
# middle textures of two-sided lines (the BRNBIG/BRNSMAL windows): drawn masked, as on the PC;
# the first wad2gfx.py pass writes MASKED.JSON for the level conversion
SWMASKED = --masked --masked-opaque --masked-budget 65536
swset:
	@test -n "$(WAD)" || { echo "usage: make swset WAD=<DOOM1.WAD>"; exit 1; }
	$(PYTHON) tools/wad2gfx.py convert --data data --wad "$(WAD)" $(SWMASKED)
	$(PYTHON) tools/wadlevels.py --no-build --wad "$(WAD)" --zokumbsp "$(ZOKUMBSP)" $(SWMAPS)
	$(PYTHON) tools/mk2mb.py shareware --wad "$(WAD)"
	$(PYTHON) tools/wad2gfx.py convert --data data --wad "$(WAD)" $(SWMASKED) --drop-unused
	@test -e data/wad2art.json || $(PYTHON) tools/wad2art.py learn --data data
	$(PYTHON) tools/wad2art.py convert --data data --wad "$(WAD)" --intermission --level-names --title tools/title/TITLE.png --order HELP2 --cart skill,episode,skull,font,textfont
	$(MENUS)
	$(PYTHON) tools/wad2soundfx.py convert --data data --wad "$(WAD)" --drop-missing
	$(PYTHON) tools/wad2cut.py --data data --wad "$(WAD)" --weapons Fist,Pistol,ShotGun,ChainSaw,ChainGun,Rocket
	@mkdir -p build
	bash tools/build.sh

# DOOM II demo: MAP01-MAP03 only, 2 MB ROM (tools/mk2mb.py demo), on a copy of a DOOM II data set,
# with DOOM2.WAD's music (tools/music/wad2music.py; the other ROMs keep the cartridge's music)
demo:
	@test -n "$(WAD)" || { echo "usage: make demo WAD=<DOOM2.WAD>"; exit 1; }
	@grep -q '^!RLEPISODELEN = 99' data/RLLEV/levels.inc || { echo "data is not a DOOM II data set: make doom2set WAD=DOOM2.WAD first"; exit 1; }
	$(PYTHON) tools/mk2mb.py demo
	$(PYTHON) tools/music/wad2music.py convert --data data --wad "$(WAD)"
	@mkdir -p build
	bash tools/build.sh

# the WAD's music for the title, the intermission and the levels in use (the music modules of
# the data set are replaced; songs that do not fit sound RAM keep the cartridge's)
wadmusic:
	@test -n "$(WAD)" || { echo "usage: make wadmusic WAD=<x.WAD>"; exit 1; }
	$(PYTHON) tools/music/wad2music.py convert --data data --wad "$(WAD)"
	@mkdir -p build
	bash tools/build.sh

# a 128x128 picture as sky SKY (1-4), in the nearest colours of the data set's walls
skypng:
	@test -n "$(SKY)" -a -n "$(PNG)" || { echo "usage: make skypng SKY=<1-4> PNG=<128x128.png>"; exit 1; }
	$(PYTHON) tools/skypng.py --data data --sky $(SKY) --png "$(PNG)"
	@mkdir -p build
	bash tools/build.sh

# One ROM per game: a fresh copy of gamedata-fx3 (make data) as gamedata-<game>, linked as data,
# the game's conversions (DOOM-FX: the levels, walls, sprites, title and menus of DOOM.WAD on the
# cartridge set) and reworked skies (tools/skies), then roms/<NAME>.sfc.  The music stays the
# cartridge's (the DOOM II demo: its WAD's).  The settings of each set are the ones its ROM was made with.
TNT_SET = NAMES=tnt BANK3F=0x6000 MASKED=65536 MASKEDBANKS=3C \
	MASKEDMAPS=MAP01,MAP02,MAP03,MAP04,MAP05,MAP06,MAP07,MAP08,MAP10,MAP11,MAP13,MAP14,MAP15,MAP17,MAP24,MAP25,MAP28
PLUTONIA_SET = NAMES=plutonia BANK3F= MASKED=65536 MASKEDBANKS=29 \
	MASKEDMAPS=MAP01,MAP02,MAP03,MAP04,MAP05,MAP07,MAP08,MAP10,MAP12,MAP14,MAP15,MAP16,MAP17,MAP19,MAP20,MAP21,MAP24,MAP31,MAP32
TNT_SKIES = 1:tools/skies/TNT-SKY1.png 2:tools/skies/TNT-SKY2.png 3:tools/skies/TNT-SKY3.png
PLUTONIA_SKIES = 2:tools/skies/PLUTONIA-SKY2.png
define newset
	@test -n "$(WAD)" || { echo "usage: make $(1) WAD=<the game's WAD>"; exit 1; }
	@test -d gamedata-$(2) || { echo "gamedata-$(2) missing: run $(if $(filter fx3,$(2)),make data,make $(2)) first"; exit 1; }
	rm -rf gamedata-$(1) && cp -a gamedata-$(2) gamedata-$(1) && ln -sfn gamedata-$(1) data
endef
define finish
	$(foreach s,$(2),$(PYTHON) tools/skypng.py --data data --sky $(word 1,$(subst :, ,$(s))) --png $(word 2,$(subst :, ,$(s)));)
	@mkdir -p build roms
	bash tools/build.sh
	cp build/doom.sfc roms/$(1).sfc && cp build/doom.sym roms/$(1).sym
	@echo "-> roms/$(1).sfc"
endef
doomfx:
	$(call newset,doomfx,fx3)
	$(PYTHON) tools/wad2gfx.py convert --data data --wad "$(WAD)"
	$(PYTHON) tools/wad2art.py convert --data data --wad "$(WAD)" --cart skill
	$(MENUS)
	$(PYTHON) tools/wadlevels.py --wad "$(WAD)" --zokumbsp "$(ZOKUMBSP)"
	$(call finish,DOOM-FX,)
doom2:
	$(call newset,doom2,fx3)
	$(MAKE) doom2set WAD="$(WAD)"
	$(call finish,DOOM2-FX,)
tnt:
	$(call newset,tnt,fx3)
	$(MAKE) doom2set WAD="$(WAD)" $(TNT_SET)
	$(call finish,TNT-FX,$(TNT_SKIES))
plutonia:
	$(call newset,plutonia,fx3)
	$(MAKE) doom2set WAD="$(WAD)" $(PLUTONIA_SET)
	$(call finish,PLUTONIA-FX,$(PLUTONIA_SKIES))
shareware:
	$(call newset,shareware,fx3)
	$(MAKE) swset WAD="$(WAD)"
	$(call finish,DOOM1-SHAREWARE-FX,)
doom2demo:
	$(call newset,doom2demo,doom2)
	$(MAKE) demo WAD="$(WAD)"
	$(call finish,DOOM2-DEMO-FX,)

fx3levels:
	$(PYTHON) tools/wadlevels.py --restore
	@mkdir -p build
	bash tools/build.sh

wadgfx:
	@test -n "$(WAD)" || { echo "usage: make wadgfx WAD=<DOOM.WAD> [PWAD=<x.wad>]"; exit 1; }
	@test -e data/wad2gfx.json || { echo "data/wad2gfx.json missing - run: make data ... (or tools/wad2gfx.py learn)"; exit 1; }
	$(PYTHON) tools/wad2gfx.py convert --data data --wad "$(WAD)" $(if $(PWAD),--wad "$(PWAD)")
	@mkdir -p build
	bash tools/build.sh

fx3gfx:
	$(PYTHON) tools/wad2gfx.py restore --data data
	@mkdir -p build
	bash tools/build.sh

wadsfx:
	@test -n "$(WAD)" || { echo "usage: make wadsfx WAD=<DOOM.WAD> [PWAD=<x.wad>] [FULL=1]"; exit 1; }
	@test -e data/wad2soundfx.json || { echo "data/wad2soundfx.json missing - run: make data ... (or tools/wad2soundfx.py learn)"; exit 1; }
	$(PYTHON) tools/wad2soundfx.py convert --data data --wad "$(WAD)" $(if $(PWAD),--wad "$(PWAD)") $(if $(FULL),--full)
	@mkdir -p build
	bash tools/build.sh

fx3sfx:
	$(PYTHON) tools/wad2soundfx.py restore --data data
	@mkdir -p build
	bash tools/build.sh

wadart:
	@test -n "$(WAD)" || { echo "usage: make wadart WAD=<DOOM.WAD> [PWAD=<x.wad>]"; exit 1; }
	@test -e data/wad2art.json || $(PYTHON) tools/wad2art.py learn --data data
	$(PYTHON) tools/wad2art.py convert --data data --wad "$(WAD)" $(if $(PWAD),--wad "$(PWAD)") --cart skill
	$(MENUS)
	@mkdir -p build
	bash tools/build.sh

fx3art:
	$(PYTHON) tools/wad2art.py restore --data data
	$(MENUS)
	@mkdir -p build
	bash tools/build.sh

clean:
	rm -rf build

distclean: clean
	rm -rf data gamedata-* roms
