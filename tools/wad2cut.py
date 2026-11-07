#!/usr/bin/env python3
"""
wad2cut.py -- weapon HUD frames from a WAD in the CUTTER weapon format (RLDATA/CUT/<weapon>/).

usage: wad2cut.py --data DATA --wad DOOM2.WAD                -> RLDATA/CUT/SuperShotGun/
       wad2cut.py --data DATA --wad DOOM1.WAD --weapons Fist,Pistol,ShotGun,ChainSaw,ChainGun,Rocket
                                                             -> RLDATA/CUT/<weapon>/
       wad2cut.py show DATA WEAPON OUT.png                    (render a weapon's images)

Each PC frame is scaled by SCALE (0.675: the 216-pixel SNES view of the 320-pixel
PC screen) with area averaging, placed by its PC offsets (PC x 160 / y 168 -> SNES
CX / CY), cut into 8x8 OBJ tiles (empty ones left out), each tile in the OBJ palette
with the least colour error.  If a weapon's frames exceed the format's limits, the
biggest frame is shrunk 1 % at a time.  Frames per weapon: WEAPONS, in the order of
rlweapons.asm WeaponFrameList<weapon>.  Super shotgun (6 images, the limit):

  0 SHT2A0 ready        1 SHT2I0 flash        2 SHT2B0 fired
  3 SHT2D0 open         4 SHT2F0 shells in    5 SHT2H0 closing

(C, E, G and the second flash J are left out: E alone is 201 pixels wide.)

The CUT format:

  .imagetbl  per image: dw CharData index, dw MiscData index
  .miscdata  per image: db #OAMs, then per OAM db flags (%vhppccc1: flips, priority, OBJ palette), x, y (signed)
  .chardata  per image: the master character (8x8 4bpp tile) of each OAM, compressed
             (rlweapons.asm _GetCharDataMChr): $00-$BF hh ll unique char $hhll;
             $E0-$EF next 1-16 chars in sequence; $F0-$F7 the last char 1-8 times;
             $F8-$FB 1-4 transparent (char 0); $C0-$DF/$FC-$FF repeat earlier data
  .chardef   the tiles, 32 bytes each (SNES 4bpp), char 0 blank
Limits (rlcut.inc): 6 images, 128 bytes CharData, 704 bytes MiscData, 7168 bytes CharDef
(224 tiles); a frame shows at most RLMaxCutSprOAMs OAMs (rle.inc: 128-32 = 96).
"""
import argparse, os, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'datagen'))
from snesgfx import encode_tile, bgr555_to_rgb8  # noqa: E402
from wad import WAD                              # noqa: E402


# ---------------------------------------------------------------- the CUT format
MAXIMAGES, MAXCHARDATA, MAXMISCDATA, MAXCHARDEF, MAXOAMS = 6, 128, 704, 7168, 96


def chars_of(cd, x, n):
    """the n master chars of the image whose CharData starts at x"""
    out = []
    mode = reps = 0
    dups = -1
    stack = []
    nt = 0
    while len(out) < n:
        if mode:
            if reps == 0:
                mode = 0
                continue
            reps -= 1
            if mode == 1:
                nt += 1; out.append(nt)
            elif mode == 2:
                out.append(nt)
            else:
                out.append(0)
            continue
        if dups == 0:
            x, dups = stack.pop()
            continue
        c = cd[x]
        if c < 0xC0:
            nt = (c << 8) | cd[x + 1]
            if dups >= 0:
                dups -= 1
            x += 2
            out.append(nt)
            continue

        def start(m, r):
            nonlocal mode, reps, dups
            mode = m
            if dups >= 0:
                r = min(r, dups)
                dups -= r
            reps = r
        if c < 0xE0 or c >= 0xFC:
            if c < 0xE0:
                r = (c & 0x1F) + 2; x += 1
            else:
                r = (((c & 3) << 8) | cd[x + 1]) + 34; x += 2
            if dups >= 0:
                r = min(r, dups); dups -= r
            stack.append((x + 2, dups))
            dups = r
            x = struct.unpack_from('<H', cd, x)[0]
            continue
        x += 1
        if c < 0xF0:
            start(1, (c & 0x0F) + 1)
        elif c < 0xF8:
            start(2, (c & 7) + 1)
        else:
            start(3, (c & 3) + 1)
    return out


