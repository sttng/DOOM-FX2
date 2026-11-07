#!/usr/bin/env python3
"""
xa2asar.py - translate the DOOM-FX (Reality Engine) sources from the
Sculptured Software xa/xl dialect to asar (65816 + superfx) syntax.

The translation is driven by the reference assembler (xasm.py): every
instruction whose encoding depends on symbol values (addressing size,
immediate size, GSU ibt/iwt, lms/lm, align padding) is emitted with an
explicit form taken from the reference assembly, so the asar build is
byte-identical to the reference build.

usage: xa2asar.py SRCDIR DATADIR OUTDIR   (SRCDIR, DATADIR as for xasm.py)
  writes OUTDIR/engine/*.asm, OUTDIR/include/*.inc, OUTDIR/<volume>/*.inc
  (e.g. rlmus/) and OUTDIR/xlat_info.json; run by mkproject.py.

Legacy: src/ was translated with it once and has been edited by hand since.
"""
import os, re, sys, json, collections
sys.path.insert(0, os.path.dirname(__file__))
import xasm
from xasm import (Assembler, AsmError, Reg, strip_comment, split_args, TOK, M16, IMM_M, IMM_X,
                  BRANCH, IMPLIED, CPU65_MNEMS, GSU_MNEMS, GSU_IMPL, GSU_BR, GSU_REG, GSU_IMM,
                  parse_secmap, modules_from_smakefile)

# xa macros that are not translated: calls become %NAME(...), asar versions in src/macros.inc
HAND_MACROS = {'halt', 'colourflash', 'haltgsu', 'cacher', 'cacheb', 'cachee', 'cachep',
               'inmac', 'otmac', 'mvmac', 'exmymac', 'memtestmac', 'richjml',
               'date', 'vers', 'vstring', 'verstag'}

# ------------------------------------------------------------------ expressions
class XNode:
    pass

class ExprXlat:
    """parse an xa expression and render it as asar math"""
    PREC = {'|': 1, '!': 1, '^^': 1, '&': 2, '<<': 3, '>>': 3, '+': 4, '-': 4, '*': 5, '/': 5, '%': 5}
    def __init__(self, tr):
        self.tr = tr
    def tokens(self, text):
        toks = []; pos = 0; text = text.strip()
        while pos < len(text):
            m = TOK.match(text, pos)
            if not m or m.end() == pos:
                if text[pos:].strip() == '': break
                raise AsmError('bad expression %r' % text)
            pos = m.end(); k = m.lastgroup; toks.append((k, m.group(k)))
        return toks
    def render(self, text):
        self.toks = self.tokens(text); self.i = 0
        node = self.p_bin(0)
        while self.i < len(self.toks) and self.toks[self.i][1] == ')': self.i += 1
        if self.i != len(self.toks):
            raise AsmError('junk in expr %r' % text)
        return self.out(node)
    def peek(self):
        return self.toks[self.i][1] if self.i < len(self.toks) else None
    def p_bin(self, minp):
        left = self.p_unary()
        while True:
            op = self.peek()
            if op not in self.PREC or self.PREC[op] < minp + (0):
                if op not in self.PREC: break
            p = self.PREC.get(op)
            if p is None or p < minp: break
            self.i += 1
            right = self.p_bin(p + 1)
            left = ('bin', '|' if op == '!' else op, left, right)
        return left
    def p_unary(self):
        t = self.peek()
        if t == '-': self.i += 1; return ('neg', self.p_unary())
        if t == '+': self.i += 1; return self.p_unary()
        if t == '~': self.i += 1; return ('not', self.p_unary())
        if t == '<': self.i += 1; return ('fn', 'lo16', self.p_unary())
        if t == '>': self.i += 1; return ('fn', 'hi16', self.p_unary())
        if t == '^': self.i += 1; return ('fn', 'bank', self.p_unary())
        return self.p_prim()
    def p_prim(self):
        if self.i >= len(self.toks): raise AsmError('unexpected end of expression')
        k, v = self.toks[self.i]; self.i += 1
        if v == '(':
            n = self.p_bin(0)
            if self.peek() == ')': self.i += 1
            return ('paren', n)
        if v == '*':
            if self.peek() == '*' and (self.i + 1 >= len(self.toks) or self.toks[self.i + 1][1] in ('&', '+', '-', ')', '|')):
                self.i += 1
                return ('atom', 'snestopc(realbase())')
            return ('atom', 'pc()')
        if k == 'hex': return ('atom', '$' + v[1:].upper() if len(v) > 1 else v)
        if k == 'bin': return ('atom', v)
        if k == 'dec': return ('atom', str(int(v)))
        if k == 'chr':
            s = v[1:-1].replace("''", "'")
            val = 0
            for ch in s.encode('latin1'): val = (val << 8) | ch     # big-endian like xa
            if len(s) == 1 and s.isalnum():
                return ('atom', "'%s'" % s)
            return ('atom', '$%X' % val)
        if k == 'id':
            return ('atom', self.tr.sym_ref(v))
        raise AsmError('bad token %r' % v)
    def out(self, n, parent_prec=0, right=False):
        t = n[0]
        if t == 'atom': return n[1]
        if t == 'paren':
            inner = n[1]
            if inner[0] in ('atom', 'paren', 'fn'): return self.out(inner)
            return '(' + self.out(inner) + ')'
        if t == 'neg': return '-' + self.wrap(n[1])
        if t == 'not': return '~' + self.wrap(n[1])
        if t == 'fn':
            a = n[2]
            while a[0] == 'paren': a = a[1]
            return '%s(%s)' % (n[1], self.out(a))
        if t == 'bin':
            op = n[1]; p = self.PREC[op]
            l = self.out(n[2], p); r = self.out(n[3], p, True)
            if n[2][0] == 'bin' and self.PREC[n[2][1]] != p: l = '(' + l + ')' if not l.startswith('(') or not self._closed(l) else l
            if n[3][0] == 'bin': r = '(' + r + ')'
            s = l + op + r
            return s
        raise AsmError('bad node')
    def _closed(self, s):
        d = 0
        for k, ch in enumerate(s):
            if ch == '(': d += 1
            elif ch == ')':
                d -= 1
                if d == 0 and k != len(s) - 1: return False
        return True
    def wrap(self, n):
        s = self.out(n)
        if n[0] in ('atom', 'fn') or (n[0] == 'paren'):
            if n[0] == 'paren' and not s.startswith('('): return s
            return s
        return '(' + s + ')'

