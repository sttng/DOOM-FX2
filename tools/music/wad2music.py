#!/usr/bin/env python3
"""
wad2music.py -- convert a WAD's MUS music (D_xxx) to song modules for the SPC700
music driver, played with the FX3 cartridge's instruments

  wad2music.py convert [--data DATA] --wad WAD [--wad PWAD] [--only D_X,...]
  wad2music.py song    LUMP... [--data DATA] --wad WAD --out DIR [--seconds N]
                       (each song rendered to DIR/LUMP.wav with spcrender.py, and the
                        module's size; for listening and tuning)

The arrangement follows the FX3 cartridge's own conversions of DOOM's MUS scores,
whose rules were learnt by lining up its 23 songs with DOOM.WAD:

  * notes, lengths and timing as in the MUS score: one sequencer step = 2.8 MUS ticks
    (tempo 0: 50 steps a second, the PC's speed, as in FX3's own E2M1 and E3M3);
  * one FX3 instrument per GM program (PROGRAMS: FX3's choice where it had one,
    else an instrument of the same GM family), the FX3 drum kit per drum key (KIT);
  * a channel's chords spread over tracks; the first track of each channel and the
    kick and snare get the highest voice priority, chord notes, hi-hats and cymbals
    a lower one, the echo the lowest (the driver shares its 8 voices by priority);
  * level = LEVEL0 (2000 RMS, the FX3 songs' average) * (volume/127) * (velocity/127),
    through each instrument's measured loudness (LOUDNESS); pan from the MUS pan;
  * the distortion guitar's higher notes doubled on $33 an octave up (FX3's guitar sound);
  * an echo of the lead part, 7 steps late, quieter and on the other side, as
    FX3 adds with its spare voices;
  * pitch bends as pitch slides; repeats stored once and played with the driver's
    pattern calls.
Instrument data (samples, records, curves) come from the cartridge songs of the
data set (RLMUSIC.fx3 when the data set has it, else RLDATA/MUSIC).

A level song must fit sound RAM $6517-$B806 (samples + song); a song that does not
gets, in turn (build): stand-ins for rarely used instruments, no echo, no guitar
layer, no velocity detail, coarser bends, stand-ins of the same role, no bends,
at most 3, 2, then 1 chord notes.  A song that still does not fit keeps the
cartridge's song.
"""
import argparse, bisect, collections, math, os, re, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))  # (tools/: rlmusic, wad, snescomp)
import mus, musiclib, rlmusic            # noqa: E402

STEP = 2.8                  # MUS ticks (140 Hz) per sequencer step (50 Hz)
LEVEL0 = 2000.0             # RMS at volume 127, velocity 127 (the FX3 songs' average)
PRI_LEAD, PRI_CHORD, PRI_ECHO = 200, 120, 65
SFX_VOICES = 0xF8           # voices sound effects may take (FX3: voices 3-7)
ECHO_DELAY, ECHO_LEVEL, ECHO_DETUNE = 7, 0.35, -6     # (detune: DSP pitch units, about 2 cents at C4)
LAYER_FROM, LAYER_INS, LAYER_NOTE, LAYER_LEVEL, LAYER_DETUNE = 0x2C, 0x33, 55, 0.6, -4
PRI_LAYER = 75
MAX_TRACKS = 18             # the driver's track tables hold 20, shared with sound effects; FX3 uses <= 18
RELEASE_STEPS = 4            # a voice counted busy this long after its note (the release)
LEGATO_STEPS, LEGATO_PART = 2, 0.3   # overlap of a note with the one before it that is cut
STANDIN_SAVING = 300        # bytes a stand-in instrument must save (a sample, not a few curve bytes)

