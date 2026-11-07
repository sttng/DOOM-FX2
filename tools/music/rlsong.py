#!/usr/bin/env python3
"""
rlsong.py -- the song format of the Sculptured SPC music driver (DOOM-FX)

  list     songs of the data set: module, header, tracks, instruments, size
  dump     one song as a readable listing (events per track)
  midi     songs as MIDI files (one track per driver track)
  compare  each song against the MUS lumps of a WAD: matching notes and timing

usage: rlsong.py list    [--data DATA]
       rlsong.py dump    SONG [--data DATA]
       rlsong.py midi    [SONG...] --out DIR [--data DATA]
       rlsong.py compare --wad DOOM.WAD [--data DATA]

SONG is a number or a name from doommus.asm (e1m1, intro, ...).

Format (decoded from the driver, MUSIC_D.C at APU $0700; see README "Song format"):

  song module   chunks loaded into sound RAM: song data + BRR samples from $6517,
                and entries of the driver's tables: sample table $1F00 (4 bytes:
                start, loop), instrument pointers $2156, envelope tables $221C/$221E,
                song pointer $25C4 + 2 * song#
  song header   byte #tracks, then a word per track: start address
  track         a byte stream, read per sequencer tick:
    $00-$7F     note: previous note + (b >> 3) - 8, length (b & 7) + 1 ticks
    $80-$BF     note b - $60, length = next byte
    $C0-$DF     rest b - $BF ticks (key off)
    $E0-$FF     command (table at $1C37), see CMDS
  notes         MIDI note numbers (the songs are DOOM's MUS note data); the
                driver's pitch is note * 20 - 900 (+ transposes, in 1/20 semitone)
  timing        timer 1 at 50 Hz; each tick adds the tempo ($FA, 0 = 256) to an
                8-bit accumulator, the sequencer steps on carry: 50 * tempo / 256
                steps per second
"""
import argparse, collections, os, re, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))  # (tools/: rlmusic, wad, snescomp)
import rlmusic                          # noqa: E402
from wad import directory as wadlumps   # noqa: E402

SONGPTR = 0x25C4
TABLES = 0x1EE0                         # driver table pointers (table# * 2)
INSTR = 0x2156
SAMPLES = 0x1F00
NOTE0, PITCH_PER_NOTE = 45, 20

# command: (#argument bytes, name, meaning)
CMDS = {
    0xE0: (2, 'detune', 'word added to the voice pitch ($015B)'),
    0xE1: (1, 'env1', 'envelope override ($0316 -> $0F)'),
    0xE2: (1, 'env2', 'envelope override ($0352 -> $11)'),
    0xE3: (1, 'env3', 'envelope override ($033E -> $0E)'),
    0xE4: (1, 'env4', 'envelope override ($032A -> $10)'),
    0xE5: (3, 'voice', 'voice allocation: flags, voice#, voice bit'),
    0xE6: (0, 'voice-default', 'default voice allocation'),
    0xE7: (0, 'reset', 'reset the track state'),
    0xE9: (1, 'sfx-voices', 'voices sound effects may take (mask, $0C)'),
    0xEA: (0, 'key-off', ''),
    0xEB: (-1, 'slide', 'pitch slide steps, ends with $00'),
    0xEC: (-1, 'slide-off', 'key off, then pitch slide steps'),
    0xED: (1, 'velocity', 'note velocity ($028A, times the volume)'),
    0xEF: (2, 'note', 'note, length'),
    0xF0: (0, 'end', 'end of track'),
    0xF1: (2, 'volume-scale', 'volume *= a/256 * b/256 (approx.)'),
    0xF2: (1, 'volume', 'track volume ($05C3)'),
    0xF3: (1, 'priority', 'voice allocation priority ($02B2)'),
    0xF4: (0, 'legato', 'next note without key on'),
    0xF5: (1, 'instrument', 'instrument# ($05D7; table at $2156)'),
    0xF6: (-2, 'pattern', 'call: address, end, count (0 = forever), transpose (1/20 semitone), volume scale a b, skip'),
    0xF7: (2, 'fine', 'fine pitch word ($0663)'),
    0xF8: (0, 'rest32', 'rest 32 ticks'),
    0xF9: (0, 'loop', 'restart the track'),
    0xFA: (1, 'tempo', 'tempo ($CB): 50 * n / 256 steps per second, 0 = 50'),
    0xFB: (1, 'pan', 'pan offset, signed ($029E; voice pan 0-100)'),
    0xFC: (0, 'flag-3', 'sets $07.3 (envelope not reset at the next note)'),
    0xFD: (0, 'rest64', 'rest 64 ticks'),
    0xFE: (0, 'rest128', 'rest 128 ticks'),
    0xFF: (0, 'rest256', 'rest 256 ticks'),
}
RESTS = {0xF8: 32, 0xFD: 64, 0xFE: 128, 0xFF: 256}


