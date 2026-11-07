#!/usr/bin/env python3
"""
rlcompare.py - compare two sets of Reality Engine level data, field by field.

Used by `wad2rl.py compare` to measure the WAD converter against the levels of
a cartridge (FX3 / SNES DOOM).  The SNES team edited many maps (moved or
removed vertexes, cut areas, renumbered sectors), so records are matched by
geometry, not by index:

  * LINES and SEGS by the coordinates of their two vertexes
  * SECTORS through the matched SEGS (the sectors of their faces)
  * OBJECTS as a multiset of (flags, type, x, y, angle)
  * DOORS / STAIRS / FLOORS / LIFTS / CEILINGS as records with the sector
    numbers (and line numbers) translated through the matches

For every field it counts how many matched records agree.
"""
import struct
from collections import Counter, defaultdict

RLL, RLB, RLA, RLG, RLS = 12, 28, 4, 11, 10       # record sizes: line, BSP node, area, seg, sector


def u16(b, o):
    return b[o] | b[o + 1] << 8


class Level:
    def __init__(self, L, vbase):
        self.L = L
        V = [struct.unpack_from('<hh', L['VERTEXES'], 4 * i) for i in range(len(L['VERTEXES']) // 4)]
        self.V = V
        vx = lambda p: V[(p - vbase) // 4] if 0 <= (p - vbase) // 4 < len(V) else None
        self.lines = {}
        self.lineidx = {}
        for i in range(len(L['LINES']) // RLL):
            o = i * RLL
            k = (vx(u16(L['LINES'], o)), vx(u16(L['LINES'], o + 2)))
            self.lines[k] = o
            self.lineidx[i] = k
        self.segs = {}
        for i in range(len(L['SEGS']) // RLG):
            o = i * RLG
            k = (vx(u16(L['SEGS'], o)), vx(u16(L['SEGS'], o + 2)))
            self.segs.setdefault(k, o)
        self.nsec = len(L['SECTORS']) // RLS

    def face(self, segoff):
        F = self.L['FACES']
        p = u16(self.L['SEGS'], segoff + 7)
        solid = self.L['SEGS'][segoff + 4] & 1
        n = 2 if solid else 4
        return tuple(F[p:p + n]) if p + n <= len(F) else None


def objects(b):
    out = Counter()
    a = 0
    while a + 6 <= len(b):
        f, t, x, y = struct.unpack_from('<BBhh', b, a)
        a += 6
        ang = None
        if t <= 5:
            ang = u16(b, a)
            a += 2
        out[(f, t, x, y, ang)] += 1
    return out


def specials(L, kind):
    """decode a special list into records (sector numbers raw)"""
    b = L[kind]
    out = []
    a = 0
    try:
        if kind == 'DOORS':
            while a < len(b):
                s, mc, ox, oy, n = struct.unpack_from('<BhhhB', b, a)
                lines = [u16(b, a + 8 + 2 * k) for k in range(n)]
                out.append(('door', s, mc, ox, oy, tuple(lines)))
                a += 8 + 2 * n
        elif kind == 'STAIRS':
            while a < len(b):
                tag, ox, oy, h, n = struct.unpack_from('<BhhhB', b, a)
                out.append(('stairs', tag, ox, oy, h, tuple(b[a + 8:a + 8 + n])))
                a += 8 + n
        elif kind == 'FLOORS':
            while a < len(b):
                tag, typ, n = b[a], b[a + 1], b[a + 2]
                a += 3
                e = []
                for k in range(n):
                    e.append(struct.unpack_from('<BhhhB', b, a))
                    a += 8
                out.append(('floor', tag, typ, tuple(e)))
        elif kind == 'LIFTS':
            while a < len(b):
                tag, typ, n = b[a], b[a + 1], b[a + 2]
                a += 3
                e = []
                for k in range(n):
                    e.append(struct.unpack_from('<Bhhhh', b, a))
                    a += 9
                out.append(('lift', tag, typ, tuple(e)))
        elif kind == 'CEILINGS':
            while a < len(b):
                tag, typ, n = b[a], b[a + 1], b[a + 2]
                a += 3
                e = []
                for k in range(n):
                    s, h, ox, oy, nl = struct.unpack_from('<BhhhB', b, a)
                    e.append((s, h, ox, oy, tuple(u16(b, a + 8 + 2 * j) for j in range(nl))))
                    a += 8 + 2 * nl
                out.append(('ceiling', tag, typ, tuple(e)))
    except struct.error:
        pass
    return out


class Score:
    def __init__(self):
        self.c = defaultdict(lambda: [0, 0])

    def add(self, k, ok):
        self.c[k][0] += bool(ok)
        self.c[k][1] += 1

    def pct(self, k):
        a, n = self.c[k]
        return 100.0 * a / n if n else None


def compare_level(A, B, vbase_a, vbase_b):
    """A = converter output, B = reference (cartridge).  Returns a dict."""
    a, b = Level(A, vbase_a), Level(B, vbase_b)
    sc = Score()
    r = {'same_geometry': A['VERTEXES'] == B['VERTEXES'] and A['BSP'] == B['BSP'],
         'identical': [k for k in A if A[k] == B.get(k)],
         'counts': {k: (len(A[k]) // s, len(B[k]) // s) for k, s in
                    (('VERTEXES', 4), ('LINES', RLL), ('SEGS', RLG), ('SECTORS', RLS), ('BSP', RLB),
                     ('AREAS', RLA))}}
    # lines
    found = 0
    for k, oa in a.lines.items():
        ob = b.lines.get(k)
        if ob is None:
            continue
        found += 1
        la, lb = A['LINES'], B['LINES']
        sc.add('line flags', la[oa + 4] == lb[ob + 4])
        sc.add('line flags2', la[oa + 5] == lb[ob + 5])
        sc.add('line angle', la[oa + 6:oa + 8] == lb[ob + 6:ob + 8])
        sc.add('line type', la[oa + 10] == lb[ob + 10])
        sc.add('line tag', la[oa + 11] == lb[ob + 11])
    r['lines_matched'] = (found, len(a.lines), len(b.lines))
    # segs, faces, sector map
    secmap = defaultdict(Counter)
    found = 0
    for k, oa in a.segs.items():
        ob = b.segs.get(k)
        if ob is None:
            continue
        found += 1
        ga, gb = A['SEGS'], B['SEGS']
        sc.add('seg flags', ga[oa + 4] == gb[ob + 4])
        sc.add('seg x offset', ga[oa + 5] == gb[ob + 5])
        sc.add('seg y offset', ga[oa + 6] == gb[ob + 6])
        fa, fb = a.face(oa), b.face(ob)
        if fa and fb and len(fa) == len(fb):
            secmap[fa[0]][fb[0]] += 1
            if len(fa) == 4:
                secmap[fa[1]][fb[1]] += 1
                sc.add('wall texture (upper)', fa[2] == fb[2])
                sc.add('wall texture (lower)', fa[3] == fb[3])
            else:
                sc.add('wall texture (one-sided)', fa[1] == fb[1])
    r['segs_matched'] = (found, len(a.segs), len(b.segs))
    smap = {s: c.most_common(1)[0][0] for s, c in secmap.items()}
    # sectors
    SA, SB = A['SECTORS'], B['SECTORS']
    for s, t in smap.items():
        if s >= a.nsec or t >= b.nsec:
            continue
        pa, pb = s * RLS, t * RLS
        sc.add('sector type', SA[pa] == SB[pb])
        sc.add('sector light', SA[pa + 1] == SB[pb + 1])
        sc.add('sector light (neighbour)', SA[pa + 2] == SB[pb + 2])
        sc.add('sector heights', SA[pa + 3:pa + 7] == SB[pb + 3:pb + 7])
        sc.add('floor colour', SA[pa + 7] == SB[pb + 7])
        sc.add('ceiling colour', SA[pa + 8] == SB[pb + 8])
        sc.add('sector tag', SA[pa + 9] == SB[pb + 9])
    r['sectors_matched'] = (len(smap), a.nsec, b.nsec)
    # objects
    oa, ob = objects(A['OBJECTS']), objects(B['OBJECTS'])
    common = sum((oa & ob).values())
    r['objects'] = (common, sum(oa.values()), sum(ob.values()))
    # specials: translate sector numbers and line numbers of A into B's
    lmap = {}
    for i, k in a.lineidx.items():
        if k in b.lines:
            lmap[i] = b.lines[k] // RLL
    ms = lambda s: smap.get(s, ('?', s))
    ml = lambda l: lmap.get(l, ('?', l))
    for kind in ('DOORS', 'STAIRS', 'FLOORS', 'LIFTS', 'CEILINGS'):
        ra, rb = specials(A, kind), specials(B, kind)
        tr = []
        for x in ra:
            if x[0] == 'door':
                tr.append((x[0], ms(x[1]), x[2], x[3], x[4], tuple(sorted(map(ml, x[5]), key=str))))
            elif x[0] == 'stairs':
                tr.append(x[:5] + (tuple(map(ms, x[5])),))
            elif x[0] == 'ceiling':
                tr.append(x[:3] + (tuple((ms(e[0]),) + e[1:4] + (tuple(sorted(map(ml, e[4]), key=str)),)
                                         for e in x[3]),))
            elif x[0] == 'floor':
                tr.append(x[:3] + (tuple((ms(e[0]),) + e[1:4] + (ms(e[4]),) for e in x[3]),))
            else:
                tr.append(x[:3] + (tuple((ms(e[0]),) + e[1:] for e in x[3]),))
        rbn = []
        for x in rb:
            if x[0] == 'door':
                rbn.append(x[:5] + (tuple(sorted(x[5], key=str)),))
            elif x[0] == 'ceiling':
                rbn.append(x[:3] + (tuple(e[:4] + (tuple(sorted(e[4], key=str)),) for e in x[3]),))
            else:
                rbn.append(x)
        ca, cb = Counter(tr), Counter(rbn)
        r[kind.lower()] = (sum((ca & cb).values()), len(ra), len(rb))
    # REJECT: bits of the matched sector pairs set in both / only A / only B
    na, nb = a.nsec, b.nsec
    rba, rbb = (na + 7) >> 3, (nb + 7) >> 3
    vis = lambda R, rb, x, y: R[x * rb + (y >> 3)] >> (y & 7) & 1
    both = onlya = onlyb = 0
    inv = {}
    for s, t in smap.items():
        inv.setdefault(t, s)
    pairs = [(s, t) for s, t in smap.items() if s < na and t < nb]
    for s1, t1 in pairs:
        for s2, t2 in pairs:
            x, y = vis(A['REJECT'], rba, s1, s2), vis(B['REJECT'], rbb, t1, t2)
            both += x and y
            onlya += x and not y
            onlyb += y and not x
    r['pvs'] = (both, onlya, onlyb)
    r['fields'] = {k: (v[0], v[1]) for k, v in sc.c.items()}
    return r


def summary(results):
    """per field over all levels"""
    tot = defaultdict(lambda: [0, 0])
    for r in results.values():
        for k, (ok, n) in r['fields'].items():
            tot[k][0] += ok
            tot[k][1] += n
    return {k: (v[0], v[1], 100.0 * v[0] / v[1] if v[1] else 0) for k, v in tot.items()}
