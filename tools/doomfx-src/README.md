# Files from the DOOM-FX source release

Unchanged copies of six files from `source/` of Randal Linden's public
DOOM-FX source release (GPL v3, see `LICENSE`). `make data`
(`tools/mkdata.py`) reads them when it builds a data set from your FX3
cartridge and `DOOM.WAD`. They are source files and tables, not game data.

| File | Used for |
|---|---|
| `WallList`, `ImageList` | Names and order of the walls and sprites: ties the cartridge's graphics slots to DOOM's names (`fx3_gfx.py`, `wad2gfx.py learn`) |
| `TextureList2` | DOOM texture name to SNES wall translation (TEXTURE2, `fx3_gfx.py`) |
| `rlsound3.a` | Sound effect names and order (`datagen/rlmus.py`) |
| `InverseTable.bin` | 1/x table, assembled into the engine (copied to `data/SRC/`) |
| `RandomTable.bin` | The random number table (DOOM's `rndtable`), assembled into the engine (copied to `data/SRC/`) |

`--src DIR` (`make data SRC=DIR`) still reads them from another copy of the
source tree instead.
