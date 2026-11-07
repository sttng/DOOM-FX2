#!/usr/bin/env python3
"""
menus.py - the pause, save and load menus.

build: the save/load menu graphics from the data set (make data).

The cartridge's main menu art (RLDATA/COMP/MainMenu.*, the FX3 one) has
"Restart Level", "New Game", "Music: On", "Sounds: On" and "Rumble: On".  For
saving like the PC version we need "Save Game" and "Load Game" items and a
slot menu.  Nothing new is drawn by hand: the words are put together from
letters of the existing menu art (S, o, d from "Sounds", L, e, v from
"Level", a and "Game" from "New Game"), and the slot texts use DOOM's own HUD
font (STCFN033-STCFN090 from the player's DOOM.WAD), recoloured to the menu
palette.

Writes into DATA/RLDATA/COMP:
  PauseMenu.def0 / PauseMenu.map0   Restart Level / New Game / Save Game /
                                    Load Game / Music: On / Sounds: On /
                                    Rumble: On  (lines 15-16 pixels apart,
                                    14 tile rows; an On/Off line starts one
                                    pixel above its toggle glyphs' tile row)
  SlotMenu.def0                     "Save Game", "Load Game" titles + font
  SaveMenu.map0 / LoadMenu.map0     the two slot menus (titles only; the
                                    slot lines are written by the game)
  menus.inc                         On/Off toggle tiles, their map positions and
                                    the slot font table for the game code

  python3 tools/menus.py build DATADIR WAD [--png DIR]   (--png: preview images)

retouch: put the retouched Pause, Save Game and Load Game menus into a data set
(make data, and after wadart, fx3art, doom2 and shareware).

These three menus are cartridge-style art that `build` assembles from
letters of the cartridge menu font (the FX3 cartridge had no saving).
tools/menus/{PauseMenu,SaveMenu,LoadMenu}.png are hand-retouched versions
(any integer scale of the 256-pixel-wide menu, colours of menu palette 2).

The tool starts from the cartridge-style menus (DATA/RLART.fx3/COMP, kept by
wad2art.py; else DATA/RLDATA/COMP), changes only the 8x8 tiles that differ
from the PNG (a tile shared with unchanged places gets a new copy), and
writes PauseMenu.def0/.map0, SlotMenu.def0, SaveMenu.map0, LoadMenu.map0
and menus.inc (On/Off toggles, slot font) to DATA/RLDATA/COMP.  When the
PNG has the Music/Sounds/Rumble lines one pixel lower than the cartridge
layout (as tools/menus/PauseMenu.png does: tile aligned, so no On/Off block
covers the line below), the On/Off glyph tiles are moved down with them.  An
EpisodeMenu.png in the PNG directory, if there is one, patches the converted
episode menu the same way.  The other menus and the title stay as they are.

  python3 tools/menus.py retouch [--data DATA] [--png tools/menus]
"""
import argparse, os, shutil, struct, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'datagen'))
import snescomp as sc          # noqa: E402
from wad import WAD            # noqa: E402
from snesgfx import encode_tile, decode_tile, bgr555_to_rgb, bgr555_to_rgb8   # noqa: E402

# ---------------------------------------------------------------- build
PAL = 2                        # BG palette of the menu text
MENUS = (('PauseMenu', 'PauseMenu'), ('SaveMenu', 'SlotMenu'), ('LoadMenu', 'SlotMenu'))   # (menu, its tiles) retouch patches
PRIO = 0x2000


