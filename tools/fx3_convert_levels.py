#!/usr/bin/env python3
"""
fx3_convert_levels.py - convert the 36 levels of "The Ultimate DOOM" (FX3 ROM)
into the level data files the engine includes (data/RLLEV/<EnMm>/...).

The FX3 level format is the DOOM-FX engine's level format with these differences,
all of which are handled here:

  * vertex pointers (LINES fields 0/2, SEGS fields 0/2) are absolute GSU RAM
    addresses into FX3's rotated-vertex array (base $14BC); they are rebased to
    our _RLVertexes (first to --vbase, then wad2rl.finalize computes the real
    base from the level set and writes it to levels.inc, where the engine
    asserts it)
  * "REJECT" is a sector visibility matrix (PVS) stored right after BLOCKMAP:
    rows of (NumSectors+7)>>3 bytes, bit (s2&7) of byte (s2>>3), 1 = can see.
    It is written as REJECT; the engine's sight test uses this format.
  * wall numbers (FACES) and object types (OBJECTS) are FX3's (67 walls with
    SKY1-SKY4 = #0-#3; Spectre object type after Demon).  The engine uses the
    FX3 numbering, so they are copied unchanged.

Blob lengths are exact (counts from the FX3 level tables, the BLOCKMAP parsed,
FACES up to the last face referenced, special lists parsed), so the files can
be packed freely.  levels.inc gets !NUMLEVELS, the !lvlN slots, songs, names,
next/secret exits, the engine limits (!RLMAX...), the vertex base and the FX3
format flags.  Also writes levels.json and OUTDIR/../RLDATA/ART/ScoreE4.txt
(the Episode 4 end text).

usage: fx3_convert_levels.py ROM OUTDIR [--vbase ADDR]
"""
import argparse, json, os, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
FX3_VBASE = 0x14BC
FX3_NEXT = 0x29FFB3             # NextLevelI ($E9:FFB3)
FX3_E4TEXT = 0x3CD1CB           # Episode 4 end text ($FC:D1CB)
FX3_NAMES = 0x3C9D02            # EMNames ($FC:9D02), 36 zero-terminated names
RLL, RLG, RLS, RLB, RLA = 12, 11, 10, 28, 4
u16 = lambda b, o: b[o] | b[o + 1] << 8

# the FX3 level tables (EM...Table, in the original rllevels order, 36 entries); GSU addresses are
# linear: file = addr - $400000
TBL = 0x3C9642
N = 36
LEVELS = ['E%dM%d' % (e, m) for e in (1, 2, 3, 4) for m in range(1, 10)]


def tables(d):
    w = lambda a: d[a] | d[a + 1] << 8
    l = lambda a: d[a] | d[a + 1] << 8 | d[a + 2] << 16
    t = TBL
    T = {'BSP': [l(t + 4 * i) for i in range(N)]}; t += 4 * N
    for n in ['BSPR', 'AREAS', 'VERTEXES', 'NUMVERTEXES', 'LINES', 'NUMLINES', 'SEGS', 'SEGS2', 'NUMSEGS', 'REJECT', 'FACES']:
        T[n] = [w(t + 2 * i) for i in range(N)]; t += 2 * N
    T['SECTORS'] = [l(t + 4 * i) for i in range(N)]; t += 4 * N
    for n in ['NUMSECTORS', 'OBJECTS', 'BLOCKMAP', 'DOORS', 'FLOORS', 'CEILINGS', 'STAIRS', 'LIFTS', 'SONG']:
        T[n] = [w(t + 2 * i) for i in range(N)]; t += 2 * N
    return T


