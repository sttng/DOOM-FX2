#!/usr/bin/env python3
"""
fixup.py - maintenance helper for the asar sources.

asar cannot size data from forward references and does not allow label
math in label assignments, so three kinds of values are stored literally
in the sources and protected by asserts:

  * GSU cache-line alignment:  %align_pad(<pad>, <n>, <offset-expr>)
  * cached constants:          NAME = <value>
                               assert (NAME&$FFFFFF) == ((<expr>)&$FFFFFF), "cached constant ..."
                               (also "!NAME #= <value>" with the assert before it)
  * cached ds sizes:           %ds(<bytes>)  ; ds.<b|w|l|4> <expr>
                               assert <count> == <expr>, "cached ds size is stale ..."

After editing engine code these can become stale (asar then stops with
"GSU align pad out of date" / "cached ... is stale").  tools/build.sh runs
this tool before every assembly; by hand:  python3 tools/fixup.py
It assembles a scratch copy in which every check is replaced by a print
of the value asar computes, rewrites the stale values in the sources and
repeats until everything is stable (at most 12 passes).
"""
import os, re, sys, shutil, subprocess, tempfile, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASAR = os.environ.get('ASAR', 'asar')

RE_ALIGN = re.compile(r'^(\s*)%align_pad\((\d+), (\d+), (.*)\)(\s*;.*)?$')
RE_CONST_ASSERT = re.compile(r'^(\s*)assert \((.*?)&\$FFFFFF\) == \(\((.*)\)&\$FFFFFF\), "cached constant (\S+) is stale.*$')
RE_DS_ASSERT = re.compile(r'^(\s*)assert (-?\$?[0-9A-Fa-f]+) == (.*), "cached ds size is stale.*$')

def src_files():
    return sorted(glob.glob(os.path.join(ROOT, 'src', '**', '*.asm'), recursive=True) +
                  glob.glob(os.path.join(ROOT, 'src', '**', '*.inc'), recursive=True))

def probe():
    """assemble a scratch copy where checks print their values; return {(file,line): values}"""
    tmp = tempfile.mkdtemp(prefix='doomfx_fix_')
    files = src_files()
    try:
        shutil.copy(os.path.join(ROOT, 'doom.asm'), tmp)
        shutil.copytree(os.path.join(ROOT, 'src'), os.path.join(tmp, 'src'))
        os.symlink(os.path.join(ROOT, 'data'), os.path.join(tmp, 'data'))
        mac = os.path.join(tmp, 'src', 'macros.inc')
        t = open(mac).read()
        t = t.replace('\tassert (!__alignpc-(<o>))%<n> == 0, "GSU align pad out of date (tools/fixup.py)"',
                      '\tprint "FIXA !__fixid ",hex(!__alignpc)," ",hex(<o>)')
        t = re.sub(r'^(\s*)assert ', r'\1;assert ', t, flags=re.M)
        open(mac, 'w').write(t)
        for fi, f in enumerate(files):
            rel = os.path.relpath(f, ROOT)
            if rel == os.path.join('src', 'macros.inc'): continue
            tf = os.path.join(tmp, rel)
            lines = open(tf).read().split('\n')
            out = []
            for li, l in enumerate(lines):
                m = RE_ALIGN.match(l)
                if m:
                    out.append('%s!__fixid = %d:%d' % (m.group(1), fi, li)); out.append(l); continue
                m = RE_CONST_ASSERT.match(l)
                if m:
                    out.append('%sprint "FIXC %d:%d ",hex((%s)&$FFFFFF)' % (m.group(1), fi, li, m.group(3))); continue
                m = RE_DS_ASSERT.match(l)
                if m:
                    out.append('%sprint "FIXD %d:%d ",hex(%s)' % (m.group(1), fi, li, m.group(3))); continue
                if re.match(r'^\s*assert ', l):
                    out.append(';' + l); continue
                out.append(l)
            open(tf, 'w').write('\n'.join(out))
        r = subprocess.run([ASAR, '-I.', '--fix-checksum=off', 'doom.asm', 'out.sfc'],
                           cwd=tmp, capture_output=True, text=True)
        if r.returncode != 0:
            sys.stderr.write(r.stdout[-4000:] + r.stderr[-4000:])
            raise SystemExit('assembly failed')
        vals = {}
        for l in r.stdout.splitlines():
            p = l.split()
            if len(p) >= 3 and p[0] in ('FIXA', 'FIXC', 'FIXD'):
                fi, li = map(int, p[1].split(':'))
                vals[(files[fi], li)] = (p[0], [int(x, 16) for x in p[2:]])
        return vals
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