def tile(cdef, n):
    """8x8 colour indices (0-15) of tile n"""
    t = cdef[32 * n:32 * n + 32]
    px = [[0] * 8 for _ in range(8)]
    for y in range(8):
        p0, p1, p2, p3 = t[2 * y], t[2 * y + 1], t[16 + 2 * y], t[17 + 2 * y]
        for x in range(8):
            b = 7 - x
            px[y][x] = ((p0 >> b) & 1) | (((p1 >> b) & 1) << 1) | (((p2 >> b) & 1) << 2) | (((p3 >> b) & 1) << 3)
    return px


def read(d):
    """[(oams: [(flags, x, y, char)], ...)], chardef"""
    it = open(os.path.join(d, '.imagetbl'), 'rb').read()
    md = open(os.path.join(d, '.miscdata'), 'rb').read()
    cd = open(os.path.join(d, '.chardata'), 'rb').read()
    cdef = open(os.path.join(d, '.chardef'), 'rb').read()
    imgs = []
    for i in range(len(it) // 4):
        ci, mi = struct.unpack_from('<HH', it, 4 * i)
        n = md[mi]
        ch = chars_of(cd, ci, n)
        oams = []
        for k in range(n):
            f, x, y = md[mi + 1 + 3 * k:mi + 4 + 3 * k]
            oams.append((f, x - 256 if x >= 128 else x, y - 256 if y >= 128 else y, ch[k]))
        imgs.append(oams)
    return imgs, cdef


def write(d, imgs, tiles):
    """IMGS: per image a list of (flags, x, y, tile#) with tile# 1.. in order of first use
    (each image's chars consecutive); TILES: 32-byte tiles (tile 0 = blank)"""
    os.makedirs(d, exist_ok=True)
    it, md, cd = bytearray(), bytearray(), bytearray()
    for oams in imgs:
        it += struct.pack('<HH', len(cd), len(md))
        md.append(len(oams))
        for f, x, y, _ in oams:
            md += bytes([f, x & 0xFF, y & 0xFF])
        prev = 0                                 # (the engine starts each image at char 0)
        chars = [c for _, _, _, c in oams]
        k = 0
        while k < len(chars):
            c = chars[k]
            if c == prev + 1:
                r = 1
                while k + r < len(chars) and r < 16 and chars[k + r] == c + r:
                    r += 1
                cd.append(0xE0 | (r - 1)); k += r; prev = c + r - 1
                continue
            assert c < 0xC000
            cd += bytes([c >> 8, c & 0xFF]); prev = c; k += 1
    cdef = b''.join(tiles)
    assert len(imgs) <= MAXIMAGES and len(cd) <= MAXCHARDATA and len(md) <= MAXMISCDATA \
        and len(cdef) <= MAXCHARDEF, (len(imgs), len(cd), len(md), len(cdef))
    for nm, b in (('.imagetbl', it), ('.miscdata', md), ('.chardata', cd), ('.chardef', cdef)):
        open(os.path.join(d, nm), 'wb').write(bytes(b))
    return len(cd), len(md), len(cdef)


def palette(data):
    """the 256 game colours at full light (OBJ colour c of palette p = 128 + 16 p + c)"""
    return bgr555_to_rgb8(open(os.path.join(data, 'RLDATA', 'COLOUR', 'BASERGB.RGB'), 'rb').read())


def render(imgs, cdef, pal):
    """each image as (PIL image, x0, y0): its OAMs drawn, x0/y0 = the top left OAM position"""
    from PIL import Image
    out = []
    for oams in imgs:
        if not oams:
            out.append((Image.new('RGB', (8, 8)), 0, 0)); continue
        x0 = min(x for _, x, _, _ in oams); y0 = min(y for _, _, y, _ in oams)
        x1 = max(x for _, x, _, _ in oams) + 8; y1 = max(y for _, _, y, _ in oams) + 8
        im = Image.new('RGB', (x1 - x0, y1 - y0), (60, 0, 60))
        for f, x, y, c in oams:
            p = (f >> 1) & 7
            t = tile(cdef, c)
            for ty in range(8):
                for tx in range(8):
                    v = t[ty][7 - tx if f & 0x40 else tx] if not f & 0x80 else t[7 - ty][7 - tx if f & 0x40 else tx]
                    if v:
                        im.putpixel((x - x0 + tx, y - y0 + ty), pal[128 + 16 * p + v])
        out.append((im, x0, y0))
    return out


# ---------------------------------------------------------------- from a WAD
FRAMES = ['SHT2A0', 'SHT2I0', 'SHT2B0', 'SHT2D0', 'SHT2F0', 'SHT2H0']
# the cartridge weapons' images, in the order rlweapons.asm WeaponFrameList<weapon> uses them
WEAPONS = {
    'Fist': ['PUNGA0', 'PUNGB0', 'PUNGC0', 'PUNGD0'],
    'Pistol': ['PISGA0', 'PISGB0', 'PISGC0', 'PISFA0'],
    'ShotGun': ['SHTGA0', 'SHTGB0', 'SHTGC0', 'SHTGD0', 'SHTFA0', 'SHTFB0'],
    'ChainSaw': ['SAWGC0', 'SAWGD0', 'SAWGA0', 'SAWGB0'],
    'ChainGun': ['CHGGA0', 'CHGGB0', 'CHGFA0', 'CHGFB0'],
    'Rocket': ['MISGA0', 'MISGB0', 'MISFA0', 'MISFB0', 'MISFC0', 'MISFD0'],
    'Plasma': ['PLSGA0', 'PLSGB0', 'PLSFA0', 'PLSFB0'],
    'BFG': ['BFGGA0', 'BFGFA0', 'BFGFB0'],
    'SuperShotGun': FRAMES,
}
SCALE = 0.675
CX, CY = 7, 75                                   # SNES position of PC (160, 168)
FLAGS = 0x11                                     # %vhppccc1: priority 1, palette in bits 1-3 (py)
VIEW_BOTTOM = 71                                 # last row of the 3D view (OAM y): lower rows are
                                                 # behind the status bar (every cartridge frame ends there)


def wad_patch(w, name):
    """(width, height, leftoffset, topoffset, rows of palette index or -1)"""
    s, e = w.find('S_START'), w.find('S_END')
    k = next((k for k in range(s, e) if w.lumps[k][0] == name), None)
    if k is None:
        sys.exit('%s: not in the WAD' % name)
    d = w.data(k)
    W, H, lo, to = struct.unpack('<hhhh', d[:8])
    a = [[-1] * W for _ in range(H)]
    for x in range(W):
        o = struct.unpack('<i', d[8 + 4 * x:12 + 4 * x])[0]
        while d[o] != 255:
            top, n = d[o], d[o + 1]
            for i in range(n):
                a[top + i][x] = d[o + 3 + i]
            o += n + 4
    return W, H, lo, to, a


def convert(data, wads, weapon='SuperShotGun'):
    from PIL import Image
    w = WAD(wads[-1])
    pp = None
    for p in reversed(wads):
        ww = WAD(p)
        try:
            pp = ww.data(ww.find('PLAYPAL'))[:768]; break
        except Exception:
            continue
    pc = [tuple(pp[3 * i:3 * i + 3]) for i in range(256)]
    game = palette(data)
    pals = [[game[128 + 16 * p + c] for c in range(16)] for p in range(8)]
    pats = {nm: wad_patch(w, nm) for nm in WEAPONS[weapon]}

    def image(nm, scale):
        """the frame at `scale`: [(flags, x, y, tile bytes)]"""
        W, H, lo, to, a = pats[nm]
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        for y in range(H):
            for x in range(W):
                if a[y][x] >= 0:
                    im.putpixel((x, y), pc[a[y][x]] + (255,))
        # PC screen position: x = -lo, y = -to (WEAPONTOP cancels the renderer's BASEYCENTER)
        x0, y0 = -lo, -to
        sx0 = round(scale * (x0 - 160)) + CX
        sy0 = round(scale * (y0 - 168)) + CY
        sw, sh = max(1, round(W * scale)), max(1, round(H * scale))
        sm = im.resize((sw, sh), Image.BOX)

        def opaque(x, y):
            return 0 <= x < sw and 0 <= y < sh and sy0 + y <= VIEW_BOTTOM and sm.getpixel((x, y))[3] >= 128
        op = {(x, y) for y in range(sh) for x in range(sw) if opaque(x, y)}
        # the 8x8 grid position that needs the fewest tiles (OAMs can sit anywhere)
        gx, gy = min(((gx, gy) for gy in range(8) for gx in range(8)),
                     key=lambda g: len({((x + g[0]) // 8, (y + g[1]) // 8) for x, y in op}))
        oams = []
        for ty in range(-gy, sh, 8):
            for tx in range(-gx, sw, 8):
                px = [[sm.getpixel((tx + x, ty + y)) if opaque(tx + x, ty + y) else (0, 0, 0, 0)
                       for x in range(8)] for y in range(8)]
                if not any(p[3] >= 128 for row in px for p in row):
                    continue
                best = None
                for p in range(8):
                    err, t = 0, []
                    for row in px:
                        r = []
                        for c in row:
                            if c[3] < 128:
                                r.append(0); continue
                            e, v = min((sum((c[i] - pals[p][k][i]) ** 2 for i in range(3)), k)
                                       for k in range(1, 16))
                            err += e; r.append(v)
                        t.append(r)
                    if best is None or err < best[0]:
                        best = (err, p, t)
                _, p, t = best
                oams.append((FLAGS | (p << 1), sx0 + tx, sy0 + ty, encode_tile(t, 4)))
        return oams

    # every frame at SCALE; while the frames exceed CharDef / MiscData / OAM limits, the
    # biggest is shrunk 1 % at a time (as the cartridge did with the shotgun's reload frames)
    names = WEAPONS[weapon]
    scale = {nm: SCALE for nm in names}
    cache = {}
    while True:
        frames = [cache.setdefault((nm, scale[nm]), image(nm, scale[nm])) for nm in names]
        ntiles = 1 + sum(len(f) for f in frames)
        misc = sum(1 + 3 * len(f) for f in frames)
        if ntiles * 32 <= MAXCHARDEF and misc <= MAXMISCDATA and \
                all(len(f) <= MAXOAMS for f in frames):
            break
        big = max(range(len(names)), key=lambda k: len(frames[k]))
        scale[names[big]] = round(scale[names[big]] - 0.01, 2)
    imgs, tiles = [], [bytes(32)]
    for f in frames:
        oams = []
        for fl, x, y, t in f:
            tiles.append(t)
            oams.append((fl, x, y, len(tiles) - 1))
        imgs.append(oams)
    small = ['%s %.2f' % (nm, scale[nm]) for nm in names if scale[nm] != SCALE]
    if small:
        print('%s: shrunk to fit: %s' % (weapon, ', '.join(small)))
    d = os.path.join(data, 'RLDATA', 'CUT', weapon)
    ncd, nmd, ncdef = write(d, imgs, tiles)
    print('%s: %d images, %s OAMs, %d tiles (CharData %d/%d, MiscData %d/%d, CharDef %d/%d bytes)'
          % (weapon, len(imgs), '+'.join(str(len(o)) for o in imgs), len(tiles), ncd, MAXCHARDATA,
             nmd, MAXMISCDATA, ncdef, MAXCHARDEF))
    return imgs


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[1])
    ap.add_argument('--data', default=os.path.join(HERE, '..', 'data'))
    ap.add_argument('--wad', action='append', required=True)
    ap.add_argument('--weapons', default='SuperShotGun',
                    help='comma-separated: %s (default SuperShotGun)' % ','.join(WEAPONS))
    a = ap.parse_args()
    for wp in a.weapons.split(','):
        convert(a.data, a.wad, wp)


def show(data, wpn, png):
    from PIL import Image
    imgs, cdef = read(os.path.join(data, 'RLDATA', 'CUT', wpn))
    r = render(imgs, cdef, palette(data))
    W = sum(i.width + 8 for i, _, _ in r); H = max(i.height for i, _, _ in r)
    s = Image.new('RGB', (W, H), (30, 30, 30)); x = 0
    for (i, x0, y0), oams in zip(r, imgs):
        s.paste(i, (x, 0)); x += i.width + 8
        print('image: %d OAMs, origin %d,%d, %dx%d' % (len(oams), x0, y0, i.width, i.height))
    s.resize((W * 3, H * 3), Image.NEAREST).save(png)


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'show':
        show(*sys.argv[2:5])
    else:
        main()
