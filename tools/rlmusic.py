"""
rlmusic.py - read and write the music/sound data set (data/RLDATA/MUSIC)

  MUSIC_I     word per module  module -> offset into MUSIC_L
  MUSIC_L     chunk lists     { word APU dest, word chunk#..., word -1 } ..., word 0
  MUSIC_T     5 bytes/chunk   address (24 bit, chunks at $47:0000), size (bit 15: RLC packed:
                              word unpacked size + RLC stream of the low 15 bits' length)
  MUSIC_C     chunk data
  MUSIC_O.C   DeCompress blob: turbo table, 6 bytes per effect (rlsound.inc rlsett*):
              BWave#, data address (24 bit, chunks at $47:0000), #bytes
  MUSIC_B.C, MUSIC_D.C  APU boot code and SPC700 driver (read only)

Turbo ("blast") sound effects are streamed by the 65816 (rlsound.asm
_RLIRQUpdateTSounds) from the address in the turbo table into one of 4 slots
of the APU blast buffer: the data must be a raw (unpacked) copy in MUSIC_C.

The addresses are built for MUSIC_C at $47:0000 (MUSICDAT.A's ORG in the source);
musicdat.asm relocates them to wherever layout.py puts MUSIC_C.
"""
import os, struct
import snescomp as sc

ORG = 0x470000


