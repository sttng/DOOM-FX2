#!/usr/bin/env python3
"""
wadlevels.py - put levels converted from a DOOM .WAD (tools/wad2rl.py) into
the data set and build the ROM.

usage: wadlevels.py --wad DOOM.WAD [--wad PWAD.wad] [--zokumbsp PATH] [--keep-nodes]
                    [--pvs compute|wad] [--no-build] [--profile doom2 [--names tnt|plutonia]] [MAPS...]
       wadlevels.py --restore            (back to the FX3 levels)

* starts from the FX3 levels (data/RLLEV.fx3, written by `make data`)
* converts the maps (default: every map of the WAD the data set has a slot
  for) with the tables learned from the FX3 levels (data/wad2rl.json)
* needs ZokumBSP (--zokumbsp, $ZOKUMBSP or zokumbsp on the PATH): the nodes
  of every map are rebuilt with it first (tools/wadnodes.py; nothing visible
  changes).  --keep-nodes: the WAD's nodes are kept where the map fits (tests)
* a map whose BSP, AREAS, VERTEXES, SEGS and FACES exceed the one 64 KB bank
  the engine reads them from gets its nodes rebuilt again, in steps until it
  fits: + merging adjacent look-alike sectors; + merging neighbours whose
  light differs by 16, then 32 (visible: printed).  When no step fits, the
  map keeps its FX3 version (--profile doom2: it is left out).
* builds (tools/build.sh; not with --no-build); while the 2 MB GamePak ROM
  (what the Super FX sees) is full, the nodes of the map that gains most get
  rebuilt with ZokumBSP (nothing visible changes: same lines and sectors,
  the same segs except back sides that cannot be seen), one map at a time;
  when that is not enough, the converted map that grew most against its
  FX3 version goes back to the FX3 version (the SNES team cut some maps
  for this reason)
* --profile doom2 (also TNT/Plutonia with --names): MAP01-MAP32 into the
  first 32 slots in DOOM II order; a map that does not convert or fit is
  left out (the game skips the slot) instead of keeping an FX3 level, and
  left-out maps are tried again, smallest first, once the ROM fits
* with wall format 2/3 (RLDATA/WALLS/WALLS.FMT) wad2rl.py gets the wall map
  (--walls RLDATA/WALLS/WALLMAP.JSON); otherwise, when RLDATA/IMAGES/MASKED.JSON
  exists (wad2gfx.py --masked), it gets --masked MASKED.JSON
"""
import argparse, os, re, shutil, struct, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import wad2rl   # noqa: E402
import wadnodes   # noqa: E402

DATA = os.path.join(ROOT, 'data')
LEV = os.path.join(DATA, 'RLLEV')
FX3 = os.path.join(DATA, 'RLLEV.fx3')
MASKED = os.path.join(DATA, 'RLDATA', 'IMAGES', 'MASKED.JSON')   # wall format 1 + wad2gfx.py --masked
GSU = ['BSP', 'AREAS', 'VERTEXES', 'SEGS', 'FACES', 'SECTORS', 'DOORS', 'STAIRS', 'FLOORS', 'CEILINGS', 'LIFTS']


def vbase(d):
    return int(re.search(r'^!RLVERTEXBASE = \$([0-9A-Fa-f]+)', open(os.path.join(d, 'levels.inc')).read(),
                         re.M).group(1), 16)


DROP = False                                    # no cartridge version to fall back on: leave the map out


def restore_map(lv):
    """copy the FX3 version of LV back, its vertex pointers rebased to the current base
    (DROP: leave the slot out of the ROM instead; the game skips it)"""
    if DROP:
        print('%s (%s) is left out' % (lv, src(lv)))
        set_inc({}, unused=[lv])
        return
    old, new = vbase(FX3), vbase(LEV)
    shutil.rmtree(os.path.join(LEV, lv))
    shutil.copytree(os.path.join(FX3, lv), os.path.join(LEV, lv))
    for k, sz in (('LINES', wad2rl.RLL), ('SEGS', wad2rl.RLG)):
        fn = os.path.join(LEV, lv, k)
        b = bytearray(open(fn, 'rb').read())
        for o in range(0, len(b), sz):
            for f in (0, 2):
                struct.pack_into('<H', b, o + f, struct.unpack_from('<H', b, o + f)[0] - old + new)
        open(fn, 'wb').write(bytes(b))