def numtxt(v):
    if v >= 0x800000: v -= 0x1000000   # 24-bit masked negative
    if v < 0: return '-$%X' % -v
    return str(v) if v < 16 else '$%X' % v

def apply(vals):
    changed = 0
    # GSU alignment: process in address order, accounting for the shift
    # caused by pads changed earlier in the same bank
    aligns = sorted(((v[1][0], k) for k, v in vals.items() if v[0] == 'FIXA'))
    newpads = {}
    cum = {}
    for pc, key in aligns:
        f, li = key
        l = open(f).read().split('\n')[li]
        m = RE_ALIGN.match(l)
        pad, n = int(m.group(2)), int(m.group(3))
        o = vals[key][1][1]
        bank = pc >> 16
        pc2 = pc + cum.get(bank, 0)
        newpad = (pad + o - pc2) % n
        if newpad != pad:
            newpads[key] = newpad
            cum[bank] = cum.get(bank, 0) + newpad - pad
    for f in src_files():
        lines = open(f).read().split('\n')
        dirty = False
        for li, l in enumerate(lines):
            v = vals.get((f, li))
            if not v: continue
            kind, nums = v
            if kind == 'FIXA':
                m = RE_ALIGN.match(l)
                pad, n = int(m.group(2)), int(m.group(3))
                newpad = newpads.get((f, li), pad)
                if newpad != pad:
                    lines[li] = '%s%%align_pad(%d, %d, %s)%s' % (m.group(1), newpad, n, m.group(4), m.group(5) or '')
                    changed += 1; dirty = True
            elif kind == 'FIXC':
                m = RE_CONST_ASSERT.match(l)
                name = m.group(4); new = numtxt(nums[0])
                # value line is either right before ("NAME = v") or right after ("!NAME #= v")
                for j in (li - 1, li + 1):
                    if 0 <= j < len(lines):
                        m2 = re.match(r'^(\s*)(!?)%s (#?=) \(?(-?\$?[0-9A-Fa-f]+)\)?(\s*;.*)?$' % re.escape(name), lines[j])
                        if m2:
                            if m2.group(4) != new:
                                paren = lines[j].split('=', 1)[1].strip().startswith('(')
                                val = '(%s)' % new if paren else new
                                lines[j] = '%s%s%s %s %s%s' % (m2.group(1), m2.group(2), name, m2.group(3), val, m2.group(5) or '')
                                changed += 1; dirty = True
                            break
                # the assert itself may also hold the cached number (var form)
                if m.group(2) != name and not m.group(2).startswith('!'):
                    if m.group(2) != new:
                        lines[li] = l.replace('assert (%s&' % m.group(2), 'assert (%s&' % new, 1)
                        changed += 1; dirty = True
            elif kind == 'FIXD':
                m = RE_DS_ASSERT.match(l)
                new = numtxt(nums[0])
                if m.group(2) != new:
                    old = m.group(2)
                    lines[li] = l.replace('assert %s ==' % old, 'assert %s ==' % new, 1)
                    # the %ds() line before holds n*size
                    m3 = re.match(r'^(\s*)%ds\((\S+)\)(\s*; ds\.(\w).*)$', lines[li - 1])
                    if m3:
                        size = {'b': 1, 'w': 2, 'l': 3, '4': 4}[m3.group(4)]
                        lines[li - 1] = '%s%%ds(%s)%s' % (m3.group(1), numtxt(nums[0] * size), m3.group(3))
                    changed += 1; dirty = True
        if dirty:
            open(f, 'w').write('\n'.join(lines))
    return changed

def main():
    for it in range(12):
        n = apply(probe())
        print('fixup pass %d: %d values updated' % (it + 1, n))
        if n == 0: break
    else:
        raise SystemExit('fixup did not converge')

if __name__ == '__main__':
    main()