def pointers(d, T, i):
    """file offsets of level i's blobs"""
    a0 = T['BSP'][i] - 0x400000; bank = T['BSP'][i] & 0xFF0000
    A = lambda lo: (bank | lo) - 0x400000
    b0 = T['SECTORS'][i] - 0x400000; bb = T['SECTORS'][i] & 0xFF0000
    B = lambda lo: (bb | lo) - 0x400000
    return {'BSP': a0, 'AREAS': A((T['AREAS'][i] + 0x8000) & 0xFFFF), 'VERTEXES': A((T['VERTEXES'][i] + FX3_VBASE) & 0xFFFF),
            'LINES': A(T['LINES'][i]), 'SEGS': A((T['SEGS'][i] + RLG) & 0xFFFF), 'REJECT': A(T['REJECT'][i]), 'FACES': A(T['FACES'][i]),
            'SECTORS': b0, 'OBJECTS': B(T['OBJECTS'][i]), 'BLOCKMAP': B(T['BLOCKMAP'][i]), 'DOORS': B(T['DOORS'][i]),
            'FLOORS': B(T['FLOORS'][i]), 'CEILINGS': B(T['CEILINGS'][i]), 'STAIRS': B(T['STAIRS'][i]), 'LIFTS': B(T['LIFTS'][i])}


def blockmap_len(d, b):
    nb = d[b + 4] * d[b + 5]
    end = 6 + 2 * nb
    for k in range(nb):
        a1 = 6 + 2 * k
        q = a1 + u16(d, b + a1) + 1
        while True:
            hi = d[b + q + 1]
            q += 2
            if hi & 0x80:
                break
        end = max(end, q)
    return end


# ---- special lists (no terminator: the engine searches until the tag matches)
# The last list of a level is followed by unrelated data (often another
# level), so every record is validated (known line type, sectors and lines in
# range) and the parse stops at the first record that is not one.
FLOORTYPES = {5, 9, 14, 18, 19, 20, 22, 23, 30, 36, 37, 38, 45, 56, 58, 59, 60, 65, 70, 71, 82, 83, 91,
              98, 101, 102}
LIFTTYPES = {10, 21, 62, 88, 87, 89, 120, 121, 122, 123}
CEILINGTYPES = {25, 44, 73, 74, 77}


def parse_floors(d, a, end, ns, nl):
    while a + 3 <= end:
        tag, typ, n = d[a], d[a + 1], d[a + 2]
        if not tag or typ not in FLOORTYPES or not n or a + 3 + n * 8 > end or \
                any(d[a + 3 + 8 * k] >= ns or d[a + 3 + 8 * k + 7] >= ns for k in range(n)):
            break
        a += 3 + n * 8
    return a


def parse_lifts(d, a, end, ns, nl):
    while a + 3 <= end:
        tag, typ, n = d[a], d[a + 1], d[a + 2]
        if not tag or typ not in LIFTTYPES or not n or a + 3 + n * 9 > end or \
                any(d[a + 3 + 9 * k] >= ns for k in range(n)):
            break
        a += 3 + n * 9
    return a


def parse_ceilings(d, a, end, ns, nl):
    while a + 3 <= end:
        tag, typ, n = d[a], d[a + 1], d[a + 2]
        if not tag or typ not in CEILINGTYPES or not n:
            break
        q = a + 3
        for _ in range(n):
            if q + 8 > end or d[q] >= ns:
                return a
            nlines = d[q + 7]
            if q + 8 + 2 * nlines > end or any(u16(d, q + 8 + 2 * j) >= nl for j in range(nlines)):
                return a
            q += 8 + 2 * nlines
        a = q
    return a


def parse_stairs(d, a, end, ns, nl):
    while a + 8 <= end:
        tag, n = d[a], d[a + 7]
        if not tag or not n or a + 8 + n > end or any(d[a + 8 + k] >= ns for k in range(n)):
            break
        a += 8 + n
    return a


PARSE = {'FLOORS': parse_floors, 'LIFTS': parse_lifts,
         'CEILINGS': parse_ceilings, 'STAIRS': parse_stairs}
OUR_ORDER = ['DOORS', 'STAIRS', 'FLOORS', 'CEILINGS', 'LIFTS']   # EXMYMAC order


# PC A_BossDeath on E4M8: the last Spider Mastermind lowers the floors tagged 666 to the
# lowest neighbouring floor (on E4M6 the last Cyberdemon opens the doors tagged 666: the
# cartridge's E4M6 has their DOORS records, for the switch that opens them too).  The
# cartridge ends both levels at once instead, so its E4M8 has no FLOORS record for this;
# the engine (rlmobjects2.asm _RLMAD2Boss) needs one: tag 666 & $FF, line type 38.
BOSS_FLOORS = {'E4M8': (666 & 0xFF, 38)}


