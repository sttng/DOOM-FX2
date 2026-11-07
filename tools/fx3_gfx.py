#!/usr/bin/env python3
"""
fx3_gfx.py -- extract the Reality Engine wall/image/colour data from the
"THE ULTIMATE DOOM" FX3 cartridge ROM and rebuild it in the exact format the
DOOM-FX engine includes:

  RLDATA/WALLS/WALLS.TBL, WALLS.DAT        (rlwalls.asm)
  RLDATA/WALLS/TEXTURE2.TBL                (rltextures.asm, RLTextureXLatTable)
  RLDATA/IMAGES/IMAGES.TBL, IMAGES.DAT     (rlimages.asm)
  RLDATA/WALLIMG/BANKxx.DEF                (rlwallimgdef0/1.asm; banks $01-$0D,$18-$1F)
  RLDATA/COLOUR/COLOURMAPS                 (rlcolour.asm, 33*256 bytes)
  RLDATA/COLOUR/BASERGB.RGB                (rlrgb.asm, 14 palettes * 256 * BGR555)

DATA FORMATS (identical in the DOOM-FX engine and in FX3 "Reality Engine 2")
----------------------------------------------------------------------------
xxx.TBL : n * dc.w  offset of entry i within xxx.DAT (little endian)
xxx.DAT : per entry  dc.b Height
                     dc.b Width-1 (WALLS: "modulo")  /  Width (IMAGES)
                     Width * { dc.b AddrLo, AddrHi ; dc.b Bank }   (3 bytes)
          Addr is $8000-$FFFF, Bank is the GSU ROM bank $00-$3F (LoROM, 32K
          per bank), i.e. the pointer is to a pixel strip inside BANKxx.DEF.
Strips are stored BOTTOM-TO-TOP (the engine plots with  dec r2).
Wall strip   : exactly Height pixels:  $01-$7F n, n colour bytes (literal)
                                       $80-$FF -n, 1 colour byte (repeat n)
               SKY walls (#0-#3) are raw (Height bytes), and the sky drawer
               (rldrawf.asm) hard-codes them: SKY1 $01:8000, SKY2 $01:C000,
               SKY3 $02:8000, SKY4 $02:C000, 128x128 column-major each.
Image strip  : non-zero byte = 1 literal pixel; $00,$01-$7F = skip n;
               $00,$80-$FF,c = repeat (256-b) of c; $00,$00 = end of strip.
               A strip ends after Height pixels or at $00,$00.
Colours are indices into COLOURMAPS (getc through the light-level colourmap).
TEXTURE2.TBL : one dc.w per wall:  (AlternateWall#*2)  (mktex DMT800 logic)

Usage: fx3_gfx.py --rom R [--src DIR (default tools/doomfx-src)] --wad W [--out OUTROOT] [--check DIR]
OUTROOT receives RLDATA/... (point it at the build's data/ directory).
"""
import argparse, collections, os, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEF_OUT = 'out'

# ---------------------------------------------------------------- FX3 layout
# Each location is verified against the FX3 GSU code that references it.
FX3_LOC = {
    # rlvsegs3.asm: ibt r3,#<RLWallsTable / ibt r4,#^RLWallsTable / iwt r1,#<(RLWallsData)
    'walls_tbl': (0x650000, [(0x4B83, 'a300a465'), (0x4BF9, 'f18600')]),
    # rlvobjs.asm: ibt r0,#^RLImagesTable ; romb ; iwt r0,#<Tbl ; ... iwt r1,#<Data
    'images_tbl': (0x5F8954, [(0x4E56, 'a05f3fdff05489'), (0x4E5F, 'f1f08a')]),
    # rldraww.asm: ibt r4,#^RLColourMaps ; rltracef3.asm: ibtx r1,#>RLColourMaps
    'colourmaps': (0x6F8000, [(0x690E, 'a46f'), (0x58B3, 'a180')]),
    # rlinit.asm xfer list: RLTextureXLatTable -> RAM, length $86
    'xlat': (0x407E2F, [(0x3FC002, '2f7e4000'), (0x3FC00A, '8600')]),
    # rlrgb.asm: RLRGBNormalAnim dc.w <(RLRGBs+0) = $3749 ; RLRGBAnimTable at file $2AF670
    'rgbs': (None, [(0x2AF694, '4937ff7f')]),
}
FX3_RGB_FILE = 0x2AF670 - 14 * 512      # RLRGBs = RLRGBAnimTable - 14*512
FX3_NWALLS = 67
FX3_NIMAGES = (0x8AF0 - 0x8954) // 2      # 206
FX3_WALLS_DAT = 0x650086
FX3_IMAGES_DAT = 0x5F8AF0
FX3_RAW_WALLS = 4                       # SKY1..SKY4 are stored uncompressed

