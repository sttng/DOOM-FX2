"""
fx3_art.py -- write RLDATA (COMP/ART/CUT/MUSIC) with the FX3 ("The Ultimate Doom")
content in the formats the engine's incbins expect.

Policy per file (everything from the FX3 cartridge)
  * FX3 blob type 0/4/8/12 (the engine's DeCompress formats) -> FX3 blob verbatim
  * FX3-only compressor ($10 LZ/Huffman @ $BF:8637, $14 @ $BF:8927)
                                            -> unpacked (65816 emulation of FX3 DeCompress)
                                               and repacked with snescomp (RLC / ECLIPSE-1)
  * FX3 8bpp Mode-3 pictures (title, E1-E3 maps) -> requantised to the engine's 4bpp
    Mode-1 layout (tilequant, deterministic seed)
With a verifier, every packed blob written is decoded again with the FX3 cartridge's 65816
DeCompress under emulation (fx3dec.FX3Verifier).
"""
import os, struct
import numpy as np
import snescomp as sc
from .snesgfx import bgr555_to_rgb, rgb_to_bgr555, encode_tile, render_map
from .tilequant import quantize, dedupe
from . import fx3_music

WEAPONS = ['Fist', 'Pistol', 'ShotGun', 'ChainSaw', 'ChainGun', 'Rocket', 'Plasma', 'BFG']