# GM program -> (FX3 instrument, transpose).  FX3 = its choice for that program in
# its songs (song noted); the rest by GM family.  Measured tuning: every instrument
# plays MUS note n at pitch n, except $33 $4F $51 $53 $54 $55 $5B $5C (an octave high).
PROGRAMS = {
    0: (0x3A, 0), 1: (0x3A, 0), 2: (0x3A, 0), 3: (0x3A, 0), 4: (0x3A, 0), 5: (0x3A, 0),
    6: (0x37, 0),                       # FX3 E1M2 (harpsichord)
    7: (0x3A, 0),                       # FX3 title (clavinet)
    8: (0x44, 0), 9: (0x44, 0), 10: (0x44, 0),     # 10: FX3 E1M6 (music box)
    11: (0x44, 0), 12: (0x46, 0), 13: (0x46, 0), 14: (0x46, 0),
    15: (0x46, 0),                      # FX3 E1M7 (dulcimer)
    16: (0x3C, 0), 17: (0x3C, 0), 18: (0x3C, 0), 19: (0x3C, 0), 20: (0x3C, 0),
    21: (0x3C, 0), 22: (0x3C, 0), 23: (0x3C, 0),
    24: (0x46, 0), 25: (0x46, 0), 26: (0x46, 0), 27: (0x46, 0),
    28: (0x2D, 0),                      # FX3 E2M1 (muted guitar)
    29: (0x2C, 0),                      # FX3 E1M1 riffs (overdriven guitar; FX3 puts leads on $33, an octave up)
    30: (0x2C, 0),                      # FX3 E1M4/inter/title (distortion guitar)
    31: (0x61, 0),                      # FX3 E3M8 (harmonics)
    32: (0x2D, 0), 33: (0x2D, 0), 34: (0x2D, 0), 35: (0x2D, 0),   # FX3 E1M1/E1M6/E2M1 (bass)
    36: (0x35, 0), 37: (0x35, 0),       # FX3 E1M2 (slap bass)
    38: (0x3A, 0), 39: (0x3A, 0),       # FX3 E1M3 (synth bass)
    40: (0x4E, 0),                      # FX3 E1M9 (violin)
    41: (0x3D, 0), 42: (0x3D, 0), 43: (0x3D, 0),   # FX3 E1M9 (viola)
    44: (0x58, 0),                      # FX3 E2M6 (tremolo strings)
    45: (0x56, 0),                      # FX3 E2M4 (pizzicato)
    46: (0x46, 0),                      # FX3 E1M7 (harp)
    47: (0x43, 0),                      # FX3 E1M6/E2M7/title (timpani)
    48: (0x3D, 0), 49: (0x3D, 0),       # FX3 E1M5/E1M7/E2M7/titles (strings)
    50: (0x58, 0), 51: (0x58, 0),       # FX3 E2M6 (synth strings)
    52: (0x3D, 0), 53: (0x3B, 0), 54: (0x3B, 0),   # FX3 E2M4 (choir)
    55: (0x3E, -24),                    # FX3 E2M7 (orchestra hit)
    56: (0x3C, 0), 57: (0x3C, 0), 58: (0x3C, 0), 59: (0x3C, 0), 60: (0x3C, 0), 61: (0x3C, 0),
    62: (0x41, 0),                      # FX3 E1M6 (synth brass 1)
    63: (0x3C, 0),                      # FX3 E1M4/E1M6 (synth brass 2)
    64: (0x4D, 0), 65: (0x4D, 0), 66: (0x4D, 0), 67: (0x4D, 0), 68: (0x4D, 0), 69: (0x4D, 0),
    70: (0x4D, 0),                      # FX3 bunny (bassoon)
    71: (0x4D, 0),
    72: (0x5A, 0),                      # FX3 E2M7 (piccolo)
    73: (0x5A, 0), 74: (0x5A, 0),
    75: (0x3B, 0),                      # FX3 bunny (pan flute)
    76: (0x3B, 0), 77: (0x3B, 0), 78: (0x3B, 0),
    79: (0x4F, -12),                    # FX3 E2M2 (ocarina)
    80: (0x51, -12),                    # FX3 E2M2 (square lead; an octave high)
    81: (0x36, 0),                      # FX3 E1M6/E1M7 (saw lead)
    82: (0x36, 0), 83: (0x36, 0), 84: (0x36, 0), 85: (0x36, 0), 86: (0x36, 0),
    87: (0x36, 0),                      # FX3 E2M6 (bass + lead)
    88: (0x36, 0), 89: (0x3D, 0), 90: (0x36, 0), 91: (0x3B, 0),
    92: (0x3B, 0),                      # FX3 E1M3 (bowed pad)
    93: (0x3B, 0),
    94: (0x36, 0),                      # FX3 title (halo pad)
    95: (0x36, 0),
    96: (0x50, 0), 97: (0x50, 0), 98: (0x44, 0), 99: (0x50, 0), 100: (0x50, 0),
    101: (0x52, -12),                   # FX3 E2M2 (goblin)
    102: (0x50, 0), 103: (0x50, 0),
    104: (0x46, 0), 105: (0x46, 0), 106: (0x46, 0), 107: (0x46, 0),
    108: (0x59, 0),                     # FX3 E2M7 (kalimba)
    109: (0x4D, 0), 110: (0x4E, 0), 111: (0x4D, 0),
    112: (0x44, 0), 113: (0x38, 0), 114: (0x46, 0), 115: (0x38, 0),
    116: (0x43, 0),                     # taiko: the timpani
    117: (0x2B, 0),                     # melodic tom: the toms
    118: (0x4A, 0),                     # FX3 E1M8 (synth drum)
    119: (0x40, 0),                     # FX3 E1M5 (reverse cymbal)
    120: (0x3F, 0),                     # FX3 E1M5 (guitar fret noise)
    121: (0x3B, 0), 122: (0x40, 0), 123: (0x44, 0), 124: (0x44, 0), 125: (0x40, 0),
    126: (0x40, 0), 127: (0x2A, 0),
}
# GM drum key -> (instrument, note, FX3 volume at velocity ~100, priority, group).
# The FX3 kit (its drum tracks: kick, snare, hi-hats, toms, cymbals, claves,
# triangle); keys FX3 never used get the nearest sound.
KIT = {
    35: (0x2E, 36, 64, PRI_LEAD, 'kick'), 36: (0x2E, 36, 64, PRI_LEAD, 'kick'),
    37: (0x38, 72, 40, PRI_CHORD, 'perc'), 38: (0x2A, 75, 70, PRI_LEAD, 'snare'),
    39: (0x2A, 79, 60, PRI_CHORD, 'snare'), 40: (0x2A, 75, 70, PRI_LEAD, 'snare'),
    41: (0x2B, 57, 55, PRI_CHORD, 'tom'), 43: (0x2B, 60, 55, PRI_CHORD, 'tom'),
    45: (0x2B, 64, 55, PRI_CHORD, 'tom'), 47: (0x2B, 67, 55, PRI_CHORD, 'tom'),
    48: (0x2B, 70, 55, PRI_CHORD, 'tom'), 50: (0x2B, 74, 55, PRI_CHORD, 'tom'),
    42: (0x2F, 68, 21, PRI_CHORD, 'hat'), 44: (0x30, 69, 30, PRI_CHORD, 'hat'),
    46: (0x31, 70, 20, PRI_CHORD, 'hat'),
    49: (0x29, 65, 38, PRI_CHORD, 'cymbal'), 57: (0x29, 63, 38, PRI_CHORD, 'cymbal'),
    52: (0x29, 60, 34, PRI_CHORD, 'cymbal'), 55: (0x29, 67, 30, PRI_CHORD, 'cymbal'),
    51: (0x32, 64, 17, PRI_CHORD, 'ride'), 59: (0x32, 62, 17, PRI_CHORD, 'ride'),
    53: (0x32, 60, 19, PRI_CHORD, 'ride'),
    54: (0x31, 76, 14, PRI_CHORD, 'perc'), 56: (0x38, 62, 34, PRI_CHORD, 'perc'),
    58: (0x2F, 62, 16, PRI_CHORD, 'perc'),
    60: (0x2B, 79, 40, PRI_CHORD, 'perc'), 61: (0x2B, 76, 40, PRI_CHORD, 'perc'),
    62: (0x2B, 72, 40, PRI_CHORD, 'perc'), 63: (0x2B, 70, 40, PRI_CHORD, 'perc'),
    64: (0x2B, 66, 40, PRI_CHORD, 'perc'), 65: (0x2B, 72, 45, PRI_CHORD, 'perc'),
    66: (0x2B, 68, 45, PRI_CHORD, 'perc'),
    67: (0x38, 70, 34, PRI_CHORD, 'perc'), 68: (0x38, 65, 34, PRI_CHORD, 'perc'),
    69: (0x2F, 74, 14, PRI_CHORD, 'perc'), 70: (0x2F, 76, 14, PRI_CHORD, 'perc'),
    71: (0x4C, 95, 20, PRI_CHORD, 'perc'), 72: (0x4C, 90, 20, PRI_CHORD, 'perc'),
    73: (0x2F, 70, 14, PRI_CHORD, 'perc'), 74: (0x2F, 66, 14, PRI_CHORD, 'perc'),
    75: (0x38, 67, 45, PRI_CHORD, 'perc'), 76: (0x38, 72, 40, PRI_CHORD, 'perc'),
    77: (0x38, 67, 40, PRI_CHORD, 'perc'), 78: (0x4C, 85, 20, PRI_CHORD, 'perc'),
    79: (0x4C, 80, 20, PRI_CHORD, 'perc'),
    80: (0x4B, 95, 25, PRI_CHORD, 'perc'), 81: (0x4C, 95, 25, PRI_CHORD, 'perc'),
    82: (0x2F, 72, 14, PRI_CHORD, 'perc'), 83: (0x4C, 95, 20, PRI_CHORD, 'perc'),
    84: (0x4C, 99, 20, PRI_CHORD, 'perc'), 85: (0x38, 76, 34, PRI_CHORD, 'perc'),
    86: (0x2B, 62, 40, PRI_CHORD, 'perc'), 87: (0x2B, 58, 40, PRI_CHORD, 'perc'),
}
KIT_LOW = 35                # keys below 35 (non-GM): the snare's sound
# measured RMS of each instrument at volume 127, velocity 255, at the note FX3 plays it
# around (else note 60; spcrender, after the fade-in); drums use their kit volume
LOUDNESS = {
    0x27: 7607, 0x28: 4103, 0x29: 1891, 0x2A: 1936, 0x2B: 780, 0x2C: 7546, 0x2D: 4052, 0x2F: 151,
    0x30: 1679, 0x31: 1469, 0x32: 1157, 0x33: 2598, 0x34: 3781, 0x35: 1143, 0x36: 9708, 0x37: 2808,
    0x38: 1000, 0x39: 890, 0x3A: 1824, 0x3B: 12208, 0x3C: 6534, 0x3D: 5231, 0x3E: 6027, 0x3F: 5280,
    0x40: 1573, 0x41: 3869, 0x42: 1422, 0x43: 3660, 0x44: 3818, 0x45: 4276, 0x46: 769, 0x47: 2576,
    0x48: 8538, 0x49: 1052, 0x4A: 2656, 0x4B: 129, 0x4B: 1000, 0x4C: 830, 0x4D: 3997, 0x4E: 10797,
    0x4F: 10204, 0x50: 9849, 0x51: 2965, 0x52: 3250, 0x53: 3936, 0x54: 5113, 0x55: 9199, 0x56: 2801,
    0x57: 1430, 0x58: 5158, 0x59: 639, 0x5A: 10922, 0x5B: 6962, 0x5C: 4792, 0x5D: 3381, 0x5E: 4094,
    0x5F: 6818, 0x60: 4670, 0x61: 2158, 0x62: 927,
}
# note length against the MUS duration (FX3: its synth bass and timpani play short)
LENGTH = {0x3A: 0.5, 0x43: 0.65}
# instruments whose sample sounds an octave above the note played
TUNING = {0x33: 12, 0x4F: 12, 0x51: 12, 0x53: 12, 0x54: 12, 0x55: 12, 0x5B: 12, 0x5C: 12}
# stand-ins when a song does not fit in sound RAM: each instrument's role, the roles'
# members in order of preference (a stand-in keeps the pitch: TUNING)
ROLES = {
    'pad': [0x3D, 0x58, 0x3B, 0x3C, 0x50, 0x41, 0x5F, 0x45, 0x3E, 0x49, 0x57, 0x5D, 0x28,
            0x34, 0x39, 0x27, 0x52],
    'lead': [0x36, 0x51, 0x5C, 0x4F, 0x55, 0x5A, 0x4D, 0x4E, 0x53, 0x54, 0x5B, 0x5E],
    'guitar': [0x2C, 0x33, 0x60, 0x48, 0x61],
    'bass': [0x2D, 0x35, 0x3A],
    'pluck': [0x46, 0x42, 0x56, 0x37, 0x44, 0x59, 0x47, 0x3F],
    'tom': [0x2B, 0x43, 0x4A],
    'cymbal': [0x2F, 0x31, 0x32, 0x29, 0x30, 0x40, 0x62],     # (one sample)
    'snare': [0x2A], 'kick': [0x2E],
    'small': [0x38, 0x4B, 0x4C, 0x2B, 0x31],                 # claves, triangles
}
ROLE = {}
for r, mem in ROLES.items():
    for i in mem:
        ROLE.setdefault(i, r)                   # (an instrument's role: the first list it is in)


