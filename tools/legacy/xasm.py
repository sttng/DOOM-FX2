#!/usr/bin/env python3
"""
xasm.py - reference re-implementation of the Sculptured Software "xa"/"xl"
65816 + Super FX (GSU) assembler/linker dialect used by the DOOM-FX
(Reality Engine) sources.

It reproduces the original build exactly (section layout from RL.SEC,
addressing-mode selection from dbr/dpr/mode, GSU pseudo-ops), so the sources
can be checked byte for byte; xa2asar.py uses it to translate them to asar.

usage: xasm.py SRCDIR DATADIR OUT.sfc [--sec FILE] [--placeholders JSON]
               [--pin] [--romsize N] [--report FILE] [-v]
  SRCDIR          the release's source/ directory (smakefile, RL.SEC, *.a)
  DATADIR         holds the VOLUME:file includes and images (RLDATA/, RLMUS/, ...)
  --sec           section map (default SRCDIR/RL.SEC)
  --placeholders  JSON {image name: [bytes]} used for missing images
  --pin           keep the sections at the addresses of SRCDIR/RL.BNK
  --romsize       ROM size in bytes (default 2 MB)
  --report        errors, warnings, symbols and section sizes to FILE, plus
                  OUT.sfc.lst.pkl, OUT.sfc.defs.pkl and OUT.sfc.sym.json
  -v              progress per pass on stderr
environment:
  XASM_TRACK_SEPREP=1  let literal rep/sep change the immediate sizes (xa does not)
  XASM_OLD_ABS=1       bank-0 operands with a non-zero dbr use abs, not long
"""
import os, re, sys, json, collections

# ---------------------------------------------------------------- utilities
class AsmError(Exception):
    pass

class Reg:
    __slots__ = ('n',)
    def __init__(self, n): self.n = n
    def __repr__(self): return 'r%d' % self.n
    def __eq__(self, o): return isinstance(o, Reg) and o.n == self.n
    def __hash__(self): return hash(('reg', self.n))

def strip_comment(s):
    out = []; q = None
    for ch in s:
        if q:
            out.append(ch)
            if ch == q: q = None
        else:
            if ch == ';': break
            if ch in '"\'': q = ch
            out.append(ch)
    return ''.join(out)

def split_args(s):
    """split on commas at top level (parens/brackets/quotes)"""
    parts = []; depth = 0; cur = []; q = None
    for ch in s:
        if q:
            cur.append(ch)
            if ch == q: q = None
            continue
        if ch in '"\'':
            q = ch; cur.append(ch); continue
        if ch in '([': depth += 1
        elif ch in ')]': depth -= 1
        if ch == ',' and depth <= 0:
            parts.append(''.join(cur).strip()); cur = []
        else:
            cur.append(ch)
    parts.append(''.join(cur).strip())
    if parts == ['']: return []
    return parts

# ---------------------------------------------------------------- expressions
TOK = re.compile(r"""\s*(?:
  (?P<hex>\$[0-9A-Fa-f]+) |
  (?P<bin>%[01]+) |
  (?P<dec>\d+) |
  (?P<chr>'(?:[^']|'')*') |
  (?P<id>[A-Za-z_.@][A-Za-z0-9_.@]*:?) |
  (?P<op><<|>>|[-+*/&|^~<>!()%=])
)""", re.X)

class Undef(Exception):
    pass

class ExprParser:
    def __init__(self, text, lookup, pc, loadpc=0):
        self.loadpc = loadpc
        self.toks = []
        pos = 0; text = text.strip()
        while pos < len(text):
            m = TOK.match(text, pos)
            if not m or m.end() == pos:
                if text[pos:].strip() == '': break
                raise AsmError('bad expression %r at %r' % (text, text[pos:]))
            pos = m.end()
            k = m.lastgroup; v = m.group(k)
            self.toks.append((k, v))
        self.i = 0; self.lookup = lookup; self.pc = pc; self.text = text
    def peek(self):
        return self.toks[self.i] if self.i < len(self.toks) else (None, None)
    def take(self):
        t = self.peek(); self.i += 1; return t
    def parse(self):
        v = self.p_or()
        # tolerate stray closing parens
        while self.peek()[1] == ')': self.take()
        if self.i != len(self.toks):
            raise AsmError('trailing junk in expression %r' % self.text)
        return v
    # precedence (C-like, low to high): | ! (both or), &, << >>, + -, * / %
    def p_or(self):
        v = self.p_and()
        while self.peek()[1] in ('|', '!'):
            self.take(); r = self.p_and(); v = self.bin(v, r, lambda a, b: a | b)
        return v
    def p_and(self):
        v = self.p_shift()
        while self.peek()[1] == '&':
            self.take(); r = self.p_shift(); v = self.bin(v, r, lambda a, b: a & b)
        return v
    def p_shift(self):
        v = self.p_add()
        while self.peek()[1] in ('<<', '>>'):
            op = self.take()[1]; r = self.p_add()
            v = self.bin(v, r, (lambda a, b: a << b) if op == '<<' else (lambda a, b: a >> b))
        return v
    def p_add(self):
        v = self.p_mul()
        while self.peek()[1] in ('+', '-'):
            op = self.take()[1]; r = self.p_mul()
            v = self.bin(v, r, (lambda a, b: a + b) if op == '+' else (lambda a, b: a - b))
        return v
    def p_mul(self):
        v = self.p_unary()
        while self.peek()[1] in ('*', '/', '%'):
            op = self.take()[1]; r = self.p_unary()
            if op == '*': f = lambda a, b: a * b
            elif op == '/': f = lambda a, b: int(a / b) if b else 0
            else: f = lambda a, b: a % b if b else 0
            v = self.bin(v, r, f)
        return v
    def bin(self, a, b, f):
        if a is None or b is None: return None
        if isinstance(a, Reg) or isinstance(b, Reg):
            raise AsmError('register in arithmetic: %r' % self.text)
        return f(a, b)
    def p_unary(self):
        k, v = self.peek()
        if v == '-':
            self.take(); x = self.p_unary(); return None if x is None else -x
        if v == '+':
            self.take(); return self.p_unary()
        if v == '~':
            self.take(); x = self.p_unary(); return None if x is None else ~x
        if v == '<':
            self.take(); x = self.p_unary(); return None if x is None else x & 0xFFFF
        if v == '>':
            self.take(); x = self.p_unary(); return None if x is None else (x >> 8) & 0xFFFF
        if v == '^':
            self.take(); x = self.p_unary(); return None if x is None else (x >> 16) & 0xFF
        return self.p_prim()
    def p_prim(self):
        k, v = self.take()
        if k is None: raise AsmError('unexpected end of expression %r' % self.text)
        if v == '(':
            x = self.p_or()
            if self.peek()[1] == ')': self.take()
            return x
        if k == 'hex': return int(v[1:], 16)
        if k == 'bin': return int(v[1:], 2)
        if k == 'dec': return int(v, 10)
        if k == 'chr':
            s = v[1:-1].replace("''", "'")
            # multi-character constants are big-endian in xa: 'RL' = $524C
            # (verified against the original build: lda #'RL' = A9 4C 52)
            val = 0
            for ch in s.encode('latin1'):
                val = (val << 8) | ch
            return val
        if v == '*':
            if self.peek()[1] == '*' and self.i + 1 < len(self.toks) and self.toks[self.i+1][1] in ('&','+','-',')','|'):
                self.take(); return self.loadpc
            return self.pc
        if k == 'id': return self.lookup(v)
        raise AsmError('bad token %r in %r' % (v, self.text))

