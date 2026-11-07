"""DeCompress blobs by running the real 65816 routines of the FX3 cartridge under
emulation (emu65816).

  * FX3 ("The Ultimate DOOM") packs most of its data with compressors the DOOM-FX
    engine does not have (DeCompress types $10/$14).  They are unpacked by
    running FX3's own DeCompress ($BF:8000) on the FX3 ROM image.
  * Verification of the blobs written for the engine (mkdata --verify) runs FX3's
    DeCompress too: it still has the engine's formats (types 0/4/8/12).

Results of FX3Decoder.blob() are memoised in memory and optionally in a cache
directory (pickles keyed by file offset + ROM checksum).
"""
import os, pickle, struct, zlib
from .emu65816 import Mem, CPU, fx3_mapper

FX3_DECOMPRESS = 0xBF8000       # FX3 DeCompress


def run_decompress(romdata, mapper, entry, src24, dst24=0x7f0000):
    """Call DeCompress(entry) with .X/.A = src, .Y/.B = dst.
    Returns (bytes, rom_min, rom_max, type, cpu)."""
    m = Mem(romdata, mapper)
    c = CPU(m)
    c.Mf = 0; c.Xf = 0; c.D = 0; c.S = 0x1ff0; c.DBR = 0
    c.A = ((dst24 >> 16) << 8) | (src24 >> 16)
    c.X = src24 & 0xffff; c.Y = dst24 & 0xffff
    c.PBR = entry >> 16; c.PC = entry & 0xffff
    c.push8(0); c.push16(0xfffe)
    m.track = True
    sf = mapper(src24)
    m.track_lo = sf if sf is not None else 0
    ef = mapper(entry)
    m.excl = (ef, ef + 0x1000) if ef is not None else (0, 0)
    c.run()
    m.track = False
    size = c.Y
    tp = m.r8(0x0a) | (m.r8(0x0b) << 8)    # Temp2+2 = format
    out = bytes(m.r8(((dst24 + i) & 0xffff) | (dst24 & 0xff0000)) for i in range(size))
    return out, m.rmin, m.rmax, tp, c


class FX3Decoder:
    def __init__(self, fx3rom, cache_dir=None):
        self.rom = fx3rom
        self.mem = {}
        self.cache_dir = cache_dir
        self.tag = '%08x' % zlib.crc32(fx3rom)
        if cache_dir:
            os.makedirs(cache_dir, exist_ok=True)

    def blob(self, fileoff):
        """-> (unpacked data, compressed length, type)"""
        if fileoff in self.mem:
            return self.mem[fileoff]
        p = None
        if self.cache_dir:
            p = os.path.join(self.cache_dir, '%s_%06x.pkl' % (self.tag, fileoff))
            if os.path.exists(p):
                res = pickle.load(open(p, 'rb'))
                self.mem[fileoff] = res
                return res
        out, lo, hi, tp, c = run_decompress(self.rom, fx3_mapper, FX3_DECOMPRESS, 0xc00000 + fileoff)
        res = (out, hi - fileoff + 1, tp)
        self.mem[fileoff] = res
        if p:
            pickle.dump(res, open(p, 'wb'))
        return res

    def decode_at(self, blob, dst24=0x7f0002):
        """unpack any blob with FX3's DeCompress (blob placed at $FF:0000)"""
        r = bytearray(self.rom); base = 0x3f0000
        r[base:base + len(blob)] = blob
        return run_decompress(bytes(r), fx3_mapper, FX3_DECOMPRESS, 0xc00000 + base, dst24)[0]


class FX3Verifier:
    """Unpack blobs written for the engine with the FX3 cartridge's own 65816 DeCompress
    (it has the engine's types 0/4/8/12 besides its $10/$14)."""
    def __init__(self, fx3rom):
        self.dec = FX3Decoder(fx3rom)

    def decompress(self, blob):
        return self.dec.decode_at(blob)

    def unpackrl0(self, chunk, nbytes):
        """a music chunk (word size + RLC stream of NBYTES): as the type 4 blob of that stream"""
        size = chunk[0] | chunk[1] << 8
        return self.dec.decode_at(struct.pack('<HHH', 4, size, nbytes + 2) + chunk[2:2 + nbytes])

