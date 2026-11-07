#!/usr/bin/env python3
"""
wadnodes.py - make a PC map's renderer data smaller for the engine

The engine reads a level's BSP, AREAS, VERTEXES, SEGS and FACES through one
bank byte, so together they must fit one 64 KB ROM bank.  The SNES team cut
big maps down by hand; for E4M8 they merged look-alike sectors (223 -> 155)
and rebuilt the BSP.  This tool does the same automatically:

  1. merge ADJACENT sectors that look the same and never change (same floor,
     ceiling, flats and light (--light N: or light up to N apart); no tag, no
     special, no door, stair or donut; the line between them does not block
     sound).  The lines between them then have the same sector on both sides
     and draw nothing.
  2. rebuild the nodes with ZokumBSP (-ni: no segs for those lines; they
     stay in LINEDEFS for collision and triggers.  -np=b: node picks that
     split fewer segs and make fewer subsectors.  -nb: no back seg for a
     two-sided line whose back sector is closed (floor = ceiling) and never
     moves: nobody stands in such a sector, so that side is never seen).

Writes a PWAD with the new map, to be given to wad2rl.py after the IWAD.

usage:  wadnodes.py --wad DOOMU.WAD MAP --out MAP.wad [--zokumbsp PATH] [--no-merge] [--light N]
        wadnodes.py --wad DOOMU.WAD MAP --size     (size of the one-bank lumps now)
"""
import argparse, os, shutil, struct, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import wad2rl   # noqa: E402

LUMPS = ['THINGS', 'LINEDEFS', 'SIDEDEFS', 'VERTEXES', 'SEGS', 'SSECTORS', 'NODES', 'SECTORS', 'REJECT', 'BLOCKMAP']
ZOKUM_OPTS = ['-b-', '-nq', '-np=b', '-nb']   # keep BLOCKMAP; rebuild NODES and REJECT
INVISIBLE = '-ni'     # no segs for two-sided lines with the same sector on both sides
SOUNDBLOCK = 0x40


def fixed_sectors(m):
    """sectors that may change during play (wad2rl's merge_sectors rules)"""
    keep = set()
    for l in m.lines:
        t = l['type']
        if t in wad2rl.DOORLOCAL and l['left'] >= 0:
            keep.add(m.sec(l['left']))
        if t in wad2rl.STAIRTYPES and l['tag']:
            for s, sc in enumerate(m.sectors):
                if sc['tag'] == l['tag']:
                    keep.update(m.stair_chain(s))
                    break
        if t == 9 and l['tag']:
            for s, sc in enumerate(m.sectors):
                if sc['tag'] == l['tag']:
                    keep.update((s, s - 1))
    return keep


def merge_adjacent(m, light=0):
    """union of adjacent look-alike fixed sectors.  LIGHT > 0 also merges
    neighbours whose light differs by at most that much (a visible edit: the
    group keeps the light of its largest sector, by number of sidedefs).
    Returns (old -> new sector map, new sector -> old sector whose record it keeps,
    [(kept, [merged...]) for groups whose light changed])"""
    n = len(m.sectors)
    keep = fixed_sectors(m)
    key = lambda s: (m.sectors[s]['floor'], m.sectors[s]['ceil'], m.sectors[s]['rawftex'], m.sectors[s]['ctex'])
    ok = lambda s: not (m.sectors[s]['tag'] or m.sectors[s]['special'] or s in keep)
    up = list(range(n))

    def find(s):
        while up[s] != s:
            up[s] = up[up[s]]
            s = up[s]
        return s
    for l in m.lines:
        if l['left'] < 0 or l['right'] < 0 or l['flags'] & SOUNDBLOCK or l['tag']:
            continue
        a, b = m.sec(l['right']), m.sec(l['left'])
        if a != b and ok(a) and ok(b) and key(a) == key(b) and \
                abs(m.sectors[a]['light'] - m.sectors[b]['light']) <= light:
            ra, rb = find(a), find(b)
            if ra != rb:
                up[max(ra, rb)] = min(ra, rb)
    size = [0] * n
    for sd in m.sides:
        size[sd['sector']] += 1
    groups = {}
    for s in range(n):
        groups.setdefault(find(s), []).append(s)
    roots = sorted(groups)
    rank = {r: i for i, r in enumerate(roots)}
    remap = {s: rank[find(s)] for s in range(n)}
    rep, lit = {}, []
    for r in roots:
        g = groups[r]
        k = max(g, key=lambda s: (size[s], -s))
        rep[rank[r]] = k
        if len({m.sectors[s]['light'] for s in g}) > 1:
            lit.append((k, [s for s in g if s != k]))
    return remap, rep, lit