# ---------------------------------------------------------------- 65816 tables
M16 = {
 'adc': dict(imm=0x69,dp=0x65,dpx=0x75,abs=0x6D,absx=0x7D,absy=0x79,long=0x6F,longx=0x7F,ind=0x72,indx=0x61,indy=0x71,indl=0x67,indly=0x77,sr=0x63,sry=0x73),
 'and': dict(imm=0x29,dp=0x25,dpx=0x35,abs=0x2D,absx=0x3D,absy=0x39,long=0x2F,longx=0x3F,ind=0x32,indx=0x21,indy=0x31,indl=0x27,indly=0x37,sr=0x23,sry=0x33),
 'cmp': dict(imm=0xC9,dp=0xC5,dpx=0xD5,abs=0xCD,absx=0xDD,absy=0xD9,long=0xCF,longx=0xDF,ind=0xD2,indx=0xC1,indy=0xD1,indl=0xC7,indly=0xD7,sr=0xC3,sry=0xD3),
 'eor': dict(imm=0x49,dp=0x45,dpx=0x55,abs=0x4D,absx=0x5D,absy=0x59,long=0x4F,longx=0x5F,ind=0x52,indx=0x41,indy=0x51,indl=0x47,indly=0x57,sr=0x43,sry=0x53),
 'lda': dict(imm=0xA9,dp=0xA5,dpx=0xB5,abs=0xAD,absx=0xBD,absy=0xB9,long=0xAF,longx=0xBF,ind=0xB2,indx=0xA1,indy=0xB1,indl=0xA7,indly=0xB7,sr=0xA3,sry=0xB3),
 'ora': dict(imm=0x09,dp=0x05,dpx=0x15,abs=0x0D,absx=0x1D,absy=0x19,long=0x0F,longx=0x1F,ind=0x12,indx=0x01,indy=0x11,indl=0x07,indly=0x17,sr=0x03,sry=0x13),
 'sbc': dict(imm=0xE9,dp=0xE5,dpx=0xF5,abs=0xED,absx=0xFD,absy=0xF9,long=0xEF,longx=0xFF,ind=0xF2,indx=0xE1,indy=0xF1,indl=0xE7,indly=0xF7,sr=0xE3,sry=0xF3),
 'sta': dict(dp=0x85,dpx=0x95,abs=0x8D,absx=0x9D,absy=0x99,long=0x8F,longx=0x9F,ind=0x92,indx=0x81,indy=0x91,indl=0x87,indly=0x97,sr=0x83,sry=0x93),
 'asl': dict(acc=0x0A,dp=0x06,dpx=0x16,abs=0x0E,absx=0x1E),
 'lsr': dict(acc=0x4A,dp=0x46,dpx=0x56,abs=0x4E,absx=0x5E),
 'rol': dict(acc=0x2A,dp=0x26,dpx=0x36,abs=0x2E,absx=0x3E),
 'ror': dict(acc=0x6A,dp=0x66,dpx=0x76,abs=0x6E,absx=0x7E),
 'inc': dict(acc=0x1A,dp=0xE6,dpx=0xF6,abs=0xEE,absx=0xFE),
 'dec': dict(acc=0x3A,dp=0xC6,dpx=0xD6,abs=0xCE,absx=0xDE),
 'bit': dict(imm=0x89,dp=0x24,dpx=0x34,abs=0x2C,absx=0x3C),
 'cpx': dict(imm=0xE0,dp=0xE4,abs=0xEC),
 'cpy': dict(imm=0xC0,dp=0xC4,abs=0xCC),
 'ldx': dict(imm=0xA2,dp=0xA6,dpy=0xB6,abs=0xAE,absy=0xBE),
 'ldy': dict(imm=0xA0,dp=0xA4,dpx=0xB4,abs=0xAC,absx=0xBC),
 'stx': dict(dp=0x86,dpy=0x96,abs=0x8E),
 'sty': dict(dp=0x84,dpx=0x94,abs=0x8C),
 'stz': dict(dp=0x64,dpx=0x74,abs=0x9C,absx=0x9E),
 'trb': dict(dp=0x14,abs=0x1C),
 'tsb': dict(dp=0x04,abs=0x0C),
}
IMM_M = {'adc','and','cmp','eor','lda','ora','sbc','bit'}
IMM_X = {'cpx','cpy','ldx','ldy'}
BRANCH = {'bpl':0x10,'bmi':0x30,'bvc':0x50,'bvs':0x70,'bra':0x80,'bcc':0x90,'bcs':0xB0,'bne':0xD0,'beq':0xF0,
          'blt':0x90,'bge':0xB0}
IMPLIED = {'clc':0x18,'cld':0xD8,'cli':0x58,'clv':0xB8,'dex':0xCA,'dey':0x88,'inx':0xE8,'iny':0xC8,'nop':0xEA,
 'pha':0x48,'phb':0x8B,'phd':0x0B,'phk':0x4B,'php':0x08,'phx':0xDA,'phy':0x5A,'pla':0x68,'plb':0xAB,'pld':0x2B,
 'plp':0x28,'plx':0xFA,'ply':0x7A,'rti':0x40,'rtl':0x6B,'rts':0x60,'sec':0x38,'sed':0xF8,'sei':0x78,'stp':0xDB,
 'tax':0xAA,'tay':0xA8,'tcd':0x5B,'tcs':0x1B,'tdc':0x7B,'tsc':0x3B,'tsx':0xBA,'txa':0x8A,'txs':0x9A,'txy':0x9B,
 'tya':0x98,'tyx':0xBB,'wai':0xCB,'xba':0xEB,'xce':0xFB}
# xa does not track the width changes of literal rep/sep (only 'mode' does);
# verified against the original build (comp.a Pattern2 runs in 16-bit after a sep)
TRACK_SEPREP = bool(os.environ.get('XASM_TRACK_SEPREP'))

CPU65_MNEMS = set(M16) | set(BRANCH) | set(IMPLIED) | {'jmp','jml','jsr','jsl','brl','rep','sep','pea','pei','per','mvn','mvp','brk','cop','wdm'}

