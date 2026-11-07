#!/usr/bin/env python3
"""
gsuprof.py - summarise a GSU cycle profile.

The profile is written by tools/mesenrun/mesenrun when MESEN_GSU_PROF=<file>
is set: one line "<GSU address> <cycles>" per executed instruction address
(cycles include ROM/RAM waits and pixel cache flushes).  Cycles are summed
per label of SYMFILE (the nearest at or below the address).

usage: gsuprof.py PROFILE SYMFILE [--top N] [--files]
"""
import sys, os, re, glob, bisect, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from dettest import load_syms   # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('prof'); ap.add_argument('sym')
    ap.add_argument('--top', type=int, default=30)
    ap.add_argument('--files', action='store_true', help='also sum per source file (src/engine/*.asm)')
    a = ap.parse_args()
    syms = load_syms(a.sym)
    labs = sorted((v, k) for k, v in syms.items() if '.' not in k and not k.startswith(':'))
    addrs = [v for v, _ in labs]
    per = {}; tot = 0
    for l in open(a.prof):
        ad, n = l.split(); ad = int(ad, 16); n = int(n); tot += n
        i = bisect.bisect_right(addrs, ad) - 1
        k = labs[i][1] if i >= 0 else '?'
        per[k] = per.get(k, 0) + n
    print('GSU cycles: %d' % tot)
    for k, n in sorted(per.items(), key=lambda x: -x[1])[:a.top]:
        print('%6.2f%% %11d %s' % (100.0 * n / tot, n, k))
    if a.files:
        src = os.path.join(HERE, '..', '..', 'src', 'engine')
        lab2f = {}
        for f in glob.glob(os.path.join(src, '*.asm')):
            for l in open(f, errors='replace'):
                m = re.match(r'([A-Za-z_][A-Za-z0-9_]*):', l)
                if m: lab2f[m.group(1)] = os.path.basename(f)
        agg = {}
        for k, n in per.items():
            f = lab2f.get(k, '?')
            agg[f] = agg.get(f, 0) + n
        print('per file:')
        for f, n in sorted(agg.items(), key=lambda x: -x[1])[:a.top]:
            print('%6.2f%% %s' % (100.0 * n / tot, f))


if __name__ == '__main__':
    main()
