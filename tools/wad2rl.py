#!/usr/bin/env python3
"""
wad2rl.py - convert DOOM .WAD maps into Reality Engine level data
(data/RLLEV/<map>/...), the format the engine includes through EXMYMAC.

This is a port of the level part of RIPDOOM (DOOM-FX source/ripdoom3.asm,
the 68000 tool Sculptured Software used), with the changes the FX3
"Ultimate DOOM" data needs:

  * the BSP comes straight from the WAD: NODES -> BSP, SSECTORS -> AREAS,
    SEGS -> SEGS (no node builder needed)
  * SIDEDEFS -> FACES (deduplicated like RIPDOOM), LINEDEFS -> LINES,
    SECTORS -> SECTORS, THINGS -> OBJECTS (priority sorted like RIPDOOM),
    BLOCKMAP -> BLOCKMAP (line lists deduplicated)
  * DOORS / STAIRS / FLOORS / LIFTS / CEILINGS are built from the line types
    (RIPDOOM's tables plus the Ultimate DOOM types the engine runs; line
    types the engine has no code for are cleared, as FX3 did)
  * REJECT is the FX3 sector visibility matrix (rows of (sectors+7)>>3 bytes,
    bit set = can see), computed with portal flow (rlpvs.py) or, with
    --pvs wad, taken from the WAD's REJECT.  When the level RAM image
    (LINES, BLOCKMAP, OBJECTS, REJECT: GSU RAM $71:0000 up to RAMIMAGEEND,
    src/include/savegame.inc) would not fit with it, it stays in the
    GamePak ROM (marker file REJROM)
  * vertex pointers are built for the engine's _RLVertexes (--vbase); convert
    into a directory with a levels.inc updates its limits and vertex base
    (finalize)
  * wall textures are FX3 wall numbers, floors/ceilings FX3 colours, objects
    FX3 object types.  The wall/floor tables are learned from FX3 levels
    (learn, writes a JSON table); names the table does not know are mapped
    to the wall/colour that looks closest (4x4 average colours from the WAD).
    --walls (wad2gfx.py --map-walls, wall format 2/3): the wall indexes of
    WALLMAP.JSON instead.  Masked middle textures (MASKED.TBL index in the
    face) come from WALLMAP.JSON, or with wall format 1 from --masked
    MASKED.JSON (wad2gfx.py --masked)
  * limits: maps with more than 255 sectors get look-alike sectors that never
    change merged; the engine limits (MaxRLVisNodes/Areas, MaxRLFObjects,
    MaxRLVSectors) are read from rle.inc and RAMIMAGEEND from savegame.inc
    (engine_limits).  The visible floors/ceilings per frame are not a property of
    the map: they share the plot data room, and the engine leaves out the
    strips that do not fit (rltracef.asm)
  * tests: RL_START="MAP15:x,y,angle;..." moves player 1's start

Nothing here contains game data: the tables are generated from the user's
own ROM and WAD at build time.

usage:
  wad2rl.py learn  --wad DOOM.WAD --ref data/RLLEV --out tables.json
  wad2rl.py convert --wad DOOM.WAD [--wad PWAD] --tables tables.json --out DIR
                    [--walls WALLMAP.JSON | --masked MASKED.JSON] [--pvs compute|wad] [MAPS...]
  wad2rl.py compare --wad DOOM.WAD --tables tables.json --ref data/RLLEV [--out report.json] [MAPS...]
  wad2rl.py finalize --out DIR
"""
import argparse, json, math, os, re, struct, sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from wad import directory as wadlumps   # noqa: E402

RLL, RLB, RLA, RLG, RLS = 12, 28, 4, 11, 10
RLSD = 14
LUMPS = ['BSP', 'AREAS', 'VERTEXES', 'LINES', 'SEGS', 'FACES', 'SECTORS', 'OBJECTS',
         'BLOCKMAP', 'REJECT', 'DOORS', 'STAIRS', 'FLOORS', 'CEILINGS', 'LIFTS']


# --------------------------------------------------------------------------
#   WAD reading
# --------------------------------------------------------------------------
class Wad:
    def __init__(self, *files):
        self.lumps = []                     # (name, data); later files override
        for fn in files:
            d = open(fn, 'rb').read()
            self.lumps += [(nm, d[p:p + s]) for nm, p, s in wadlumps(d)]

    def find(self, name):
        for i in range(len(self.lumps) - 1, -1, -1):
            if self.lumps[i][0] == name:
                return i
        return -1

    def get(self, name):
        i = self.find(name)
        return self.lumps[i][1] if i >= 0 else None

    def maps(self):
        out = []
        for i, (n, _) in enumerate(self.lumps):
            if i + 1 < len(self.lumps) and self.lumps[i + 1][0] == 'THINGS' and n not in out:
                out.append(n)
        return out

    def map(self, name):
        i = self.find(name)
        if i < 0:
            raise KeyError(name)
        m = {}
        for j in range(i + 1, min(i + 12, len(self.lumps))):
            n, d = self.lumps[j]
            if n in ('THINGS', 'LINEDEFS', 'SIDEDEFS', 'VERTEXES', 'SEGS', 'SSECTORS',
                     'NODES', 'SECTORS', 'REJECT', 'BLOCKMAP'):
                m.setdefault(n, d)
            else:
                break
        return Map(name, m)


# --------------------------------------------------------------------------
#   what textures and flats look like (for names the FX3 tables don't know)
# --------------------------------------------------------------------------
GRID = 4


def palette(wad):
    p = wad.get('PLAYPAL')
    return [tuple(p[i * 3:i * 3 + 3]) for i in range(256)]