# GSU
GSU_IMPL = {'stop':[0x00],'nop':[0x01],'cache':[0x02],'lsr':[0x03],'rol':[0x04],'loop':[0x3C],'alt1':[0x3D],'alt2':[0x3E],
 'alt3':[0x3F],'plot':[0x4C],'rpix':[0x3D,0x4C],'swap':[0x4D],'color':[0x4E],'cmode':[0x3D,0x4E],'not':[0x4F],
 'merge':[0x70],'sbk':[0x90],'sex':[0x95],'asr':[0x96],'div2':[0x3D,0x96],'ror':[0x97],'lob':[0x9E],'fmult':[0x9F],
 'lmult':[0x3D,0x9F],'hib':[0xC0],'getc':[0xDF],'ramb':[0x3E,0xDF],'romb':[0x3F,0xDF],'getb':[0xEF],'getbh':[0x3D,0xEF],
 'getbl':[0x3E,0xEF],'getbs':[0x3F,0xEF]}
GSU_BR = {'bra':0x05,'bge':0x06,'blt':0x07,'bne':0x08,'beq':0x09,'bpl':0x0A,'bmi':0x0B,'bcc':0x0C,'bcs':0x0D,'bvc':0x0E,'bvs':0x0F}
# (prefix bytes, opcode base): register forms, then the #n forms
GSU_REG = {'to':([],0x10),'with':([],0x20),'add':([],0x50),'sub':([],0x60),'and':([],0x70),'mult':([],0x80),
 'from':([],0xB0),'or':([],0xC0),'inc':([],0xD0),'dec':([],0xE0),'adc':([0x3D],0x50),'sbc':([0x3D],0x60),
 'bic':([0x3D],0x70),'umult':([0x3D],0x80),'xor':([0x3D],0xC0),'cmp':([0x3F],0x60),'jmp':([],0x90),'ljmp':([0x3D],0x90)}
GSU_IMM = {'add':([0x3E],0x50),'sub':([0x3E],0x60),'and':([0x3E],0x70),'mult':([0x3E],0x80),'or':([0x3E],0xC0),
 'adc':([0x3F],0x50),'bic':([0x3F],0x70),'umult':([0x3F],0x80),'xor':([0x3F],0xC0)}
GSU_MNEMS = set(GSU_IMPL)|set(GSU_BR)|set(GSU_REG)|set(GSU_IMM)|{'move','moves','ibt','ibtx','iwt','link','ldw','ldb','stw','stb','lm','lms','sm','sms','lea'}

# ---------------------------------------------------------------- sections
class Section:
    def __init__(self, name):
        self.name = name
        self.reloc = True
        self.load = None   # absolute file/load address of start (int)
        self.org = None    # cpu address of start
        self.size_limit = None
        self.cur_load = None
        self.cur_pc = None
        self.data = {}     # load addr -> byte
        self.chunks = []   # (module, load_start, pc_start, size)
        self.started = False

class Macro:
    def __init__(self, name, lines, file):
        self.name = name; self.lines = lines; self.file = file

