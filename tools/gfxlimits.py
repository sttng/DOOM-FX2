#!/usr/bin/env python3
"""gfxlimits.py -- check walls and sprites (data/RLDATA) against what the engine handles.

  python3 tools/gfxlimits.py [--data data] [--strict]     (exit 1 on an error)

wad2gfx.py calls check() after writing (strict); tools/build.sh runs it (not strict).

Walls (WALLS.TBL/.DAT, strips in WALLIMG/BANKxx.DEF):
  * height even, a power of two, at most 128: the height byte carries the "pegged"
    flag in bit 0 and the texture wraps vertically with AND (height-1)
    (rltracew3.asm _RLAWP5800);
  * width a power of two, at most 256: the column is AND (width-1) (rltracew5.asm);
  * each strip: no $00 control byte (a 0-pixel run: the drawer loops forever),
    exactly `height` pixels, inside its bank (the GSU's ROM pointer wraps within
    a bank, into its lower half);
  * what follows a strip must keep the drawer going when it reads a little past the
    end (scaling can take one or two texels more): runs, no $00 control bytes, for
    at least OVERRUN pixels (wad2gfx.py ends each bank with 4 runs of 128).
Sprites (IMAGES.TBL/.DAT): every column decodes inside its bank with its end mark.
Banks: only the GamePak wall banks the engine maps ($01-$0D, $18-$1F; DOOM II also $36, $37, $3A, $3B, $3F;
--masked-banks: $3C, $39, $29, $23, $27, $2B).
Wall format 2 (run-length strips; RLDATA/WALLS/WALLS.FMT exists): a third header byte, the
column step 12/6/3 (+ $80: half height, each strip holds height/2 texels); the modulo has
the low 0/1/2 bits clear; TEXTURE2.TBL holds wall indexes.
Wall format 3 (VQ walls; WALLS.FMT "3", wad2gfx.py --vq, tools/wallvq.py): 9 byte headers
(height, modulo, flags $80 half size, bank, codebook, indices, index bytes per block
column); a wall's codebook (2048 bytes) and indices inside its bank, the block column
offset within the engine's 8x8 bit multiply.
"""
import argparse, os, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
# the wall/sprite banks (also wad2gfx.py's): the cartridge's, then those of the WAD conversions
EXTRA_BANKS = [0x36, 0x37, 0x3A, 0x3B]                     # wad2gfx.py --extra-banks (DOOM II)
BANK_3F = 0x3F                                             # --map-walls --bank-3f (DOOM II)
MASKED_BANKS = [0x3C, 0x39, 0x29, 0x23, 0x27, 0x2B]        # --masked-banks (TNT, Plutonia): banks without code
BANKS = list(range(0x01, 0x0E)) + list(range(0x18, 0x20)) + EXTRA_BANKS + [BANK_3F] + MASKED_BANKS
NRAW = 4                       # SKY1-SKY4: raw 128x128 pictures, not RLE
OVERRUN = 16                   # texels a strip must survive being read past


def pow2(n):
    return n > 0 and n & (n - 1) == 0


def wall_ok_after(buf, p, need):
    """decode `need` pixels of wall RLE from p; None if fine, else the reason"""
    got = 0
    while got < need:
        if p >= len(buf):
            return 'reaches the end of the bank'
        c = buf[p]; p += 1
        if c == 0:
            return '$00 control byte'
        if c < 0x80:
            got += c; p += c
        else:
            got += 256 - c; p += 1
    return None