def grid_sig(pix, w, h, pal):
    """GRID x GRID average colours (transparent pixels skipped) -> flat list"""
    out = []
    for gy in range(GRID):
        for gx in range(GRID):
            r = g = b = n = 0
            for y in range(gy * h // GRID, max(gy * h // GRID + 1, (gy + 1) * h // GRID)):
                for x in range(gx * w // GRID, max(gx * w // GRID + 1, (gx + 1) * w // GRID)):
                    c = pix[y * w + x]
                    if c >= 0:
                        pr, pg, pb = pal[c]
                        r += pr; g += pg; b += pb; n += 1
            out += [r / n, g / n, b / n] if n else [0, 0, 0]
    return out


def signatures(wad):
    pal = palette(wad)
    sigs = {'walls': {}, 'flats': {}}
    # flats
    inside = False
    for n, d in wad.lumps:
        if n in ('F_START', 'FF_START'):         # (F1_/F2_ markers inside do not end the
            inside = True                           #  flats: DOOM II's own come after F1_END)
        elif n in ('F_END', 'FF_END'):
            inside = False
        elif inside and len(d) == 4096:
            sigs['flats'][n] = grid_sig(list(d), 64, 64, pal)
    # textures (TEXTURE1/TEXTURE2 from PNAMES patches)
    pn = wad.get('PNAMES')
    if pn is None:
        return sigs
    names = [name8(pn[4 + 8 * i:12 + 8 * i]) for i in range(struct.unpack_from('<i', pn)[0])]
    patches = {}
    for n, d in wad.lumps:
        patches[n] = d
    for tl in ('TEXTURE1', 'TEXTURE2'):
        t = wad.get(tl)
        if t is None:
            continue
        nt = struct.unpack_from('<i', t)[0]
        for i in range(nt):
            o = struct.unpack_from('<i', t, 4 + 4 * i)[0]
            tn = name8(t[o:o + 8])
            w, h = struct.unpack_from('<hh', t, o + 12)
            npt = struct.unpack_from('<h', t, o + 20)[0]
            pix = [-1] * (w * h)
            for k in range(npt):
                ox, oy, pi = struct.unpack_from('<hhh', t, o + 22 + 10 * k)
                pd = patches.get(names[pi]) if 0 <= pi < len(names) else None
                if not pd:
                    continue
                pw, ph = struct.unpack_from('<hh', pd)
                for x in range(pw):
                    tx = ox + x
                    if not 0 <= tx < w:
                        continue
                    q = struct.unpack_from('<i', pd, 8 + 4 * x)[0]
                    while q < len(pd) and pd[q] != 0xFF:
                        top, cnt = pd[q], pd[q + 1]
                        for y in range(cnt):
                            ty = oy + top + y
                            if 0 <= ty < h:
                                pix[ty * w + tx] = pd[q + 3 + y]
                        q += cnt + 4
            sigs['walls'][tn] = grid_sig(pix, w, h, pal)
    return sigs


def name8(b):
    return b.split(b'\0')[0].decode('latin1').upper()


class Map:
    def __init__(self, name, m):
        self.name = name
        self.raw = m
        u = struct.iter_unpack
        self.vertexes = [v for v in u('<hh', m['VERTEXES'])]
        self.lines = [dict(v1=a, v2=b, flags=c, type=d, tag=e, right=f, left=g)
                      for a, b, c, d, e, f, g in u('<HHHHHHH', m['LINEDEFS'])]
        for l in self.lines:
            if l['left'] == 0xFFFF:
                l['left'] = -1
            if l['right'] == 0xFFFF:
                l['right'] = -1
        self.sides = [dict(xoff=a, yoff=b, upper=name8(c), lower=name8(d), mid=name8(e), sector=f)
                      for a, b, c, d, e, f in u('<hh8s8s8sH', m['SIDEDEFS'])]
        # Packed sidedefs (one sidedef for several lines: TNT, some Plutonia maps): DOOM takes
        # the sector behind a line from the line, a FACE holds it (SectorFar: the door a use
        # opens, which steps are drawn), so every line gets a sidedef of its own; identical
        # faces are merged again (conv_faces).  (Plutonia MAP01: both start-room doors shared
        # one, using the north door opened the south one.)
        used = set()
        for l in self.lines:
            for k in ('right', 'left'):
                if l[k] >= 0:
                    if l[k] in used:
                        self.sides.append(dict(self.sides[l[k]]))
                        l[k] = len(self.sides) - 1
                    used.add(l[k])
        self.sectors = [dict(floor=a, ceil=b, ftex=name8(c), ctex=name8(d), light=e, special=f, tag=g,
                             rawftex=c)
                        for a, b, c, d, e, f, g in u('<hh8s8sHHH', m['SECTORS'])]
        self.segs = [dict(v1=a, v2=b, angle=c, line=d, side=e, offset=f)
                     for a, b, c, d, e, f in u('<HHhHHh', m['SEGS'])]
        self.ssectors = [v for v in u('<HH', m['SSECTORS'])]
        self.nodes = m['NODES']
        self.things = [dict(x=a, y=b, angle=c, type=d, flags=e) for a, b, c, d, e in u('<hhhHH', m['THINGS'])]
        self.substituted = Counter()
        for t in self.things:           # DOOM II things the engine lacks: the nearest DOOM thing
            s = None if DOOM2_MONSTERS and t['type'] in DOOM2_TYPES.values() else DOOM2_SUBST.get(t['type'])
            if s is not None:
                self.substituted[(t['type'], s)] += 1
                t['type'] = s
        # (tests: RL_START="MAP15:x,y,angle;..." moves player 1's start, e.g. to look at a grate)
        for st in os.environ.get('RL_START', '').split(';'):
            if st.startswith(name + ':'):
                x, y, a = (int(v) for v in st.split(':')[1].split(','))
                for t in self.things:
                    if t['type'] == 1:
                        t['x'], t['y'], t['angle'] = x, y, a
        for t in self.things:           # DOOM ignores the skill bits of player starts (E4M3, E4M4 and
            if t['type'] in (1, 2, 3, 4):   # E4M8 have none): every skill, as the cartridge has them
                t['flags'] |= 0x07
        self.blockmap = m['BLOCKMAP']
        self.reject = m.get('REJECT', b'')

    def sec(self, side):
        return self.sides[side]['sector']

    def stair_chain(self, first):
        """sectors a stair starting at FIRST raises (RIPDOOM's walk)"""
        base = self.sectors[first]['rawftex']
        secs, s = [first], first
        while True:
            nxt = None
            for k in self.lines:
                if self.sec(k['right']) == s and k['left'] >= 0:
                    n = self.sec(k['left'])
                    if self.sectors[n]['rawftex'] == base:
                        nxt = n
                        break
            if nxt is None or nxt in secs:
                return secs
            secs.append(nxt)
            s = nxt

    def merge_sectors(self, limit):
        """merge sectors that look the same and never change (no tag a line uses,
        no special other than the same light/damage one, no door, stair or donut)
        until at most LIMIT are left.  Returns the number of sectors merged away,
        or -(sectors left) when even merging every look-alike is not enough."""
        n = len(self.sectors)
        if n <= limit:
            return 0
        keep = set()
        for l in self.lines:
            t = l['type']
            if t in DOORLOCAL and l['left'] >= 0:
                keep.add(self.sec(l['left']))
            if t in STAIRTYPES and l['tag']:
                for s, sc in enumerate(self.sectors):
                    if sc['tag'] == l['tag']:
                        keep.update(self.stair_chain(s))
                        break
            if t == 9 and l['tag']:             # donut: RIPDOOM uses hole-1
                for s, sc in enumerate(self.sectors):
                    if sc['tag'] == l['tag']:
                        keep.update((s, s - 1))
        # look-alike: same heights, flats and light; if that is not enough, light in
        # steps of 16, 32, 64, then any light (a visible edit: self.merge_light)
        self.merge_light = None
        used = {l['tag'] for l in self.lines if l['tag']}   # a tag no line uses does nothing
        for q in (None, 16, 32, 64, 256):
            groups = defaultdict(list)
            for s, sc in enumerate(self.sectors):
                if not ((sc['tag'] in used) or sc['special'] not in SAMESPECIAL or s in keep):
                    lt = sc['light'] if q is None else sc['light'] // q
                    groups[(sc['floor'], sc['ceil'], sc['rawftex'], sc['ctex'], lt, sc['special'])].append(s)
            # merge the biggest groups first, only as many as needed
            into = {}
            left = n
            for g in sorted(groups.values(), key=lambda g: (-len(g), g[0])):
                if left <= limit:
                    break
                if len(g) < 2:
                    continue
                take = g[:min(len(g), left - limit + 1)]
                for s in take[1:]:
                    into[s] = take[0]
                left -= len(take) - 1
            if left <= limit:
                self.merge_light = q
                break
        if left > limit:
            return -left
        new = [s for s in range(n) if s not in into]
        rank = {s: i for i, s in enumerate(new)}
        self.remap = {s: rank[into.get(s, s)] for s in range(n)}
        old = self.sectors
        self.sectors = [old[s] for s in new]
        for sd in self.sides:
            sd['sector'] = self.remap[sd['sector']]
        # REJECT: a merged sector sees what any of its parts sees
        rej = self.reject
        nn = len(new)
        blocked = bytearray((nn * nn + 7) >> 3)
        vis = [[False] * nn for _ in range(nn)]
        for a in range(n):
            for b in range(n):
                k = a * n + b
                if not ((k >> 3) < len(rej) and rej[k >> 3] >> (k & 7) & 1):
                    vis[self.remap[a]][self.remap[b]] = True
        for a in range(nn):
            for b in range(nn):
                if not vis[a][b]:
                    k = a * nn + b
                    blocked[k >> 3] |= 1 << (k & 7)
        self.reject = bytes(blocked)
        return n - nn


# --------------------------------------------------------------------------
#   RIPDOOM tables
# --------------------------------------------------------------------------
# WAD LINE_TYPE -> LINE FLAGS2 (TRIGGER/USABLE), types 0-109
WADLINETYPEFLAGS = bytes([
    0x00, 0x28, 0x04, 0x04, 0x00, 0x04, 0x00, 0x08, 0x04, 0x08,
    0x04, 0x08, 0x00, 0x04, 0x08, 0x00, 0x04, 0x00, 0x08, 0x04,
    0x08, 0x08, 0x04, 0x08, 0x00, 0x00, 0x08, 0x08, 0x08, 0x08,
    0x04, 0x08, 0x08, 0x08, 0x08, 0x04, 0x04, 0x04, 0x04, 0x14,
    0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x08, 0x04, 0x00, 0x00, 0x00, 0x04, 0x00, 0x04, 0x04,
    0x00, 0x08, 0x08, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x08, 0x00, 0x00, 0x04, 0x04, 0x04, 0x00, 0x04, 0x00, 0x00,
    0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x04, 0x04, 0x14, 0x04,
    0x04, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x14, 0x04, 0x00,
    0x00, 0x00, 0x08, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])

# FX3 (Ultimate DOOM) line types beyond RIPDOOM's table: trigger flags as the
# FX3 levels have them ($04 walk, $08 use, $10 monsters walk, $20 monsters use)
FX3LINETYPEFLAGS = {25: 0x04, 44: 0x04, 45: 0x08, 60: 0x08, 65: 0x04, 71: 0x08, 76: 0x04, 83: 0x04,
                    99: 0x08, 101: 0x08, 104: 0x04, 105: 0x04, 109: 0x04, 112: 0x08, 114: 0x08,
                    115: 0x08, 117: 0x08, 118: 0x08, 120: 0x14, 123: 0x08, 127: 0x08, 133: 0x08,
                    134: 0x08, 135: 0x08, 136: 0x08, 137: 0x08}
DOORLOCAL = {1, 26, 27, 28, 31, 32, 33, 34, 117, 118}
DOORREMOTE = {2, 3, 16, 29, 42, 46, 61, 63, 75, 76, 86, 90, 99, 103, 105, 109, 112, 114, 115,
              133, 134, 135, 136, 137}
STAIRTYPES = {7, 8, 127}
# level RAM image size: GSU RAM $71:0000 up to RAMIMAGEEND (src/include/savegame.inc;
# engine_limits sets it)
RAMIMAGE = 0xACC0
# sector specials that only light or hurt: two such sectors with the same special can be one
# (not 9 secret, which is counted per sector, nor 10/14, the timed doors)
SAMESPECIAL = {0, 1, 2, 3, 4, 5, 7, 8, 11, 12, 13, 16, 17}

FLOORCODE = {5: 'LIC', 9: 'DONUT', 14: 'F32', 18: 'NHEF', 19: 'HEF', 20: 'NHEF', 22: 'NHEF',
             23: 'LEF', 30: 'F64', 36: 'HEF8', 37: 'LEF', 38: 'LEF', 45: 'HEF', 56: 'LIC8', 58: 'F24',
             59: 'F24', 60: 'LEF', 65: 'LIC8', 70: 'HEF8', 71: 'HEF8', 82: 'LEF', 83: 'LEF',
             91: 'LIC', 98: 'HEF8', 101: 'LIC', 102: 'HEF'}
LIFTCODE = {10: 'LIFT', 21: 'LIFT', 62: 'LIFT', 88: 'LIFT', 120: 'LIFT', 121: 'LIFT', 122: 'LIFT',
            123: 'LIFT', 87: 'MOVING', 89: 'MOVING'}
CEILINGCODE = {25, 44, 73, 74, 77}
TASKSPECIALS = {1, 2, 3, 4, 8, 12, 13, 17}           # sector types with a task (rlsectors.asm)
LIGHTTASKS = 40                                       # of the 48 task slots


def engine_line_types(srcdir):
    """line types the engine runs: the use (rluse2.asm _RLUseCode) and walk
    (rlmove7.asm _RLTriggerCode) jumptables"""
    import re
    out = set()
    for fn, lab in (('rluse2.asm', '_RLUseCode:'), ('rlmove7.asm', '_RLTriggerCode:')):
        txt = open(os.path.join(srcdir, fn)).read().split('\n')
        i = txt.index(lab) + 1
        n = 0
        while i < len(txt):
            t = txt[i].strip()
            i += 1
            if t.startswith(';') or not t:
                if n and not t:
                    break
                continue
            m = re.match(r'dw\s+(\S+)', t)
            if not m:
                break
            if m.group(1) != '0':
                out.add(n)
            n += 1
    return out


# THINGS priority groups (SortTHINGS)
PRIORITY = [
    [1, 2, 3, 4, 11, 14],
    [3004, 9, 3001, 3002, 58, 3005, 3006, 3003, 16, 7, 65, 84, 69, 68, 67, 66, 71, 64, 72, 88, 89, 87],
    [2001, 2005, 2002, 2003, 2004, 2006, 82],
    [13, 5, 6, 38, 39, 40],
    [2013, 2022, 2023, 2024, 2025, 2026, 2045],
    [2011, 2012, 2014, 2015, 2018, 2019, 8, 2007, 2048, 2008, 2049, 2010, 2046, 2047, 17],
    [2028, 34, 35, 48, 43, 54, 47, 41, 42, 55, 56, 57, 44, 45, 46],
    [2035, 10, 12, 15, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 36, 37,
     49, 63, 50, 59, 51, 61, 52, 60, 53, 62],
]

# WAD THING type -> (RIPDOOM RL object number, RL flags); flags $0100 = angular.
# The engine numbers objects by the order of the RL numbers (RIPDOOM's
# "reduced" types), FX3 inserts the Spectre (58) after the Demon.
THINGS = {
    1: (1, 0x01e8), 2: (2, 0x01f8), 3: (3, 0x01f8), 4: (4, 0x01f8), 11: (5, 0x01f8), 14: (7, 0x0100),
    3004: (10, 0xe8), 9: (11, 0xe8), 3001: (12, 0xe8), 3002: (13, 0xe8), 58: ('SPECTRE', 0xe8),
    3005: (14, 0xe8), 3006: (15, 0xe8), 3003: (16, 0xe8), 16: (17, 0xe8), 7: (18, 0xe8),
    65: ('CHAINGUY', 0xe8), 84: ('WOLFSS', 0xe8), 69: ('KNIGHT', 0xe8),     # (DOOM II monsters)
    68: ('ARACHNO', 0xe8), 67: ('MANCUBUS', 0xe8), 66: ('REVENANT', 0xe8), 71: ('PAINELEM', 0xe8),
    64: ('ARCHVILE', 0xe8), 72: ('KEEN', 0xe8), 88: ('BRAIN', 0xe8),
    89: ('SHOOTER', 0x40), 87: ('SPOT', 0x40),       # (MAP30: movable, not drawn, not solid)
    82: ('SSG', 0x80),                                # (DOOM II super shotgun)
    2001: (20, 0x80), 2005: (21, 0x80), 2002: (22, 0x80), 2003: (23, 0x80), 2004: (24, 0x80),
    2006: (25, 0x80),
    13: (30, 0x80), 5: (31, 0x80), 6: (32, 0x80), 38: (33, 0x80), 39: (34, 0x80), 40: (35, 0x80),
    8: (40, 0x80), 2007: (41, 0x80), 2048: (42, 0x80), 2008: (43, 0x80), 2049: (44, 0x80),
    2010: (45, 0x80), 2046: (46, 0x80), 2047: (47, 0x80), 17: (48, 0x80),
    2011: (50, 0x80), 2012: (51, 0x80), 2014: (52, 0x80), 2015: (53, 0x80), 2018: (54, 0x80),
    2019: (55, 0x80),
    2013: (60, 0x80), 2022: (61, 0x80), 2023: (62, 0x80), 2024: (63, 0x80), 2025: (64, 0x80),
    2026: (65, 0x80), 2045: (66, 0x80),
    2035: (70, 0xa8), 2028: (71, 0x88), 10: (72, 0x80), 12: (72, 0x80), 15: (72, 0x80),
    18: (72, 0x80), 19: (72, 0x80), 20: (73, 0x80), 21: (74, 0x80), 27: (75, 0x88), 28: (75, 0x88),
    30: (76, 0x88), 31: (76, 0x88), 32: (76, 0x88), 33: (76, 0x88), 34: (77, 0x80), 35: (78, 0x88),
    36: (76, 0x88), 37: (76, 0x88), 42: (79, 0x88), 43: (80, 0x88), 44: (81, 0x88), 45: (81, 0x88),
    46: (81, 0x88), 47: (82, 0x88), 48: (83, 0x88), 54: (80, 0x88), 55: (84, 0x88), 56: (84, 0x88),
    57: (84, 0x88),
}
# DOOM II things -> the nearest DOOM thing, for the engine without the DOOM II monsters
# (!RLDOOM2MONSTERS: those in DOOM2_TYPES keep their own type); without them Commander
# Keen and the MAP30 boss brain/shooter/spawn spots have no object and are dropped
DOOM2_SUBST = {
    65: 9,          # chaingunner -> shotgun guy
    84: 3004,       # Wolfenstein SS -> zombieman
    69: 3003,       # hell knight -> baron
    66: 3001,       # revenant -> imp
    67: 3003,       # mancubus -> baron
    68: 3005,       # arachnotron -> cacodemon
    71: 3005,       # pain elemental -> cacodemon
    64: 3003,       # arch-vile -> baron
    82: 2001,       # super shotgun -> shotgun
    83: 2013,       # megasphere -> soulsphere
    85: 2028, 86: 2028,     # tall/short techno lamp -> floor lamp
}
DOOM2_NAMES = {65: 'chaingunner', 84: 'SS', 69: 'hell knight', 66: 'revenant', 67: 'mancubus',
               68: 'arachnotron', 71: 'pain elemental', 64: 'arch-vile', 82: 'super shotgun',
               83: 'megasphere', 85: 'tall lamp', 86: 'short lamp'}
# (WAD thing types not in THINGS, the SNES object set (RIPDOOM discards them):
#  22 23 24 25 26 29 41 49-53 59-63)
# engine object order (rlobjects.inc) of the RL object numbers
RLORDER = [1, 2, 3, 4, 5, 7, 10, 11, 12, 13, 'SPECTRE', 14, 15, 16, 17, 18,
           'CHAINGUY', 'WOLFSS', 'KNIGHT', 'ARACHNO', 'MANCUBUS', 'REVENANT', 'PAINELEM', 'ARCHVILE',
           'KEEN', 'BRAIN', 'SHOOTER', 'SPOT', 20, 21, 22, 23, 24, 25, 'SSG',
           30, 31, 32, 33, 34, 35, 40, 41, 42, 43, 44, 45, 46, 47, 48, 50, 51, 52, 53, 54, 55,
           60, 61, 62, 63, 64, 65, 66, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84]


DOOM2_TYPES = {'CHAINGUY': 65, 'WOLFSS': 84, 'KNIGHT': 69, 'ARACHNO': 68, 'MANCUBUS': 67, 'REVENANT': 66,
               'PAINELEM': 71, 'ARCHVILE': 64, 'KEEN': 72, 'BRAIN': 88, 'SHOOTER': 89, 'SPOT': 87,
               'SSG': 82}
DOOM2_MONSTERS = False      # the engine has the DOOM II monster types (levels.inc !RLDOOM2MONSTERS)


def object_types(rlobjects_inc=None, spectre=True, doom2=None):
    """RL object number -> engine object type (RIPDOOM's reduced numbering)"""
    doom2 = DOOM2_MONSTERS if doom2 is None else doom2
    order = [x for x in RLORDER if (spectre or x != 'SPECTRE') and (doom2 or x not in DOOM2_TYPES)]
    out = {x: i for i, x in enumerate(order)}
    if not spectre:
        out['SPECTRE'] = out[13]
    if rlobjects_inc:                       # cross-check the count with the engine
        n = 0
        skip = False
        for line in open(rlobjects_inc):
            t = line.split(';')[0].strip()
            if t.startswith('if !RLSPECTRE'):
                skip = not spectre
            elif t.startswith('if !RLDOOM2MONSTERS'):
                skip = not doom2
            elif t == 'endif':
                skip = False
            elif t.startswith('%otMAC(') and not skip:
                if t.startswith('%otMAC(otFireBall1'):
                    break
                n += 1
        assert n == len(order), 'engine has %d level object types, table %d' % (n, len(order))
    return out


# --------------------------------------------------------------------------
#   conversion
# --------------------------------------------------------------------------
def line_angle(dx, dy):
    """GetAngle: RIPDOOM's (double precision) line angle, rounded to $40"""
    if dx == 0:
        a = 0x4000 if dy >= 0 else 0xC000
    elif dy == 0:
        a = 0x0000 if dx >= 0 else 0x8000
    else:
        ax, ay = abs(dx), abs(dy)
        swap = ay > ax
        r = (ax / ay) if swap else (ay / ax)
        a = int(math.atan(r) * (1800000000 / 31415926) * (65536 / 360)) & 0xFFFF
        if swap:
            a = 0x4000 - a
        if dx >= 0:
            a = a if dy >= 0 else -a
        else:
            a = (0x8000 - a) if dy >= 0 else (0x8000 + a)
    a &= 0xFFFF
    return (((a + 32) & 0xFFFF) >> 6) << 6


class Converter:
    def __init__(self, m, tables, otypes, supported, vbase, sigs=None, pvs='compute',
                 pvs_budget=600):
        self.m = m
        self.t = tables
        self.ot = otypes
        self.vbase = vbase
        self.warnings = []
        self.unknown = Counter()
        self.missing = Counter()
        self.cleared = Counter()
        self.sigs = sigs
        self.alike = {}
        self.pvs = pvs
        self.pvs_budget = pvs_budget
        for l in m.lines:                   # FX3 clears what the engine can't run
            t = l['type']
            if t and t != 0xFFFF and t not in supported:
                self.cleared[t] += 1
                l['type'] = 0

    def warn(self, s):
        self.warnings.append(s)

    # ---- texture cross references
    def wall(self, name, used=True):
        """XREFTexture: returns (wall number, x offset translation)"""
        if name == '-' or name == '':
            return self.t.get('transparent', 2), None
        w = self.t['walls'].get(name)
        if w is None:
            w = self.lookalike('walls', name)
            if used:
                self.unknown['wall %s->%s' % (name, self.t['wallname'].get(str(w), w))] += 1
            return w, None
        return w, self.t.get('wallxoff', {}).get(name)

    def yfix(self, i, sd, far, need):
        """y offset change for a side whose drawn texture is stored padded to a power-of-two
        height (wall format 2: WAD rows (y - r0) mod H0 at row y of H) and pegged the other
        way than its layout: top pegged needs r0, bottom pegged r0 + H0 - H.  Only when every
        drawn part of the side agrees (a shift of the others' whole height is no change)."""
        yp = self.t.get('ypad')
        if not yp:
            return 0
        l = self.side_line.get(i)
        if l is None:
            return 0
        f = l['flags']
        parts = []
        if far < 0:
            parts.append((sd['mid'], 'bottom' if f & 0x10 else 'top'))
        else:
            if need.get('upper'):
                parts.append((sd['upper'], 'top' if f & 0x08 else 'bottom'))
            if need.get('lower'):
                parts.append((sd['lower'], 'top'))
        fix = set()
        others = []
        for nm, peg in parts:
            if self.t['walls'].get(nm) is None or self.t['wallname'].get(str(self.t['walls'][nm])) != nm:
                others.append(nm); continue           # shown as another texture: leave it
            if nm in yp:
                h0, h, r0 = yp[nm]
                fix.add((r0 if peg == 'top' else r0 + h0 - h) % h)
            else:
                others.append(nm)
        if len(fix) != 1:
            return 0
        d = fix.pop()
        wh = self.t.get('wallh', {})
        if any(d % wh.get(str(self.t['walls'].get(n)), 128) for n in others):
            return 0                                   # another texture on the side would move
        return d

    def lookalike(self, kind, name):
        """a name the FX3 levels never use: the known one that looks closest"""
        key = (kind, name)
        if key not in self.alike:
            sig = self.sigs.get(kind, {}).get(name) if self.sigs else None
            best, bd = None, None
            if sig is not None:
                known = self.t.get('sigs', {}).get(kind, {})
                for n, code in self.t[kind].items():
                    o = known.get(n)
                    if o is None:
                        continue
                    d = sum((a - b) ** 2 for a, b in zip(sig, o))
                    if bd is None or d < bd:
                        best, bd = n, d
            self.alike[key] = self.t[kind][best] if best else \
                self.t.get('walldefault' if kind == 'walls' else 'flatdefault', 0)
        return self.alike[key]

    def flat(self, name):
        """XREFTexture2"""
        if name == 'F_SKY1':
            return 0xFF
        c = self.t['flats'].get(name)
        if c is None:
            c = self.lookalike('flats', name)
            self.unknown['flat %s->%d' % (name, c)] += 1
        return c

    def vptr(self, v):
        return (v * 4 + self.vbase) & 0xFFFF

    # ---- RIPDOOM ConvertLevel order
    def run(self):
        m = self.m
        self.out = {}
        self.out['VERTEXES'] = m.raw['VERTEXES']
        self.conv_sectors()
        self.conv_lines()
        self.conv_nodes()
        self.conv_sides()
        self.conv_segs()
        self.conv_ssectors()
        self.conv_blockmap()
        self.conv_things()
        self.conv_doors()
        self.conv_stairs()
        self.conv_floors()
        self.conv_lifts()
        self.conv_ceilings()
        self.conv_reject()
        o = self.out
        o['LINES'] = bytes(self.rllines)
        o['SEGS'] = bytes(self.rlsegs)
        self.fit_ram_image()
        return o

    def fit_ram_image(self):
        """LINES, BLOCKMAP, OBJECTS (+$0000) and REJECT are copied to GSU RAM $71:0000
        and must end below RAMIMAGEEND (savegame.inc: the walls' band buffer follows).  If they do not,
        leave out the multiplayer-only objects (the engine never creates them); if still
        too big, REJECT stays in the GamePak ROM (self.rejrom: marker file REJROM), then
        the last (lowest priority) objects go."""
        o = self.out
        self.ramimage = 0
        self.rejrom = False
        size = lambda: len(o['LINES']) + len(o['BLOCKMAP']) + len(o['OBJECTS']) + 2 + \
            (0 if self.rejrom else len(o['REJECT']))
        if size() <= RAMIMAGE:
            return
        keep = [x for x in self.objects if not x[1] & 0x10]
        dropped = len(self.objects) - len(keep)
        o['OBJECTS'] = b''.join(e for e, f in keep)
        if size() > RAMIMAGE:
            # (this port) the visibility table (REJECT) to the GamePak ROM instead of the
            # RAM image (marker file REJROM: levels.inc, macros.inc EXMYMAC, rlenemies.asm)
            self.rejrom = True
            self.warn('level RAM image over %d bytes: the visibility table (REJECT, %d bytes) is '
                      'in the GamePak ROM' % (RAMIMAGE, len(o['REJECT'])))
        cut = 0
        while size() > RAMIMAGE and keep:
            keep.pop(); cut += 1
            o['OBJECTS'] = b''.join(e for e, f in keep)
        if dropped or cut:
            self.warn('level RAM image (LINES+BLOCKMAP+OBJECTS+REJECT) over %d bytes: %d multiplayer-only '
                      'objects%s left out' % (RAMIMAGE, dropped, ' and the last %d objects' % cut if cut else ''))
        self.ramimage = size()

    def lines_of_sector(self, s):
        """linedefs with a side in sector s (RIPDOOM scan order, left side first)"""
        m = self.m
        for i, l in enumerate(m.lines):
            if (l['left'] >= 0 and m.sec(l['left']) == s) or m.sec(l['right']) == s:
                yield i, l

    def conv_sectors(self):
        m = self.m
        out = bytearray()
        self.origins = []
        # every blinking/flickering/glowing sector runs a task from level start, and the
        # task table (MaxRLTasks = 48, rle.inc) is also what doors, lifts and floors use:
        # past LIGHTTASKS the light keeps its level but stops changing (TNT MAP08: 66)
        ntask = 0
        cut = 0
        for s, sc in enumerate(m.sectors):
            r = bytearray(RLS)
            sp = sc['special'] if sc['special'] <= 17 else 0          # (the engine's table ends at 17)
            if sp in TASKSPECIALS:
                if ntask >= LIGHTTASKS:
                    sp = 16 if sp == 4 else 0                      # (4: keep its damage)
                    cut += 1
                else:
                    ntask += 1
            r[0] = (sp << 2) & 0xFF
            r[9] = sc['tag'] & 0xFF
            struct.pack_into('<hh', r, 3, sc['floor'], sc['ceil'])
            r[1] = min(0xF7, (0xFF - (sc['light'] & 0xFF)) & 0xFF)
            # darkest neighbour
            far = 0
            for l in m.lines:
                if l['left'] < 0:
                    continue
                sl, sr = m.sec(l['left']), m.sec(l['right'])
                if sl == s:
                    o = sr
                elif sr == s:
                    o = sl
                else:
                    continue
                if o == s:
                    continue
                b = min(0xF7, (0xFF - (m.sectors[o]['light'] & 0xFF)) & 0xFF)
                if b > far:
                    far = b
            if far <= 1:
                far = 0xF7
            r[2] = far
            r[7] = self.flat(sc['ftex'])
            r[8] = self.flat(sc['ctex'])
            # sound origin: centre of the bounding box of its lines
            x0 = y0 = 0x7FFFFFFF
            x1 = y1 = -0x80000000
            for l in m.lines:
                if m.sec(l['right']) == s or (l['left'] >= 0 and m.sec(l['left']) == s):
                    for v in (l['v1'], l['v2']):
                        x, y = m.vertexes[v]
                        x0, x1, y0, y1 = min(x0, x), max(x1, x), min(y0, y), max(y1, y)
            if x0 > x1:
                self.origins.append((0, 0))
            else:
                self.origins.append((x0 + ((x1 - x0) >> 1), y0 + ((y1 - y0) >> 1)))
            out += r
        self.out['SECTORS'] = bytes(out)
        if cut:
            self.warn('%d light-effect sectors (more than %d tasks): their light stays steady' % (cut, LIGHTTASKS))

    def conv_lines(self):
        m = self.m
        out = bytearray()
        for i, l in enumerate(m.lines):
            r = bytearray(RLL)
            struct.pack_into('<HH', r, 0, self.vptr(l['v1']), self.vptr(l['v2']))
            (x1, y1), (x2, y2) = m.vertexes[l['v1']], m.vertexes[l['v2']]
            struct.pack_into('<H', r, 6, line_angle(x2 - x1, y2 - y1))
            f = l['flags']
            g = 0
            if not f & 4:
                g |= 0x01
            if f & 0x20:
                g |= 0x04
            if f & 0x80:
                g |= 0x20
            if f & 0x01:
                g |= 0x08
            r[4] = g
            g2 = 0
            if l['left'] >= 0:
                sl, sr = m.sectors[m.sec(l['left'])], m.sectors[m.sec(l['right'])]
                if sl['floor'] != sr['floor']:
                    g2 |= 1
                if sl['ceil'] != sr['ceil']:
                    g2 |= 2
            t = l['type']
            if t not in (0, 0xFFFF):
                if t in FX3LINETYPEFLAGS:
                    g2 |= FX3LINETYPEFLAGS[t]
                elif t < len(WADLINETYPEFLAGS):
                    g2 |= WADLINETYPEFLAGS[t]
                else:
                    self.warn('line %d: type %d has no RL meaning' % (i, t))
            r[5] = g2
            r[10] = t & 0xFF
            r[11] = l['tag'] & 0xFF
            out += r
        self.rllines = out

    def conv_nodes(self):
        n = self.m.nodes
        out = bytearray()
        for i in range(len(n) // 28):
            x, y, dx, dy, rt, rb, rl, rr, lt, lb, ll, lr, rc, lc = struct.unpack_from('<12h2H', n, i * 28)

            def child(c):
                return 0x8000 | ((c & 0x7FFF) * RLA) if c & 0x8000 else c * RLB
            out += struct.pack('<4h4hH4hH', y, dx, x, dy, lt, lb, ll, lr, child(lc) & 0xFFFF,
                               rt, rb, rl, rr, child(rc) & 0xFFFF)
        self.out['BSP'] = bytes(out)

    def conv_sides(self):
        m = self.m
        faces = bytearray()
        self.faceptr = []
        self.faceflags = []
        self.nmasked = 0
        rlsec = self.out['SECTORS']
        self.side_line = {}
        for l in m.lines:
            for k in ('right', 'left'):
                if l[k] >= 0:
                    self.side_line.setdefault(l[k], l)
        for i, sd in enumerate(m.sides):
            near = sd['sector']
            far = -1
            for l in m.lines:
                L, R = l['left'], l['right']
                if L == i:
                    o = R
                elif R == i:
                    o = L
                else:
                    continue
                if o == -1 or o == i:
                    continue
                far = m.sec(o)
                break
            f = bytearray(4 if far >= 0 else 2)
            f[0] = near & 0xFF
            if far >= 0:
                f[1] = far & 0xFF
            flags = 0
            xoff = 0
            # RIPDOOM resolves all three names (the last translation X offset
            # wins); a two-sided face keeps upper/lower, a one-sided one normal
            need = {'mid': True} if far < 0 else {}
            if far >= 0:
                me, ot = m.sectors[near], m.sectors[far]
                bothsky = me['ctex'] == 'F_SKY1' and ot['ctex'] == 'F_SKY1'
                need = {'lower': ot['floor'] > me['floor'], 'upper': ot['ceil'] < me['ceil'] and not bothsky}
            for slot, nm in (('mid', sd['mid']), ('lower', sd['lower']), ('upper', sd['upper'])):
                used = (slot == 'mid') == (far < 0)
                if nm in ('-', '') and (need.get(slot) or (far >= 0 and slot != 'mid')):
                    # a step with no texture (also one not drawn now: doors, lifts and floors
                    # move): PC DOOM leaves it undrawn (a HOM), the engine would draw the
                    # "transparent" wall number, a raw sky picture, as RLE strip data and
                    # lose its way in it (DOOM II MAP01 would hang).  Use the side's other
                    # texture or the other side's.
                    other = m.sides[o] if far >= 0 else {}
                    nm = next((x for x in (other.get(slot), sd['mid'], sd['upper'], sd['lower'],
                                           other.get('mid')) if x not in (None, '-', '')), nm)
                    if nm in ('-', ''):
                        nm = None
                    if need.get(slot):
                        self.missing[slot] += 1
                if nm is None:
                    nm = 'STARTAN2'
                w, xo = self.wall(nm, used)
                if xo is not None:
                    xoff = xo
                if slot == 'mid':
                    if far >= 0:
                        flags |= 1          # (cleared again by lower/upper)
                        f[2] = w & 0xFF
                    else:
                        f[1] = w & 0xFF
                    if nm.startswith('SW'):
                        flags |= 0x40
                elif far >= 0:
                    f[3 if slot == 'lower' else 2] = w & 0xFF
                    flags &= ~1
                    if nm.startswith('SW'):
                        flags |= 0x40 if slot == 'lower' else 0x20
            if rlsec[near * RLS + 8] == 0xFF and (far < 0 or rlsec[far * RLS + 8] == 0xFF):
                flags |= 2
            mk = self.t.get('masked', {}).get(sd['mid']) if far >= 0 else None
            if mk is not None:
                # masked middle texture (seg flag $08, rlvsegs4.asm _RLBuildMaskList): face bytes
                # 4 = MASKED.TBL index, 5 = y offset (signed: at most 127 up, 128 down)
                f += bytes([mk, max(-128, min(127, sd['yoff'])) & 0xFF])
                flags |= 4
                self.nmasked += 1
            sd['xoff_rl'] = sd['xoff'] + xoff
            sd['yfix'] = self.yfix(i, sd, far, need)
            self.faceflags.append(flags)
            # deduplicate (byte search, may overlap the tail like RIPDOOM)
            n = len(f)
            full = faces + f
            p = full.find(f)
            if p == len(faces):
                faces += f
            else:
                if p + n > len(faces):
                    faces = full[:p + n]
            self.faceptr.append(p)
        self.out['FACES'] = bytes(faces)

    def conv_segs(self):
        m = self.m
        out = bytearray()
        for i, g in enumerate(m.segs):
            l = m.lines[g['line']]
            r = bytearray(RLG)
            struct.pack_into('<HH', r, 0, self.vptr(g['v1']), self.vptr(g['v2']))
            f = l['flags']
            fl = 0
            if not f & 4:
                fl |= 0x01
                if not f & 0x10:
                    fl |= 0x40
            else:
                if f & 0x08:
                    fl |= 0x20
                if f & 0x10:
                    fl |= 0x40
            sd = l['left'] if g['side'] else l['right']
            ff = self.faceflags[sd]
            if ff & 1:
                fl |= 0x08
            if ff & 2:
                fl |= 0x02
            if ff & 4:
                fl |= 0x08
            r[4] = fl
            face = self.faceptr[sd]
            struct.pack_into('<H', r, 7, face)
            if g['side'] == 0:
                struct.pack_into('<H', self.rllines, g['line'] * RLL + 8, face)
            s = m.sides[sd]
            r[5] = (g['offset'] + s['xoff_rl']) & 0xFF
            r[6] = (s['yoff'] + s.get('yfix', 0)) & 0xFF
            struct.pack_into('<H', r, 9, g['line'])
            out += r
        self.rlsegs = out

    def conv_ssectors(self):
        out = bytearray()
        faces = self.out['FACES']
        for n, first in self.m.ssectors:
            off = first * RLG
            face = struct.unpack_from('<H', self.rlsegs, off + 7)[0]
            out += struct.pack('<BHB', n & 0xFF, off & 0xFFFF, faces[face])
        self.out['AREAS'] = bytes(out)

    def conv_blockmap(self):
        b = self.m.blockmap
        x0, y0, nx, ny = struct.unpack_from('<hhHH', b, 0)
        nb = nx * ny
        hdr = struct.pack('<hhBB', x0, y0, nx & 0xFF, ny & 0xFF)
        offs = []
        lists = bytearray()
        base = 6 + 2 * nb                   # file offset of the line lists
        for k in range(nb):
            p = struct.unpack_from('<H', b, 8 + 2 * k)[0] * 2
            p += 2                          # skip the $0000 entry
            new = bytearray()
            while True:
                v = struct.unpack_from('<H', b, p)[0]
                p += 2
                new += struct.pack('<H', v)
                if v & 0x8000:
                    break
            slot = 6 + 2 * k
            full = lists + new
            q = full.find(new)
            if q == len(lists):
                lists += new
            offs.append((base + q) - slot - 1)
        self.out['BLOCKMAP'] = hdr + b''.join(struct.pack('<H', o & 0xFFFF) for o in offs) + bytes(lists)

    def conv_things(self):
        things = [dict(t) for t in self.m.things]
        order = []
        for grp in PRIORITY:
            while True:
                added = 0
                for typ in grp:
                    for t in things:
                        if t['type'] == typ and t['flags'] & 0x17:
                            order.append(dict(t))
                            t['type'] = 0
                            added += 1
                            break
                if not added:
                    break
        out = bytearray()
        self.objects = []                   # (bytes, DOOM flags) per entry, for fit_ram_image
        nm = nf = 0
        for t in order:
            e = THINGS.get(t['type'])
            if e is None or e[0] not in self.ot:    # (DOOM II things without DOOM II monsters)
                continue
            rl, fl = e
            e = struct.pack('<BBhh', (t['flags'] & 0x17) | (fl & 0xFF), self.ot[rl], t['x'], t['y'])
            if fl & 0x100:
                a = (((t['angle'] & 0xFFFF) * 182) & 0xFFFF)
                a = ((a + 0x1000) & 0xFFFF) & 0xE000
                e += struct.pack('<H', a)
            out += e
            self.objects.append((e, t['flags']))
            if fl & 0x40:
                nm += 1
            else:
                nf += 1
        self.nmobj, self.nfobj = nm, nf
        self.out['OBJECTS'] = bytes(out)

    # ---- specials
    def mark_door_segs(self, li):
        for i, g in enumerate(self.m.segs):
            if g['line'] == li:
                self.rlsegs[i * RLG + 4] |= 0x04

    def door(self, out, s):
        m = self.m
        p = 0
        while p < len(out):
            if out[p] == (s & 0xFF):
                return
            p += 8 + 2 * out[p + 7]
        rec = bytearray(8)
        rec[0] = s & 0xFF
        ox, oy = self.origins[s]
        struct.pack_into('<hh', rec, 3, ox, oy)
        lines = []
        maxc = 0x7FFFFFFF
        for i, l in self.lines_of_sector(s):
            lines.append(i)
            self.rllines[i * RLL + 4] |= 0x10
            if l['left'] < 0:
                continue
            o = m.sec(l['right']) if m.sec(l['left']) == s else m.sec(l['left'])
            c = m.sectors[o]['ceil']
            if c < maxc:
                maxc = c
            self.mark_door_segs(i)
        if not lines:
            return
        rec[7] = len(lines) & 0xFF
        struct.pack_into('<H', rec, 1, (maxc - 4) & 0xFFFF)
        for i in lines:
            rec += struct.pack('<H', i)
        out += rec

    def conv_doors(self):
        m = self.m
        out = bytearray()
        for l in m.lines:
            t = l['type']
            if t not in DOORLOCAL and t not in DOORREMOTE:
                continue
            if t in DOORLOCAL:
                if l['left'] < 0:
                    continue
                self.door(out, m.sec(l['left']))
            else:
                if l['tag'] == 0:
                    continue
                for s, sc in enumerate(m.sectors):
                    if sc['tag'] == l['tag']:
                        self.door(out, s)
        for x in self.boss_specials():          # (MAP32: Keen's doors, E4M6: the Cyberdemon's)
            if x['type'] == 0:
                for s, sc in enumerate(m.sectors):
                    if sc['tag'] == x['tag']:
                        self.door(out, s)
        self.out['DOORS'] = bytes(out)

    def conv_stairs(self):
        m = self.m
        out = bytearray()
        for l in m.lines:
            if l['type'] not in STAIRTYPES or l['tag'] == 0:
                continue
            first = next((s for s, sc in enumerate(m.sectors) if sc['tag'] == l['tag']), None)
            if first is None:
                continue
            base = m.sectors[first]
            ox, oy = self.origins[first]
            rec = bytearray(struct.pack('<Bhhh', l['tag'] & 0xFF, ox, oy, base['floor']))
            secs = []
            s = first
            while True:
                secs.append(s)
                nxt = None
                for k in m.lines:
                    if m.sec(k['right']) == s and k['left'] >= 0:
                        n = m.sec(k['left'])
                        if m.sectors[n]['rawftex'] == base['rawftex']:
                            nxt = n
                            break
                if nxt is None or nxt in secs:
                    if nxt is not None:
                        self.warn('stairs at tag %d loop (RIPDOOM would hang)' % l['tag'])
                    break
                s = nxt
            rec += bytes([len(secs) & 0xFF]) + bytes(x & 0xFF for x in secs)
            out += rec
        self.out['STAIRS'] = bytes(out)

    def neighbours(self, s):
        """(opposite sector) for each two-sided line of s, RIPDOOM order"""
        m = self.m
        for l in m.lines:
            if l['left'] < 0:
                continue
            if m.sec(l['left']) == s:
                yield m.sec(l['right'])
            elif m.sec(l['right']) == s:
                yield m.sec(l['left'])

    def height(self, code, s):
        """returns (height, model sector)"""
        m = self.m
        sc = m.sectors
        model = s
        if code in ('F24', 'F32', 'F64'):
            return sc[s]['floor'] + int(code[1:]), s
        if code in ('HEF', 'HEF8'):
            h = -0x80000000
            for o in self.neighbours(s):
                if sc[o]['floor'] > h:
                    h, model = sc[o]['floor'], o
            return h + (8 if code == 'HEF8' else 0), model
        if code == 'LEF':
            h = 0x7FFFFFFF
            for o in self.neighbours(s):
                if sc[o]['floor'] <= h:
                    h, model = sc[o]['floor'], o
            return h, model
        if code == 'NHEF':
            cur, h = sc[s]['floor'], 0x7FFFFFFF
            for o in self.neighbours(s):
                f = sc[o]['floor']
                if f <= h and f > cur:
                    h, model = f, o
            return h, model
        if code in ('LIC', 'LIC8'):
            h = sc[s]['ceil']
            for o in self.neighbours(s):
                if sc[o]['ceil'] <= h:
                    h, model = sc[o]['ceil'], o
            return h - (8 if code == 'LIC8' else 0), model
        if code == 'LIF':
            h = sc[s]['floor']
            for o in self.neighbours(s):
                if sc[o]['floor'] <= h:
                    h, model = sc[o]['floor'], o
            return h, model
        if code == 'HIF':
            h = sc[s]['floor']
            for o in self.neighbours(s):
                if sc[o]['floor'] > h:
                    h, model = sc[o]['floor'], o
            return h, model
        if code == 'DONUT':
            h, model = self.height('NHEF', s - 1)
            return h, model
        raise ValueError(code)

    def boss_specials(self):
        """PC A_BossDeath/A_KeenDie as (tag, line type) pseudo lines: DOOM II MAP07's mancubi
        (666: lower floor), arachnotrons (667: raise), MAP32's Keens (666: open doors, type 0);
        DOOM E4M6's Cyberdemon (666: open doors), E4M8's Spider Mastermind (666: lower floor);
        the engine (rlmobjects2.asm _RLMAD2Boss) runs them on the last one's death"""
        types = {t['type'] for t in self.m.things}
        tags = {sc['tag'] for sc in self.m.sectors}
        out = []
        if not DOOM2_MONSTERS:
            if self.m.name == 'E4M6' and 16 in types and 666 in tags:
                out.append(dict(type=0, tag=666))
            if self.m.name == 'E4M8' and 7 in types and 666 in tags:
                out.append(dict(type=38, tag=666))
            return out
        if 67 in types and 666 in tags:
            out.append(dict(type=38, tag=666))
        if 68 in types and 667 in tags:
            out.append(dict(type=30, tag=667))
        if 72 in types and 666 in tags:
            out.append(dict(type=0, tag=666))
        return out

    def conv_floors(self):
        m = self.m
        out = bytearray()
        seen = set()
        for l in m.lines + [x for x in self.boss_specials() if x['type']]:
            t = l['type']
            if t & 0x8000 or t not in FLOORCODE or l['tag'] == 0:
                continue
            key = (l['tag'] & 0xFF, t & 0xFF)
            if key in seen:
                continue
            seen.add(key)
            code = FLOORCODE[t]
            rec = bytearray([key[0], key[1], 0])
            ents = []
            for s, sc in enumerate(m.sectors):
                if sc['tag'] != l['tag']:
                    continue
                h, model = self.height(code, s)
                ox, oy = self.origins[s]
                ents.append(struct.pack('<BHhhB', s & 0xFF, h & 0xFFFF, ox, oy, model & 0xFF))
            if code == 'DONUT' and ents:
                e = bytearray(ents[0])
                e[0] = (e[0] - 1) & 0xFF
                ents.append(bytes(e))
            rec[2] = len(ents) & 0xFF
            out += rec + b''.join(ents)
        self.out['FLOORS'] = bytes(out)

    def conv_lifts(self):
        m = self.m
        out = bytearray()
        seen = set()
        for l in m.lines:
            t = l['type']
            if t & 0x8000 or t not in LIFTCODE or l['tag'] == 0:
                continue
            key = (l['tag'] & 0xFF, t & 0xFF)
            if key in seen:
                continue
            seen.add(key)
            rec = bytearray([key[0], key[1], 0])
            n = 0
            for s, sc in enumerate(m.sectors):
                if sc['tag'] != l['tag']:
                    continue
                lo = self.height('LIF', s)[0]
                hi = sc['floor'] if LIFTCODE[t] == 'LIFT' else self.height('HIF', s)[0]
                ox, oy = self.origins[s]
                rec += struct.pack('<BHHhh', s & 0xFF, lo & 0xFFFF, hi & 0xFFFF, ox, oy)
                n += 1
            rec[2] = n & 0xFF
            out += rec
        self.out['LIFTS'] = bytes(out)

    def conv_ceilings(self):
        m = self.m
        out = bytearray()
        seen = set()
        for l in m.lines:
            t = l['type']
            if t not in CEILINGCODE or l['tag'] == 0:
                continue
            key = (l['tag'] & 0xFF, t & 0xFF)
            if key in seen:
                continue
            seen.add(key)
            rec = bytearray([key[0], key[1], 0])
            n = 0
            for s, sc in enumerate(m.sectors):
                if sc['tag'] != l['tag']:
                    continue
                ox, oy = self.origins[s]
                lines = [i for i, _ in self.lines_of_sector(s)]
                rec += struct.pack('<BhhhB', s & 0xFF, sc['ceil'], ox, oy, len(lines) & 0xFF)
                rec += b''.join(struct.pack('<H', i) for i in lines)
                n += 1
            rec[2] = n & 0xFF
            out += rec
        self.out['CEILINGS'] = bytes(out)

    def conv_reject(self):
        """FX3 REJECT rows (bit set = can see): computed (rlpvs.py) or the WAD's"""
        n = len(self.m.sectors)
        if self.pvs == 'compute':
            import rlpvs
            try:
                vis = rlpvs.compute(self.m, budget=self.pvs_budget)
                self.out['REJECT'] = rlpvs.to_rows(vis, n)
                self.pvsinfo = 'computed'
                return
            except TimeoutError as e:
                self.warn('%s: using the WAD REJECT' % e)
        self.pvsinfo = 'WAD REJECT'
        rej = self.m.reject
        rb = (n + 7) >> 3
        out = bytearray(n * rb)
        for a in range(n):
            for b in range(n):
                k = a * n + b
                blocked = (k >> 3) < len(rej) and rej[k >> 3] >> (k & 7) & 1
                if not blocked or a == b:
                    out[a * rb + (b >> 3)] |= 1 << (b & 7)
        self.out['REJECT'] = bytes(out)

    def most_visible(self):
        """(sectors visible from the sector that sees most, that sector): an upper
        bound of the engine's visible sector list (MaxRLVSectors) in that sector"""
        n = len(self.m.sectors)
        rb = (n + 7) >> 3
        rej = self.out['REJECT']
        return max((sum(bin(b).count('1') for b in rej[s * rb:(s + 1) * rb]), s) for s in range(n))


# --------------------------------------------------------------------------
#   learning the FX3 wall / floor tables from FX3 levels
# --------------------------------------------------------------------------
def read_ref(refdir, lv):
    return {k: open(os.path.join(refdir, lv, k), 'rb').read() for k in LUMPS}


def ref_seg_keys(R, vbase):
    """FX3 segs keyed by their vertex coordinates"""
    V = list(struct.iter_unpack('<hh', R['VERTEXES']))
    out = defaultdict(list)
    for i in range(len(R['SEGS']) // RLG):
        a, b = struct.unpack_from('<HH', R['SEGS'], i * RLG)
        out[(V[(a - vbase) // 4], V[(b - vbase) // 4])].append(i)
    return out


def learn(wad, refdir, vbase, maps):
    votes = defaultdict(Counter)
    fvotes = defaultdict(Counter)
    xvotes = defaultdict(Counter)
    for lv in maps:
        try:
            m = wad.map(lv)
        except KeyError:
            continue
        R = read_ref(refdir, lv)
        keys = ref_seg_keys(R, vbase)
        F, S = R['FACES'], R['SECTORS']
        for g in m.segs:
            k = (m.vertexes[g['v1']], m.vertexes[g['v2']])
            if k not in keys:
                continue
            i = keys[k][0]
            l = m.lines[g['line']]
            sd = m.sides[l['left'] if g['side'] else l['right']]
            fl, xo, yo, face = struct.unpack_from('<BBBH', R['SEGS'], i * RLG + 4)
            if fl & 1:
                if face + 2 <= len(F):
                    votes[sd['mid']][F[face + 1]] += 1
                    xvotes[sd['mid']][(xo - g['offset'] - sd['xoff']) & 0xFF] += 1
            else:
                if face + 4 <= len(F):
                    if sd['upper'] != '-':
                        votes[sd['upper']][F[face + 2]] += 1
                    if sd['lower'] != '-':
                        votes[sd['lower']][F[face + 3]] += 1
            # sector colours: the FX3 near sector of this face
            if face < len(F):
                rs = F[face]
                if rs * RLS + RLS <= len(S):
                    sc = m.sectors[sd['sector']]
                    fvotes[sc['ftex']][S[rs * RLS + 7]] += 1
                    fvotes[sc['ctex']][S[rs * RLS + 8]] += 1
    walls = {n: c.most_common(1)[0][0] for n, c in votes.items() if n not in ('-', '')}
    flats = {n: c.most_common(1)[0][0] for n, c in fvotes.items() if n != 'F_SKY1'}
    wallxoff = {}
    for n, c in xvotes.items():
        d, k = c.most_common(1)[0]
        if d and k >= 2:
            wallxoff[n] = d if d < 128 else d - 256
    conf = {n: '%d/%d' % (c.most_common(1)[0][1], sum(c.values())) for n, c in votes.items()}
    names = defaultdict(Counter)
    for n, c in votes.items():
        for code, k in c.items():
            names[code][n] += k
    sigs = signatures(wad)
    return {'walls': walls, 'flats': flats, 'wallxoff': wallxoff, 'transparent': 2,
            'walldefault': 2, 'flatdefault': 0, 'confidence': conf,
            'wallname': {str(k): c.most_common(1)[0][0] for k, c in names.items()},
            'sigs': {'walls': {n: [round(v, 1) for v in sigs['walls'][n]] for n in walls if n in sigs['walls']},
                     'flats': {n: [round(v, 1) for v in sigs['flats'][n]] for n in flats if n in sigs['flats']}}}


# --------------------------------------------------------------------------
#   finalize a level directory (levels.inc limits, vertex base)
# --------------------------------------------------------------------------
SECTORDATA = 0x3080                 # _RLSectorData (GSU RAM bank $70)
RLOSIZE, RLOSIZE0 = 38, 8           # movable / fixed object size (rle.inc rloSize, rloSize0)


MOBJ_MIN, MOBJ_MAX, MOBJ_SPARE = 116, 300, 16   # rle.inc MaxRLMObjects range, slots kept for projectiles


def vertex_base(nsectors, nmobjects, srcdir=None):
    """_RLVertexes: sector data, then the movable and fixed object tables
    (rlram7.asm asserts the same formula)"""
    import re
    txt = open(os.path.join(srcdir or os.path.join(HERE, '..', 'src'), 'include', 'rle.inc')).read()
    nf = int(re.search(r'^\s*MaxRLFObjects\s*=\s*(\d+)', txt, re.M).group(1))
    return SECTORDATA + nsectors * RLSD + nmobjects * RLOSIZE + nf * RLOSIZE0


def movable_objects(objects):
    """the most movable objects one skill (single player) creates from a
    level's OBJECTS: flags $40, skill bits 1/2/4, not multiplayer ($10)"""
    best = 0
    for bit in (1, 2, 4):
        n = a = 0
        while a + 6 <= len(objects):
            f, t = objects[a], objects[a + 1]
            if f & 0x40 and f & bit and not f & 0x10:
                n += 1
            a += 8 if t <= 5 else 6         # angular types (players, teleport spots) have an angle
        best = max(best, n)
    return best


def mobject_slots(nmax):
    """MaxRLMObjects for a data set whose largest level creates NMAX movable objects"""
    return min(MOBJ_MAX, max(MOBJ_MIN, nmax + MOBJ_SPARE))


def finalize(d, log=print):
    """recompute !RLMAX... (with !RLMAXMOBJECTS) and !RLVERTEXBASE in DIR/levels.inc and
    the sizes in levels.json from the level files; rebase every level's vertex pointers
    when the base moves"""
    import re
    inc = os.path.join(d, 'levels.inc')
    txt = open(inc).read()
    names = re.findall(r'^!lvl(\d+) = (\w+)$', txt, re.M)
    lv = [n for _, n in sorted(names, key=lambda x: int(x[0]))]
    unused = set(re.findall(r'^!use(\w+) #= 0', txt, re.M))     # slots left out of the ROM
    lv = [n for n in lv if n not in unused]
    size = lambda n, k: os.path.getsize(os.path.join(d, n, k))
    nv = max(size(n, 'VERTEXES') // 4 for n in lv)
    ns = max(size(n, 'SECTORS') // RLS for n in lv)
    nl = max(size(n, 'LINES') // RLL for n in lv)
    mo = {n: movable_objects(open(os.path.join(d, n, 'OBJECTS'), 'rb').read()) for n in lv}
    worst = max(lv, key=lambda n: mo[n])
    nm = mobject_slots(mo[worst])
    if mo[worst] + MOBJ_SPARE > MOBJ_MAX:
        log('%s: %d movable objects on one skill, the engine has room for %d (the last ones are left out)' % (
            worst, mo[worst], MOBJ_MAX - MOBJ_SPARE))
    old = int(re.search(r'^!RLVERTEXBASE = \$([0-9A-Fa-f]+)', txt, re.M).group(1), 16)
    new = vertex_base(ns, nm)
    if new != old:
        for n in lv:
            for k, sz in (('LINES', RLL), ('SEGS', RLG)):
                fn = os.path.join(d, n, k)
                b = bytearray(open(fn, 'rb').read())
                for o in range(0, len(b), sz):
                    for f in (0, 2):
                        v = struct.unpack_from('<H', b, o + f)[0] - old
                        assert v % 4 == 0 and 0 <= v < nv * 4, (n, k, o, hex(old))
                        struct.pack_into('<H', b, o + f, v + new)
                open(fn, 'wb').write(bytes(b))
        log('vertex base $%04X -> $%04X (max %d sectors)' % (old, new, ns))
    txt = re.sub(r'^!RLVERTEXBASE = \$[0-9A-Fa-f]+', '!RLVERTEXBASE = $%04X' % new, txt, flags=re.M)
    txt = re.sub(r'^!RLMAXVERTEXES = \d+', '!RLMAXVERTEXES = %d' % nv, txt, flags=re.M)
    txt = re.sub(r'^!RLMAXSECTORS = \d+', '!RLMAXSECTORS = %d' % ns, txt, flags=re.M)
    txt = re.sub(r'^!RLMAXLINES = \d+', '!RLMAXLINES = %d' % ((nl + 1) & ~1), txt, flags=re.M)
    line = '!RLMAXMOBJECTS = %d\t; movable object slots: %s has %d on one skill, +%d for projectiles' % (
        nm, worst, mo[worst], MOBJ_SPARE)
    if re.search(r'^!RLMAXMOBJECTS = ', txt, re.M):
        txt = re.sub(r'^!RLMAXMOBJECTS = .*$', line, txt, flags=re.M)
    else:
        txt = re.sub(r'^(!RLMAXLINES = .*)$', lambda m_: m_.group(1) + '\n' + line, txt, flags=re.M)
    open(inc, 'w').write(txt)
    js = os.path.join(d, 'levels.json')
    info = json.load(open(js)) if os.path.exists(js) else {'levels': []}
    by = {x['name']: x for x in info['levels']}
    for n in lv:
        e = by.setdefault(n, {'name': n})
        e.update(vertexes=size(n, 'VERTEXES') // 4, lines=size(n, 'LINES') // RLL,
                 segs=size(n, 'SEGS') // RLG, sectors=size(n, 'SECTORS') // RLS,
                 sizes={k: size(n, k) for k in LUMPS})
    info['levels'] = [by[n] for n in lv] + [x for x in info['levels'] if x['name'] not in lv]
    json.dump(info, open(js, 'w'), indent=1)
    log('levels.inc: max %d vertexes, %d sectors, %d lines, %d movable object slots' % (nv, ns, nl, nm))


# --------------------------------------------------------------------------
#   limits
# --------------------------------------------------------------------------
# defaults; engine_limits() sets all but 'sectors' (sector numbers are bytes) from the engine
LIMITS = {'sectors': 255, 'nodes': 960, 'areas': 960, 'movable': 100, 'fixed': 180, 'vsectors': 127}


def engine_limits(srcdir):
    """LIMITS from rle.inc: MaxRLVisNodes/Areas, MaxRLFObjects, MaxRLVSectors
    (RAMIMAGE from savegame.inc RAMIMAGEEND);
    movable objects: the table is sized from the levels (finalize), up to MOBJ_MAX with
    MOBJ_SPARE kept for projectiles"""
    import re
    txt = open(os.path.join(srcdir, 'include', 'rle.inc')).read()
    get = lambda n: int(eval(re.search(r'^\s*%s\s*=\s*([-+*() \d]+)' % n, txt, re.M).group(1)))
    global RAMIMAGE
    m = re.search(r'^\s*RAMIMAGEEND\s*=\s*\$71([0-9A-Fa-f]{4})', open(os.path.join(srcdir, 'include', 'savegame.inc')).read(), re.M)
    RAMIMAGE = int(m.group(1), 16)
    LIMITS.update(nodes=get('MaxRLVisNodes'), areas=get('MaxRLVisAreas'),
                  movable=MOBJ_MAX - MOBJ_SPARE, fixed=get('MaxRLFObjects'),
                  vsectors=get('MaxRLVSectors'))


def check_limits(m, c):
    """problems that stop a map from working in the engine"""
    bad = []
    if len(m.sectors) > LIMITS['sectors']:
        bad.append('%d sectors (sector numbers are bytes and $FF ends DOORS, max %d)' % (len(m.sectors), LIMITS['sectors']))
    if len(m.nodes) // 28 > LIMITS['nodes']:
        bad.append('%d BSP nodes (max %d, MaxRLVisNodes)' % (len(m.nodes) // 28, LIMITS['nodes']))
    if len(m.ssectors) > LIMITS['areas']:
        bad.append('%d areas (max %d, MaxRLVisAreas)' % (len(m.ssectors), LIMITS['areas']))
    if c.ramimage > RAMIMAGE:
        bad.append('level RAM image %d bytes even without objects (max %d, RAMIMAGEEND)' % (c.ramimage, RAMIMAGE))
    return bad


def skill_counts(m):
    """(movable, fixed) objects per skill bit, single player"""
    out = {}
    for bit, nm in ((1, '1-2'), (2, '3'), (4, '4-5')):
        mv = fx = 0
        for t in m.things:
            e = THINGS.get(t['type'])
            if e is None or t['flags'] & 0x10 or not t['flags'] & bit:
                continue
            if e[1] & 0x40:
                mv += 1
            else:
                fx += 1
        out[nm] = (mv, fx)
    return out


def ref_vbase(d):
    import re
    return int(re.search(r'^!RLVERTEXBASE = \$([0-9A-Fa-f]+)', open(os.path.join(d, 'levels.inc')).read(),
                         re.M).group(1), 16)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('cmd', choices=['learn', 'convert', 'compare', 'finalize'])
    ap.add_argument('maps', nargs='*')
    ap.add_argument('--wad', action='append')
    ap.add_argument('--ref', default=os.path.join(HERE, '..', 'data', 'RLLEV'))
    ap.add_argument('--tables')
    ap.add_argument('--masked', help='MASKED.JSON (wall format 1, wad2gfx.py --masked): middle textures of '
                                     'two-sided lines drawn masked, name -> MASKED.TBL index')
    ap.add_argument('--walls', help='wall map of wall format 2/3 (RLDATA/WALLS/WALLMAP.JSON, wad2gfx.py --map-walls): '
                                    'texture names -> wall indexes, in place of the learned FX3 walls')
    ap.add_argument('--out')
    ap.add_argument('--vbase', type=lambda s: int(s, 0),
                    help="vertex pointer base (default: the output directory's levels.inc, else computed)")
    ap.add_argument('--pvs', choices=['compute', 'wad'], default='compute',
                    help='sector visibility: computed with portal flow (default) or the WAD REJECT')
    ap.add_argument('--pvs-budget', type=int, default=600, help='seconds per map before falling back to the WAD REJECT')
    ap.add_argument('--src', default=os.path.join(HERE, '..', 'src'), help='engine source (object and line types, limits)')
    a = ap.parse_args()
    if a.cmd == 'finalize':
        finalize(a.out)
        return
    wad = Wad(*a.wad)
    maps = a.maps or wad.maps()
    if a.cmd == 'learn':
        t = learn(wad, a.ref, ref_vbase(a.ref), [m for m in maps if os.path.isdir(os.path.join(a.ref, m))])
        json.dump(t, open(a.out, 'w'), indent=1, sort_keys=True)
        print('learned %d walls, %d flats, %d x offsets' % (len(t['walls']), len(t['flats']), len(t['wallxoff'])))
        return
    t = json.load(open(a.tables))
    if a.walls:
        wm = json.load(open(a.walls))
        t['walls'], t['wallxoff'], t['wallname'] = wm['walls'], {}, wm['wallname']
        t['transparent'], t['walldefault'] = wm['transparent'], wm['walldefault']
        t['masked'] = wm.get('masked', {})
        t['sigs'] = dict(t.get('sigs', {}), walls={})
        # textures padded to a power-of-two height: the layout (r0) suits one pegging,
        # the other gets its y offset moved (Converter.conv_sides)
        t['ypad'] = {x['name']: (x['h0'], x['h'], x['r0']) for x in wm['slots'] if x['h0'] & (x['h0'] - 1)}
        t['wallh'] = {str(t['walls'][x['name']]): x['h'] for x in wm['slots']}
    if a.masked:
        t['masked'] = json.load(open(a.masked))
    global DOOM2_MONSTERS
    inc = os.path.join(a.out or '', 'levels.inc')
    if os.path.exists(inc) and re.search(r'^!RLDOOM2MONSTERS\s*=\s*1', open(inc).read(), re.M):
        DOOM2_MONSTERS = True
    if a.vbase is None:
        inc = os.path.join(a.out or '', 'levels.inc')
        a.vbase = ref_vbase(a.out) if a.cmd == 'convert' and a.out and os.path.exists(inc) else \
            vertex_base(255, MOBJ_MIN, a.src)
    results = {}
    if a.cmd == 'compare':
        rvb = ref_vbase(a.ref)
    ot = object_types(os.path.join(a.src, 'include', 'rlobjects.inc'))
    supported = engine_line_types(os.path.join(a.src, 'engine'))
    engine_limits(a.src)
    sigs = signatures(wad)
    for spec in maps:
        src, lv = spec.split('=') if '=' in spec else (spec, spec)
        m = wad.map(src)
        merged = m.merge_sectors(LIMITS['sectors'])
        c = Converter(m, t, ot, supported, a.vbase, sigs, a.pvs, a.pvs_budget)
        o = c.run()
        if merged:
            c.warn('%d sectors: merged %d look-alike sectors that never change%s' % (
                len(m.sectors) + merged, merged, '' if not m.merge_light else
                ' (light differences up to %d merged)' % (m.merge_light - 1))
                   if merged > 0 else 'too many sectors even after merging (%d)' % -merged)
        bad = check_limits(m, c)
        if m.substituted:
            c.warn('DOOM II things: ' + ', '.join('%d %s' % (n, DOOM2_NAMES.get(a, a)) for (a, b), n in sorted(m.substituted.items()))
                   + ' as the nearest DOOM monster/item')
        nvis, vsec = c.most_visible()
        if nvis > LIMITS['vsectors']:
            c.warn('sector %d can see %d sectors: the engine lists %d (MaxRLVSectors), objects in the '
                   'farthest ones may not be drawn' % (vsec, nvis, LIMITS['vsectors']))
        for nm, (mv, fx) in skill_counts(m).items():
            if mv > LIMITS['movable'] or fx > LIMITS['fixed']:
                c.warn('skill %s: %d movable / %d fixed objects (max %d/%d): the last ones are left out' % (
                    nm, mv, fx, LIMITS['movable'], LIMITS['fixed']))
        if bad:
            print('%s: NOT CONVERTED: %s' % (lv, '; '.join(bad)))
            continue
        if a.cmd == 'convert':
            d = os.path.join(a.out, lv)
            os.makedirs(d, exist_ok=True)
            for k in LUMPS:
                open(os.path.join(d, k), 'wb').write(o[k])
            rj = os.path.join(d, 'REJROM')
            if getattr(c, 'rejrom', False):
                open(rj, 'wb').write(b'1')
            elif os.path.exists(rj):
                os.remove(rj)
            print('%s: %d vertexes %d lines %d segs %d sectors %d areas, %d objects (%d movable), '
                  'up to %d sectors visible%s' % (
                lv, len(m.vertexes), len(m.lines), len(m.segs), len(m.sectors), len(m.ssectors),
                c.nmobj + c.nfobj, c.nmobj, nvis, (', unknown: ' + ', '.join(sorted(c.unknown))) if c.unknown else ''))
        else:
            if not os.path.isdir(os.path.join(a.ref, lv)):
                continue
            R = read_ref(a.ref, lv)
            import rlcompare
            results[lv] = r = rlcompare.compare_level(o, R, a.vbase, rvb)
            print('%s: %s; identical: %s' % (lv, 'same geometry' if r['same_geometry'] else
                                             'SNES-edited geometry', ' '.join(r['identical'])))
            print('   lines %d/%d matched, segs %d/%d, sectors %d/%d (%d in ref), objects %d of %d (%d in ref)' % (
                r['lines_matched'][0], r['lines_matched'][1], r['segs_matched'][0], r['segs_matched'][1],
                r['sectors_matched'][0], r['sectors_matched'][1], r['sectors_matched'][2], *r['objects']))
            bad = ['%s %d/%d' % (k, ok, n) for k, (ok, n) in sorted(r['fields'].items()) if ok != n]
            if bad:
                print('   fields that differ: ' + ', '.join(bad))
            print('   specials (same/ours/ref): ' + ', '.join('%s %d/%d/%d' % ((k,) + r[k]) for k in
                                                           ('doors', 'stairs', 'floors', 'lifts', 'ceilings')))
            print('   visible sector pairs: both %d, only ours %d, only ref %d' % r['pvs'])
        if c.missing:
            print('   steps with no texture (given the side\'s other texture): %s' % ', '.join(
                '%d %s' % (v, k) for k, v in sorted(c.missing.items())))
        if c.cleared:
            print('   line types the engine does not run (cleared): %s' % ', '.join(
                '%d x%d' % kv for kv in sorted(c.cleared.items())))
        for w in c.warnings:
            print('   warning:', w)
    if a.cmd == 'convert' and os.path.exists(os.path.join(a.out, 'levels.inc')):
        finalize(a.out)
    if a.cmd == 'compare' and results:
        import rlcompare
        print('\nall levels, matched records that agree:')
        for k, (ok, n, p) in sorted(rlcompare.summary(results).items()):
            print('   %-28s %6d/%-6d %6.2f %%' % (k, ok, n, p))
        if a.out:
            json.dump(results, open(a.out, 'w'), indent=1, default=str)


if __name__ == '__main__':
    main()
