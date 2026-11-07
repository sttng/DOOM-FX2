#!/usr/bin/env python3
"""
delaycheck.py - find GSU branch delay slot hazards in the asar sources.

The Super FX executes the byte after every branch/jump before the jump takes
effect.  If that byte starts a multi-byte instruction (ibt, iwt, lms, ...)
or is a prefix (alt1/2/3, with, from, to), the rest of it is fetched from
the branch target.  The original code uses this on purpose in places
("bne x+1" tricks), so by default only lines changed since a git revision
are checked.

usage: delaycheck.py [--since REV] [--all] [FILES...]
  --since  revision to diff against (default HEAD: uncommitted changes)
  --all    check every line
  FILES    default src/engine/*.asm (files without "arch superfx" are skipped)
Exit 1 if a hazard is found.
"""
import os, re, sys, subprocess, argparse

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

BRANCH = re.compile(r'^(bra|bge|blt|bne|beq|bpl|bmi|bcc|bcs|bvc|bvs|jmp|ljmp|loop)\b')
TO_R15 = re.compile(r'^(iwt|ibt|lms|lm)\s+r15\b')
# one byte, no prefix, no operand bytes
SAFE = re.compile(r'^(nop|stop|cache|lsr|rol|ror|asr|inc|dec|not|sex|lob|hib|swap|merge|loop|plot|color|getb|sbk|fmult|link|ldw|stw|add\s+r\d+$|sub\s+r\d+$|and\s+r\d+$|or\s+r\d+$|mult\s+r\d+$|jmp)\b')


def instr(line):
    l = line.split(';', 1)[0].strip()
    if not l or l.endswith(':') or l.startswith(('!', '%align', 'if', 'else', 'endif', 'assert', 'macro', 'endmacro')):
        return None
    if re.match(r'^[A-Za-z_?.][\w.?]*:', l):
        l = l.split(':', 1)[1].strip()
        if not l:
            return None
    if '=' in l and not l.startswith(('ibt', 'iwt')):
        return None
    return l


def check(path, lines_of_interest):
    src = open(path, errors='replace').read().split('\n')
    bad = []
    for i, line in enumerate(src):
        ins = instr(line)
        if ins is None:
            continue
        if not (BRANCH.match(ins) or TO_R15.match(ins) or re.match(r'^to\s+r15$', ins)):
            continue
        if lines_of_interest is not None and (i + 1) not in lines_of_interest:
            continue
        if re.match(r'^to\s+r15$', ins):
            continue                      # the instruction after it is the jump
        j = i + 1
        while j < len(src) and instr(src[j]) is None:
            j += 1
        if j >= len(src):
            continue
        nxt = instr(src[j])
        if nxt.startswith('%'):
            bad.append((i + 1, ins, nxt + '  (macro)'))
        elif not SAFE.match(nxt):
            bad.append((i + 1, ins, nxt))
    return bad


def changed_lines(rev, path):
    out = subprocess.run(['git', 'diff', '-U0', rev, '--', path], cwd=ROOT, capture_output=True, text=True).stdout
    lines = set()
    for m in re.finditer(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@', out, re.M):
        a = int(m.group(1)); n = int(m.group(2) or 1)
        lines.update(range(a, a + n))
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--since', default='HEAD')
    ap.add_argument('--all', action='store_true')
    ap.add_argument('files', nargs='*')
    a = ap.parse_args()
    files = a.files or sorted(os.path.join(ROOT, 'src', 'engine', f) for f in os.listdir(os.path.join(ROOT, 'src', 'engine')) if f.endswith('.asm'))
    n = 0
    for f in files:
        txt = open(f, errors='replace').read()
        if 'arch superfx' not in txt:
            continue
        loi = None if a.all else changed_lines(a.since, os.path.relpath(f, ROOT))
        if loi is not None and not loi:
            continue
        for ln, ins, nxt in check(f, loi):
            print('%s:%d: %-30s delay slot: %s' % (os.path.relpath(f, ROOT), ln, ins, nxt))
            n += 1
    sys.exit(1 if n else 0)


if __name__ == '__main__':
    main()
