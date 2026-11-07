"""
disspc700.py -- SPC700 disassembler (the APU's CPU; music driver MUSIC_D.C)

  python3 tools/music/disspc700.py FILE ADDR [LEN] [--base BASE]

ADDR, LEN and BASE are hex.  FILE is loaded at BASE (default $0000; a 64 KB sound
RAM image needs none); prints LEN bytes (default $100) from ADDR.
"""
import sys

# mnemonic templates: d/d2 = direct page byte, !a = absolute word, #i = immediate,
# r = relative branch, m = mem.bit (13-bit address + 3-bit bit#), d.n = dp bit n
OPS = {}
def _t(op, s): OPS[op] = s
for b in range(8):
    _t(0x02 + 0x20 * b, 'set1 d.%d' % b); _t(0x12 + 0x20 * b, 'clr1 d.%d' % b)
    _t(0x03 + 0x20 * b, 'bbs d.%d,r' % b); _t(0x13 + 0x20 * b, 'bbc d.%d,r' % b)
for n in range(16):
    _t(0x01 + 0x10 * n, 'tcall %d' % n)
T = {
 0x00:'nop',0x04:'or a,d',0x05:'or a,!a',0x06:'or a,(x)',0x07:'or a,[d+x]',0x08:'or a,#i',0x09:'or d,d2',
 0x0A:'or1 c,m',0x0B:'asl d',0x0C:'asl !a',0x0D:'push psw',0x0E:'tset1 !a',0x0F:'brk',
 0x10:'bpl r',0x14:'or a,d+x',0x15:'or a,!a+x',0x16:'or a,!a+y',0x17:'or a,[d]+y',0x18:'or d,#i',0x19:'or (x),(y)',
 0x1A:'decw d',0x1B:'asl d+x',0x1C:'asl a',0x1D:'dec x',0x1E:'cmp x,!a',0x1F:'jmp [!a+x]',
 0x20:'clrp',0x24:'and a,d',0x25:'and a,!a',0x26:'and a,(x)',0x27:'and a,[d+x]',0x28:'and a,#i',0x29:'and d,d2',
 0x2A:'or1 c,/m',0x2B:'rol d',0x2C:'rol !a',0x2D:'push a',0x2E:'cbne d,r',0x2F:'bra r',
 0x30:'bmi r',0x34:'and a,d+x',0x35:'and a,!a+x',0x36:'and a,!a+y',0x37:'and a,[d]+y',0x38:'and d,#i',0x39:'and (x),(y)',
 0x3A:'incw d',0x3B:'rol d+x',0x3C:'rol a',0x3D:'inc x',0x3E:'cmp x,d',0x3F:'call !a',
 0x40:'setp',0x44:'eor a,d',0x45:'eor a,!a',0x46:'eor a,(x)',0x47:'eor a,[d+x]',0x48:'eor a,#i',0x49:'eor d,d2',
 0x4A:'and1 c,m',0x4B:'lsr d',0x4C:'lsr !a',0x4D:'push x',0x4E:'tclr1 !a',0x4F:'pcall i',
 0x50:'bvc r',0x54:'eor a,d+x',0x55:'eor a,!a+x',0x56:'eor a,!a+y',0x57:'eor a,[d]+y',0x58:'eor d,#i',0x59:'eor (x),(y)',
 0x5A:'cmpw ya,d',0x5B:'lsr d+x',0x5C:'lsr a',0x5D:'mov x,a',0x5E:'cmp y,!a',0x5F:'jmp !a',
 0x60:'clrc',0x64:'cmp a,d',0x65:'cmp a,!a',0x66:'cmp a,(x)',0x67:'cmp a,[d+x]',0x68:'cmp a,#i',0x69:'cmp d,d2',
 0x6A:'and1 c,/m',0x6B:'ror d',0x6C:'ror !a',0x6D:'push y',0x6E:'dbnz d,r',0x6F:'ret',
 0x70:'bvs r',0x74:'cmp a,d+x',0x75:'cmp a,!a+x',0x76:'cmp a,!a+y',0x77:'cmp a,[d]+y',0x78:'cmp d,#i',0x79:'cmp (x),(y)',
 0x7A:'addw ya,d',0x7B:'ror d+x',0x7C:'ror a',0x7D:'mov a,x',0x7E:'cmp y,d',0x7F:'reti',
 0x80:'setc',0x84:'adc a,d',0x85:'adc a,!a',0x86:'adc a,(x)',0x87:'adc a,[d+x]',0x88:'adc a,#i',0x89:'adc d,d2',
 0x8A:'eor1 c,m',0x8B:'dec d',0x8C:'dec !a',0x8D:'mov y,#i',0x8E:'pop psw',0x8F:'mov d,#i',
 0x90:'bcc r',0x94:'adc a,d+x',0x95:'adc a,!a+x',0x96:'adc a,!a+y',0x97:'adc a,[d]+y',0x98:'adc d,#i',0x99:'adc (x),(y)',
 0x9A:'subw ya,d',0x9B:'dec d+x',0x9C:'dec a',0x9D:'mov x,sp',0x9E:'div ya,x',0x9F:'xcn a',
 0xA0:'ei',0xA4:'sbc a,d',0xA5:'sbc a,!a',0xA6:'sbc a,(x)',0xA7:'sbc a,[d+x]',0xA8:'sbc a,#i',0xA9:'sbc d,d2',
 0xAA:'mov1 c,m',0xAB:'inc d',0xAC:'inc !a',0xAD:'cmp y,#i',0xAE:'pop a',0xAF:'mov (x)+,a',
 0xB0:'bcs r',0xB4:'sbc a,d+x',0xB5:'sbc a,!a+x',0xB6:'sbc a,!a+y',0xB7:'sbc a,[d]+y',0xB8:'sbc d,#i',0xB9:'sbc (x),(y)',
 0xBA:'movw ya,d',0xBB:'inc d+x',0xBC:'inc a',0xBD:'mov sp,x',0xBE:'das a',0xBF:'mov a,(x)+',
 0xC0:'di',0xC4:'mov d,a',0xC5:'mov !a,a',0xC6:'mov (x),a',0xC7:'mov [d+x],a',0xC8:'cmp x,#i',0xC9:'mov !a,x',
 0xCA:'mov1 m,c',0xCB:'mov d,y',0xCC:'mov !a,y',0xCD:'mov x,#i',0xCE:'pop x',0xCF:'mul ya',
 0xD0:'bne r',0xD4:'mov d+x,a',0xD5:'mov !a+x,a',0xD6:'mov !a+y,a',0xD7:'mov [d]+y,a',0xD8:'mov d,x',0xD9:'mov d+y,x',
 0xDA:'movw d,ya',0xDB:'mov d+x,y',0xDC:'dec y',0xDD:'mov a,y',0xDE:'cbne d+x,r',0xDF:'daa a',
 0xE0:'clrv',0xE4:'mov a,d',0xE5:'mov a,!a',0xE6:'mov a,(x)',0xE7:'mov a,[d+x]',0xE8:'mov a,#i',0xE9:'mov x,!a',
 0xEA:'not1 m',0xEB:'mov y,d',0xEC:'mov y,!a',0xED:'notc',0xEE:'pop y',0xEF:'sleep',
 0xF0:'beq r',0xF4:'mov a,d+x',0xF5:'mov a,!a+x',0xF6:'mov a,!a+y',0xF7:'mov a,[d]+y',0xF8:'mov x,d',0xF9:'mov x,d+y',
 0xFA:'mov d2,d',0xFB:'mov y,d+x',0xFC:'inc y',0xFD:'mov y,a',0xFE:'dbnz y,r',0xFF:'stop',
}
OPS.update(T)