def steps(t):
    return int(round(t / STEP))


BEND_UNITS = 20 / 64        # MUS bend (128 = none, +-128 = +-2 semitones) -> 1/20 semitone


def bend_timelines(m, q=1):
    """channel -> ([step...], [pitch offset (1/20 semitone)...]), one value per change;
    Q: offsets rounded to multiples of Q (fewer slide steps)"""
    out = collections.defaultdict(lambda: ([0], [0]))
    for e in m.events:
        if e[2] == 'bend':
            ts, vs = out[e[1]]
            s, v = steps(e[0]), q * int(round((e[3] - 128) * BEND_UNITS / q))
            if ts[-1] == s:
                vs[-1] = v
            elif vs[-1] != v:
                ts.append(s); vs.append(v)
    return out


def bend_at(tl, s):
    ts, vs = tl
    return vs[bisect.bisect_right(ts, s) - 1]


def slide_bytes(changes, length, start=0):
    """the bend of a note as slide bytes: START (its bend when it starts, applied with the
    slide's first byte, a step after the note) and [(step from the note's start, offset
    from START)]; the waits add up to LENGTH - 1 (the note plays 1 step before the slide).
    (The driver adds the fine pitch command only when a slide recalculates the pitch, so
    a slide carries the whole bend.)"""
    out = []; t = 1; cur = -start

    def wait(w, delta):
        while not -7 <= delta <= 7:                # deltas over 7: chained, without a wait
            d = 7 if delta > 0 else -7
            out.append((d + 8) << 4); delta -= d
        k = min(w, 15)
        out.append(((delta + 8) << 4) | k); w -= k
        while w > 0:
            k = min(w, 15); out.append(0x80 | k); w -= k

    for k, o in changes:
        if k >= length:
            break
        if not out and k > t:
            wait(k - t, -cur); cur = 0
        nxt = [kk for kk, _ in changes if kk > k]
        end = min(nxt[0], length) if nxt else length
        wait(end - k, o - cur); cur = o; t = end
    if t < length:
        wait(length - t, -cur if not out else 0)
    return tuple(out)


