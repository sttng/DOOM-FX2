#!/usr/bin/env python3
"""
layout.py - ROM layout ("linker") for the asar build of DOOM-FX.

asar has no linker, so section placement lives in src/layout.inc (asar is
used with the 'norom' mapper: a section's "real" value is its file offset,
its "pc" value the address the code/data is assembled for).  This tool
measures every section (assembling with the current layout) and places the
relocatable ones, up to 6 rounds until src/layout.inc stops changing; it also
writes src/layout_end.inc (PRINT_LAYOUT).  Section metadata (kind, home bank,
code or data) comes from tools/sections.json.

ROM map (Super FX 2, 4 MB; README "Cartridge and memory map"):

  file $000000-$1FFFFF  GamePak ROM, seen by the GSU and the CPU
                        CPU/GSU $00-$3F:$8000 (LoROM) and $40-$5F (linear);
                        sections are assembled for those (never $80-$DF: on
                        the hardware map $80-$BF:8000 and $C0-$FF are the
                        additional CPU ROM, not mirrors of the GamePak ROM)
  file $200000-$3FFFFF  Super NES ROM, CPU only, $E0-$FF:$0000-$FFFF (linear,
                        in the additional CPU ROM window $C0-$FF);
                        the GSU never sees it (official Super FX limit: 2 MB)

Placement rules
  * absolute sections (fixed LOAD/ORG in the source) stay where they are
  * sections listed in regions.json (below) as "snesrom" (CPU-only data) are
    placed in the Super NES ROM (64 KB banks $E0-$FF)
  * every other section first tries its home bank in the GamePak ROM (the
    bank of the original link: code sections MUST stay there because
    of 16-bit jsr/jmp and data-bank assumptions); data sections that do
    not fit move to any GamePak bank with room
  * "lorom" sections (RORG=$8000 originally) stay inside one 32 KB half
    bank, the rest inside one 64 KB bank unless marked "crossok"

regions.json: a data set's own data/regions.json if there is one, else
tools/regions.json.  The 2 MB builds (tools/mk2mb.py)
copy tools/regions-2mb.json there, which lists no "snesrom" sections, so
everything goes to the GamePak ROM and the ROM is 2 MB.

usage:  python3 tools/layout.py [--asar asar] [--report]
"""
import os, re, sys, json, subprocess, argparse, fnmatch

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMEPAK = (0x000000, 0x200000)
SNES_LO = (0x200000, 0x200000)      # (the 8 MB map's LoROM window: none in the 4 MB map)
SNES_HI = (0x200000, 0x400000)

def load_meta():
    return json.load(open(os.path.join(ROOT, 'tools', 'sections.json')))

def load_regions():
    p = os.path.join(ROOT, 'data', 'regions.json')         # (the data set's own: the 2 MB builds)
    if not os.path.exists(p):
        p = os.path.join(ROOT, 'tools', 'regions.json')
    return json.load(open(p)) if os.path.exists(p) else {}

def region_of(name, regions):
    for pat, reg in regions.items():
        if pat == '_comment': continue    # (section names start with _ too: _CHARDEF*)
        if fnmatch.fnmatchcase(name, pat): return reg
    return 'gamepak'

def parse_layout(path):
    lay = {}
    for l in open(path):
        m = re.match(r'!sec_(\w+)_(real|pc|ram)\s*=\s*\$?([0-9A-Fa-f]+)', l)
        if m:
            n, k, v = m.groups()
            lay.setdefault(n, {})[k] = int(v, 16) if k != 'ram' else int(v)
    return lay

def file_to_pc(off, kind):
    """file offset -> address the section is assembled for"""
    if off < 0x200000:
        if kind == 'lorom': return ((off >> 15) << 16) | 0x8000 | (off & 0x7FFF)
        return 0x400000 + off
    return 0xC00000 + off               # CPU $E0-$FF