def check(data, strict=True):
    """(errors, warnings); STRICT: a strip not safe to read past is an error, else a warning"""
    rl = os.path.join(data, 'RLDATA')
    banks = {}
    for b in BANKS:
        f = os.path.join(rl, 'WALLIMG', 'BANK%02X.DEF' % b)
        banks[b] = open(f, 'rb').read() if os.path.exists(f) else b''
    err, warn = [], []

    fmt2 = os.path.exists(os.path.join(rl, 'WALLS', 'WALLS.FMT'))
    fmt3 = fmt2 and open(os.path.join(rl, 'WALLS', 'WALLS.FMT'), 'rb').read()[:1] == b'3'

    def strip_ptr(dat, o, x, hd=2):
        lo, hi, b = dat[o + hd + 3 * x:o + hd + 3 + 3 * x]
        return b, lo | hi << 8

    # walls
    tbl = open(os.path.join(rl, 'WALLS', 'WALLS.TBL'), 'rb').read()
    dat = open(os.path.join(rl, 'WALLS', 'WALLS.DAT'), 'rb').read()
    nw = len(tbl) // 2
    xl = os.path.join(rl, 'WALLS', 'TEXTURE2.TBL')
    if os.path.exists(xl):
        x = open(xl, 'rb').read()
        if len(x) // 2 != nw:
            err.append('TEXTURE2.TBL has %d entries, WALLS.TBL %d' % (len(x) // 2, nw))
        bad = [v for v in struct.unpack('<%dH' % (len(x) // 2), x) if (v >= nw if fmt2 else v >= 2 * nw or v & 1)]
        if bad:
            err.append('TEXTURE2.TBL: wall codes out of range: %s' % bad[:8])
    def check3(wi, nm, dat, o, h, w):
        """wall format 3 (tools/wallvq.py): header h, modulo, flags, bank, codebook, indices, rowbytes"""
        if not (pow2(h) and h <= 128):
            err.append('%s: height %d (a power of two up to 128)' % (nm, h))
        if not (pow2(w) and w <= 256):
            err.append('%s: width %d (a power of two up to 256)' % (nm, w))
        fl, b = dat[o + 2], dat[o + 3]
        if b not in banks:
            err.append('%s: bank $%02X is not a wall bank' % (nm, b)); return
        if wi < NRAW:
            if fl & 0x80:
                err.append('%s: a sky picture at half size' % nm)
            return
        if fl & 0x7F:
            err.append('%s: flags $%02X' % (nm, fl))
        half = fl & 0x80
        if half and (h < 8 or w < 4):
            err.append('%s: %dx%d at half size' % (nm, w, h))
        hs, ws = (h >> 1, w >> 1) if half else (h, w)
        cb, ix, rb = dat[o + 4] | dat[o + 5] << 8, dat[o + 6] | dat[o + 7] << 8, dat[o + 8]
        n = len(banks[b])
        if rb != -(-hs // 4):
            err.append('%s: %d index bytes per block column, height %d' % (nm, rb, hs))
        if cb < 0x8000 or cb - 0x8000 + 2048 > n:
            err.append('%s: codebook $%02X:%04X not inside its bank' % (nm, b, cb))
        nbx = -(-ws // 2)
        if ix < 0x8000 or ix - 0x8000 + nbx * rb > n:
            err.append('%s: indices $%02X:%04X not inside its bank' % (nm, b, ix))
        if (nbx - 1) * rb > 255 * 255 or nbx > 128 or rb > 32:
            err.append('%s: block column offset beyond the 8x8 bit multiply' % nm)

    unsafe = 0
    for wi in range(nw):
        o = struct.unpack_from('<H', tbl, 2 * wi)[0]
        h, w = dat[o], dat[o + 1] + 1
        nm = 'wall %d' % wi
        if fmt3:
            check3(wi, nm, dat, o, h, w)
            continue
        hd, ncol, hs = 2, w, h
        if fmt2:
            hd, st = 3, dat[o + 2] & 0x7F
            if dat[o + 2] & 0x80:
                hs = h >> 1
                if wi < NRAW:
                    err.append('%s: a sky picture at half height' % nm)
            sh = {12: 0, 6: 1, 3: 2}.get(st)
            if sh is None or dat[o + 1] & ((1 << sh) - 1):
                err.append('%s: column step %d with modulo $%02X' % (nm, st, dat[o + 1])); continue
            w = (dat[o + 1] | ((1 << sh) - 1)) + 1
            ncol = w >> sh
        if not (pow2(h) and h <= 128):
            err.append('%s: height %d (a power of two up to 128)' % (nm, h))
        if not (pow2(w) and w <= 256):
            err.append('%s: width %d (a power of two up to 256)' % (nm, w))
        for x in range(ncol):
            b, ad = strip_ptr(dat, o, x, hd)
            if b not in banks or ad < 0x8000:
                err.append('%s column %d: $%02X:%04X is not in a wall bank' % (nm, x, b, ad)); break
            buf, p = banks[b], ad - 0x8000
            if wi < NRAW:
                if p + h > len(buf):
                    err.append('%s column %d runs past its bank' % (nm, x)); break
                continue
            got, q = 0, p
            while got < hs:
                if q >= len(buf):
                    err.append('%s column %d runs past its bank' % (nm, x)); got = -1; break
                c = buf[q]; q += 1
                if c == 0:
                    err.append('%s column %d: $00 control byte at $%02X:%04X' % (nm, x, b, q - 1 + 0x8000)); got = -1; break
                got += c if c < 0x80 else 256 - c
                q += c if c < 0x80 else 1
            if got < 0:
                break
            if got != hs:
                err.append('%s column %d decodes to %d pixels, not %d' % (nm, x, got, hs)); break
            why = wall_ok_after(buf, q, OVERRUN)
            if why:
                unsafe += 1
                if unsafe <= 5:
                    (err if strict else warn).append('%s column %d ($%02X:%04X): read past its end it %s' % (nm, x, b, ad, why))
    if unsafe > 5:
        (err if strict else warn).append('... %d wall columns in all are not safe to read past their end' % unsafe)

    # sprites
    tbl = open(os.path.join(rl, 'IMAGES', 'IMAGES.TBL'), 'rb').read()
    dat = open(os.path.join(rl, 'IMAGES', 'IMAGES.DAT'), 'rb').read()
    for ii in range(len(tbl) // 2):
        o = struct.unpack_from('<H', tbl, 2 * ii)[0]
        h, w = dat[o], dat[o + 1]
        if not h or not w:
            err.append('image %d: %dx%d' % (ii, w, h)); continue
        for x in range(w):
            b, ad = strip_ptr(dat, o, x)
            if b not in banks or ad < 0x8000:
                err.append('image %d column %d: $%02X:%04X is not in a wall bank' % (ii, x, b, ad)); break
            buf, p, got = banks[b], ad - 0x8000, 0
            while got < h:                              # (fx3_gfx.image_strip_len: ends at the
                if p >= len(buf):                       #  height or at 0,0)
                    err.append('image %d column %d runs past its bank' % (ii, x)); got = -1; break
                c = buf[p]; p += 1
                if c:
                    got += 1; continue
                if p >= len(buf):
                    err.append('image %d column %d runs past its bank' % (ii, x)); got = -1; break
                n = buf[p]; p += 1
                if n == 0:
                    break
                got += n if n < 0x80 else 256 - n
                p += 0 if n < 0x80 else 1
            if got > h:
                err.append('image %d column %d: %d pixels, height %d' % (ii, x, got, h)); break
            if got < 0:
                break
    return err, warn


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--data', default=os.path.join(HERE, '..', 'data'))
    ap.add_argument('--strict', action='store_true',
                    help='strips not safe to read past their end are errors (the cartridge has 24)')
    a = ap.parse_args()
    err, warn = check(a.data, a.strict)
    for w in warn:
        print('gfxlimits: warning:', w)
    for e in err:
        print('gfxlimits: ERROR:', e)
    if err:
        sys.exit(1)
    print('gfxlimits: walls and sprites within the engine limits')


if __name__ == '__main__':
    main()