class Lane:
    """one track: monophonic notes [(start, end, note, ins, vol, vel, pan, bend)]"""
    def __init__(self, name, pri, chan, detune=0):
        self.name = name; self.pri = pri; self.chan = chan; self.notes = []; self.detune = detune

    def free_at(self):
        return self.notes[-1][1] if self.notes else -1


def merge_lanes(a, b):
    """B's notes into lane A (one track): a note is cut where the next one starts"""
    notes = sorted(a.notes + b.notes, key=lambda n: (n[0], -n[4]))
    out = []
    for n in notes:
        if out and out[-1][0] == n[0]:
            continue                                # (two hits at once: the louder)
        if out and out[-1][1] > n[0]:
            out[-1] = (out[-1][0], n[0]) + out[-1][2:]
        out.append(n)
    a.notes = out; a.pri = max(a.pri, b.pri)


def pan_offset(p):
    return max(-50, min(50, int(round((p - 64) * 0.6))))


def melodic_volume(ins, chvol):
    """track volume byte for a channel volume (velocity 255 = MUS velocity 127)"""
    r = LOUDNESS.get(ins, 3000)
    return max(1, min(127, int(round(127 * LEVEL0 / r * chvol / 127))))


def arrange(m, loop=True, echo=True, velocity=True, max_chord=None, subst=None, bend=True, layers=True,
            split_drums=True):
    """MUS -> (tracks [event lists], instruments, notes per instrument); SUBST:
    {instrument: stand-in}"""
    subst = subst or {}
    uses = collections.Counter()
    lanes = []
    bends = bend_timelines(m, bend) if bend else {}
    notes = sorted(m.notes, key=lambda n: (n.t, n.ch, -n.note))
    by_ch = collections.defaultdict(list)
    for n in notes:
        if n.dur is None or n.dur <= 0 and n.ch != 15:
            continue
        by_ch[n.ch].append(n)
    for ch in sorted(by_ch):
        chl = []
        for n in by_ch[ch]:
            if ch == 15:
                k = KIT.get(n.note) or KIT[38 if n.note < KIT_LOW else min(KIT, key=lambda x: abs(x - n.note))]
                ins, note, kvol, pri, grp = k
                name = 'drum-' + grp
                if ins in subst:                # (a stand-in at its loudness)
                    kvol *= LOUDNESS.get(ins, 1000) / LOUDNESS.get(subst[ins], 1000); ins = subst[ins]
                vol = max(1, min(127, int(round(kvol * n.vol / 127 * 127 / 100))))
                vel = n.vel
                if split_drums:
                    name = 'drum-%s-%02X' % (grp, ins)  # (one track per drum sound, as FX3)
            else:
                ins, tr = PROGRAMS.get(n.prog, (0x3D, 0))
                if ins in subst:
                    tr += TUNING.get(ins, 0) - TUNING.get(subst[ins], 0); ins = subst[ins]
                note = n.note + tr
                while note < 24: note += 12
                while note > 108: note -= 12
                pri = None; name = 'ch%d' % ch
                vol = melodic_volume(ins, n.vol); vel = n.vel
            s = steps(n.t); e = max(s + 1, steps(n.t + max(n.dur, 1) * LENGTH.get(ins, 1.0)))
            if ch == 15:
                e = max(s + 1, min(e, s + 64))
            # the first lane that is free, or still sounding but started 2+ steps ago and
            # overlapping a little (the MUS score's legato: cut short, as FX3 does).  Notes
            # that start together, or under a long held one, take the next lane.
            cand = [l for l in chl if l.name == name and (l.free_at() <= s or (
                l.notes[-1][0] <= s - 2 and l.free_at() - s <= max(LEGATO_STEPS, LEGATO_PART * (l.free_at() - l.notes[-1][0]))))]
            if cand:
                lane = cand[0]                          # (the channel's first lanes: its main lines)
            else:
                same = [l for l in chl if l.name == name]
                if max_chord and ch != 15 and len(same) >= max_chord:
                    continue                    # (chord note beyond the limit: left out)
                lane = Lane(name, pri if pri is not None else (PRI_LEAD if not same else PRI_CHORD), ch)
                chl.append(lane)
            if lane.notes and lane.notes[-1][1] > s:
                lane.notes[-1] = (lane.notes[-1][0], s) + lane.notes[-1][2:]
            bd = (0, ())
            if ch != 15 and ch in bends:
                tl = bends[ch]; b0 = bend_at(tl, s)
                j = bisect.bisect_right(tl[0], s)
                bd = (b0, tuple((tl[0][k] - s, tl[1][k] - b0) for k in range(j, len(tl[0])) if tl[0][k] < e))
            lane.notes.append((s, e, note, ins, vol, vel, pan_offset(n.pan), bd))
            uses[ins] += 1
        lanes += chl
    length = max(1, steps(m.length))
    while len(lanes) > MAX_TRACKS:                  # too many tracks for the driver:
        drums = [l for l in lanes if l.chan == 15]
        pairs = [(a, b) for i, a in enumerate(drums) for b in drums[i + 1:]]
        if pairs:                                   # merge the two smallest drum tracks
            a, b = min(pairs, key=lambda p: (p[0].name.split('-')[1] != p[1].name.split('-')[1],
                                             len(p[0].notes) + len(p[1].notes)))
            merge_lanes(a, b); lanes.remove(b)
        else:                                       # else drop the least used chord lane
            k = min(range(len(lanes)), key=lambda k: (lanes[k].pri, len(lanes[k].notes)))
            lanes.pop(k)
    # FX3's guitar sound: the distortion guitar's higher notes doubled on $33 (an octave
    # up), slightly flat; quieter, and the first voices to go
    if layers and LAYER_INS not in subst:
        for l in [l for l in lanes if l.chan != 15 and l.pri == PRI_LEAD]:
            hi = [n for n in l.notes if n[3] == LAYER_FROM and n[2] >= LAYER_NOTE]
            if len(hi) >= 8 and len(lanes) < MAX_TRACKS - (1 if echo else 0):
                ly = Lane('layer', PRI_LAYER, l.chan, LAYER_DETUNE)
                g = LOUDNESS[LAYER_FROM] / LOUDNESS[LAYER_INS] * LAYER_LEVEL
                ly.notes = [(a, b, n, LAYER_INS, max(1, min(127, int(round(v * g)))), vl, p, bd)
                            for a, b, n, i, v, vl, p, bd in hi]
                lanes.append(ly)
    # echo of the lead: the busiest first lane of a non-bass melodic channel
    if echo:
        cands = [l for l in lanes if l.chan != 15 and l.pri == PRI_LEAD and l.notes and
                 not (0x2D == l.notes[0][3] or 0x35 == l.notes[0][3] or 0x3A == l.notes[0][3])]
        if cands and len(lanes) < MAX_TRACKS:
            lead = max(cands, key=lambda l: sum(e - s for s, e, *_ in l.notes))
            ec = Lane('echo', PRI_ECHO, lead.chan, ECHO_DETUNE)
            for s, e, note, ins, vol, vel, pan, bd in lead.notes:
                if s + ECHO_DELAY < length:
                    ec.notes.append((s + ECHO_DELAY, min(e + ECHO_DELAY, length), note, ins,
                                     max(1, int(round(vol * ECHO_LEVEL))), vel, -pan if pan else 25, bd))
            lanes.append(ec)
    voices = assign_voices(lanes, length)
    tracks = []; instruments = set()
    for k, l in enumerate(lanes):
        ev = []
        if k == 0:
            ev += [('tempo', 0), ('sfx-voices', SFX_VOICES)]
        first = l.notes[0]
        cur = dict(ins=first[3], vol=first[4], pan=first[6], vel=None)
        ev += [('volume', cur['vol']), ('priority', l.pri), ('instrument', cur['ins']), ('pan', cur['pan'] & 0xFF),
               ('voice', 4, voices[k], 1 << voices[k])]
        if l.detune:
            ev.append(('detune', l.detune))
        instruments.add(cur['ins'])
        t = 0
        for s, e, note, ins, vol, vel, pan, (b0, bch) in l.notes:
            if s > t:
                ev.append(('rest', s - t)); t = s
            if ins != cur['ins']:
                ev.append(('instrument', ins)); cur['ins'] = ins; instruments.add(ins)
            if vol != cur['vol']:
                ev.append(('volume', vol)); cur['vol'] = vol
            if pan != cur['pan']:
                ev.append(('pan', pan & 0xFF)); cur['pan'] = pan
            if velocity and l.chan != 15:                # (drums: no velocity, as FX3)
                vb = velocity_byte(vel, cur['vel'])
                if vb != cur['vel']:
                    ev.append(('velocity', vb)); cur['vel'] = vb
            ln = e - s
            if (bch or b0) and ln >= 2:                 # bent: the note, then its bend as a slide
                ev.append(('note', note, 1)); ev.append(('slide', slide_bytes(bch, ln, b0))); t = e
                continue
            while ln > 255:
                ev.append(('note', note, 255)); ev.append(('legato',)); ln -= 255
            ev.append(('note', note, ln)); t = e
        if t < length:
            ev.append(('rest', length - t))
        ev.append(('loop',) if loop else ('end',))
        tracks.append(ev)
    return tracks, instruments, uses


