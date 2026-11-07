"""
musiclib.py -- the FX3 cartridge's music instrument library, and song modules built
from it for the Sculptured SPC700 music driver (MUSIC_D.C)

  Library(md)          instruments, samples and curves of a data set's song modules
  Library.module(...)  a new song module: [(APU dest, bytes)] for add_modules, and its end
  add_modules(md, ...) appends modules to a data set (new chunks, MUSIC_I/MUSIC_L)

The driver's tables are global index spaces; every FX3 song module loads the
entries of the instruments it uses (and the common module 0 those of the sound
effects), so one instrument number means the same instrument in every song:

  $1F00 + 4 s   sample s: BRR start, loop address (DSP sample directory, DIR = $1F00);
                3 bytes before the BRR data: word tuning, byte $60
  $2156 + 2 i   instrument i -> its 6-byte record:
                  0  flags: bit 0 byte 1 is a curve ($221E table), else the level
                        bit 2 byte 3 is a pitch curve ($2292 table)
                        bit 3 byte 4 is a curve ($22BA table), else the pan (0-100)
                        bit 4 DSP patch byte 5 ($22C8 table, 12 voice registers) + echo
                        bit 5 pitch modulation
                  1  level curve# / level   2  sample#   3  pitch curve#
                  4  pan / curve#           5  patch#
  $221C + 2 k   curve k (the level curves are indexed from $221E, i.e. k - 1);
  $2292 + 2 k, $22BA + 2 k   other curves: 8-byte header + steps (position independent)
  $25C4 + 2 n   song n -> song header: byte #tracks, word per track
Module data goes from $6517 (song modules end below the blast buffer, $B807, in a
level; the echo buffer is $EC00-$FBFF).
"""
import collections, struct

SONG_BASE = 0x6517
SMP_HDR = 3                         # bytes before a sample's BRR data: word tuning, byte $60
SONG_END = 0xB807                   # BlastBufferAddress (doommus.asm): a level song ends below it
SMP_T, INS_T, CRV_T, PCRV_T, XCRV_T, SONG_T = 0x1F00, 0x2156, 0x221C, 0x2292, 0x22BA, 0x25C4
TABLES = {'smp': (SMP_T, 4, 0x2080), 'ins': (INS_T, 2, 0x221C), 'crv': (CRV_T, 2, 0x2292),
          'pcrv': (PCRV_T, 2, 0x22BA), 'xcrv': (XCRV_T, 2, 0x22C8), 'song': (SONG_T, 2, 0x2600)}


def brr_len(a, p):
    n = 0
    while True:
        h = a[p + n]; n += 9
        if h & 1:
            return n


class Instrument:
    def __init__(self, num, rec):
        self.num = num; self.rec = bytes(rec)
        f = rec[0]
        self.sample = rec[2]
        self.curves = []                        # (table kind, index)
        if f & 1: self.curves.append(('crv', rec[1] + 1))
        if f & 4: self.curves.append(('pcrv', rec[3]))
        if f & 8: self.curves.append(('xcrv', rec[4]))
        self.pan = None if f & 8 else rec[4]
        self.level = None if f & 1 else rec[1]