# WallList wall# -> FX3 wall#.  FX3 = the WallList walls + SKY3,SKY4 (#2,#3) + an
# extra SW1GRAY/SW2GRAY variant (#42/#53, switch moved 64 rows; named <previous
# wall>B).  Verified visually and against DOOM.WAD.
WALL_MAP = ([0, 1] + [i + 2 for i in range(2, 40)] + [43, 44] + list(range(45, 51)) +
            [51, 52] + list(range(54, 62)) + list(range(62, 67)))
FX3_SKY3 = 2
# ImageList image# -> FX3 image#.  FX3 lacks the 26 multiplayer PLAY* frames
# (#0-#25, rebuilt from DOOM.WAD); otherwise the same images in the same order
# (ImageList: 232, FX3: 206).
IMAGE_MAP = [None] * 26 + [i - 26 for i in range(26, 232)]
# The source ImageList (229 images) lacks the 3 barrel-explosion frames that the
# cartridge has after BAR1B0 (#185-#187, rlimages.inc inBarrelExp): without them every
# image tag from inBarrelExp on points 3 images too far.
# They are the PC's BEXPC0-BEXPE0, pixel for pixel (an older wad2gfx.json names them
# BEXPB0-BEXPD0; wad2gfx.py maps those to the right lumps).
BEXP_AT, BEXP = 185, [('BEXPC0', 'RLART:IMAGES/BEXPC0'), ('BEXPD0', 'RLART:IMAGES/BEXPD0'),
                      ('BEXPE0', 'RLART:IMAGES/BEXPE0')]


def read_imagelist(path):
    """ImageList with the cartridge's barrel-explosion frames (232 images)"""
    il = read_list(path)
    if len(il) == 229 and il[BEXP_AT - 1][0] == 'BAR1B0':
        il[BEXP_AT:BEXP_AT] = BEXP
    return il

WALL_BANKS = list(range(0x01, 0x0E)) + list(range(0x18, 0x20))   # 21 * 32K
# bank -> max bytes: 65816 code sections (music driver, INIT, LOGO2) share GamePak
# bank $4E with wall bank $1D, so only its first $55CD bytes take walls
BANK_LIMIT = {0x1D: 0x55CD}


def gsu_file(bank, addr):
    """FX3 GSU address -> ROM file offset."""
    if bank < 0x40:
        return bank * 0x8000 + (addr & 0x7FFF)
    return (bank - 0x40) * 0x10000 + addr


def lin(addr24):
    return gsu_file(addr24 >> 16, addr24 & 0xFFFF)


# ---------------------------------------------------------------- strips
def wall_strip_len(d, p, h):
    px = []; s = p
    while len(px) < h:
        c = d[p]; p += 1
        if c == 0:
            raise ValueError('zero control byte in wall strip at $%X' % (p - 1))
        if c < 0x80:
            px += list(d[p:p + c]); p += c
        else:
            px += [d[p]] * (256 - c); p += 1
    if len(px) != h:
        raise ValueError('wall strip overrun at $%X' % s)
    return px, p - s


def image_strip_len(d, p, h):
    px = []; s = p
    while len(px) < h:
        c = d[p]; p += 1
        if c:
            px.append(c); continue
        n = d[p]; p += 1
        if n == 0:
            break
        if n < 0x80:
            px += [None] * n
        else:
            px += [d[p]] * (256 - n); p += 1
    if len(px) > h:
        raise ValueError('image strip overrun at $%X' % s)
    return px + [None] * (h - len(px)), p - s


