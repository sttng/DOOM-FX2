"""
mus.py -- read DOOM's MUS music lumps (D_xxx)

  Mus(data).notes    [Note(t, ch, note, dur, vel, vol, pan, prog, bend, expr)] in 140 Hz ticks
  Mus(data).events   [(t, ch, kind, values...)] all events, kinds: on off bend sys ctrl
  Mus(data).length   ticks to the score end

MUS format (DOOM's DMX): header 'MUS',$1A, word score length, word score start,
word primary channels, word secondary channels, word #instruments, word 0, then
the instrument (GM program) list; events: byte (last << 7 | type << 4 | channel),
  0 release note   byte note
  1 play note      byte note (| $80: byte volume follows)
  2 pitch bend     byte (128 = centre, 64 = -1 semitone ... with DMX's +-2)
  3 system event   byte (10 all sounds off, 11 all notes off, 14 reset all controllers ...)
  4 controller     byte controller (0 = program change), byte value
  5 end of measure
  6 score end
then, when the last bit is set, a variable-length delay (7 bits per byte, top bit
= more).  Channel 15 is percussion (MIDI channel 10).  The note volume (velocity)
carries over to the channel's later notes without one.
"""
import collections, struct

Note = collections.namedtuple('Note', 't ch note dur vel vol pan prog bend expr')
CTRL = {0: 'program', 1: 'bank', 2: 'modulation', 3: 'volume', 4: 'pan', 5: 'expression',
        6: 'reverb', 7: 'chorus', 8: 'sustain', 9: 'soft'}
RATE = 140                      # ticks per second


class Mus:
    def __init__(self, d):
        assert d[:4] == b'MUS\x1a', 'not a MUS lump'
        ln, off, self.primary, self.secondary, ni = struct.unpack_from('<HHHHH', d, 4)
        self.instruments = list(struct.unpack_from('<%dH' % ni, d, 16))
        p = off; t = 0; ev = []
        vel = [100] * 16
        while p < len(d):
            b = d[p]; p += 1
            typ = (b >> 4) & 7; c = b & 15
            if typ == 0:
                ev.append((t, c, 'off', d[p] & 0x7F)); p += 1
            elif typ == 1:
                n = d[p]; p += 1
                if n & 0x80:
                    vel[c] = d[p] & 0x7F; p += 1
                ev.append((t, c, 'on', n & 0x7F, vel[c]))
            elif typ == 2:
                ev.append((t, c, 'bend', d[p])); p += 1
            elif typ == 3:
                ev.append((t, c, 'sys', d[p])); p += 1
            elif typ == 4:
                ev.append((t, c, 'ctrl', d[p], d[p + 1])); p += 2
            elif typ == 5:
                pass
            elif typ == 6:
                break
            else:
                raise ValueError('MUS event type %d' % typ)
            if b & 0x80:
                dl = 0
                while True:
                    x = d[p]; p += 1; dl = dl * 128 + (x & 0x7F)
                    if not x & 0x80:
                        break
                t += dl
        self.events = ev
        self.length = t
        self.notes = self._notes()

    def _notes(self):
        st = {c: dict(vol=127, pan=64, prog=0, bend=128, expr=127) for c in range(16)}
        held = {}; out = []
        for e in self.events:
            t, c, k = e[:3]
            if k == 'on':
                key = (c, e[3])
                if key in held:                         # retrigger: end the old one
                    out[held[key]] = out[held[key]]._replace(dur=t - out[held[key]].t)
                s = st[c]
                held[key] = len(out)
                out.append(Note(t, c, e[3], None, e[4], s['vol'], s['pan'], s['prog'], s['bend'], s['expr']))
            elif k == 'off':
                key = (c, e[3])
                if key in held:
                    i = held.pop(key); out[i] = out[i]._replace(dur=t - out[i].t)
            elif k == 'ctrl':
                key = {0: 'prog', 3: 'vol', 4: 'pan', 5: 'expr'}.get(e[3])
                if key:
                    st[c][key] = e[4]
            elif k == 'bend':
                st[c]['bend'] = e[3]
            elif k == 'sys' and e[3] in (10, 11):
                for key in [x for x in held if x[0] == c]:
                    i = held.pop(key); out[i] = out[i]._replace(dur=t - out[i].t)
        for key, i in held.items():
            out[i] = out[i]._replace(dur=self.length - out[i].t)
        return out


def lumps(wadfile):
    """{name: MUS data} of a WAD's music lumps"""
    import wad
    d = open(wadfile, 'rb').read()
    out = {}
    for nm, q, sz in wad.directory(d):
        if d[q:q + 4] == b'MUS\x1a':
            out[nm] = d[q:q + sz]
    return out
