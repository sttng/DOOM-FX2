"""Small 65816 interpreter (native mode) used to run the FX3 ROM's real DeCompress
routines (datagen/fx3dec.py).

Not cycle accurate, no interrupts, no hardware registers (unmapped reads, e.g.
$2100-$43FF, return 0).
"""
import struct

class Mem:
    """Memory map.  mapper(addr24) -> ROM file offset | None; WRAM handled here,
    other writes go to self.extra."""
    def __init__(self, rom, mapper):
        self.rom = rom
        self.mapper = mapper
        self.wram = bytearray(0x20000)
        self.extra = {}            # other writable areas (e.g. GSU RAM $70-$71)
        self.rmin = None; self.rmax = None
        self.track = False         # track rmin/rmax: the ROM range read (minus excl)
        self.track_lo = 0
        self.excl = (0, 0)
        self.writes = None
    def reset_track(self):
        self.rmin = None; self.rmax = None
    def _wram(self, a):
        b = a >> 16; o = a & 0xffff
        if b in (0x7e, 0x7f): return ((b - 0x7e) << 16) | o
        if (b < 0x40 or 0x80 <= b < 0xc0) and o < 0x2000: return o
        return None
    def r8(self, a):
        a &= 0xffffff
        w = self._wram(a)
        if w is not None: return self.wram[w]
        m = self.mapper(a)
        if m is not None:
            if self.track and m >= self.track_lo and not (self.excl[0] <= m < self.excl[1]):
                if self.rmin is None or m < self.rmin: self.rmin = m
                if self.rmax is None or m > self.rmax: self.rmax = m
            return self.rom[m] if m < len(self.rom) else 0
        if a in self.extra: return self.extra[a]
        b = a >> 16
        if 0x70 <= b <= 0x71: return self.extra.get(a, 0)
        return 0
    def w8(self, a, v):
        a &= 0xffffff
        w = self._wram(a)
        if w is not None:
            self.wram[w] = v & 0xff
            if self.writes is not None: self.writes.add(w)
            return
        self.extra[a] = v & 0xff

