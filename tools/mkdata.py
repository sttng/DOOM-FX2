#!/usr/bin/env python3
"""
mkdata.py -- regenerate a complete data set directory (the directory `data` points
at: RLDATA/, RLLEV/, RLMUS/, SRC/) from the user's own copies of the games, so the
repository can be shipped without any copyrighted game data.

  python3 tools/mkdata.py --fx3 "THE ULTIMATE DOOM.sfc" --wad DOOM.WAD \\
          --out DIR [--src DIR] [--verify] [--cache DIR] [--compare REFDIR]

Inputs
  --fx3    THE ULTIMATE DOOM FX3 cartridge (4 MB) art, music, walls, levels, song/effect numbers
  --wad    DOOM.WAD                               PLAY* sprites, slot menu font (menus.py
                                                 build), the WAD conversion rules below
  --src    DOOM-FX source directory               WallList, ImageList, TextureList2,
                                                 rlsound3.a, *.bin tables
           (default tools/doomfx-src: copies of these files from the GPL source release)

The data set: "The Ultimate DOOM" content for this port's engine (gamedata-fx3): RLDATA art and
music (datagen/fx3_art.py, fx3_music.py), walls/images/colour (fx3_gfx.py),
RLLEV (fx3_convert_levels.py), RLMUS (datagen/rlmus.py), SRC tables, placeholders,
menus (menus.py build, retouch).  For the WAD conversions it also gets a copy of the
FX3 data and the rules learnt from the WAD:
  RLLEV.fx3   wad2rl.json       levels               make wadlevels (wad2rl.py, wadlevels.py)
  RLGFX.fx3   wad2gfx.json      walls, sprites       make wadgfx    (wad2gfx.py)
  RLART.fx3   wad2art.json      title, menus, fonts  make wadart    (wad2art.py)
  RLMUSIC.fx3 wad2soundfx.json  sound effects        make wadsfx    (wad2soundfx.py)

--verify   also unpack every DeCompress blob / music chunk written with the FX3
           cartridge's own 65816 DeCompress under emulation (slow)
--cache    directory for memoised FX3 decompressions (speeds up repeated runs)
--compare  compare the result recursively with a reference directory
"""
import argparse, filecmp, os, shutil, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from datagen import rlmus                                             # noqa: E402

FX3_SIZE = 4 * 1024 * 1024

# zero-filled files that no game provides (the engine incbins them)
PLACEHOLDERS_COMMON = {
    'RLDATA/FLOORS/FLOORS.DEF': 0,
    'RLDATA/WALLS/TEXTURE.TBL': 0,
    'RLDATA/WALLS/TEXTURE.DAT': 0,
    'SRC/SysDate': 0,
}
PLACEHOLDERS_FX3 = dict(
    {'RLDATA/COMP/%s' % n: 0 for n in (
        'Logo.def0', 'Logo.map0', 'Logo.rgb', 'Logo3.def0', 'Logo3.map0', 'Logo3.rgb',
        'Logo4.def0', 'Logo4.map0', 'Logo4.rgb', 'SCULPT.def', 'SCULPT.map')},
    **{'RLDATA/COMP/SCULPT.rgb': 16 * 4 * 2})
SRC_TABLES = ('InverseTable.bin', 'RandomTable.bin')     # copied from the DOOM-FX source
DOOMFX_SRC = os.path.join(HERE, 'doomfx-src')            # the files of the source release we need



def log(*a):
    print(*a, flush=True)


def placeholders(out, table):
    for rel, n in table.items():
        p = os.path.join(out, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, 'wb').write(bytes(n))


def run(*cmd):
    subprocess.check_call([sys.executable] + [str(c) for c in cmd], stdout=subprocess.DEVNULL)