class Gfx:
    def __init__(self, name, h, w):
        self.name, self.h, self.w = name, h, w
        self.strips = []     # FX3 file offsets (or None for generated)
        self.lens = []
        self.cols = []       # decoded, bottom->top
        self.gen = None      # generated strip bytes (list of bytes) if not from FX3


def parse_fx3(d, tbl, dat, n, is_wall):
    out = []
    for i in range(n):
        o = d[tbl + 2 * i] | d[tbl + 2 * i + 1] << 8
        p = dat + o
        h, b = d[p], d[p + 1]
        g = Gfx('FX3#%d' % i, h, b + 1 if is_wall else b)
        raw = is_wall and i < FX3_RAW_WALLS
        for k in range(g.w):
            lo, hi, bank = d[p + 2 + 3 * k:p + 5 + 3 * k]
            f = gsu_file(bank, lo | hi << 8)
            if raw:
                px, nb = list(d[f:f + h]), h
            elif is_wall:
                px, nb = wall_strip_len(d, f, h)
            else:
                px, nb = image_strip_len(d, f, h)
            if f // 0x8000 != (f + nb - 1) // 0x8000:
                raise ValueError('strip crosses bank')
            g.strips.append(f); g.lens.append(nb); g.cols.append(px)
        out.append(g)
    return out


# ---------------------------------------------------------------- lists
def read_list(path):
    """Parse WallList / ImageList exactly like mkwall (DMW200..DMW740)."""
    t = open(path, 'rb').read().decode('latin1').replace('\r', '\n')
    p, n, out = 0, len(t), []
    while p < n:
        c = t[p]
        if c == '\n':
            p += 1; continue
        if c == '<':
            q = t.find('>', p); p = n if q < 0 else q + 1; continue
        if c == ';':
            q = t.find('\n', p); p = n if q < 0 else q + 1; continue
        q = t.find('\n', p); name = t[p:q if q >= 0 else n]; p = n if q < 0 else q + 1
        q = t.find('\n', p); fn = t[p:q if q >= 0 else n]; p = n if q < 0 else q + 1
        out.append((name.strip(), fn.strip()))
    return out


def make_texture2(path):
    """Emulate mktex DMT800: TEXTURE2.TBL from TextureList2."""
    lines = open(path, 'rb').read().decode('latin1').replace('\r', '\n').split('\n')
    ents = []                       # (name, alt, kind, data, wall#)
    i = 0
    while i < len(lines):
        if not lines[i].strip():
            i += 1; continue
        hdr = lines[i].split(','); i += 1
        name = hdr[0].strip().upper()
        alt = hdr[3].strip().upper() if len(hdr) > 3 and hdr[3].strip() else name
        if lines[i].startswith(' '):
            while i < len(lines) and lines[i].startswith(' '):
                i += 1
            kind, data = 'P', None
        else:
            kind, data = 'T', lines[i].split(',')[0].strip().upper(); i += 1
        wn = lines[i].strip(); i += 1          # wall translation line
        i += 1                                 # misc text line
        ents.append((name, alt[:8], kind, data, int(wn) if wn else None))
    byname = {}
    for e in ents:
        byname.setdefault(e[0], e)
    out = bytearray()
    for e in ents:
        if e[2] != 'P':
            continue
        nm, seen, v = e[1], set(), -1
        while nm in byname and nm not in seen:
            seen.add(nm); t = byname[nm]
            if t[2] == 'T':
                nm = t[3]; continue
            v = t[4]; break
        out += struct.pack('<H', (v * 2) & 0xFFFF)
    return bytes(out), [e for e in ents if e[2] == 'P']