# ---------------------------------------------------------------- assembler
class Assembler:
    def __init__(self, srcdir, datadir, secmap, placeholders=None, verbose=False):
        self.srcdir = srcdir; self.datadir = datadir; self.secmap = secmap
        self.placeholders = placeholders or {}
        self.files = {f.lower(): f for f in os.listdir(srcdir)}
        self.verbose = verbose
        self.prev = {}        # global symbols from previous pass
        self.prev_mod = {}    # per module: its own equ/label values from the previous pass
        self.prev_mod_next = {}
        self.cache_lines = {}
        self.missing_images = set()
        self.records = []

    # ---- file access
    def read_lines(self, name):
        key = name.lower()
        if key not in self.cache_lines:
            fn = self.files.get(key)
            if fn is None: raise AsmError('include not found: %s' % name)
            with open(os.path.join(self.srcdir, fn), encoding='latin1') as f:
                self.cache_lines[key] = [l.rstrip('\r\n') for l in f]
        return self.cache_lines[key]

    def image_data(self, path):
        # VOLUME:file (RLDATA:, RLLEV:, ...) from datadir, else a source file
        p = path.strip()
        if ':' in p:
            vol, rest = p.split(':', 1)
            cand = os.path.join(self.datadir, vol.upper(), rest)
        else:
            cand = os.path.join(self.srcdir, self.files.get(p.lower(), p))
        # case-insensitive resolution
        if not os.path.exists(cand):
            alt = self._ci_path(cand)
            if alt: cand = alt
        if os.path.exists(cand):
            with open(cand, 'rb') as f: return f.read()
        self.missing_images.add(p)
        ph = self.placeholders.get(p)
        if ph is not None: return bytes(ph)
        return b''

    def _ci_path(self, path):
        parts = path.split('/')
        cur = '/' if path.startswith('/') else '.'
        for part in parts:
            if part == '': continue
            if not os.path.isdir(cur): return None
            m = {x.lower(): x for x in os.listdir(cur)}
            if part.lower() not in m: return None
            cur = os.path.join(cur, m[part.lower()])
        return cur

    # ---- symbol handling
    def lookup(self, name):
        n = self.resolve_name(name)
        if n in self.mod_syms: return self.mod_syms[n]
        # a symbol this module defines further down (xa assembles every module
        # on its own, so its own equ/label wins over another module's global;
        # e.g. rlvsegs4.a uses rDeltaX/rDeltaY before defining them)
        pm = self.prev_mod.get(self.cur_module)
        if pm is not None and n in pm: return pm[n]
        if n in self.gsyms: return self.gsyms[n]
        lk = n.lower()
        if lk in REGS: return REGS[lk]
        if n in self.prev:
            self.used_prev = True
            return self.prev[n]
        self.undef.add(n)
        return None

    def resolve_name(self, name):
        name = name.lower()
        if name.startswith('.'):
            if self.macro_scope is not None:
                return '%s%s' % (self.macro_scope, name)
            return '%s%s' % (self.scope, name)
        return name

    def define(self, name, value, kind='label'):
        n = self.resolve_name(name)
        if self.recording:
            self.defs.append((self.cur_module, self.cur_file, self.cur_line, n, kind, value))
        if kind == 'var':
            self.mod_syms[n] = value; self.cur_mod_defs.pop(n, None); self.mod_vars.add(n); return
        if n not in self.mod_vars: self.cur_mod_defs[n] = value
        if n in self.mod_syms and kind == 'label' and not n.endswith(':'):
            if self.mod_syms[n] != value:
                self.warn('redefinition of %s' % n)
        self.mod_syms[n] = value
        if not name.startswith('.') or True:
            if kind == 'label' or kind == 'equ':
                if n in self.gsyms and self.gsyms[n] != value and kind == 'label' and not n.startswith(('.', '__m')) and '.' not in n[1:2]:
                    self.dup_globals.add(n)
                self.gsyms[n] = value

    def ev(self, text, allow_none=True):
        s = self.sec
        lp = s.cur_load if s and s.cur_load is not None else 0
        v = ExprParser(text, self.lookup, self.pc_or0(), lp).parse()
        if v is None and not allow_none:
            raise AsmError('undefined symbol in %r' % text)
        return v

    def pc_or0(self):
        s = self.sec
        return s.cur_pc if s and s.cur_pc is not None else 0

    def warn(self, msg):
        self.warnings.append('%s:%d: %s' % (self.cur_file, self.cur_line, msg))

    # ---- emission
    def emit(self, bs):
        if getattr(self, 'dry', False): return
        s = self.sec
        if s is None: raise AsmError('no section')
        if s.cur_load is None: raise AsmError('section %s not placed' % s.name)
        for b in bs:
            if s.cur_load >= 0x80000000:
                s.data[s.cur_load] = b & 0xFF
            s.cur_load += 1; s.cur_pc += 1
        self.modbytes[s.name] = self.modbytes.get(s.name, 0) + len(bs)
        if self.recording and bs:
            self.listing.append((self.cur_module, self.cur_file, self.cur_line, s.name, s.cur_pc - len(bs), s.cur_load - len(bs), bytes(b & 0xFF for b in bs)))

    def skip(self, n):
        if getattr(self, 'dry', False): return
        s = self.sec
        s.cur_load += n; s.cur_pc += n
        self.modbytes[s.name] = self.modbytes.get(s.name, 0) + n

    def record(self, kind, info):
        if self.recording:
            self.records.append((self.cur_file, self.cur_line, self.ctx_id, kind, info))

    # ---- sections
    def section_directive(self, args):
        parts = split_args(args)
        name = parts[0]
        attrs = {}
        reloc = False
        for p in parts[1:]:
            if '=' in p:
                k, v = p.split('=', 1); attrs[k.strip().upper()] = v.strip()
            elif p.upper() == 'RELOC': reloc = True
        key = name
        s = self.sections.get(key)
        if s is None:
            s = Section(name); self.sections[key] = s; self.section_order.append(key)
        if 'LOAD' in attrs or 'ORG' in attrs:
            if not s.started:
                s.reloc = False
                ld = self.ev(attrs.get('LOAD', attrs.get('ORG')))
                og = self.ev(attrs.get('ORG', attrs.get('LOAD')))
                if ld is None or og is None:
                    ld = ld or 0x7FFFFFFF; og = og or 0
                s.load = ld; s.org = og
                s.cur_load = ld; s.cur_pc = og; s.started = True
        elif not s.started:
            # relocatable: place from section map
            if name in self.secmap:
                ld, pc, sz = self.secmap[name]
                s.load = ld; s.org = pc; s.cur_load = ld; s.cur_pc = pc; s.started = True
            else:
                raise AsmError('relocatable section %s has no placement' % name)
        self.switch_section(s)

    def switch_section(self, s):
        if self.sec is not None and self.sec is not s:
            self.close_chunk()
        if self.sec is not s:
            self.sec = s
            pins = self.pins.get(s.name) if getattr(self, 'pins', None) else None
            if pins:
                k = len(s.chunks)
                if k < len(pins):
                    s.cur_load, s.cur_pc = pins[k]
            self.chunk_start = (s.cur_load, s.cur_pc)

    def close_chunk(self):
        s = self.sec
        if s is None or s.cur_load is None: return
        st = self.chunk_start
        if st and s.cur_load != st[0]:
            s.chunks.append((self.cur_module, st[0], st[1], s.cur_load - st[0]))
        self.chunk_start = (s.cur_load, s.cur_pc)

    # ---- main driver
    def assemble(self, modules, passes=12):
        for p in range(passes):
            self.run_pass(modules)
            changed = [k for k in set(self.gsyms) | set(self.prev) if self.gsyms.get(k) != self.prev.get(k)]
            if self.verbose:
                print('pass %d: %d symbols, %d changed, %d undefined' % (p, len(self.gsyms), len(changed), len(self.undef)), file=sys.stderr)
            self.prev = dict(self.gsyms)
            if self.prev_mod != self.prev_mod_next: changed = changed or ['<module>']
            self.prev_mod = {k: dict(v) for k, v in self.prev_mod_next.items()}
            if not changed and p > 0:
                break
        # final recording pass
        self.recording = True; self.records = []; self.listing = []; self.defs = []
        self.run_pass(modules)
        self.recording = False

    def run_pass(self, modules):
        self.gsyms = {}
        self.sections = {}
        self.section_order = []
        self.sec = None
        self.undef = set()
        self.warnings = []
        self.dup_globals = set()
        self.macros = {}
        self.texts = []
        self.ctx_counter = 0
        self.recording = getattr(self, 'recording', False)
        self.errors = []
        for m in modules:
            self.assemble_module(m)

    def assemble_module(self, fname):
        self.cur_module = fname
        self.mod_syms = {}
        self.cur_mod_defs = {}; self.mod_vars = set()
        self.prev_mod_next[fname] = self.cur_mod_defs
        self.scope = ''
        self.macro_scope = None
        self.cpu = '65816'
        self.mflag = 16; self.xflag = 16
        self.mode_stack = []
        self.dbr = None; self.dpr = 0
        self.modbytes = {}
        self.ctx_id = 0
        self.process_file(fname)
        self.close_chunk()
        self.sec = None

    def process_file(self, fname):
        lines = self.read_lines(fname)
        self.process_lines(lines, fname, 0)

    def process_lines(self, lines, fname, base_line, macro_args=None, ctx=0):
        i = 0
        cond = []  # stack of bools (active)
        n = len(lines)
        while i < n:
            raw = lines[i]; lineno = base_line + i + 1; i += 1
            save_file, save_line = getattr(self, 'cur_file', None), getattr(self, 'cur_line', None)
            self.cur_file, self.cur_line = fname, lineno
            line = raw
            if macro_args is not None:
                line = self.subst_args(line, macro_args)
            if not line.strip() or line.lstrip().startswith(';') or line.startswith('*'):
                continue
            label, mnem, ops = self.split_line(line)
            ml = mnem.lower() if mnem else ''
            active = all(cond)
            # conditionals
            if ml in ('ifn', 'ife', 'ifd', 'ifnd'):
                if not active:
                    cond.append(False); continue
                if ml in ('ifd', 'ifnd'):
                    d = self.lookup(ops.strip()) is not None
                    cond.append(d if ml == 'ifd' else not d)
                else:
                    v = self.ev(ops)
                    if v is None:
                        self.warn('undefined in conditional %r' % ops); v = 0
                    cond.append((v != 0) if ml == 'ifn' else (v == 0))
                continue
            if ml == 'else':
                cond[-1] = not cond[-1] if all(cond[:-1]) else False; continue
            if ml in ('endif', 'endc'):
                if cond: cond.pop()
                else: self.warn('unbalanced endif')
                continue
            if not active:
                continue
            # macro definition
            if ml == 'macro':
                body = []
                while i < n:
                    l2 = lines[i]; i += 1
                    _, m2, _ = self.split_line(strip_comment(l2)) if l2.strip() and not l2.startswith(('*', ';')) else (None, '', '')
                    if m2 and m2.lower() in ('endmac', 'endm'):
                        break
                    body.append(l2)
                self.macros[label.lower()] = Macro(label, body, fname)
                continue
            if ml == 'repeat':
                cnt = self.ev(ops, False)
                body = []; depth = 1
                while i < n:
                    l2 = lines[i]; i += 1
                    _, m2, _ = self.split_line(strip_comment(l2)) if l2.strip() and not l2.startswith(('*', ';')) else (None, '', '')
                    if m2 and m2.lower() == 'repeat': depth += 1
                    if m2 and m2.lower() == 'endrep':
                        depth -= 1
                        if depth == 0: break
                    body.append(l2)
                start = lineno
                for k in range(cnt):
                    self.process_lines(body, fname, start, macro_args, ctx)
                continue
            try:
                self.do_line(label, mnem, ml, ops, fname, lineno, ctx)
            except (AsmError, KeyError, TypeError) as e:
                self.errors.append('%s:%d: %s   [%s]' % (fname, lineno, e, raw.strip()))
        if cond:
            self.warn('unterminated conditional in %s' % fname)

    def subst_args(self, line, args):
        def rep(m):
            k = int(m.group(1))
            return args[k] if k < len(args) else ''
        return re.sub(r'@(\d)', rep, line)

    def split_line(self, line):
        s = strip_comment(line).rstrip()
        label = None
        if s and not s[0].isspace():
            m = re.match(r'([A-Za-z_.@][A-Za-z0-9_.@]*:?)', s)
            if not m:
                raise AsmError('bad label line %r' % s)
            label = m.group(1)
            rest = s[m.end():]
            s = rest
        parts = s.strip().split(None, 1)
        mnem = parts[0] if parts else ''
        ops = parts[1].strip() if len(parts) > 1 else ''
        return label, mnem, ops

    # ---- per line
    def do_line(self, label, mnem, ml, ops, fname, lineno, ctx):
        # directives that use the label
        if ml in ('equ', '='):
            v = self.ev(ops)
            if label.endswith(':'): self.mod_syms[label.lower()] = v; self.gsyms[label.lower()] = v
            else: self.define(label, v, 'equ')
            return
        if ml in ('var', 'set'):
            v = self.ev(ops)
            self.define(label, v, 'var'); return
        if label is not None:
            if label.startswith('.') or label.endswith(':'):
                pass
            else:
                self.scope = label.lower()
            if self.sec is None:
                if not label.endswith(':'):
                    self.warn('label %s outside section' % label)
            else:
                self.define(label, self.sec.cur_pc)
        if not mnem:
            return
        # macros
        if ml in self.macros:
            mac = self.macros[ml]
            args = split_args(ops)
            args = [a for a in args]
            # the body sees the args as @0..@9 and has its own local-label scope
            self.ctx_counter += 1
            saved = self.macro_scope
            self.macro_scope = '__m%d' % self.ctx_counter
            self.process_lines(mac.lines, mac.file, 0, args, self.ctx_counter)
            self.macro_scope = saved
            self.cur_file, self.cur_line = fname, lineno
            return
        h = getattr(self, 'd_' + ml.replace('.', '_'), None)
        if h is not None:
            h(ops); return
        if self.cpu == 'sfx' and ml in GSU_MNEMS:
            self.gsu(ml, ops); return
        if ml in CPU65_MNEMS:
            self.c65(ml, ops); return
        if self.cpu == 'sfx':
            raise AsmError('unknown mnemonic %s' % mnem)
        raise AsmError('unknown mnemonic %s' % mnem)

    # ---- directives
    def d_include(self, ops):
        f = ops.strip().strip('"')
        save = (self.cur_file, self.cur_line)
        if ':' in f:
            vol, rest = f.split(':', 1)
            path = os.path.join(self.datadir, vol.upper(), rest)
            key = 'ext:' + path
            if key not in self.cache_lines:
                with open(path, encoding='latin1') as fh:
                    self.cache_lines[key] = [l.rstrip('\r\n') for l in fh]
            self.process_lines(self.cache_lines[key], f, 0)
        else:
            self.process_file(f)
        self.cur_file, self.cur_line = save
    def d_section(self, ops): self.section_directive(ops)
    def d_globals(self, ops): pass
    def d_public(self, ops): pass
    def d_extern(self, ops): pass
    def d_xref(self, ops): pass
    def d_xdef(self, ops): pass
    def d_plist(self, ops): pass
    def d_mmu(self, ops): pass
    def d_cpudata(self, ops): pass
    def d_dump(self, ops): pass
    def d_end(self, ops): pass
    def d_cpu(self, ops):
        o = ops.strip().lower()
        self.cpu = 'sfx' if o == 'sfx' else '65816'
        self.record('cpu', self.cpu)
    def d_text(self, ops): self.texts_dir(ops)
    def d_ltext(self, ops): self.texts_dir(ops)
    def texts_dir(self, ops):
        a = split_args(ops)
        if not a: return
        if a[0].startswith('"'):
            vals = [self.ev(x) for x in a[1:]]
            self.texts.append('%s:%d: %s %s' % (self.cur_file, self.cur_line, a[0], vals))
        else:
            v = self.ev(a[0])
            if v:
                vals = [self.ev(x) for x in a[2:]]
                self.texts.append('%s:%d: COND %s %s' % (self.cur_file, self.cur_line, a[1] if len(a) > 1 else '', vals))
    def d_dbr(self, ops):
        o = ops.strip()
        self.dbr = None if o == '?' else (self.ev(o) & 0xFF if self.ev(o) is not None else None)
        self.record('dbr', self.dbr)
    def d_dpr(self, ops):
        o = ops.strip()
        self.dpr = None if o == '?' else self.ev(o)
        self.record('dpr', self.dpr)
    def d_mode(self, ops):
        s = ops.strip().strip("'\"")
        emit = '!' in s
        seps = 0; reps = 0; native = False
        j = 0
        while j < len(s):
            c = s[j]
            if c == '@':
                j += 1; c2 = s[j] if j < len(s) else ''
                if c2.upper() == 'A': self.mflag = None
                if c2.upper() == 'X': self.xflag = None
            elif c == 'A': self.mflag = 16; reps |= 0x20
            elif c == 'a': self.mflag = 8; seps |= 0x20
            elif c == 'X': self.xflag = 16; reps |= 0x10
            elif c == 'x': self.xflag = 8; seps |= 0x10
            elif c == 'E': native = True
            j += 1
        self.record('mode', (s, self.mflag, self.xflag))
        if emit:
            if native: self.emit([0x18, 0xFB])
            if seps: self.emit([0xE2, seps])
            if reps: self.emit([0xC2, reps])
    def d_pushmode(self, ops): self.mode_stack.append((self.mflag, self.xflag))
    def d_popmode(self, ops): self.mflag, self.xflag = self.mode_stack.pop()
    def d_org(self, ops):
        v = self.ev(ops); self.sec.cur_pc = v if v is not None else 0
        self.record('org', v)
    def d_load(self, ops):
        v = self.ev(ops)
        s = self.sec
        if s.cur_load is not None and s.cur_load < 0x80000000:
            s.cur_load = v
    def d_reorg(self, ops): raise AsmError('reorg unsupported')
    def d_align(self, ops):
        a = split_args(ops)
        n = self.ev(a[0], False)
        off = self.ev(a[1]) if len(a) > 1 else 0
        if off is None: off = 0
        pc = self.sec.cur_pc
        pad = (off - pc) % n
        self.record('align', pad)
        self.dec = {'pad': pad}
        if self.sec.cur_load >= 0x80000000: self.emit([0] * pad)
        else: self.skip(pad)
    def data_items(self, ops, size):
        out = []
        for a in split_args(ops):
            if (a.startswith("'") and a.endswith("'") and (size == 1 or len(a) - 2 == size)) or a.startswith('"'):
                s = a[1:-1].replace("''", "'") if a.startswith("'") else a[1:-1]
                out.extend(s.encode('latin1'))
                continue
            v = self.ev(a.lstrip('#'))
            if v is None: v = 0
            out.extend([(v >> (8 * k)) & 0xFF for k in range(size)])
        return out
    def d_dc_b(self, ops): self.emit(self.data_items(ops, 1))
    def d_dc_w(self, ops): self.emit(self.data_items(ops, 2))
    def d_word(self, ops): self.emit(self.data_items(ops, 2))
    def d_dc_l(self, ops): self.emit(self.data_items(ops, 3))
    def d_dc_4(self, ops): self.emit(self.data_items(ops, 4))
    def dcb(self, ops, size):
        a = split_args(ops)
        n = self.ev(a[0], False); v = self.ev(a[1]) if len(a) > 1 else 0
        v = v or 0
        self.emit([(v >> (8 * k)) & 0xFF for _ in range(n) for k in range(size)])
    def d_dcb_b(self, ops): self.dcb(ops, 1)
    def d_dcb_w(self, ops): self.dcb(ops, 2)
    def d_dcb_l(self, ops): self.dcb(ops, 3)
    def ds(self, ops, size):
        n = self.ev(ops)
        if n is None: n = 0; self.warn('undefined ds size %r' % ops)
        if n < 0: raise AsmError('negative ds')
        if self.sec.cur_load >= 0x80000000: self.emit([0] * (n * size))
        else: self.skip(n * size)
    def d_ds_b(self, ops): self.ds(ops, 1)
    def d_ds_w(self, ops): self.ds(ops, 2)
    def d_ds_l(self, ops): self.ds(ops, 3)
    def d_ds_4(self, ops): self.ds(ops, 4)
    def d_image(self, ops):
        a = split_args(ops)
        data = self.image_data(a[0])
        off = self.ev(a[1], False) if len(a) > 1 else 0
        ln = self.ev(a[2], False) if len(a) > 2 else len(data) - off
        chunk = data[off:off + ln]
        if len(chunk) < ln and data:
            self.warn('image %s short: want %d got %d' % (a[0], ln, len(chunk)))
        if not data and a[0] in self.placeholders:
            chunk = bytes(ln) if len(a) > 2 else b''
        self.record('image', (a[0], off, len(chunk)))
        self.emit(list(chunk))

    # ---- 65816
    def imm_size(self, ml):
        if ml in IMM_M: f = self.mflag
        elif ml in IMM_X: f = self.xflag
        else: f = 8
        if f is None:
            self.warn('unknown register size for %s #' % ml); f = 16
        return 1 if f == 8 else 2

    def c65(self, ml, ops):
        o = ops.strip()
        pcb = self.sec.cur_pc
        if ml in IMPLIED:
            self.emit([IMPLIED[ml]]); return
        if ml in BRANCH:
            t = self.ev(o)
            if t is None: d = 0
            else:
                d = t - (pcb + 2)
                # xa evaluates '*' in a branch operand as the address after the
                # branch (verified: rlsound.a 'bmi *+5' = 30 05 in the release)
                if re.search(r'(^|[^\w)])\*', o): d += 2
                if not -128 <= d <= 127: raise AsmError('branch out of range (%d)' % d)
            self.emit([BRANCH[ml], d & 0xFF]); return
        if ml == 'brl':
            t = self.ev(o); d = 0 if t is None else t - (pcb + 3)
            self.emit([0x82, d & 0xFF, (d >> 8) & 0xFF]); return
        if ml in ('rep', 'sep'):
            v = self.ev(o.lstrip('#'), False)
            if not TRACK_SEPREP: pass
            elif ml == 'rep':
                if v & 0x20: self.mflag = 16
                if v & 0x10: self.xflag = 16
            else:
                if v & 0x20: self.mflag = 8
                if v & 0x10: self.xflag = 8
            self.emit([0xC2 if ml == 'rep' else 0xE2, v & 0xFF]); return
        if ml in ('brk', 'cop', 'wdm'):
            v = self.ev(o.lstrip('#')) if o else 0
            self.emit([{'brk': 0, 'cop': 2, 'wdm': 0x42}[ml], (v or 0) & 0xFF]); return
        if ml == 'pea':
            v = self.ev(o.lstrip('#')) or 0
            self.emit([0xF4, v & 0xFF, (v >> 8) & 0xFF]); return
        if ml in ('mvn', 'mvp'):
            a = split_args(o)
            if len(a) == 1:
                v = self.ev(a[0].lstrip('#')) or 0
                src, dst = (v >> 8) & 0xFF, v & 0xFF
            else:
                src = (self.ev(a[0].lstrip('#')) or 0) & 0xFF; dst = (self.ev(a[1].lstrip('#')) or 0) & 0xFF
            self.emit([0x54 if ml == 'mvn' else 0x44, dst, src]); return
        if ml in ('jsl', 'jml', 'jmp', 'jsr'):
            self.c65_jump(ml, o); return
        tab = M16[ml]
        # accumulator
        if o == '' or o.lower() == 'a':
            self.emit([tab['acc']]); return
        if o.startswith('#'):
            sz = self.imm_size(ml)
            v = self.ev(o[1:])
            if v is None: v = 0
            self.record('imm', sz)
            self.dec = {'imm': sz}
            self.emit([tab['imm']] + [(v >> (8 * k)) & 0xFF for k in range(sz)]); return
        # index suffix
        idx = None
        m = re.match(r'^(.*),\s*([xXyYsS])$', o)
        body = o
        if m:
            body, idx = m.group(1).strip(), m.group(2).lower()
        # indirect forms
        if body.startswith('[') and body.endswith(']'):
            v = self.ev(body[1:-1]); mode = 'indly' if idx == 'y' else 'indl'
            self.emit([tab[mode], self.dp_off(v)]); return
        if body.startswith('(') and self._outer_paren(body) and 'ind' in tab:
            inner = body[1:-1].strip()
            m2 = re.match(r'^(.*),\s*([xXsS])$', inner)
            if m2:
                v = self.ev(m2.group(1))
                if m2.group(2).lower() == 's':
                    self.emit([tab['sry'], (v or 0) & 0xFF]); return
                self.emit([tab['indx'], self.dp_off(v)]); return
            v = self.ev(inner)
            mode = 'indy' if idx == 'y' else 'ind'
            self.emit([tab[mode], self.dp_off(v)]); return
        if idx == 's':
            v = self.ev(body); self.emit([tab['sr'], (v or 0) & 0xFF]); return
        force = None
        if body[:1] in '<!>' and not body.startswith('<<'):
            force = body[0]; body = body[1:].strip()
        v = self.ev(body)
        mode = self.choose_addr(ml, tab, v, force, idx)
        self.dec = {'addr': mode, 'force': force, 'idx': idx, 'body': body}
        self.record('addr', mode)
        if v is None: v = 0
        if mode.startswith('dp'):
            self.emit([tab[mode], self.dp_off(v)])
        elif mode.startswith('abs'):
            self.emit([tab[mode], v & 0xFF, (v >> 8) & 0xFF])
        else:
            self.emit([tab[mode], v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF])

    def _balanced(self, s):
        d = 0
        for ch in s:
            if ch in '([': d += 1
            elif ch in ')]': d -= 1
        return d == 0
    def _outer_paren(self, s):
        d = 0
        for k, ch in enumerate(s):
            if ch == '(': d += 1
            elif ch == ')':
                d -= 1
                if d == 0 and k != len(s) - 1: return False
        return True

    def dp_off(self, v):
        if v is None: return 0
        base = self.dpr or 0
        off = (v & 0xFFFF) - base
        if self.dpr is not None and not (0 <= off <= 0xFF) and v < 0x10000:
            if self.sec.cur_load is not None: pass
        return off & 0xFF

    def choose_addr(self, ml, tab, v, force, idx):
        sfx = {'x': 'x', 'y': 'y', None: ''}[idx]
        def ok(m): return (m + sfx) in tab
        if force == '<':
            return 'dp' + sfx if ok('dp') else 'abs' + sfx
        if force == '!':
            if ok('abs'): return 'abs' + sfx
            raise AsmError('no abs mode')
        if force == '>':
            if ok('long'): return 'long' + sfx
            self.warn('long forced but not available for %s,%s' % (ml, idx)); return 'abs' + sfx
        if v is None:
            # unknown: assume largest
            if ok('long'): return 'long' + sfx
            return 'abs' + sfx
        if v < 0x10000:
            if self.dpr is not None and 0 <= v - self.dpr <= 0xFF and ok('dp'):
                return 'dp' + sfx
            # bank-0 address with a non-zero data bank: xa uses long addressing
            # (verified against the original build, e.g. GSU registers in LEVEL)
            if self.dbr and ok('long') and not os.environ.get('XASM_OLD_ABS'): return 'long' + sfx
            if ok('abs'): return 'abs' + sfx
            return 'long' + sfx
        bank = (v >> 16) & 0xFF
        if self.dbr is not None and bank == self.dbr and ok('abs'):
            return 'abs' + sfx
        if ok('long'): return 'long' + sfx
        self.warn('no long mode for %s %s (bank $%02X, dbr %s)' % (ml, sfx, bank, self.dbr))
        return 'abs' + sfx

    def c65_jump(self, ml, o):
        if ml in ('jsl', 'jml'):
            if o.startswith('['):
                v = self.ev(o[1:-1]) or 0
                self.emit([0xDC, v & 0xFF, (v >> 8) & 0xFF]); return
            b = o[1:] if o.startswith('>') else o
            v = self.ev(b) or 0
            self.emit([0x22 if ml == 'jsl' else 0x5C, v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF]); return
        # jmp / jsr
        if o.startswith('(') and self._outer_paren(o):
            inner = o[1:-1]
            m = re.match(r'^(.*),\s*[xX]$', inner)
            if m:
                v = self.ev(m.group(1)) or 0
                self.emit([0x7C if ml == 'jmp' else 0xFC, v & 0xFF, (v >> 8) & 0xFF]); return
            v = self.ev(inner) or 0
            self.emit([0x6C, v & 0xFF, (v >> 8) & 0xFF]); return
        if o.startswith('['):
            v = self.ev(o[1:-1]) or 0
            self.emit([0xDC, v & 0xFF, (v >> 8) & 0xFF]); return
        if o.startswith('>'):
            v = self.ev(o[1:]) or 0
            self.emit([0x5C if ml == 'jmp' else 0x22, v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF]); return
        b = o[1:] if o.startswith('!') else o
        v = self.ev(b) or 0
        self.emit([0x4C if ml == 'jmp' else 0x20, v & 0xFF, (v >> 8) & 0xFF])

    # ---- GSU
    def reg(self, text):
        t = text.strip()
        v = self.ev(t)
        if not isinstance(v, Reg):
            raise AsmError('register expected: %r' % text)
        return v.n

    def gsu(self, ml, ops):
        o = ops.strip()
        pcb = self.sec.cur_pc
        if ml in GSU_IMPL and not o:
            self.emit(GSU_IMPL[ml]); return
        if ml in GSU_BR:
            t = self.ev(o)
            d = 0 if t is None else t - (pcb + 2)
            if re.search(r'(^|[^\w)])\*', o): d += 2      # see c65(): '*' = address after the branch
            if t is not None and not -128 <= d <= 127: raise AsmError('GSU branch out of range %d' % d)
            self.emit([GSU_BR[ml], d & 0xFF]); return
        a = split_args(o)
        if ml in ('move', 'moves'):
            dst, src = a[0], a[1]
            if ml == 'moves':
                d = self.reg(dst); s = self.reg(src)
                self.emit([0x20 | d, 0xB0 | s]); return
            if src.startswith('#'):
                d = self.reg(dst); v = self.ev(src[1:])
                kind = self.gsu_imm_kind(v)
                self.dec = {'gform': kind}
                self.record('gmovi', kind)
                if kind == 'ibt': self.emit([0xA0 | d, v & 0xFF])
                else:
                    v = v or 0; self.emit([0xF0 | d, v & 0xFF, (v >> 8) & 0xFF])
                return
            if src.startswith('(') and self._outer_paren(src) and not self._is_reg_expr(src[1:-1]):
                d = self.reg(dst); v = self.ev(src[1:-1])
                self.gsu_lm(d, v, load=True); return
            if dst.startswith('(') and self._outer_paren(dst) and not self._is_reg_expr(dst[1:-1]):
                s = self.reg(src); v = self.ev(dst[1:-1])
                self.gsu_lm(s, v, load=False); return
            d = self.reg(dst); s = self.reg(src)
            self.emit([0x20 | s, 0x10 | d]); return
        if ml in ('ibt', 'ibtx'):
            d = self.reg(a[0]); v = self.ev(a[1].lstrip('#'))
            v = v or 0
            if ml == 'ibt' and not (-128 <= v <= 127 or 0xFF80 <= v <= 0xFFFF):
                if not (0 <= v <= 0xFF):
                    raise AsmError('ibt out of range %d' % v)
                self.warn('ibt value $%X > 127' % v)
            self.emit([0xA0 | d, v & 0xFF]); return
        if ml in ('iwt', 'lea'):
            d = self.reg(a[0]); v = self.ev(a[1].lstrip('#')) or 0
            self.emit([0xF0 | d, v & 0xFF, (v >> 8) & 0xFF]); return
        if ml in ('lm', 'lms'):
            d = self.reg(a[0]); v = self.ev(a[1].strip()[1:-1])
            self.gsu_lm(d, v, True, force=ml); return
        if ml in ('sm', 'sms'):
            s = self.reg(a[1]); v = self.ev(a[0].strip()[1:-1])
            self.gsu_lm(s, v, False, force=ml); return
        if ml == 'link':
            v = self.ev(o.lstrip('#'), False)
            if not 1 <= v <= 4: raise AsmError('link range')
            self.emit([0x90 | v]); return
        if ml in ('ldw', 'ldb', 'stw', 'stb'):
            r = self.reg(o.strip()[1:-1])
            base = {'ldw': [0x40], 'ldb': [0x3D, 0x40], 'stw': [0x30], 'stb': [0x3D, 0x30]}[ml]
            self.emit(base[:-1] + [base[-1] | r]); return
        if o.startswith('#') and ml in GSU_IMM:
            v = self.ev(o[1:], False)
            if not 0 <= v <= 15: raise AsmError('GSU #imm out of range %d for %s' % (v, ml))
            if ml in ('and', 'or', 'bic', 'xor') and v == 0:
                raise AsmError('#0 invalid for %s' % ml)
            pre, base = GSU_IMM[ml]
            self.emit(pre + [base | v]); return
        if ml in GSU_REG:
            r = self.reg(o)
            pre, base = GSU_REG[ml]
            self.emit(pre + [base | r]); return
        raise AsmError('bad GSU instruction %s %s' % (ml, ops))

    def _is_reg_expr(self, t):
        try:
            v = self.ev(t)
        except AsmError:
            return False
        return isinstance(v, Reg)

    def gsu_imm_kind(self, v):
        if v is None: return 'iwt'
        v16 = v & 0xFFFF
        return 'ibt' if (v16 < 0x80 or v16 >= 0xFF80) else 'iwt'

    def gsu_lm(self, r, v, load, force=None):
        a = None if v is None else v & 0xFFFF
        short = a is not None and a <= 0x1FE and not (a & 1)
        if force in ('lms', 'sms'): short = True
        if force in ('lm', 'sm'): short = False
        self.record('glm', 'short' if short else 'long')
        self.dec = {'gform': ('lms' if load else 'sms') if short else ('lm' if load else 'sm')}
        if short:
            self.emit([0x3D if load else 0x3E, 0xA0 | r, (a >> 1) & 0xFF])
        else:
            a = a or 0
            self.emit([0x3D if load else 0x3E, 0xF0 | r, a & 0xFF, (a >> 8) & 0xFF])