def assign_voices(lanes, length):
    """a DSP voice per track, as FX3 does (E5 4,v,bit: the track plays on voice v; a
    note takes it over from another track's note of the same or a lower priority).
    Tracks in order of priority, then of time sounding; each to the voice where it
    overlaps least with the tracks already there (overlap with a higher-priority track
    costs most: those notes are lost).  The 3 most important tracks get voices 0-2,
    which sound effects never take (SFX_VOICES)."""
    import numpy as np
    act = []
    for l in lanes:
        a = np.zeros(length + RELEASE_STEPS + 1, bool)
        for s, e, *_ in l.notes:
            a[s:min(e + RELEASE_STEPS, len(a))] = True
        act.append(a)
    order = sorted(range(len(lanes)), key=lambda k: (-lanes[k].pri, -act[k].sum()))
    placed = [[] for _ in range(8)]                         # voice -> [(priority, activity)]
    out = {}
    for rank, k in enumerate(order):
        def cost(v):
            c = 0
            for pri, a in placed[v]:
                c += (act[k] & a).sum() * (3 if pri > lanes[k].pri else 1)
            return (c, len(placed[v]), v)
        v = min(range(3) if rank < 3 else range(8), key=cost)
        out[k] = v; placed[v].append((lanes[k].pri, act[k]))
    return out


