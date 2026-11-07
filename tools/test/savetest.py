#!/usr/bin/env python3
"""
savetest.py ROM NAME LEVEL... - save/load test through the pause menu.

Runs dettest.py on each level, JOBS (default 2) at a time: at rendered frame 100
Save Game -> slot 1, play on, at 130 Load Game -> slot 1 (skill 0, so the player
lives).  Then every GSU RAM block a save stores (savegame.asm _SaveBlocksGSU) must
be the same, byte for byte, when SaveGame starts and when SaveRestore has
finished, both after the save (the level is set up again, the state XORed back)
and after the load.  Runs and logs: $TESTOUT/save_NAME_<level> (TESTOUT default
${TMPDIR:-/tmp}/doomtest); MESENRUN as for dettest.py.  Exit 1 unless every
level passes.

  savetest.py --check SYM OUTBASE LEVEL...   (only the check, on earlier runs)
"""
import glob, os, re, struct, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from dettest import load_syms   # noqa: E402

BLOCKS = [('RL variables', 'RAM7AStart', 'RAM7BEnd'), ('sectors+objects', '_RLSectorData', '_RLVertexes'),
          ('tasks/line flags', '_RLTasks', '_RLLineRLCounts'), ('plats/toggles/lists', '_RLPlatTasks', 'RAM7DEnd')]
NAMES = ['E%dM%d' % (e, m) for e in (1, 2, 3, 4) for m in range(1, 10)]


def _walk(o):
    """input after rendered frame o: walk, fire, turn"""
    return 'r%d:up@20;r%d:b@4;r%d:right@6;r%d:up,b@14;r%d:left@4' % (o + 1, o + 22, o + 28, o + 36, o + 52)


INPUT = '900:a@5;1100:a@5;1300:a@5;r5:up@40;r50:b@5;r60:right@8;r70:up@25;' + _walk(100)
MENU = 'r100:start,-,-,down,-,down,-,a,-,-,a;r130:start,-,-,down,-,down,-,down,-,a,-,-,a'


def savebase():
    inc = os.path.join(HERE, '..', '..', 'src', 'include', 'savegame.inc')
    return int(re.search(r'^\s*SAVEBASE\s*=\s*\$71([0-9A-Fa-f]{4})', open(inc).read(), re.M).group(1), 16)


def run(rom, out, level):
    cmd = [sys.executable, os.path.join(HERE, 'dettest.py'), rom, '--sym', os.path.splitext(rom)[0] + '.sym',
           '--out', out, '--frames', '160', '--level', str(level), '--skill', '0', '--input', INPUT,
           '--menu', MENU, '--dump-at', 'SaveGame,SaveRestore_end',
           '--mesenrun', os.environ.get('MESENRUN', 'mesenrun')]
    with open(out + '.log', 'w') as log:
        subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT)


def check(sym, base, levels):
    sy = load_syms(sym)
    ok = n = 0
    for l in levels:
        d = '%s_%d' % (base, l)
        n += 1
        sv = os.path.join(d, 'gsuram_SaveGame1.bin')
        rs = sorted(glob.glob(os.path.join(d, 'gsuram_SaveRestore_end*.bin')), key=lambda f: int(re.search(r'(\d+)\.bin$', f).group(1)))
        if not os.path.exists(sv) or len(rs) < 3:
            print('%-5s no save/load (player died?)' % NAMES[l])
            continue
        a = open(sv, 'rb').read()
        size = struct.unpack_from('<H', open(os.path.join(d, 'gsuram.bin'), 'rb').read(), 0x10000 + savebase() + 8)[0]
        bad = []
        for when, f in (('after save', rs[-2]), ('after load', rs[-1])):
            b = open(f, 'rb').read()
            for nm, s0, s1 in BLOCKS:
                x, y = sy[s0] & 0xFFFF, sy[s1] & 0xFFFF
                diff = sum(1 for i in range(x, y) if a[i] != b[i])
                if diff:
                    bad.append('%s, %s: %d bytes differ' % (when, nm, diff))
        ok += not bad
        print('%-5s %s  (save %d bytes)%s' % (NAMES[l], 'OK' if not bad else 'DIFF', size, ''.join('  ' + x for x in bad)))
    print('%d of %d levels restored byte for byte' % (ok, n))
    return ok == n


def main():
    if len(sys.argv) > 1 and sys.argv[1] == '--check':
        sys.exit(0 if check(sys.argv[2], sys.argv[3], [int(l) for l in sys.argv[4:]]) else 1)
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    rom, name, levels = sys.argv[1], sys.argv[2], [int(l) for l in sys.argv[3:]]
    s = os.environ.get('TESTOUT') or os.path.join(os.environ.get('TMPDIR', '/tmp'), 'doomtest')
    os.makedirs(s, exist_ok=True)
    base = os.path.join(s, 'save_%s' % name)
    with ThreadPoolExecutor(int(os.environ.get('JOBS', 2))) as ex:
        list(ex.map(lambda l: run(rom, '%s_%d' % (base, l), l), levels))
    sys.exit(0 if check(os.path.splitext(rom)[0] + '.sym', base, levels) else 1)


if __name__ == '__main__':
    main()
