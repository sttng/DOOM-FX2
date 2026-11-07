#!/usr/bin/env python3
"""
snescomp.py -- the DOOM-FX DeCompress formats: decompressors and compressors.

The decompressors are ports of the engine's 65816 code (src/engine/comp.asm).

Container ("DeCompress" format):   word TYPE, then type specific data
    TYPE 0  DeCompNone   : word SIZE, SIZE raw bytes
    TYPE 4  UnPackRL     : word SIZE, word N (=stream length+2), bit stream words
                           (stream occupies blob[6 .. 4+N], read backwards)
    TYPE 8  UnPackEclipse: word SIZE, byte STAGGER(=1), packets..., $00
    TYPE 12 UnPackEclipse: word SIZE, byte STAGGER(=2), packets..., $00
    (the ECLIPSE routine decides on the STAGGER byte; 8/12 are just labels)

The RLC bit-stream is also used raw by the music driver (UnPackRL0,
musicdrv.asm): chunk = word SIZE + stream, compressed stream size given separately.

API
    decompress(blob, off=0)          -> (data, consumed_len, type)
    compress(data, method)           -> blob   method: 'none','rlc','eclipse1','eclipse2','best'
    rlc_encode_stream(data)          -> raw RLC bit stream (no header)
    rlc_decode_stream(stream, size)  -> (data, lowest byte offset read)

Both directions are verified against the real 65816 code (tools/datagen/emu65816.py).

usage: snescomp.py {c,d} infile outfile [-m none|rlc|eclipse1|eclipse2|best]
"""
import struct, sys

# ---------------------------------------------------------------------------
#  RLC  (UnPackRL)
# ---------------------------------------------------------------------------

class _BitReader:
    """Reads the RLC bit stream exactly like the 65816 code: words fetched from the END
    of the stream backwards; the first (highest) word carries a sentinel 1 bit above
    its data bits; each further word supplies 16 bits, LSB first."""
    def __init__(self, stream, endpos):
        self.s = stream
        self.p = endpos            # byte index of the word currently loaded
        self.a = self.s[self.p] | (self.s[self.p + 1] << 8)
        self.lowest = self.p
    def _refill(self):
        self.p -= 2
        if self.p < self.lowest: self.lowest = self.p
        w = self.s[self.p] | (self.s[self.p + 1] << 8)
        c = w & 1
        self.a = (w >> 1) | 0x8000
        return c
    def bit(self):
        c = self.a & 1
        self.a >>= 1
        if self.a == 0:
            return self._refill()
        return c
    def bits(self, n):
        v = 0
        for _ in range(n):
            v = (v << 1) | self.bit()
        return v

def rlc_decode_stream(stream, size, endpos=None):
    """Decode a raw RLC stream (as copied to _MDDeCompBuffer2 by UnPackRL0).
    endpos = byte offset of the first-read word (default len(stream)-2).
    Returns (data, lowest_byte_offset_read)."""
    if endpos is None: endpos = len(stream) - 2
    out = bytearray(size)
    br = _BitReader(stream, endpos)
    p = size
    while p > 0:
        if br.bit() == 0:
            if br.bit() == 0:            # %00 nnn : 1-8 literal bytes
                n = br.bits(3) + 1
                for _ in range(n):
                    p -= 1; out[p] = br.bits(8)
            else:                        # %01 oooooooo : copy 2 bytes, 8-bit offset
                off = br.bits(8)
                for _ in range(2):
                    p -= 1; out[p] = out[p + off] if p + off < size else 0
        else:
            t = br.bits(2)
            if t == 3:                   # %111 nnnnnnnn : 9-264 literal bytes
                n = br.bits(8) + 9
                for _ in range(n):
                    p -= 1; out[p] = br.bits(8)
            else:
                if t == 2:               # %110 nnnnnnnn o*12 : 5-260 bytes, 12 bit offset
                    n = br.bits(8) + 5; ob = 12
                else:                    # %100 o*9 : 3 bytes  /  %101 o*10 : 4 bytes
                    n = 3 + t; ob = 9 + t
                off = br.bits(ob)
                for _ in range(n):
                    p -= 1; out[p] = out[p + off] if p + off < size else 0
        if p < 0: raise ValueError('RLC overrun')
    return bytes(out), br.lowest

