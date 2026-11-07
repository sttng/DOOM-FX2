#!/usr/bin/env python3
"""
wad2soundfx.py -- sound effects from a DOOM WAD for the SNES sound driver.

DOOM's DS* sounds are resampled to the rate the Sculptured driver plays each
one at (4000-11025 Hz), cut to fit, scaled to the cartridge's level (with a
look-ahead peak limiter, limit()) and stored as BRR:

  * 7 samples stay in sound RAM (module 0, $290B-$5E27): noway, switch, plpain,
    door open/close, punch, chainsaw.  They keep their size, so the sound RAM
    layout does not change.
  * 27 "turbo" samples (weapons, monsters, lifts, teleport) are streamed by the
    65816 into one of four 3,321-byte slots of the APU blast buffer
    (rlsound.asm); in ROM they are MUSIC_C chunks found through the turbo
    table (MUSIC_O.C).
  * itemup/wpnup use a synthesized tone; left alone.
  * The demon death sample (DSSGTDTH, effect $2F) is never played: the demon
    and the spectre die with the imp's death sound.  Its slot holds DOOM II's
    super shotgun (DSDSHTGN, whole, at the slot's 4 kHz; dshtgn_eff in
    music.inc) when the WAD has it, else one silent block (REPLACE).
  * The cartridge chainsaw has one sample (DSSAWIDL) for idling and cutting.
    This port adds three turbo sounds (NEWTURBO): cutting (DSSAWFUL, effect
    $18; original: the idle sample), raising (DSSAWUP) and hitting (DSSAWHIT)
    in the two quieter variants of the demon death effect ($49, $63).  They
    share the super shotgun's sample number (only one weapon sounds at a time;
    the 65816 tells turbo sounds apart by their data address, rlsound.asm) and its effect
    record (the demon death's: 4000 Hz, so a slot holds 1.47 s), at the WAD's
    own level (NEWTURBO_GAIN 1.0: no boost).

  learn    match each cartridge sample (RLDATA/MUSIC) to its WAD lump: rate,
           start offset, gain -> DATA/wad2soundfx.json; backs up the
           cartridge data to DATA/RLMUSIC.fx3 (for 'restore')
  convert  rebuild the samples from the WAD with those rules.  --full: turbo
           sounds as long as the WAD sound (up to the slot size).
           --drop-missing: a turbo sound the WAD lacks becomes one silent
           block instead of the cartridge sample (shareware WAD).
  compare  per sample: correlation with the cartridge; --wav DIR writes
           cartridge/converted WAV pairs
  restore  put the cartridge sound data back

EFFECT_PITCH was measured in Mesen (S-DSP pitch at key-on of every effect;
Hz = pitch * 32000 / 4096).

usage: wad2soundfx.py learn   --data DATA --wad DOOM.WAD
       wad2soundfx.py convert --data DATA --wad DOOM.WAD [--wad PWAD] [--full] [--drop-missing]
       wad2soundfx.py compare --data DATA --wad DOOM.WAD [--wav DIR]
       wad2soundfx.py restore --data DATA
"""
import argparse, json, os, re, shutil, struct, sys, wave
from fractions import Fraction

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import numpy as np                      # noqa: E402
import brr                              # noqa: E402
import rlmusic                          # noqa: E402
from wad import directory as wadlumps   # noqa: E402

MUSIC = os.path.join('RLDATA', 'MUSIC')
BACKUP = 'RLMUSIC.fx3'
RULES = 'wad2soundfx.json'

