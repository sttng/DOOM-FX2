#!/usr/bin/env python3
"""
skypng.py - put a 128x128 picture into one of the data set's skies (SKY1-SKY4)

  skypng.py --data data --sky N --png FILE.png

The skies are raw 128x128 strips in fixed places of the wall banks
(wad2gfx.py SKY_AT; the levels pick one with !lvlskyN or by episode).  Each
pixel of the PNG becomes the wall pixel value whose colour (colour map row 0,
read_colour) is nearest to it, among the values the data set's walls use.
The conversions that write the skies (make wadgfx, doom2, shareware) replace
it again, so run this after them, then build.
"""
import argparse, os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import wad2gfx as G   # noqa: E402


def main():
    ap = argparse.ArgumentParser(description='a PNG -> one of the data set\'s skies')
    ap.add_argument('--data', default='data')
    ap.add_argument('--sky', type=int, required=True, choices=range(1, G.NRAW + 1), help='1..%d' % G.NRAW)
    ap.add_argument('--png', required=True)
    a = ap.parse_args()
    rl = os.path.join(a.data, 'RLDATA')
    img = np.array(Image.open(a.png).convert('RGB')).astype(float)
    if img.shape[:2] != (128, 128):
        sys.exit('%s: %dx%d, a sky is 128x128' % (a.png, img.shape[1], img.shape[0]))
    walls, _ = G.read_rldata(rl)
    k = a.sky - 1
    if walls[k].a.shape != (128, 128):
        sys.exit('SKY%d is not stored in this data set (no level uses it)' % a.sky)
    rgb = G.read_colour(rl)
    used = np.array(sorted({int(p) for w in walls[G.NRAW:] for p in np.unique(w.a) if p >= 0}))
    d = ((img[:, :, None, :] - rgb[used][None, None, :, :]) ** 2).sum(-1)
    px = used[d.argmin(-1)]
    err = np.sqrt(d.min(-1))
    bank, off = G.SKY_AT[k]
    fn = os.path.join(rl, 'WALLIMG', 'BANK%02X.DEF' % bank)
    buf = bytearray(open(fn, 'rb').read())
    if len(buf) < off + 0x4000:
        sys.exit('%s: too short for SKY%d' % (fn, a.sky))
    buf[off:off + 0x4000] = px.T[:, ::-1].astype(np.uint8).tobytes()   # column strips, bottom first
    open(fn, 'wb').write(bytes(buf))
    print('SKY%d <- %s: %d colours, nearest SNES colour within %.1f (mean %.1f)' % (
        a.sky, a.png, len(np.unique(px)), err.max(), err.mean()))


if __name__ == '__main__':
    main()