IO = {0xF0: 'TEST', 0xF1: 'CONTROL', 0xF2: 'DSPADDR', 0xF3: 'DSPDATA', 0xF4: 'CPUIO0', 0xF5: 'CPUIO1',
      0xF6: 'CPUIO2', 0xF7: 'CPUIO3', 0xFA: 'T0TARGET', 0xFB: 'T1TARGET', 0xFC: 'T2TARGET',
      0xFD: 'T0OUT', 0xFE: 'T1OUT', 0xFF: 'T2OUT'}


def length(op):
    s = OPS[op]
    n = 1
    toks = s
    for c in ',[]()+/':
        toks = toks.replace(c, ' ')
    toks = toks.split()[1:]
    for t in toks:
        t = t.split('.')[0]
        if t in ('d', 'd2', 'i', '#i', 'r'): n += 1
        elif t in ('!a', 'm'): n += 2
    if op in (0x4F,):                    # pcall u
        n = 2
    return n


def dis(mem, pc, base=0):
    """(length, text) of the instruction at PC (MEM indexed from BASE)"""
    op = mem[pc - base]
    s = OPS[op]
    n = length(op)
    b = list(mem[pc - base + 1:pc - base + n])
    # operand order: "op d,d2" (dst,src) is encoded op src dst; "op d,#i" as op ii dd;
    # bbs/bbc/cbne/dbnz d,r as op dd rr
    def dp(v): return IO.get(v, '$%02X' % v)
    out = s
    if '#i' in s and ' d' in s and op in (0x18, 0x38, 0x58, 0x78, 0x98, 0xB8, 0x8F):
        out = out.replace('#i', '#$%02X' % b[0]).replace(' d', ' ' + dp(b[1]), 1)
    elif 'd,d2' in s:                    # op src dst: "op dst,src"
        out = out.replace('d,d2', dp(b[1]) + ',' + dp(b[0]))
    elif op == 0xFA:                     # mov dst,src: FA src dst
        out = 'mov %s,%s' % (dp(b[1]), dp(b[0]))
    else:
        k = 0
        res = ''; i = 0
        while i < len(s):
            if s.startswith('!a', i):
                v = b[k] | b[k + 1] << 8; k += 2; res += '$%04X' % v; i += 2
            elif s.startswith('#i', i):
                res += '#$%02X' % b[k]; k += 1; i += 2
            elif s[i] == 'm' and (i == 0 or not s[i - 1].isalpha()) and (i + 1 == len(s) or not s[i + 1].isalpha()):
                v = b[k] | b[k + 1] << 8; k += 2; res += '$%04X.%d' % (v & 0x1FFF, v >> 13); i += 1
            elif s[i] == 'r' and (i + 1 == len(s)) and s[i - 1] in ', ':
                rel = b[k] - 256 if b[k] > 127 else b[k]; k += 1; res += '$%04X' % ((pc + n + rel) & 0xFFFF); i += 1
            elif s[i] == 'd' and (i == 0 or not s[i - 1].isalpha()) and (i + 1 == len(s) or not s[i + 1].isalpha()) and s[:i].strip():
                res += dp(b[k]); k += 1; i += 1
            elif s[i] == 'i' and s.startswith('pcall', 0) and i == len(s) - 1:
                res += '$FF%02X' % b[k]; k += 1; i += 1
            else:
                res += s[i]; i += 1
        out = res
    return n, out


def listing(mem, start, n, base=0):
    pc = start; out = []
    while pc < start + n:
        k, t = dis(mem, pc, base)
        out.append('%04X  %-9s %s' % (pc, ' '.join('%02X' % x for x in mem[pc - base:pc - base + k]), t))
        pc += k
    return out


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('file'); ap.add_argument('addr'); ap.add_argument('len', nargs='?', default='100')
    ap.add_argument('--base', default='0')
    a = ap.parse_args()
    mem = open(a.file, 'rb').read()
    print('\n'.join(listing(mem, int(a.addr, 16), int(a.len, 16), int(a.base, 16))))