# ------------------------------------------------------------------ translator
class _NeedMacro(Exception):
    pass

class Translator(Assembler):
    def __init__(self, *a, **k):
        super().__init__(*a, **k)
        self.translating = False
        self.outputs = collections.OrderedDict()   # fname -> list of lines
        self.done_files = set()
        self.canon = {}       # lower -> canonical spelling
        self.varnames = set() # lower names defined with var
        self.regalias = set() # lower names that alias registers
        self.negdefs = set()
        self.xl = ExprXlat(self)
        self.label_counter = 0
        self.secinfo = {}     # section -> attrs
        self.todo = collections.Counter()

    # -------- symbol references
    def sym_ref(self, name):
        low = name.lower()
        if low in xasm.REGS: return low
        if low.startswith('.'):
            return '.' + self.clean(name[1:])
        if low in self.regalias or low in self.varnames or low in self.negdefs:
            # used before this module (re)defines it: xa takes the module's own value
            pm = self.prev_mod.get(self.cur_module)
            if pm and low in pm and low not in self.mod_syms and isinstance(pm[low], xasm.Reg):
                return 'r%d' % pm[low].n
            return '!' + self.canon.get(low, self.clean(name))
        return self.canon.get(low, self.clean(name))
    def clean(self, name):
        n = name.replace('.', '_').replace('@', '_').replace(':', '_C')
        if n and n[0].isdigit(): n = '_' + n
        return n
    def expr(self, text):
        return self.xl.render(text)
    def opexpr(self, text):
        e = self.xl.render(text)
        while e.startswith('(') and self.xl._closed(e):
            e = e[1:-1]
        if e.startswith('('):
            e = '+' + e
        return e
    def numtxt(self, v):
        if v < 0: return '-$%X' % (-v)
        return str(v) if v < 16 else '$%X' % v
    def is_static(self, text):
        try:
            toks = self.xl.tokens(text)
        except AsmError:
            return False
        prev = None
        for i, (k, v) in enumerate(toks):
            if v == '*' and (prev is None or (prev[0] == 'op' and prev[1] != ')')): return False
            prev = (k, v)
            if k == 'id':
                low = v.lower()
                if low in xasm.REGS: continue
                if low not in self.static_syms: return False
        return True

    # -------- output
    def out(self, s):
        if self.translating and self.out_target is not None:
            self.outputs[self.out_target].append(s)

    def fmt(self, label, body, comment):
        lab = ''
        if label:
            lab = label
        line = lab
        if body:
            line = lab + '\t' + body
        if comment:
            line = (line + '\t' if line else '') + comment
        return line.rstrip()

    # -------- file processing with translation hooks
    def process_file(self, fname):
        lines = self.read_lines(fname)
        key = fname.lower()
        prev_target = getattr(self, 'out_target', None)
        if self.translating and key not in self.done_files:
            self.done_files.add(key)
            self.outputs[fname] = []
            self.out_target = fname
            if not fname.lower().endswith('.i'):
                self.out('\tarch 65816')
        else:
            self.out_target = None if self.translating else prev_target
        self.process_lines(lines, fname, 0)
        self.out_target = prev_target

    def process_lines(self, lines, fname, base_line, macro_args=None, ctx=0):
        if not self.translating or macro_args is not None:
            # plain assembly (also used for macro bodies / repeat iterations)
            saved = self.out_target if self.translating else None
            if self.translating and macro_args is not None:
                self.out_target = None
            super().process_lines(lines, fname, base_line, macro_args, ctx)
            if self.translating and macro_args is not None:
                self.out_target = saved
            return
        self._xl_lines(lines, fname, base_line)

    def _xl_lines(self, lines, fname, base_line, force_inactive=False):
        i = 0; n = len(lines)
        cond = []
        state_stack = []
        while i < n:
            raw = lines[i]; lineno = base_line + i + 1; i += 1
            self.cur_file, self.cur_line = fname, lineno
            stripped = raw.strip()
            if not stripped:
                self.out(''); continue
            if raw.startswith('*'):
                self.out(';' + raw[1:]); continue
            if raw.lstrip().startswith(';'):
                self.out(raw.rstrip()); continue
            code = strip_comment(raw).rstrip()
            comment = raw[len(code):].strip() if len(raw) > len(code) else ''
            if comment and not comment.startswith(';'): comment = ''
            try:
                label, mnem, ops = self.split_line(raw)
            except AsmError:
                self.out('; ' + raw); continue
            ml = mnem.lower() if mnem else ''
            active = all(cond) and not force_inactive
            if ml in ('ifn', 'ife', 'ifd', 'ifnd'):
                try:
                    e = self.expr(ops)
                    if ml == 'ifn': t = 'if %s != 0' % e
                    elif ml == 'ife': t = 'if %s == 0' % e
                    else: t = 'if %sdefined("%s")' % ('' if ml == 'ifd' else '!', ops.strip())
                except AsmError as ex:
                    t = 'if 0 ; FIXME %s %s' % (mnem, ops)
                self.out(self.fmt(None, t, comment))
                if active:
                    if ml in ('ifd', 'ifnd'):
                        d = self.lookup(ops.strip()) is not None
                        val = d if ml == 'ifd' else not d
                    else:
                        v = self.ev(ops)
                        if v is None: v = 0
                        val = (v != 0) if ml == 'ifn' else (v == 0)
                    cond.append(val)
                    if not val:
                        state_stack.append(self.save_state())
                else:
                    cond.append(False)
                    state_stack.append(None)
                continue
            if ml in ('endif', 'endc'):
                self.out(self.fmt(None, 'endif', comment))
                if cond:
                    v = cond.pop()
                    if not v:
                        st = state_stack.pop()
                        if st is not None: self.restore_state(st)
                continue
            if ml == 'else':
                self.out(self.fmt(None, 'else', comment)); continue
            if ml == 'macro':
                # swallow the body; the asar macro is hand-written
                name = label
                body = []
                while i < n:
                    l2 = lines[i]; i += 1
                    try:
                        _, m2, _ = self.split_line(l2) if l2.strip() and not l2.startswith(('*', ';')) and not l2.lstrip().startswith(';') else (None, '', '')
                    except AsmError:
                        m2 = ''
                    if m2 and m2.lower() in ('endmac', 'endm'): break
                    body.append(l2)
                self.out('; macro %s -> see src/macros.inc' % name)
                if active:
                    self.macros[label.lower()] = xasm.Macro(label, body, fname)
                continue
            if ml == 'repeat':
                body = []; depth = 1
                while i < n:
                    l2 = lines[i]; i += 1
                    try:
                        _, m2, _ = self.split_line(l2) if l2.strip() and not l2.startswith(('*', ';')) and not l2.lstrip().startswith(';') else (None, '', '')
                    except AsmError:
                        m2 = ''
                    if m2 and m2.lower() == 'repeat': depth += 1
                    if m2 and m2.lower() == 'endrep':
                        depth -= 1
                        if depth == 0: break
                    body.append(l2)
                self.out(self.fmt(None, 'for __rep = 0..%s' % self.expr(ops), comment))
                if active:
                    cnt = self.ev(ops, False)
                    if cnt > 0:
                        self._xl_lines(body, fname, lineno, False)
                        for k in range(cnt - 1):
                            saved = self.out_target; self.out_target = None
                            self._plain_lines(body, fname, lineno)
                            self.out_target = saved
                    else:
                        st = self.save_state()
                        self._xl_lines(body, fname, lineno, True)
                        self.restore_state(st)
                else:
                    self._xl_lines(body, fname, lineno, True)
                self.out('\tendfor')
                continue
            if active:
                self.dec = None
                err = None
                try:
                    self.do_line(label, mnem, ml, ops, fname, lineno, 0)
                except (AsmError, KeyError, TypeError) as e:
                    self.errors.append('%s:%d: %s   [%s]' % (fname, lineno, e, raw.strip()))
                    err = e
                self.cur_file, self.cur_line = fname, lineno
                try:
                    self.translate_line(label, mnem, ml, ops, comment, True, raw)
                except AsmError as e:
                    self.out('; FIXME %s: %s' % (e, raw.strip()))
                    self.todo['active-fail'] += 1
            else:
                # inactive: dry-run the line for its encoding decisions
                self.dec = None
                saved_dry = getattr(self, 'dry', False)
                self.dry = True
                saved_scope = self.scope
                try:
                    if ml in ('equ', 'var', 'set', '='):
                        pass
                    elif ml in ('mode', 'dbr', 'dpr', 'cpu', 'pushmode', 'popmode'):
                        getattr(self, 'd_' + ml)(ops)
                    elif self.sec is not None and ml not in HAND_MACROS:
                        if self.cpu == 'sfx' and ml in GSU_MNEMS: self.gsu(ml, ops)
                        elif ml in CPU65_MNEMS: self.c65(ml, ops)
                except Exception:
                    self.dec = None
                self.dry = saved_dry
                self.scope = saved_scope
                try:
                    self.translate_line(label, mnem, ml, ops, comment, False, raw)
                except AsmError as e:
                    self.out('; FIXME %s: %s' % (e, raw.strip()))
                    self.todo['inactive-fail'] += 1

    def _plain_lines(self, body, fname, lineno):
        tr = self.translating
        self.translating = False
        try:
            xasm.Assembler.process_lines(self, body, fname, lineno)
        finally:
            self.translating = tr

    def save_state(self):
        return (self.mflag, self.xflag, self.dbr, self.dpr, self.cpu, list(self.mode_stack))
    def restore_state(self, st):
        self.mflag, self.xflag, self.dbr, self.dpr, self.cpu, ms = st
        self.mode_stack = ms

    # -------- line translation
    def label_text(self, label):
        if label is None: return None
        if label.startswith('.'): return '.' + self.clean(label[1:]) + ':'
        return self.canon.get(label.lower(), self.clean(label)) + ':'

    def translate_line(self, label, mnem, ml, ops, comment, active, raw):
        lab = self.label_text(label) if label and ml not in ('equ', 'var', 'set', '=', 'macro') else None
        if not mnem:
            self.out(self.fmt(lab, '', comment)); return
        # ---- symbol definitions
        if ml in ('equ', '=', 'var', 'set'):
            low = label.lower()
            isvar = ml in ('var', 'set')
            if label.endswith(':'):
                self.out('; ' + raw.strip()); return
            try:
                v = self.ev(ops) if active else None
            except AsmError:
                v = None
            name = self.canon.get(low, self.clean(label))
            if isinstance(v, Reg) or (re.fullmatch(r'r\d+', ops.strip(), re.I)) or low in self.regalias:
                self.regalias.add(low)
                self.out(self.fmt(None, '!%s = %s' % (name, self.expr(ops)), comment))
                return
            if isvar: self.varnames.add(low)
            xe = self.expr(ops)
            static = self.is_static(ops)
            if active and not isvar and low in self.emitted_equ and low not in self.negdefs:
                self.out(self.fmt(None, '; (dup) %s = %s' % (name, xe), comment)); return
            if static:
                if isvar:
                    self.static_syms.add(low)
                    self.out(self.fmt(None, '!%s #= %s' % (name, xe), comment))
                elif low in self.negdefs:
                    self.static_syms.add(low)
                    if active: self.emitted_equ.add(low)
                    self.out(self.fmt(None, '!%s = (%s)' % (name, xe), comment))
                else:
                    self.static_syms.add(low)
                    if active: self.emitted_equ.add(low)
                    self.out(self.fmt(None, '%s = %s' % (name, xe), comment))
                return
            # derived from positional labels / forward references:
            # cache the value as a number and verify it with an assert
            if v is None or not isinstance(v, int):
                self.todo['dynamic-unknown'] += 1
                if isvar:
                    self.out(self.fmt(None, '!%s = (%s)' % (name, xe), comment))
                else:
                    self.emitted_equ.add(low)
                    self.out(self.fmt(None, '%s = %s\t; FIXME non-static' % (name, xe), comment))
                return
            num = self.numtxt(v)
            self.todo['dynamic-cached'] += 1
            if isvar or low in self.negdefs:
                self.static_syms.add(low)
                if not isvar: self.emitted_equ.add(low)
                self.out('\tassert (%s&$FFFFFF) == ((%s)&$FFFFFF), "cached constant %s is stale (tools/fixup.py)"' % (num, xe, name))
                self.out(self.fmt(None, ('!%s = (%s)' if v < 0 else '!%s #= %s') % (name, num), comment))
            else:
                self.static_syms.add(low)
                if active: self.emitted_equ.add(low)
                self.out(self.fmt(None, '%s = %s' % (name, num), comment))
                self.out('\tassert (%s&$FFFFFF) == ((%s)&$FFFFFF), "cached constant %s is stale (tools/fixup.py)"' % (name, xe, name))
            return
        # ---- macros
        if ml in HAND_MACROS or ml in self.macros:
            args = split_args(ops)
            xargs = []
            for a in args:
                a2 = a.strip()
                if ml in ('halt', 'haltgsu'):
                    a2 = a2.lstrip('#')
                if ml in ('exmymac', 'cacheb', 'cachee', 'cachep', 'inmac', 'otmac'):
                    xargs.append(self.canon.get(a2.lower(), self.clean(a2)) if re.fullmatch(r'[A-Za-z_.][\w.]*', a2) else self.expr(a2))
                else:
                    xargs.append(self.expr(a2))
            self.out(self.fmt(lab, '%%%s(%s)' % (mnem.upper() if ml != 'inmac' and ml != 'otmac' and ml != 'mvmac' else mnem, ', '.join(xargs)), comment))
            return
        # ---- directives
        h = getattr(self, 'x_' + ml.replace('.', '_'), None)
        if h:
            body = h(ops, active)
            if body is None: body = ''
            if isinstance(body, list):
                if lab: self.out(lab)
                for b in body: self.out('\t' + b)
                if comment: self.out('\t' + comment)
                return
            self.out(self.fmt(lab, body, comment)); return
        # ---- instructions
        cpu = self.cpu
        if active and self.sec is not None:
            self.code_secs.add(self.sec.name)
        if cpu == 'sfx' and ml in GSU_MNEMS:
            body = self.xl_gsu(ml, ops, active)
        elif ml in CPU65_MNEMS:
            body = self.xl_65(ml, ops, active)
        else:
            raise AsmError('cannot translate %s' % mnem)
        if isinstance(body, list):
            if lab: self.out(lab)
            for b in body: self.out('\t' + b)
            if comment: self.out('\t' + comment)
            return
        self.out(self.fmt(lab, body, comment))

    # -------- directive translators
    def x_include(self, ops, active):
        f = ops.strip().strip('"')
        if ':' in f:
            vol, rest = f.split(':', 1)
            return 'incsrc "src/%s/%s"' % (vol.lower(), os.path.splitext(rest)[0] + '.inc')
        base = self.files.get(f.lower(), f)
        return 'incsrc "src/include/%s"' % (os.path.splitext(base)[0].lower() + '.inc')
    def x_section(self, ops, active):
        parts = split_args(ops)
        name = parts[0]
        attrs = parts[1:]
        info = self.secinfo.setdefault(name, {})
        for p in attrs:
            if '=' in p:
                k, v = p.split('=', 1); info[k.strip().upper()] = v.strip()
            else: info[p.strip().upper()] = True
        return '%%section(%s)' % self.clean(name)
    def x_cpu(self, ops, active):
        return 'arch superfx' if ops.strip().lower() == 'sfx' else 'arch 65816'
    def x_mode(self, ops, active):
        s = ops.strip().strip("'\"")
        if '!' not in s: return '; mode \'%s\'' % s
        seps = 0; reps = 0; native = False
        j = 0
        while j < len(s):
            c = s[j]
            if c == '@': j += 1
            elif c == 'A': reps |= 0x20
            elif c == 'a': seps |= 0x20
            elif c == 'X': reps |= 0x10
            elif c == 'x': seps |= 0x10
            elif c == 'E': native = True
            j += 1
        out = []
        if native: out += ['clc', 'xce']
        if seps: out.append('sep #$%02X' % seps)
        if reps: out.append('rep #$%02X' % reps)
        out[-1] += "\t\t; mode '%s'" % s
        return out
    def x_dbr(self, ops, active): return '; dbr %s' % ops.strip()
    def x_dpr(self, ops, active): return '; dpr %s' % ops.strip()
    def x_pushmode(self, ops, active): return '; pushmode'
    def x_popmode(self, ops, active): return '; popmode'
    def x_globals(self, ops, active): return '; globals %s' % ops
    def x_public(self, ops, active): return '; public %s' % ops
    def x_extern(self, ops, active): return '; extern %s' % ops
    def x_xref(self, ops, active): return '; xref %s' % ops
    def x_plist(self, ops, active): return '; plist %s' % ops
    def x_mmu(self, ops, active): return '; mmu %s' % ops
    def x_cpudata(self, ops, active): return '; cpudata'
    def x_dump(self, ops, active): return '; dump %s' % ops
    def x_end(self, ops, active): return '; end'
    def x_org(self, ops, active):
        return 'base %s' % self.expr(ops)
    def x_load(self, ops, active):
        return '; load %s' % ops.strip()
    def x_reorg(self, ops, active):
        return '; reorg (unsupported)'
    def x_align(self, ops, active):
        a = split_args(ops)
        if active and self.dec and 'pad' in self.dec:
            pad = self.dec['pad']
            return '%%align_pad(%d, %s, %s)\t; align %s' % (pad, self.expr(a[0]), self.expr(a[1]) if len(a) > 1 else '0', ops.strip())
        self.todo['inactive-align'] += 1
        return '%%align_pad(0, %s, %s)\t; align %s  (inactive: pad unknown)' % (self.expr(a[0]), self.expr(a[1]) if len(a) > 1 else '0', ops.strip())
    def x_text(self, ops, active): return self.x_ltext(ops, active)
    def x_ltext(self, ops, active):
        a = split_args(ops)
        if not a: return ''
        if a[0].startswith('"'):
            return '; ltext %s' % ops.strip()
        try:
            c = self.expr(a[0])
        except AsmError:
            return '; ltext %s' % ops.strip()
        msg = a[1] if len(a) > 1 else '"check"'
        msg = re.sub(r'\$?%0?\d*l?[xd]', '?', msg)
        return 'assert %s == 0, %s' % (c, msg)
    def data_list(self, ops, size):
        items = []
        for a in split_args(ops):
            a = a.strip()
            if a.startswith('"') or (a.startswith("'") and a.endswith("'") and size == 1 and (len(a) > 3 or len(a) == 2)):
                s = a[1:-1].replace("''", "'")
                if s == '':
                    continue
                items.append('"%s"' % s.replace('"', '""') if '"' not in s else ','.join('$%02X' % ord(c) for c in s))
            elif a.startswith("'") and a.endswith("'") and size > 1 and len(a) - 2 == size:
                # a full-width string in word/dc.w data is stored in text order
                items.append('$%X' % int.from_bytes(a[1:-1].encode('latin1'), 'little'))
            else:
                items.append(self.expr(a.lstrip('#')))
        return ','.join(items)
    def in_ram(self):
        s = self.sec
        return s is not None and s.load is not None and s.load < 0x80000000
    def x_dc_b(self, ops, active):
        if self.in_ram(): return '%%ds(%d)\t; dc.b %s' % (len(self.data_items(ops, 1)), ops)
        return 'db %s' % self.data_list(ops, 1)
    def x_dc_w(self, ops, active):
        if self.in_ram(): return '%%ds(%d)\t; dc.w %s' % (len(split_args(ops))*2, ops)
        return 'dw %s' % self.data_list(ops, 2)
    def x_word(self, ops, active):
        if self.in_ram(): return '%%ds(%d)\t; word %s' % (len(split_args(ops))*2, ops)
        return 'dw %s' % self.data_list(ops, 2)
    def x_dc_l(self, ops, active):
        if self.in_ram(): return '%%ds(%d)\t; dc.l %s' % (len(split_args(ops))*3, ops)
        return 'dl %s' % self.data_list(ops, 3)
    def x_dc_4(self, ops, active):
        if self.in_ram(): return '%%ds(%d)\t; dc.4 %s' % (len(split_args(ops))*4, ops)
        return 'dd %s' % self.data_list(ops, 4)
    def dcb_x(self, ops, d):
        a = split_args(ops)
        n = self.expr(a[0]); v = self.expr(a[1]) if len(a) > 1 else '0'
        if re.fullmatch(r'\d+', n) and int(n) <= 8:
            return '%s %s' % (d, ','.join([v] * int(n)))
        return ['for __i = 0..%s' % n, '\t%s %s' % (d, v), 'endfor']
    def x_dcb_b(self, ops, active): return self.dcb_x(ops, 'db')
    def x_dcb_w(self, ops, active): return self.dcb_x(ops, 'dw')
    def x_dcb_l(self, ops, active): return self.dcb_x(ops, 'dl')
    def ds_x(self, ops, size):
        e = self.expr(ops)
        if not self.is_static(ops):
            try: v = self.ev(ops)
            except Exception: v = None
            if isinstance(v, int):
                n = v * size
                return ['%%ds(%s)\t; ds.%s %s' % (self.numtxt(n), {1:'b',2:'w',3:'l',4:'4'}[size], ops.strip()),
                        'assert %s == %s, "cached ds size is stale (tools/fixup.py)"' % (self.numtxt(v), e)]
            self.todo['ds-dynamic-unknown'] += 1
        if size != 1: e = '(%s)*%d' % (e, size) if not re.fullmatch(r'[\w$]+', e) else '%s*%d' % (e, size)
        return '%%ds(%s)' % e
    def x_ds_b(self, ops, active): return self.ds_x(ops, 1)
    def x_ds_w(self, ops, active): return self.ds_x(ops, 2)
    def x_ds_l(self, ops, active): return self.ds_x(ops, 3)
    def x_ds_4(self, ops, active): return self.ds_x(ops, 4)
    def x_image(self, ops, active):
        a = split_args(ops)
        p = a[0].strip()
        if ':' in p:
            vol, rest = p.split(':', 1)
            path = 'data/%s/%s' % (vol.upper(), rest)
        else:
            path = 'data/SRC/%s' % self.files.get(p.lower(), p)
        if len(a) == 1:
            return 'incbin "%s"' % path
        off = self.expr(a[1])
        if len(a) == 2:
            return 'incbin "%s":%s..filesize("%s")' % (path, off, path)
        ln = self.expr(a[2])
        end = '%s+%s' % (off, ln) if off != '0' else ln
        return 'incbin "%s":%s..%s' % (path, off, end)

    # -------- instruction translators
    def xl_65(self, ml, ops, active):
        o = ops.strip()
        d = self.dec or {}
        if ml in IMPLIED: return ml
        if ml in BRANCH:
            m = {'blt': 'bcc', 'bge': 'bcs'}.get(ml, ml)
            pm = re.fullmatch(r'\*\s*([+-])\s*(\d+)', o)
            if pm:
                n = int(pm.group(2)) * (1 if pm.group(1) == '+' else -1)
                return 'db $%02X,$%02X\t; %s %s' % (BRANCH[ml], n & 0xFF, ml, o)   # xa: '*' in a branch = address after it
            return '%s %s' % (m, self.branch_target(o))
        if ml == 'brl': return 'brl %s' % self.branch_target(o)
        if ml in ('rep', 'sep'): return '%s #%s' % (ml, self.expr(o.lstrip('#')))
        if ml in ('brk', 'cop', 'wdm'):
            return '%s #%s' % (ml, self.expr(o.lstrip('#'))) if o else ml + ' #$00'
        if ml == 'pea':
            return 'pea.w %s' % self.expr(o.lstrip('#'))
        if ml in ('mvn', 'mvp'):
            a = split_args(o)
            if len(a) == 1:
                e = a[0].lstrip('#')
                m = re.fullmatch(r'\(\s*\(\s*(\^.*?)\s*<<\s*8\s*\)\s*\+\s*\(?\s*(\^[^)]*?)\s*\)?\s*\)', e)
                if m:
                    # asar operand order is destination,source
                    return '%s %s,%s\t; src,dst = %s,%s' % (ml, self.expr(m.group(2)), self.expr(m.group(1)), m.group(1), m.group(2))
                x = self.expr(e)
                return 'db $%02X,(%s)&$FF,((%s)>>8)&$FF\t; %s %s' % (0x54 if ml == 'mvn' else 0x44, x, x, ml, o)
            return '%s %s,%s' % (ml, self.expr(a[0].lstrip('#')), self.expr(a[1].lstrip('#')))
        if ml in ('jsl', 'jml'):
            if o.startswith('['): return '%s [%s]' % ('jml', self.expr(o[1:-1]))
            b = o[1:] if o.startswith('>') else o
            return '%s.l %s' % (ml, self.opexpr(b))
        if ml in ('jmp', 'jsr'):
            if o.startswith('(') and self._outer_paren(o):
                inner = o[1:-1]
                m = re.match(r'^(.*),\s*[xX]$', inner)
                if m: return '%s.w (%s,x)' % (ml, self.expr(m.group(1)))
                return '%s.w (%s)' % (ml, self.expr(inner))
            if o.startswith('['): return 'jml [%s]' % self.expr(o[1:-1])
            if o.startswith('>'):
                return '%s.l %s' % ('jml' if ml == 'jmp' else 'jsl', self.opexpr(o[1:]))
            b = o[1:] if o.startswith('!') else o
            return '%s.w %s' % (ml, self.opexpr(b))
        tab = M16[ml]
        if o == '' or o.lower() == 'a':
            return '%s a' % ml
        if o.startswith('#'):
            sz = d.get('imm')
            if sz is None:
                f = self.mflag if ml in IMM_M else (self.xflag if ml in IMM_X else 8)
                sz = 1 if f == 8 else 2
            return '%s.%s #%s' % (ml, 'b' if sz == 1 else 'w', self.expr(o[1:]))
        idx = None
        o = re.sub(r',\s*[sS][pP]$', ',s', o)
        m = re.match(r'^(.*),\s*([xXyYsS])$', o)
        body = o
        if m:
            body, idx = m.group(1).strip(), m.group(2).lower()
        sfx = (',' + idx) if idx else ''
        if body.startswith('[') and body.endswith(']'):
            return '%s.b [%s]%s' % (ml, self.dp_expr(body[1:-1]), sfx)
        if body.startswith('(') and self._outer_paren(body) and 'ind' in tab:
            inner = body[1:-1].strip()
            m2 = re.match(r'^(.*),\s*([xXsS])$', inner)
            if m2:
                if m2.group(2).lower() == 's':
                    return '%s.b (%s,s)%s' % (ml, self.expr(m2.group(1)), sfx)
                return '%s.b (%s,x)' % (ml, self.dp_expr(m2.group(1)))
            return '%s.b (%s)%s' % (ml, self.dp_expr(inner), sfx)
        if idx == 's':
            return '%s.b %s,s' % (ml, self.expr(body))
        force = None
        if body[:1] in '<!>' and not body.startswith('<<'):
            force = body[0]; body = body[1:].strip()
        mode = d.get('addr')
        if mode is None:
            try:
                v = self.ev(body)
            except Exception:
                v = None
            mode = self.choose_addr(ml, tab, v, force, idx)
            if not active: self.todo['inactive-addr'] += 1
        if mode.startswith('dp'):
            return '%s.b %s%s' % (ml, self.dp_expr(body, True), sfx)
        if mode.startswith('abs'):
            return '%s.w %s%s' % (ml, self.opexpr(body), sfx)
        return '%s.l %s%s' % (ml, self.opexpr(body), sfx)

    def dp_expr(self, body, plain=False):
        e = self.opexpr(body) if plain else self.expr(body)
        if self.dpr:
            e = '%s-%s' % ('(' + e + ')' if not re.fullmatch(r'[\w!.$]+', e) else e, self.dpr_text())
            if plain and e.startswith('('): e = '+' + e
        return e
    def dpr_text(self):
        return self.cur_dpr_text or ('$%X' % self.dpr)

    def branch_target(self, o):
        if '*' in o and re.search(r'(^|[^\w)])\*', o):
            # '*'-relative target ("*+5"): pc() math
            return '%s' % self.expr(o).replace('pc()', 'pc()')
        return self.expr(o)

    def xl_gsu(self, ml, ops, active):
        o = ops.strip(); d = self.dec or {}
        if ml in GSU_IMPL and not o: return ml
        if ml in GSU_BR:
            pm = re.fullmatch(r'\*\s*([+-])\s*(\d+)', o)
            if pm:
                n = int(pm.group(2)) * (1 if pm.group(1) == '+' else -1)
                return 'db $%02X,$%02X\t; %s %s' % (GSU_BR[ml], n & 0xFF, ml, o)   # xa: '*' in a branch = address after it
            return '%s %s' % (ml, self.branch_target(o))
        a = split_args(o)
        if ml == 'move' or ml == 'moves':
            dst, src = a[0].strip(), a[1].strip()
            if ml == 'moves':
                return 'moves %s,%s' % (self.expr(dst), self.expr(src))
            if src.startswith('#'):
                form = d.get('gform')
                if form is None:
                    try: v = self.ev(src[1:])
                    except Exception: v = None
                    form = self.gsu_imm_kind(v)
                return '%s %s,#%s' % (form, self.expr(dst), self.expr(src[1:]))
            if src.startswith('(') and self._outer_paren(src) and not self._is_reg_text(src[1:-1]):
                form = d.get('gform') or self.guess_lm(src[1:-1], 'lms', 'lm')
                try:
                    return '%s %s,(%s)' % (form, self.expr(dst), self.gsu_addr(src[1:-1], form))
                except _NeedMacro as nm:
                    return '%%%s(%s, %s)' % (form.upper(), self.expr(dst), nm.args[0])
            if dst.startswith('(') and self._outer_paren(dst) and not self._is_reg_text(dst[1:-1]):
                form = d.get('gform') or self.guess_lm(dst[1:-1], 'sms', 'sm')
                try:
                    return '%s (%s),%s' % (form, self.gsu_addr(dst[1:-1], form), self.expr(src))
                except _NeedMacro as nm:
                    return '%%%s(%s, %s)' % (form.upper(), self.expr(src), nm.args[0])
            return 'move %s,%s' % (self.expr(dst), self.expr(src))
        if ml in ('ibt', 'ibtx'):
            return 'ibt %s,#%s' % (self.expr(a[0]), self.expr(a[1].lstrip('#')))
        if ml in ('iwt', 'lea'):
            return 'iwt %s,#%s' % (self.expr(a[0]), self.expr(a[1].lstrip('#')))
        if ml in ('lm', 'lms'):
            return '%s %s,(%s)' % (ml, self.expr(a[0]), self.gsu_addr(a[1].strip()[1:-1], ml))
        if ml in ('sm', 'sms'):
            return '%s (%s),%s' % (ml, self.gsu_addr(a[0].strip()[1:-1], ml), self.expr(a[1]))
        if ml == 'link':
            return 'link #%s' % self.literal(o.lstrip('#'))
        if ml in ('ldw', 'ldb', 'stw', 'stb'):
            return '%s (%s)' % (ml, self.expr(o.strip()[1:-1]))
        if o.startswith('#') and ml in GSU_IMM:
            inner = o[1:].strip()
            if re.fullmatch(r'\d+', inner):
                return '%s #%s' % (ml, int(inner))
            return '%%%s_i(%s)' % (ml, self.expr(inner))
        if ml in GSU_REG:
            return '%s %s' % (ml, self.expr(o))
        raise AsmError('bad gsu %s %s' % (ml, ops))

    def literal(self, t):
        if re.fullmatch(r'\d+', t.strip()): return str(int(t))
        v = self.ev(t)
        return str(v)

    def gsu_addr(self, t, form):
        e = self.expr(t)
        if e.startswith('lo16(') and e.endswith(')') and self._closed(e[4:]):
            e = e[5:-1]
        if '(' in e:
            raise _NeedMacro(e)
        return e + '&$FFFF'
    def _closed(self, s):
        d = 0
        for k, ch in enumerate(s):
            if ch == '(': d += 1
            elif ch == ')':
                d -= 1
                if d == 0 and k != len(s) - 1: return False
        return True

    def guess_lm(self, t, short, long_):
        try: v = self.ev(t)
        except Exception: v = None
        if v is None: return long_
        a = v & 0xFFFF
        return short if a <= 0x1FE and not a & 1 else long_

    def _is_reg_text(self, t):
        try: v = self.ev(t)
        except Exception: v = None
        if isinstance(v, Reg): return True
        return re.fullmatch(r'r\d+', t.strip(), re.I) is not None or t.strip().lower() in self.regalias

    def d_include(self, ops):
        f = ops.strip().strip('"')
        if ':' in f and self.translating:
            prev = self.out_target
            key = f
            if key.lower() not in self.done_files:
                self.done_files.add(key.lower()); self.outputs[key] = []; self.out_target = key
            else:
                self.out_target = None
            vol, rest = f.split(':', 1)
            path = os.path.join(self.datadir, vol.upper(), rest)
            with open(path, encoding='latin1') as fh:
                lines = [l.rstrip('\r\n') for l in fh]
            save = (self.cur_file, self.cur_line)
            self._xl_lines(lines, f, 0)
            self.cur_file, self.cur_line = save
            self.out_target = prev
            return
        super().d_include(ops)

    # -------- dpr text tracking (for dp offset expressions)
    def d_dpr(self, ops):
        o = ops.strip()
        super().d_dpr(ops)
        self.cur_dpr_text = None if o in ('?', '0') else self.expr(o)

    def assemble_module(self, fname):
        self.cur_dpr_text = None
        super().assemble_module(fname)


