"""brr.py - BRR, the S-DSP's sample format, with the S-DSP's own arithmetic
(wad2soundfx.py).

  decode(b, p1=0, p2=0)            whole 9-byte blocks -> int16 samples, up to the
                                   block with the end flag; p1/p2: the filter history
  encode(pcm, end=True, loop=False) int16 samples -> BRR, padded to 16 samples; each
                                   block gets the shift and filter with the least error
                                   (filter 0 for the first: the DSP may start with any
                                   history)

A block is a header byte (shift << 4 | filter << 2 | loop << 1 | end) and 16
4-bit samples, high nibble first.
"""
import numpy as np

def _clamp16(v):
    return -32768 if v < -32768 else 32767 if v > 32767 else v


def _pred(f, p1, p2):
    """S-DSP filter on the last two outputs (16-bit, i.e. after the decoder's <<1)"""
    if f == 0:
        return 0
    q2 = p2 >> 1
    if f == 1:
        return (p1 >> 1) + ((-p1) >> 5)
    if f == 2:
        return p1 - q2 + (q2 >> 4) + ((p1 * -3) >> 6)
    return p1 - q2 + ((p1 * -13) >> 7) + ((q2 * 3) >> 4)


def decode(b, p1=0, p2=0):
    """BRR bytes (whole 9-byte blocks) -> int16 numpy array (S-DSP arithmetic)"""
    out = []
    for o in range(0, len(b) - len(b) % 9, 9):
        h = b[o]; sh = h >> 4; f = (h >> 2) & 3
        for i in range(16):
            n = b[o + 1 + i // 2]
            n = (n >> 4) if i % 2 == 0 else (n & 15)
            if n >= 8:
                n -= 16
            s = (n << sh) >> 1 if sh <= 12 else (-2048 if n < 0 else 0)
            s = _clamp16(s + _pred(f, p1, p2))
            s = ((s << 1) & 0xFFFF)
            s = s - 0x10000 if s >= 0x8000 else s
            p2, p1 = p1, s
            out.append(s)
        if h & 1:
            break
    return np.array(out, dtype=np.int16)


def _block(x, p1, p2):
    """best (err, shift, filter, nibbles, p1, p2) for 16 target samples x (int16,
    the decoder's output scale), starting from history p1/p2"""
    best = None
    for f in range(4):
        for sh in range(13):
            q1, q2, err, nib = p1, p2, 0, []
            for i in range(16):
                pred = _pred(f, q1, q2)
                # target before the final <<1 of the decoder
                t = (x[i] >> 1) - pred
                n = int(round(t * 2 / (1 << sh))) if sh else int(round(t * 2))
                n = max(-8, min(7, n))
                s = _clamp16(((n << sh) >> 1) + pred)
                s = (s << 1) & 0xFFFF
                s = s - 0x10000 if s >= 0x8000 else s
                err += (s - x[i]) ** 2
                if best is not None and err >= best[0]:
                    break
                nib.append(n & 15)
                q2, q1 = q1, s
            else:
                if best is None or err < best[0]:
                    best = (err, sh, f, nib, q1, q2)
    return best


def encode(pcm, end=True, loop=False):
    """int16 samples -> BRR bytes (zero-padded to a multiple of 16 samples).
    end/loop set the header end/loop flags.  The first block uses filter 0
    (the DSP may start a sample with any history)."""
    x = [int(v) for v in pcm]
    x += [0] * (-len(x) % 16)
    if not x:
        x = [0] * 16
    out = bytearray(); p1 = p2 = 0
    for b in range(len(x) // 16):
        blk = x[16 * b:16 * b + 16]
        if b == 0:
            # filter 0 only
            best = None
            for sh in range(13):
                err, nib = 0, []
                for v in blk:
                    n = max(-8, min(7, int(round((v >> 1) * 2 / (1 << sh))) if sh else int(round(v))))
                    s = _clamp16((n << sh) >> 1); s = (s << 1) & 0xFFFF; s = s - 0x10000 if s >= 0x8000 else s
                    err += (s - v) ** 2; nib.append(n & 15)
                if best is None or err < best[0]:
                    best = (err, sh, 0, nib)
            err, sh, f, nib = best
            dec = decode(bytes([sh << 4]) + bytes((nib[2 * i] << 4) | nib[2 * i + 1] for i in range(8)))
            p1, p2 = int(dec[15]), int(dec[14])
        else:
            err, sh, f, nib, p1, p2 = _block(blk, p1, p2)
        h = (sh << 4) | (f << 2)
        last = b == len(x) // 16 - 1
        if last and end:
            h |= 1
        if loop:
            h |= 2
        out.append(h)
        out += bytes((nib[2 * i] << 4) | nib[2 * i + 1] for i in range(8))
    return bytes(out)