class CPU:
    def __init__(self, mem):
        self.m = mem
        self.A = 0; self.X = 0; self.Y = 0; self.S = 0x1ff; self.D = 0
        self.DBR = 0; self.PBR = 0; self.PC = 0
        self.N = self.V = self.Z = self.C = 0
        self.Mf = 1; self.Xf = 1; self.Df = 0; self.If = 1
        self.steps = 0
    # --- helpers
    def P(self):
        return (self.N << 7) | (self.V << 6) | (self.Mf << 5) | (self.Xf << 4) | (self.Df << 3) | (self.If << 2) | (self.Z << 1) | self.C
    def setP(self, v):
        self.N = (v >> 7) & 1; self.V = (v >> 6) & 1; self.Mf = (v >> 5) & 1; self.Xf = (v >> 4) & 1
        self.Df = (v >> 3) & 1; self.If = (v >> 2) & 1; self.Z = (v >> 1) & 1; self.C = v & 1
        if self.Xf: self.X &= 0xff; self.Y &= 0xff
    def fetch8(self):
        t = self.m.track; self.m.track = False
        v = self.m.r8((self.PBR << 16) | self.PC); self.m.track = t; self.PC = (self.PC + 1) & 0xffff; return v
    def fetch16(self):
        lo = self.fetch8(); return lo | (self.fetch8() << 8)
    def fetch24(self):
        lo = self.fetch16(); return lo | (self.fetch8() << 16)
    def r16(self, a, bankwrap=False):
        if bankwrap: return self.m.r8(a) | (self.m.r8((a & 0xff0000) | ((a + 1) & 0xffff)) << 8)
        return self.m.r8(a) | (self.m.r8(a + 1) << 8)
    def push8(self, v):
        self.m.w8(self.S, v); self.S = (self.S - 1) & 0xffff
    def pull8(self):
        self.S = (self.S + 1) & 0xffff; return self.m.r8(self.S)
    def push16(self, v): self.push8(v >> 8); self.push8(v)
    def pull16(self):
        lo = self.pull8(); return lo | (self.pull8() << 8)
    def nz(self, v, w):
        if w: self.Z = int((v & 0xffff) == 0); self.N = (v >> 15) & 1
        else: self.Z = int((v & 0xff) == 0); self.N = (v >> 7) & 1
    # --- effective addresses
    def ea(self, mode):
        D = self.D; DB = self.DBR << 16
        if mode == 'dp': return (D + self.fetch8()) & 0xffff
        if mode == 'dpx': return (D + self.fetch8() + self.X) & 0xffff
        if mode == 'dpy': return (D + self.fetch8() + self.Y) & 0xffff
        if mode == 'dpi': p = (D + self.fetch8()) & 0xffff; return DB | self.r16(p)
        if mode == 'dpxi': p = (D + self.fetch8() + self.X) & 0xffff; return DB | self.r16(p)
        if mode == 'dpiy': p = (D + self.fetch8()) & 0xffff; return ((DB | self.r16(p)) + self.Y) & 0xffffff
        if mode == 'dpil':
            p = (D + self.fetch8()) & 0xffff; return self.r16(p) | (self.m.r8(p + 2) << 16)
        if mode == 'dpily':
            p = (D + self.fetch8()) & 0xffff; return ((self.r16(p) | (self.m.r8(p + 2) << 16)) + self.Y) & 0xffffff
        if mode == 'sr': return (self.S + self.fetch8()) & 0xffff
        if mode == 'sriy': p = (self.S + self.fetch8()) & 0xffff; return ((DB | self.r16(p)) + self.Y) & 0xffffff
        if mode == 'abs': return DB | self.fetch16()
        if mode == 'absx': return ((DB | self.fetch16()) + self.X) & 0xffffff
        if mode == 'absy': return ((DB | self.fetch16()) + self.Y) & 0xffffff
        if mode == 'long': return self.fetch24()
        if mode == 'longx': return (self.fetch24() + self.X) & 0xffffff
        raise Exception('mode ' + mode)
    def rd(self, a, w):
        return self.r16(a) if w else self.m.r8(a)
    def wr(self, a, v, w):
        self.m.w8(a, v)
        if w: self.m.w8(a + 1, v >> 8)
    def operand(self, mode, w):
        if mode in ('immm', 'immx'):
            return self.fetch16() if w else self.fetch8()
        return self.rd(self.ea(mode), w)

    def run(self, maxsteps=50_000_000, stop_on_rtl_depth=True):
        """Run until RTL/RTS returns to the sentinel return address (S back above start)."""
        from .dis65816 import OPS
        start_S = self.S
        while True:
            self.steps += 1
            if self.steps > maxsteps: raise Exception('too many steps')
            op = self.fetch8()
            mn, am = OPS[op]
            Mw = not self.Mf; Xw = not self.Xf
            if mn in ('lda', 'ora', 'and', 'eor', 'adc', 'sbc', 'cmp', 'bit'):
                if am == 'immm': v = self.fetch16() if Mw else self.fetch8()
                else: v = self.rd(self.ea(am), Mw)
                mask = 0xffff if Mw else 0xff
                A = self.A & mask
                if mn == 'lda': r = v; self.nz(r, Mw)
                elif mn == 'ora': r = A | v; self.nz(r, Mw)
                elif mn == 'and': r = A & v; self.nz(r, Mw)
                elif mn == 'eor': r = A ^ v; self.nz(r, Mw)
                elif mn == 'adc':
                    if self.Df: raise Exception('decimal')
                    s = A + v + self.C
                    sb = 15 if Mw else 7
                    self.V = int(((~(A ^ v)) & (A ^ s)) >> sb & 1)
                    self.C = int(s > mask); r = s & mask; self.nz(r, Mw)
                elif mn == 'sbc':
                    if self.Df: raise Exception('decimal')
                    vv = v ^ mask
                    s = A + vv + self.C
                    sb = 15 if Mw else 7
                    self.V = int(((~(A ^ vv)) & (A ^ s)) >> sb & 1)
                    self.C = int(s > mask); r = s & mask; self.nz(r, Mw)
                elif mn == 'cmp':
                    d = (A - v) & mask; self.C = int(A >= v); self.nz(d, Mw); continue
                elif mn == 'bit':
                    self.Z = int((A & v) == 0)
                    if am != 'immm':
                        sb = 15 if Mw else 7
                        self.N = (v >> sb) & 1; self.V = (v >> (sb - 1)) & 1
                    continue
                self.A = (self.A & 0xff00) | r if not Mw else r
                continue
            if mn in ('ldx', 'ldy', 'cpx', 'cpy'):
                v = self.operand(am, Xw)
                mask = 0xffff if Xw else 0xff
                if mn == 'ldx': self.X = v; self.nz(v, Xw)
                elif mn == 'ldy': self.Y = v; self.nz(v, Xw)
                else:
                    R = self.X if mn == 'cpx' else self.Y
                    self.C = int(R >= v); self.nz((R - v) & mask, Xw)
                continue
            if mn in ('sta', 'stx', 'sty', 'stz'):
                a = self.ea(am)
                if mn == 'sta': self.wr(a, self.A, Mw)
                elif mn == 'stz': self.wr(a, 0, Mw)
                elif mn == 'stx': self.wr(a, self.X, Xw)
                else: self.wr(a, self.Y, Xw)
                continue
            if mn in ('asl', 'lsr', 'rol', 'ror', 'inc', 'dec', 'tsb', 'trb'):
                mask = 0xffff if Mw else 0xff; sb = 15 if Mw else 7
                if am == 'acc':
                    v = self.A & mask; a = None
                else:
                    a = self.ea(am); v = self.rd(a, Mw)
                if mn == 'asl': self.C = (v >> sb) & 1; r = (v << 1) & mask; self.nz(r, Mw)
                elif mn == 'lsr': self.C = v & 1; r = v >> 1; self.nz(r, Mw)
                elif mn == 'rol': c = self.C; self.C = (v >> sb) & 1; r = ((v << 1) | c) & mask; self.nz(r, Mw)
                elif mn == 'ror': c = self.C; self.C = v & 1; r = (v >> 1) | (c << sb); self.nz(r, Mw)
                elif mn == 'inc': r = (v + 1) & mask; self.nz(r, Mw)
                elif mn == 'dec': r = (v - 1) & mask; self.nz(r, Mw)
                elif mn == 'tsb': self.Z = int((v & self.A & mask) == 0); r = v | (self.A & mask)
                elif mn == 'trb': self.Z = int((v & self.A & mask) == 0); r = v & ~(self.A & mask) & mask
                if a is None: self.A = (self.A & 0xff00) | r if not Mw else r
                else: self.wr(a, r, Mw)
                continue
            if am == 'rel' or am == 'rell':
                if am == 'rel':
                    d = self.fetch8(); d = d - 256 if d > 127 else d
                else:
                    d = self.fetch16(); d = d - 65536 if d > 32767 else d
                cond = {'bpl': not self.N, 'bmi': self.N, 'bvc': not self.V, 'bvs': self.V, 'bcc': not self.C,
                        'bcs': self.C, 'bne': not self.Z, 'beq': self.Z, 'bra': True, 'brl': True}.get(mn)
                if mn == 'per': self.push16((self.PC + d) & 0xffff); continue
                if cond: self.PC = (self.PC + d) & 0xffff
                continue
            if mn == 'jmp':
                if am == 'abs': self.PC = self.fetch16()
                elif am == 'absi': p = self.fetch16(); self.PC = self.r16(p)
                elif am == 'absxi': p = self.fetch16(); self.PC = self.r16((self.PBR << 16) | ((p + self.X) & 0xffff))
                elif am == 'long': t = self.fetch24(); self.PC = t & 0xffff; self.PBR = t >> 16
                continue
            if mn == 'jml':
                if am == 'long': t = self.fetch24()
                else: p = self.fetch16(); t = self.r16(p) | (self.m.r8(p + 2) << 16)
                self.PC = t & 0xffff; self.PBR = t >> 16; continue
            if mn == 'jsr':
                if am == 'abs': t = self.fetch16()
                else: p = self.fetch16(); t = self.r16((self.PBR << 16) | ((p + self.X) & 0xffff))
                self.push16((self.PC - 1) & 0xffff); self.PC = t; continue
            if mn == 'jsl':
                t = self.fetch24(); self.push8(self.PBR); self.push16((self.PC - 1) & 0xffff)
                self.PC = t & 0xffff; self.PBR = t >> 16; continue
            if mn == 'rts':
                self.PC = (self.pull16() + 1) & 0xffff
                if self.S >= start_S + 2 and stop_on_rtl_depth == 'rts': return
                continue
            if mn == 'rtl':
                self.PC = (self.pull16() + 1) & 0xffff; self.PBR = self.pull8()
                if self.S >= start_S + 3 and stop_on_rtl_depth: return
                continue
            if mn == 'rti': raise Exception('rti')
            if mn == 'rep': v = self.fetch8(); self.setP(self.P() & ~v); continue
            if mn == 'sep': v = self.fetch8(); self.setP(self.P() | v); continue
            if mn == 'xba':
                self.A = ((self.A >> 8) | (self.A << 8)) & 0xffff; self.nz(self.A & 0xff, False); continue
            simple = mn
            if simple == 'clc': self.C = 0
            elif simple == 'sec': self.C = 1
            elif simple == 'cli': self.If = 0
            elif simple == 'sei': self.If = 1
            elif simple == 'cld': self.Df = 0
            elif simple == 'sed': self.Df = 1
            elif simple == 'clv': self.V = 0
            elif simple == 'nop': pass
            elif simple == 'xce': pass
            elif simple in ('inx', 'dex', 'iny', 'dey'):
                mask = 0xffff if Xw else 0xff
                d = 1 if simple[0] == 'i' else -1
                if simple[2] == 'x': self.X = (self.X + d) & mask; self.nz(self.X, Xw)
                else: self.Y = (self.Y + d) & mask; self.nz(self.Y, Xw)
            elif simple in ('tax', 'tay'):
                v = self.A if Xw else self.A & 0xff
                if simple == 'tax': self.X = v
                else: self.Y = v
                self.nz(v, Xw)
            elif simple in ('txa', 'tya'):
                v = self.X if simple == 'txa' else self.Y
                if Mw: self.A = v
                else: self.A = (self.A & 0xff00) | (v & 0xff)
                self.nz(v, Mw)
            elif simple == 'txy': self.Y = self.X; self.nz(self.Y, Xw)
            elif simple == 'tyx': self.X = self.Y; self.nz(self.X, Xw)
            elif simple == 'tsx': self.X = self.S if Xw else self.S & 0xff; self.nz(self.X, Xw)
            elif simple == 'txs': self.S = self.X
            elif simple == 'tcs': self.S = self.A
            elif simple == 'tsc': self.A = self.S; self.nz(self.A, True)
            elif simple == 'tcd': self.D = self.A; self.nz(self.A, True)
            elif simple == 'tdc': self.A = self.D; self.nz(self.A, True)
            elif simple == 'pha':
                if Mw: self.push16(self.A)
                else: self.push8(self.A)
            elif simple == 'pla':
                if Mw: self.A = self.pull16(); self.nz(self.A, True)
                else: v = self.pull8(); self.A = (self.A & 0xff00) | v; self.nz(v, False)
            elif simple in ('phx', 'phy'):
                v = self.X if simple == 'phx' else self.Y
                if Xw: self.push16(v)
                else: self.push8(v)
            elif simple in ('plx', 'ply'):
                v = self.pull16() if Xw else self.pull8()
                if simple == 'plx': self.X = v
                else: self.Y = v
                self.nz(v, Xw)
            elif simple == 'phb': self.push8(self.DBR)
            elif simple == 'plb': self.DBR = self.pull8(); self.nz(self.DBR, False)
            elif simple == 'phk': self.push8(self.PBR)
            elif simple == 'phd': self.push16(self.D)
            elif simple == 'pld': self.D = self.pull16(); self.nz(self.D, True)
            elif simple == 'php': self.push8(self.P())
            elif simple == 'plp': self.setP(self.pull8())
            elif simple == 'pea': self.push16(self.fetch16())
            elif simple == 'pei': p = (self.D + self.fetch8()) & 0xffff; self.push16(self.r16(p))
            elif simple in ('mvn', 'mvp'):
                dst = self.fetch8(); src = self.fetch8()
                while True:
                    self.m.w8((dst << 16) | self.Y, self.m.r8((src << 16) | self.X))
                    d = 1 if simple == 'mvn' else -1
                    self.X = (self.X + d) & 0xffff; self.Y = (self.Y + d) & 0xffff
                    self.A = (self.A - 1) & 0xffff
                    if self.A == 0xffff: break
                self.DBR = dst
            else:
                raise Exception('unimpl %s %s at %02x:%04x' % (mn, am, self.PBR, (self.PC - 1) & 0xffff))

# FX3 (4 MB) map: $C0-$FF and $40-$7D linear (file = addr - $C00000 / - $400000),
# $00-$3F/$80-$BF:8000-FFFF LoROM over the first 2 MB
def fx3_mapper(a):
    b = a >> 16; o = a & 0xffff
    if b >= 0xc0: return a - 0xc00000
    if 0x40 <= b < 0x7e: return a - 0x400000
    if (b < 0x40 or 0x80 <= b < 0xc0) and o >= 0x8000: return (b & 0x3f) * 0x8000 + (o & 0x7fff)
    return None