def _rlc_unpack(blob):
    size, n = struct.unpack_from('<HH', blob, 2)
    # CDPtr points at SIZE word (blob offset 2); first word at 2+n
    data, low = rlc_decode_stream(blob, size, 2 + n)
    return data, 4 + n

class _BitWriter:
    def __init__(self): self.bits = []
    def put(self, v, n):
        for i in range(n - 1, -1, -1): self.bits.append((v >> i) & 1)
    def words(self):
        """-> bytes of the stream in memory order (lowest address first)."""
        b = self.bits
        k = len(b) % 16
        first = 1 << k
        for i in range(k): first |= b[i] << i
        ws = [first]
        i = k
        while i < len(b):
            w = 0
            for j in range(16): w |= b[i + j] << j
            ws.append(w); i += 16
        # ws[0] is read first = highest address
        return b''.join(struct.pack('<H', w) for w in reversed(ws))

def _lcp(r, a, b, lim):
    """common prefix length of r[a:] and r[b:], at most lim"""
    l = 0
    while l + 16 <= lim and r[a + l:a + l + 16] == r[b + l:b + l + 16]: l += 16
    while l < lim and r[a + l] == r[b + l]: l += 1
    return l

def _find_matches(r, maxdist, minlen, maxlen, chain=96):
    """For data r, per position i: list of (dist, len) candidates (nearest first),
    from previous occurrences of the 2-byte prefix."""
    n = len(r)
    head = {}
    prev = [-1] * n
    res = [None] * n
    for i in range(n):
        cands = []
        if i + 2 <= n:
            key = r[i:i + 2]
            j = head.get(key, -1)
            cnt = 0
            lim = min(maxlen, n - i)
            best = 0
            while j >= 0 and i - j <= maxdist and cnt < chain:
                l = _lcp(r, j, i, lim)
                if l >= minlen and (l > best or i - j <= 1023):
                    cands.append((i - j, l))
                    if l > best: best = l
                if best >= lim: break
                j = prev[j]; cnt += 1
            prev[i] = head.get(key, -1)
            head[key] = i
        res[i] = cands
    return res

class _SlideMin:
    """sliding window minimum of values v[j] for j in [t-hi, t-lo]"""
    def __init__(self): 
        import collections
        self.dq = collections.deque()
    def push(self, j, v):
        dq = self.dq
        while dq and dq[-1][1] >= v: dq.pop()
        dq.append((j, v))
    def get(self, jmin):
        dq = self.dq
        while dq and dq[0][0] < jmin: dq.popleft()
        return dq[0] if dq else None