# ---------------------------------------------------------------- image encode
def encode_image_strip(px):
    """mkwall BuildImageStrip with -c (ImageComp); px bottom->top, 0 = transparent."""
    out = bytearray(); d2 = -1; i = 0; n = len(px)
    state = 'U'
    while i < n:
        p = px[i]
        if state == 'U':                         # BIS300
            if p == d2:
                out[-1] = 0; out += bytes([0xFE, d2]); state = 'R'; i += 1; continue
            state = 'S0'
        if state == 'S0':                        # BIS340
            if p == 0:
                out += b'\x00\x00'; state = 'K'; i += 1; continue
            d2 = p; out.append(p); state = 'U'; i += 1; continue
        if state == 'R':                         # BIS420
            if p == d2:
                out[-2] = (out[-2] - 1) & 0xFF; i += 1; continue
            if out[-2] == 0xFE:                  # only 2 -> 2 uniques
                del out[-3:]; out += bytes([d2, d2])
            state = 'S0'; continue               # BIS340 with p
        if state == 'K':                         # BIS620: count++ then read
            out[-1] += 1
            if p != 0:
                d2 = p; out.append(p); state = 'U'
            i += 1; continue
    if state == 'R' and out[-2] == 0xFE:
        del out[-3:]; out += bytes([d2, d2])
    if state == 'K':
        out[-1] = 0
    return bytes(out)


def learn_remap(d, fx3imgs, wadspr, names, cmaps_snes, cm_doom):
    """DOOM palette index -> SNES palette index, learned from FX3 sprites that
    are pixel-aligned with the WAD sprites, then solved/checked with the
    colourmaps (SNES_CM[k][r(b)] == r(DOOM_CM[k][b]))."""
    votes = collections.defaultdict(collections.Counter)
    for i, nm in enumerate(names):
        j = IMAGE_MAP[i]
        if j is None:
            continue
        s = wadspr(nm); g = fx3imgs[j]
        if not s or (s[0], s[1]) != (g.w, g.h):
            continue
        for x in range(g.w):
            for y in range(g.h):
                a = g.cols[x][g.h - 1 - y]; b = s[2][x][y]
                if a is not None and b is not None:
                    votes[b][a] += 1
    rm = {b: v.most_common(1)[0][0] for b, v in votes.items()}
    for _ in range(4):
        new = {}
        for b in range(256):
            best = None
            for r in range(256):
                sc = sum(1 for k in range(1, 33)
                         if cm_doom[k * 256 + b] in rm and cmaps_snes[k * 256 + r] == rm[cm_doom[k * 256 + b]])
                key = (sc, votes[b][r])
                if best is None or key > best[0]:
                    best = (key, r)
            new[b] = best[1]
        if new == rm:
            break
        rm = new
    return rm


