"""wad.py -- minimal WAD reader, the one all tools use.  directory(d): the lumps of WAD
bytes d as (name, offset, size), names up to the first NUL in upper case (wad2rl.py
Wad, wad2soundfx.py, rlsong.py, mus.py).  WAD(fn) (wad2gfx.py, fx3_gfx.py, wad2cut.py,
menus.py): find/get by name (first match), level(name) = the 10 lumps after the map
marker."""
import struct


def directory(d):
    magic, n, o = struct.unpack('<4sii', d[:12])
    if magic not in (b'IWAD', b'PWAD'):
        raise ValueError('not a WAD')
    out = []
    for i in range(n):
        p, s, name = struct.unpack('<ii8s', d[o + 16 * i:o + 16 * i + 16])
        out.append((name.split(b'\0')[0].decode('latin1').upper(), p, s))
    return out


class WAD:
    def __init__(self, fn):
        self.d = open(fn, 'rb').read()
        self.lumps = directory(self.d)

    def find(self, name, start=0):
        for i in range(start, len(self.lumps)):
            if self.lumps[i][0] == name:
                return i
        return -1

    def data(self, i):
        n, p, s = self.lumps[i]
        return self.d[p:p + s]

    def get(self, name):
        i = self.find(name)
        return self.data(i) if i >= 0 else None

    def level(self, name):
        i = self.find(name)
        return {self.lumps[j][0]: self.data(j) for j in range(i + 1, i + 11)}