def rlc_encode_stream(data):
    """Optimal-parse RLC encoder. Returns raw stream bytes (memory order); the first-read
    word is the last word.  Decoding: rlc_decode_stream(stream, len(data))."""
    import heapq
    r = bytes(reversed(data))
    n = len(r)
    if n == 0: return struct.pack('<H', 1)
    INF = 1 << 60
    cost = [INF] * (n + 1); cost[0] = 0
    back = [None] * (n + 1)
    matches = _find_matches(r, 4095, 2, 260)
    short = _SlideMin()   # literal runs 1..8   : cost[j] - 8j  for j in [t-8, t-1]
    long_ = _SlideMin()   # literal runs 9..264 : j in [t-264, t-9]
    act = {}              # long matches activation: t -> [(c, end, i, d)]
    heap = []
    for t in range(n + 1):
        if t > 0:
            # pull literal arrivals
            short.push(t - 1, cost[t - 1] - 8 * (t - 1)) if cost[t - 1] < INF else None
            if t - 9 >= 0 and cost[t - 9] < INF: long_.push(t - 9, cost[t - 9] - 8 * (t - 9))
            e = short.get(t - 8)
            if e is not None:
                c = e[1] + 8 * t + 5
                if c < cost[t]: cost[t] = c; back[t] = ('L', t - e[0], 0)
            e = long_.get(t - 264)
            if e is not None:
                c = e[1] + 8 * t + 19
                if c < cost[t]: cost[t] = c; back[t] = ('L', t - e[0], 0)
            # long-match intervals
            for it in act.pop(t, ()): heapq.heappush(heap, it)
            while heap and heap[0][1] < t: heapq.heappop(heap)
            if heap:
                c, end, i, d = heap[0]
                if c < cost[t]: cost[t] = c; back[t] = ('M', t - i, d)
        if t == n: break
        c0 = cost[t]
        if c0 >= INF: continue
        b2 = b3 = b4 = None; bl = (0, 0)
        for d, l in matches[t]:
            if b2 is None and d <= 255: b2 = d
            if b3 is None and l >= 3 and d <= 511: b3 = d
            if b4 is None and l >= 4 and d <= 1023: b4 = d
            if l > bl[0]: bl = (l, d)
        if b2 is not None and c0 + 10 < cost[t + 2]: cost[t + 2] = c0 + 10; back[t + 2] = ('M', 2, b2)
        if b3 is not None and c0 + 12 < cost[t + 3]: cost[t + 3] = c0 + 12; back[t + 3] = ('M', 3, b3)
        if b4 is not None and c0 + 13 < cost[t + 4]: cost[t + 4] = c0 + 13; back[t + 4] = ('M', 4, b4)
        if bl[0] >= 5:
            act.setdefault(t + 5, []).append((c0 + 23, t + bl[0], t, bl[1]))
    ops = []
    i = n
    while i > 0:
        op = back[i]; ops.append(op); i -= op[1]
    ops.reverse()
    bw = _BitWriter()
    pos = 0
    for kind, k, d in ops:
        if kind == 'L':
            while k > 0:     # (k <= 264 always, loop kept for safety)
                kk = min(k, 264)
                if kk <= 8: bw.put(0, 1); bw.put(0, 1); bw.put(kk - 1, 3)
                else: bw.put(1, 1); bw.put(3, 2); bw.put(kk - 9, 8)
                for j in range(kk): bw.put(r[pos + j], 8)
                pos += kk; k -= kk
            continue
        if k == 2: bw.put(0, 1); bw.put(1, 1); bw.put(d, 8)
        elif k == 3 and d <= 511: bw.put(1, 1); bw.put(0, 2); bw.put(d, 9)
        elif k == 4 and d <= 1023: bw.put(1, 1); bw.put(1, 2); bw.put(d, 10)
        else: bw.put(1, 1); bw.put(2, 2); bw.put(k - 5, 8); bw.put(d, 12)
        pos += k
    return bw.words()

def rlc_compress(data):
    s = rlc_encode_stream(data)
    return struct.pack('<HHH', 4, len(data), len(s) + 2) + s

# ---------------------------------------------------------------------------
#  ECLIPSE (UnPackEclipse)
# ---------------------------------------------------------------------------