# ---------------------------------------------------------------- packing
class Packer:
    def __init__(self):
        self.data = {b: bytearray() for b in WALL_BANKS}
        self.fixed = {}
        self.saved = 0

    def place_fixed(self, bank, off, blob):
        buf = self.data[bank]
        if len(buf) < off:
            buf += bytes(off - len(buf))
        assert len(buf) == off, 'fixed placement overlap'
        buf += blob
        return bank, off

    def place(self, blob, search=False, fit='first'):
        """Place blob; reuse an identical byte run (search) or overlap the
        blob's head with a bank's tail (like mkwall's FWIS360 partial match)."""
        if search:
            for b in WALL_BANKS:
                k = bytes(self.data[b]).find(blob)
                if k >= 0:
                    return b, k
        best = None
        for b in WALL_BANKS:
            buf = self.data[b]
            k = min(len(buf), len(blob))
            while k and buf[len(buf) - k:] != blob[:k]:
                k -= 1
            if len(buf) - k + len(blob) <= BANK_LIMIT.get(b, 0x8000) and (best is None or k > best[0]):
                best = (k, b)
        if best is None or (best[0] == 0 and fit == 'best'):
            # best fit: the bank with the least room that still takes the blob
            room = [(BANK_LIMIT.get(b, 0x8000) - len(self.data[b]), b) for b in WALL_BANKS]
            room = [r for r in room if r[0] >= len(blob)]
            if room:
                best = (0, min(room)[1])
        if best is None:
            raise RuntimeError('wall/image strip data does not fit in the wall banks '
                               '(blob of %d bytes left over)' % len(blob))
        k, b = best
        off = len(self.data[b]) - k
        self.data[b] += blob[k:]
        self.saved += k
        return b, off


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[1])
    ap.add_argument('--rom', required=True)
    ap.add_argument('--src', default=os.path.join(HERE, 'doomfx-src'), help='DOOM-FX source files (WallList, ...)')
    ap.add_argument('--wad', required=True)
    ap.add_argument('--out', default=DEF_OUT)
    ap.add_argument('--check', default=None, help='write PNG check images here')
    a = ap.parse_args()

    d = open(a.rom, 'rb').read()
    assert len(d) == 4 * 1024 * 1024, 'expected the 4MB FX3 ROM'
    for key, (_, sigs) in FX3_LOC.items():
        for off, hx in sigs:
            if d[off:off + len(hx) // 2].hex() != hx:
                sys.exit('FX3 signature mismatch for %s at $%X' % (key, off))

    fx3w = parse_fx3(d, lin(0x650000), lin(FX3_WALLS_DAT), FX3_NWALLS, True)
    fx3i = parse_fx3(d, lin(0x5F8954), lin(FX3_IMAGES_DAT), FX3_NIMAGES, False)
    cmaps = d[lin(0x6F8000):lin(0x6F8000) + 34 * 256]
    assert cmaps[32 * 256:33 * 256] == cmaps[33 * 256:34 * 256]   # rlcolour.asm layout
    rgbs = d[FX3_RGB_FILE:FX3_RGB_FILE + 14 * 512]
    xlat_fx3 = d[lin(0x407E2F):lin(0x407E2F) + 0x86]

    walllist = read_list(os.path.join(a.src, 'WallList'))
    imagelist = read_imagelist(os.path.join(a.src, 'ImageList'))
    assert len(walllist) == len(WALL_MAP) == 63, len(walllist)
    assert len(imagelist) == len(IMAGE_MAP) == 232, len(imagelist)

    # --- TEXTURE2.TBL
    tex2, tex2ents = make_texture2(os.path.join(a.src, 'TextureList2'))
    assert len(tex2) == 2 * len(walllist)
    fx3x = [struct.unpack('<H', xlat_fx3[2 * i:2 * i + 2])[0] // 2 for i in range(FX3_NWALLS)]
    inv = {f: i for i, f in enumerate(WALL_MAP)}
    for i in range(len(walllist)):
        mine = struct.unpack('<H', tex2[2 * i:2 * i + 2])[0] // 2
        if inv.get(fx3x[WALL_MAP[i]]) != mine:
            print('WARNING: TEXTURE2 entry %d (%s): TextureList2 -> %d, FX3 -> %s' %
                  (i, walllist[i][0], mine, inv.get(fx3x[WALL_MAP[i]])))
    for k, (nm, _, _, _, wn) in enumerate(tex2ents):
        if wn != k:
            print('WARNING: TextureList2 wall #%d is %s (wall translation %s)' % (k, nm, wn))

    # --- walls in FX3 order (named from WallList), images in ImageList order
    walls = []
    inv = {f: i for i, f in enumerate(WALL_MAP)}
    for f in range(FX3_NWALLS):
        g = fx3w[f]
        if f in inv:
            g.name = walllist[inv[f]][0]
        elif f in (2, 3):
            g.name = 'SKY%d' % (f + 1)
        else:
            g.name = walllist[inv[f - 1]][0] + 'B'
        walls.append(g)
    tex2 = bytes(xlat_fx3)
    nraw = FX3_RAW_WALLS
    images = []
    missing = []
    for i, (nm, fn) in enumerate(imagelist):
        if IMAGE_MAP[i] is not None:
            g = fx3i[IMAGE_MAP[i]]
            images.append(Gfx(nm, g.h, g.w)); images[-1].__dict__.update(
                strips=g.strips, lens=g.lens, cols=g.cols)
        else:
            images.append(None); missing.append(i)

    # --- regenerate the missing PLAY* images from DOOM.WAD
    sys.path.insert(0, HERE)
    from wad import WAD
    wad = WAD(a.wad)

    def wadspr(name):
        s = wad.find('S_START')
        for k in range(s, len(wad.lumps)):
            if wad.lumps[k][0] == name:
                dat = wad.data(k)
                W_, H_ = struct.unpack('<hh', dat[:4])
                cols = []
                for x in range(W_):
                    o = struct.unpack('<i', dat[8 + 4 * x:12 + 4 * x])[0]
                    col = [None] * H_
                    while dat[o] != 255:
                        top, nn = dat[o], dat[o + 1]
                        for q in range(nn):
                            if top + q < H_:
                                col[top + q] = dat[o + 3 + q]
                        o += nn + 4
                    cols.append(col)
                return W_, H_, cols
        return None

    names = [n for n, _ in imagelist]
    remap = learn_remap(d, fx3i, wadspr, names, cmaps, wad.get('COLORMAP'))
    for i in missing:
        nm = names[i]
        s = wadspr(nm)
        if s is None:
            sys.exit('no WAD sprite for %s' % nm)
        W_, H_, cols = s
        pix = [[0 if c is None else remap[c] for c in col] for col in cols]
        while W_ and not any(pix[W_ - 1]):                 # mkwall: right-most strip
            W_ -= 1
        while H_ and not any(pix[x][H_ - 1] for x in range(W_)):   # bottom-most
            H_ -= 1
        g = Gfx(nm, H_, W_)
        g.gen = []
        for x in range(W_):
            col = pix[x][:H_][::-1]                        # bottom -> top
            g.gen.append(encode_image_strip(col))
            g.cols.append([c if c else None for c in col])
        images[i] = g

    # --- collect FX3 strip intervals actually used, group overlapping ones
    used = set()
    for g in walls[nraw:] + [x for x in images if x.gen is None]:
        for f, n in zip(g.strips, g.lens):
            used.add((f, f + n))
    sky_ranges = [(0x8000, 0xC000), (0xC000, 0x10000)]
    groups = []
    for s, t in sorted(used):
        if any(a_ <= s < b_ for a_, b_ in sky_ranges) or 0x10000 <= s < 0x18000:
            sys.exit('strip inside sky area')
        if groups and s < groups[-1][1]:
            groups[-1][1] = max(groups[-1][1], t)
        else:
            groups.append([s, t])

    pk = Packer()
    reloc = {}                                   # FX3 file offset -> (bank, addr)

    def put_fixed(fx3wall, bank, off):
        g = fx3w[fx3wall]
        base = g.strips[0]
        blob = d[base:base + g.w * g.h]
        assert all(g.strips[k] == base + k * g.h for k in range(g.w))
        pk.place_fixed(bank, off, blob)
        for k in range(g.w):
            reloc[g.strips[k]] = (bank, 0x8000 + off + k * g.h)
    put_fixed(WALL_MAP[0], 0x01, 0x0000)        # SKY1  $01:8000 (rldrawf.asm)
    put_fixed(WALL_MAP[1], 0x01, 0x4000)        # SKY2  $01:C000
    put_fixed(FX3_SKY3, 0x02, 0x0000)           # SKY3  $02:8000
    put_fixed(FX3_SKY3 + 1, 0x02, 0x4000)       # SKY4  $02:C000 (rldrawf.asm !RLSKY4)

    gstart = {}
    for s, t in sorted(groups, key=lambda g: g[0] - g[1]):    # biggest first, best fit
        b, off = pk.place(d[s:t], fit='best')
        gstart[s] = (b, off, t)
    starts = sorted(gstart)
    import bisect

    def relocate(f):
        if f in reloc:
            return reloc[f]
        k = bisect.bisect_right(starts, f) - 1
        s = starts[k]; b, off, t = gstart[s]
        assert s <= f < t
        return b, 0x8000 + off + (f - s)

    gen_stats = [0, 0]
    for g in images:
        if g.gen is None:
            continue
        g.ptrs = []
        for blob in g.gen:
            b, off = pk.place(blob, search=True, fit='best')
            gen_stats[0] += 1
            g.ptrs.append((b, 0x8000 + off))

    # --- write tables
    def build(lst, is_wall):
        tbl, dat = bytearray(), bytearray()
        for g in lst:
            tbl += struct.pack('<H', len(dat))
            dat += bytes([g.h, (g.w - 1) if is_wall else g.w])
            ptrs = g.ptrs if getattr(g, 'gen', None) else [relocate(f) for f in g.strips]
            for b, ad in ptrs:
                assert 0x8000 <= ad <= 0xFFFF
                dat += bytes([ad & 0xFF, ad >> 8, b])
        return bytes(tbl), bytes(dat)

    wt, wd = build(walls, True)
    it, idt = build(images, False)
    out = os.path.join(a.out, 'RLDATA')
    for sub in ('WALLS', 'IMAGES', 'WALLIMG', 'COLOUR'):
        os.makedirs(os.path.join(out, sub), exist_ok=True)

    def wr(rel, data):
        open(os.path.join(out, rel), 'wb').write(data)
    wr('WALLS/WALLS.TBL', wt); wr('WALLS/WALLS.DAT', wd)
    wr('WALLS/TEXTURE2.TBL', tex2)
    wr('IMAGES/IMAGES.TBL', it); wr('IMAGES/IMAGES.DAT', idt)
    wr('COLOUR/COLOURMAPS', bytes(cmaps[:33 * 256]))
    wr('COLOUR/BASERGB.RGB', bytes(rgbs))
    total = 0
    for b in WALL_BANKS:
        buf = bytes(pk.data[b])
        wr('WALLIMG/BANK%02X.DEF' % b, buf)
        total += len(buf)

    # --- verify: decode every strip again from the written banks
    banks = {b: bytes(pk.data[b]) for b in WALL_BANKS}

    def verify(tbl, dat, lst, is_wall):
        for i, g in enumerate(lst):
            o = struct.unpack('<H', tbl[2 * i:2 * i + 2])[0]
            h, w = dat[o], dat[o + 1] + (1 if is_wall else 0)
            assert (h, w) == (g.h, g.w)
            for x in range(w):
                lo, hi, b = dat[o + 2 + 3 * x:o + 5 + 3 * x]
                buf = banks[b] + bytes(16); p = (lo | hi << 8) - 0x8000
                if is_wall and i < nraw:
                    px = list(buf[p:p + h])
                elif is_wall:
                    px, _ = wall_strip_len(buf, p, h)
                else:
                    px, _ = image_strip_len(buf, p, h)
                assert px == g.cols[x], (g.name, x)
    verify(wt, wd, walls, True)
    verify(it, idt, images, False)

    print('walls  : %d (WALLS.TBL %d, WALLS.DAT %d bytes)' % (len(walls), len(wt), len(wd)))
    print('images : %d (IMAGES.TBL %d, IMAGES.DAT %d bytes); %d regenerated from WAD: %s'
          % (len(images), len(it), len(idt), len(missing), ' '.join(names[i] for i in missing)))
    print('TEXTURE2.TBL %d bytes, COLOURMAPS %d, BASERGB.RGB %d' % (len(tex2), 33 * 256, len(rgbs)))
    print('strip groups from FX3: %d (%d bytes)' % (len(groups), sum(t - s for s, t in groups)))
    print('bank usage (bytes of 32768):')
    for b in WALL_BANKS:
        print('  $%02X %5d %s' % (b, len(pk.data[b]), '(SKY1+SKY2)' if b == 1 else '(SKY3 @$8000)' if b == 2 else ''))
    print('  total %d / %d, free %d' % (total, 0x8000 * len(WALL_BANKS), 0x8000 * len(WALL_BANKS) - total))

    if a.check:
        from PIL import Image
        os.makedirs(a.check, exist_ok=True)
        pal = []
        for i in range(256):
            v = rgbs[2 * i] | rgbs[2 * i + 1] << 8
            pal.append(((v & 31) * 255 // 31, ((v >> 5) & 31) * 255 // 31, ((v >> 10) & 31) * 255 // 31))

        def png(g, fn):
            im = Image.new('RGB', (g.w, g.h), (90, 0, 90))
            for x, col in enumerate(g.cols):
                for y, c in enumerate(col):
                    if c is not None:
                        im.putpixel((x, g.h - 1 - y), pal[c])
            im.resize((g.w * 2, g.h * 2), Image.NEAREST).save(fn)
        for i, g in enumerate(walls):
            png(g, os.path.join(a.check, 'wall%02d_%s.png' % (i, g.name)))
        for i, g in enumerate(images):
            png(g, os.path.join(a.check, 'img%03d_%s.png' % (i, g.name)))


if __name__ == '__main__':
    main()
