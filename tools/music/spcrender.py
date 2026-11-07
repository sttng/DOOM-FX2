#!/usr/bin/env python3
"""
spcrender.py -- render songs of a data set to WAV files through the real SPC700
music driver (tools/music/spcrender/spcrender: blargg's snes_spc from libgme)

  spcrender.py SONG... --out DIR [--data DATA] [--seconds N]

SONG is a number or a name from doommus.asm (e1m1, intro, ...), or 'all'.
Sound RAM: the driver (MUSIC_D.C) at $0700, the common module (0) and the
song's module, as after the game's uploads; then DCOM_RUN (musicdrv.asm) and the
commands of a level start (rllevels.asm): DCOM_ALLOCATION_MODE 1, DCOM_START_SONG,
DCOM_FADEIN $1001.
"""
import argparse, os, re, struct, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))  # (tools/: rlmusic, wad, snescomp)
import rlmusic, rlsong, snescomp as sc      # noqa: E402

RENDER = os.path.join(HERE, 'spcrender', 'spcrender')


def dcom(data):
    out = {}
    for l in open(os.path.join(data, 'RLMUS', 'dcom.i')):
        m = re.match(r'(DCOM_\w+)\s+equ\s+\$([0-9A-Fa-f]+)', l)
        if m:
            out[m.group(1)] = int(m.group(2), 16)
    return out


def ram_image(md, module):
    a = md.aram(0, module)
    drv = sc.decompress(md.driver)[0]
    a[0x0700:0x0700 + len(drv)] = drv
    return bytes(a)


def render(md, data, song, wav, seconds=60, ram=None):
    d = dcom(data)
    img = ram or ram_image(md, song.module)
    tmp = wav + '.ram'
    open(tmp, 'wb').write(img)
    cmds = ['%X:0' % d['DCOM_RUN'], '%X:1' % d['DCOM_ALLOCATION_MODE'],
            '%X:%X' % (d['DCOM_START_SONG'], song.module << 8 | song.number), '%X:1001' % d['DCOM_FADEIN']]
    subprocess.check_call([RENDER, tmp, wav, str(seconds)] + cmds)
    os.remove(tmp)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[1])
    ap.add_argument('songs', nargs='+')
    ap.add_argument('--data', default=os.path.join(HERE, '..', '..', 'data'))
    ap.add_argument('--out', required=True)
    ap.add_argument('--seconds', type=float, default=60)
    a = ap.parse_args()
    if not os.path.exists(RENDER):
        sys.exit('%s missing: run tools/music/spcrender/build.sh <libgme source>' % RENDER)
    md = rlmusic.MusicData(os.path.join(a.data, 'RLDATA', 'MUSIC'))
    names = rlsong.song_names(a.data)
    os.makedirs(a.out, exist_ok=True)
    sel = list(rlsong.songs(md).values()) if a.songs == ['all'] else [rlsong.find(md, a.data, s) for s in a.songs]
    for s in sel:
        fn = os.path.join(a.out, '%02d_%s.wav' % (s.number, names.get(s.number, 'song')))
        render(md, a.data, s, fn, a.seconds)
        print(fn)


if __name__ == '__main__':
    main()