def boss_floors(lv, o, vbase):
    """o['FLOORS'] with the boss special's record of level LV added (as wad2rl.py conv_floors
    writes it from a WAD), built from the level's SECTORS, LINES, FACES and VERTEXES (vertex
    pointers built for VBASE)"""
    fl = bytes(o['FLOORS'])
    if lv not in BOSS_FLOORS:
        return fl
    tag, typ = BOSS_FLOORS[lv]
    a = 0
    while a + 3 <= len(fl):                       # (already there)
        if fl[a] == tag and fl[a + 1] == typ:
            return fl
        a += 3 + 8 * fl[a + 2]
    S, L, F, V = o['SECTORS'], o['LINES'], o['FACES'], o['VERTEXES']
    floor = lambda s: struct.unpack_from('<h', S, s * RLS + 3)[0]
    vertex = lambda ptr: struct.unpack_from('<hh', V, ((ptr - vbase) & 0xFFFF) // 4 * 4)
    lines = []                                    # (right sector, left sector or None, v1, v2)
    for i in range(len(L) // RLL):
        f = u16(L, i * RLL + 8)                   # the right side's face: near, far sector
        lines.append((F[f], None if L[i * RLL + 4] & 1 else F[f + 1],
                      vertex(u16(L, i * RLL)), vertex(u16(L, i * RLL + 2))))
    ents = []
    for s in range(len(S) // RLS):
        if S[s * RLS + 9] != tag:
            continue
        h, model, xs, ys = 0x7FFFFFFF, s, [], []
        for r, l, v1, v2 in lines:
            if s not in (r, l):
                continue
            xs += [v1[0], v2[0]]; ys += [v1[1], v2[1]]
            if l is None:
                continue
            n = l if r == s else r                # lowest neighbouring floor (the last of equal ones)
            if floor(n) <= h:
                h, model = floor(n), n
        ox = min(xs) + ((max(xs) - min(xs)) >> 1)  # sound origin: the centre of its lines' box
        oy = min(ys) + ((max(ys) - min(ys)) >> 1)
        ents.append(struct.pack('<BHhhB', s, h & 0xFFFF, ox, oy, model))
    assert ents, '%s: no sector tagged %d' % (lv, tag)
    return fl + bytes([tag, typ, len(ents)]) + b''.join(ents)


def rebase(blob, size, fields, delta):
    b = bytearray(blob)
    for o in range(0, len(b), size):
        for f in fields:
            v = u16(b, o + f) - FX3_VBASE
            assert 0 <= v < 0x10000 and v % 4 == 0, 'bad vertex pointer'
            struct.pack_into('<H', b, o + f, (v + delta) & 0xFFFF)
    return bytes(b)


def convert(d, out, vbase=0x3E64):
    # (vertex pointers are built for VBASE; wad2rl.finalize rebases them at the end)
    T = tables(d)
    nxt_all = sorted(set(v for i in range(N) for k, v in pointers(d, T, i).items()
                         if k != 'REJECT'))
    import bisect

    def next_start(v):
        j = bisect.bisect_right(nxt_all, v)
        e = nxt_all[j] if j < len(nxt_all) else len(d)
        return min(e, (v | 0xFFFF) + 1)

    info = {'levels': [], 'stats': {}}
    waste = 0
    for i, lv in enumerate(LEVELS):
        p = pointers(d, T, i)
        nv, nl, ng, ns = (T[k][i] for k in ('NUMVERTEXES', 'NUMLINES', 'NUMSEGS', 'NUMSECTORS'))
        o = {}
        nbsp = (T['BSPR'][i] // RLB) + 1
        o['BSP'] = d[p['BSP']:p['BSP'] + nbsp * RLB]
        assert p['BSP'] + nbsp * RLB == p['AREAS'], lv
        o['AREAS'] = d[p['AREAS']:p['VERTEXES']]
        assert len(o['AREAS']) % RLA == 0 and len(o['AREAS']) // RLA == nbsp + 1, lv
        o['VERTEXES'] = d[p['VERTEXES']:p['VERTEXES'] + nv * 4]
        o['LINES'] = rebase(d[p['LINES']:p['LINES'] + nl * RLL], RLL, (0, 2), vbase)
        o['SEGS'] = rebase(d[p['SEGS']:p['SEGS'] + ng * RLG], RLG, (0, 2), vbase)
        # FACES: up to the last face referenced by SEGS (word at +7), +4 bytes,
        # at most up to the next blob
        fmax = 0
        for k in range(ng):
            g = p['SEGS'] + k * RLG
            fmax = max(fmax, u16(d, g + 7))
        fend = fmax + 4
        o['FACES'] = d[p['FACES']:min(p['FACES'] + fend, next_start(p['FACES']))]
        # SECTORS (+ 'RL' sentinel, re-added by EXMYMAC)
        o['SECTORS'] = d[p['SECTORS']:p['SECTORS'] + ns * RLS]
        assert d[p['SECTORS'] + ns * RLS:p['SECTORS'] + ns * RLS + 2] == b'LR', lv
        o['OBJECTS'] = d[p['OBJECTS']:p['BLOCKMAP']]
        assert o['OBJECTS'][-2:] == b'\0\0', lv
        o['OBJECTS'] = o['OBJECTS'][:-2]          # (EXMYMAC adds the dw 0 terminator)
        assert p['OBJECTS'] < p['BLOCKMAP']
        bml = blockmap_len(d, p['BLOCKMAP'])
        o['BLOCKMAP'] = d[p['BLOCKMAP']:p['BLOCKMAP'] + bml]
        rb = (ns + 7) >> 3
        pvs = p['BLOCKMAP'] + bml
        assert (T['REJECT'][i] & 0xFFFF) == (pvs & 0xFFFF), lv
        rej = bytearray(d[pvs:pvs + ns * rb])
        for k in range(ns):                       # a sector always sees itself (E3M2 #21 did not)
            rej[k * rb + (k >> 3)] |= 1 << (k & 7)
        o['REJECT'] = bytes(rej)
        assert pvs + ns * rb == p['DOORS'], lv
        # special lists: FX3 places DOORS, then the others; equal pointers = one
        # shared region.  Reproduce the FX3 label offsets in our EXMYMAC order.
        sp = {k: p[k] for k in OUR_ORDER}
        base = sp['DOORS']
        starts = sorted(set(sp.values()))
        last = starts[-1]
        # parse the last region with the format of each list starting there
        cands = [k for k in OUR_ORDER if sp[k] == last]
        lim = next_start(last)
        ends = set()
        for k in cands:
            if k == 'DOORS':
                continue
            try:
                ends.add(PARSE[k](d, last, lim, ns, nl))
            except IndexError:
                pass
        ends = [e for e in ends if e <= lim]
        # a shared region holds the data of one non-empty list only; take the
        # longest parse that stays inside the bank
        lastend = max(ends) if ends else last
        waste += lim - lastend
        # offsets in FX3, region boundaries
        bounds = starts + [lastend]
        reg = {s: d[s:bounds[bounds.index(s) + 1]] for s in starts}
        # assign each region to the LAST list (in our order) that starts there,
        # so that empty lists come first and share the label
        files = {k: b'' for k in OUR_ORDER}
        for s in starts:
            ks = [k for k in OUR_ORDER if sp[k] == s]
            files[ks[-1]] = reg[s]
        # check: our label offsets == FX3 offsets
        off = 0
        for k in OUR_ORDER:
            if k == 'DOORS':
                assert files[k].endswith(b'\xff'), lv
                body = files[k][:-1]
                lab = off
                off += len(body) + 1
                files[k] = body
            else:
                lab = off
                off += len(files[k])
            assert lab == sp[k] - base, (lv, k, lab, sp[k] - base, sp)
        o.update(files)
        o['FLOORS'] = boss_floors(lv, o, vbase)   # (after the FX3 offset check above)
        os.makedirs(os.path.join(out, lv), exist_ok=True)
        for k, v in o.items():
            open(os.path.join(out, lv, k), 'wb').write(v)
        info['levels'].append({'name': lv, 'song': T['SONG'][i], 'vertexes': nv, 'lines': nl,
                               'segs': ng, 'sectors': ns,
                               'sizes': {k: len(v) for k, v in o.items()}})
    # levels.inc
    L = ['; generated by tools/fx3_convert_levels.py from the FX3 ROM -- do not edit',
         '!NUMLEVELS = %d' % N,
         '!RLVERTEXBASE = $%04X\t; _RLVertexes the vertex pointers were built for' % vbase]
    for i, lv in enumerate(LEVELS):
        L.append('!lvl%d = %s' % (i, lv))
    for i, lv in enumerate(LEVELS):
        L.append('!lvlsong%d = $%04X' % (i, T['SONG'][i]))
    a = FX3_NAMES
    for i, lv in enumerate(LEVELS):
        e = d.index(b'\0', a)
        nm = d[a:e].decode('ascii'); a = e + 1
        assert nm and all(32 <= ord(c) < 127 and c != '"' for c in nm), nm
        L.append('!lvlname%d = "%s"' % (i, nm))
    for lv in LEVELS:
        L.append('!use%s #= 1' % lv)
    mx = lambda k: max(l[k] for l in info['levels'])
    L.append('!RLMAXVERTEXES = %d' % mx('vertexes'))
    L.append('!RLMAXSECTORS = %d' % mx('sectors'))
    L.append('!RLMAXLINES = %d\t; (even: the RAM after _RLLineFlags must stay word aligned)' % ((mx('lines') + 1) & ~1))
    nxt = d[FX3_NEXT:FX3_NEXT + N]
    for i in range(N):
        L.append('!lvlnext%d = %d' % (i, nxt[i]))
    for i in range(N):            # FX3 $E9:FF18: E1M3, E2M5, E3M6 -> M9; any other secret exit -> E4M9
        L.append('!lvlsecret%d = %d' % (i, {2: 8, 13: 17, 23: 26}.get(i, 35)))
    L.append('!RLSKILLEPISODES = 0\t; every skill plays every episode')
    L.append('!RLSKY4 = 1\t; SKY1-SKY4 at GSU $01:8000/$01:C000/$02:8000/$02:C000, one per episode')
    L.append('!RLSPECTRE = 1\t; FX3 object types: Spectre after Demon')
    L.append('!RLREJECTPVS = 1\t; REJECT is FX3 visibility (rows of (sectors+7)>>3 bytes, bit set = can see)')
    open(os.path.join(out, 'levels.inc'), 'w').write('\n'.join(L) + '\n')
    json.dump(info, open(os.path.join(out, 'levels.json'), 'w'), indent=1)
    import wad2rl                       # engine limits and vertex base for this level set
    wad2rl.finalize(out)
    # Episode 4 end text (score screen, FX3 $FC:D1CB): {0, VRAM word, text}... $FF
    a = e = FX3_E4TEXT
    while not d[e] & 0x80:
        e += 3 if d[e] == 0 else 1
    art = os.path.join(out, '..', 'RLDATA', 'ART')
    os.makedirs(art, exist_ok=True)
    open(os.path.join(art, 'ScoreE4.txt'), 'wb').write(d[a:e + 1])
    mx = lambda k: max(l[k] for l in info['levels'])
    print('36 levels converted; max vertexes %d lines %d segs %d sectors %d; '
          'unparsed tail bytes skipped %d' % (mx('vertexes'), mx('lines'), mx('segs'),
                                              mx('sectors'), waste))


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('rom')
    ap.add_argument('out')
    ap.add_argument('--vbase', type=lambda s: int(s, 0), help='vertex base to build for first (default $3E64; wad2rl.finalize then rebases to the computed one)')
    a = ap.parse_args()
    d = open(a.rom, 'rb').read()
    convert(d, a.out, a.vbase or 0x3E64)
