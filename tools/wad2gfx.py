#!/usr/bin/env python3
"""
wad2gfx.py -- walls and sprites from a DOOM WAD for the Reality Engine.

The cartridge's walls and sprites are the PC art in the SNES palette, cut
down by hand (one repeat of repeating textures, half-width skies, the biggest
monsters at ~87 %, wall columns shown as a copy of another column).  This
tool does the same from the WAD:

  learn    match the cartridge walls/sprites (RLDATA, FX3 order) to the WAD:
           per wall texture, size and offset, per sprite lump and size, and
           the WAD-to-SNES colour map -> DATA/wad2gfx.json.  Backs up the
           cartridge graphics to DATA/RLGFX.fx3 (for art the WAD lacks and
           for 'restore').
  convert  rebuild RLDATA/WALLS, IMAGES and WALLIMG from the WAD (wall
           format 1).  If the strips do not fit the 20 wall/sprite banks
           (more with --bank-1f / --extra-banks), wall columns are shown as
           the most similar column of the same wall, least error per byte
           first.  Options:
             --masked         also the see-through middle textures of
                              two-sided lines (IMAGES/MASKED.TBL, MASKED.JSON
                              for wad2rl.py); --masked-opaque adds those
                              without holes; --masked-budget caps the bytes
             --drop-unused    only the walls the kept levels show and the
                              sprites the WAD has; the rest become 1x1
                              placeholders (shareware WAD)
             --doom2-monsters DOOM II monsters as image page 1 (DOOM2_PAGE1)
             --map-walls      (DOOM II) a wall set made for the WAD's maps
                              (tools/wallset.py): wall format 2 (run-length
                              strips) or with --vq format 3 (2x4 texel blocks,
                              tools/wallvq.py); masked middle textures always
                              (unless --no-masked); writes WALLS/WALLMAP.JSON
                              for wad2rl.py --walls; --bank-3f fills $3F too;
                              --masked-banks "3C 39" gives the masked textures
                              those banks first (the walls get no more than
                              without them)
           Masked middle textures: at most 255 high, 256 wide and 32 of
           them, chosen by area seen per strip byte within the budget
           (--masked-maps: on these maps only).
  compare  per wall/sprite: likeness to the cartridge, error against the WAD;
           --png DIR writes comparison sheets
  restore  put the cartridge graphics back

Colours: the SNES palette is PLAYPAL in 5-bit colour (reordered).  A WAD
colour maps to the SNES index the cartridge uses most for it, else to the
nearest SNES colour.  Sprites cannot use index 0 (the strip format's escape).
A PWAD with its own PLAYPAL is mapped by nearest colour.

usage: wad2gfx.py learn   --data DATA --wad DOOM.WAD [--src DIR (default tools/doomfx-src)]
       wad2gfx.py convert --data DATA --wad DOOM.WAD [--wad PWAD] [--lossless] [--masked [--masked-opaque]
                          [--masked-budget N] [--masked-maps "MAP01 ..."]] [--drop-unused] [--doom2-monsters]
                          [--bank-1f] [--extra-banks]
       wad2gfx.py convert --data DATA --wad DOOM2.WAD --map-walls [--vq] [--bank-3f [--bank-3f-size N]]
                          [--masked-banks "3C ..."] [...]   (see --help)
       wad2gfx.py compare --data DATA --wad DOOM.WAD [--png DIR] [-v]
       wad2gfx.py restore --data DATA
"""
import argparse, collections, heapq, json, os, shutil, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import numpy as np                                                   # noqa: E402
import fx3_gfx as G                                                  # noqa: E402
from wad import WAD                                                  # noqa: E402
sys.path.insert(0, os.path.join(HERE, 'datagen'))
from snesgfx import bgr555_to_rgb8                                   # noqa: E402

GFXDIRS = ('WALLS', 'IMAGES', 'WALLIMG', 'COLOUR')
from gfxlimits import EXTRA_BANKS, BANK_3F, MASKED_BANKS, BANKS, NRAW  # noqa: E402  (every wall/sprite bank)
# convert packs into $1F only with --bank-1f: the cartridge set needs a few KB of it
# (232 images), a WAD conversion fills every bank it gets, and with 36 DOOM maps the
# GamePak ROM has no 32 KB to spare (DOOM II's 32 maps leave room: make doom2set uses it)
PACK_BANKS = [b for b in BANKS if b != 0x1F and b not in EXTRA_BANKS and b != BANK_3F and b not in MASKED_BANKS]
BANK_LIMIT = {0x1D: 0x55CD}
# The wall drawer has no strip end: a strip drawn taller than its texture (DOOM II's
# tall walls, clipped at the top of the view) reads on into the following bytes.
# After the last strip of a bank that would be the next ROM data, or past $FFFF the
# bank's lower half; a $00 byte there is a 0-pixel run and the GSU loops forever
# (DOOM II MAP01).  Sprite strips use $00 as an escape, so the wall strips of a bank
# are followed by 4 runs of 128 pixels before its sprite strips start, and each bank
# ends with them too (tools/gfxlimits.py checks every strip).
GUARD = bytes([0x80, 0x00]) * 4
SKY_AT = {0: (0x01, 0x0000), 1: (0x01, 0x4000), 2: (0x02, 0x0000), 3: (0x02, 0x4000)}   # SKY1-SKY4: raw 128x128
# DOOM II monsters (--doom2-monsters; the engine with !RLDOOM2MONSTERS = 1): image
# page 1 (objects with rlodfPage1 take image numbers 256+, so the cartridge's 232
# images stay as they are).  Front frames 1:1 like the cartridge's monsters, except
# the two biggest (mancubus, pain elemental) at 0.85 like the FX3 cyberdemon.  Each
# entry: (rlimages.inc tag, frames); a frame is a WAD sprite, (sprite, scale), or
# '=NAME' for a page 0 image shown again (no second copy).  convert writes the tags
# to RLDATA/IMAGES/IMAGES1.INC (rlimages.inc includes it).
DOOM2_PAGE1 = [
    ('inChainGunnerWalk', ['CPOSA1', 'CPOSB1', 'CPOSC1', 'CPOSD1']),
    ('inChainGunnerShoot', ['CPOSE1', 'CPOSF1']),
    ('inChainGunnerHit', ['CPOSG1']),
    ('inChainGunnerDie', ['CPOSH0', 'CPOSJ0', 'CPOSL0', 'CPOSN0']),
    ('inWolfSSWalk', ['SSWVA1', 'SSWVB1', 'SSWVC1', 'SSWVD1']),
    ('inWolfSSShoot', ['SSWVE0', 'SSWVF0', 'SSWVG0']),
    ('inWolfSSHit', ['SSWVH0']),
    ('inWolfSSDie', ['SSWVI0', 'SSWVK0', 'SSWVM0']),
    ('inHellKnightWalk', ['BOS2A1C1', 'BOS2B1D1']),
    ('inHellKnightShoot', ['BOS2E1', 'BOS2F1', 'BOS2G1']),
    ('inHellKnightHit', ['BOS2H1']),
    ('inHellKnightDie', ['BOS2I0', 'BOS2K0', 'BOS2M0', 'BOS2O0']),
    ('inArachnotronWalk', ['BSPIA1D1', 'BSPIB1E1', 'BSPIC1F1']),
    ('inArachnotronShoot', ['BSPIG1', 'BSPIH1']),
    ('inArachnotronHit', ['BSPII1']),
    ('inArachnotronDie', ['BSPIJ0', 'BSPIL0', 'BSPIN0', 'BSPIP0']),
    ('inArachPlasma', ['APLSA0', 'APLSB0', 'APBXA0', 'APBXB0', 'APBXC0']),
    ('inMancubusWalk', [('FATTA1', .85), ('FATTB1', .85), ('FATTC1', .85)]),
    ('inMancubusShoot', [('FATTG1', .85), ('FATTH1', .85)]),
    ('inMancubusHit', [('FATTJ1', .85)]),
    ('inMancubusDie', [('FATTK0', .85), ('FATTM0', .85), ('FATTO0', .85), ('FATTT0', .85)]),
    ('inMancubusShot', ['MANFA1', 'MANFB1', '=MISLB0', '=MISLC0', '=MISLD0']),
    ('inRevenantWalk', ['SKELA1D1', 'SKELB1E1', 'SKELC1F1']),
    ('inRevenantShoot', ['SKELJ1', 'SKELK1']),
    ('inRevenantHit', ['SKELL1']),
    ('inRevenantDie', ['SKELM0', 'SKELO0', 'SKELQ0']),
    ('inRevenantShot', ['FATBA1', 'FBXPA0', 'FBXPB0', 'FBXPC0']),
    ('inPainElemWalk', [('PAINA1', .85), ('PAINB1', .85), ('PAINC1', .85)]),
    ('inPainElemShoot', [('PAINE1', .85), ('PAINF1', .85)]),
    ('inPainElemHit', [('PAING1', .85)]),
    ('inPainElemDie', [('PAINH0', .85), ('PAINJ0', .85), ('PAINL0', .85)]),
    ('inArchVileWalk', ['VILEA1D1', 'VILEB1E1', 'VILEC1F1']),
    ('inArchVileShoot', ['VILEG1', 'VILEJ1', 'VILEO1']),
    ('inArchVileHit', ['VILEQ1']),
    ('inArchVileDie', ['VILER0', 'VILET0', 'VILEV0', 'VILEX0', 'VILEZ0']),
    ('inArchVileFire', ['FIREA0', 'FIREC0', 'FIREE0', 'FIREG0']),
    ('inKeen', ['KEENA0']),
    ('inKeenHit', ['KEENM0']),
    ('inKeenDie', ['KEENB0', 'KEENE0', 'KEENH0', 'KEENL0']),
    ('inBossBrain', ['BBRNA0', 'BBRNB0']),
    ('inSuperShotGunItem', ['SGN2A0']),
]
MARGIN = 6000                                                        # pack: slack for bank ends (strips do not cross banks)


def log(*a):
    print(*a, flush=True)


class Art:
    """a[y, x] = colour index, -1 = clear (y = 0 is the top)"""
    def __init__(self, name, a):
        self.name, self.a = name, a

    w = property(lambda s: s.a.shape[1])
    h = property(lambda s: s.a.shape[0])