def pack_pwad(name, lumps):
    data = bytearray(b'PWAD' + bytes(8))
    dirs = []
    for nm, d in [(name, b'')] + lumps:
        dirs.append((len(data), len(d), nm))
        data += d
    off = len(data)
    for p, s, nm in dirs:
        data += struct.pack('<ii8s', p, s, nm.encode('latin1'))
    struct.pack_into('<ii', data, 4, len(dirs), off)
    return bytes(data)


def onebank_size(wads, mapname):
    """bytes of BSP+AREAS+VERTEXES+SEGS+FACES as wad2rl.py writes them (run with --pvs wad
    and without --walls/--masked, so FACES is approximate); None if the map does not convert"""
    out = tempfile.mkdtemp()
    cmd = [sys.executable, os.path.join(HERE, 'wad2rl.py'), 'convert', '--pvs', 'wad',
           '--tables', os.path.join(os.path.dirname(HERE), 'data', 'wad2rl.json'), '--out', out]
    for w in wads:
        cmd += ['--wad', w]
    try:
        subprocess.run(cmd + [mapname], capture_output=True, text=True)
        d = os.path.join(out, mapname)
        if not os.path.exists(os.path.join(d, 'BSP')):     # (NOT CONVERTED: too many sectors...)
            return None
        return sum(os.path.getsize(os.path.join(d, k)) for k in ('BSP', 'AREAS', 'VERTEXES', 'SEGS', 'FACES'))
    finally:
        shutil.rmtree(out, ignore_errors=True)


def build(wads, mapname, out, zokum, merge=True, light=0, log=print, invisible=True):
    """write OUT, a PWAD with MAPNAME's nodes rebuilt by ZokumBSP (MERGE: adjacent look-alike
    sectors merged first).  INVISIBLE: no segs for same-sector lines (they then show on the
    automap only once the computer map is found)"""
    m = wad2rl.Wad(*wads).map(mapname)
    lumps = dict(m.raw)
    if merge:
        remap, rep, lit = merge_adjacent(m, light)
        nn = len(rep)
        lumps['SECTORS'] = b''.join(m.raw['SECTORS'][rep[i] * 26:rep[i] * 26 + 26] for i in range(nn))
        for k, g in lit:
            log('%s: sectors %s take the light of sector %d (%d instead of %s)' % (
                mapname, ' '.join(map(str, g)), k, m.sectors[k]['light'],
                '/'.join(str(m.sectors[s]['light']) for s in g)))
        sd = bytearray(m.raw['SIDEDEFS'])
        for i in range(len(sd) // 30):
            s = struct.unpack_from('<H', sd, i * 30 + 28)[0]
            struct.pack_into('<H', sd, i * 30 + 28, remap[s])
        lumps['SIDEDEFS'] = bytes(sd)
        lumps['REJECT'] = b''                   # rebuilt by ZokumBSP
        log('%s: merged %d adjacent look-alike sectors (%d -> %d)' % (mapname, len(m.sectors) - nn, len(m.sectors), nn))
    tmp = tempfile.mkdtemp()
    src = os.path.join(tmp, 'in.wad')
    open(src, 'wb').write(pack_pwad(mapname, [(k, lumps.get(k, b'')) for k in LUMPS]))
    r = subprocess.run([zokum] + ZOKUM_OPTS + ([INVISIBLE] if invisible else []) + [src, mapname, '-o', out], stdin=subprocess.DEVNULL,
                       capture_output=True, text=True, errors='replace')
    if r.returncode or not os.path.exists(out):
        raise SystemExit('zokumbsp failed on %s:\n%s' % (mapname, (r.stdout + r.stderr)[-2000:]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--wad', action='append', required=True)
    ap.add_argument('map')
    ap.add_argument('--out')
    ap.add_argument('--zokumbsp', default=os.environ.get('ZOKUMBSP', 'zokumbsp'))
    ap.add_argument('--no-merge', action='store_true')
    ap.add_argument('--size', action='store_true')
    ap.add_argument('--light', type=int, default=0, help='also merge neighbours whose light differs by up to this')
    a = ap.parse_args()
    m = a.map.upper()
    def report(n):
        print('%s: %s' % (m, 'does not convert (wad2rl.py)' if n is None else
                          'one-bank lumps %d bytes (max 65536)' % n))
    if a.size:
        report(onebank_size(a.wad, m))
        return
    build(a.wad, m, a.out, a.zokumbsp, not a.no_merge, a.light)
    report(onebank_size(a.wad + [a.out], m))


if __name__ == '__main__':
    main()