VEL_LEVELS = [int(round(255 * 10 ** (-db / 20))) for db in range(0, 40, 2)]   # 2 dB steps


def velocity_byte(vel, cur):
    """MUS velocity (0-127) -> driver velocity byte, on a 2 dB grid, kept when within 1.5 dB"""
    want = 255 * max(vel, 1) / 127
    if cur and abs(20 * math.log10(want / cur)) < 1.5:
        return cur
    return min(VEL_LEVELS, key=lambda v: abs(math.log(v / want)))


musiclib.CMD['voice'] = 0xE5


def build(lib, m, song_number, loop=True, limit=musiclib.SONG_END, log=None):
    """the module for MUS M: (groups, end, tracks, what was changed to fit).  To fit in
    sound RAM, in turn (stages): stand-ins for instruments with few notes, no echo, no
    guitar layer, no velocity detail, coarse bends, stand-ins in the same role, no
    bends, fewer chord notes."""
    opt = dict(echo=True, layers=True, velocity=True, max_chord=None, bend=1)
    subst = {}; done = []

    def make():
        tracks, ins, uses = arrange(m, loop=loop, subst=subst, **opt)
        tracks = musiclib.compress(tracks)
        try:
            groups, end = lib.module(ins, song_number, lambda base: musiclib.assemble(tracks, base))
        except struct.error:                    # (past the end of sound RAM: far too big)
            groups, end = [], 0x10000 + sum(len(t) for t in tracks)
        return groups, end, tracks, ins, uses

    def stand_in(ins, uses, rare):
        """the best (saving, instrument, stand-in) by bytes saved per note changed"""
        total = sum(uses.values()) or 1
        base = lib.size(ins); best = None
        for a in ins:
            if a in subst:
                continue
            if rare and uses[a] > 0.03 * total:
                continue
            for b in ROLES.get(ROLE.get(a), []):
                if b == a or b not in lib.ins or b in subst:    # (never back to a replaced one)
                    continue
                saving = base - lib.size((set(ins) - {a}) | {b})
                if saving < STANDIN_SAVING:
                    continue
                rank = ROLES[ROLE[a]].index(b) + 1
                score = saving / (1 + uses[a] * rank)
                if best is None or score > best[0]:
                    best = (score, a, b, saving)
        return best

    groups, end, tracks, ins, uses = make()
    stages = ['rare', 'echo', 'layers', 'velocity', 'bend4', 'role', 'nobend', 'chord3', 'chord2', 'chord1']
    rounds = 0
    while end > limit and stages and rounds < 40:
        rounds += 1
        st = stages[0]
        if st in ('rare', 'role'):
            b = stand_in(ins, uses, st == 'rare')
            if b is None:
                stages.pop(0); continue
            subst[b[1]] = b[2]
            for k, v in list(subst.items()):           # (chains: a -> b -> c)
                while v in subst: v = subst[v]
                subst[k] = v
            done.append('instrument %02X -> %02X' % (b[1], b[2]))
        else:
            stages.pop(0)
            if st == 'echo': opt['echo'] = False; done.append('no echo')
            elif st == 'layers': opt['layers'] = False; done.append('no guitar layer')
            elif st == 'velocity': opt['velocity'] = False; done.append('no velocity')
            elif st == 'bend4': opt['bend'] = 4; done.append('coarse bends')
            elif st == 'nobend': opt['bend'] = 0; done.append('no bends')
            else: opt['max_chord'] = int(st[-1]); done.append('chords: %s notes' % st[-1])
        groups, end, tracks, ins, uses = make()
    if end > limit:
        done.append('TOO BIG')
    return groups, end, tracks, done