def main():
    import argparse, pickle
    ap = argparse.ArgumentParser()
    ap.add_argument('srcdir'); ap.add_argument('datadir'); ap.add_argument('outdir')
    a = ap.parse_args()
    secmap = parse_secmap(os.path.join(a.srcdir, 'RL.SEC'))
    T = Translator(a.srcdir, a.datadir, secmap, {}, True)
    T.errors = []
    mods = modules_from_smakefile(a.srcdir)
    # pass 1..n: plain reference assembly to get symbol values
    T.assemble(mods)
    # canonical spelling of a symbol: its most common spelling at a line start
    import collections as C
    defs = T.defs
    cnt = C.defaultdict(C.Counter)
    kinds = C.defaultdict(set)
    for m, f, ln, n, k, v in defs:
        kinds[n].add(k)
    for f, lines in T.cache_lines.items():
        for l in lines:
            m = re.match(r'^([A-Za-z_][A-Za-z0-9_.@]*)', l)
            if m: cnt[m.group(1).lower()][m.group(1)] += 1
    for low, c in cnt.items():
        T.canon[low] = T.clean(c.most_common(1)[0][0])
    T.varnames = {n for n, k in kinds.items() if 'var' in k}
    gs = T.gsyms
    T.negdefs = {n for n, v in gs.items() if isinstance(v, int) and v < 0}
    T.emitted_equ = set()
    T.code_secs = set()
    T.static_syms = set()
    # translation pass
    T.translating = True
    T.out_target = None
    T.recording = True; T.records = []; T.listing = []; T.defs = []
    T.run_pass(mods)
    os.makedirs(os.path.join(a.outdir, 'engine'), exist_ok=True)
    os.makedirs(os.path.join(a.outdir, 'include'), exist_ok=True)
    for fname, lines in T.outputs.items():
        base, ext = os.path.splitext(fname)
        if ':' in fname:
            vol, rest = fname.split(':', 1)
            os.makedirs(os.path.join(a.outdir, vol.lower()), exist_ok=True)
            path = os.path.join(a.outdir, vol.lower(), os.path.splitext(rest)[0] + '.inc')
            lines = ['includeonce'] + lines
        elif ext.lower() == '.i':
            path = os.path.join(a.outdir, 'include', base.lower() + '.inc')
            lines = ['includeonce'] + lines
        else:
            path = os.path.join(a.outdir, 'engine', base.lower() + '.asm')
        with open(path, 'w') as f:
            f.write('\n'.join(lines) + '\n')
    json.dump({'sections': T.secinfo, 'modules': mods, 'order': T.section_order,
               'placement': {n: [T.sections[n].load, T.sections[n].org] for n in T.section_order},
               'code': sorted(T.code_secs)},
              open(os.path.join(a.outdir, 'xlat_info.json'), 'w'), indent=1)
    print('files', len(T.outputs), 'errors', len(T.errors), 'todo', dict(T.todo))
    for e in T.errors[:30]: print('E', e)

if __name__ == '__main__':
    main()