def measure(asar):
    """assemble (with every assert removed: cached constants / GSU pads may be
    stale while sections move, tools/fixup.py refreshes them) and collect the
    section end positions printed with PRINT_LAYOUT"""
    import tempfile, shutil, glob
    tmp = tempfile.mkdtemp(prefix='doomfx_lay_')
    try:
        # sections may sit at stale positions while measuring: no bank-border checks
        top = open(os.path.join(ROOT, 'doom.asm'), encoding='latin1').read()
        open(os.path.join(tmp, 'doom.asm'), 'w', encoding='latin1').write(
            top.replace('norom', 'norom\ncheck bankcross off', 1))
        for f in glob.glob(os.path.join(ROOT, 'src', '**', '*'), recursive=True):
            if os.path.isdir(f): continue
            rel = os.path.relpath(f, ROOT); dst = os.path.join(tmp, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            txt = open(f, encoding='latin1').read()
            txt = re.sub(r'(?m)^(\s*)assert\b.*$', r'\1; (assert removed for layout measurement)', txt)
            txt = re.sub(r'(?m)^(\s*)check bankcross full', r'\1check bankcross off', txt)
            open(dst, 'w', encoding='latin1').write(txt)
        os.symlink(os.path.realpath(os.path.join(ROOT, 'data')), os.path.join(tmp, 'data'))
        out = subprocess.run([asar, '-I.', '--define', 'PRINT_LAYOUT=1', '--fix-checksum=off',
                              'doom.asm', os.path.join(tmp, '_measure.sfc')], cwd=tmp, capture_output=True, text=True)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    ends = {}
    for l in out.stdout.splitlines() + out.stderr.splitlines():
        m = re.match(r'SECEND (\w+) ([0-9A-Fa-f]+) ([0-9A-Fa-f]+)', l.strip())
        if m: ends[m.group(1)] = (int(m.group(2), 16), int(m.group(3), 16))
    return ends, out

def place(meta, sizes, regions):
    used = []  # (start, end, name)
    def free(a, b):
        for s, e, n in used:
            if a < e and s < b: return False
        return True
    for n, m in meta.items():
        if m['kind'] == 'fixed' and not m['ram']:
            off = m['file']; sz = sizes.get(n, m.get('size', 0))
            if sz: used.append((off, off + sz, n))
    placement = {}
    reloc = [n for n, m in meta.items() if m['kind'] in ('reloc', 'lorom') and sizes.get(n, 0) > 0]
    reloc.sort(key=lambda n: (0 if meta[n]['code'] else 1, -sizes[n]))
    def window(n, off, kind):
        if meta[n].get('crossok'): return 0, 1 << 24
        if SNES_LO[0] <= off < SNES_LO[1] or kind == 'lorom': span = 0x8000
        else: span = 0x10000
        return off - off % span, off - off % span + span
    def try_fit(n, lo, hi, align=1, kind=None):
        sz = sizes[n]
        cands = sorted(set([lo] + [e for s, e, _ in used if lo <= e < hi] + list(range(lo - lo % 0x8000 + 0x8000, hi, 0x8000))))
        mib = meta[n].get('min_in_bank', 0)      # e.g. colourmaps: page >= $80
        for c in cands:
            c = (c + align - 1) // align * align
            if c % 0x10000 < mib: c = c - c % 0x10000 + mib
            w0, w1 = window(n, c, kind or meta[n]['kind'])
            if c + sz <= min(hi, w1) and free(c, c + sz):
                return c
        return None
    for n in reloc:
        m = meta[n]; sz = sizes[n]; align = m.get('align', 1)
        reg = region_of(n, regions)
        if reg == 'snesrom':
            if m['code']:
                raise SystemExit('%s: code sections cannot be moved to the Super NES ROM yet' % n)
            c = try_fit(n, SNES_HI[0], SNES_HI[1], align)
            if c is None: c = try_fit(n, SNES_LO[0], SNES_LO[1], align)
            if c is None: raise SystemExit('Super NES ROM full: cannot place %s ($%X bytes)' % (n, sz))
        else:
            home = m['home_file']
            bank0 = home - home % 0x10000
            # (a home outside the GamePak ROM - the level images' Super NES ROM bank -
            #  is no home there: any GamePak bank)
            c = try_fit(n, bank0, bank0 + 0x10000, align) if home < GAMEPAK[1] else None
            if c is None:
                if m['code']:
                    raise SystemExit('code section %s ($%X bytes) does not fit its home bank $%02X' % (n, sz, 0x40 + bank0 // 0x10000))
                c = try_fit(n, GAMEPAK[0], GAMEPAK[1], align)
                if c is None:
                    raise SystemExit('GamePak ROM full: cannot place %s ($%X bytes)' % (n, sz))
        used.append((c, c + sz, n)); placement[n] = c
    return placement, used

def write_layout(meta, placement, path):
    lines = [';', ';\tSECTION PLACEMENT  (generated by tools/layout.py - do not edit by hand)', ';',
             ';\treal = file offset (asar norom), pc = address the section is assembled for', ';']
    for n, m in meta.items():
        if m['ram']:
            real, pc = 0, m['pc']          # RAM: skip only, nothing is emitted
        elif m['kind'] == 'fixed':
            real, pc = m['file'], m['pc']
        else:
            real = placement.get(n, m['home_file'])
            pc = file_to_pc(real, m['kind']) if not m.get('runpc') else m['runpc']
        lines.append('!sec_%s_real = $%06X\t\t; %s' % (n, real, 'RAM' if m['ram'] else
                     ('GamePak' if real < 0x200000 else 'Super NES ROM')))
        lines.append('!sec_%s_pc = $%06X' % (n, pc))
        lines.append('!sec_%s_ram = %d' % (n, 1 if m['ram'] else 0))
        if not m['ram']:   # CPU address of the section's ROM start (_real/_pc are advanced to the section end while assembling; _cpu is not)
            lines.append('!sec_%s_cpu = $%06X' % (n, file_to_pc(real, m['kind']) if m['kind'] != 'fixed' else pc))
    open(path, 'w').write('\n'.join(lines) + '\n')
    # end-of-assembly section positions for the next measurement
    pr = [';', ';\tSECTION END POSITIONS (generated by tools/layout.py), printed with PRINT_LAYOUT', ';']
    for n in meta:
        pr.append('print "SECEND %s ",hex(!sec_%s_real)," ",hex(!sec_%s_pc)' % (n, n, n))
    open(os.path.join(os.path.dirname(path), 'layout_end.inc'), 'w').write('\n'.join(pr) + '\n')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--asar', default=os.environ.get('ASAR', 'asar'), help='asar binary (default $ASAR or asar)')
    ap.add_argument('--report', action='store_true', help='list every placed section')
    a = ap.parse_args()
    meta = load_meta(); regions = load_regions()
    lay = parse_layout(os.path.join(ROOT, 'src', 'layout.inc'))
    if any(n not in lay for n in meta) or not os.path.exists(os.path.join(ROOT, 'src', 'layout_end.inc')):
        # new sections: start from their home positions, then measure
        cur = {n: lay[n]['real'] for n in lay if n in meta and not meta[n]['ram']}
        write_layout(meta, cur, os.path.join(ROOT, 'src', 'layout.inc'))
        lay = parse_layout(os.path.join(ROOT, 'src', 'layout.inc'))
    os.makedirs(os.path.join(ROOT, 'build'), exist_ok=True)
    for it in range(6):
        ends, out = measure(a.asar)
        if not ends:
            print(out.stdout[-3000:], out.stderr[-3000:]); raise SystemExit('measure failed')
        sizes = {}
        for n, (endreal, endpc) in ends.items():
            if n not in meta or meta[n]['ram']: continue
            sizes[n] = endreal - lay[n]['real'] if n in lay else 0
        placement, used = place(meta, sizes, regions)
        old = open(os.path.join(ROOT, 'src', 'layout.inc')).read()
        write_layout(meta, placement, os.path.join(ROOT, 'src', 'layout.inc'))
        new = open(os.path.join(ROOT, 'src', 'layout.inc')).read()
        lay = parse_layout(os.path.join(ROOT, 'src', 'layout.inc'))
        if old == new:
            break
    gp = sum(min(e, GAMEPAK[1]) - s for s, e, n in used if s < GAMEPAK[1])
    sn = sum(e - s for s, e, n in used if s >= GAMEPAK[1])
    top = max(e for s, e, n in used)
    print('layout: %d sections; GamePak ROM %d bytes used, %d free; Super NES ROM %d bytes used; ROM end $%06X'
          % (len(used), gp, GAMEPAK[1] - gp, sn, top))
    if a.report:
        for s, e, n in sorted(used):
            print('  %06X-%06X %6X %s' % (s, e, e - s, n))

if __name__ == '__main__':
    main()