def song_names(data):
    names = {}
    p = os.path.join(data, 'RLMUS', 'doommus.asm')
    if os.path.exists(p):
        for l in open(p):
            m = re.match(r'(\w+)_sng\s+equ\s+\$([0-9A-Fa-f]+)', l)
            if m:
                names[int(m.group(2), 16)] = m.group(1)
    return names


class Song:
    def __init__(self, md, module):
        self.module = module
        self.aram = md.aram(0, module)
        self.groups = md.module(module)
        g = [d for d, ch in self.groups if SONGPTR <= d < SONGPTR + 0x40]
        self.number = (g[0] - SONGPTR) // 2
        self.header = struct.unpack_from('<H', self.aram, g[0])[0]
        n = self.aram[self.header]
        self.tracks = [struct.unpack_from('<H', self.aram, self.header + 1 + 2 * i)[0] for i in range(n)]
        self.size = sum(len(md.chunk(c)) for d, ch in self.groups for c in ch)

    def events(self, pc, end=None):
        """raw events of a track or pattern: (pc, kind, values...)"""
        a = self.aram; ev = []; note = 0
        for _ in range(100000):
            if end is not None and pc == end:
                return ev
            at = pc; b = a[pc]; pc += 1
            if b < 0x80:
                note += (b >> 3) - 8; ev.append((at, 'note', note, (b & 7) + 1))
            elif b < 0xC0:
                note = b - 0x60; ev.append((at, 'note', note, a[pc])); pc += 1
            elif b < 0xE0:
                ev.append((at, 'rest', b - 0xBF))
            elif b in RESTS:
                ev.append((at, 'rest', RESTS[b]))
            elif b == 0xEF:
                note = a[pc]; ev.append((at, 'note', note, a[pc + 1])); pc += 2
            elif b in (0xEB, 0xEC):
                s = []
                while True:
                    x = a[pc]; pc += 1; s.append(x)
                    if x == 0:
                        break
                    if x == 1 or (x >> 4 == 0 and x > 2):
                        s.append(a[pc]); pc += 1
                ev.append((at, CMDS[b][1], s))
            elif b == 0xF6:
                p = a[pc:pc + 10]
                ev.append((at, 'pattern', p[0] | p[1] << 8, p[2] | p[3] << 8, p[4],
                           struct.unpack_from('<h', p, 5)[0], p[7], p[8]))
                pc += 10 + p[9]
            elif b in (0xF0, 0xF9):
                ev.append((at, CMDS[b][1]))
                return ev
            elif b in CMDS:
                n = CMDS[b][0]; ev.append((at, CMDS[b][1]) + tuple(a[pc:pc + n])); pc += n
            else:
                ev.append((at, 'BAD', b))
                return ev
        return ev

    def timeline(self, pc, end=None, transpose=0, depth=0):
        """expanded events in ticks: (tick, 'note', note, length) / (tick, 'rest', ticks) /
        (tick, 'cmd', name, args); patterns played their count times (count 0, i.e. forever,
        once); the track once"""
        out = []; t = 0
        for e in self.events(pc, end):
            k = e[1]
            if k == 'note':
                out.append((t, 'note', e[2] + transpose / PITCH_PER_NOTE, e[3])); t += e[3]
            elif k == 'rest':
                out.append((t, 'rest', e[2])); t += e[2]
            elif k == 'pattern':
                if depth < 4:
                    for _ in range(e[4] or 1):
                        sub = self.timeline(e[2], e[3], transpose + e[5], depth + 1)
                        out += [(t + x[0],) + x[1:] for x in sub]
                        t += sum(x[3] if x[1] == 'note' else x[2] if x[1] == 'rest' else 0 for x in sub)
            elif k in ('end', 'loop', 'BAD'):
                break
            else:
                out.append((t, 'cmd', k, e[2:]))
        return out

    def instruments(self):
        """instrument# used -> its 6-byte instrument record"""
        out = {}
        for t in self.tracks:
            for e in self.events(t):
                if e[1] == 'instrument':
                    i = e[2]
                    p = struct.unpack_from('<H', self.aram, INSTR + 2 * i)[0]
                    out[i] = bytes(self.aram[p:p + 6])
        return out

    def tempo(self):
        for t in self.tracks:
            for e in self.events(t):
                if e[1] == 'tempo':
                    return e[2]
        return 0