# DOOM II: MAP01-MAP32 into the first 32 slots, one sequence (no episode starts),
# MAP15 -> MAP31 -> MAP32 -> MAP16 secret branch, MAP30 ends the game
DOOM2_NAMES = ['ENTRYWAY', 'UNDERHALLS', 'THE GANTLET', 'THE FOCUS', 'THE WASTE TUNNELS', 'THE CRUSHER',
               'DEAD SIMPLE', 'TRICKS AND TRAPS', 'THE PIT', 'REFUELING BASE', 'CIRCLE OF DEATH',
               'THE FACTORY', 'DOWNTOWN', 'THE INMOST DENS', 'INDUSTRIAL ZONE', 'SUBURBS', 'TENEMENTS',
               'THE COURTYARD', 'THE CITADEL', 'GOTCHA!', 'NIRVANA', 'THE CATACOMBS', 'BARRELS O FUN',
               'THE CHASM', 'BLOODFALLS', 'THE ABANDONED MINES', 'MONSTER CONDO', 'THE SPIRIT WORLD',
               'THE LIVING END', 'ICON OF SIN', 'WOLFENSTEIN', 'GROSSE']


TNT_NAMES = ['SYSTEM CONTROL', 'HUMAN BBQ', 'POWER CONTROL', 'WORMHOLE', 'HANGER', 'OPEN SEASON', 'PRISON',
             'METAL', 'STRONGHOLD', 'REDEMPTION', 'STORAGE FACILITY', 'CRATER', 'NUKAGE PROCESSING',
             'STEEL WORKS', 'DEAD ZONE', 'DEEPEST REACHES', 'PROCESSING AREA', 'MILL', 'SHIPPING RESPAWNING',
             'CENTRAL PROCESSING', 'ADMINISTRATION CENTER', 'HABITAT', 'LUNAR MINING PROJECT', 'QUARRY',
             'BARONS DEN', 'BALLISTYX', 'MOUNT PAIN', 'HECK', 'RIVER STYX', 'LAST CALL', 'PHARAOH', 'CARIBBEAN']
PLUTONIA_NAMES = ['CONGO', 'WELL OF SOULS', 'AZTEC', 'CAGED', 'GHOST TOWN', 'BARONS LAIR', 'CAUGHTYARD',
                  'REALM', 'ABATTOIRE', 'ONSLAUGHT', 'HUNTED', 'SPEED', 'THE CRYPT', 'GENESIS', 'THE TWILIGHT',
                  'THE OMEN', 'COMPOUND', 'NEUROSPHERE', 'NME', 'THE DEATH DOMAIN', 'SLAYER',
                  'IMPOSSIBLE MISSION', 'TOMBSTONE', 'THE FINAL FRONTIER', 'THE TEMPLE OF DARKNESS', 'BUNKER',
                  'ANTI CHRIST', 'THE SEWERS', 'ODYSSEY OF NOISES', 'THE GATEWAY OF HELL', 'CYBERDEN', 'GO 2 IT']
NAMES = {'doom2': None, 'tnt': TNT_NAMES, 'plutonia': PLUTONIA_NAMES}           # (the names are in the PC executables, not the WADs)


def doom2_profile(slots, names=None):
    """{slot name: MAPxx} and the levels.inc lines for DOOM II"""
    n = len(slots)
    src = {slots[i]: 'MAP%02d' % (i + 1) for i in range(32)}
    nxt = {i: i + 1 for i in range(32)}
    sec = dict(nxt)
    nxt[29] = sec[29] = n                       # MAP30: the end
    sec[14] = 30                                # MAP15 secret -> MAP31
    nxt[30], sec[30] = 15, 31                   # MAP31 -> MAP16, secret MAP32
    nxt[31] = sec[31] = 15                      # MAP32 -> MAP16
    lines = {'RLEPISODELEN': 99, 'RLDOOM2MONSTERS': 1}   # (wad2gfx.py --doom2-monsters)
    for i, k in ((6, 'RLMAP07'), (29, 'RLMAP30'), (31, 'RLMAP32')):   # boss specials: EMNUM of the slot
        m = re.match(r'E(\d)M(\d)$', slots[i])              # (mission.B; with !lvlsky its sky, not the
        sky = 1 if i < 11 else 2 if i < 20 else 3           #  episode, is the low byte: rllevels.asm)
        lines[k] = '$%04X' % ((int(m.group(2)) << 8) | sky) if m else 0
    for i in range(n):
        lines['lvlnext%d' % i] = nxt.get(i, n)
        lines['lvlsecret%d' % i] = sec.get(i, n)
        if i < 32:
            lines['lvlname%d' % i] = '"%s"' % (names or DOOM2_NAMES)[i]
        # DOOM II skies: SKY1 MAP01-11, SKY2 MAP12-20, SKY3 MAP21-32
        lines['lvlsky%d' % i] = 1 if i < 11 else 2 if i < 20 else 3
    return src, lines


