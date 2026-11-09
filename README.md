# DOOM for the SNES — Super FX 2 (GSU-2)

SNES **DOOM** rebuilt from the 1995 [`DOOM-FX`](https://github.com/RandalLinden/DOOM-FX)
source (Randy Linden's "Reality Engine") with [`asar`](https://github.com/RPGHacker/asar).
It adds the content and fixes of *The Ultimate DOOM* cartridge (FX3) but stays
on a **Super FX 2** within its official 2 MB, and the same engine builds
DOOM II, TNT: Evilution and Plutonia from their WADs, and a 2 MB ROM of the
shareware DOOM.

> **No game data is included.** The build makes it from your own FX3
> *The Ultimate DOOM* cartridge dump and your WADs. The repository only holds
> retouched menu art (`tools/menus/`), the shareware title picture
> (`tools/title/`) and reworked skies (`tools/skies/`).

## Building a ROM

You need:

- [`asar` 1.91](https://github.com/RPGHacker/asar)
- Python 3.8+ with Pillow, numpy and scipy
- [ZokumBSP](https://github.com/zokum-no/zokumbsp) (commit `22af6de`) on the
  PATH, or `ZOKUMBSP=<path>`
- your FX3 cartridge dump `THE ULTIMATE DOOM.sfc`, The Ultimate DOOM's
  `DOOM.WAD` (v1.9), and the WAD of each other game you want

Make the data set once, then one command per game:

```sh
make data FX3="THE ULTIMATE DOOM.sfc" WAD=DOOM.WAD   # once: gamedata-fx3/

make doomfx    WAD=DOOM.WAD        # -> roms/DOOM-FX.sfc (4 MB)
make doom2     WAD=DOOM2.WAD       # -> roms/DOOM2-FX.sfc (4 MB)
make tnt       WAD=TNT.WAD         # -> roms/TNT-FX.sfc (4 MB)
make plutonia  WAD=PLUTONIA.WAD    # -> roms/PLUTONIA-FX.sfc (4 MB)
make shareware WAD=DOOM1.WAD       # -> roms/DOOM1-SHAREWARE-FX.sfc (2 MB)
```

Each game is built in its own copy of the data set (`gamedata-<game>/`,
linked as `data/`), so the games do not interfere; `make` alone rebuilds the
linked one to `build/doom.sfc`. DOOM II, TNT and Plutonia take 10–15 minutes
each, DOOM-FX and the shareware game a few minutes. The steps behind these
targets, and how to convert or restore single parts, are in
[docs/TECHNICAL.md](docs/TECHNICAL.md).

## Compared with the original 1995 SNES DOOM

* **All 36 levels** of The Ultimate DOOM (the original had 22) with Episode 4,
  its intermission and end texts, one sky per episode, and the line and
  sector specials its maps use. The DOOM-FX ROM takes the levels, walls,
  sprites, title and menus from `DOOM.WAD`.
* **The Spectre** as a dark see-through shadow.
* **The Ultimate DOOM cartridge's** controls (circle strafing, walking,
  quicker turning), title menu (New Game / Load Game), screen melt and
  rumble (LRG rumble controller; not yet tried on a real controller), and
  its cheats, entered in the pause menu (*Cheats*).
* **Save games:** three slots in battery-backed RAM.
* **As on the PC:** falling, Nightmare (respawning, fast monsters, double
  ammo), a start screen like the PC's start-up log, joypad plus mouse.
* **Faster** renderer (*Engine limits and speed*).
* The music is the FX3 cartridge's; `make wadmusic` converts a WAD's.

### Fixes

Compared with the two cartridges:

* From The Ultimate DOOM cartridge, which fixed these in the original: using
  an already-used line goes on to the next line in reach (the original said
  "oof"); a sector whose floor type changes loses its old type; projectiles
  leave from half the monster's height (the Cyberdemon's rockets came out of
  its knees); a sound effect is no longer lost while the music driver is busy.
* On both cartridges: the player gets less hung up on walls (door frames,
  steps): a blocked move is tried along X only and Y only, as the PC's
  "stairstep" does.
* On the original cartridge: impassible windows and fences block the player
  from both sides; every monster of a level is created (the original had 100
  slots, its own levels need up to 162); a Cyberdemon killed outside E2M8 no
  longer writes a stray value to RAM.
* Changed from The Ultimate DOOM cartridge: E4M6 and E4M8 go on after the
  boss dies, as on the PC (the tagged doors open, the floor lowers).

## Cheats

The three cheats of The Ultimate DOOM cartridge, with its button sequences,
entered in the pause menu: they do nothing while playing, and take effect
when the game goes on. Press each button on its own; a wrong one starts that
cheat over.

| Buttons | Cheat |
|---|---|
| R, A, Down ×5, A, L | full ammo, every weapon and key, 200% armor, at least 100% health |
| L, Right, Right, Down ×5, Left, Left, Down ×4 | invulnerability for 60 seconds |
| Right, Right, Down, Down, Left ×4, twice | the whole map and the monsters on it, for this level |

## DOOM II, TNT and Plutonia

* The maps in one sequence: New Game → skill → MAP01, secret levels, level
  names, the three skies and MAP30's ending as on the PC.
* All DOOM II monsters and the super shotgun:

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
  | Boss brain, shooter | monsters appear at random spots; killing it ends the game | no cubes |

* Walls, sprites, weapons, sounds, title and intermission picture from the
  WAD; grates, bars and windows drawn see-through. TNT's three skies and
  Plutonia's SKY2 are reworked pictures (`tools/skies/`).
* Maps left out, because each needs more than the engine or the 2 MB the
  Super FX reads allow:

  | Game | Left out | Why |
  |---|---|---|
  | TNT (17 of 32 maps) | MAP09, 16, 18, 19, 22, 31 | over 255 sectors |
  | | MAP20, 21, 27, 31 | level RAM image over 43 KB |
  | | MAP23, 26, 29, 30, 32 | map data over one 64 KB bank |
  | | MAP12 | no room left in the 2 MB |
  | Plutonia (19 of 32 maps) | MAP06, 09, 11, 13, 18, 25, 26, 27 | no room left in the 2 MB |
  | | MAP22, 23, 28, 30 | map data over one 64 KB bank |
  | | MAP29 | level RAM image over 43 KB |

## Shareware DOOM

Episode 1 (E1M1–E1M9) from the shareware `DOOM1.WAD` as a 2 MB ROM, laid out
like the original cartridge: maps, walls, sprites, weapons, sounds and the
order screen from the WAD; the title is `tools/title/TITLE.png`. Episodes 2–4
in the menu show the order screen. The shareware licence allows passing on
`DOOM1.WAD` unchanged only: a ROM built from it is for your own use.

## Cartridge and memory map

The 4 MB ROMs use map `$20`, type `$15` (Super FX + RAM + battery, 128 KB GSU
RAM). The Super FX reads only the first 2 MB, its official limit:

| file offset | CPU address | contents |
|---|---|---|
| `$000000-$1FFFFF` | `$00-$3F:8000`, `$40-$5F` (also GSU) | GSU code, walls, sprites, the map data the GSU reads, colour maps, CPU code |
| `$200000-$3FFFFF` | `$E0-$FF` (CPU only) | level RAM images, music, menus, pictures, weapons, status bar, save and cheat code |

A board or flash cart must map the second 2 MB at `$E0-$FF`. The stock
sd2snes / FXPak Pro Super FX core maps save RAM mirrors there, so the 4 MB
ROMs do not start on it, and ares maps only 2 MB; the 2 MB shareware ROM runs
on both. `tools/mesence-doomfx.patch` adds the 4 MB map to MesenCE.

## Engine limits and speed

* Per map: 255 sectors, 1664 BSP nodes and areas, 180 fixed and up to 300
  moving objects, map data in one 64 KB bank, a 43 KB level RAM image.
* Per frame: 127 visible sectors; lists that would overflow leave the rest
  out for that frame instead of hanging.

| level | fps (MesenCE, real Super FX clock) |
|---|---|
| E1M1 | 17.8 |
| E3M5 | 17.5 |
| E4M2 | 11.2 |
| E4M8 | 10.9 |

The frame rate is capped at 20 fps.

## Source

```
doom.asm            master file
src/                engine (the original modules and this port's), headers, macros
tools/              build, conversion and test tools
docs/TECHNICAL.md   conversions, memory map, save format, song format, tools
```

The first commits are the translation: with the original data it assembles
byte for byte to the original tool chain's ROM. Later engine changes are
marked `this port` in the source.

## Credits / licence

Reality Engine and DOOM-FX source © Randal Linden, GPL v3 (the files in
`tools/doomfx-src/` are unchanged copies from it, with its `LICENSE`); DOOM ©
id Software (`RandomTable.bin` is DOOM's `rndtable`, GPL in the DOOM source
release). The Ultimate DOOM SNES content belongs to its owners and is only
read from your cartridge. The rumble protocol is Limited Run Games'
(`snes-rumble`, Randal Linden's *Super NES Rumble Controller Support*); the
effect waves are the FX3 cartridge's. Conversion tools, asar port and
extensions: this project, GPL v3.
