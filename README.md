# DOOM for the SNES — Super FX 2 (GSU-2)

SNES **DOOM** rebuilt from the 1995 [`DOOM-FX`](https://github.com/RandalLinden/DOOM-FX) 
source (Randy Linden's "Reality Engine") with [`asar`](https://github.com/RPGHacker/asar).

It adds the content and fixes of *The Ultimate DOOM* cartridge (FX3) but stays 
on a **Super FX 2**. 

This engine also builds DOOM II, TNT: Evilution and Plutonia
from their WADs, and a 2 MB ROM of the shareware DOOM wad.

> **No game data is included**.
> There is some retouched menu art in `tools/menus/` and the shareware
> title picture `tools/title/TITLE.png`. The build makes the rest from your
> own files: your FX3 *The Ultimate DOOM* cartridge dump and `DOOM.WAD` (v1.9);
> the DOOM II / Final DOOM sets use your WADs.

## Compared with the original SNES DOOM

* **All 36 levels** of The Ultimate DOOM (the original left out E1M6, E2M2, E2M5,
  E2M7 and E3M5) with Episode 4, its intermission and end texts, and one sky
  per episode.
* **The Spectre**, drawn as a dark see-through shadow.
* **Start screen** the PC game's inspired start-up log for the WAD it was made from
  (title bar, `adding doom.wad`, the shareware / do-not-distribute notice), in the
  system text font (`tools/startscreen.py`, `startscreen.asm`).
* **Screen melt** when the title is left, as on The Ultimate DOOM cartridge,
  in place of the fade to black: 8-pixel columns slide down
  after random delays (`title.asm`).
* **Title menu** as on The Ultimate DOOM cartridge, in every game: a button on
  the title opens New Game / Load Game over the darkened title (the cartridge:
  New Game / Enter Code). New Game leads to the skill menu, then (DOOM games)
  the episode menu; Load Game to the slot menu of the pause menu. B goes back
  a menu; when the title times out, the game starts as before. The menus are
  `tools/menus/TitleMenu.png`, `TitleSkillMenu.png`, `TitleEpisodeMenu.png`
  (256×224, in screen position), put together by `tools/titlemenus.py` at
  every build (`title.asm`).
* **Save games:** three slots in battery-backed RAM (*Save games*).
* **Controls of The Ultimate DOOM:** circle strafing (turn while strafing
  with L/R), walking at half the running speed, quicker turning
  (`useFX3CONTROLS = 0` in `rlplayer.inc` restores the original controls).
* **Falling as on the PC:** the player falls from rest at 1 unit per tic²
  (35 tics a second, `rlmobjects3.asm`), so a run carries over a gap as on
  the PC (about 120 units instead of 76; PC about 130). The original dropped
  16 units per 20th of a second at once. Monsters fall as before.
* **SNES Mouse:** joypad in port 1 and mouse in port 2 play like keyboard and
  mouse on the PC; the original mouse-only mode (port 1) remains.
* **Rumble** for the LRG rumble controller in port 1, with the FX3
  cartridge's effects: each weapon's shot, the chainsaw's idle buzz while it
  is ready, and damage in three strengths (up to 10, up to 20, more). The
  pause menu has *Rumble: On/Off* (kept like Music and Sounds); the pause
  menu itself is silent, and a mouse in port 2 turns rumble off, as on FX3
  (`rumble.asm`; protocol: Limited Run Games' `snes-rumble`,
  its `docs/RumbleTech.pdf`). Checked in MesenCE by decoding the bits sent to
  port 1, not yet on a controller.
* **Nightmare as on the PC:** monsters respawn, act twice as fast, fireballs
  fly 1.5× as fast; double ammo.
* **Faster** renderer.
* **Fixes**:
  * Every monster of a level is created: the object table is sized from the
    level data (`!RLMAXMOBJECTS`); the original left out up to 78 monsters on
    Ultra-Violence (E1M6).
  * Impassible two-sided lines (windows, fences) block the player and
    monsters from both sides; the original checked them only from the right side.
    Projectiles still pass, as on the PC.
  * The player gets less hung up on walls: when a move and its slide
    along the wall are both blocked (door frames, steps, walls made of
    several lines), the move is tried along X only and Y only, as the PC's
    "stairstep" does; the original stopped the player there.
  * Walking speed no longer drops at 15 fps (the "nearly stopped" check
    stopped a moving player every frame).
  * Less hangs in huge views: the renderer's per-frame lists have overflow
    checks (*Engine limits*).
  * On E4M6 the last Cyberdemon opens the doors tagged 666 and on
    E4M8 the last Spider Mastermind lowers the floor tagged 666, as on the PC;
    the FX3 cartridge ended both levels at once.
  * New line specials (keyed remote doors, 16-unit stairs, blazing doors and
    lifts), sector special 17 (random flicker).
  * Intermission percentages are right past 255 kills/items and on levels
    without monsters.

## Build

Requirements: 
- [`asar` 1.91](https://github.com/RPGHacker/asar)
- Python 3.8+ with Pillow and numpy (scipy for`wad2soundfx.py`)
- [ZokumBSP](https://github.com/zokum-no/zokumbsp) (used commit`22af6de`)
- FX3 "THE ULTIMATE DOOM.sfc" rom dump

Converting maps from WADs is done with
[ZokumBSP](https://github.com/zokum-no/zokumbsp) (used commit
`22af6de`; `ZOKUMBSP=<path>` or `$ZOKUMBSP`) to rebuild the nodes of maps that
do not fit (*Node rebuilds* below): the DOOM II, TNT and Plutonia sets need it.
Without it, such a map keeps the cartridge's version or is left out.

```sh
make data FX3="THE ULTIMATE DOOM.sfc" WAD=DOOM.WAD   # -> gamedata-fx3/, linked as data/
make                                    # -> build/doom.sfc, build/doom.sym
```

`make data` also reads six files of the public DOOM-FX source release
(the wall, sprite and texture lists, the sound effect list and two math
tables). Copies of them are in
`tools/doomfx-src/`, so the source release isn't needed;
`SRC=<DOOM-FX-master/source>` reads them from another copy instead.
Nothing else is read: the build needs no dump of the original SNES DOOM
cartridge.

Every data set builds from the same source; `data/RLLEV/levels.inc` tells
the engine which set it is (level list, RAM limits, format flags).

`tools/build.sh` places the ROM sections and refreshes the cached constants
until stable (`layout.py`, `fixup.py`), writes the build id for save games,
checks the graphics limits (`gfxlimits.py`), assembles, then `romcheck.py`
pads the ROM to 2 or 4 MB and sets the header and checksum.

## Converting from a WAD

Each part of a data set can be built from a WAD and switched back to the
cartridge's. `make data` first learns from your cartridge and `DOOM.WAD` how
the SNES version was made (`data/*.json`).

```sh
make wadlevels WAD=DOOM.WAD [MAPS="E1M6 E3M5"] [ZOKUMBSP=...]   # make fx3levels
make wadgfx    WAD=DOOM.WAD [PWAD=x.wad]                        # make fx3gfx
make wadart    WAD=DOOM.WAD                                     # make fx3art
make wadsfx    WAD=DOOM.WAD [FULL=1]                            # make fx3sfx
```

* **Levels** (`wad2rl.py`, `wadlevels.py`): a port of Sculptured's RIPDOOM
  level converter. The BSP comes from the WAD; FACES, LINES, SECTORS, OBJECTS,
  BLOCKMAP and the door/stair/floor/lift lists are built as RIPDOOM did. Line
  types the engine has no code for are cleared. WAD texture names map to the
  cartridge's walls and floor colours. The visibility table (REJECT) is
  computed with 2D portal flow (`rlpvs.py`): it must never hide a visible
  sector, and it is much tighter than the WAD's. Converted maps match the FX3
  levels to 98–100 % in every field (`wad2rl.py compare`) except the upper
  and lower textures of two-sided lines (42 % and 49 %).
* **Node rebuilds** (`wadnodes.py`, ZokumBSP at commit `22af6de`): only where
  needed — a map whose BSP, areas, vertexes, segs and faces exceed one 64 KB
  bank is rebuilt without invisible segs and with look-alike sectors merged,
  and when the GamePak ROM is full the map that gains most is rebuilt. If a
  map still does not fit, it keeps the cartridge version.
* **Walls and sprites** (`wad2gfx.py`): the PC art in the SNES palette, with
  the cartridge's size savings learned per wall and sprite. Wall columns are
  shared with the most similar column of the same wall until the strips fit
  the 20 wall/sprite banks. The converted art is closer to the PC than the
  cartridge's in less space. The engine has 232 sprites (the FX3 cartridge
  206: no multiplayer frames), not the 229 of the source's `ImageList` (three
  barrel-explosion frames were missing).
* **Title, menus, fonts** (`wad2art.py`): `TITLEPIC`, the menus in DOOM's
  menu lettering (scaled to the cartridge's line height), the menu skull and
  the HUD font. `--intermission` adds the WIMAP pictures, `--textfont` the
  credits/end-text font, `--episodes N` limits the episode menu, `--title PNG`
  takes a 256×224 picture instead of `TITLEPIC`, `--cart ITEM,...` keeps the
  cartridge's skill/episode menu, skull or fonts. Every build keeps the
  cartridge's skill menu (`make wadart`, `doom2` and `shareware` pass
  `--cart skill`).
* **Pause, Save Game and Load Game menus** in the cartridge's lettering
  (the cartridge had no saving: `menus.py build` assembles them from its
  menu font; "Rumble:" from the FX3 main menu), retouched by hand in
  `tools/menus/*.png`. `menus.py retouch`
  puts them into the data set; `make data`, `wadart`, `fx3art`, `doom2` and
  `shareware` run it (`PNGMENUS=` leaves them out).
* **Weapons** (`wad2cut.py --weapons`; the CUT format is described there,
  `wad2cut.py show` renders a weapon): the PC frames at the 216/320 view
  scale, clipped at the view bottom, each 8×8 tile with its best palette; a
  frame too big for its tile budget is shrunk.
* **Sound effects** (`wad2soundfx.py`): the WAD sounds resampled, cut and
  levelled as the cartridge did, stored as BRR (`brr.py`). A look-ahead
  limiter keeps them below full scale (the matched gain would clip most WAD
  sounds). `--drop-missing` silences sounds the WAD lacks. 7 samples are
  resident in sound RAM, 27 (and the three chainsaw sounds below) are
  streamed into the APU blast buffer. The
  demon death sample was never played (demons die with the imp's sound):
  its slot holds DOOM II's super shotgun (`DSDSHTGN`, whole, 4 kHz). The
  chainsaw has the WAD's start-up (`DSSAWUP`), cutting (`DSSAWFUL`) and hit
  (`DSSAWHIT`) sounds as streamed effects (4 kHz, at most 1.47 s: the
  cutting sound fades out, the others play whole; at the WAD's own level,
  not boosted), the start-up and hit ones in the two other demon death
  effect numbers. A streamed sound already in a slot is replayed from
  there (the slot keeps the sample's start address).
* **Music** (`tools/music/`, `make wadmusic`): `wad2music.py` converts the
  WAD's MUS scores into song modules for the SPC700 driver (*Song format*),
  played with the cartridge's instruments and arranged by the rules of the
  cartridge's own conversions (instrument per GM program, voice priorities,
  an echo of the lead part, repeats as pattern calls). A song must fit sound
  RAM; one that does not is simplified step by step (stand-in instruments,
  no echo, no guitar layer, no velocity detail, coarser or no pitch bends, fewer
  chord voices), and otherwise keeps the cartridge's song. For now only the
  DOOM II demo uses it; the other ROMs keep the cartridge's music.
  `rlsong.py` reads the songs (`list`, `dump`, `midi`, `compare`),
  `spcrender.py` renders them to WAV through the real driver (in an SPC
  emulator, `spcrender/build.sh <libgme source>`).

## DOOM II, TNT and Plutonia

```sh
cp -a gamedata-fx3 gamedata-doom2 && ln -sfn gamedata-doom2 data     # each set in its own copy
make doom2 WAD=DOOM2.WAD ZOKUMBSP=<zokumbsp>                     # 32 maps
make doom2 WAD=TNT.WAD NAMES=tnt BANK3F=0x6000 MASKED=65536 MASKEDBANKS=3C \
    MASKEDMAPS=MAP01,MAP02,MAP03,MAP04,MAP05,MAP06,MAP07,MAP08,MAP10,MAP11,MAP13,MAP14,MAP15,MAP17,MAP24,MAP25,MAP28 ZOKUMBSP=...  # 17 of 32 maps
make doom2 WAD=PLUTONIA.WAD NAMES=plutonia BANK3F= MASKED=65536 MASKEDBANKS=29 \
    MASKEDMAPS=MAP01,MAP02,MAP03,MAP04,MAP05,MAP07,MAP08,MAP10,MAP12,MAP14,MAP15,MAP16,MAP17,MAP19,MAP20,MAP21,MAP24,MAP31,MAP32 ZOKUMBSP=...  # 19 of 32 maps
```

* **Maps** in the first 32 level slots as one sequence (`!RLEPISODELEN =
  99`): *New Game* goes to skill, then MAP01; secret levels, MAP30 ending the
  game, level names and the three skies as on the PC. Every map's nodes are
  rebuilt.
* **Monsters:** all DOOM II monsters (`!RLDOOM2MONSTERS`; their images in a
  second image page), with the MAP07, MAP30 and MAP32 specials:

  | Thing | Here | Differs from the PC |
  |---|---|---|
  | Chaingunner | 4-shot burst | does not fire continuously |
  | Wolfenstein SS | as on the PC | |
  | Hell knight | claw or fireball | 600 HP (PC 500), scaled like the SNES Baron |
  | Arachnotron | 4 plasma bolts | does not fire continuously |
  | Mancubus | 3 volleys of 2 fireballs | volley pattern |
  | Revenant | punch or missile | missile does not home, no smoke |
  | Pain elemental | spits lost souls | no souls on death, no 20-soul limit |
  | Arch-vile | flame attack | no blast lift, no resurrection |
  | Commander Keen | hangs from the ceiling | |
  | Boss brain, shooter | monsters appear at random spots; killing it ends the game | no cubes; DOOM's finale text |

* **Super shotgun** (weapon type 16): 2 shells, wider aim window, its own
  frames from the WAD; between shotgun and chainsaw in the weapon cycle.
* **Walls:** a wall set chosen for the maps (`--map-walls`, `wallset.py`):
  252 slots picked by visual likeness to the WAD textures, stored as 2×4
  blocks indexed into per-group 256-block codebooks (wall format 3,
  `wallvq.py`); `WALLS=rle` gives the older run-length format 2. Skies are
  placed at the PC's horizon. Flats are one colour each.
* **Switches:** every switch the maps use has its own slot, with its pressed
  state (`SW1*`/`SW2*`, the alternate texture of `TEXTURE2.TBL`) also when
  the maps never show that state, and its texels count 8 times in the
  codebooks (`SWITCH_WEIGHT`), so lamps and levers keep their colours.
* **Middle textures of two-sided lines** (grates, bars, fences, windows,
  and those without holes, which the PC draws once, untiled) are drawn
  masked with the objects, so monsters behind them show through: up to 32
  textures, 255 high and 256 wide, chosen by area seen per byte within
  `MASKED` bytes of strips. DOOM II's banks are full, so its 48 KB come out
  of the walls. TNT and Plutonia get one more GamePak bank for them first
  (`MASKEDBANKS`, of `$3C $39 $29 $23 $27 $2B`: the one their maps leave
  emptiest; a second one cost each a map), the rest comes out of the walls;
  `MASKEDMAPS` counts only the maps that fit. DOOM II has 15 masked
  textures, TNT 14, Plutonia 11; left out (used on few sides): DOOM II
  SKSPINE2 BFALL1 BIGBRIK2 SP_FACE2 PIPE4 TEKBRON1, TNT FIREBLU1 BROWN96
  ROCK4 GSTFONT2 METAL PIPE2 SP_ROCK1 BRONZE2 METAL2, Plutonia A-BROCK2
  FIRELAVA METAL STONE6 A-BRBRK2. Animated ones show their first frame.
* **Score screen:** the WAD's `INTERPIC` behind every level (`wad2art.py
  --interpic`), no map and no level markers; no DOOM episode text between
  maps (MAP09, 18, 27), only at the end of the game. The finished level's
  name above FINISHED, from the WAD's `CWILVnn` pictures (`--level-names`;
  the shareware set has them too, from `WILVem`).
* **Music** stays the cartridge's (`make wadmusic` would convert the WAD's; only the
  DOOM II demo does so for now).

Maps that do not fit (each needs more than the engine or ROM allows):

| Set | Left out | Why |
|---|---|---|
| TNT | MAP09, 16, 18, 19, 22, 31 | over 255 sectors after merging (sector numbers are bytes) |
| TNT | MAP20, 21, 27, 31 | level RAM image over 43 KB |
| TNT | MAP23, 26, 29, 30, 32 | BSP/areas/vertexes/segs/faces over one 64 KB bank |
| TNT | MAP12 | no room left in the GamePak ROM |
| Plutonia | MAP06, 09, 11, 13, 18, 25, 26, 27 | no room left in the GamePak ROM |
| Plutonia | MAP22, 23, 28, 30 | over one 64 KB bank (MAP22, 30: by under 120 bytes) |
| Plutonia | MAP29 | level RAM image over 43 KB |

The game skips empty level slots.

## 2 MB builds: shareware DOOM and the DOOM II demo

The same engine and source build 2 MB ROMs with everything in the GamePak
ROM, as on the original cartridge. Their data sets carry `data/regions.json` (a
copy of `tools/regions-2mb.json`, written by the scripts below): it lists no
CPU-only sections and replaces `tools/regions.json`, so `make` on such a set
gives a 2 MB ROM (`romcheck.py` pads to 2 MB). Each set lives in its own data
directory, as the DOOM II sets do; switch with the `data` link.

Data-set flags in `levels.inc`: `!RLEPISODES` (episodes offered, score
screens kept), `!RLNOPLASMABFG` (no plasma/BFG frames), `!RLORDERSCREEN`
(every episode in the menu; the missing ones, and the end of the game after
the end text, show the order screen, `wad2art.py --order HELP2`).

| | original cartridge | shareware | DOOM II demo | full build |
|---|---|---|---|---|
| ROM | 2 MB | 2 MB (1.3 MB used) | 2 MB (1.4 MB used) | 4 MB |
| levels | 22 | 9 | 3 | 36 (DOOM II: 32) |
| GSU RAM | 64 KB, no battery | 128 KB, battery | 128 KB, battery | 128 KB, battery |

A 2 MB ROM runs on a stock sd2snes / FXPak Pro and in ares.

**Shareware DOOM:** Episode 1, *Knee-Deep in the Dead* (E1M1–E1M9), from
the shareware `DOOM1.WAD` (v1.9).

```sh
cp -a gamedata-fx3 gamedata-shareware && ln -sfn gamedata-shareware data   # a copy of a DOOM data set (make data)
make shareware WAD=DOOM1.WAD ZOKUMBSP=<zokumbsp>
```

* `tools/mk2mb.py shareware` keeps the nine Episode 1 slots, makes E1M8 end the
  game and sets `!RLEPISODES = 1` and `!RLNOPLASMABFG`. With
  `--wad` it rebuilds the three walls whose texture the shareware WAD lacks
  (PIPE4, ROCKRED3, STARG2) from the texture the maps use there (PIPE2,
  REDWALL1, STARG3).
* **Everything from the WAD** except the engine, the music, the status bar,
  the palette, the list of wall slots and the title, menus and fonts below:
  maps, walls, sprites, intermission picture, order screen, sound effects and
  weapon frames. Sounds the WAD lacks are silent, art it lacks is a 1×1
  placeholder (38 of 67 walls and 163 of 232 sprites are used).
* **Title screen:** `tools/title/TITLE.png`, the WAD's `TITLEPIC` at
  256×224 with a retouched bottom line ("PROVIDED BY id FREE OF CHARGE •
  PRICE $9.00"), converted by `wad2art.py --title`.
* **Menus:** the retouched Pause, Save Game and Load Game menus
  (`tools/menus/*.png`, `menus.py retouch`); the cartridge's skill and
  four-episode menus, menu skull, message and text fonts (`wad2art.py
  --cart`). `!RLORDERSCREEN`: a new game on Episodes 2–4 shows the WAD's
  order screen (`HELP2`) until a button is pressed, then the title.
* **Windows and grates** (the BRNBIG/BRNSMAL windows, BROWNGRN) are drawn
  masked, as on the PC; the cartridge had none.

Tested in MesenCE: boot → title → E1M1, the episode menu, E1M8's end text →
order screen → title, every map, save/load on all nine maps. The shareware
licence allows passing on `DOOM1.WAD` unchanged only: a ROM built from it is
for your own use.

**DOOM II demo:** MAP01–MAP03 (*Entryway*, *Underhalls*, *The Gantlet*).

```sh
cp -a gamedata-doom2 gamedata-doom2demo && ln -sfn gamedata-doom2demo data   # a copy of a DOOM II data set (make doom2)
make demo WAD=DOOM2.WAD
```

`tools/mk2mb.py demo` keeps the first three level slots of a DOOM II data set
(`--maps N`: the first N); MAP03 ends the game (end text, then the title).
The demo plays `DOOM2.WAD`'s music (title, intermission and the three maps'
songs; `tools/music/wad2music.py`).
Tested in MesenCE: MAP01 → MAP02 → MAP03 → end text → title, and save/load
on all three maps.

## Engine limits

* Sectors: 255 per map (look-alike sectors are merged above that).
* BSP nodes and areas: 1664 each (`MaxRLVisNodes`/`MaxRLVisAreas`).
* BSP, areas, vertexes, segs and faces of a map: one 64 KB GamePak bank.
* Level RAM image (LINES, BLOCKMAP, OBJECTS, REJECT): 43 KB; REJECT moves to
  the GamePak ROM when the rest needs the room.
* Fixed objects: 180 per map (`MaxRLFObjects`). Movable objects: sized per
  data set, at most 300.
* Per frame: 127 visible sectors; the BSP area list is filled in chunks so
  nothing is left out; floors/ceilings, wall pieces, wall and floor plot data
  share the plot data room and stop before they overrun other data (what does
  not fit is left out for that frame; the original had a fixed array of 40
  floors/ceilings and no check).
* Light tasks: at most 40 per map (the task table holds 48 for all kinds).
* Textures: heights and widths powers of two, up to 128 × 256
  (`gfxlimits.py` checks every strip at build time).

## Speed

Frame times at the real Super FX clock (MesenCE, Hurt Me Plenty, the
`test/det_suite.sh` input with `dettest.py --gsuclock 100`, 600 rendered
frames):

| level | VBlanks per frame | fps |
|---|---|---|
| E1M1 | 3.37 | 17.8 |
| E3M5 | 3.44 | 17.5 |
| E4M2 | 5.37 | 11.2 |
| E4M8 | 5.52 | 10.9 |

What makes the renderer faster than the original's:

* **Wall band buffer:** walls are drawn 8 pixels wide into a buffer and
  plotted row by row, so the pixel cache never reads back the screen.
* **BSP visibility bits:** the walk skips subtrees the player's sector cannot
  see.
* **BSP walk in chunks:** the segment passes run after each 1 KB chunk and
  the walk stops once the view is covered.
* **Screen thirds through WRAM:** each finished third is copied to WRAM at
  once, so the GSU no longer waits for the VBlank. The upload to VRAM goes
  strip by strip, starting a GSU that halted in between, so the GSU runs
  during it.
* **3-VBlank frames:** the weapon phase's VBlank is empty when the weapon
  picture did not change (96–99 % of frames); the next frame's first third
  is uploaded in it, so a frame takes 3 VBlanks instead of 4 when the GSU
  keeps up. Same game; input lands up to a frame later in game frames, the
  same in real time. A changed weapon picture waits for the next third's
  upload and goes in the rest of its blank when it fits.
* **Wall texel loops** (cartridge wall format): a magnified wall plot keeps a
  texel's pixels in a LOOP (9 cycles a pixel instead of 15), a minified one
  steps a whole run in a LOOP (25 instead of 36).
* **Wall colour maps in GSU RAM:** the wall pixel loops read the lit colour
  from a RAM copy instead of switching the ROM bank to the colour maps and
  back for every pixel (the emulators charge nothing for a GSU RAM read;
  real hardware does, so the gain there is smaller).
* Smaller gains: the BSP walk fits the 512-byte GSU cache, fast paths for
  single-colour floor strips and skies, and a LOOP for magnified wall plots
  (wall format 3).

The frame rate is capped at 20 fps (3 screen thirds take 3 VBlanks; a changed
weapon picture needs a VBlank of its own when it does not fit after a third).

## Cartridge and memory map

The ROM is **4 MB** (map `$20`, type `$15`: Super FX + RAM + battery, 128 KB
GSU RAM). The Super FX only reads the first 2 MB, its official limit.

| file offset | CPU address | contents |
|---|---|---|
| `$000000-$1FFFFF` | `$00-$3F:8000`, `$40-$5F` (also GSU) | **GamePak ROM**: GSU code, walls, sprites, the level parts the GSU reads, colour maps, CPU code |
| `$200000-$3FFFFF` | `$E0-$FF` (CPU only) | level RAM images, music, menus, pictures, weapon graphics, status bar, save code |

| GSU RAM | contents |
|---|---|
| `$70:0000-$FFFF` | variables, screen buffer, sectors, objects, vertexes, lines, visibility bits, the renderer's work lists |
| `$71:0000-$ACBF` | level RAM image, copied from ROM at level start |
| `$71:ACC0-$AEFF` | wall band buffer |
| `$71:AF00-$CFFF` | the walls' colour maps (33 × 256 bytes), copied from ROM at level start |
| `$71:D000-$FFFF` | save games (12 KB, battery backed) |

`tools/regions.json` lists what goes into the CPU-only ROM; a data set's own
`data/regions.json` replaces it (the 2 MB builds: none).

**Hardware.** A board or flash cart must map the second 2 MB at `$E0-$FF`.
The stock sd2snes / FXPak Pro Super FX core maps save RAM mirrors there, so
the 4 MB ROMs do not start on it (the 2 MB builds do). `tools/mesence-doomfx.patch`
adds the 4 MB map to MesenCE. ares maps only 2 MB, so it runs the 2 MB builds.
The game never touches `$80-$DF`, so boards that mirror the GamePak ROM
there work too.

## Save games

* **Save:** pause → *Save Game* → one of three slots (not while dead). A slot
  is named after its level ("E1M3 TOXIN REFINERY", "MAP10 REFUELING BASE").
* **Load:** pause → *Load Game*. The level is restarted, then everything is
  put back: monsters and objects, doors and lifts, switches, the automap,
  health, ammo, weapons, keys and the level time.
* **Storage:** a save keeps only what changed since the level started: the
  level blocks XORed with the freshly set-up level, plus the game variables,
  packed with a small LZ77 (1.2–2.7 KB). Saving restarts the level the same
  way, so the game continues exactly as after loading that save. Each slot
  has a checksum, and saves load only into the ROM build that wrote them.
* **Code:** `src/engine/savegame.asm`, `src/include/savegame.inc`; menu art by
  `tools/menus.py`.

## Song format

The SPC700 driver (`MUSIC_D.C`, APU `$0700`–`$1EDF`) loads one module per
song: song data and BRR samples from `$6517`, plus driver table entries
(sample addresses `$1F00`, instruments `$2156`, envelopes `$221C`, song
pointer `$25C4`). A song is a track count and a pointer per track. Timer 1
runs at 50 Hz; each tick adds the tempo to an 8-bit accumulator and the
sequencer steps on the carry.

| byte | meaning |
|---|---|
| `$00`–`$7F` | note: previous + (b >> 3) − 8, length (b & 7) + 1 |
| `$80`–`$BF` | note b − `$60`, length = next byte |
| `$C0`–`$DF` | rest b − `$BF` |
| `$F8` `$FD` `$FE` `$FF` | rest 32, 64, 128, 256 |
| `$EF` n l | note n, length l |
| `$F5` i | instrument |
| `$F2` v, `$F1` a b | volume, volume scale |
| `$ED` v | velocity |
| `$FB` p | pan offset |
| `$F3` p, `$E5` f v m, `$E6` | voice priority, voice allocation, default allocation |
| `$E9` m | voices sound effects may take |
| `$FA` t | tempo |
| `$F6` … | pattern call (address, end, count, transpose, volume scale, skip) |
| `$EB` / `$EC` … `$00` | pitch slide (`$EC`: key off first) |
| `$F4` | legato |
| `$F7` w, `$E0` w | fine pitch, detune |
| `$E1`–`$E4` x | envelope overrides |
| `$EA`, `$E7`, `$FC` f | key off, reset, flag |
| `$F9`, `$F0` | loop the track, end |

Notes are MIDI note numbers. The cartridge's songs step about once every
2.88 MUS ticks (MUS: 140 Hz); `wad2music.py` uses tempo 0, 50 steps a second,
2.8 MUS ticks a step.

## Source layout

```
doom.asm            master file: mapper, settings, module list
src/macros.inc      asar replacements for xa/xl features, project macros
src/layout.inc      section placement (generated)
src/include/        the original headers + levels.inc, savegame.inc, rumble.inc
src/engine/         the original modules + savegame.asm, rumble.asm, order.asm;
                    startscreen.asm replaces legal.asm, exmy.asm the e1my/e2my/
                    e3my.asm level modules
data/               generated game data (not distributed)
tools/              build, conversion and test tools
tools/doomfx-src/   the files of the DOOM-FX source release `make data` reads
tools/music/        the music converter and song tools (make wadmusic, make demo)
tools/test/         test and analysis scripts (not used by the build)
tools/legacy/       the xa/xl reference assembler and the xa → asar translator
```

The first commits are the translation: with the original data it assembles
byte for byte to the original tool chain's ROM. Engine changes of this port
since then are marked `this port` in the source.

### Tools

Every script's header has the details and its usage.

| Build (`make`, `tools/build.sh`) | |
|---|---|
| `build.sh` | the build: layout, cached values, build id, graphics check, asar, ROM check |
| `layout.py` | the "linker": places the ROM sections (`regions*.json`, `sections.json`), writes `src/layout.inc` |
| `fixup.py` | refreshes the cached alignment pads, constants and `ds` sizes the asserts guard |
| `gfxlimits.py` | checks walls and sprites against the engine's limits; holds the wall/sprite bank lists |
| `romcheck.py` | pads the ROM to 2 or 4 MB, checks the header, sets the checksum |

| Data set from your files (`make data`) | |
|---|---|
| `mkdata.py` | builds a whole data set from the FX3 cartridge, `DOOM.WAD` and `tools/doomfx-src/` |
| `fx3_gfx.py` | walls, sprites and colour maps from a cartridge ROM, rebuilt in the engine's format |
| `fx3_convert_levels.py` | the 36 FX3 levels as level data files and `levels.inc` |
| `menus.py` | `build`: the pause/save/load menus from the cartridge's lettering; `retouch`: puts in `tools/menus/*.png` |
| `titlemenus.py` | the title menus (New Game / Load Game, skill, episode, slots) for `title.asm`; `build.sh` runs it |
| `startscreen.py` | the start screen's text: the PC start-up log of the data set's game; `build.sh` runs it |
| `datagen/` | `mkdata.py`'s package: `fx3_art.py`, `fx3_music.py`, `rlmus.py` (the song, effect and music driver command numbers), `fx3dec.py` with `emu65816.py` and `dis65816.py` (the FX3 cartridge's own 65816 decompressor run under emulation), `tilequant.py` (full-colour screens to 4 bpp tiles and palettes), `snesgfx.py` (tiles, palettes, previews) |

| From a WAD (`make doom2`, `shareware`, `wadlevels`, `wadgfx`, ...) | |
|---|---|
| `wad2rl.py` | WAD maps to Reality Engine level data; `learn` / `compare` against the cartridge's levels |
| `wadlevels.py` | puts converted levels into the data set and fits them into the ROM (DOOM II profile) |
| `wadnodes.py` | rebuilds a map's nodes with ZokumBSP so it fits one bank |
| `rlpvs.py` | the sector visibility table (REJECT/PVS) of a map |
| `wad2gfx.py` | walls, sprites and masked middle textures |
| `wallset.py`, `wallvq.py` | the wall set for a WAD's maps; wall format 3 (VQ blocks and codebooks) |
| `wad2art.py` | title screen, menus, menu skull, fonts, score screens, level names |
| `wad2cut.py` | weapon HUD frames (the CUT format; `show` renders a weapon) |
| `wad2soundfx.py` | sound effects (BRR) |
| `mk2mb.py` | `shareware` / `demo`: cuts a data set down to a 2 MB ROM |

| Libraries | |
|---|---|
| `wad.py` | the WAD reader all tools use |
| `snescomp.py` | the DeCompress formats: decompressors and compressors (`comp.asm`) |
| `rlmusic.py` | reads and writes the music and sound data (`RLDATA/MUSIC`) |
| `brr.py` | BRR sample encoder/decoder (`wad2soundfx.py`) |
| `rlcompare.py` | compares two level data sets field by field (`wad2rl.py compare`) |

| Tests and analysis | |
|---|---|
| `mesenrun/` | the headless MesenCE runner (`mesenrun.cpp`, `build.sh`; `tools/mesence-doomfx.patch`: the 4 MB map and the GSU probes) |
| `aresrun/` | the headless ares runner for the 2 MB ROMs (`main.cpp`, `build.sh`, `ares-probes.patch`) |
| `test/dettest.py` | deterministic play test: hashes, screenshots, RAM dumps, profiles |
| `test/det_suite.sh` | `dettest.py` on several levels, compared with a baseline |
| `test/savetest.py` | save and load through the pause menu, checked byte for byte |
| `test/gsuprof.py` | GSU cycles per routine from a `mesenrun` profile |
| `test/delaycheck.py` | GSU branch delay slot hazards in the sources |

| Music (`tools/music/`) | |
|---|---|
| `wad2music.py` | `convert`: a WAD's MUS music into song modules of the data set; `song`: one song as WAV |
| `musiclib.py` | the cartridge's instrument library and the song module builder |
| `mus.py` | reads DOOM's MUS lumps |
| `rlsong.py` | reads the songs: `list`, `dump`, `midi`, `compare` with the WAD's MUS |
| `spcrender.py`, `spcrender/` | renders songs to WAV through the SPC700 driver (libgme's SPC emulator) |
| `disspc700.py` | SPC700 disassembler (the music driver) |

| Legacy (`tools/legacy/`, not used by the build) | |
|---|---|
| `xasm.py` | reference re-implementation of the original xa/xl assembler and linker |
| `xa2asar.py` | translates the original sources to asar syntax |
| `mkproject.py` | generated the first asar project tree with `xa2asar.py` (do not run it on this repository) |

**Tests** need the headless MesenCE runner (`tools/mesenrun/build.sh <MesenCE
source>`; set `MESENRUN`). MesenCE continues the archived Mesen 2; its
Super FX timing differs slightly, so results from the two do not compare
frame for frame.

* `test/dettest.py`: deterministic play — pins the frame time, hashes the game
  state every rendered frame, takes screenshots and RAM dumps; options for
  menus, level, skill, joypad and mouse input, GSU profiling.
* `test/det_suite.sh`: `dettest.py` on 5 levels (`LEVELS="0 1 7"`: those a change
  touches), each level's result, and `--compare` against a baseline.
* `test/savetest.py ROM NAME LEVEL...`: save and load through the pause menu, every
  saved block checked byte for byte.
* `test/gsuprof.py`: GSU cycles per routine (`MESEN_GSU_PROF=<file>`).
  `MESEN_GSU_IDLE=<file>`: GSU time running, stopped, or waiting for the
  ROM/RAM bus, per frame and per GSU address (`MESEN_GSU_IDLE_FROM=<frame>`).
* `test/delaycheck.py`: GSU branches whose delay slot holds a prefix or a
  multi-byte instruction.
* `MESEN_RAM=random|ones`: random or set power-on RAM; `tools/aresrun` runs a
  2 MB ROM in ares.

## Credits / licence

Reality Engine and DOOM-FX source © Randal Linden, GPL v3 (the files in
`tools/doomfx-src/` are unchanged copies from it, with its `LICENSE`); DOOM ©
id Software (`RandomTable.bin` is DOOM's `rndtable`, GPL in the DOOM source
release). The Ultimate DOOM SNES content belongs to its owners and is only
read from your cartridge. The rumble protocol is Limited Run Games'
(`snes-rumble`, Randal Linden's *Super NES Rumble Controller Support*); the
effect waves are the FX3 cartridge's. Conversion tools, asar port and
extensions: this project, GPL v3.