def ff(a): return a - 0xc00000 if a >= 0xc00000 else a - 0x400000
def words(b): return list(struct.unpack('<%dH' % (len(b) // 2), b))
def pw(w): return struct.pack('<%dH' % len(w), *w)


class FX3Art:
    def __init__(self, fx3, dec, out, verifier=None, log=print):
        self.F = fx3; self.dec = dec; self.ver = verifier; self.log = log
        self.data = os.path.join(out, 'RLDATA')

    def blob(self, a):
        return self.dec.blob(ff(a))

    def verify(self, blob, data):
        if self.ver and blob[0] != 0:
            assert self.ver.decompress(blob) == data

    def write(self, rel, data):
        p = os.path.join(self.data, rel); os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, 'wb').write(data)

    def comp_item(self, rel, fx3a, transform=None):
        F = self.F
        fd, fl, ft = self.blob(fx3a)
        data = transform(fd) if transform else fd
        if transform is None and ft in (0, 4, 8, 12):
            blob = F[ff(fx3a):ff(fx3a) + fl]
            d2, l2, _ = sc.decompress(blob); blob = blob[:l2]; assert d2 == fd
        else:
            blob = sc.compress(data)
        self.verify(blob, data)
        self.write(rel, blob)
        return data

    def raw_item(self, rel, fx3a, n, pre=b''):
        d = self.F[ff(fx3a):ff(fx3a) + n]
        self.write(rel, pre + d)
        return d

    def comp_new(self, rel, data):
        blob = sc.compress(data)
        self.verify(blob, data)
        self.write(rel, blob)

    # -----------------------------------------------------------------------
    def status(self):
        for rel, a in (('COMP/Status.def0', 0xFFB22E), ('COMP/StatNum.def0', 0xFFE52E),
                       ('COMP/StatFaces.def0', 0xF5E17E), ('COMP/StatKeys.def0', 0xEAFF45),
                       ('COMP/StatArms.def0', 0xE1FB03)):
            self.comp_item(rel, a)

    def fonts(self):
        self.comp_item('COMP/TextFont.def0', 0xD9FB43)
        # GSU 8x8 byte font chars 33-90 (FX3: iwt r10,#$E1EE / ibt r0,#$52); 64 zero bytes for char 32
        self.raw_item('ART/rlfont.def0', 0x52EA2E, 58 * 64, pre=bytes(64))

    def menus(self):
        self.comp_item('COMP/MenuSkulls.def0', 0xFFC602)
        # main menu: with a 'Rumble: On/Off' line (rows 8-10, On/Off glyph rows
        # moved to 11-12); menus.py build takes its letters (and "Rumble:") for the pause menu
        for n, ma, da in (('MainMenu', 0xFAF697, 0xFAF714), ('SkillMenu', 0xFCB4D7, 0xFCB542),
                          ('EpisodeMenu', 0xFCE158, 0xFCE1CA)):
            self.comp_item('COMP/%s.map0' % n, ma)
            self.comp_item('COMP/%s.def0' % n, da)

    def score(self):
        self.comp_item('COMP/Score.def0', 0xFFC79A)
        self.comp_item('COMP/Score.map0', 0xFFCD35)
        self.raw_item('ART/Score.rgb', 0xFFCDF2, 16)
        self.raw_item('ART/ScoreNum.rgb', 0xFFCFB8, 16)
        self.comp_item('COMP/ScoreNum.def0', 0xFFCE02)
        self.comp_item('COMP/ScoreSplat.def0', 0xFFCFC8)
        self.comp_item('COMP/ScoreHere.def0', 0xFFD084)

    def quant_screen(self, ca, ma, pa, praw, npal):
        cd = self.blob(ca)[0]; md = self.blob(ma)[0]
        pd = self.F[ff(pa):ff(pa) + praw] + bytes(512 - praw) if praw else self.blob(pa)[0]
        pal = bgr555_to_rgb(pd)
        src = render_map(cd, md, pal, 8)
        tiles, tp, pals, err = quantize(np.array(src)[:224], npal, backdrop=pal[0])
        u, e = dedupe(tiles, tp)
        flat = [tuple(int(v) for v in c) for p in pals for c in p]
        chars = b''.join(encode_tile(t, 4) for t in u)
        return chars, pw(e), rgb_to_bgr555(flat)

    def score_maps(self):
        # FX3 8bpp/96-colour Mode-3 pictures requantised to 4bpp Mode-1, 6 palettes
        eps = {1: (0xEC0000, 0xE5FF7C, 0xD4FF3C), 2: (0xEB0000, 0xF8FF82, 0xDAFF40), 3: (0xED0000, 0xFFED4C, 0xFFE902)}
        for e, (c, m, p) in eps.items():
            chars, mapb, rgb = self.quant_screen(c, m, p, 0xC0, 6)
            self.comp_new('COMP/ScoreE%d.def.0' % e, chars[:0x4000])
            self.comp_new('COMP/ScoreE%d.def.1' % e, chars[0x4000:] or bytes(32))
            self.comp_new('COMP/ScoreE%d.map0' % e, mapb)
            self.write('ART/ScoreE%d.rgb' % e, rgb)
        # E4 (FX3-only): 4bpp Mode 1, 96 colours -- the engine's format natively; split at 512 tiles
        d = self.blob(0xF57F1E)[0]; mp = self.blob(0xFFEC41)[0]
        self.comp_new('COMP/ScoreE4.def.0', d[:0x4000])
        self.comp_new('COMP/ScoreE4.def.1', d[0x4000:])
        self.comp_new('COMP/ScoreE4.map0', mp)
        self.write('ART/ScoreE4.rgb', self.F[ff(0xFFE9C2):ff(0xFFE9C2) + 0xC0])

    def title(self):
        # FX3 default title picture (8bpp) requantised to 4bpp, 7 palettes;
        # palette 7 = SystemText colours (7=$0007, 11=$001F: the original legal page's)
        chars, mapb, rgb = self.quant_screen(0xF48484, 0xFCFED8, 0xEDFD19, 0, 7)
        full = bytearray(512); full[:len(rgb)] = rgb
        full[(7 * 16 + 7) * 2:(7 * 16 + 8) * 2] = struct.pack('<H', 0x0007)
        full[(7 * 16 + 11) * 2:(7 * 16 + 12) * 2] = struct.pack('<H', 0x001F)
        self.comp_new('COMP/title.def.0', chars[:0x4000])
        self.comp_new('COMP/title.def.1', chars[0x4000:] or bytes(32))
        self.comp_new('COMP/title.map0', mapb)
        self.comp_new('COMP/title.rgb', bytes(full))

    def logo2(self):
        # FX3 Logo2 page = R&R Digital logo
        self.comp_item('COMP/Logo2.def0', 0xC9F680)
        self.comp_item('COMP/Logo2.map0', 0xEBFE2C)
        self.comp_item('COMP/Logo2.rgb', 0xC9FFB5)

    def cut(self):
        F = self.F
        T = 0x2AD27B; t = [struct.unpack_from('<8H', F, T + 16 * k) for k in range(9)]
        for w, name in enumerate(WEAPONS):
            for fn, bk, ai, si in (('.imagetbl', 0, 1, 2), ('.miscdata', 0, 5, 6), ('.chardata', 0, 3, 4), ('.chardef', 1, 7, 8)):
                fa = (((t[0][w] >> (8 * bk)) & 0xff) << 16) | t[ai][w]
                self.raw_item('CUT/%s/%s' % (name, fn), fa, t[si][w])

    def music(self):
        fx3_music.build(self.F, self.dec, os.path.join(self.data, 'MUSIC'), (), self.ver, log=self.log)

    def run(self):
        for p in ('status', 'fonts', 'menus', 'score', 'score_maps', 'title', 'logo2', 'cut', 'music'):
            getattr(self, p)()


def build(fx3, dec, out, verifier=None, log=print):
    FX3Art(fx3, dec, out, verifier, log).run()