EFFTAB, INSTAB, SAMPTAB = 0x2080, 0x2156, 0x1F00   # driver tables in module 0 (sound RAM)
NEFF, NINS = 106, 35
RESIDENT = 0x2908                                     # module 0 chunk with the resident samples
SLOT = (0x33F7 // 4) // 9 * 9                         # turbo slot bytes (rlsound.asm)
TURBO_HDR = 3                                         # bytes before the BRR in a turbo chunk

# S-DSP pitch of the first effect that plays each sample (measured, see above)
EFFECT_PITCH = {
    0x00: 0x02FF, 0x03: 0x0400, 0x08: 0x023E, 0x0E: 0x02FF, 0x0F: 0x02FF, 0x14: 0x0583, 0x17: 0x0260,
    0x19: 0x047D, 0x1C: 0x0200, 0x1D: 0x0200, 0x1E: 0x02FF, 0x1F: 0x0200, 0x20: 0x027F, 0x21: 0x0200,
    0x22: 0x0364, 0x23: 0x02FF, 0x24: 0x032C, 0x25: 0x0364, 0x26: 0x02FF, 0x27: 0x03BE, 0x28: 0x03BE,
    0x29: 0x02FF, 0x2A: 0x0315, 0x2B: 0x02FF, 0x2C: 0x047D, 0x2D: 0x047D, 0x2E: 0x047D, 0x2F: 0x0200,
    0x30: 0x0200, 0x31: 0x041E, 0x32: 0x02FF, 0x33: 0x037E, 0x34: 0x057E, 0x35: 0x03BE,
}
# effect names (doommus.asm) whose WAD lump is not DS + the name
LUMP_NAMES = {'DOOROPEN': 'DSDOROPN', 'DOORCLOS': 'DSDORCLS'}
# effects without a name in doommus.asm: their sample was identified by comparing
# spectrograms with every DS lump (correlation 0.88)
UNNAMED = {0x1C: 'DSBGACT'}


# --------------------------------------------------------------------------
#   WAD sounds
# --------------------------------------------------------------------------
def wad_sounds(paths):
    """DS* lumps of the WADs (later ones override): name -> (rate, float samples)"""
    out = {}
    for p in paths:
        d = open(p, 'rb').read()
        for nm, q, s in wadlumps(d):
            if not nm.startswith('DS') or s < 8:
                continue
            fmt, rate, cnt = struct.unpack_from('<HHI', d, q)
            if fmt != 3:
                continue
            x = (np.frombuffer(d[q + 8:q + 8 + cnt], dtype=np.uint8).astype(float) - 128) / 128
            if cnt > 32:
                x = x[16:-16]                   # DMX pads 16 samples at each end
            out[nm] = (rate, x)
    return out


def resample(x, src, dst):
    from scipy.signal import resample_poly
    f = Fraction(dst / src).limit_denominator(1000)
    return resample_poly(x, f.numerator, f.denominator)


# --------------------------------------------------------------------------
#   the cartridge's samples
# --------------------------------------------------------------------------
def effect_names(data):
    names = {}
    p = os.path.join(data, 'RLMUS', 'doommus.asm')
    for l in open(p):
        m = re.match(r'(\w+)_eff\s+equ\s+\$([0-9A-Fa-f]+)', l)
        if m:
            names.setdefault(int(m.group(2), 16), m.group(1))
    return names


def samples(md, names):
    """the convertible samples: [{key, effect, lump, kind, ...}] in the data set"""
    a = md.aram(0)
    eff = [struct.unpack_from('<H', a, EFFTAB + 2 * i)[0] for i in range(NEFF)]
    ins = [struct.unpack_from('<H', a, INSTAB + 2 * i)[0] for i in range(NINS)]
    tc = md.turbo_chunks()
    res = [g for g in md.module(0) if g[0] == RESIDENT][0]
    out, seen = [], set()
    for e in range(NEFF):
        rec = a[eff[e]:eff[e] + 9]
        if e in tc:
            key = 'turbo:%d' % tc[e]
        else:
            i = ins[rec[1]]
            if a[i] == 3:                       # synthesized instrument
                continue
            st = struct.unpack_from('<H', a, SAMPTAB + 4 * a[i + 2])[0]
            key = 'ram:%04X' % st
        if key in seen:
            continue
        seen.add(key)
        nm = names.get(e)
        lump = UNNAMED.get(e) or LUMP_NAMES.get((nm or '').upper()) or ('DS' + nm.upper() if nm else None)
        s = dict(key=key, effect=e, name=nm or '', lump=lump, pitch=EFFECT_PITCH.get(e))
        if key.startswith('turbo'):
            c = tc[e]; data = md.chunk(c)
            s.update(kind='turbo', chunk=c, header=data[:TURBO_HDR].hex(), bytes=len(data) - TURBO_HDR)
        else:
            st = int(key[4:], 16)
            pcm_len, nbytes = 0, 0
            while True:
                h = a[st + nbytes]; nbytes += 9
                if h & 1:
                    break
            s.update(kind='ram', addr=st, bytes=nbytes, last=a[st + nbytes - 9] & 3, chunk=res[1][0])
        out.append(s)
    return out


def cart_pcm(md, s):
    if s['kind'] == 'turbo':
        return brr.decode(md.chunk(s['chunk'])[TURBO_HDR:])
    a = md.aram(0)
    return brr.decode(bytes(a[s['addr']:s['addr'] + s['bytes']]))


def hz(s):
    return s['pitch'] * 32000 / 4096


# --------------------------------------------------------------------------
#   learn
# --------------------------------------------------------------------------
def best_offset(y, x):
    """offset of y in x (normalized cross-correlation of waveforms, then of
    envelopes); y may start before or end after x. Returns (offset, correlation)"""
    from scipy.signal import fftconvolve
    def ncc(a, b):
        p = len(b)
        a = np.pad(a, (p, p))
        c = fftconvolve(a, b[::-1], mode='valid')
        ea = np.convolve(a * a, np.ones(len(b)), mode='valid')
        e = np.sqrt(ea) * np.linalg.norm(b) + 1e-9
        v = np.where(ea > 0.3 * ea.max(), c / e, -1)   # windows mostly outside x do not count
        i = int(np.argmax(v))
        return i - p, float(v[i])
    o, v = ncc(x, y)
    if v < 0.5:
        env = lambda z: np.convolve(np.abs(z), np.ones(64) / 64, mode='same')
        o, _ = ncc(env(x), env(y))
    return o, v


def spec_offset(y, x, n=128, hop=32):
    """offset of y in x by correlating log spectrograms (phase-free, for noise)"""
    def spec(z):
        if len(z) < n:
            z = np.pad(z, (0, n - len(z)))
        fr = np.lib.stride_tricks.sliding_window_view(z, n)[::hop] * np.hanning(n)
        s = np.log1p(np.abs(np.fft.rfft(fr, axis=1)) * 8)
        return (s - s.mean()) / (s.std() + 1e-9)
    sy, sx = spec(y), spec(x)
    k = min(len(sy), len(sx)) * 2 // 3          # compare the first two thirds of the shorter
    best = (-1, 0)
    for o in range(-len(sy) + k, len(sx) - k + 1):
        a0, b0 = max(o, 0), max(-o, 0)
        m = min(len(sx) - a0, len(sy) - b0)
        if m < k:
            continue
        v = float((sx[a0:a0 + m] * sy[b0:b0 + m]).mean())
        if v > best[0]:
            best = (v, o)
    return best[1] * hop, best[0]


def learn(a):
    data = a.data
    md = rlmusic.MusicData(os.path.join(data, MUSIC))
    bk = os.path.join(data, BACKUP)
    if not os.path.isdir(bk):
        shutil.copytree(os.path.join(data, MUSIC), bk)
    W = wad_sounds(a.wad)
    rules = []
    for s in samples(md, effect_names(data)):
        if s['lump'] not in W or not s['pitch']:
            print('%-9s %s: no WAD lump / rate, kept' % (s['name'], s['key'])); continue
        rate, x = W[s['lump']]
        y = cart_pcm(md, s).astype(float) / 32768
        # the rate the cartridge resampled at: near the playback rate (the pitch
        # register is quantized, and some sounds are played a little higher)
        best = (-1, hz(s), 0)
        for f in np.arange(0.85, 1.1501, 0.005):
            o, v = best_offset(y, resample(x, rate, hz(s) * f))
            if v > best[0]:
                best = (v, hz(s) * f, o)
        for f in np.arange(-0.005, 0.0051, 0.0005):
            r = best[1] * (1 + f)
            o, v = best_offset(y, resample(x, rate, r))
            if v > best[0]:
                best = (v, r, o)
        v, src, off = best
        how = 'waveform'
        if v < 0.5:                            # noise-like, no waveform match: the playback rate,
            src = hz(s)                        # start from the spectrograms (else the sound's start)
            off, v = spec_offset(y, resample(x, rate, src))
            how = 'spectrum'
            if v < 0.5:
                off, how = 0, 'start'
        xr = resample(x, rate, src)
        seg = xr[max(off, 0):max(off, 0) + len(y)]
        gain = float(np.sqrt((y ** 2).mean() / max((seg ** 2).mean(), 1e-9)))
        s['rate'] = round(src, 1)
        s.update(offset=off, gain=round(gain, 3), corr=round(v, 3), match=how, samples=len(y), wad_samples=len(xr))
        rules.append(s)
        print('%-9s %-9s plays at %5.0f Hz, made at %5.0f Hz  %4d bytes  start %+5d of %5d  gain %.2f  corr %.2f' % (
            s['name'] or '?', s['lump'], hz(s), src, s['bytes'], off, len(xr), gain, v) + '  (%s)' % how)
    json.dump(dict(samples=rules), open(os.path.join(data, RULES), 'w'), indent=1)
    print('%d samples -> %s' % (len(rules), os.path.join(data, RULES)))


# --------------------------------------------------------------------------
#   convert
# --------------------------------------------------------------------------
def limit(y, level=0.92, w=24):
    """look-ahead peak limiter (the cartridge gain takes most WAD sounds past full scale;
    clipping crackles).  Per-sample gain min(1, level/|y|), minimum over +-w samples, then
    smoothed over w: it falls before a peak and recovers after.  level leaves BRR headroom."""
    from scipy.ndimage import minimum_filter1d, uniform_filter1d
    g = np.minimum(1.0, level / np.maximum(np.abs(y), 1e-9))
    g = uniform_filter1d(minimum_filter1d(g, 2 * w + 1, mode='nearest'), w, mode='nearest')
    return y * g


def make_pcm(s, W, full=False):
    rate, x = W[s['lump']]
    xr = resample(x, rate, s['rate']) * s['gain']
    off = s['offset']
    seg = xr[off:] if off >= 0 else np.concatenate([np.zeros(-off), xr])
    if s['kind'] == 'ram':
        n = s['bytes'] // 9 * 16                # same size: the sound RAM layout stays
    elif full:
        n = min(len(seg), (SLOT - TURBO_HDR) // 9 * 16)
    else:
        n = s['bytes'] // 9 * 16
    cut = len(seg) > n
    seg = np.concatenate([seg[:n], np.zeros(max(0, n - len(seg)))])
    if cut:                                     # short fade instead of a click
        f = min(256, n // 4)
        seg[n - f:] *= np.linspace(1, 0, f)
    pcm = np.clip(np.round(limit(seg) * 32767), -32768, 32767).astype(int)
    # trailing silence of a turbo sound costs streaming time: drop it
    if s['kind'] == 'turbo':
        nz = np.nonzero(np.abs(pcm) > 64)[0]
        end = (int(nz[-1]) + 16) // 16 * 16 + 16 if len(nz) else 16
        pcm = pcm[:min(end, len(pcm))]
    return pcm


# slots the engine never plays, given to another sound: rule name -> WAD lump
REPLACE = {'sgtdth': 'DSDSHTGN'}
# new turbo sounds: effect# -> WAD lump.  Effect record: the demon death's ($2F: 4000 Hz,
# as the super shotgun in its slot) with instrument $1C (sample number = BWave 30); turbo
# table: BWave 30.  NEWTURBO_GAIN: their level against the WAD's (1.0: as in the WAD)
NEWTURBO = {0x18: 'DSSAWFUL', 0x49: 'DSSAWUP', 0x63: 'DSSAWHIT'}
NEWTURBO_TEMPLATE, NEWTURBO_INSTR, NEWTURBO_BWAVE, NEWTURBO_GAIN = 0x2F, 0x1C, 30, 1.0


def convert(a):
    data = a.data
    rules = json.load(open(os.path.join(data, RULES)))['samples']
    gains = {r['name']: r['gain'] for r in rules}
    md = rlmusic.MusicData(os.path.join(data, BACKUP))       # always from the cartridge data
    W = wad_sounds(a.wad)
    res_chunk = None
    for s in rules:
        if s['name'] in REPLACE:
            lump = REPLACE[s['name']]
            if lump in W:                       # whole, at the slot's rate, the shotgun's level
                t = dict(s, lump=lump, offset=0, gain=gains.get('shotgn', 1.0))
                b = brr.encode(make_pcm(t, W, full=True))
                assert len(b) + TURBO_HDR <= SLOT
            else:
                b = brr.encode(np.zeros(16, int))
            md.data[md.chunks[s['chunk']][0]] = bytes.fromhex(s['header']) + b
            print('%-9s %-9s %5.0f Hz  %4d bytes (the %s slot, never played)' % (
                lump.lower()[2:], lump if lump in W else '(none)', s['rate'], len(b), s['lump']))
            continue
        if s['lump'] not in W:
            if not (a.drop_missing and s['kind'] == 'turbo'):
                print('%-9s %s missing in the WAD: cartridge sample kept' % (s['name'], s['lump'])); continue
            # --drop-missing: one silent BRR block instead of the cartridge sample
            b = brr.encode(np.zeros(16, int))
            md.data[md.chunks[s['chunk']][0]] = bytes.fromhex(s['header']) + b
            print('%-9s %s missing in the WAD: left out (%d bytes, cartridge %d)' % (s['name'], s['lump'], len(b), s['bytes']))
            continue
        pcm = make_pcm(s, W, a.full)
        if s['kind'] == 'ram':
            b = brr.encode(pcm)
            assert len(b) == s['bytes'], (s['name'], len(b), s['bytes'])
            b = bytearray(b); b[-9] = (b[-9] & ~3) | s['last'] | 1
            ca = md.chunks[s['chunk']][0]
            if res_chunk is None:
                res_chunk = bytearray(md.data[ca])
            o = s['addr'] - RESIDENT
            res_chunk[o:o + len(b)] = b
        else:
            b = brr.encode(pcm)
            assert len(b) + TURBO_HDR <= SLOT
            md.data[md.chunks[s['chunk']][0]] = bytes.fromhex(s['header']) + b
        print('%-9s %-9s %5.0f Hz  %4d bytes (cartridge %d)' % (s['name'] or '?', s['lump'], hz(s), len(b), s['bytes']))
    # new turbo sounds (NEWTURBO): effect records in the resident chunk, new chunks
    rc = [r for r in rules if r['kind'] == 'ram'][0]['chunk']
    if res_chunk is None:
        res_chunk = bytearray(md.data[md.chunks[rc][0]])
    a = md.aram(0)
    eff = [struct.unpack_from('<H', a, EFFTAB + 2 * i)[0] for i in range(NEFF)]
    tmap = md.turbo_chunks()
    tpl = bytearray(a[eff[NEWTURBO_TEMPLATE]:eff[NEWTURBO_TEMPLATE] + 9])
    tpl[1] = NEWTURBO_INSTR
    tr = [r for r in rules if r['effect'] == NEWTURBO_TEMPLATE][0]
    t = dict(tr, offset=0, gain=NEWTURBO_GAIN, rate=hz(tr))
    for e, lump in sorted(NEWTURBO.items()):
        if lump in W:
            b = brr.encode(make_pcm(dict(t, lump=lump), W, full=True))
        else:
            b = brr.encode(np.zeros(16, int))
        assert len(b) + TURBO_HDR <= SLOT
        o = eff[e] - RESIDENT
        res_chunk[o:o + 9] = tpl
        fake = 0x7F0000 + e                     # (a new chunk: save() places it in MUSIC_C)
        md.chunks.append((fake, 0)); md.data[fake] = bytes.fromhex(tr['header']) + b
        tmap[e] = len(md.chunks) - 1
        md.turbo[e][0] = NEWTURBO_BWAVE
        print('%-9s %-9s %5.0f Hz  %4d bytes (new turbo sound, effect $%02X)' % (
            lump.lower()[2:], lump if lump in W else '(none)', hz(tr), len(b), e))
    md.data[md.chunks[rc][0]] = bytes(res_chunk)
    out = os.path.join(data, MUSIC)
    n = md.save(out, turbo_map=tmap)
    print('sound effects from the WAD -> %s (MUSIC_C %d bytes)' % (out, n))


# --------------------------------------------------------------------------
#   compare / restore
# --------------------------------------------------------------------------
def write_wav(path, pcm, rate):
    w = wave.open(path, 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(int(rate))
    w.writeframes(np.asarray(pcm, dtype='<i2').tobytes()); w.close()


def compare(a):
    data = a.data
    rules = json.load(open(os.path.join(data, RULES)))['samples']
    cart = rlmusic.MusicData(os.path.join(data, BACKUP))
    cur = rlmusic.MusicData(os.path.join(data, MUSIC))
    if a.wav:
        os.makedirs(a.wav, exist_ok=True)
    for s in rules:
        y = cart_pcm(cart, s); z = cart_pcm(cur, s)
        n = min(len(y), len(z))
        c = float(np.corrcoef(y[:n].astype(float), z[:n].astype(float))[0, 1]) if n > 16 else 0
        same = len(y) == len(z) and np.array_equal(y, z)
        print('%-9s %-9s %5.0f Hz  cartridge %5d  now %5d samples  %s' % (
            s['name'] or '?', s['lump'], hz(s), len(y), len(z), 'identical' if same else 'corr %.2f' % c))
        if a.wav:
            nm = (s['name'] or s['lump']).lower()
            write_wav(os.path.join(a.wav, nm + '_cart.wav'), y, hz(s))
            write_wav(os.path.join(a.wav, nm + '_now.wav'), z, hz(s))


def restore(a):
    bk = os.path.join(a.data, BACKUP)
    if not os.path.isdir(bk):
        sys.exit('%s missing (run learn first)' % bk)
    out = os.path.join(a.data, MUSIC)
    shutil.rmtree(out)
    shutil.copytree(bk, out)
    print('cartridge sound effects restored')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[1])
    ap.add_argument('cmd', choices=('learn', 'convert', 'compare', 'restore'))
    ap.add_argument('--data', default=os.path.join(HERE, '..', 'data'))
    ap.add_argument('--wad', action='append', default=[])
    ap.add_argument('--full', action='store_true', help='convert: turbo sounds as long as the WAD sound (up to the slot size)')
    ap.add_argument('--drop-missing', action='store_true',
                    help='convert: turbo sounds the WAD lacks become silent instead of keeping the cartridge sample (shareware WAD)')
    ap.add_argument('--wav', help='compare: write WAV pairs here')
    a = ap.parse_args()
    {'learn': learn, 'convert': convert, 'compare': compare, 'restore': restore}[a.cmd](a)


if __name__ == '__main__':
    main()
