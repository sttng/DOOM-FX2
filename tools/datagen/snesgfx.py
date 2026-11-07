"""snesgfx.py - SNES graphics helpers (wad2art.py, menus.py, wad2cut.py, wad2gfx.py, fx3_art.py).

  bgr555_to_rgb(b)           15-bit CGRAM colours -> 8-bit RGB, full range (c << 3 | c >> 2)
  bgr555_to_rgb8(b, n=256)   the same as c << 3 (0-248), as the converters match colours
  rgb_to_bgr555(rgb)         8-bit RGB -> CGRAM bytes
  decode_tile(d, off, bpp)   one 8x8 tile (2/4/8 bpp planar, SNES layout) -> index array
  decode_tiles(d, bpp)       every tile of d
  encode_tile(t, bpp)        8x8 index array -> tile bytes
  render_map(...)            a BG map (16-bit entries: tile, palette, flips) -> PIL image
  render_tiles(...)          a sheet of tiles -> PIL image
"""
import numpy as np
from PIL import Image

def bgr555_to_rgb(pal_bytes):
    n = len(pal_bytes) // 2
    out = []
    for i in range(n):
        v = pal_bytes[2*i] | (pal_bytes[2*i+1] << 8)
        r = (v & 31); g = (v >> 5) & 31; b = (v >> 10) & 31
        out.append(((r << 3) | (r >> 2), (g << 3) | (g >> 2), (b << 3) | (b >> 2)))
    return out

def bgr555_to_rgb8(pal_bytes, n=256):
    """the first n colours, each 5-bit channel << 3 (0-248): the converters' colour matching"""
    out = []
    for i in range(n):
        v = pal_bytes[2 * i] | pal_bytes[2 * i + 1] << 8
        out.append(((v & 31) << 3, (v >> 5 & 31) << 3, (v >> 10 & 31) << 3))
    return out

def rgb_to_bgr555(rgb):
    out = bytearray()
    for r, g, b in rgb:
        v = (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)
        out += bytes((v & 0xff, v >> 8))
    return bytes(out)

def decode_tile(data, off, bpp):
    """return 8x8 numpy array of colour indices"""
    t = np.zeros((8, 8), np.uint8)
    for y in range(8):
        for p in range(bpp):
            pair = p // 2
            b = data[off + pair * 16 + y * 2 + (p & 1)] if off + pair * 16 + y * 2 + (p & 1) < len(data) else 0
            for x in range(8):
                if b & (0x80 >> x): t[y, x] |= (1 << p)
    return t

def decode_tiles(data, bpp):
    sz = 8 * bpp
    return [decode_tile(data, i * sz, bpp) for i in range(len(data) // sz)]

def encode_tile(t, bpp):
    out = bytearray(8 * bpp)
    for y in range(8):
        for p in range(bpp):
            pair = p // 2
            b = 0
            for x in range(8):
                if t[y][x] & (1 << p): b |= 0x80 >> x
            out[pair * 16 + y * 2 + (p & 1)] = b
    return bytes(out)

def render_map(chars, mapdata, pal, bpp, w=32, h=None, tile_base=0, pal_base=0):
    """chars: raw char data (VRAM from tile_base). mapdata: 16-bit entries. pal: list of RGB (256)."""
    tiles = decode_tiles(chars, bpp)
    n = len(mapdata) // 2
    if h is None: h = n // w
    img = np.zeros((h * 8, w * 8, 3), np.uint8)
    for i in range(min(n, w * h)):
        e = mapdata[2*i] | (mapdata[2*i+1] << 8)
        tn = (e & 0x3ff) - tile_base; pn = (e >> 10) & 7
        hf = e & 0x4000; vf = e & 0x8000
        if not (0 <= tn < len(tiles)): continue
        t = tiles[tn]
        if hf: t = t[:, ::-1]
        if vf: t = t[::-1, :]
        base = 0 if bpp == 8 else pal_base + pn * (1 << bpp)
        y, x = divmod(i, w)
        for yy in range(8):
            for xx in range(8):
                c = int(t[yy, xx])
                img[y*8+yy, x*8+xx] = pal[(base + c) % len(pal)] if c or bpp == 8 else pal[0]
    return Image.fromarray(img)

def render_tiles(chars, pal, bpp, cols=16, palno=0, scale=1):
    tiles = decode_tiles(chars, bpp)
    rows = (len(tiles) + cols - 1) // cols
    img = np.zeros((max(rows,1) * 8, cols * 8, 3), np.uint8)
    for i, t in enumerate(tiles):
        y, x = divmod(i, cols)
        for yy in range(8):
            for xx in range(8):
                img[y*8+yy, x*8+xx] = pal[(palno * (1 << bpp) + int(t[yy, xx])) % len(pal)] if pal else (t[yy, xx] * (255 // ((1 << bpp) - 1)),) * 3
    im = Image.fromarray(img)
    if scale > 1: im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    return im