class MusicData:
    def __init__(self, d):
        self.dir = d
        rd = lambda f: open(os.path.join(d, f), 'rb').read()
        self.I = rd('MUSIC_I'); self.L = rd('MUSIC_L')
        T = rd('MUSIC_T'); C = rd('MUSIC_C')
        self.chunks = []
        for i in range(len(T) // 5):
            a = T[5 * i] | T[5 * i + 1] << 8 | T[5 * i + 2] << 16
            s = T[5 * i + 3] | T[5 * i + 4] << 8
            self.chunks.append((a, s))
        self._C = C
        self.data = {}
        for i, (a, s) in enumerate(self.chunks):
            if a not in self.data:
                self.data[a] = self._unpack(a, s)
        t = sc.decompress(rd('MUSIC_O.C'))[0]
        self.turbo = [list(struct.unpack_from('<BBBBH', t, 6 * i)) for i in range(len(t) // 6)]
        for e in self.turbo:
            e[1:4] = [e[1] | e[2] << 8 | e[3] << 16]
        self.boot = rd('MUSIC_B.C'); self.driver = rd('MUSIC_D.C')
        self._turbo0 = self.turbo_chunks()

    def _unpack(self, a, s):
        o = a - ORG
        if s & 0x8000:
            n = struct.unpack_from('<H', self._C, o)[0]
            return sc.rlc_decode_stream(self._C[o + 2:o + 2 + (s & 0x7fff)], n)[0]
        return self._C[o:o + s]

    def chunk(self, i):
        return self.data[self.chunks[i][0]]

    def modules(self):
        return len(self.I) // 2

    def module(self, m):
        """[(APU dest, [chunk#...]), ...]"""
        x = struct.unpack_from('<H', self.I, 2 * m)[0]; groups = []
        dest = struct.unpack_from('<H', self.L, x)[0]
        while True:
            ch = []
            while True:
                x += 2; c = struct.unpack_from('<h', self.L, x)[0]
                if c < 0:
                    break
                ch.append(c)
            groups.append((dest, ch)); x += 2; dest = struct.unpack_from('<H', self.L, x)[0]
            if dest == 0:
                break
        return groups

    def aram(self, *mods):
        a = bytearray(0x10000)
        for m in mods:
            for d, ch in self.module(m):
                b = b''.join(self.chunk(c) for c in ch)
                a[d:d + len(b)] = b
        return a

    def turbo_chunks(self):
        """effect# -> chunk# of the data the turbo table entry streams"""
        by_addr = {a: i for i, (a, s) in enumerate(self.chunks)}
        out = {}
        for e, (bw, addr, n) in enumerate(self.turbo):
            if addr and addr in by_addr:
                out[e] = by_addr[addr]
        return out

    def new_chunk(self, data):
        """a new chunk holding DATA (placed in MUSIC_C by save()); returns its number"""
        key = 0x1000000 + len(self.chunks)
        self.chunks.append((key, 0)); self.data[key] = bytes(data)
        return len(self.chunks) - 1

    def set_modules(self, lists):
        """replace every module's chunk lists: LISTS[m] = [(APU dest, [chunk#...]), ...]"""
        L = bytearray(); I = []
        for groups in lists:
            I.append(len(L))
            for dest, ch in groups:
                L += struct.pack('<H', dest) + b''.join(struct.pack('<h', c) for c in ch) + struct.pack('<h', -1)
            L += struct.pack('<H', 0)
        self.I = struct.pack('<%dH' % len(I), *I); self.L = bytes(L)

    def save(self, d=None, raw=(), turbo_map=None):
        """write MUSIC_I / MUSIC_L / MUSIC_T / MUSIC_C / MUSIC_O.C. RAW: chunk numbers
        stored unpacked.  TURBO_MAP: effect# -> chunk# whose (raw) data the turbo table
        points at (default: as loaded).  Chunks no module or turbo sound uses are left
        out of MUSIC_C (their table entries point at the lowest-numbered chunk in use)."""
        d = d or self.dir
        if turbo_map is None:
            turbo_map = self._turbo0
        raw = set(raw) | set((turbo_map or {}).values())
        live = set((turbo_map or {}).values())
        for m in range(self.modules()):
            for dest, ch in self.module(m):
                live.update(ch)
        cdata = bytearray(); table = bytearray(); placed = {}
        for i, (a, s) in enumerate(self.chunks):
            if i not in live:
                i, (a, s) = min(live), self.chunks[min(live)]
            key = (a, i in raw)
            if key in placed:
                table += placed[key]; continue
            data = self.data[a]
            stream = sc.rlc_encode_stream(data) if len(data) > 8 and i not in raw else None
            if stream is not None and len(stream) + 2 < len(data) and len(stream) <= 0x4000:
                assert sc.rlc_decode_stream(stream, len(data))[0] == data
                blob = struct.pack('<H', len(data)) + stream; sz = 0x8000 | len(stream)
            else:
                blob = bytes(data); sz = len(data)
            addr = ORG + len(cdata); cdata += blob
            ent = bytes((addr & 0xff, (addr >> 8) & 0xff, addr >> 16, sz & 0xff, sz >> 8))
            placed[key] = ent; table += ent
        turbo = bytearray()
        for e, (bw, addr, n) in enumerate(self.turbo):
            if turbo_map and e in turbo_map:
                c = turbo_map[e]
                ent = table[5 * c:5 * c + 5]
                addr = ent[0] | ent[1] << 8 | ent[2] << 16
                n = len(self.chunk(c))
                assert not ent[4] & 0x80
            turbo += struct.pack('<BBBBH', bw, addr & 0xff, (addr >> 8) & 0xff, addr >> 16, n)
        open(os.path.join(d, 'MUSIC_I'), 'wb').write(self.I)
        open(os.path.join(d, 'MUSIC_L'), 'wb').write(self.L)
        open(os.path.join(d, 'MUSIC_T'), 'wb').write(table)
        open(os.path.join(d, 'MUSIC_C'), 'wb').write(cdata)
        open(os.path.join(d, 'MUSIC_O.C'), 'wb').write(sc.compress(bytes(turbo)))
        assert sc.decompress(open(os.path.join(d, 'MUSIC_O.C'), 'rb').read())[0] == bytes(turbo)
        return len(cdata)


def fx3_turbo_map(md, fx3_chunk_addr):
    """effect# -> chunk#, for a turbo table that holds FX3 ROM addresses: the chunk
    whose FX3 chunk-table address is that address (FX3 stores turbo chunks raw)"""
    by = {a: i for i, a in enumerate(fx3_chunk_addr)}
    return {e: by[addr] for e, (bw, addr, n) in enumerate(md.turbo) if addr and addr in by}
