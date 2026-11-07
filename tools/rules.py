#!/usr/bin/env python3
"""
rules.py - the WAD conversion rules that come with the source (tools/rules/).

The WAD conversions (make wadlevels / wadgfx / wadsfx, doom2, shareware) follow
how the SNES version was made from the PC data: which DOOM texture became which
SNES wall and floor colour (wad2rl.json), the size, offset and scale of every
wall and sprite and the PC -> SNES palette mapping (wad2gfx.json), the rate,
gain and start of every sound effect (wad2soundfx.json).  These rules were
learned once from the FX3 cartridge and DOOM.WAD (wad2rl.py / wad2gfx.py /
wad2soundfx.py learn) and are kept here without the parts that are WAD content:
DOOM's palette (PLAYPAL) and the texture signatures (4x4 colour grids of DOOM's
textures and flats, which match the textures of other WADs to DOOM's).  Those
are computed from the user's DOOM.WAD when the rules are installed.

  rules.py install --wad DOOM.WAD --data DIR [--rules tools/rules]
      write DIR/wad2rl.json, wad2gfx.json, wad2soundfx.json (make data does this)
  rules.py export --data DIR [--rules tools/rules]
      the rules of a data set whose rules were learned (make data LEARN=1) -> tools/rules
  rules.py check --wad DOOM.WAD --data DIR [--rules tools/rules]
      do the installed rules give exactly DIR's (learned) files?
"""
import argparse, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
RULES = os.path.join(HERE, 'rules')
FILES = ('wad2rl.json', 'wad2gfx.json', 'wad2soundfx.json')


def strip(name, d):
    """a learned file -> its rules (no WAD content)"""
    d = dict(d)
    if name == 'wad2rl.json':
        d.pop('sigs', None)
    elif name == 'wad2gfx.json':
        d.pop('wad_playpal', None)
    return d


def complete(name, d, wadpath):
    """rules -> the file the converters read: plus what comes from DOOM.WAD"""
    d = dict(d)
    if name == 'wad2rl.json':
        import wad2rl
        sigs = wad2rl.signatures(wad2rl.Wad(wadpath))
        d['sigs'] = {'walls': {n: [round(v, 1) for v in sigs['walls'][n]] for n in d['walls'] if n in sigs['walls']},
                     'flats': {n: [round(v, 1) for v in sigs['flats'][n]] for n in d['flats'] if n in sigs['flats']}}
    elif name == 'wad2gfx.json':
        import wad2gfx
        d['wad_playpal'] = [int(x) for x in wad2gfx.WadArt([wadpath]).palette.flatten()]
    return d


def write(path, name, d):
    # the converters' own formats (wad2rl.py / wad2gfx.py / wad2soundfx.py learn)
    if name == 'wad2rl.json':
        json.dump(d, open(path, 'w'), indent=1, sort_keys=True)
    elif name == 'wad2gfx.json':
        json.dump(d, open(path, 'w'), indent=0)
    else:
        json.dump(d, open(path, 'w'), indent=1)


def main():
    ap = argparse.ArgumentParser(description='the WAD conversion rules in tools/rules')
    ap.add_argument('cmd', choices=('install', 'export', 'check'))
    ap.add_argument('--data', required=True, help='data set directory')
    ap.add_argument('--wad', help='DOOM.WAD (install, check)')
    ap.add_argument('--rules', default=RULES)
    a = ap.parse_args()
    if a.cmd != 'export' and not a.wad:
        sys.exit('%s needs --wad DOOM.WAD' % a.cmd)
    bad = 0
    for name in FILES:
        if a.cmd == 'export':
            os.makedirs(a.rules, exist_ok=True)
            write(os.path.join(a.rules, name), name, strip(name, json.load(open(os.path.join(a.data, name)))))
            print('%s -> %s' % (os.path.join(a.data, name), os.path.join(a.rules, name)))
            continue
        d = complete(name, json.load(open(os.path.join(a.rules, name))), a.wad)
        if a.cmd == 'install':
            write(os.path.join(a.data, name), name, d)
            print('%s -> %s' % (os.path.join(a.rules, name), os.path.join(a.data, name)))
        else:
            ref = json.load(open(os.path.join(a.data, name)))
            same = json.loads(json.dumps(d)) == ref
            bad += not same
            print('%s: %s' % (name, 'the same' if same else 'DIFFERENT'))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
