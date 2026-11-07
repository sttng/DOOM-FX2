"""
fx3_music.py -- extract the Sculptured SPC music driver + song/sample chunks from the
FX3 ROM and rebuild them in the DOOM-FX formats (musicdrv.asm / musicdat.asm):

  MUSIC_B.C   DeCompress blob : SPC boot code   (uploaded to APU $0700)
  MUSIC_D.C   DeCompress blob : SPC driver code (uploaded to APU $0700)
  MUSIC_I     word[52]        : module -> offset into MUSIC_L
  MUSIC_L     chunk lists     : { word APUdest, word chunk#..., word -1 } ..., word 0
  MUSIC_T     5 bytes/chunk   : LOAD.L (24 bit CPU address) , SIZE.W
                                (SIZE bit15 = RLC packed: chunk = word unpacked size + RLC
                                 stream, low 15 bits = stream length; else raw byte count)
  MUSIC_O.C   DeCompress blob : turbo sound-effect table (-> musicdrv.asm __MusicTurboTable)
  MUSIC_C     chunk data; MUSIC_T/MUSIC_O.C addresses are built for $47:0000 (the source's
              MUSICDAT.A ORG), musicdat.asm relocates them to where layout.py puts it

FX3 keeps the same driver protocol and tables, but packs its music chunks and the
boot/driver/turbo blobs with its new compressors (DeCompress types $10/$14), which the
engine cannot unpack.  They are unpacked by emulating the FX3 65816 code and repacked
with RLC (snescomp); a blob FX3 packs in one of the engine's formats is kept as it is.
Optional verification: every repacked blob and chunk is unpacked again with the FX3
cartridge's 65816 DeCompress (emulated, fx3dec.FX3Verifier).
"""
import os, struct
import snescomp as sc
from .fx3dec import run_decompress, FX3_DECOMPRESS
from .emu65816 import fx3_mapper

MB = 0x3b0000                      # FX3 music driver data bank ($FB)
OFF_BOOT, OFF_DRV, OFF_IDX, OFF_LST, OFF_TAB, OFF_TURBO = 0x0000, 0x0063, 0x143c, 0x14a4, 0x2242, 0x2c47
NMOD = (OFF_LST - OFF_IDX) // 2
NCHUNK = (OFF_TURBO - OFF_TAB) // 5
MUSIC_C_ORG = 0x470000


