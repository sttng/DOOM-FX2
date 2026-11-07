"""
rlmus.py -- write RLMUS/dcom.i and RLMUS/doommus.asm (song / effect / driver command
numbers), read from the FX3 cartridge (THE ULTIMATE DOOM).

  effects   FX3's effect table (file $005F0B: 29 rows of $80,effect3,$D0,effect2,$FF,
            effect1) under the names of the DOOM-FX source's rlsound3.a (28 rows; FX3
            reordered the rows and added some, so ROWS gives the FX3 row that holds
            each one's sounds), FX3's DemonDie row, and the effect numbers FX3's GSU
            code loads itself (CODE)
  songs     FX3's song list (file $3BFE36: module<<8 | song per song, SONG_ORDER)
  commands  the music driver commands FX3's 65816 code loads (DCOM), and the APU
            blast buffer (the first turbo slot's address and the buffer end)

Code values are found by the instructions around them (PAT: hex bytes, '..' any
byte, '??' the value); each pattern must match exactly once.
"""
import os, re, struct

TABLE, TABLE_ROWS = 0x005F0B, 29
ROWS = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 12, 15, 16, 17, 18, 19,
        17,                 # skldth: the lost soul dies with the cacodemon's death effects
        21, 22, 23,
        7,                  # (the second pistol row)
        25, 26, 27, 28)
DEMONDIE_ROW = 14           # FX3-only: sgtdth (DemonDie)
SONGS = 0x3BFE36
SONG_ORDER = ('intro', 'inter', 'e1m1', 'e1m2', 'e1m3', 'e1m4', 'e1m5', 'e1m6', 'e1m7', 'e1m8', 'e1m9',
              'e2m1', 'e2m2', 'e2m4', 'e2m6', 'e2m7', 'e2m8', 'e2m9', 'e3m2', 'e3m3', 'e3m8',
              'fx3title', 'fx3title2')
SONG_OUT = ('intro', 'inter', 'e1m1', 'e1m2', 'e1m3', 'e1m4', 'e1m5', 'e1m6', 'e1m7', 'e1m8', 'e1m9',
            'e2m2', 'e2m4', 'e2m6', 'e2m7', 'e2m8', 'e2m9', 'e3m2', 'e3m8',
            'fx3title2', 'fx3title', 'e2m1', 'e3m3')      # (doommus.asm order)

# GSU code (bank $00): the effect in ibt r3,#e / the low byte of iwt r3,#(rumble<<8)|e
CODE = (
    (('swtchn_eff', 'noway_eff'), 'a3 ?? 05 .. 01 a3 ??', 'use: switch, nothing to use'),
    (('swtchx_eff',), '3e a4 .. a3 ?? fb .. .. ff 05 df', 'exit switch'),
    (('itemup_eff',), 'f0 b4 00 3e a0 .. a3 ?? 94 ff 05 df', 'item picked up (after its 3-second message)'),
    (('plpain_eff',), '3d 31 a3 ?? 3e a6 .. 94 ff 05 df', '_RLDamagePlayer'),
    (('pldeth_eff',), '94 ff .. .. 90 a3 ?? 94 ff 05 df', 'player dies (after _RLDropWeapon)'),
    (('punch_eff',), 'f4 07 02 f3 ?? 0c', '_RLFireFist'),
    (('pistol_eff',), 'f4 07 03 f3 ?? 0d', '_RLFirePistol'),
    (('shotgn_eff',), 'f4 03 20 f3 ?? 0e', '_RLFireShotGun'),
    (('firsht_eff',), 'f3 ?? 12 a5 01', '_RLFireRocket'),
    (('sawidl_eff',), '2b 1a a3 ?? 94 ff 05 df 01 a2 4f', '_RLReadyChainSaw2'),
    (('sawful_eff',), 'a3 ?? ff 05 df 01 3d a0', '_RLChainSawNull'),
)
CODE_CHECK = ((('pistol_eff',), '2b 1a a3 ?? 94 ff 05 df 01 2a', '_RLChainGunLight0'),)
# 65816 code: lda #command (musicdrv, rllevels, rlsound)
DCOM = (
    (('DCOM_START_SONG', 'DCOM_FADEIN'), 'a9 ?? 00 22 .. .. .. a9 ?? 00 a0 01 7f 5c', '_PlaySong'),
    (('DCOM_STOP_SONG', 'DCOM_STOP_SOUND', 'DCOM_FADE_AND_STOP'),
     'a9 ?? 00 a0 00 00 22 .. .. .. a9 ?? 00 a0 80 80 22 .. .. .. a9 ?? 00 a0 01 7f 22', '_LoadSong'),
    (('DCOM_RELOAD',), 'bf .. .. .. 48 a9 ?? 00 22', '_LoadModule2'),
    (('DCOM_RUN',), '68 20 .. .. a9 ?? 5c', '_LCL800'),
    (('DCOM_ALLOCATION_MODE',), 'a0 01 00 a9 ?? 00 22', 'level start'),
    (('DCOM_SLOW_BLAST',), 'a9 ?? eb ad .. .. 1a 30 02 a9 80', 'turbo sound start'),
    (('DCOM_BLAST_ADDR',), 'bb bc .. .. a9 ?? 00 22 .. .. .. b0', 'turbo sound'),
    (('DCOM_SETWAVEASBLAST',), 'be .. .. bc .. .. a9 ?? 00 22 .. .. .. 90', 'turbo sound'),
    (('DCOM_SET_NEXT_EFFECT_VOL', 'DCOM_START_EFFECT'), 'a9 ?? 00 22 .. .. .. b0 .. a6 .. bc .. .. a9 ?? 00 22', 'sound effect'),
)
DCOM_CHECK = ((('DCOM_RELOAD', 'DCOM_RUN'), 'e2 20 c9 ?? f0 .. c9 ?? d0', '_SendDriverCommand'),
              (('DCOM_START_SONG', 'DCOM_FADEIN'), 'a9 ?? 00 22 .. .. .. a9 ?? 00 a0 01 10 5c', 'level start'))