REGS = {('r%d' % i): Reg(i) for i in range(16)}

# ---------------------------------------------------------------- driver
def parse_secmap(fn):
    m = {}
    for line in open(fn, encoding='latin1'):
        p = line.split()
        if len(p) == 4 and p[1].startswith('$'):
            m[p[0]] = (int(p[1][1:], 16), int(p[2][1:], 16), int(p[3][1:], 16))
    return m

def parse_bnk(fn):
    out = []
    for line in open(fn, encoding='latin1'):
        m = re.match(r'\$([0-9A-F]+)-\$([0-9A-F]+) \$([0-9A-F]+)-\$([0-9A-F]+) \(\$([0-9A-F]+)\)', line.strip())
        if m:
            out.append(tuple(int(x, 16) for x in m.groups()))
    return out

def modules_from_smakefile(srcdir):
    txt = open(os.path.join(srcdir, 'smakefile'), encoding='latin1').read()
    m = re.search(r'^RL = \\\n(.*?)\n\n', txt, re.S | re.M)
    mods = re.findall(r'(\S+)\.o', m.group(1))
    files = {f.lower(): f for f in os.listdir(srcdir)}
    return [files[(x + '.a').lower()] for x in mods]

if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('srcdir'); ap.add_argument('datadir'); ap.add_argument('out')
    ap.add_argument('--sec'); ap.add_argument('--placeholders')
    ap.add_argument('--report'); ap.add_argument('--pin', action='store_true'); ap.add_argument('-v', action='store_true')
    ap.add_argument('--romsize', type=int, default=0x200000)
    a = ap.parse_args()
    secmap = parse_secmap(a.sec or os.path.join(a.srcdir, 'RL.SEC'))
    ph = json.load(open(a.placeholders)) if a.placeholders else {}
    asm = Assembler(a.srcdir, a.datadir, secmap, ph, a.v)
    asm.errors = []
    mods = modules_from_smakefile(a.srcdir)
    if a.pin:
        bnk = parse_bnk(os.path.join(a.srcdir, 'RL.BNK'))
        pins = {}
        for (l0, l1, p0, p1, sz) in bnk:
            for n, (ld, pc, s_) in secmap.items():
                if s_ > 0 and ld <= l0 < ld + s_:
                    pins.setdefault(n, []).append((l0, p0)); break
        asm.pins = pins
    asm.assemble(mods)
    rom = bytearray(b'\xff' * a.romsize)
    overlaps = 0
    owner = {}
    for name in asm.section_order:
        s = asm.sections[name]
        for addr, b in s.data.items():
            off = addr - 0x80000000
            if 0 <= off < len(rom):
                if off in owner and owner[off] != name: overlaps += 1
                owner[off] = name
                rom[off] = b
    open(a.out, 'wb').write(rom)
    errs = sorted(set(asm.errors))
    print('errors: %d, warnings: %d, undefined: %d, overlaps: %d' % (len(errs), len(asm.warnings), len(asm.undef), overlaps))
    for e in errs[:60]: print('E', e)
    if a.report:
        with open(a.report, 'w') as f:
            for e in errs: f.write('E %s\n' % e)
            for w in asm.warnings: f.write('W %s\n' % w)
            f.write('UNDEF %s\n' % sorted(asm.undef))
            f.write('MISSING %s\n' % sorted(asm.missing_images))
            for t in asm.texts: f.write('T %s\n' % t)
            for name in asm.section_order:
                s = asm.sections[name]
                tot = sum(c[3] for c in s.chunks)
                f.write('S %-24s load=%s pc=%s size=%X\n' % (name, hex(s.load) if s.load is not None else None, hex(s.org) if s.org is not None else None, tot))
                for c in s.chunks:
                    f.write('C %-24s %-16s %08X %08X %X\n' % (name, c[0], c[1], c[2], c[3]))
        import pickle
        pickle.dump(asm.listing, open(a.out + '.lst.pkl', 'wb'))
        pickle.dump(asm.defs, open(a.out + '.defs.pkl', 'wb'))
        json.dump({k: v for k, v in asm.gsyms.items() if isinstance(v, int)}, open(a.out + '.sym.json', 'w'), indent=0, sort_keys=True)