def songs(md):
    out = {}
    for m in range(md.modules()):
        if any(SONGPTR <= d < SONGPTR + 0x40 for d, ch in md.module(m)):
            s = Song(md, m)
            out.setdefault(s.number, s)
    return out


def find(md, data, name):
    ss = songs(md); names = song_names(data)
    if name.isdigit():
        return ss[int(name)]
    for n, nm in names.items():
        if nm.lower() in (name.lower(), name.lower() + '_sng'):
            return ss[n]
    sys.exit('no song %s (%s)' % (name, ', '.join(names.values())))


# --------------------------------------------------------------------------
def cmd_list(a, md):
    names = song_names(a.data)
    for n, s in sorted(songs(md).items()):
        print('song %2d %-10s module %2d  header %04X  %2d tracks  tempo %3d  %d instruments  %5d bytes' % (
            n, names.get(n, '?'), s.module, s.header, len(s.tracks), s.tempo(), len(s.instruments()), s.size))


def cmd_dump(a, md):
    s = find(md, a.data, a.songs[0])
    print('song %d module %d header %04X tempo %d' % (s.number, s.module, s.header, s.tempo()))
    for i, r in sorted(s.instruments().items()):
        print('instrument %02X: %s' % (i, r.hex(' ')))
    pats = set()
    for i, t in enumerate(s.tracks):
        print('track %d @%04X' % (i, t))
        for e in s.events(t):
            print('  %04X %s' % (e[0], ' '.join(str(x) for x in e[1:])))
            if e[1] == 'pattern':
                pats.add((e[2], e[3]))
    for p, end in sorted(pats):
        print('pattern @%04X-%04X' % (p, end))
        for e in s.events(p, end):
            print('  %04X %s' % (e[0], ' '.join(str(x) for x in e[1:])))


def write_midi(path, s, ppq=96):
    tempo = s.tempo() or 256
    rate = 50.0 * tempo / 256                   # sequencer steps per second
    us = int(round(ppq * 1e6 / rate))           # one tick = one MIDI tick
    def vlq(n):
        b = [n & 0x7F]; n >>= 7
        while n:
            b.insert(0, 0x80 | (n & 0x7F)); n >>= 7
        return bytes(b)
    trks = [b'\x00\xff\x51\x03' + us.to_bytes(3, 'big') + b'\x00\xff\x2f\x00']
    ch_of = [c for c in range(16) if c != 9]
    for i, t in enumerate(s.tracks):
        ch = ch_of[i % 15]
        ev = []; vel = 100; vol = None; ins = None
        for x in s.timeline(t):
            if x[1] == 'cmd':
                if x[2] == 'velocity': vel = max(1, x[3][0] >> 1)
                elif x[2] == 'volume': ev.append((x[0], 0, bytes((0xB0 | ch, 7, min(127, x[3][0])))))
                elif x[2] == 'instrument' and x[3][0] != ins:
                    ins = x[3][0]
                    ev.append((x[0], 0, b'\xff\x01' + vlq(len('instrument %02X' % ins)) + ('instrument %02X' % ins).encode()))
            elif x[1] == 'note':
                n = int(round(x[2]))
                if 0 <= n < 128:
                    ev.append((x[0], 1, bytes((0x90 | ch, n, vel))))
                    ev.append((x[0] + x[3], 0, bytes((0x80 | ch, n, 0))))
        ev.sort(key=lambda e: (e[0], e[1]))
        body = bytearray(b'\x00\xff\x03' + vlq(len('track %d' % i)) + ('track %d' % i).encode()); last = 0
        for tk, _, m in ev:
            body += vlq(tk - last) + m; last = tk
        body += b'\x00\xff\x2f\x00'
        trks.append(bytes(body))
    out = b'MThd' + struct.pack('>IHHH', 6, 1, len(trks), ppq)
    for tr in trks:
        out += b'MTrk' + struct.pack('>I', len(tr)) + tr
    open(path, 'wb').write(out)