# --------------------------------------------------------------------------
#   songs of a data set
# --------------------------------------------------------------------------
# DOOM II: level slot i (MAP i+1) -> music lump (DOOM II's S_music order)
DOOM2_MUSIC = ('RUNNIN STALKS COUNTD BETWEE DOOM THE_DA SHAWN DDTBLU IN_CIT DEAD STLKS2 THEDA2 DOOM2 '
               'DDTBL2 RUNNI2 DEAD2 STLKS3 ROMERO SHAWN2 MESSAG COUNT2 DDTBL3 AMPIE THEDA3 ADRIAN '
               'MESSG2 ROMER2 TENSE SHAWN3 OPENIN EVIL ULTIMA').split()
# The Ultimate DOOM's Episode 4 plays songs of the other episodes
DOOM_E4 = {'E4M1': 'E3M4', 'E4M2': 'E3M2', 'E4M3': 'E3M3', 'E4M4': 'E1M5', 'E4M5': 'E2M7',
           'E4M6': 'E2M4', 'E4M7': 'E2M6', 'E4M8': 'E2M5', 'E4M9': 'E1M9'}


def song_plan(data):
    """([(what, module, song#, lump, loop)], is DOOM II) for the title, the intermission
    and each level slot in use, from RLLEV/levels.inc and RLMUS/doommus.asm"""
    inc = open(os.path.join(data, 'RLLEV', 'levels.inc')).read()
    mus_asm = open(os.path.join(data, 'RLMUS', 'doommus.asm')).read()
    sym = {k: int(v, 16) for k, v in re.findall(r'^(\w+)\s+equ\s+\$([0-9A-Fa-f]+)', mus_asm, re.M)}
    doom2 = bool(re.search(r'^!RLEPISODELEN = 99', inc, re.M))
    slots = dict((int(i), n) for i, n in re.findall(r'^!lvl(\d+) = (\w+)$', inc, re.M))
    use = dict(re.findall(r'^!use(\w+) #= (\d)', inc, re.M))
    song = dict((int(i), int(v, 16)) for i, v in re.findall(r'^!lvlsong(\d+) = \$([0-9A-Fa-f]+)', inc, re.M))
    plan = [('title', sym['intro_sng_MODULE'], sym['intro_sng'], 'D_DM2TTL' if doom2 else 'D_INTRO', False),
            ('intermission', sym['inter_sng_MODULE'], sym['inter_sng'], 'D_DM2INT' if doom2 else 'D_INTER', True)]
    for i in sorted(slots):
        if use.get(slots[i], '1') != '1' or i not in song:
            continue
        if doom2:
            if i >= len(DOOM2_MUSIC):
                continue
            lump = 'D_' + DOOM2_MUSIC[i]
        else:
            lump = 'D_' + DOOM_E4.get(slots[i], slots[i])
        plan.append(('level %s' % slots[i], song[i] >> 8, song[i] & 0xFF, lump, True))
    return plan, doom2