def resample(src, w, h, sx=1.0, sy=1.0, dx=0, dy=0, wrap=True):
    """nearest neighbour: dst(x, y) = src(floor(x*sx) + dx, floor(y*sy) + dy)"""
    xs = np.floor(np.arange(w) * sx).astype(int) + dx
    ys = np.floor(np.arange(h) * sy).astype(int) + dy
    if wrap:
        return Art(src.name, src.a[(ys % src.h)][:, xs % src.w])
    a = np.full((h, w), -1, int)
    ok_y, ok_x = (ys >= 0) & (ys < src.h), (xs >= 0) & (xs < src.w)
    a[np.ix_(ok_y, ok_x)] = src.a[np.ix_(ys[ok_y], xs[ok_x])]
    return Art(src.name, a)


def rgb_of(art, pal):
    m = art.a >= 0
    return pal[np.where(m, art.a, 0)], m


def close(x, y, px, py, tol=20.0):
    """share of pixels of the same colour (within 5-bit rounding) or both clear"""
    if x.a.shape != y.a.shape:
        return 0.0
    X, Xm = rgb_of(x, px); Y, Ym = rgb_of(y, py)
    d = np.sqrt(((X - Y) ** 2).sum(-1))
    return float((((d < tol) & Xm & Ym) | (~Xm & ~Ym)).mean())