def cmd_midi(a, md):
    os.makedirs(a.out, exist_ok=True)
    names = song_names(a.data)
    sel = [find(md, a.data, x) for x in a.songs] if a.songs else list(songs(md).values())
    for s in sel:
        fn = os.path.join(a.out, '%02d_%s.mid' % (s.number, names.get(s.number, 'song')))
        write_midi(fn, s)
        print(fn)


def mus_notes(d):
    """MUS lump -> [(tick 140 Hz, channel, note)]"""
    ln, off = struct.unpack_from('<HH', d, 4)
    p = off; t = 0; out = []
    while p < len(d):
        b = d[p]; p += 1
        typ = (b >> 4) & 7; c = b & 15
        if typ == 1:
            n = d[p]; p += 1
            if n & 0x80: p += 1
            out.append((t, c, n & 0x7F))
        elif typ in (0, 2, 3): p += 1
        elif typ == 4: p += 2
        elif typ == 6: break
        if b & 0x80:
            dl = 0
            while True:
                x = d[p]; p += 1; dl = dl * 128 + (x & 0x7F)
                if not x & 0x80: break
            t += dl
    return out


def cmd_compare(a, md):
    lumps = {}
    for w in a.wad:
        d = open(w, 'rb').read()
        for nm, q, sz in wadlumps(d):
            if nm.startswith('D_') and d[q:q + 4] == b'MUS\x1a':
                lumps[nm] = d[q:q + sz]
    names = song_names(a.data)
    for n, s in sorted(songs(md).items()):
        # SNES notes in MUS ticks (25/72 SNES ticks per MUS tick)
        sn = set()
        for t in s.tracks:
            for x in s.timeline(t):
                if x[1] == 'note' and x[0] * 72 / 25 < 140 * 120:
                    sn.add((int(round(x[0] * 72 / 25 / 7)), int(round(x[2]))))
        best = (0, None)
        for nm, d in lumps.items():
            mn = {(int(round(t / 7)), k) for t, c, k in mus_notes(d) if t < 140 * 120 and c != 15}
            if mn:
                hit = len(mn & sn) / len(mn)
                if hit > best[0]:
                    best = (hit, nm)
        print('song %2d %-10s best MUS match %-8s  %3.0f %% of its notes (first 2 minutes, drums aside)' % (
            n, names.get(n, '?'), best[1], best[0] * 100))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[1])
    ap.add_argument('cmd', choices=('list', 'dump', 'midi', 'compare'))
    ap.add_argument('songs', nargs='*')
    ap.add_argument('--data', default=os.path.join(HERE, '..', '..', 'data'))
    ap.add_argument('--out')
    ap.add_argument('--wad', action='append', default=[])
    a = ap.parse_args()
    md = rlmusic.MusicData(os.path.join(a.data, 'RLDATA', 'MUSIC'))
    {'list': cmd_list, 'dump': cmd_dump, 'midi': cmd_midi, 'compare': cmd_compare}[a.cmd](a, md)


if __name__ == '__main__':
    main()