def set_inc(updates, unused=(), used=()):
    """rewrite !name = value lines of levels.inc (added when missing); UNUSED: !use<slot> #= 0,
    USED: !use<slot> #= 1"""
    inc = os.path.join(LEV, 'levels.inc')
    txt = open(inc).read()
    for k, v in updates.items():
        if re.search(r'^!%s = ' % k, txt, re.M):
            txt = re.sub(r'^!%s = .*$' % k, lambda m: '!%s = %s' % (k, v), txt, flags=re.M)
        else:
            txt += '!%s = %s\n' % (k, v)
    for s in unused:
        txt = re.sub(r'^!use%s #= \d+' % s, '!use%s #= 0' % s, txt, flags=re.M)
    for s in used:
        txt = re.sub(r'^!use%s #= \d+' % s, '!use%s #= 1' % s, txt, flags=re.M)
    open(inc, 'w').write(txt)


BANK = 0x10000
ONEBANK = ['BSP', 'AREAS', 'VERTEXES', 'SEGS', 'FACES']
NODE_STEPS = [('nodes rebuilt', False, 0), ('+ look-alike sectors merged', True, 0),
              ('+ light differences up to 16 merged', True, 16), ('+ light differences up to 32 merged', True, 32)]


def onebank(d, lv):
    return sum(os.path.getsize(os.path.join(d, lv, k)) for k in ONEBANK)


SRC = {}                                        # slot name -> WAD map name (when they differ)


def src(lv):
    return SRC.get(lv, lv)


def convert(wads, maps, pvs):
    wmap = os.path.join(DATA, 'RLDATA', 'WALLS', 'WALLMAP.JSON')      # wall format 2/3 (wad2gfx.py --map-walls)
    cmd = [sys.executable, os.path.join(HERE, 'wad2rl.py'), 'convert', '--tables', os.path.join(DATA, 'wad2rl.json'),
           '--out', LEV, '--pvs', pvs] + sum((['--wad', w] for w in wads), []) + \
          (['--walls', wmap] if os.path.exists(os.path.join(DATA, 'RLDATA', 'WALLS', 'WALLS.FMT')) else
           ['--masked', MASKED] if os.path.exists(MASKED) else []) + \
          [('%s=%s' % (src(m), m)) if src(m) != m else m for m in maps]
    p = subprocess.run(cmd, stdout=subprocess.PIPE, text=True)
    sys.stdout.write(p.stdout); sys.stdout.flush()
    if p.returncode:
        sys.exit(1)
    return set(re.findall(r'^(\w+): NOT CONVERTED', p.stdout, re.M))


def fit_bank(wads, lv, pvs, zokum):
    """rebuild LV's nodes until its one-bank lumps fit; False: it does not"""
    print('%s: BSP/AREAS/VERTEXES/SEGS/FACES %d bytes, one bank holds %d' % (lv, onebank(LEV, lv), BANK))
    if not zokum or not shutil.which(zokum):
        print('%s: ZokumBSP not found (--zokumbsp or $ZOKUMBSP)' % lv)
        return False
    d = os.path.join(DATA, 'wadnodes')
    os.makedirs(d, exist_ok=True)
    pw = os.path.join(d, lv + '.wad')
    for what, merge, light in NODE_STEPS:
        notes = []
        wadnodes.build(wads, src(lv), pw, zokum, merge, light, log=notes.append)
        size = wadnodes.onebank_size(wads + [pw], src(lv))
        print('%s: %s: %s bytes' % (lv, what, size))
        if size is not None and size <= BANK:
            convert(wads + [pw], [lv], pvs)
            real = onebank(LEV, lv)             # (the estimate's FACES are without the wall map)
            if real <= BANK:
                for n in notes:
                    print('   ' + n)
                return True
            print('%s: converted: %d bytes' % (lv, real))
    print('%s: still too big' % lv)
    return False