# ---------------------------------------------------------------- RLDATA I/O
def read_rldata(rl):
    """walls (FX3 order) and images of an RLDATA directory"""
    banks = {}
    for b in BANKS:
        p = os.path.join(rl, 'WALLIMG', 'BANK%02X.DEF' % b)
        banks[b] = (open(p, 'rb').read() if os.path.exists(p) else b'') + bytes(300)

    fmt2 = os.path.exists(os.path.join(rl, 'WALLS', 'WALLS.FMT'))
    fmt3 = fmt2 and open(os.path.join(rl, 'WALLS', 'WALLS.FMT'), 'rb').read()[:1] == b'3'

    def parse3(i, dat, o):
        """wall format 3: codebook + indices (tools/wallvq.py) -> full size art"""
        import wallvq as VQ
        h, w, fl, b = dat[o], dat[o + 1] + 1, dat[o + 2], dat[o + 3]
        if i < NRAW:
            bk, off = SKY_AT[i]
            raw = banks[bk][off:off + h * w]
            return np.array(list(raw), int).reshape(w, h)[:, ::-1].T
        cb, ix, rb = dat[o + 4] | dat[o + 5] << 8, dat[o + 6] | dat[o + 7] << 8, dat[o + 8]
        half = bool(fl & 0x80)
        hs, ws = (h >> 1, w >> 1) if half else (h, w)
        nbx = -(-ws // VQ.BW)
        buf = banks[b]
        cbk = VQ.cb_from_bytes(buf[cb - 0x8000:cb - 0x8000 + VQ.CB_BYTES])
        idx = list(buf[ix - 0x8000:ix - 0x8000 + nbx * rb])
        return VQ.full_size(VQ.decode(idx, cbk, rb, nbx, hs, ws), half)

    def parse(sub, is_wall):
        tbl = open(os.path.join(rl, sub, sub + '.TBL'), 'rb').read()
        dat = open(os.path.join(rl, sub, sub + '.DAT'), 'rb').read()
        out = []
        for i in range(len(tbl) // 2):
            o = struct.unpack('<H', tbl[2 * i:2 * i + 2])[0]
            if is_wall and fmt3:
                out.append(Art('%s%d' % (sub, i), parse3(i, dat, o)))
                continue
            h, w = dat[o], dat[o + 1] + (1 if is_wall else 0)
            hd, sh = 2, 0
            if is_wall and fmt2:                   # wall format 2: + column step 12/6/3
                hd, sh = 3, {12: 0, 6: 1, 3: 2}[dat[o + 2] & 0x7F]
                w = (dat[o + 1] | ((1 << sh) - 1)) + 1
            half = is_wall and fmt2 and dat[o + 2] & 0x80        # half height: texel rows stored once per pair
            hs = h >> 1 if half else h
            a = np.full((hs, w), -1, int)
            for x in range(w):
                lo, hi, b = dat[o + hd + 3 * (x >> sh):o + hd + 3 + 3 * (x >> sh)]
                buf, p = banks[b], (lo | hi << 8) - 0x8000
                if is_wall and i < NRAW:
                    px = list(buf[p:p + h])
                elif is_wall:
                    px, _ = G.wall_strip_len(buf, p, hs)
                else:
                    px, _ = G.image_strip_len(buf, p, h)
                a[:, x] = [-1 if q is None else q for q in px[::-1]]
            if half:
                a = np.repeat(a, 2, 0)
            out.append(Art('%s%d' % (sub, i), a))
        return out
    return parse('WALLS', True), parse('IMAGES', False)


def read_colour(rl):
    """displayed colour of each pixel value at full light (colour map row 0)"""
    cm = open(os.path.join(rl, 'COLOUR', 'COLOURMAPS'), 'rb').read()
    pal = bgr555_to_rgb8(open(os.path.join(rl, 'COLOUR', 'BASERGB.RGB'), 'rb').read())
    return np.array([pal[cm[i]] for i in range(256)], float)


# ---------------------------------------------------------------- WAD art
class WadArt:
    def __init__(self, paths):
        self.wads = [WAD(p) for p in paths]          # later WADs override
        self.palette = np.array(list(self.get('PLAYPAL')[:768]), float).reshape(256, 3)
        self._patch = {}
        self.textures = {}
        pn = self.get('PNAMES')
        n = struct.unpack('<i', pn[:4])[0]
        self.pnames = [pn[4 + 8 * i:12 + 8 * i].rstrip(b'\0').decode('latin1').upper() for i in range(n)]
        for w in self.wads:
            for tl in ('TEXTURE1', 'TEXTURE2'):
                t = w.get(tl)
                if not t:
                    continue
                for i in range(struct.unpack('<i', t[:4])[0]):
                    o = struct.unpack('<i', t[4 + 4 * i:8 + 4 * i])[0]
                    nm = t[o:o + 8].rstrip(b'\0').decode('latin1').upper()
                    tw, th = struct.unpack('<hh', t[o + 12:o + 16])
                    npat = struct.unpack('<h', t[o + 20:o + 22])[0]
                    self.textures[nm] = (tw, th, [struct.unpack('<hhh', t[o + 22 + 10 * j:o + 28 + 10 * j])
                                                  for j in range(npat)])
        self._tex = {}

    def get(self, name):
        for w in reversed(self.wads):
            d = w.get(name)
            if d is not None:
                return d
        return None

    def lump(self, name, start, end, prefix=False):
        for w in reversed(self.wads):
            s = max(w.find(start), 0)
            e = w.find(end, s)
            e = len(w.lumps) if e < 0 else e
            for k in range(s, e):
                n = w.lumps[k][0].upper()
                if n == name or (prefix and n.startswith(name)):
                    return w.data(k), n
        return None, None

    @staticmethod
    def patch(dat):
        w, h = struct.unpack('<hh', dat[:4])
        a = np.full((h, w), -1, int)
        for x in range(w):
            o = struct.unpack('<i', dat[8 + 4 * x:12 + 4 * x])[0]
            while dat[o] != 255:
                top, n = dat[o], dat[o + 1]
                k = min(n, h - top)
                if k > 0:
                    a[top:top + k, x] = list(dat[o + 3:o + 3 + k])
                o += n + 4
        return a

    def texture(self, name):
        if name not in self.textures:
            return None
        if name not in self._tex:
            tw, th, ps = self.textures[name]
            a = np.full((th, tw), -1, int)
            for ox, oy, pi in ps:
                pnm = self.pnames[pi]
                if pnm not in self._patch:
                    d, _ = self.lump(pnm, 'P_START', 'P_END')
                    self._patch[pnm] = self.patch(d if d is not None else self.get(pnm))
                p = self._patch[pnm]
                y0, x0 = max(oy, 0), max(ox, 0)
                y1, x1 = min(oy + p.shape[0], th), min(ox + p.shape[1], tw)
                if y1 > y0 and x1 > x0:
                    sub = p[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
                    a[y0:y1, x0:x1] = np.where(sub >= 0, sub, a[y0:y1, x0:x1])
            self._tex[name] = Art(name, a)
        return self._tex[name]

    def sprite(self, name):
        d, n = self.lump(name, 'S_START', 'S_END')
        if d is None and len(name) < 8:              # SPIDA1 -> SPIDA1D1
            d, n = self.lump(name, 'S_START', 'S_END', prefix=True)
        return (Art(n, self.patch(d)), n) if d is not None else (None, None)


# ---------------------------------------------------------------- learn
def learn(a):
    rl = os.path.join(a.data, 'RLDATA')
    keep = os.path.join(a.data, 'RLGFX.fx3')
    if not os.path.isdir(keep):
        for s in GFXDIRS:
            shutil.copytree(os.path.join(rl, s), os.path.join(keep, s))
    walls, images = read_rldata(keep)
    rgb_s = read_colour(keep)
    wa = WadArt(a.wad)
    rgb_w = wa.palette
    walllist = G.read_list(os.path.join(a.src, 'WallList'))
    imagelist = G.read_imagelist(os.path.join(a.src, 'ImageList'))
    inv = {f: i for i, f in enumerate(G.WALL_MAP)}

    def fit(sn, t, raw, refine=True):
        """placement of texture t that looks most like the cartridge wall sn:
        coarse offsets first, then +-7 pixels around the best ones"""
        def score(sx, sy, dx, dy):
            return close(sn, resample(t, sn.w, sn.h, sx, sy, dx, dy), rgb_s, rgb_w)
        best = (score(t.w / sn.w if raw else 1.0, 1.0, 0, 0), 0, 0, t.w / sn.w if raw else 1.0, 1.0)
        if best[0] > 0.9:
            return best
        coarse = []
        for sx in ([t.w / sn.w] if raw else sorted({1.0, t.w / sn.w})):
            for sy in sorted({1.0, t.h / sn.h, 0.875, 1.125}):
                for dy in range(0, t.h, 16):
                    for dx in range(0, t.w, 32):
                        coarse.append((score(sx, sy, dx, dy), dx, dy, sx, sy))
        coarse.sort(key=lambda c: -c[0])
        if not refine:
            return max(best, coarse[0])
        for _, dx0, dy0, sx, sy in coarse[:6]:
            for dy in range(dy0 - 8, dy0 + 8):
                for dx in range(dx0 - 8, dx0 + 8, 1 if t.w <= 64 else 4):
                    s = score(sx, sy, dx % t.w, dy % t.h)
                    if s > best[0] + 0.005:                # ties: the first (dx = dy = 0, scale 1)
                        best = (s, dx % t.w, dy % t.h, sx, sy)
        return best

    wrec = []
    for f, sn in enumerate(walls):
        nm = walllist[inv[f]][0].lstrip('_') if f in inv else ('SKY%d' % (f + 1) if f < NRAW else None)
        raw = f < NRAW
        r = None
        if nm and nm in wa.textures:
            b = fit(sn, wa.texture(nm), raw)
            if b[0] < 0.5:                             # redrawn on the cart: the WAD texture as it is
                t = wa.texture(nm)
                b = (b[0], 0, 0, t.w / sn.w if raw else 1.0, 1.0)
            r = (b, nm)
        if r is None and not raw:                      # edited or renamed: search the WAD
            found = sorted(((fit(sn, wa.texture(tn), raw, False), tn) for tn, (tw, th, _)
                            in wa.textures.items() if (tw, th) == (sn.w, sn.h)), key=lambda c: -c[0][0])
            if found and found[0][0][0] >= 0.5:
                r = (fit(sn, wa.texture(found[0][1]), raw), found[0][1])
        if r is None:
            wrec.append(dict(name=nm or 'WALL%d' % f, wad=None, w=sn.w, h=sn.h))
            log('wall #%-2d %-9s no WAD texture: keeps the cartridge wall' % (f, nm))
            continue
        (s, dx, dy, sx, sy), tn = r
        t = wa.texture(tn)
        wrec.append(dict(name=nm or tn, wad=tn, w=sn.w, h=sn.h, dx=dx, dy=dy, sx=sx, sy=sy, like=round(s, 3)))
        log('wall #%-2d %-9s <- %-9s %3dx%-3d from %3dx%-3d  dx=%-3d dy=%-3d sx=%.2f sy=%.3f  %3.0f%% like the cart'
            % (f, nm or '?', tn, sn.w, sn.h, t.w, t.h, dx, dy, sx, sy, 100 * s))

    irec = []
    for (nm, _), sn in zip(imagelist, images):
        sp, ln = wa.sprite(nm)
        if sp is None:
            irec.append(dict(name=nm, lump=None, w=sn.w, h=sn.h))
            log('image %-9s no WAD sprite: keeps the cartridge image' % nm)
            continue
        irec.append(dict(name=nm, lump=ln, w=sn.w, h=sn.h))
        if (sp.w, sp.h) != (sn.w, sn.h):
            log('image %-9s %3dx%-3d from %-8s %3dx%-3d (scaled %.2f)' % (nm, sn.w, sn.h, ln, sp.w, sp.h, sn.h / sp.h))

    # colours: votes over the aligned pixels
    votes = collections.defaultdict(collections.Counter)
    for r, sn in zip(wrec, walls):
        if r.get('wad'):
            wd = resample(wa.texture(r['wad']), r['w'], r['h'], r['sx'], r['sy'], r['dx'], r['dy'])
            m = (sn.a >= 0) & (wd.a >= 0)
            for q, p in zip(wd.a[m], sn.a[m]):
                votes[int(q)][int(p)] += 1
    svotes = collections.defaultdict(collections.Counter)
    for r, sn in zip(irec, images):
        if r['lump']:
            sp, _ = wa.sprite(r['lump'])
            if sp.a.shape == sn.a.shape:
                m = (sn.a >= 0) & (sp.a >= 0)
                for q, p in zip(sp.a[m], sn.a[m]):
                    svotes[int(q)][int(p)] += 1
    used_w = sorted({int(p) for s in walls[NRAW:] for p in np.unique(s.a) if p >= 0})
    used_s = sorted({int(p) for s in images for p in np.unique(s.a) if p > 0})

    def nearest(c, allowed):
        return int(allowed[int(((rgb_s[allowed] - c) ** 2).sum(-1).argmin())])
    palw, pals = [], []
    for b in range(256):
        v = votes[b] + svotes[b]
        palw.append(v.most_common(1)[0][0] if v else nearest(rgb_w[b], used_w))
        c = [p for p, _ in (svotes[b] + votes[b]).most_common() if p != 0]
        pals.append(c[0] if c else nearest(rgb_w[b], used_s))
    json.dump(dict(walls=wrec, images=irec, palette_walls=palw, palette_sprites=pals,
                   wad_playpal=[int(x) for x in rgb_w.flatten()]),
              open(os.path.join(a.data, 'wad2gfx.json'), 'w'), indent=0)
    log('learned: %d walls (%d from the WAD), %d sprites (%d from the WAD), %d WAD colours seen'
        % (len(wrec), sum(1 for r in wrec if r.get('wad')), len(irec), sum(1 for r in irec if r['lump']),
           len(set(votes) | set(svotes))))


# ---------------------------------------------------------------- convert
def encode_wall_strip(px):
    """$01-$7F: n literal colours, $80-$FF: 256-b times the next colour (bottom->top)"""
    out = bytearray(); i = 0; n = len(px)
    while i < n:
        j = i
        while j < n and px[j] == px[i] and j - i < 128:
            j += 1
        if j - i >= 3:
            out += bytes([256 - (j - i), px[i]]); i = j; continue
        k, lit = i, []
        while k < n and len(lit) < 127:
            j = k
            while j < n and px[j] == px[k] and j - k < 128:
                j += 1
            if j - k >= 3:
                break
            lit.append(px[k]); k += 1
        out += bytes([len(lit)]) + bytes(lit); i = k
    return bytes(out)


def build(a, rec, keep):
    cwalls, cimages = read_rldata(keep)
    rgb_s = read_colour(keep)
    wa = WadArt(a.wad)
    palw, pals = np.array(rec['palette_walls']), np.array(rec['palette_sprites'])
    if any(int(x) != y for x, y in zip(wa.palette.flatten(), rec['wad_playpal'])):
        log('the WAD has its own PLAYPAL: nearest SNES colours')
        used = np.array(sorted({int(p) for s in cwalls[NRAW:] for p in np.unique(s.a) if p >= 0}))
        for b in range(256):
            o = np.argsort(((rgb_s[used] - wa.palette[b]) ** 2).sum(-1))
            palw[b] = used[o[0]]
            pals[b] = used[o[0]] if used[o[0]] else used[o[1]]
    walls, wsrc = [], []
    for r, cw in zip(rec['walls'], cwalls):
        t = wa.texture(r['wad']) if r.get('wad') else None
        if t is None:
            walls.append(Art(r['name'], cw.a)); wsrc.append('cart'); continue
        x = resample(t, r['w'], r['h'], r['sx'], r['sy'], r['dx'], r['dy'])
        walls.append(Art(r['name'], palw[np.where(x.a >= 0, x.a, 0)])); wsrc.append('wad')
    images, isrc = [], []
    # an older wad2gfx.json names the barrel explosion BEXPB0-D0: its PC frames are C, D, E
    if any(r['name'] == 'BEXPB0' for r in rec['images']):
        fix = {'BEXPB0': 'BEXPC0', 'BEXPC0': 'BEXPD0', 'BEXPD0': 'BEXPE0'}
        rec['images'] = [dict(r, lump=fix[r['lump']]) if r.get('lump') in fix else r
                         for r in rec['images']]
    for r, ci in zip(rec['images'], cimages):
        sp = wa.sprite(r['lump'])[0] if r.get('lump') else None
        if sp is None:
            images.append(Art(r['name'], ci.a)); isrc.append('cart'); continue
        if sp.a.shape != (r['h'], r['w']):
            sp = resample(sp, r['w'], r['h'], sp.w / r['w'], sp.h / r['h'], wrap=False)
        images.append(Art(r['name'], np.where(sp.a >= 0, pals[np.where(sp.a >= 0, sp.a, 0)], -1)))
        isrc.append('wad')
    slots = list(range(len(images)))                # IMAGES.TBL entry -> image
    if getattr(a, 'doom2_monsters', False):          # image page 1 (rlimages.inc)
        names = {r['name']: k for k, r in enumerate(rec['images'])}
        slots += [0] * (256 - len(slots))
        for tag, frames in DOOM2_PAGE1:
            for f in frames:
                if isinstance(f, str) and f.startswith('='):
                    slots.append(names[f[1:]]); continue
                nm, sc = (f, 1.0) if isinstance(f, str) else f
                sp = wa.sprite(nm)[0]
                if sp is None:
                    sys.exit('%s: not in the WAD (--doom2-monsters needs DOOM2.WAD)' % nm)
                if sc != 1.0:
                    w, h = max(1, round(sp.w * sc)), max(1, round(sp.h * sc))
                    sp = resample(sp, w, h, sp.w / w, sp.h / h, wrap=False)
                slots.append(len(images))
                images.append(Art(nm, np.where(sp.a >= 0, pals[np.where(sp.a >= 0, sp.a, 0)], -1)))
                isrc.append('wad')
        assert len(slots) <= 512, len(slots)
    a.image_slots = slots
    a._pals = pals
    return walls, wsrc, images, isrc, rgb_s, wa


def used_art(data, walls, images, isrc):
    """--drop-unused: the walls the kept levels show (faces of their segs, switch/animation
    alternates from TEXTURE2.TBL, the skies of the kept episodes) and the sprites the WAD
    has (the WAD's sprite set is what its maps need); (keep walls, keep images)"""
    import re
    lev = os.path.join(data, 'RLLEV')
    inc = open(os.path.join(lev, 'levels.inc')).read()
    used = [s for s in re.findall(r'^!use(\w+) #= 1', inc, re.M) if os.path.isdir(os.path.join(lev, s))]
    keep = set()
    for lv in used:
        segs = open(os.path.join(lev, lv, 'SEGS'), 'rb').read()
        faces = open(os.path.join(lev, lv, 'FACES'), 'rb').read()
        for o in range(0, len(segs) - 10, 11):
            p = struct.unpack_from('<H', segs, o + 7)[0]
            f = faces[p:p + (2 if segs[o + 4] & 1 else 4)]
            keep.update(c // 2 for c in (f[1:2] if segs[o + 4] & 1 else f[2:4]))   # (wall# * 2)
    alt = struct.unpack('<%dH' % len(walls), open(os.path.join(data, 'RLGFX.fx3', 'WALLS', 'TEXTURE2.TBL'), 'rb').read())
    todo = list(keep)
    while todo:                                      # switch / animation alternates
        w = alt[todo.pop()] // 2
        if w < len(walls) and w not in keep:
            keep.add(w); todo.append(w)
    m = re.search(r'^!RLEPISODES = (\d+)', inc, re.M)
    keep.update(range(int(m.group(1)) if m else NRAW))   # SKY1..: one per episode
    keep = {w for w in keep if w < len(walls)}
    return keep, {k for k, src in enumerate(isrc) if src == 'wad'}


def pack(walls, images, rgb, lossless=False, banks=None):
    """strips -> banks; shows wall columns as similar columns until everything fits"""
    BANKS = banks or PACK_BANKS
    raw = [i for i in range(NRAW) if walls[i].h == 128]  # (--drop-unused: the other skies are 1x1)
    cap = sum(BANK_LIMIT.get(b, 0x8000) for b in BANKS) - len(raw) * 0x4000
    img_strips = [[G.encode_image_strip([0 if p < 0 else int(p) for p in g.a[::-1, x]]) for x in range(g.w)]
                  for g in images]
    cols = [(wi, x) for wi in range(NRAW, len(walls)) for x in range(walls[wi].w)]
    enc = {k: encode_wall_strip([int(p) for p in walls[k[0]].a[::-1, k[1]]]) for k in cols}
    rep = {k: k for k in cols}                       # the column shown in place of k
    members = {k: [k] for k in cols}
    shown = collections.Counter(enc[k] for k in cols)
    img_bytes = set(s for ss in img_strips for s in ss)
    need = sum(len(e) for e in shown) + sum(len(s) for s in img_bytes if s not in shown)
    merged, err = 0, collections.Counter()
    target = cap - MARGIN
    if need > target and lossless:
        sys.exit('strips need %d bytes, %d fit (try without --lossless)' % (need, target))
    if need > target:
        dm = {}
        heap = []
        for wi in range(NRAW, len(walls)):
            X = rgb[walls[wi].a]                         # (h, w, 3)
            w = X.shape[1]
            d = np.empty((w, w))
            for x in range(w):
                d[x] = np.sqrt(((X - X[:, x:x + 1]) ** 2).sum(-1)).sum(0)
            np.fill_diagonal(d, np.inf)
            dm[wi] = d
            for x in range(w):
                y = int(d[x].argmin())
                heap.append((d[x, y] / max(len(enc[(wi, x)]) / shown[enc[(wi, x)]], 1), wi, x, y))
        heapq.heapify(heap)
        while heap and need > target:
            c, wi, x, y = heapq.heappop(heap)
            k = (wi, x)
            if rep[k] != k:
                continue
            if rep[(wi, y)] != (wi, y):                  # y is shown as another column now
                d = dm[wi][x].copy()
                for q in range(len(d)):
                    if rep[(wi, q)] != (wi, q):
                        d[q] = np.inf
                if np.isfinite(d.min()):
                    y = int(d.argmin())
                    heapq.heappush(heap, (d[y] / max(len(enc[k]) / shown[enc[k]], 1), wi, x, y))
                continue
            t = (wi, y)
            for m in members[k]:                         # everything shown as k is now shown as y
                rep[m] = t
                shown[enc[k]] -= 1
                shown[enc[t]] += 1
                err[wi] += dm[wi][m[1], y] if m == k else 0
            members[t] += members.pop(k)
            if shown[enc[k]] == 0:                       # the strip is no longer stored
                del shown[enc[k]]
                if enc[k] not in img_bytes:
                    need -= len(enc[k])
            merged += 1
    # placement: skies at fixed addresses, wall strips (largest first), then sprite strips
    G.BANK_LIMIT.clear(); G.BANK_LIMIT.update(BANK_LIMIT)
    G.WALL_BANKS[:] = BANKS
    skyb = {b for b in {SKY_AT[i][0] for i in raw}             # banks the skies fill (a bank with one
            if sum(SKY_AT[i][0] == b for i in raw) == 2}       #  sky left takes strips after it, guarded)
    for b in BANKS:                                  # room for the overrun guard (below)
        if b not in skyb:
            G.BANK_LIMIT[b] = BANK_LIMIT.get(b, 0x8000) - 2 * len(GUARD)
    pk = G.Packer()
    for i in raw:
        b, off = SKY_AT[i]
        pk.place_fixed(b, off, bytes(int(p) for x in range(walls[i].w) for p in walls[i].a[::-1, x]))
    at = {}
    for e in sorted({enc[rep[k]] for k in cols}, key=len, reverse=True):
        at[e] = pk.place(e)
    wptr = {k: (at[enc[rep[k]]][0], 0x8000 + at[enc[rep[k]]][1]) for k in cols}
    for b in BANKS:                                  # walls end here: the guard before the sprites
        if b not in skyb and pk.data[b]:
            pk.data[b] += GUARD
    iptr = []
    for ss in img_strips:
        row = []
        for s in ss:
            if s not in at:
                at[s] = pk.place(s, search=True)
            row.append((at[s][0], 0x8000 + at[s][1]))
        iptr.append(row)
    for b in BANKS:
        if b not in skyb:
            pk.data[b] += GUARD
    for wi in range(NRAW, len(walls)):               # what the walls look like now
        a = walls[wi].a.copy()
        for x in range(walls[wi].w):
            a[:, x] = walls[wi].a[:, rep[(wi, x)][1]]
        walls[wi].a = a
    return pk, wptr, iptr, merged, err, need, cap


def write(rl, walls, images, pk, wptr, iptr, slots=None):
    tbl, dat = bytearray(), bytearray()
    for wi, g in enumerate(walls):
        tbl += struct.pack('<H', len(dat))
        dat += bytes([g.h, g.w - 1])
        for x in range(g.w):
            if wi < NRAW:
                b, off = SKY_AT[wi]; ad = 0x8000 + off + x * g.h
            else:
                b, ad = wptr[(wi, x)]
            dat += bytes([ad & 0xFF, ad >> 8, b])
    open(os.path.join(rl, 'WALLS', 'WALLS.TBL'), 'wb').write(tbl)
    open(os.path.join(rl, 'WALLS', 'WALLS.DAT'), 'wb').write(dat)
    tbl, dat, at = bytearray(), bytearray(), []
    for g, ptrs in zip(images, iptr):
        at.append(len(dat))
        dat += bytes([g.h, g.w & 0xFF])         # (a masked middle texture 256 wide: 0)
        for b, ad in ptrs:
            dat += bytes([ad & 0xFF, ad >> 8, b])
    slots = slots if slots is not None else list(range(len(images)))
    for k in slots:
        tbl += struct.pack('<H', at[k])
    if len(dat) + len(tbl) > 0x10000:
        sys.exit('IMAGES.TBL + IMAGES.DAT: %d bytes, more than one 64 KB bank' % (len(dat) + len(tbl)))
    open(os.path.join(rl, 'IMAGES', 'IMAGES.TBL'), 'wb').write(tbl)
    open(os.path.join(rl, 'IMAGES', 'IMAGES.DAT'), 'wb').write(dat)
    for b in BANKS:
        open(os.path.join(rl, 'WALLIMG', 'BANK%02X.DEF' % b), 'wb').write(bytes(pk.data.get(b, b'')))
    write.at = at                                    # (IMAGES.DAT offset per image: MASKED.TBL)
    w2, i2 = read_rldata(rl)                         # read back
    for k, (x, y) in enumerate(zip(walls + [images[k] for k in slots], w2 + i2)):
        assert (k < NRAW and x.h != 128) or np.array_equal(x.a, y.a), x.name   # (a dropped sky: 1x1, not stored)


def map_walls(a, rec, walls, images, rgb_s, wa, banks):
    """--map-walls: the wall set of the WAD's maps (tools/wallset.py) and the masked middle
    textures (add_masked); wall format 2 strips here, format 3 with --vq (map_walls_vq).
    -> (walls' art, slots, alias, column steps, slot metadata, half size per slot)"""
    import wallset as WS
    from wad2rl import Wad
    maps = Wad(*a.wad).maps()
    area, peg = WS.usage(a.wad, maps)
    palw = np.array(rec['palette_walls'])
    texs = {}
    for n in area:
        t = wa.texture(n)
        if t is None:
            log('texture %s: not in the WAD' % n); continue
        texs[n] = WS.Tex(n, t.a, palw, wa.palette, peg[n][1] > peg[n][0])
    weight = {n: area[n] ** WS.GAMMA for n in texs}
    add_masked(a, wa, maps, images)
    boost = json.load(open(a.boost)) if a.boost else {}
    if a.slots_by == 'likeness':
        # (--boost: visible difference feedback, more weight for these when slots are chosen)
        sw = {n: v * boost.get(n, 1.0) * (8.0 if n[:3] in ('SW1', 'SW2') else 1.0) for n, v in weight.items()}
        force = WS.KEEP + tuple(sorted(n for n in texs if n[:3] in ('SW1', 'SW2')))   # (every switch: its own slot)
        slots, alias = WS.choose_slots_ssim(texs, sw, a.wall_slots, log=log, force=force)
    else:
        slots, alias = WS.choose_slots(texs, weight, a.wall_slots)
    wsl = collections.Counter()
    for n, s_ in alias.items():
        wsl[s_] += weight[n]
    a_tex = {n: wsl[n] / (texs[n].h * texs[n].w) for n in slots}
    nw = NRAW + len(slots)
    if a.vq:
        return map_walls_vq(a, texs, slots, alias, wsl, area, images, rgb_s, palw, walls, banks)
    steps, dat, lam_s = WS.choose_steps(slots, texs, a_tex, a.dat_budget - 3 * NRAW - 3 * NRAW * 128, nw,
                                        a.min_step)
    log('walls  : %d textures in the maps, %d slots (+ %d skies), %d shown as another; wall table %d bytes '
        '(%d slots with every 2nd column, %d with every 4th; last step %.1f error/byte)'
        % (len(texs), len(slots), NRAW, len(texs) - len(slots), dat + 3 * NRAW + 3 * NRAW * 128,
           sum(1 for v in steps.values() if v == 1), sum(1 for v in steps.values() if v == 2), lam_s))
    # strip budget: the banks less skies, guards, sprite strips and a margin per bank
    img_strips = [[G.encode_image_strip([0 if p < 0 else int(p) for p in g.a[::-1, x]]) for x in range(g.w)]
                  for g in images]
    img_bytes = sum(len(e) for e in set(e for ss in img_strips for e in ss))
    skyb = {SKY_AT[i][0] for i in range(NRAW)}
    cap = sum(BANK_LIMIT.get(b, 0x8000) - (0 if b in skyb else 2 * len(GUARD)) for b in banks) - NRAW * 0x4000
    budget = cap - img_bytes - 160 * len(banks)
    # --masked-banks: as in map_walls_vq, those banks are for the masked middle textures first
    mroom = sum(BANK_LIMIT.get(b, 0x8000) - 2 * len(GUARD) for b in banks if b in MASKED_BANKS)
    if mroom:
        mk = {k for _, k in getattr(a, '_masked', [])}
        m_bytes = sum(len(e) for e in set(e for k, ss in enumerate(img_strips) if k in mk for e in ss))
        budget = min(budget, cap - mroom - (img_bytes - min(mroom, m_bytes)) - 160 * len(banks))
    if a.strip_budget:
        budget = min(budget, a.strip_budget)
    log('banks  : %d bytes, sprite strips %d, wall strips get %d' % (cap, img_bytes, budget))
    colours = sorted(set(int(x) for x in palw))
    colours_a = np.array(colours)

    # two ways to store a slot (--half-height): mode 0 = its column step, every texel row,
    # own strips from the texture's columns; mode 1 = at least every 2nd column and half
    # height, each stored texel the SNES colour closest to the mean of the texels it
    # stands for (box downsampling: lines across the texture stay, at lower contrast)
    def mode_of(n, md):
        t = texs[n]
        if md == 0:
            return steps[n], 0
        return min(max(steps[n], 1), max(0, t.w.bit_length() - 2)), 1

    # the strips' targets: the texture, or with --target-blur a lightly blurred copy (the
    # pixel noise is what the runs cannot keep; without it neighbouring columns get the
    # same run colours instead of streaks)
    tref = {n: (WS.blur(texs[n].ref) * a.target_blur + texs[n].ref * (1 - a.target_blur)) for n in slots}

    def wall_items(n, md):
        """stored columns of slot N in mode MD: (stored height, weight, target mean RGB, own strip)"""
        t = texs[n]
        s_, v = mode_of(n, md)
        g, k = 1 << s_, 1 << v
        out = []
        for j in range(t.w >> s_):
            R = tref[n][:, j * g:(j + 1) * g]                     # (h, g, 3)
            mu = R.reshape(t.h // k, k * g, 3).mean(1) if not v else R.reshape(t.h // 2, 2 * g, 3).mean(1)
            if v or a.box:
                best = colours_a[((mu[:, None, :] - rgb_s[colours_a][None]) ** 2).sum(-1).argmin(-1)]
            else:
                # own strip: the group's column closest to the group
                cand = [t.pix[:, j * g + c] for c in range(g)]
                best = min(cand, key=lambda q: float(((mu - rgb_s[q]) ** 2).sum()))
            out.append((t.h // k, a_tex[n] * g * k, mu.reshape(-1), tuple(int(p) for p in best)))
        return out

    def wall_art(n, md, strips):
        """full size art of slot N from its stored strips"""
        t = texs[n]
        s_, v = mode_of(n, md)
        arr = np.array([strips[x >> s_] for x in range(t.w)]).T
        return np.repeat(arr, 2, 0) if v else arr

    blur_ref = {n: WS.blur(texs[n].ref) for n in slots}

    def werr(n, art):
        """visible error of ART: squared distance after a small blur (pixel noise counts
        little, lost or smeared shapes count fully), x area per texel"""
        return a_tex[n] * float(((WS.blur(rgb_s[art]) - blur_ref[n]) ** 2).sum())

    vopt = [0, 1] if a.half_height else [0]

    def build_cand(pairs):
        """(n, mode) -> simplified items, for the given slot/mode pairs"""
        cand = {}
        for md in vopt:
            its, own, wts = [], [], []
            for n in slots:
                if (n, md) not in pairs or (md and texs[n].h < 16):
                    continue
                w_ = wall_items(n, md)
                its += w_; own += [n] * len(w_)
                s_, v = mode_of(n, md)
                ew = WS.edge_weights(texs[n].ref, 1 << s_, 1 << v, a.edge_weight)
                wts += [ew[:, j] for j in range(ew.shape[1])]
            if not its:
                continue
            b0 = sum(len(encode_wall_strip(list(it[3])[::-1])) for it in {it[3]: it for it in its}.values())
            lam_r = a.rle_lambda if md == 0 else a.half_rle_lambda
            if lam_r:
                its = WS.simplify(its, rgb_s, colours, lam_r, log=log, weights=wts if a.edge_weight else None)
            b1 = sum(len(encode_wall_strip(list(it[3])[::-1])) for it in {it[3]: it for it in its}.values())
            log('strips : %s: %d -> %d bytes before sharing' % ('half size' if md else 'full size', b0, b1))
            for n, it in zip(own, its):
                cand.setdefault((n, md), []).append(it)
        return cand
    cand = build_cand({(n, md) for n in slots for md in vopt})
    # per slot and mode: visible error of its own (unshared) strips and their bytes
    E, B = {}, {}
    for (n, md), its in cand.items():
        E[(n, md)] = werr(n, wall_art(n, md, [it[3] for it in its]))
        B[(n, md)] = sum(len(encode_wall_strip(list(st)[::-1])) for st in set(it[3] for it in its))
    lam_v = a.half_lambda
    best_run = None
    for rnd in range(a.half_iter if len(vopt) > 1 and not a.half_force else 1):
        vh = {n: min((md for md in vopt if (n, md) in E), key=lambda md: E[(n, md)] + lam_v * B[(n, md)])
              for n in slots}
        if a.half_force:
            vh = {n: max(md for md in vopt if (n, md) in E) for n in slots}
        items, owner = [], []
        for n in slots:
            for j, it in enumerate(cand[(n, vh[n])]):
                items.append(it); owner.append((n, j))
        log('walls  : %d slots at half size (lambda %.0f), own strips %d bytes'
            % (sum(vh.values()), lam_v, sum(B[(n, vh[n])] for n in slots)))
        strips, used, lam = WS.share_strips(items, rgb_s, encode_wall_strip, budget, log)
        cols = collections.defaultdict(list)
        for (n, j), st in zip(owner, strips):
            cols[n].append(st)
        obj = sum(werr(n, wall_art(n, vh[n], cols[n])) for n in slots)
        log('walls  : visible error %.4g' % obj)
        if best_run is None or obj < best_run[0]:
            best_run = (obj, vh, cols, used, lam)
        # next round: the error per byte the sharing ended at, in the visible error's units
        lam_v = max(lam * (sum(E[(n, vh[n])] for n in slots) / max(1.0, sum(
            a_tex[n] * float(((rgb_s[wall_art(n, vh[n], [it[3] for it in cand[(n, vh[n])]])] - texs[n].ref) ** 2).sum())
            for n in slots))), 1.0)
    obj, vh, cols, used, lam = best_run
    if len(vopt) > 1 and a.restep:
        # the half size walls keep at most every 2nd column, which frees wall table room:
        # the column steps chosen again with that, and the strips made again
        st2, dat2, _ = WS.choose_steps(slots, texs, a_tex, a.dat_budget - 3 * NRAW - 3 * NRAW * 128, nw,
                                       {n: vh[n] for n in slots})
        st2 = {n: max(st2[n], vh[n]) for n in slots}
        log('walls  : column steps again: %d slots every 2nd column, %d every 4th (wall table %d bytes)'
            % (sum(1 for v in st2.values() if v == 1), sum(1 for v in st2.values() if v == 2),
               dat2 + 3 * NRAW + 3 * NRAW * 128))
        old_steps = dict(steps)
        steps.clear(); steps.update(st2)
        cand2 = build_cand({(n, vh[n]) for n in slots})
        items, owner = [], []
        for n in slots:
            for j, it in enumerate(cand2[(n, vh[n])]):
                items.append(it); owner.append((n, j))
        strips2, used2, lam2 = WS.share_strips(items, rgb_s, encode_wall_strip, budget, log)
        cols2 = collections.defaultdict(list)
        for (n, j), st in zip(owner, strips2):
            cols2[n].append(st)
        obj2 = sum(werr(n, wall_art(n, vh[n], cols2[n])) for n in slots)
        log('walls  : visible error %.4g' % obj2)
        if obj2 < obj:
            obj, cols, used, lam, dat = obj2, cols2, used2, lam2, dat2
        else:
            steps.clear(); steps.update(old_steps)
    steps = {n: mode_of(n, vh[n])[0] for n in slots}
    vh = {n: mode_of(n, vh[n])[1] for n in slots}
    out = list(walls[:NRAW])
    meta = []
    for n in slots:
        t, s_ = texs[n], steps[n]
        out.append(Art(n, wall_art(n, vh[n], cols[n])))
        meta.append(dict(name=n, step=s_, half=vh[n], h0=t.H0, w0=t.W0, h=t.h, w=t.w, r0=t.r0))
    # error report: mean RGB distance per texel against the WAD, area weighted
    tot = sum(area[n] for n in texs)
    e_slot, obj = 0.0, 0.0
    for art, n in zip(out[NRAW:], slots):
        d2 = ((rgb_s[art.a] - texs[n].ref) ** 2).sum(-1)
        e_slot += area[n] * float(np.sqrt(d2).mean())
        obj += a_tex[n] * float(d2.sum())
    obj0 = obj1 = 0.0
    for n in slots:                                  # (palette only; palette + column steps)
        t, g = texs[n], 1 << steps[n]
        obj0 += a_tex[n] * float(((rgb_s[t.pix] - t.ref) ** 2).sum())
        R = t.ref.reshape(t.h, t.w // g, g, 3)
        obj1 += a_tex[n] * float(((R - R.mean(2, keepdims=True)) ** 2).sum())
    log('walls  : objective %.4g (weighted squared error; colours alone %.4g, + steps >= %.4g), '
        'strips %d + wall table %d bytes' % (obj, obj0, obj0 + obj1, used, dat))
    log('walls  : mean RGB distance to the WAD %.1f over the slots\' area (%.0f %% of all wall area has a slot)'
        % (e_slot / max(1, sum(area[n] for n in slots)), 100 * sum(area[n] for n in slots) / tot))
    return out, slots, alias, steps, meta, vh


def vq_capacity(banks, img_bytes):
    """room per wall bank (skies, guards and a 160 byte margin off; the sprite strips must fit
    what the groups leave, vq_fits)"""
    skyb = {SKY_AT[i][0] for i in range(NRAW)}
    room = {}
    for b in banks:
        r = BANK_LIMIT.get(b, 0x8000) - (0 if b in skyb else 2 * len(GUARD))
        if b in skyb:
            r -= sum(0x4000 for i in range(NRAW) if SKY_AT[i][0] == b)
        room[b] = max(0, r - 160)
    return room


def vq_fits(room, sizes, img_bytes):
    """best fit decreasing of the groups into the banks; the sprite strips need the rest"""
    left = dict(room)
    for s_ in sorted(sizes, reverse=True):
        ok = [(r, b) for b, r in left.items() if r >= s_]
        if not ok:
            return False
        r, b = min(ok)
        left[b] -= s_
    return sum(left.values()) >= img_bytes + 1024


MASKED_MAX = 32      # masked middle textures at most (index: face byte 4, rlvsegs4.asm _RLBuildMaskList)


def wad2rl_maps(wads):
    from wad2rl import Wad
    return Wad(*wads).maps()


def add_masked(a, wa, maps, images):
    """the middle textures of two-sided lines (grates, bars, fences: texels either drawn or not) as
    images (sprite strips: transparent runs are skipped), appended to IMAGES; a._masked = [(name, image index)]"""
    import wallset as WS
    a._masked = []
    if getattr(a, 'no_masked', False):
        return
    if getattr(a, 'masked_maps', None):                # (only the maps the ROM gets)
        maps = [m for m in maps if m in a.masked_maps]
    use = WS.masked_usage(a.wad, maps)
    pals = a._pals
    # see-through ones only (< 2 % clear: opaque, left out unless --masked-opaque), at most 255x256
    # (rlvsegs4.asm _RLBuildMaskList: height and width-1 are bytes), up to --masked-budget bytes of
    # strips and MASKED_MAX textures; chosen by area per strip byte (the most seen for the bytes),
    # kept in order of area; their image headers (3 bytes a column) must leave IMAGES in its bank
    cand = []
    for nm, ar in sorted(use.items(), key=lambda kv: (-kv[1], kv[0])):
        t = wa.texture(nm)
        if t is None:
            continue
        x = t.a
        h, w = x.shape
        if ((x < 0).mean() < 0.02 and not getattr(a, 'masked_opaque', False)) or h > 255 or w > 256:
            continue
        W = 1 << (w - 1).bit_length()          # the engine wraps columns with AND (width - 1)
        x = x[:, np.arange(W) % w]
        art = Art(nm, np.where(x >= 0, pals[np.where(x >= 0, x, 0)], -1))
        n = sum(len(e) for e in set(G.encode_image_strip([0 if p < 0 else int(p) for p in art.a[::-1, c]])
                                    for c in range(W)))
        cand.append((nm, ar, n, art))
    hdr = sum(2 + 3 * g.w for g in images) + 2 * len(images)      # IMAGES.DAT (+ at most IMAGES.TBL)
    nb, pick = 0, set()
    for nm, ar, n, art in sorted(cand, key=lambda c: -c[1] / max(1, c[2])):
        hd = 2 + 3 * art.w + 2
        if nb + n > a.masked_budget or len(pick) >= MASKED_MAX or hdr + hd > 0x10000 - 256:
            continue
        pick.add(nm)
        nb += n
        hdr += hd
    out = []
    for nm, ar, n, art in cand:
        if nm in pick:
            a._masked.append((nm, len(images)))
            images.append(art)
        else:
            out.append(nm)
    if a._masked:
        log('masked : %d middle textures of two-sided lines (%s), strips %d bytes%s'
            % (len(a._masked), ' '.join(n for n, _ in a._masked), nb,
               '; left out: ' + ' '.join(out) if out else ''))


def map_walls_vq(a, texs, slots, alias, wsl, area, images, rgb_s, palw, walls, banks):
    """wall format 3: the slots as 2x4 texel blocks from codebooks (tools/wallvq.py)"""
    import wallvq as VQ
    img_strips = [[G.encode_image_strip([0 if p < 0 else int(p) for p in g.a[::-1, x]]) for x in range(g.w)]
                  for g in images]
    img_bytes = sum(len(e) for e in set(e for ss in img_strips for e in ss))
    room = vq_capacity(banks, img_bytes)
    budget = sum(room.values()) - img_bytes - 1024
    # --masked-banks: those banks are for the masked middle textures first; the walls get no
    # more than they would without them
    mroom = sum(r for b, r in room.items() if b in MASKED_BANKS)
    if mroom:
        mk = {k for _, k in getattr(a, '_masked', [])}
        m_bytes = sum(len(e) for e in set(e for k, ss in enumerate(img_strips) if k in mk for e in ss))
        budget = min(budget, sum(room.values()) - mroom - (img_bytes - min(mroom, m_bytes)) - 1024)
    if a.strip_budget:
        budget = min(budget, a.strip_budget)
    log('banks  : %d bytes for walls and sprites, sprite strips %d, walls get %d' % (sum(room.values()), img_bytes, budget))
    colours = sorted(set(int(x) for x in palw))
    res = VQ.encode(texs, slots, wsl, rgb_s, colours, budget, a.vq_half, a.vq_maxblob,
                    fits=lambda sizes: vq_fits(room, sizes, img_bytes), log=log)
    out = list(walls[:NRAW])
    meta, steps, vh = [], {}, {}
    for n in slots:
        t, hv = texs[n], int(n in res['half'])
        out.append(Art(n, res['arts'][n]))
        steps[n] = vh[n] = hv
        meta.append(dict(name=n, step=hv, half=hv, h0=t.H0, w0=t.W0, h=t.h, w=t.w, r0=t.r0))
    tot = sum(area[n] for n in texs)
    e_slot = sum(area[n] * float(np.sqrt(((rgb_s[art.a] - texs[n].ref) ** 2).sum(-1)).mean())
                 for art, n in zip(out[NRAW:], slots))
    log('walls  : mean RGB distance to the WAD %.1f over the slots\' area (%.0f %% of all wall area has a slot)'
        % (e_slot / max(1, sum(area[n] for n in slots)), 100 * sum(area[n] for n in slots) / tot))
    a._vq = res
    return out, slots, alias, steps, meta, vh


def place3(walls, slots, vq, images, banks):
    """wall format 3: skies fixed, the VQ groups (codebook + indices) largest first, sprite strips"""
    import wallvq as VQ
    G.BANK_LIMIT.clear(); G.BANK_LIMIT.update(BANK_LIMIT)
    G.WALL_BANKS[:] = banks
    skyb = {SKY_AT[i][0] for i in range(NRAW)}
    for b in banks:
        if b not in skyb:
            G.BANK_LIMIT[b] = BANK_LIMIT.get(b, 0x8000) - 2 * len(GUARD)
    pk = G.Packer()
    for i in range(NRAW):
        b, off = SKY_AT[i]
        pk.place_fixed(b, off, bytes(int(p) for x in range(walls[i].w) for p in walls[i].a[::-1, x]))
    blobs = []
    for gi, g in enumerate(vq['groups']):
        blob = bytearray(VQ.cb_bytes(g['cb']))
        assert len(blob) == VQ.CB_BYTES
        at = {}
        for n in g['members']:
            at[n] = len(blob)
            blob += bytes(vq['walls'][n]['idx'])
        blobs.append((bytes(blob), gi, at))
    wvq = {}
    for blob, gi, at in sorted(blobs, key=lambda x: len(x[0]), reverse=True):
        b, off = pk.place(blob, fit='best')
        for n, o in at.items():
            wvq[n] = (b, 0x8000 + off, 0x8000 + off + o)
    for b in banks:
        if b not in skyb and pk.data[b]:
            pk.data[b] += GUARD
    iptr, at = [], {}
    for g in images:
        row = []
        for x in range(g.w):
            s_ = G.encode_image_strip([0 if p < 0 else int(p) for p in g.a[::-1, x]])
            if s_ not in at:
                at[s_] = pk.place(s_, search=True)
            row.append((at[s_][0], 0x8000 + at[s_][1]))
        iptr.append(row)
    for b in banks:
        if b not in skyb:
            pk.data[b] += GUARD
    return pk, wvq, iptr


def wall_header3(g, wi, slot, vq, wvq):
    """9 bytes: height, modulo (width-1), flags ($80 half size), bank, codebook, indices, index bytes per block column"""
    if wi < NRAW:
        b = SKY_AT[wi][0]
        return bytes([g.h, (g.w - 1) & 0xFF, 0, b, 0x00, 0x80, 0x00, 0x80, 0])
    w = vq['walls'][slot]
    b, cb, ix = wvq[slot]
    return bytes([g.h, (g.w - 1) & 0xFF, 0x80 if w['half'] else 0, b, cb & 0xFF, cb >> 8, ix & 0xFF, ix >> 8, w['rb']])


def stored_rows(g, half):
    """the texel rows a wall stores: every 2nd at half height"""
    return g.a[::2] if half else g.a


def place2(walls, vh, images, banks):
    """wall format 2: strips -> banks (skies fixed, wall strips largest first, sprite strips)"""
    G.BANK_LIMIT.clear(); G.BANK_LIMIT.update(BANK_LIMIT)
    G.WALL_BANKS[:] = banks
    skyb = {SKY_AT[i][0] for i in range(NRAW)}
    for b in banks:
        if b not in skyb:
            G.BANK_LIMIT[b] = BANK_LIMIT.get(b, 0x8000) - 2 * len(GUARD)
    pk = G.Packer()
    for i in range(NRAW):
        b, off = SKY_AT[i]
        pk.place_fixed(b, off, bytes(int(p) for x in range(walls[i].w) for p in walls[i].a[::-1, x]))
    enc = {}
    for wi in range(NRAW, len(walls)):
        a_ = stored_rows(walls[wi], vh.get(walls[wi].name, 0))
        for x in range(walls[wi].w):
            col = tuple(int(p) for p in a_[:, x])
            if col not in enc:
                enc[col] = encode_wall_strip(list(col)[::-1])
    at = {}
    for e in sorted(set(enc.values()), key=len, reverse=True):
        at[e] = pk.place(e, fit='best')
    wptr = {}
    for wi in range(NRAW, len(walls)):
        a_ = stored_rows(walls[wi], vh.get(walls[wi].name, 0))
        for x in range(walls[wi].w):
            e = enc[tuple(int(p) for p in a_[:, x])]
            wptr[(wi, x)] = (at[e][0], 0x8000 + at[e][1])
    for b in banks:
        if b not in skyb and pk.data[b]:
            pk.data[b] += GUARD
    iptr = []
    for g in images:
        row = []
        for x in range(g.w):
            s_ = G.encode_image_strip([0 if p < 0 else int(p) for p in g.a[::-1, x]])
            if s_ not in at:
                at[s_] = pk.place(s_, search=True)
            row.append((at[s_][0], 0x8000 + at[s_][1]))
        iptr.append(row)
    for b in banks:
        if b not in skyb:
            pk.data[b] += GUARD
    return pk, wptr, iptr


def write2(a, rl, walls, steps, vh, slots, alias, meta, images, pk, wptr, iptr, slots_img, banks):
    """--map-walls: wall tables (format 2, or 3 with --vq), WALLS.FMT, TEXTURE2.TBL, the wall
    map for wad2rl.py (RLDATA/WALLS/WALLMAP.JSON), IMAGES, MASKED.TBL and the banks"""
    tbl, dat = bytearray(), bytearray()
    vq = getattr(a, '_vq', None)
    for wi, g in enumerate(walls):
        tbl += struct.pack('<H', len(dat))
        if vq is not None:
            dat += wall_header3(g, wi, g.name, vq, wptr)
            continue
        s_ = 0 if wi < NRAW else steps[g.name]
        v = 0 if wi < NRAW else vh[g.name]
        dat += bytes([g.h, (g.w - 1) & ~((1 << s_) - 1) & 0xFF, (12 >> s_) | (0x80 if v else 0)])
        for x in range(0, g.w, 1 << s_):
            if wi < NRAW:
                b, off = SKY_AT[wi]; ad = 0x8000 + off + x * g.h
            else:
                b, ad = wptr[(wi, x)]
            dat += bytes([ad & 0xFF, ad >> 8, b])
    if len(tbl) + len(dat) > 0x10000:
        sys.exit('WALLS.TBL + WALLS.DAT: %d bytes, more than one 64 KB bank' % (len(tbl) + len(dat)))
    open(os.path.join(rl, 'WALLS', 'WALLS.TBL'), 'wb').write(tbl)
    open(os.path.join(rl, 'WALLS', 'WALLS.DAT'), 'wb').write(dat)
    open(os.path.join(rl, 'WALLS', 'WALLS.FMT'), 'wb').write(b'3' if vq is not None else b'2')
    index = {n: NRAW + i for i, n in enumerate(slots)}
    alt = list(range(len(walls)))
    for n, i in index.items():
        if n[:3] in ('SW1', 'SW2'):
            o = ('SW2' if n[:3] == 'SW1' else 'SW1') + n[3:]
            if o in index:
                alt[i] = index[o]
            elif alias.get(o) in index:                # (its other state shown as a look-alike)
                alt[i] = index[alias[o]]
    open(os.path.join(rl, 'WALLS', 'TEXTURE2.TBL'), 'wb').write(struct.pack('<%dH' % len(alt), *alt))
    wmap = dict(format=2, vq=vq is not None, transparent=1, walldefault=index[slots[0]],
                walls={n: index[s_] for n, s_ in alias.items()},
                wallname={str(i): n for n, i in index.items()},
                masked={n: k for k, (n, _) in enumerate(getattr(a, '_masked', []))},
                slots=meta)
    json.dump(wmap, open(os.path.join(rl, 'WALLS', 'WALLMAP.JSON'), 'w'), indent=0)
    # sprites as in write()
    tbl, dat, at = bytearray(), bytearray(), []
    for g, ptrs in zip(images, iptr):
        at.append(len(dat))
        dat += bytes([g.h, g.w & 0xFF])         # (a masked middle texture 256 wide: 0)
        for b, ad in ptrs:
            dat += bytes([ad & 0xFF, ad >> 8, b])
    for k in slots_img:
        tbl += struct.pack('<H', at[k])
    mtbl = b''.join(struct.pack('<H', at[k]) for _, k in getattr(a, '_masked', []))
    if len(dat) + len(tbl) + len(mtbl) > 0x10000:
        sys.exit('IMAGES.TBL + IMAGES.DAT + MASKED.TBL: %d bytes, more than one 64 KB bank'
                 % (len(dat) + len(tbl) + len(mtbl)))
    open(os.path.join(rl, 'IMAGES', 'IMAGES.TBL'), 'wb').write(tbl)
    open(os.path.join(rl, 'IMAGES', 'IMAGES.DAT'), 'wb').write(dat)
    write_masked(rl, mtbl)
    for b in BANKS:
        f = os.path.join(rl, 'WALLIMG', 'BANK%02X.DEF' % b)
        if b in banks:
            open(f, 'wb').write(bytes(pk.data.get(b, b'')))
        elif os.path.exists(f) and (b == BANK_3F or b in MASKED_BANKS):
            os.remove(f)
    w2, i2 = read_rldata(rl)                         # read back
    for x, y in zip(walls + [images[k] for k in slots_img], w2 + i2):
        assert np.array_equal(x.a, y.a), x.name


def write_masked(rl, mtbl):
    """IMAGES/MASKED.TBL: per masked middle texture its IMAGES.DAT offset (no file: none, rlimages.asm)"""
    f = os.path.join(rl, 'IMAGES', 'MASKED.TBL')
    if mtbl:
        open(f, 'wb').write(mtbl)
    elif os.path.exists(f):
        os.remove(f)


def write_images1(a):
    inc = os.path.join(a.data, 'RLDATA', 'IMAGES', 'IMAGES1.INC')
    if a.doom2_monsters:
        with open(inc, 'w') as f:
            f.write(';\n;\tDOOM II image page 1 tags (tools/wad2gfx.py DOOM2_PAGE1; rlimages.inc)\n;\n')
            for tag, frames in DOOM2_PAGE1:
                f.write('\t%%inMAC(%s, %d)\n' % (tag, len(frames)))
    elif os.path.exists(inc):
        os.remove(inc)


def convert(a):
    rec = json.load(open(os.path.join(a.data, 'wad2gfx.json')))
    keep = os.path.join(a.data, 'RLGFX.fx3')
    walls, wsrc, images, isrc, rgb_s, wa = build(a, rec, keep)
    if a.drop_unused:
        if a.map_walls:
            sys.exit('--drop-unused: wall format 1 only (not with --map-walls)')
        kw, ki = used_art(a.data, walls, images, isrc)
        for i in range(len(walls)):
            if i not in kw:
                walls[i] = Art(walls[i].name, np.zeros((1, 1), dtype=walls[i].a.dtype)); wsrc[i] = 'dropped'
        for i in range(len(images)):
            if i not in ki:
                images[i] = Art(images[i].name, np.full((1, 1), -1, dtype=images[i].a.dtype)); isrc[i] = 'dropped'
        log('dropped: %d walls, %d sprites (not needed: 1x1 placeholders)' % (wsrc.count('dropped'), isrc.count('dropped')))
    fmt = os.path.join(a.data, 'RLDATA', 'WALLS', 'WALLS.FMT')
    for f in (fmt, os.path.join(a.data, 'RLDATA', 'WALLS', 'WALLMAP.JSON')):
        if os.path.exists(f) and not a.dry_run:
            os.remove(f)
    if any(b not in MASKED_BANKS for b in a.masked_banks):
        sys.exit('--masked-banks: of %s only' % ' '.join('%02X' % b for b in MASKED_BANKS))
    if a.map_walls:
        banks = PACK_BANKS + [0x1F] * a.bank_1f + EXTRA_BANKS * a.extra_banks + [BANK_3F] * a.bank_3f \
            + a.masked_banks
        if a.bank_3f and a.bank_3f_size:
            BANK_LIMIT[BANK_3F] = a.bank_3f_size
        walls, slots, alias, steps, meta, vh = map_walls(a, rec, walls, images, rgb_s, wa, banks)
        if a.dry_run:
            return
        if a.vq:
            pk, wptr, iptr = place3(walls, slots, a._vq, images, banks)
        else:
            pk, wptr, iptr = place2(walls, vh, images, banks)
        write2(a, os.path.join(a.data, 'RLDATA'), walls, steps, vh, slots, alias, meta, images, pk, wptr, iptr,
               a.image_slots, banks)
        write_images1(a)
        import gfxlimits
        lerr, _ = gfxlimits.check(a.data)
        if lerr:
            sys.exit('engine limits:\n  ' + '\n  '.join(lerr))
        log('banks  : ' + ' '.join('$%02X:%d' % (b, len(pk.data[b])) for b in banks))
        return
    mj = os.path.join(a.data, 'RLDATA', 'IMAGES', 'MASKED.JSON')
    a._masked = []
    if a.masked:                                      # (wall format 1: wad2rl.py reads MASKED.JSON)
        add_masked(a, wa, wad2rl_maps(a.wad), images)
    pk, wptr, iptr, merged, err, need, cap = pack(walls, images, rgb_s, a.lossless,
                                                          PACK_BANKS + [0x1F] * a.bank_1f + EXTRA_BANKS * a.extra_banks)
    shutil.copy(os.path.join(keep, 'WALLS', 'TEXTURE2.TBL'), os.path.join(a.data, 'RLDATA', 'WALLS'))
    for b in [BANK_3F] + MASKED_BANKS:
        if os.path.exists(os.path.join(a.data, 'RLDATA', 'WALLIMG', 'BANK%02X.DEF' % b)):
            os.remove(os.path.join(a.data, 'RLDATA', 'WALLIMG', 'BANK%02X.DEF' % b))
    write(os.path.join(a.data, 'RLDATA'), walls, images, pk, wptr, iptr, a.image_slots)
    write_masked(os.path.join(a.data, 'RLDATA'), b''.join(struct.pack('<H', write.at[k]) for _, k in a._masked))
    if a._masked:
        json.dump({n: k for k, (n, _) in enumerate(a._masked)}, open(mj, 'w'), indent=0)
    elif os.path.exists(mj):
        os.remove(mj)
    write_images1(a)
    import gfxlimits
    lerr, _ = gfxlimits.check(a.data)
    if lerr:
        sys.exit('engine limits:\n  ' + '\n  '.join(lerr))
    log('walls  : %d (%d from the WAD), sprites: %d (%d from the WAD)'
        % (len(walls), wsrc.count('wad'), len(images), isrc.count('wad')))
    log('strips : %d bytes of %d (+ %d KB skies); %d wall columns shown as another column'
        % (need, cap, sum(walls[i].h == 128 for i in range(NRAW)) * 16, merged))
    if err:
        worst = sorted(((v / walls[wi].a.size, walls[wi].name) for wi, v in err.items()), reverse=True)[:8]
        log('most changed walls (mean RGB distance per pixel): ' + ', '.join('%s %.1f' % (n, v) for v, n in worst))


# ---------------------------------------------------------------- compare
def compare(a):
    rec = json.load(open(os.path.join(a.data, 'wad2gfx.json')))
    keep = os.path.join(a.data, 'RLGFX.fx3')
    cw, ci = read_rldata(keep)
    nw, ni = read_rldata(os.path.join(a.data, 'RLDATA'))
    rgb_s = read_colour(keep)
    wa = WadArt(a.wad)

    def err(x, ref):
        X, Xm = rgb_of(x, rgb_s); R, Rm = rgb_of(ref, wa.palette)
        m = Xm & Rm
        return float(np.sqrt(((X - R) ** 2).sum(-1))[m].mean()) if m.any() else 0.0
    rows = []
    for r, c, n in zip(rec['walls'], cw, nw):
        if r.get('wad'):
            ref = resample(wa.texture(r['wad']), r['w'], r['h'], r['sx'], r['sy'], r['dx'], r['dy'])
            rows.append(('wall', r['name'], close(n, c, rgb_s, rgb_s), err(c, ref), err(n, ref)))
    for r, c, n in zip(rec['images'], ci, ni):
        if r.get('lump'):
            sp = wa.sprite(r['lump'])[0]
            ref = sp if sp.a.shape == (r['h'], r['w']) else \
                resample(sp, r['w'], r['h'], sp.w / r['w'], sp.h / r['h'], wrap=False)
            rows.append(('sprite', r['name'], close(n, c, rgb_s, rgb_s), err(c, ref), err(n, ref)))
    for kind in ('wall', 'sprite'):
        k = [x for x in rows if x[0] == kind]
        log('%-7s %3d: %.1f%% of pixels as on the cart; error against the WAD (mean RGB distance): '
            'cart %.1f, converted %.1f' % (kind + 's', len(k), 100 * np.mean([x[2] for x in k]),
                                           np.mean([x[3] for x in k]), np.mean([x[4] for x in k])))
    if a.verbose:
        for x in rows:
            log('  %-6s %-9s like the cart %5.1f%%   error: cart %5.1f  converted %5.1f'
                % (x[0], x[1], 100 * x[2], x[3], x[4]))
    if a.png:
        from PIL import Image
        os.makedirs(a.png, exist_ok=True)

        def img(g):
            X, m = rgb_of(g, rgb_s)
            X[~m] = (40, 0, 40)
            return Image.fromarray(X.astype(np.uint8))
        for kind, A, B, ncol in (('walls', cw, nw, 4), ('sprites', ci, ni, 6)):
            pairs = [(img(x), img(y)) for x, y in zip(A, B)]
            W = 2 * max(p[0].width for p in pairs) + 16
            rows_h = [max(p[0].height for p in pairs[i:i + ncol]) + 6 for i in range(0, len(pairs), ncol)]
            sheet = Image.new('RGB', (W * ncol, sum(rows_h)))
            y = 0
            for r_, i in enumerate(range(0, len(pairs), ncol)):
                for j, (p, q) in enumerate(pairs[i:i + ncol]):
                    sheet.paste(p, (j * W, y)); sheet.paste(q, (j * W + p.width + 4, y))
                y += rows_h[r_]
            sheet.save(os.path.join(a.png, '%s.png' % kind))
        log('sheets (cart left, converted right) in %s' % a.png)


def restore(a):
    keep = os.path.join(a.data, 'RLGFX.fx3')
    for s in GFXDIRS:
        dst = os.path.join(a.data, 'RLDATA', s)
        shutil.rmtree(dst)
        shutil.copytree(os.path.join(keep, s), dst)
    log('cartridge graphics restored')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[1])
    ap.add_argument('cmd', choices=('learn', 'convert', 'compare', 'restore'))
    ap.add_argument('--data', default=os.path.join(HERE, '..', 'data'))
    ap.add_argument('--wad', action='append', default=[])
    ap.add_argument('--src', default=os.path.join(HERE, 'doomfx-src'), help='DOOM-FX source files (WallList, ImageList)')
    ap.add_argument('--lossless', action='store_true', help='no column merging (fails if it does not fit)')
    ap.add_argument('--doom2-monsters', action='store_true',
                    help='add the DOOM II monster images as image page 1 (DOOM2_PAGE1; DOOM2.WAD; !RLDOOM2MONSTERS)')
    ap.add_argument('--bank-1f', action='store_true',
                    help='also fill GamePak bank $1F (less column merging; needs 32 KB of free GamePak ROM)')
    ap.add_argument('--extra-banks', action='store_true',
                    help='also fill GamePak banks $36, $37, $3A, $3B (DOOM II: 32 maps leave room)')
    ap.add_argument('--map-walls', action='store_true',
                    help='wall format 2 (3 with --vq): the wall set made for the WAD\'s maps (tools/wallset.py; DOOM II)')
    ap.add_argument('--dat-budget', type=int, default=52000,
                    help='--map-walls: bytes for the wall table (WALLS.TBL + .DAT, GamePak ROM the levels share)')
    ap.add_argument('--masked-maps', type=lambda v: v.replace(',', ' ').split(), default=[],
                    help='masked: choose the middle textures for these maps only, e.g. "MAP01 MAP02" (the maps '
                         'that fit in the ROM; default: all)')
    ap.add_argument('--masked-banks', type=lambda v: [int(x, 16) for x in v.replace(',', ' ').split()], default=[],
                    help='--map-walls: more GamePak banks for the masked middle textures first, e.g. "3C 39" '
                         '(of %s: those the levels leave emptiest)' % ' '.join('%02X' % b for b in MASKED_BANKS))
    ap.add_argument('--bank-3f', action='store_true', help='--map-walls: also fill GamePak bank $3F')
    ap.add_argument('--bank-3f-size', type=lambda x: int(x, 0), help='--bank-3f: use only this many bytes of it')
    ap.add_argument('--strip-budget', type=int, help='--map-walls: at most this many bytes of wall strips')
    ap.add_argument('--dry-run', action='store_true', help='--map-walls: report only, write nothing')
    ap.add_argument('--rle-lambda', type=float, default=5000.0,
                    help='--map-walls: error per byte saved by turning stretches of a strip into runs')
    ap.add_argument('--edge-weight', type=float, default=0.0,
                    help='--map-walls: run-friendly strips weigh lines across the texture this much more')
    ap.add_argument('--box', action='store_true',
                    help='--map-walls: stored texels are the SNES colour closest to the mean of the texels they stand for')
    ap.add_argument('--min-step', type=int, default=0, help='--map-walls: every wall keeps at most every 2**N-th column')
    ap.add_argument('--slots-by', choices=('look', 'likeness'), default='look',
                    help='--map-walls: rank slots by coarse look (area x distinctness) or by area-weighted 1-SSIM')
    ap.add_argument('--boost', help='--map-walls: JSON {texture: weight factor} (visible difference feedback)')
    ap.add_argument('--wall-slots', type=int, default=252, help='--map-walls: walls of their own (at most 252)')
    ap.add_argument('--half-height', action='store_true',
                    help='--map-walls: walls may store every texel row pair once (wall format 2 flag $80)')
    ap.add_argument('--half-lambda', type=float, default=5000.0,
                    help='--half-height: first error per byte for choosing it (then the strip sharing\'s)')
    ap.add_argument('--half-force', action='store_true', help='--half-height: every wall 16 or more texels high at half size')
    ap.add_argument('--half-rle-lambda', type=float, default=1500.0,
                    help='--half-height: --rle-lambda for the half size strips')
    ap.add_argument('--target-blur', type=float, default=0.0,
                    help='--map-walls: strips aim at this mix of the blurred texture (0-1)')
    ap.add_argument('--restep', action='store_true',
                    help='--half-height: choose the column steps again with the wall table room it leaves')
    ap.add_argument('--half-iter', type=int, default=2, help='--half-height: rounds of choosing it')
    ap.add_argument('--vq', action='store_true',
                    help='--map-walls: wall format 3, blocks of 2x4 texels from codebooks (tools/wallvq.py)')
    ap.add_argument('--masked', action='store_true',
                    help='wall format 1: the middle textures of two-sided lines as well (IMAGES/MASKED.TBL, '
                         'MASKED.JSON for wad2rl.py; --map-walls has them unless --no-masked)')
    ap.add_argument('--masked-opaque', action='store_true',
                    help='masked: also the middle textures without holes (PC DOOM draws them once, untiled)')
    ap.add_argument('--no-masked', action='store_true',
                    help='--map-walls: leave out the masked middle textures of two-sided lines (grates, bars)')
    ap.add_argument('--masked-budget', type=int, default=24576,
                    help='masked: at most this many bytes of strips for masked middle textures (default %(default)s)')
    ap.add_argument('--vq-half', type=int, default=170, help='--vq: this many of the lowest weight slots at half size')
    ap.add_argument('--vq-maxblob', type=int, default=16384, help='--vq: at most this many bytes per group (codebook + indices)')
    ap.add_argument('--drop-unused', action='store_true',
                    help='wall format 1: only the walls the kept levels (levels.inc !use...) show and the sprites '
                         'the WAD has; the rest become 1x1 placeholders (shareware WAD)')
    ap.add_argument('--png')
    ap.add_argument('-v', '--verbose', action='store_true')
    a = ap.parse_args()
    {'learn': learn, 'convert': convert, 'compare': compare, 'restore': restore}[a.cmd](a)


if __name__ == '__main__':
    main()