def build(FX3, dec, outdir, drop_modules=(), verifier=None, log=print):
    def fx3_chunk(i):
        p = MB + OFF_TAB + 5 * i
        return FX3[p] | (FX3[p + 1] << 8) | (FX3[p + 2] << 16), FX3[p + 3] | (FX3[p + 4] << 8)

    def fx3_unpack_chunk(a, sz):
        """FX3 _LoadChunkList: bit15 -> jsl $BF8539 (copy sz bytes, type-$10 unpack)."""
        f = fx3_mapper(a)
        n = sz & 0x7fff
        raw = FX3[f:f + n]
        if not sz & 0x8000:
            return raw
        # $BF8539 copies the chunk to $7F:B560 and enters the type $10 unpacker at $8637,
        # i.e. it is DeCompress type $10 without the type word.  Emulate exactly that.
        blob = b'\x10\x00' + raw
        r = bytearray(FX3); base = 0x3f0000
        r[base:base + len(blob)] = blob
        return run_decompress(bytes(r), fx3_mapper, FX3_DECOMPRESS, 0xc00000 + base, 0x7f7560)[0]

    os.makedirs(outdir, exist_ok=True)
    # ---- boot / driver / turbo : FX3's blob if in one of the engine's formats, else
    # unpacked (FX3 DeCompress emulated) and repacked
    for off, fn in ((OFF_BOOT, 'MUSIC_B.C'), (OFF_DRV, 'MUSIC_D.C'), (OFF_TURBO, 'MUSIC_O.C')):
        data, clen, t = dec.blob(MB + off)
        blob = FX3[MB + off:MB + off + clen] if t in (0, 4, 8, 12) else sc.compress(data)
        assert sc.decompress(blob)[0] == data
        if verifier and blob[0] != 0:          # (type 0: nothing to unpack)
            assert verifier.decompress(blob) == data, fn
        open(os.path.join(outdir, fn), 'wb').write(blob)
    # ---- chunk lists / index
    idx = list(struct.unpack_from('<%dH' % NMOD, FX3, MB + OFF_IDX))
    lst = FX3[MB + OFF_LST: MB + OFF_TAB]
    used_by = {}
    for m in range(NMOD):
        x = idx[m]
        while True:
            while True:
                x += 2; c = struct.unpack_from('<h', lst, x)[0]
                if c < 0: break
                used_by.setdefault(c, set()).add(m)
            x += 2
            if struct.unpack_from('<H', lst, x)[0] == 0: break
    drop = set(drop_modules)
    dead = {c for c, ms in used_by.items() if ms <= drop}
    for m in drop:
        idx[m] = idx[2]            # a stray load of a dropped module loads module 2 (intro)
    open(os.path.join(outdir, 'MUSIC_I'), 'wb').write(struct.pack('<%dH' % NMOD, *idx))
    open(os.path.join(outdir, 'MUSIC_L'), 'wb').write(lst)
    # ---- chunks
    cdata = bytearray(); table = bytearray()
    first_live = None; npacked = 0
    for i in range(NCHUNK):
        a, sz = fx3_chunk(i)
        if i in dead or i not in used_by:
            table += b'\0\0\0\0\0'          # patched below to a live chunk
            continue
        data = fx3_unpack_chunk(a, sz)
        assert len(data) <= 0x4000, 'chunk %d too big for _MDDeCompBuffer' % i
        stream = sc.rlc_encode_stream(data) if len(data) > 8 else None
        if stream is not None and len(stream) + 2 < len(data) and len(stream) <= 0x4000:
            assert sc.rlc_decode_stream(stream, len(data))[0] == data
            chunk = struct.pack('<H', len(data)) + stream
            entsz = 0x8000 | len(stream)
            npacked += 1
        else:
            chunk = bytes(data); entsz = len(data)
        addr = MUSIC_C_ORG + len(cdata)
        cdata += chunk
        table += bytes((addr & 0xff, (addr >> 8) & 0xff, addr >> 16, entsz & 0xff, entsz >> 8))
        if first_live is None: first_live = table[-5:]
        if verifier and entsz & 0x8000:
            assert verifier.unpackrl0(chunk, entsz & 0x7fff) == data, 'RLC mismatch chunk %d' % i
    for i in range(NCHUNK):
        if table[5 * i:5 * i + 5] == b'\0\0\0\0\0': table[5 * i:5 * i + 5] = first_live
    open(os.path.join(outdir, 'MUSIC_T'), 'wb').write(table)
    open(os.path.join(outdir, 'MUSIC_C'), 'wb').write(cdata)
    log('  music: %d modules, %d chunks (%d RLC packed), MUSIC_C %d bytes' % (NMOD, NCHUNK, npacked, len(cdata)))
    fix_turbo(FX3, outdir, log)


def fix_turbo(FX3, outdir, log=print):
    """the turbo table holds FX3 ROM addresses of the raw turbo sound data; the 65816
    streams it unpacked, relocated from $47:0000 (_DeCompressTurbo): store those chunks
    raw and point the table at them"""
    import rlmusic
    md = rlmusic.MusicData(outdir)
    fx3a = [FX3[MB + OFF_TAB + 5 * i] | (FX3[MB + OFF_TAB + 5 * i + 1] << 8) | (FX3[MB + OFF_TAB + 5 * i + 2] << 16)
            for i in range(NCHUNK)]
    tm = rlmusic.fx3_turbo_map(md, fx3a)
    n = md.save(turbo_map=tm)
    log('  turbo sounds: %d effects -> %d raw chunks, MUSIC_C %d bytes' % (len(tm), len(set(tm.values())), n))