def node_savings(wads, maps, zokum):
    """bytes of one-bank lumps a nodes-only rebuild (no merging, all segs kept) saves per map"""
    from concurrent.futures import ThreadPoolExecutor
    d = os.path.join(DATA, 'wadnodes')
    os.makedirs(d, exist_ok=True)

    def one(lv):
        pw = os.path.join(d, lv + '.wad')
        wadnodes.build(wads, src(lv), pw, zokum, merge=False, log=lambda s: None, invisible=False)
        a, b = wadnodes.onebank_size(wads, src(lv)), wadnodes.onebank_size(wads + [pw], src(lv))
        return lv, (a - b) if a is not None and b is not None else 0
    with ThreadPoolExecutor(os.cpu_count() or 2) as ex:
        return dict(ex.map(one, maps))


def gsu_size(d, lv):
    return sum(os.path.getsize(os.path.join(d, lv, k)) for k in GSU)


def build():
    p = subprocess.run(['bash', os.path.join(HERE, 'build.sh')], cwd=ROOT, capture_output=True, text=True)
    return p.returncode == 0 and 'GamePak ROM full' not in p.stdout + p.stderr, p.stdout + p.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('maps', nargs='*')
    ap.add_argument('--wad', action='append')
    ap.add_argument('--restore', action='store_true', help='back to the FX3 levels (data/RLLEV.fx3)')
    ap.add_argument('--pvs', default='compute', choices=['compute', 'wad'],
                    help='sector visibility: computed (default) or the WAD REJECT (wad2rl.py --pvs)')
    ap.add_argument('--no-build', action='store_true', help='convert only, do not build the ROM')
    ap.add_argument('--zokumbsp', default=os.environ.get('ZOKUMBSP', 'zokumbsp'), help='ZokumBSP binary (default $ZOKUMBSP)')
    ap.add_argument('--profile', choices=['doom2'], help='doom2: MAP01-MAP32 into the slots, DOOM II order and names')
    ap.add_argument('--names', choices=sorted(NAMES), default='doom2', help='--profile doom2: level names (tnt: TNT Evilution)')
    ap.add_argument('--keep-nodes', action='store_true',
                    help="keep the WAD's nodes where the map fits (default: every map's nodes rebuilt with ZokumBSP)")
    ap.add_argument('--rebuild-nodes', action='store_true', help=argparse.SUPPRESS)   # (the default now)
    a = ap.parse_args()
    global DROP
    if not os.path.isdir(FX3):
        sys.exit('%s missing: run "make data" first' % FX3)
    if not a.restore and not (a.zokumbsp and shutil.which(a.zokumbsp)):     # (before the levels are reset)
        sys.exit('ZokumBSP not found (--zokumbsp, $ZOKUMBSP or zokumbsp on the PATH): it rebuilds the nodes of every map')
    shutil.rmtree(LEV, ignore_errors=True)
    shutil.copytree(FX3, LEV)
    shutil.rmtree(os.path.join(DATA, 'wadnodes'), ignore_errors=True)   # maps rebuilt by ZokumBSP (PWADs)
    if a.restore:
        print('FX3 levels restored')
        return
    if not a.wad:
        sys.exit('--wad required')
    slots = re.findall(r'^!lvl\d+ = (\w+)$', open(os.path.join(LEV, 'levels.inc')).read(), re.M)
    if a.profile == 'doom2':
        s, lines = doom2_profile(slots, NAMES[a.names])
        SRC.update(s); DROP = True
        have = set(wad2rl.Wad(*a.wad).maps())
        maps = [sl for sl in slots[:32] if s[sl] in have]
        if a.maps:                              # (tests: only these maps; the other slots keep FX3 levels)
            maps = [sl for sl in maps if s[sl] in a.maps]
        if not maps:
            sys.exit('none of the maps %s is in the WAD' % (' '.join(a.maps) if a.maps else 'MAP01-MAP32'))
        set_inc(lines, unused=slots[32:])
        print('DOOM II: %s -> %s..%s, slots %s left out' % (s[maps[0]], maps[0], maps[-1], ' '.join(slots[32:])))
    else:
        maps = a.maps or [m for m in wad2rl.Wad(*a.wad).maps() if m in slots]
    bad = [m for m in maps if m not in slots]
    if bad:
        sys.exit('no level slot for %s in levels.inc (this data set has %s..%s)' % (' '.join(bad), slots[0], slots[-1]))
    rebuilt_all = []
    if not a.keep_nodes:
        sav = node_savings(a.wad, maps, a.zokumbsp)
        rebuilt_all = [os.path.join(DATA, 'wadnodes', lv + '.wad') for lv in maps]
        print('nodes rebuilt with ZokumBSP: %d maps, %+d bytes of BSP/AREAS/VERTEXES/SEGS/FACES' % (
            len(maps), -sum(sav.values())))
    failed = convert(a.wad + rebuilt_all, maps, a.pvs)
    converted = [m for m in maps if m not in failed]
    for lv in failed:                           # the slot keeps its FX3 level, or is left out
        restore_map(lv)
    maps = list(converted)
    fitted = {}
    for lv in maps:
        if onebank(LEV, lv) > BANK:
            fitted[lv] = fit_bank(a.wad, lv, a.pvs, a.zokumbsp)
            if not fitted[lv]:
                restore_map(lv)
                converted.remove(lv)
                wad2rl.finalize(LEV)
    if a.no_build:
        return
    dropped = []
    rebuilt = {lv for lv in converted if os.path.exists(os.path.join(DATA, 'wadnodes', lv + '.wad'))
               and onebank(LEV, lv) <= BANK and fitted.get(lv)}
    savings = None
    while True:
        ok, log = build()
        if ok:
            print(log.strip().split('\n')[-1])
            break
        if 'GamePak ROM full' not in log or not converted:
            sys.exit(log)
        if a.zokumbsp and shutil.which(a.zokumbsp):
            if savings is None:
                savings = node_savings(a.wad, [m for m in converted if m not in rebuilt], a.zokumbsp)
            best = max((m for m in savings if m in converted and m not in rebuilt and savings[m] > 0),
                       key=lambda m: savings[m], default=None)
            if best:
                print('GamePak ROM full: %s gets its nodes rebuilt (-%d bytes)' % (best, savings[best]))
                convert(a.wad + [os.path.join(DATA, 'wadnodes', best + '.wad')], [best], a.pvs)
                rebuilt.add(best)
                continue
        worst = max(converted, key=lambda m: gsu_size(LEV, m) - (0 if DROP else gsu_size(FX3, m)))
        if DROP:
            print('GamePak ROM full: %s is left out (%d bytes)' % (worst, gsu_size(LEV, worst)))
        else:
            print('GamePak ROM full: %s keeps its FX3 version (+%d bytes converted)' % (
                worst, gsu_size(LEV, worst) - gsu_size(FX3, worst)))
        restore_map(worst)
        converted.remove(worst)
        rebuilt.discard(worst)
        if DROP:
            dropped.append(worst)
        wad2rl.finalize(LEV)
    # the ROM is packed in banks: dropping the biggest maps can leave room for
    # smaller ones dropped after them; try them again, smallest first
    for lv in sorted(dropped, key=lambda m: gsu_size(LEV, m)):
        set_inc({}, used=[lv])
        wnod = os.path.join(DATA, 'wadnodes', lv + '.wad')
        convert(a.wad + ([wnod] if os.path.exists(wnod) else []), [lv], a.pvs)
        wad2rl.finalize(LEV)
        ok, log = build()
        if ok:
            print('%s (%s) fits after all' % (lv, src(lv)))
            converted.append(lv)
        else:
            set_inc({}, unused=[lv])
            wad2rl.finalize(LEV)
    if dropped:
        ok, log = build()
        if not ok:
            sys.exit(log)
        print(log.strip().split('\n')[-1])
    print('converted from the WAD: %s' % ' '.join(('%s=%s' % (src(m), m)) if src(m) != m else m for m in converted))


if __name__ == '__main__':
    main()