class Library:
    """the instruments, samples and curves that the song modules of MD load"""
    def __init__(self, md):
        import rlsong
        self.md = md
        self.ins = {}; self.smp = {}; self.crv = {}      # crv: (kind, idx) -> bytes
        self.used_in = collections.defaultdict(set)      # instrument -> song modules
        for m in range(md.modules()):
            g = md.module(m)
            if not any(SONG_T <= d < SONG_T + 0x40 for d, ch in g):
                continue
            a = md.aram(0, m)
            lo = min(d for d, ch in g if d >= SONG_BASE)
            hi = max(d + sum(len(md.chunk(c)) for c in ch) for d, ch in g if d >= SONG_BASE)
            wrote = collections.defaultdict(set)
            for d, ch in g:
                n = sum(len(md.chunk(c)) for c in ch)
                for k, (base, sz, lim) in TABLES.items():
                    for x in range(max(d, base), min(d + n, lim)):
                        if (x - base) % sz == 0:
                            wrote[k].add((x - base) // sz)
            ptr = {}
            for k in ('ins', 'crv', 'pcrv', 'xcrv', 'song'):
                base, sz, lim = TABLES[k]
                for i in wrote[k]:
                    p = struct.unpack_from('<H', a, base + 2 * i)[0]
                    if lo <= p < hi:
                        ptr[(k, i)] = p
            s = rlsong.Song(md, m)
            starts = sorted(set(ptr.values()) | set(s.tracks)) + [hi]
            ext = lambda p: bytes(a[p:starts[starts.index(p) + 1]])
            for (k, i), p in ptr.items():
                if k == 'ins':
                    ins = Instrument(i, a[p:p + 6])
                    self.ins.setdefault(i, ins); self.used_in[i].add(m)
                elif k != 'song':
                    self.crv.setdefault((k, i), ext(p))
            for i in wrote['smp']:
                p, lp = struct.unpack_from('<HH', a, SMP_T + 4 * i)
                if lo <= p < hi:            # 3-byte header (tuning word, $60) before the BRR
                    self.smp.setdefault(i, (bytes(a[p - SMP_HDR:p + brr_len(a, p)]), lp - p))
        self.common_curves = set()
        a0 = md.aram(0)
        for k in ('crv', 'pcrv', 'xcrv'):
            base, sz, lim = TABLES[k]
            for i in range((lim - base) // sz):
                if struct.unpack_from('<H', a0, base + 2 * i)[0]:
                    self.common_curves.add((k, i))

    def size(self, instruments):
        """bytes of sound RAM the samples, records and curves of INSTRUMENTS take"""
        smp = {self.ins[i].sample for i in instruments}
        crv = {c for i in instruments for c in self.ins[i].curves if c in self.crv}
        return (sum(len(self.smp[s][0]) for s in smp) + 6 * len(instruments) +
                sum(len(self.crv[c]) for c in crv))

    def module(self, instruments, song_number, song_data):
        """a song module: ([(APU dest, bytes)], end address).  SONG_DATA(base) -> bytes
        of the song (header first) assembled for address BASE."""
        instruments = sorted(set(instruments))
        smp = sorted({self.ins[i].sample for i in instruments})
        crv = sorted({c for i in instruments for c in self.ins[i].curves if c in self.crv})
        for i in instruments:
            for c in self.ins[i].curves:
                assert c in self.crv or c in self.common_curves, 'instrument %02X: curve %s missing' % (i, c)
        blob = bytearray(); addr = {}
        for s in smp:
            addr[('smp', s)] = SONG_BASE + len(blob) + SMP_HDR; blob += self.smp[s][0]
        for i in instruments:
            addr[('ins', i)] = SONG_BASE + len(blob); blob += self.ins[i].rec
        for c in crv:
            addr[c] = SONG_BASE + len(blob); blob += self.crv[c]
        song_at = SONG_BASE + len(blob)
        blob += song_data(song_at)
        groups = []

        def table(base, sz, entries):            # contiguous runs of table entries
            for k in sorted(entries):
                groups.append((base + sz * k, entries[k]))
        table(SMP_T, 4, {s: struct.pack('<HH', addr[('smp', s)], addr[('smp', s)] + self.smp[s][1]) for s in smp})
        table(INS_T, 2, {i: struct.pack('<H', addr[('ins', i)]) for i in instruments})
        for kind in ('crv', 'pcrv', 'xcrv'):
            base, sz, lim = TABLES[kind]
            table(base, 2, {c[1]: struct.pack('<H', addr[c]) for c in crv if c[0] == kind})
        table(SONG_T, 2, {song_number: struct.pack('<H', song_at)})
        # merge adjacent table writes into one group each
        merged = []
        for d, b in sorted(groups):
            if merged and merged[-1][0] + len(merged[-1][1]) == d:
                merged[-1] = (merged[-1][0], merged[-1][1] + b)
            else:
                merged.append((d, b))
        merged.append((SONG_BASE, bytes(blob)))
        return merged, SONG_BASE + len(blob)


CHUNK_MAX = 0x4000                  # _MDDeCompBuffer: an RLC chunk unpacks to at most 16 KB


def add_modules(md, modules, at=None):
    """put song modules [(dest, bytes)...] into MD: AT[k] = the module number module k
    replaces (None: a new module after the last); returns the module numbers.  Chunks
    with the same data are shared; MusicData.save() leaves out the chunks no module uses."""
    by_data = {}
    for i in range(len(md.chunks)):
        by_data.setdefault(md.chunk(i), i)
    lists = [md.module(m) for m in range(md.modules())]
    nums = []
    for k, groups in enumerate(modules):
        g2 = []
        for dest, b in groups:
            ch = []
            for o in range(0, len(b), CHUNK_MAX):
                piece = bytes(b[o:o + CHUNK_MAX])
                if piece not in by_data:
                    by_data[piece] = md.new_chunk(piece)
                ch.append(by_data[piece])
            g2.append((dest, ch))
        m = at[k] if at is not None and k < len(at) and at[k] is not None else None
        if m is None:
            m = len(lists); lists.append(g2)
        else:
            lists[m] = g2
        nums.append(m)
    md.set_modules(lists)
    return nums


# --------------------------------------------------------------------------
#   song data assembler
# --------------------------------------------------------------------------
CMD = {'detune': 0xE0, 'voice': 0xE5, 'voice-default': 0xE6, 'sfx-voices': 0xE9, 'key-off': 0xEA,
       'velocity': 0xED, 'end': 0xF0, 'volume-scale': 0xF1, 'volume': 0xF2, 'priority': 0xF3,
       'legato': 0xF4, 'instrument': 0xF5, 'fine': 0xF7, 'loop': 0xF9, 'tempo': 0xFA, 'pan': 0xFB}
WORD_ARGS = {'detune', 'fine'}
RESTS_LONG = ((256, 0xFF), (128, 0xFE), (64, 0xFD), (32, 0xF8))
CALL_BYTES = 12


def rest_bytes(t):
    """a rest of T steps: a short rest ($C0-$DF) first, which keys the note off (the long
    ones, $F8 $FD $FE $FF, only wait), then long rests for the rest"""
    out = bytearray()
    if t <= 0:
        return out
    first = t if t <= 32 else (t % 32 or 32)
    out.append(0xBF + first); t -= first
    while t > 0:
        for n, b in RESTS_LONG:
            if t >= n:
                out.append(b); t -= n; break
    return out


def encode_track(events):
    """events -> (bytes, {event index: byte offset}, [(offset, call event)]).  Events:
      ('note', note, length[, 'abs'])   length 1..255; 'abs': stored without reference to
                                        the note before (a pattern's first note)
      ('rest', steps)                   any length (keys the note before it off)
      ('call', track, from, to, count, transpose, scale)
                                        pattern call: events [from, to) of TRACK, COUNT times
                                        (0 = forever), TRANSPOSE in 1/20 semitone, track
                                        volume * SCALE meanwhile (restored after it); stored
                                        with an instrument list of one $FF (keep the track's)
      ('slide', (bytes...))             pitch slide of the note before (length 1): per byte
                                        hi nibble - 8 = 1/20 semitones, lo nibble = steps to
                                        wait (0: none); 1, n = wait n; ends with $00 (added)
      (command, args...)                see CMD"""
    out = bytearray(); at = {}; prev = None; calls = []
    for k, e in enumerate(events):
        at[k] = len(out)
        kind = e[0]
        if kind == 'note':
            n, ln = e[1], e[2]
            assert 1 <= ln <= 255 and 0 <= n < 128, e
            d = None if prev is None or (len(e) > 3 and e[3] == 'abs') else n - prev
            if d is not None and -8 <= d <= 7 and ln <= 8:
                out.append(((d + 8) << 3) | (ln - 1))
            elif 0x20 <= n <= 0x5F:
                out += bytes((n + 0x60, ln))
            else:
                out += bytes((0xEF, n, ln))
            prev = n
        elif kind == 'rest':
            out += rest_bytes(e[1])
        elif kind == 'slide':
            out += bytes((0xEB,) + tuple(e[1]) + (0,))
        elif kind == 'call':
            calls.append((len(out), e))
            tr = e[5] & 0xFFFF
            # ... skip 1, $FF: the call's instrument list (an instrument command inside the
            # pattern takes its instrument from it; $FF = the track's own, as FX3's calls)
            out += bytes((0xF6, 0, 0, 0, 0, e[4], tr & 0xFF, tr >> 8, int(e[6] * 256) & 0xFF, int(e[6]), 1, 0xFF))
            prev = None                     # (the note state after it is the pattern's: next one absolute)
        else:
            out.append(CMD[kind])
            for v in e[1:]:
                if kind in WORD_ARGS:
                    out += struct.pack('<h', v)
                else:
                    out.append(v & 0xFF)
    at[len(events)] = len(out)
    return out, at, calls


def assemble(tracks, base):
    """song data for address BASE: header (byte #tracks, word per track), the tracks"""
    enc = [encode_track(t) for t in tracks]
    pos = []; p = base + 1 + 2 * len(tracks)
    for b, at, calls in enc:
        pos.append(p); p += len(b)
    out = bytearray([len(tracks)])
    for p in pos:
        out += struct.pack('<H', p)
    for b, at, calls in enc:
        b = bytearray(b)
        for off, e in calls:
            t = e[1]
            struct.pack_into('<HH', b, off + 1, pos[t] + enc[t][1][e[2]], pos[t] + enc[t][1][e[3]])
        out += b
    return bytes(out)


# --------------------------------------------------------------------------
#   repeats -> pattern calls
# --------------------------------------------------------------------------
NO_PATTERN = {'volume', 'loop', 'end', 'call', 'tempo', 'voice', 'sfx-voices'}
MIN_SAVE = 4                        # bytes a call must save
MAX_CANDIDATES = 48                 # earlier copies tried per position (the latest)


def _key(ev, i):
    """position-independent key of events i..i+2 (notes relative to the first one)"""
    base = next((e[1] for e in ev[i:i + 3] if e[0] == 'note'), 0)
    return tuple(('n', e[1] - base, e[2]) if e[0] == 'note' else e for e in ev[i:i + 3])


def _cost(events):
    return len(encode_track(events)[0])


def _match(ev, i, sev, sj, slim, transpose):
    """length of the run ev[i:] = sev[sj:slim] (notes may differ by one constant step)"""
    L = 0; sh = None
    while i + L < len(ev) and sj + L < slim:
        a, b = ev[i + L], sev[sj + L]
        if a[0] in NO_PATTERN or b[0] in NO_PATTERN:
            break
        if a[0] == 'note' and b[0] == 'note':
            if a[2] != b[2]:
                break
            d = a[1] - b[1]
            if sh is None:
                if d and not transpose:
                    break
                sh = d
            elif d != sh:
                break
        elif a[:3] != b[:3] or a != b and a[0] != 'note':
            break
        L += 1
    while L and ev[i + L - 1][0] == 'legato':      # (a legato belongs to the note after it)
        L -= 1
    return L, sh or 0


def compress(tracks, transpose=True, cross=True):
    """replace repeated runs of events by pattern calls of an earlier copy (in the same
    track, or with CROSS any earlier track); a run repeated back to back becomes one call
    with a count.  The copy's first note is then stored absolute (so is the note after a
    call).  Runs with a volume command are never called: a call restores the volume."""
    out = []; lits = []
    index = collections.defaultdict(list)          # key -> [(track, index into out[track])]
    for ti, ev in enumerate(tracks):
        new = []; lit = []; out.append(new); lits.append(lit)
        at = encode_track(ev)[1]                    # byte offsets: what a run costs (approx.)
        i = 0
        while i < len(ev):
            best = None
            if ev[i][0] not in NO_PATTERN and i + 3 <= len(ev) and not (i and ev[i - 1][0] == 'legato'):
                for st, sj in index.get(_key(ev, i), ())[-MAX_CANDIDATES:]:
                    if st != ti and not cross:
                        continue
                    sev, slit = out[st], lits[st]
                    slim = sj
                    while slim < len(sev) and slit[slim]:
                        slim += 1
                    if sj and sev[sj - 1][0] == 'legato':
                        continue
                    L, sh = _match(ev, i, sev, sj, slim, transpose)
                    if L < 2:
                        continue
                    saved = at[i + L] - at[i] - CALL_BYTES - 1
                    if saved >= MIN_SAVE and (best is None or saved > best[0]):
                        best = (saved, st, sj, L, sh)
            if best:
                saved, st, sj, L, sh = best
                count = 1
                while count < 255 and i + (count + 1) * L <= len(ev) and ev[i + count * L:i + (count + 1) * L] == ev[i:i + L]:
                    count += 1
                _mark_abs(out[st], sj, L)
                new.append(('call', st, sj, sj + L, count, sh * 20, 1.0)); lit.append(False)
                i += count * L
            else:
                new.append(ev[i]); lit.append(True)
                k = len(new) - 3
                if k >= 0 and all(lit[k:k + 3]) and new[k][0] not in NO_PATTERN:
                    index[_key(new, k)].append((ti, k))
                i += 1
    return out


def _mark_abs(src, j, L):
    for k in range(j, j + L):
        if src[k][0] == 'note':
            if len(src[k]) < 4:
                src[k] = src[k] + ('abs',)
            return


def expand(tracks, ti, end=None):
    """the events track TI plays, calls expanded (counts 0 as 1; for checking compress)"""
    def run(t, a, b, sh, depth):
        o = []
        for e in tracks[t][a:b]:
            if e[0] == 'call':
                for _ in range(e[4] or 1):
                    o += run(e[1], e[2], e[3], sh + e[5] // 20, depth + 1)
            elif e[0] == 'note':
                o.append(('note', e[1] + sh, e[2]))
            else:
                o.append(e)
        return o
    return run(ti, 0, len(tracks[ti]) if end is None else end, 0, 0)