def _eclipse_unpack(blob, base=2):
    """Faithful port of UnPackEclipse. Works in a 64K scratch 'bank' like the 65816 code."""
    src = base
    length = blob[src] | (blob[src + 1] << 8)
    stagger = blob[src + 2]
    src += 3
    DEST = 0x100
    mem = bytearray(0x10000 + 0x200)
    def rd(i): return blob[i] if i < len(blob) else 0
    if stagger < 2:
        y = DEST + length
        while True:
            c = rd(src)
            if c & 0x80:
                off = ((c & 7) << 8) | rd(src + 1)
                L = (c & 0x78) >> 3
                n = L + 3
                y -= n
                x = y + off + 1
                # word copies in descending order (exactly like PatternCode/PatternOddCode)
                offs = list(range(n - 2, -1, -2)) if n % 2 == 0 else list(range(n - 2, 0, -2)) + [0]
                for o in offs:
                    w0, w1 = mem[x + o], mem[x + o + 1]
                    mem[y + o] = w0; mem[y + o + 1] = w1
                src += 2
            elif c & 0x40:
                L = c & 0x3f
                n = L + 1
                y -= n
                for k in range(n): mem[y + k] = rd(src + 1 + k)
                src += n + 1
            elif c & 0x20:
                off = c & 0x1f
                x = y + off
                y -= 1
                mem[y] = mem[x]
                src += 1
            else:
                L = c & 0x1f
                if L == 0: break
                n = L + 2
                b = rd(src + 1)
                y -= n
                for k in range(n): mem[y + k] = b
                src += 2
        src += 1
        return bytes(mem[DEST:DEST + length]), src - base
    # ---- stagger 2
    top = DEST + length
    y = length + DEST + (1 if (length ^ 1) & 1 else 0)
    halfway = DEST + 1
    while True:
        if y == halfway:
            y = length + DEST + (length & 1)
            halfway = 0
        c = rd(src)
        if c & 0x80:
            off = ((((c & 7) << 8) | rd(src + 1)) << 1) | 1
            L = (c & 0x78) >> 3
            n = L + 3
            y -= 2 * n
            x = y + off + 1
            if x >= top:
                x = x + (1 if (length ^ 1) & 1 else 0) - length
            for k in range(n - 1, -1, -1):
                mem[y + 2 * k] = mem[x + 2 * k]
            src += 2
        elif c & 0x40:
            L = c & 0x3f
            n = L + 1
            y -= 2 * n
            for k in range(n): mem[y + 2 * k] = rd(src + 1 + k)
            src += n + 1
        elif c & 0x20:
            n = (c & 0x1f) + 3
            b = rd(src + 1)
            for k in range(n):
                y -= 2; mem[y] = b; b = (b - 1) & 0xff
            src += 2
        else:
            L = c & 0x1f
            if L == 0: break
            n = L + 2
            b = rd(src + 1)
            y -= 2 * n
            for k in range(n): mem[y + 2 * k] = b
            src += 2
    src += 1
    return bytes(mem[DEST:DEST + length]), src - base

def _ecl_pack(data, stagger):
    """Optimal-parse ECLIPSE packer.  Returns packet bytes (without header / terminator)."""
    n0 = len(data)
    if stagger == 2:
        # virtual stream V = even-offset bytes ascending, then odd-offset bytes ascending
        V = bytes(data[0::2]) + bytes(data[1::2])
        split = (n0 + 1) // 2            # boundary index in V
    else:
        V = bytes(data); split = None
    r = bytes(reversed(V))               # decode order
    n = len(r)
    rsplit = None if split is None else n - split   # in r, ops may not straddle rsplit
    INF = 1 << 60
    cost = [INF] * (n + 1); cost[0] = 0
    back = [None] * (n + 1)
    matches = _find_matches(r, 2048, 3, 18, chain=64)
    def ok(i, k):
        return rsplit is None or not (i < rsplit < i + k)
    for i in range(n):
        c0 = cost[i]
        if c0 >= INF: continue
        # unique run 1..64 : 1+k bytes
        for k in range(1, min(64, n - i) + 1):
            if not ok(i, k): break
            c = c0 + 1 + k
            if c < cost[i + k]: cost[i + k] = c; back[i + k] = ('U', k, 0)
        # run of same byte 3..33 : 2 bytes
        b = r[i]; k = 1
        while i + k < n and k < 33 and r[i + k] == b and ok(i, k + 1): k += 1
        for kk in range(3, k + 1):
            c = c0 + 2
            if c < cost[i + kk]: cost[i + kk] = c; back[i + kk] = ('R', kk, 0)
        if stagger == 2:
            # delta series (in r: decreasing by 1 each step) 3..34 : 2 bytes
            k = 1
            while i + k < n and k < 34 and r[i + k] == (r[i + k - 1] - 1) & 0xff and ok(i, k + 1): k += 1
            for kk in range(3, k + 1):
                c = c0 + 2
                if c < cost[i + kk]: cost[i + kk] = c; back[i + kk] = ('D', kk, 0)
        else:
            # single byte copy from distance 1..32 : 1 byte
            for d in range(1, min(32, i) + 1):
                if r[i - d] == r[i]:
                    c = c0 + 1
                    if c < cost[i + 1]: cost[i + 1] = c; back[i + 1] = ('S', 1, d)
                    break
        # patterns 3..18 : 2 bytes
        bestl = 0; bestd = 0
        for d, l in matches[i]:
            if stagger == 1:
                l = min(l, d)                 # no overlap (word copies)
            elif rsplit is not None and i - d < rsplit:
                l = min(l, rsplit - (i - d))  # source must stay inside one half
            while l > bestl and not ok(i, l): l -= 1
            if l > bestl: bestl, bestd = l, d
        for kk in range(3, min(bestl, 18) + 1):
            c = c0 + 2
            if c < cost[i + kk]: cost[i + kk] = c; back[i + kk] = ('P', kk, bestd)
    ops = []
    i = n
    while i > 0:
        op = back[i]; ops.append(op); i -= op[1]
    ops.reverse()
    out = bytearray()
    pos = 0
    for kind, k, d in ops:
        if kind == 'U':
            out.append(0x40 | (k - 1))
            out += bytes(reversed(r[pos:pos + k]))   # output order (ascending address)
        elif kind == 'R':
            out += bytes((k - 2, r[pos]))
        elif kind == 'D':
            # highest address gets r[pos] (series decreases going down)
            out += bytes((0x20 | (k - 3), r[pos]))
        elif kind == 'S':
            out.append(0x20 | (d - 1))
        elif kind == 'P':
            off = d - 1
            out += bytes((0x80 | ((k - 3) << 3) | (off >> 8), off & 0xff))
        pos += k
    return bytes(out)

