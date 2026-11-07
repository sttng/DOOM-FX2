#!/usr/bin/env python3
"""
romcheck.py - finalise and sanity-check the assembled ROM image (in place):
  * pad with $FF to the next power of two (2 or 4 MB) and write that size
    into the header
  * check that the header cartridge type is a Super FX one
  * recompute the SNES checksum/complement
usage: romcheck.py build/doom.sfc
"""
import sys

def main():
    fn = sys.argv[1]
    rom = bytearray(open(fn, 'rb').read())
    hdr = 0x7FC0
    # ROM size: smallest power of two holding the image (at least 2 MB); anything
    # beyond 2 MB is the CPU-only ROM at $E0-$FF (README "Cartridge and memory map")
    want = 0x200000
    while want < len(rom): want <<= 1
    if want > 0x400000:
        raise SystemExit('%d bytes: more than 4 MB (the Super FX map ends there)' % len(rom))
    size_code = want.bit_length() - 11
    rom[hdr + 0x17] = size_code
    rom += b'\xFF' * (want - len(rom))
    maptype = rom[hdr + 0x15]; carttype = rom[hdr + 0x16]
    if carttype not in (0x13, 0x14, 0x15, 0x1A):
        raise SystemExit('header cartridge type $%02X is not a Super FX cart' % carttype)
    rom[hdr + 0x1C:hdr + 0x20] = b'\xFF\xFF\x00\x00'
    s = sum(rom) & 0xFFFF
    rom[hdr + 0x1C] = (s ^ 0xFFFF) & 0xFF; rom[hdr + 0x1D] = (s ^ 0xFFFF) >> 8
    rom[hdr + 0x1E] = s & 0xFF; rom[hdr + 0x1F] = s >> 8
    open(fn, 'wb').write(rom)
    title = bytes(rom[hdr:hdr + 21]).decode('latin1').rstrip()
    print('%s: "%s", %d KB, map $%02X, type $%02X, GSU RAM %d KB, checksum $%04X' % (
        fn, title, len(rom) // 1024, maptype, carttype, (1 << rom[0x7FBD]) if 0 < rom[0x7FBD] < 8 else 0, s))

if __name__ == '__main__':
    main()