def cmd_convert(a):
    data = a.data
    lib, src = library(data)
    lumps = {}
    for w in a.wad:                                 # (a later WAD's lumps win)
        lumps.update(mus.lumps(w))
    md = rlmusic.MusicData(os.path.join(data, 'RLDATA', 'MUSIC'))
    plan, doom2 = song_plan(data)
    if a.only:
        keep = {x.upper() if x.upper().startswith('D_') else 'D_' + x.upper() for x in a.only.split(',')}
        plan = [p for p in plan if p[3] in keep]
    # one module per lump; a module several lumps share stays with the first, the
    # others get new modules (and their level's !lvlsong changes)
    owner = {}; jobs = []; relink = {}
    for what, mod, num, lump, loop in plan:
        if lump not in lumps:
            print('%-14s %-8s not in the WAD: kept' % (what, lump)); continue
        if mod in owner and owner[mod] != lump:
            new = None
        else:
            new = mod
        owner.setdefault(mod, lump)
        key = (lump, new if new is not None else ('new', lump))
        if key not in [j[0] for j in jobs]:
            jobs.append((key, lump, new, num if new is not None else 0, loop, what))
        if new is None:
            relink.setdefault(lump, []).append(what)
    modules = []; at = []; built = []
    for key, lump, mod, num, loop, what in jobs:
        groups, end, tracks, done = build(lib, mus.Mus(lumps[lump]), num, loop=loop)
        if 'TOO BIG' in done:
            print('%-14s %-8s does not fit in sound RAM (%d bytes over): kept the cartridge song' % (what, lump, end - musiclib.SONG_END))
            continue
        modules.append(groups); at.append(mod)
        built.append((what, lump, mod, num, len(tracks), musiclib.SONG_END - end, done))
    nums = musiclib.add_modules(md, modules, at)
    inc_p = os.path.join(data, 'RLLEV', 'levels.inc'); inc = open(inc_p).read()
    slot_index = {n: k for k, n in re.findall(r'^!lvl(\d+) = (\w+)$', inc, re.M)}
    for (what, lump, mod, num, ntr, free, done), m in zip(built, nums):
        if mod is None:                             # a new module: the levels that play it
            num = 0
            for w2 in relink.get(lump, []):
                i = slot_index[w2.split()[1]]
                inc = re.sub(r'^!lvlsong%s = \$[0-9A-Fa-f]+$' % i, '!lvlsong%s = $%04X' % (i, m << 8 | num), inc, flags=re.M)
        print('%-14s %-8s module %2d song %2d  %2d tracks  %5d bytes free%s' % (
            what, lump, m, num, ntr, free, ('  (' + ', '.join(done) + ')') if done else ''))
    open(inc_p, 'w').write(inc)
    n = md.save()
    print('music: %d modules, MUSIC_C %d bytes -> %s' % (md.modules(), n, os.path.join(data, 'RLDATA', 'MUSIC')))


def library(data):
    for sub in ('RLMUSIC.fx3', os.path.join('RLDATA', 'MUSIC')):
        p = os.path.join(data, sub)
        if os.path.exists(os.path.join(p, 'MUSIC_I')):
            return musiclib.Library(rlmusic.MusicData(p)), p
    sys.exit('%s: no music data' % data)


def cmd_song(a):
    import spcrender
    lib, src = library(a.data)
    lumps = {}
    for w in a.wad:
        lumps.update(mus.lumps(w))
    os.makedirs(a.out, exist_ok=True)
    md = rlmusic.MusicData(os.path.join(a.data, 'RLDATA', 'MUSIC'))
    for name in a.lumps:
        m = mus.Mus(lumps[name.upper()])
        groups, end, tracks, done = build(lib, m, 0, loop=True)
        img = bytearray(spcrender.ram_image(md, 0))
        for d, b in groups:
            img[d:d + len(b)] = b
        s = type('S', (), {})(); s.module = 2; s.number = 0
        fn = os.path.join(a.out, '%s.wav' % name.upper())
        spcrender.render(md, a.data, s, fn, a.seconds, bytes(img))
        print('%-8s %2d tracks, ends $%04X (%d bytes free)%s -> %s' % (
            name.upper(), len(tracks), end, musiclib.SONG_END - end,
            (' (' + ', '.join(done) + ')') if done else '', fn))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[1])
    sub = ap.add_subparsers(dest='cmd', required=True)
    p = sub.add_parser('convert')
    p.add_argument('--data', default=os.path.join(HERE, '..', '..', 'data')); p.add_argument('--wad', action='append', required=True)
    p.add_argument('--only', help='comma-separated lumps (D_RUNNIN,...) to convert, the rest kept')
    p = sub.add_parser('song')
    p.add_argument('lumps', nargs='+'); p.add_argument('--data', default=os.path.join(HERE, '..', '..', 'data'))
    p.add_argument('--wad', action='append', required=True); p.add_argument('--out', required=True)
    p.add_argument('--seconds', type=float, default=60)
    a = ap.parse_args()
    {'song': cmd_song, 'convert': cmd_convert}[a.cmd](a)


if __name__ == '__main__':
    main()
