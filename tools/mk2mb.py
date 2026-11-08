#!/usr/bin/env python3
"""
mk2mb.py - cut a data set down to a 2 MB ROM: only some level slots stay in the ROM
(the others get `!use<slot> #= 0`), tools/wad2rl.py finalize sizes the RAM tables
(!RLMAX...) for the maps that are left, and data/regions.json (a copy of
tools/regions-2mb.json) makes the ROM 2 MB.  `make swset` and `make demo` (make shareware, doom2demo) run it.

shareware: turn a DOOM data set (the cartridge levels, or E1M1-E1M9
converted from the shareware DOOM1.WAD) into the shareware set: only the
nine Episode 1 slots stay in the ROM, E1M8 ends the game (its end text,
the order screen, then the title), the other episodes' score screens are
left out (!RLEPISODES = 1), and so are the plasma rifle and BFG frames
(!RLNOPLASMABFG; no such pickups in Episode 1).  The episode menu keeps
all episodes; a new game on Episode 2-4 shows the order screen
(!RLORDERSCREEN, wad2art.py --order HELP2).

  python3 tools/mk2mb.py shareware          (works on data/, then: make)

E1M3's secret exit still leads to E1M9, and E1M9 back to E1M4.

  python3 tools/mk2mb.py shareware --wad DOOM1.WAD

also re-sources walls (data/wad2gfx.json): the cartridge shows several PC
textures as one wall (wad2rl.json maps them to it); a wall whose own texture
the Episode 1 maps never use (the cartridge's PIPE4, ROCKRED3, STARG2: not in
the shareware WAD) is built from the texture the maps use most on it
(PIPE2, REDWALL1, STARG3), at that texture's size.

demo: turn a DOOM II data set (`make doom2 WAD=DOOM2.WAD`) into the
demo data set: only the first N maps (default 3: MAP01-MAP03) stay in the
ROM, the game ends after the last of them.

  python3 tools/mk2mb.py demo [--maps N]    (works on data/, then: make)

The next/secret chain of the last map points past the last slot (the end,
as MAP30 in the full game).  (New Game always starts MAP01: the DOOM II sets
have no episode menu.)
"""
import argparse, collections, json, os, re, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import wad2rl      # noqa: E402
import wadlevels   # noqa: E402

KEEP = 9           # shareware: the Episode 1 slots


def cut_down(upd, slots, keep):
    """keep the first KEEP level slots, with the levels.inc values UPD; 2 MB regions"""
    wadlevels.set_inc(upd, unused=slots[keep:], used=slots[:keep])
    wad2rl.finalize(wadlevels.LEV)
    shutil.copy(os.path.join(HERE, 'regions-2mb.json'), os.path.join(wadlevels.DATA, 'regions.json'))


def resource_walls(wadpath, maps):
    data = wadlevels.DATA
    t = json.load(open(os.path.join(data, 'wad2rl.json')))
    rp = os.path.join(data, 'wad2gfx.json')
    rec = json.load(open(rp))
    wad = wad2rl.Wad(wadpath)
    import wad2gfx
    wa = wad2gfx.WadArt([wadpath])
    use = collections.defaultdict(collections.Counter)       # wall -> texture -> sides
    for m in maps:
        for sd in wad.map(m).sides:
            for k in ('upper', 'lower', 'mid'):
                n = sd[k]
                if n and n != '-' and t['walls'].get(n) is not None:
                    use[t['walls'][n] // 2][n] += 1
    changed = []
    for w, c in sorted(use.items()):
        r = rec['walls'][w]
        if r.get('wad') in c or wa.texture(r.get('wad') or '') is not None:
            continue                                   # its own texture is used, or the WAD has it
        n = c.most_common(1)[0][0]
        tx = wa.texture(n)
        if tx is None or tx.h & (tx.h - 1) or tx.w & (tx.w - 1) or tx.h > 128 or tx.w > 256:
            continue                                   # (the engine: power-of-two sizes)
        changed.append('%s -> %s' % (r['name'], n))
        rec['walls'][w] = dict(r, name=n, wad=n, w=tx.w, h=tx.h, dx=0, dy=0, sx=1.0, sy=1.0)
    json.dump(rec, open(rp, 'w'), indent=0)
    if changed:
        print('walls built from the texture the maps use: ' + ', '.join(changed))


def shareware(a, txt, inc):
    if re.search(r'^!RLEPISODELEN = 99', txt, re.M) or not re.search(r'^!lvl8 = E1M9$', txt, re.M):
        sys.exit('%s is not a DOOM (Episode 1-4) data set' % inc)
    n = int(re.search(r'^!NUMLEVELS = (\d+)', txt, re.M).group(1))
    slots = re.findall(r'^!lvl\d+ = (\w+)$', txt, re.M)
    nxt = {i: int(re.search(r'^!lvlnext%d = (\d+)' % i, txt, re.M).group(1)) for i in range(KEEP)}
    upd = {'RLEPISODES': 1, 'RLORDERSCREEN': 1, 'RLNOPLASMABFG': 1, 'lvlnext7': n}   # E1M8: the end of the game
    for i in range(KEEP):                               # secret exits only inside Episode 1
        if i != 2:
            upd['lvlsecret%d' % i] = n if i == 7 else nxt[i]
    cut_down(upd, slots, KEEP)
    if a.wad:
        resource_walls(a.wad, slots[:KEEP])
    print('shareware: %s kept, %d slots left out, E1M8 ends the game' % (' '.join(slots[:KEEP]), n - KEEP))


def demo(a, txt, inc):
    if not re.search(r'^!RLEPISODELEN = 99', txt, re.M):
        sys.exit('%s is not a DOOM II data set (make doom2 WAD=DOOM2.WAD first)' % inc)
    slots = re.findall(r'^!lvl\d+ = (\w+)$', txt, re.M)
    n, keep = len(slots), a.maps
    upd = {}
    for i in range(n):                          # MAP01 -> MAP02 -> ... -> last kept map -> the end
        upd['lvlnext%d' % i] = upd['lvlsecret%d' % i] = i + 1 if i + 1 < keep else n
    cut_down(upd, slots, keep)
    print('demo: %s kept (%s), %d slots left out' % (
        ' '.join(slots[:keep]), ' '.join('MAP%02d' % (i + 1) for i in range(keep)), n - keep))


def main():
    ap = argparse.ArgumentParser(description='cut a data set down to a 2 MB ROM')
    sub = ap.add_subparsers(dest='set', required=True)
    s = sub.add_parser('shareware', help='DOOM: Episode 1')
    s.add_argument('--wad', help='DOOM1.WAD: re-source the walls whose own texture the maps do not use')
    d = sub.add_parser('demo', help='DOOM II: the first maps')
    d.add_argument('--maps', type=int, default=3)
    a = ap.parse_args()
    inc = os.path.join(wadlevels.LEV, 'levels.inc')
    {'shareware': shareware, 'demo': demo}[a.set](a, open(inc).read(), inc)


if __name__ == '__main__':
    main()
