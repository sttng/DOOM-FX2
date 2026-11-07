#!/usr/bin/env python3
"""
titlemenus.py - the title screen menus (as on the FX3 cartridge), for title.asm.

  python3 tools/titlemenus.py [--data DATA] [--png tools/menus]

The FX3 cartridge puts a menu over the darkened title picture: New Game / Enter
Code, then the skill and episode menus, drawn on a BG layer, with the menu skull
as sprites.  This port has New Game / Load Game; Load Game opens the slot menu
of the pause menu.  tools/build.sh runs this before every build.

Inputs (256x224 pictures in screen position, transparent background, the two
reds of the cartridge's title menus: 255,0,0 and 156,33,33):
  PNG/TitleMenu.png         New Game / Load Game
  PNG/TitleSkillMenu.png    Choose Skill Level: and the five skills
  PNG/TitleEpisodeMenu.png  Which Episode? and the four episodes (DOOM sets)
and from the data set (RLDATA/COMP): LoadMenu.map0 + SlotMenu.def0, the pause
menu's Load Game slot menu (palette 2 reds; the slot lines are written by the game).

Writes into DATA/RLDATA/COMP:
  TitleMenu0-3.def0   4bpp tiles of the title, skill, episode and load menus (BG2
                      characters at $4000 while a menu is shown): menu 0's at
                      VRAM $4840 (BG2 tile $084, loaded with the title; tile $084
                      is blank), menus 1-3 share the tiles after it and are loaded
                      when shown (as the cartridge loads each menu's tiles)
  TitleMenu0-3.map0   their 32x32 BG2 maps
  titlemenu.inc       tile numbers for title.asm
All entries use BG palette 7 (title.asm loads the menu colours there: the
pause menu's palette 2, with the two title menu reds as colours 13 and 15).
"""
import argparse, os, struct, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'datagen'))
import snescomp as sc                                        # noqa: E402
from snesgfx import encode_tile, decode_tile                 # noqa: E402

FIRST = 0x084              # first BG2 tile (VRAM $4840: after the BG1 map and the melt's OPT table)
LAST = 0x1F0               # (exclusive) the menu skull's sprite tiles follow at $5F00
ATTR = (7 << 10) | 0x2000  # palette 7, priority
COLOURS = {(255, 0, 0): 13, (156, 33, 33): 15}
LOAD_ROW = 7               # the slot menu's first map row (BG2 VOFS 0: screen line 55,
                           # BG2 HOFS -20: the menu sits where the pause menu shows it)


def picture(path):
    a = np.asarray(Image.open(path).convert('RGBA'))
    if a.shape[:2] != (224, 256):
        sys.exit('%s: must be 256x224' % path)
    idx = np.zeros((256, 256), np.uint8)          # 32 tile rows (the map is 32x32)
    for y in range(224):
        for x in range(256):
            r, g, b, al = a[y, x]
            if al < 128:
                continue
            c = COLOURS.get((int(r), int(g), int(b)))
            if c is None:
                sys.exit('%s: pixel %d,%d has colour %s (only %s)' % (path, x, y, (r, g, b), list(COLOURS)))
            idx[y, x] = c
    return idx


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[1])
    ap.add_argument('--data', default=os.path.join(HERE, '..', 'data'))
    ap.add_argument('--png', default=os.path.join(HERE, 'menus'))
    a = ap.parse_args()
    comp = os.path.join(a.data, 'RLDATA', 'COMP')

    def tileset(first):
        tiles, index = [], {}
        def add(t):
            b = encode_tile(t, 4)
            if b not in index:
                index[b] = len(tiles)
                tiles.append(b)
            return first + index[b]
        return tiles, index, add

    def picmap(name, add):
        img = picture(os.path.join(a.png, name + '.png'))
        return [add(img[r * 8:r * 8 + 8, c * 8:c * 8 + 8]) | ATTR for r in range(32) for c in range(32)]

    # menu 0 (New Game / Load Game): tiles at FIRST, loaded with the title; tile FIRST is blank
    t0, i0, add0 = tileset(FIRST)
    add0(np.zeros((8, 8), np.uint8))
    sets = [(t0, picmap('TitleMenu', add0))]
    second = FIRST + len(t0)               # menus 1-3: their own tiles here, loaded when shown
    blank = FIRST | ATTR
    for name in ('TitleSkillMenu', 'TitleEpisodeMenu'):
        t, i, add = tileset(second)
        img = picture(os.path.join(a.png, name + '.png'))
        m = []
        for r in range(32):
            for c in range(32):
                tile = img[r * 8:r * 8 + 8, c * 8:c * 8 + 8]
                m.append(blank if not tile.any() else add(tile) | ATTR)
        sets.append((t, m))
    # menu 3, the slot menu: SlotMenu.def0 as it is, LoadMenu.map0 moved to LOAD_ROW
    sd = sc.decompress(open(os.path.join(comp, 'SlotMenu.def0'), 'rb').read())[0]
    t3 = [sd[32 * i:32 * i + 32] for i in range(len(sd) // 32)]
    lm = sc.decompress(open(os.path.join(comp, 'LoadMenu.map0'), 'rb').read())[0]
    lw = struct.unpack('<%dH' % (len(lm) // 2), lm)
    if LOAD_ROW + len(lw) // 32 > 28:
        sys.exit('LoadMenu.map0: %d rows do not fit' % (len(lw) // 32))
    m = [blank] * (32 * 32)
    for i, e in enumerate(lw):
        if e & 0x3FF:
            m[LOAD_ROW * 32 + i] = (second + (e & 0x3FF)) | (e & 0xC000) | ATTR
    sets.append((t3, m))
    for n, (t, _) in enumerate(sets):
        top = (FIRST if n == 0 else second) + len(t)
        if top > LAST:
            sys.exit('title menu %d: tiles up to $%03X, room up to $%03X' % (n, top - 1, LAST - 1))
        if len(t) * 32 > 8192:
            sys.exit('title menu %d: %d tiles, more than the 8 KB buffer' % (n, len(t)))

    def wr(name, blob):
        open(os.path.join(comp, name), 'wb').write(sc.compress(blob))
    for n, (t, m) in enumerate(sets):
        wr('TitleMenu%d.def0' % n, b''.join(t))
        wr('TitleMenu%d.map0' % n, struct.pack('<1024H', *m))
    open(os.path.join(comp, 'titlemenu.inc'), 'w').write('\n'.join([
        '; generated by tools/titlemenus.py -- do not edit',
        '!TITLEMENU_BLANK = $%04X\t; map entry of the blank tile' % blank,
        '!TITLEMENU_VRAM0 = $%04X\t; VRAM word address of menu 0\'s tiles' % (0x4000 + 16 * FIRST),
        '!TITLEMENU_VRAMN = $%04X\t; VRAM word address of menu 1-3\'s tiles' % (0x4000 + 16 * second),
        '!TITLEMENU_SLOT0 = $%04X\t; map entry of SlotMenu.def0 tile 0 (+ slot font tile#)' % (second | ATTR),
        '!TITLEMENU_LOADROW = %d\t; first map row of the slot menu' % LOAD_ROW, '']))
    print('title menus: tiles %s (BG2 $%03X up, menus 1-3 from $%03X)' % ([len(t) for t, _ in sets], FIRST, second))


if __name__ == '__main__':
    main()