def load_menu(comp, name):
    d, _, _ = sc.decompress(open(os.path.join(comp, name + '.def0'), 'rb').read())
    m, _, _ = sc.decompress(open(os.path.join(comp, name + '.map0'), 'rb').read())
    w = struct.unpack('<%dH' % (len(m) // 2), m)
    tiles = [decode_tile(d, 32 * i, 4) for i in range(len(d) // 32)]
    rows = len(w) // 32
    img = np.zeros((rows * 8, 256), np.uint8)
    for i, e in enumerate(w):
        t = tiles[e & 0x3FF]
        if e & 0x4000:
            t = t[:, ::-1]
        if e & 0x8000:
            t = t[::-1, :]
        r, c = divmod(i, 32)
        img[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = t
    return img, w, tiles


class Tiler:
    """8x8 tiles with de-duplication; tile 0 is blank"""
    def __init__(self):
        self.tiles = [bytes(32)]
        self.index = {bytes(32): 0}

    def add(self, t):
        b = encode_tile(t, 4)
        if b not in self.index:
            self.index[b] = len(self.tiles)
            self.tiles.append(b)
        return self.index[b]

    def map_image(self, img):
        rows = img.shape[0] // 8
        words = []
        for r in range(rows):
            for c in range(32):
                t = img[r * 8:r * 8 + 8, c * 8:c * 8 + 8]
                n = self.add(t)
                words.append(0 if n == 0 else n | (PAL << 10) | PRIO)
        return words


def blit(dst, src, x, y):
    """paint the non-zero pixels of src; a letter's outline never covers the
    bright core (5,6,7) of its neighbour"""
    h, w = src.shape
    for yy in range(h):
        for xx in range(w):
            v = src[yy, xx]
            if not v:
                continue
            d = dst[y + yy, x + xx]
            if d in (5, 6, 7) and v not in (5, 6, 7):
                continue
            dst[y + yy, x + xx] = v


# pause menu lines: top row of each (screen y = top + 54, rlmenus.asm _RLMainMenuData);
# the On/Off ones at 8n-1, their toggle glyphs on map rows n, n+1 (MENUTOG).  This is
# the cartridge-style layout `build` makes; tools/menus/PauseMenu.png has the On/Off
# lines one pixel lower (8n, tile aligned) and `retouch` moves the glyphs with them
PAUSE_TOP = {'restart': 2, 'new': 17, 'save': 32, 'load': 47, 'music': 63, 'sounds': 79, 'rumble': 95}
TOGGLES = (('MUSIC', 'music', 16), ('SOUNDS', 'sounds', 18), ('RUMBLE', 'rumble', 18))   # (name, line, map column)


def build(data, wadfile, png=None):
    comp = os.path.join(data, 'RLDATA', 'COMP')
    A, w, _ = load_menu(comp, 'MainMenu')
    assert A.shape == (104, 256), A.shape                            # the FX3 main menu (with Rumble)
    glyph_row = 11                                                   # On/Off glyph tiles

    # ---- letters (column ranges = bright core +-1 outline column, 12 rows)
    LINE = {'restart': 2, 'new': 20, 'music': 38, 'sounds': 55}
    def letter(line, x0, x1):
        y = LINE[line]
        return A[y:y + 12, x0:x1 + 1].copy()
    L = {
        'S': letter('sounds', 61, 72), 'o': letter('sounds', 71, 81), 'd': letter('sounds', 99, 108),
        'L': letter('restart', 129, 138), 'e': letter('restart', 139, 147), 'v': letter('restart', 148, 156),
        'a': letter('new', 106, 115),
    }
    GAME = A[LINE['new']:LINE['new'] + 12, 97:140].copy()          # "Game"

    def word(img, y, x, letters, game=True):
        for ch in letters:
            g = L[ch]
            blit(img, g, x, y)
            x += g.shape[1] - 2                                      # 1 outline column shared
        if game:
            x += 6                                                   # word space (as "New Game")
            blit(img, GAME, x, y)

    # ---- pause menu: Restart Level / New Game / Save Game / Load Game / Music / Sounds / Rumble
    T = PAUSE_TOP
    P = np.zeros((14 * 8, 256), np.uint8)
    def line(src_top, dst_top, h=12):
        P[dst_top:dst_top + h] = np.maximum(P[dst_top:dst_top + h], A[src_top:src_top + h])
    line(2, T['restart'])                                            # Restart Level
    line(20, T['new'])                                               # New Game
    word(P, T['save'], 61, 'Save')
    word(P, T['load'], 61, 'Load')
    line(39, T['music'])                                             # Music: (+24 rows, tile aligned)
    line(55, T['sounds'])                                            # Sounds: (+24)
    line(71, T['rumble'])                                            # Rumble: (+24)
    tp = Tiler()
    pw = tp.map_image(P)
    # On/Off glyph tiles (main menu map rows 11-12, columns 0-3: "ff" = Off, "n" = On)
    g = glyph_row
    togw = {}
    for name, (r, c) in {'off00': (g, 0), 'off01': (g, 1), 'off10': (g + 1, 0), 'off11': (g + 1, 1),
                         'on00': (g, 2), 'on01': (g, 3), 'on10': (g + 1, 2), 'on11': (g + 1, 3)}.items():
        t = A[r * 8:r * 8 + 8, c * 8:c * 8 + 8]
        n = tp.add(t)
        togw[name] = 0 if n == 0 else n | (PAL << 10) | PRIO

    # ---- slot menus: title + DOOM HUD font
    W = WAD(wadfile)
    pp = W.get('PLAYPAL')[:768]
    doompal = [tuple(pp[3 * i:3 * i + 3]) for i in range(256)]
    snes = bgr555_to_rgb8(open(os.path.join(data, 'RLDATA', 'COLOUR', 'BASERGB.RGB'), 'rb').read())
    cand = [i for i in range(1, 16) if i not in (13, 15)]            # reds of palette 2
    def near(c):
        return min(cand, key=lambda i: sum((a - b) ** 2 for a, b in zip(c, snes[PAL * 16 + i])))
    ts = Tiler()
    font = {}
    for ch in range(32, 91):
        t = np.zeros((8, 8), np.uint8)
        lump = W.get('STCFN%03d' % ch) if ch > 32 else None
        if lump:
            gw, gh, lo, to = struct.unpack('<hhhh', lump[:8])
            for x in range(min(gw, 8)):
                o = struct.unpack('<i', lump[8 + 4 * x:12 + 4 * x])[0]
                while lump[o] != 255:
                    top, n = lump[o], lump[o + 1]
                    for k in range(n):
                        yy = top + k
                        if yy < 8:
                            t[yy, x] = near(doompal[lump[o + 3 + k]])
                    o += n + 4
        font[ch] = ts.add(t) if lump else 0
    S = np.zeros((14 * 8, 256), np.uint8)
    word(S, 2, 61, 'Save')
    savew = ts.map_image(S)
    S[:] = 0
    word(S, 2, 61, 'Load')
    loadw = ts.map_image(S)

    def wr(name, blob):
        open(os.path.join(comp, name), 'wb').write(sc.compress(blob))
    wr('PauseMenu.def0', b''.join(tp.tiles))
    wr('PauseMenu.map0', struct.pack('<%dH' % len(pw), *pw))
    wr('SlotMenu.def0', b''.join(ts.tiles))
    wr('SaveMenu.map0', struct.pack('<%dH' % len(savew), *savew))
    wr('LoadMenu.map0', struct.pack('<%dH' % len(loadw), *loadw))
    inc = ['; generated by tools/menus.py build -- do not edit']
    for k, v in togw.items():
        inc.append('!MENUTOG_%s = $%04X' % (k, v))
    for k in ('off02', 'off12', 'on02', 'on12'):                    # 3x2 toggle: third column blank
        inc.append('!MENUTOG_%s = $0000' % k)
    for name, ln, col in TOGGLES:                                    # map positions of the On/Off tiles
        assert (T[ln] + 1) % 8 == 0
        inc.append('!MENUTOG_%s = (%d*32)+%d\t; map position of the %s On/Off tiles (menu rows)' % (name, (T[ln] + 1) // 8, col, ln.capitalize()))
    inc.append('!SLOTFONT_PAL = $%04X\t; palette/priority bits of a slot font map entry' % ((PAL << 10) | PRIO))
    inc.append('macro slotfont_table()')
    for ch in range(32, 91):
        inc.append('\tdb $%02X\t; %r' % (font[ch], chr(ch)))
    inc.append('endmacro')
    open(os.path.join(comp, 'menus.inc'), 'w').write('\n'.join(inc) + '\n')
    print('pause menu %d tiles, slot menu %d tiles' % (len(tp.tiles), len(ts.tiles)))
    if png:
        out = os.path.abspath(png)
        os.makedirs(out, exist_ok=True)
        cols = [(0, 0, 0)] + [snes[PAL * 16 + i] for i in range(1, 16)]
        for nm, img in (('pause', P), ('slot', S)):
            im = Image.fromarray(np.array([[cols[v] for v in row] for row in img], np.uint8))
            im.resize((im.width * 3, im.height * 3), Image.NEAREST).save(os.path.join(out, nm + '.png'))
        fim = np.zeros((8, 8 * 59), np.uint8)
        tiles = [decode_tile(ts.tiles[font[ch]], 0, 4) for ch in range(32, 91)]
        for i, t in enumerate(tiles):
            fim[:, i * 8:i * 8 + 8] = t
        im = Image.fromarray(np.array([[cols[v] for v in row] for row in fim], np.uint8))
        im.resize((im.width * 3, im.height * 3), Image.NEAREST).save(os.path.join(out, 'font.png'))


# ---------------------------------------------------------------- retouch
def load_png(path):
    """PNG -> RGB array at 256 pixels wide (an integer scale is undone)"""
    a = np.array(Image.open(path).convert('RGB'))
    s = a.shape[1] // 256
    if a.shape[1] != 256 * s or a.shape[0] % s:
        sys.exit('%s: width must be 256 x an integer scale' % path)
    return a[::s, ::s]


def patch(menus, src, out, pal, pngdir):
    """change the tiles of MENUS ((menu, def) pairs, read from SRC) that differ from
    PNGDIR/<menu>.png; write them to OUT.  Returns the number of tiles changed."""
    rd = lambda n: sc.decompress(open(os.path.join(src, n), 'rb').read())[0]
    defs = {d: bytearray(rd(d + '.def0')) for _, d in menus}
    maps = {m: list(struct.unpack('<%dH' % (len(rd(m + '.map0')) // 2), rd(m + '.map0'))) for m, _ in menus}
    users = {d: {} for d in defs}                       # tile -> the map entries showing it
    for m, d in menus:
        for i, e in enumerate(maps[m]):
            users[d].setdefault(e & 0x3FF, []).append((m, i))
    changed = 0
    for m, d in menus:
        png = load_png(os.path.join(pngdir, m + '.png'))
        rows = len(maps[m]) // 32
        if png.shape[0] < rows * 8:
            png = np.concatenate([png, np.zeros((rows * 8 - png.shape[0], 256, 3), png.dtype)])
        for i, e in enumerate(maps[m]):
            r, c = divmod(i, 32)
            want = png[r * 8:r * 8 + 8, c * 8:c * 8 + 8].astype(int)
            t = decode_tile(defs[d], 32 * (e & 0x3FF), 4)
            t = t[:, ::-1] if e & 0x4000 else t
            t = t[::-1] if e & 0x8000 else t
            if (pal[t] == want).all():
                continue
            # new pixels: keep the old index where the colour is unchanged, else the nearest
            dist = ((want[:, :, None, :] - pal[None, None]) ** 2).sum(3)
            nt = np.where((pal[t] == want).all(2), t, dist.argmin(2)).astype(np.uint8)
            nt = nt[::-1] if e & 0x8000 else nt
            nt = nt[:, ::-1] if e & 0x4000 else nt
            k = e & 0x3FF
            if len(users[d][k]) > 1:                    # shared: give this place its own tile
                users[d][k].remove((m, i))
                k = len(defs[d]) // 32
                defs[d] += bytes(32)
                users[d][k] = [(m, i)]
                maps[m][i] = (e & ~0x3FF) | k
            defs[d][32 * k:32 * k + 32] = encode_tile(nt, 4)
            changed += 1
    for d, b in defs.items():
        if len(b) // 32 > 256:
            sys.exit('%s: %d tiles (max 256)' % (d, len(b) // 32))
        open(os.path.join(out, d + '.def0'), 'wb').write(sc.compress(bytes(b)))
    for m, _ in menus:
        open(os.path.join(out, m + '.map0'), 'wb').write(sc.compress(struct.pack('<%dH' % len(maps[m]), *maps[m])))
    return changed


def toggle_drop(pngdir):
    """how many pixels lower than the cartridge layout (PAUSE_TOP) PauseMenu.png has its
    Music/Sounds/Rumble lines: the On/Off glyph tiles are drawn that much lower"""
    png = load_png(os.path.join(pngdir, 'PauseMenu.png'))
    drops = set()
    for ln in ('music', 'sounds', 'rumble'):
        y = PAUSE_TOP[ln] - 2
        while y < png.shape[0] and not png[y].any():
            y += 1
        drops.add(y - PAUSE_TOP[ln])
    if len(drops) != 1 or not drops <= {0, 1}:
        sys.exit('PauseMenu.png: the Music/Sounds/Rumble lines must start at rows %s or one lower (found %s)'
                 % ([PAUSE_TOP[l] for l in ('music', 'sounds', 'rumble')], sorted(drops)))
    return drops.pop()


def drop_toggles(out, inc, drop):
    """MENUS.INC with On/Off glyph tiles DROP pixels lower (new tiles added to
    PauseMenu.def0).  The glyphs are 2x2 tiles drawn on the map rows below an On/Off
    line's top; with the line one pixel lower (tile aligned) the whole "O" sits in its
    own rows, and Music's glyphs no longer blank the top of Sounds' "O"."""
    if not drop:
        return inc
    rd = lambda n: sc.decompress(open(os.path.join(out, n), 'rb').read())[0]
    d = bytearray(rd('PauseMenu.def0'))
    val = {}
    for l in inc.split('\n'):
        if l.startswith('!MENUTOG_o') and '=' in l:
            k, v = l.split('=')
            val[k.strip()[9:]] = int(v.strip().lstrip('$'), 16)
    for st in ('off', 'on'):
        g = np.zeros((16, 16), np.uint8)
        for r in range(2):
            for c in range(2):
                e = val['%s%d%d' % (st, r, c)]
                if e:
                    g[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = decode_tile(d, 32 * (e & 0x3FF), 4)
        if g[16 - drop:].any():
            sys.exit('On/Off glyphs: no room to move them down %d pixel(s)' % drop)
        g = np.concatenate([np.zeros((drop, 16), np.uint8), g[:16 - drop]])
        for r in range(2):
            for c in range(2):
                t = encode_tile(g[r * 8:r * 8 + 8, c * 8:c * 8 + 8], 4)
                k = len(d) // 32
                d += t
                val['%s%d%d' % (st, r, c)] = k | (PAL << 10) | PRIO
    if len(d) // 32 > 256:
        sys.exit('PauseMenu.def0: %d tiles (max 256)' % (len(d) // 32))
    open(os.path.join(out, 'PauseMenu.def0'), 'wb').write(sc.compress(bytes(d)))
    lines = []
    for l in inc.split('\n'):
        k = l.split('=')[0].strip()
        if k.startswith('!MENUTOG_o') and k[9:] in val and k[9:][-1] != '2':
            l = '%s = $%04X\t; (menus.py retouch: %d pixel(s) lower)' % (k, val[k[9:]], drop)
        lines.append(l)
    return '\n'.join(lines)


def retouch(data, pngdir):
    out = os.path.join(data, 'RLDATA', 'COMP')
    src = os.path.join(data, 'RLART.fx3', 'COMP')
    if not os.path.isdir(src):
        src = out
    cg = bgr555_to_rgb(open(os.path.join(data, 'RLDATA', 'COLOUR', 'BASERGB.RGB'), 'rb').read()[:512])
    pal = np.array([(0, 0, 0)] + [cg[PAL * 16 + i] for i in range(1, 16)], int)
    drop = toggle_drop(pngdir)
    n = patch(MENUS, src, out, pal, pngdir)
    inc = open(os.path.join(src, 'menus.inc')).read()
    open(os.path.join(out, 'menus.inc'), 'w').write(drop_toggles(out, inc, drop))
    print('menus retouch: Pause/Save/Load menus from %s (%d tiles changed%s)'
          % (pngdir, n, ', On/Off glyphs %d pixel lower' % drop if drop else ''))
    if os.path.exists(os.path.join(pngdir, 'EpisodeMenu.png')):    # (optional; tools/menus has none)
        n = patch((('EpisodeMenu', 'EpisodeMenu'),), out, out, pal, pngdir)
        print('menus retouch: episode menu from %s (%d tiles changed)' % (pngdir, n))


def main():
    ap = argparse.ArgumentParser(description='the pause, save and load menus')
    sub = ap.add_subparsers(dest='cmd', required=True)
    b = sub.add_parser('build', help='assemble them from the cartridge menu art (make data)')
    b.add_argument('data'); b.add_argument('wad'); b.add_argument('--png', help='also write preview images here')
    r = sub.add_parser('retouch', help='put in the hand-retouched tools/menus/*.png')
    r.add_argument('--data', default=os.path.join(HERE, '..', 'data'))
    r.add_argument('--png', default=os.path.join(HERE, 'menus'))
    a = ap.parse_args()
    if a.cmd == 'build':
        build(a.data, a.wad, a.png)
    else:
        retouch(a.data, a.png)


if __name__ == '__main__':
    main()