def eclipse_compress(data, stagger=1):
    body = _ecl_pack(data, stagger)
    t = 8 if stagger == 1 else 12
    return struct.pack('<HH', t, len(data)) + bytes((stagger,)) + body + b'\x00'

# ---------------------------------------------------------------------------
#  container
# ---------------------------------------------------------------------------

def decompress(blob, off=0):
    """-> (data, consumed_bytes, type)"""
    blob = bytes(blob[off:])
    t = blob[0] | (blob[1] << 8)
    if t == 0:
        size = blob[2] | (blob[3] << 8)
        return blob[4:4 + size], 4 + size, 0
    if t == 4:
        d, l = _rlc_unpack(blob)
        return d, l, 4
    if t in (8, 12):
        d, l = _eclipse_unpack(blob, 2)
        return d, l + 2, t
    raise ValueError('unknown compression type %d' % t)

BEST_METHODS = ('rlc', 'eclipse1', 'none')
# 'eclipse2' (stagger 2) is valid for the engine's and FX3's DeCompress; 'best' tries it
# only with allow_eclipse2=True.

def compress(data, method='best', allow_eclipse2=False):
    data = bytes(data)
    if method == 'none':
        return struct.pack('<HH', 0, len(data)) + data
    if method == 'rlc': return rlc_compress(data)
    if method == 'eclipse1': return eclipse_compress(data, 1)
    if method == 'eclipse2': return eclipse_compress(data, 2)
    if method == 'best':
        ms = BEST_METHODS + (('eclipse2',) if allow_eclipse2 else ())
        cands = [compress(data, m) for m in ms]
        good = []
        for c in cands:
            d, l, t = decompress(c)
            if d == data and l == len(c): good.append(c)
        return min(good, key=len)
    raise ValueError(method)

if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[1])
    ap.add_argument('mode', choices=['c', 'd'])
    ap.add_argument('infile'); ap.add_argument('outfile')
    ap.add_argument('-m', '--method', default='best')
    a = ap.parse_args()
    src = open(a.infile, 'rb').read()
    if a.mode == 'c': open(a.outfile, 'wb').write(compress(src, a.method))
    else: open(a.outfile, 'wb').write(decompress(src)[0])