BLAST_ADDR = 'a9 80 ff 8d .. .. 8d .. .. 8d .. .. 8d .. .. a9 ?? ?? 8d'   # turbo slots: idle, then the 1st's base
BLAST_END = 'a2 ?? ?? 8d 42 21'                                     # ldx #(address+size-3), sta APUIO2
UNREF = {'wpnup_eff': 0x06, 'logo1_eff': 0x07}                       # not used by FX3's code (value arbitrary)


def find(rom, pat, what, end=None):
    """the '??' bytes of the one match of PAT (in ROM[:end])"""
    rx = b''.join(b'(.)' if t == '??' else b'.' if t == '..' else re.escape(bytes([int(t, 16)])) for t in pat.split())
    hits = list(re.finditer(rx, rom[:end] if end else rom, re.S))
    assert len(hits) == 1, '%s: %d matches of %s' % (what, len(hits), pat)
    return [g[0] for g in hits[0].groups()]


def write(fx3, rlsound3, outdir):
    F = fx3
    names = [re.match(r'\s*dc\.b\s+(\S+)', l).group(1) for l in open(rlsound3, encoding='latin1')
             if re.match(r'\s*dc\.b\s+\S', l.split(';')[0])]
    assert len(names) == 6 * len(ROWS)
    rows = [F[TABLE + 6 * r:TABLE + 6 * r + 6] for r in range(TABLE_ROWS)]
    assert all(r[0] == 0x80 and r[2] == 0xD0 and r[4] == 0xFF for r in rows), 'FX3 effect table'
    eff = {}; conflicts = []
    for i, n in enumerate(names):
        v = rows[ROWS[i // 6]][i % 6]
        if n.endswith('_eff'):
            if n in eff and eff[n] != v: conflicts.append((n, eff[n], v))
            eff.setdefault(n, v)
        else:
            assert int(n.replace('$', '0x'), 16) == v, (i, n, v)
    for keys, pat, what in CODE:
        for k, v in zip(keys, find(F, pat, what, 0x200000)):
            if k in eff and eff[k] != v: conflicts.append((k, eff[k], v))
            eff[k] = v
    for keys, pat, what in CODE_CHECK:
        assert find(F, pat, what, 0x200000) == [eff[k] for k in keys], what
    d = rows[DEMONDIE_ROW]
    fx3only = {'sgtdth3_eff': d[1], 'sgtdth2_eff': d[3], 'sgtdth_eff': d[5]}
    eff.update(fx3only)
    eff.update(UNREF)
    w = struct.unpack_from('<%dH' % len(SONG_ORDER), F, SONGS)
    songs = {s: (v >> 8, v & 0xFF) for s, v in zip(SONG_ORDER, w)}
    dcom = {}
    for keys, pat, what in DCOM:
        dcom.update(zip(keys, find(F, pat, what)))
    for keys, pat, what in DCOM_CHECK:
        assert find(F, pat, what) == [dcom[k] for k in keys], what
    lo, hi = find(F, BLAST_ADDR, 'turbo slot bases'); blast = lo | hi << 8
    lo, hi = find(F, BLAST_END, 'blast buffer end'); blast_size = (lo | hi << 8) + 3 - blast
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, 'dcom.i'), 'w') as f:
        f.write(';\tSculptured music driver command codes -- read from the FX3 cartridge (tools/datagen/rlmus.py)\n')
        for k in sorted(dcom): f.write('%s\tequ\t$%02X\n' % (k, dcom[k]))
    with open(os.path.join(outdir, 'doommus.asm'), 'w') as f:
        f.write(';\tSong / effect numbers -- read from the FX3 cartridge, The Ultimate Doom (tools/datagen/rlmus.py)\n')
        f.write('BlastBufferAddress\tequ\t$%04X\nBlastBufferSize\tequ\t$%04X\n' % (blast, blast_size))
        for s in SONG_OUT:
            m, n = songs[s]
            f.write('%s_sng\tequ\t$%02X\n%s_sng_MODULE\tequ\t$%02X\n' % (s, n, s, m))
        for k in sorted(eff):
            c = ''
            if k in UNREF: c = '\t; not used by the FX3 code (value arbitrary)'
            elif k in fx3only: c = '\t; FX3-only effect (DemonDie)'
            elif k.startswith('skldth'): c = '\t; FX3: the cacodemon death effects'
            f.write('%s\tequ\t$%02X%s\n' % (k, eff[k], c))
    return conflicts