def build(a, fx3, verifier):
    from datagen import fx3_art
    from datagen.fx3dec import FX3Decoder
    out = a.out
    t = time.time()
    log('[fx3] RLMUS (song/effect numbers), SRC tables and placeholders')
    rlmus.write(fx3, os.path.join(a.src, 'rlsound3.a'), os.path.join(out, 'RLMUS'))
    os.makedirs(os.path.join(out, 'SRC'), exist_ok=True)
    for f in SRC_TABLES:
        shutil.copyfile(os.path.join(a.src, f), os.path.join(out, 'SRC', f))
    placeholders(out, PLACEHOLDERS_COMMON)
    placeholders(out, PLACEHOLDERS_FX3)
    log('[fx3] FX3 art, intermission/title pictures (requantised), music')
    dec = FX3Decoder(fx3, a.cache)
    fx3_art.build(fx3, dec, out, verifier, log=log)
    log('  (%.1fs)' % (time.time() - t)); t = time.time()
    log('[fx3] walls/images/colour (fx3_gfx.py)')
    run(os.path.join(HERE, 'fx3_gfx.py'), '--rom', a.fx3, '--src', a.src,
        '--wad', a.wad, '--out', out)
    log('[fx3] levels (fx3_convert_levels.py)')
    run(os.path.join(HERE, 'fx3_convert_levels.py'), a.fx3, os.path.join(out, 'RLLEV'))
    # a copy of the FX3 levels (tools/wadlevels.py starts from it) and the FX3
    # wall/floor numbers of the WAD's texture names (tools/wad2rl.py learn)
    shutil.copytree(os.path.join(out, 'RLLEV'), os.path.join(out, 'RLLEV.fx3'))
    log('[fx3] WAD -> FX3 texture tables (wad2rl.py learn)')
    run(os.path.join(HERE, 'wad2rl.py'), 'learn', '--wad', a.wad, '--ref', os.path.join(out, 'RLLEV'),
        '--out', os.path.join(out, 'wad2rl.json'))
    # rules for walls/sprites from the WAD (tools/wad2gfx.py learn: wad2gfx.json,
    # and RLGFX.fx3, a copy of the cartridge graphics); `make wadgfx WAD=...`
    log('[fx3] WAD -> SNES graphics rules (wad2gfx.py learn)')
    run(os.path.join(HERE, 'wad2gfx.py'), 'learn', '--data', out, '--wad', a.wad, '--src', a.src)
    # rules for sound effects from the WAD (tools/wad2soundfx.py learn: wad2soundfx.json,
    # and RLMUSIC.fx3, a copy of the cartridge sound data); `make wadsfx WAD=...`
    log('[fx3] WAD -> SNES sound effect rules (wad2soundfx.py learn)')
    run(os.path.join(HERE, 'wad2soundfx.py'), 'learn', '--data', out, '--wad', a.wad)
    log('  (%.1fs)' % (time.time() - t))


def compare(out, ref):
    bad, missing, extra, same = [], [], [], 0
    for root, dirs, files in os.walk(ref):
        for f in files:
            r = os.path.join(root, f); rel = os.path.relpath(r, ref); o = os.path.join(out, rel)
            if not os.path.exists(o):
                missing.append(rel)
            elif filecmp.cmp(r, o, shallow=False):
                same += 1
            else:
                bad.append(rel)
    for root, dirs, files in os.walk(out):
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), out)
            if not os.path.exists(os.path.join(ref, rel)):
                extra.append(rel)
    log('compare with %s: %d identical, %d differ, %d missing, %d extra' % (ref, same, len(bad), len(missing), len(extra)))
    for k, l in (('DIFFERS', bad), ('MISSING', missing), ('EXTRA', extra)):
        for rel in sorted(l):
            log('  %s %s' % (k, rel))
    return not (bad or missing or extra)


def main():
    ap = argparse.ArgumentParser(description='regenerate a DOOM data set from the original game files')
    ap.add_argument('--fx3', required=True, help='THE ULTIMATE DOOM.sfc (FX3, 4 MB)')
    ap.add_argument('--wad', required=True, help='DOOM.WAD')
    ap.add_argument('--src', default=DOOMFX_SRC,
                    help='DOOM-FX source directory (WallList, ...; default tools/doomfx-src)')
    ap.add_argument('--out', required=True, help='output data set directory (replaced)')
    ap.add_argument('--verify', action='store_true', help='65816-emulated check of every packed blob (slow)')
    ap.add_argument('--cache', help='cache directory for FX3 decompressions')
    ap.add_argument('--compare', help='reference data set to compare the result with')
    a = ap.parse_args()
    t0 = time.time()
    fx3 = open(a.fx3, 'rb').read()
    if len(fx3) != FX3_SIZE: sys.exit('%s: expected the 4 MB FX3 ROM' % a.fx3)
    for f in ('WallList', 'ImageList', 'TextureList2', 'rlsound3.a') + SRC_TABLES:
        if not os.path.exists(os.path.join(a.src, f)):
            sys.exit('%s: %s missing (need the DOOM-FX source directory)' % (a.src, f))
    verifier = None
    if a.verify:
        from datagen.fx3dec import FX3Verifier
        verifier = FX3Verifier(fx3)
    if os.path.exists(a.out):
        shutil.rmtree(a.out)
    os.makedirs(a.out)
    build(a, fx3, verifier)
    log('[fx3] menus (menus.py build)')
    run(os.path.join(HERE, 'menus.py'), 'build', a.out, a.wad)
    # title/menus/fonts from a WAD (tools/wad2art.py learn: RLART.fx3 + wad2art.json)
    log('[fx3] title/menu layout (wad2art.py learn)')
    run(os.path.join(HERE, 'wad2art.py'), 'learn', '--data', a.out)
    log('[fx3] retouched Pause/Save/Load menus (menus.py retouch)')
    run(os.path.join(HERE, 'menus.py'), 'retouch', '--data', a.out)
    log('done: data set in %s (%.1fs)' % (a.out, time.time() - t0))
    if a.compare and not compare(a.out, a.compare):
        sys.exit(1)


if __name__ == '__main__':
    main()
