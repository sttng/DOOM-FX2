#!/usr/bin/env python3
"""
dettest.py - deterministic gameplay test in MesenCE (headless `mesenrun`).

The engine runs with a variable time step (FPSCount = VBlanks per rendered
frame), so two builds that render at different speeds play differently.
This harness pins the time step: every write of FPSCount is forced to 3
(20 fps) and VBlankTotal advances by exactly 3 per rendered frame.  After
the game has started, controller input is applied per *rendered* frame.
For every rendered frame it records a hash of the game state (objects,
sectors), the player's position, angle and health, so two builds (e.g.
before/after an engine refactor) can be compared exactly, independent of
their speed.

usage: dettest.py ROM --out DIR [--frames N] [--input SCRIPT] [--sym SYM] [...]  (see --help)
       dettest.py --compare DIR_A DIR_B   (exit 0 same, 1 different, 2 same but not as long)
input script: "<f>:<buttons>[@hold]" entries separated by ';', buttons a comma list
of a,b,x,y,l,r,start,select,up,down,left,right ('-' releases all; "@n" holds them n
frames).  Before the first rendered frame <f> counts emulated frames (menus),
afterwards "r<f>:..." entries count rendered frames.
Writes DIR/det.json (per rendered frame: rendered, emulated frame, hash, x, y,
angle, health), gsuram.bin and wram.bin after N rendered frames; if they are
not reached within N*8+3000 emulated frames, det.json so far and shot_end.png.
"""
import os, sys, re, json, argparse, subprocess

def load_syms(path):
    syms = {}; sec = None
    for l in open(path):
        l = l.strip()
        if l.startswith('['): sec = l; continue
        if sec != '[labels]': continue
        m = re.match(r'([0-9a-fA-F]{2}):([0-9a-fA-F]{4}) (\S+)$', l)
        if m: syms[m.group(3)] = int(m.group(1) + m.group(2), 16)
    return syms

def parse_input(spec):
    ev = {'f': [], 'r': []}
    for part in filter(None, (spec or '').split(';')):
        f, b = part.split(':', 1)
        k = 'r' if f.startswith('r') else 'f'
        f = int(f.lstrip('r'))
        hold = None
        if '@' in b: b, hold = b.split('@'); hold = int(hold)
        btn = [] if b == '-' else b.split(',')
        ev[k].append((f, btn))
        if hold: ev[k].append((f + hold, []))
    return ev

LUA = r'''
local frame = 0
local rendered = 0
local out = "%(out)s/"
local finputs = {%(finputs)s}
local rinputs = {%(rinputs)s}
local cur = {}
local mcur = {}
local minputs = {%(minputs)s}
local mport = %(mport)d
local shots = {%(shots)s}
local menus = {%(menus)s}
local dumps = {%(dumps)s}
local function dumpgsu(name)
  local t = {}
  for a = 0, 0x1FFFF do t[#t+1] = string.char(emu.read(a, emu.memType.gsuWorkRam)) end
  local g = io.open(out .. "gsuram_" .. name .. ".bin", "wb"); g:write(table.concat(t)); g:close()
end
local execdumps = {%(execdumps)s}
local execn = {}
for name, addr in pairs(execdumps) do
  execn[name] = 0
  emu.addMemoryCallback(function()
    execn[name] = execn[name] + 1
    dumpgsu(name .. execn[name])
  end, emu.callbackType.exec, addr, addr, emu.cpuType.snes, emu.memType.snesMemory)
end
local mseq = nil
local mstart = 0
local pending = nil
local log = {}
local MOBJ, NMOBJ, SECD, NSEC = %(mobj)d, %(nmobj)d, %(secd)d, %(nsec)d
local function r8(a) return emu.read(a, emu.memType.gsuWorkRam) end
local function hashfb()
  -- game state: every movable object (type, X, Y, Z, angle, health) and every
  -- sector (light, floor, ceiling); independent of RAM/ROM layout and speed
  local h = 0
  for i = 0, NMOBJ - 1 do
    local o = MOBJ + i * 38
    for _, f in ipairs({5, 8, 9, 12, 13, 14, 15, 20, 21, 32, 33}) do h = (h * 31 + r8(o + f)) %% 4294967291 end
  end
  for i = 0, NSEC - 1 do
    local s = SECD + i * 14
    for _, f in ipairs({1, 2, 3, 4, 5}) do h = (h * 31 + r8(s + f)) %% 4294967291 end
  end
  return h
end
local function rw(a) return emu.read(a, emu.memType.gsuWorkRam) + emu.read(a + 1, emu.memType.gsuWorkRam) * 256 end
emu.addMemoryCallback(function(addr, value)
  -- (addr & $FFFF: Mesen passes the CPU address, e.g. $01:06FE through a WRAM mirror,
  --  MesenCE the WRAM offset; FPSCount/VBlankTotal are below $2000)
  if (addr & 0xFFFF) == %(fps)d then return 3 end
  return 0
end, emu.callbackType.write, %(fps)d, %(fps)d + 1, emu.cpuType.snes, emu.memType.snesWorkRam)
emu.addMemoryCallback(function(addr, value)
  return (rendered * 3) %% 256
end, emu.callbackType.write, %(vbt)d, %(vbt)d, emu.cpuType.snes, emu.memType.snesWorkRam)
if %(level)d >= 0 then
  local function forcelvl(addr, value)
    if rendered == 0 then
      if (addr & 0xFFFF) == %(lvl)d then return %(level)d end
      return 0
    end
  end
  emu.addMemoryCallback(forcelvl, emu.callbackType.write, %(lvl)d, %(lvl)d + 1, emu.cpuType.snes, emu.memType.snesWorkRam)
  emu.addMemoryCallback(forcelvl, emu.callbackType.read, %(lvl)d, %(lvl)d + 1, emu.cpuType.snes, emu.memType.snesWorkRam)
end
if %(skill)d >= 0 then
  emu.addMemoryCallback(function(addr, value)
    if rendered == 0 then
      if (addr & 0xFFFF) == %(skilladdr)d then return %(skill)d end
      return 0
    end
  end, emu.callbackType.write, %(skilladdr)d, %(skilladdr)d + 1, emu.cpuType.snes, emu.memType.snesWorkRam)
  emu.addMemoryCallback(function(addr, value)
    if (addr & 0xFFFF) == %(skilladdr)d then return %(skill)d end
    return 0
  end, emu.callbackType.read, %(skilladdr)d, %(skilladdr)d + 1, emu.cpuType.snes, emu.memType.snesWorkRam)
end
emu.addMemoryCallback(function(addr, value)
  if value ~= 0 then
    rendered = rendered + 1
    if rinputs[rendered] ~= nil then cur = rinputs[rendered] end
    if minputs[rendered] ~= nil then mcur = minputs[rendered] end
    if shots[rendered] then pending = rendered end
    if menus[rendered] ~= nil then mseq = menus[rendered]; mstart = frame + 1; cur = {} end
    if dumps[rendered] then
      local t = {}
      for a = 0, 0x1FFFF do t[#t+1] = string.char(emu.read(a, emu.memType.gsuWorkRam)) end
      local g = io.open(out .. string.format("gsuram_%%04d.bin", rendered), "wb"); g:write(table.concat(t)); g:close()
    end
    local p = rw(%(pobj)d)
    log[#log + 1] = string.format('[%%d,%%d,%%d,%%d,%%d,%%d,%%d]', rendered, frame, hashfb(), rw(p + %(ox)d), rw(p + %(oy)d), rw(p + %(oa)d), rw(%(health)d))
    if rendered == %(nframes)d then
      local f = io.open(out .. "det.json", "w"); f:write('[' .. table.concat(log, ',\n') .. ']'); f:close()
      local t = {}
      for a = 0, 0x1FFFF do t[#t+1] = string.char(emu.read(a, emu.memType.gsuWorkRam)) end
      local g = io.open(out .. "gsuram.bin", "wb"); g:write(table.concat(t)); g:close()
      local w = {}
      for a = 0, 0x1FFFF do w[#w+1] = string.char(emu.read(a, emu.memType.snesWorkRam)) end
      local h = io.open(out .. "wram.bin", "wb"); h:write(table.concat(w)); h:close()
      dumpprof()
      dumpwatch()
      emu.stop(0)
    end
  end
end, emu.callbackType.write, %(framedone)d, %(framedone)d, emu.cpuType.snes, emu.memType.snesWorkRam)
watch = {%(watch)s}
wmax = {}
for _, a in ipairs(watch) do
  wmax[a] = 0
  emu.addMemoryCallback(function(addr, value)
    local w = emu.read(a, emu.memType.gsuWorkRam) + value * 256
    if w > wmax[a] then wmax[a] = w end
  end, emu.callbackType.write, a + 1, a + 1, emu.cpuType.gsu, emu.memType.gsuWorkRam)
end
function dumpwatch()
  if #watch == 0 then return end
  local f = io.open(out .. "watch.txt", "w")
  for _, a in ipairs(watch) do f:write(string.format("%%04X %%04X\n", a, wmax[a])) end
  f:close()
end
prof = %(prof)s
pcnt = {}
if prof then
  emu.addMemoryCallback(function(addr, value)
    if rendered >= %(pfrom)d then local k = addr & 0xFFFFFF; pcnt[k] = (pcnt[k] or 0) + 1 end
  end, emu.callbackType.exec, 0, 0xFFFFFF, emu.cpuType.gsu, emu.memType.gsuMemory)
end
function dumpprof()
  if not prof then return end
  local f = io.open(out .. "prof.txt", "w")
  for k, v in pairs(pcnt) do f:write(string.format("%%06X %%d\n", k, v)) end
  f:close()
end
emu.addEventCallback(function()
  if rendered == 0 and finputs[frame] ~= nil then cur = finputs[frame] end
  if mseq ~= nil then
    -- menu sequence (menus do not render): each step is pressed 8 frames, then 24 frames released
    local k = frame - mstart
    local i = math.floor(k / 32) + 1
    if i > #mseq then mseq = nil; cur = {} elseif k %% 32 < 8 then cur = mseq[i] else cur = {} end
  end
  emu.setInput(cur, 0)
  if mport >= 0 then emu.setInput(mcur, 0, mport) end  -- (this Mesen reads the port from the 3rd argument)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  frame = frame + 1
  if pending ~= nil then
    local png = emu.takeScreenshot()
    local f = io.open(out .. string.format("shot_%%04d.png", pending), "wb"); f:write(png); f:close()
    pending = nil
  end
  if frame > %(maxframes)d then
    local png = emu.takeScreenshot()
    local e = io.open(out .. "shot_end.png", "wb"); e:write(png); e:close()
    local f = io.open(out .. "det.json", "w"); f:write('[' .. table.concat(log, ',\n') .. ']'); f:close()
    dumpwatch()
    emu.stop(1)
  end
end, emu.eventType.endFrame)
'''

def parse_mouse(spec):
    """'r<f>:x=<dx>,y=<dy>,l,r[@hold]' entries (rendered frames); x/y are counts per poll"""
    ev = []
    for part in filter(None, (spec or '').split(';')):
        f, b = part.split(':', 1); f = int(f.lstrip('r'))
        hold = None
        if '@' in b: b, hold = b.split('@'); hold = int(hold)
        st = {}
        for t in filter(None, b.split(',')):
            if t.startswith('x='): st['xOffset'] = int(t[2:])
            elif t.startswith('y='): st['yOffset'] = int(t[2:])
            elif t == 'l': st['left'] = 'true'
            elif t == 'r': st['right'] = 'true'
        ev.append((f, st))
        if hold: ev.append((f + hold, {}))
    return ','.join('[%d]={%s}' % (f, ','.join('%s=%s' % kv for kv in st.items())) for f, st in sorted(ev, key=lambda e: e[0]))

def parse_menus(spec):
    """'r<f>:start,down,a+b,...;...': button steps (a+b: both, -: none) started at rendered frame f"""
    out = []
    for part in filter(None, (spec or '').split(';')):
        f, seq = part.split(':', 1)
        steps = ['{%s}' % ','.join('%s=true' % b for b in st.split('+') if b != '-') for st in seq.split(',')]
        out.append('[%d]={%s}' % (int(f.lstrip('r')), ','.join(steps)))
    return ','.join(out)

def lua_tbl(evs):
    return ','.join('[%d]={%s}' % (f, ','.join('%s=true' % b for b in btn)) for f, btn in sorted(evs))

def run(a):
    os.makedirs(a.out, exist_ok=True)
    syms = load_syms(a.sym or os.path.splitext(a.rom)[0] + '.sym')
    ev = parse_input(a.input)
    lua = LUA % {'out': os.path.abspath(a.out), 'finputs': lua_tbl(ev['f']), 'rinputs': lua_tbl(ev['r']),
                 'menus': parse_menus(a.menu),
                 'dumps': ','.join('[%d]=true' % int(x) for x in a.dump.split(',') if x),
                 'execdumps': ','.join('%s=%d' % (n, syms[n]) for n in a.dump_at.split(',') if n),
                 'fps': syms['FPSCount'] & 0xFFFF, 'vbt': syms['VBlankTotal'] & 0xFFFF,
                 'framedone': syms['FrameDone'] & 0xFFFF,
                 'mobj': syms['_RLMObjects'] & 0xFFFF, 'nmobj': 100,
                 'secd': syms['_RLSectorData'] & 0xFFFF, 'nsec': 205,
                 'pobj': syms['MPPlayerObject'] & 0xFFFF if 'MPPlayerObject' in syms else syms['PlayerObject'] & 0xFFFF,
                 'ox': 0x08, 'oy': 0x0C, 'oa': 0x14,
                 'health': syms['PlayerHealth'] & 0xFFFF,
                 'shots': ','.join('[%d]=true' % int(x) for x in a.shots.split(',') if x),
                 'nframes': a.frames, 'skill': a.skill, 'skilladdr': syms['_SkillLevel'] & 0xFFFF, 'minputs': parse_mouse(a.mouse), 'mport': (0 if a.mouse_port == 1 else 1) if a.mouse else -1, 'level': a.level, 'lvl': syms['Level'] & 0xFFFF, 'maxframes': a.frames * 8 + 3000,
                 'prof': 'true' if a.profile else 'false',
                 'watch': ','.join(str(syms[n] & 0xFFFF) for n in a.watch.split(',') if n), 'pfrom': a.profile_from}
    if a.lua:   # extra probes: the script sees the test's locals (out, frame, rendered, r8, rw)
        lua += '\n' + open(a.lua).read()
    lp = os.path.join(a.out, 'det.lua'); open(lp, 'w').write(lua)
    env = dict(os.environ, MESEN_GSU_CLOCK=str(a.gsuclock))
    if a.mouse:
        env['MESEN_PORT%d_MOUSE' % a.mouse_port] = '1'
    # battery RAM (save games) from an earlier run must not leak into this one
    srm = os.path.join(os.environ.get('MESEN_HOME', '/tmp/mesenhome'), 'Saves',
                       os.path.splitext(os.path.basename(a.rom))[0] + '.srm')
    try: os.remove(srm)
    except FileNotFoundError: pass
    r = subprocess.run([a.mesenrun, a.rom, lp, str(a.timeout)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, env=env)
    d = json.load(open(os.path.join(a.out, 'det.json')))
    print('%s: %d rendered frames (emulated frame %d at the end)' % (a.rom, len(d), d[-1][1] if d else 0))
    if a.profile:
        report(os.path.join(a.out, 'prof.txt'), syms, a.profile)

def report(path, syms, top):
    """GSU instructions executed per routine (nearest label at or below the address)"""
    import bisect
    labs = sorted((v, k) for k, v in syms.items() if '.' not in k and not k.startswith(':'))
    addrs = [v for v, _ in labs]
    per = {}; tot = 0
    for l in open(path):
        a, n = l.split(); a = int(a, 16); n = int(n); tot += n
        i = bisect.bisect_right(addrs, a) - 1
        k = labs[i][1] if i >= 0 else '?'
        per[k] = per.get(k, 0) + n
    out = sorted(per.items(), key=lambda x: -x[1])
    with open(path.replace('.txt', '_sum.txt'), 'w') as f:
        for k, n in out:
            f.write('%6.2f%% %10d %s\n' % (100.0 * n / tot, n, k))
    print('GSU instructions: %d' % tot)
    for k, n in out[:top]:
        print('%6.2f%% %10d %s' % (100.0 * n / tot, n, k))

def compare(x, y):
    A = json.load(open(os.path.join(x, 'det.json'))); B = json.load(open(os.path.join(y, 'det.json')))
    n = min(len(A), len(B))
    for i in range(n):
        if A[i][2:] != B[i][2:]:
            print('first difference at rendered frame %d: %s vs %s' % (A[i][0], A[i], B[i])); return 1
    print('identical for %d rendered frames (%d vs %d recorded)' % (n, len(A), len(B)))
    return 0 if len(A) == len(B) else 2

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('rom', nargs='?')
    ap.add_argument('--out'); ap.add_argument('--frames', type=int, default=600)
    ap.add_argument('--input', default=''); ap.add_argument('--sym')
    ap.add_argument('--shots', default='', help='rendered frame numbers to screenshot (shot_NNNN.png)')
    ap.add_argument('--timeout', type=int, default=600)
    ap.add_argument('--lua', help='Lua file appended to the test script (extra probes)')
    ap.add_argument('--mesenrun', default=os.environ.get('MESENRUN', 'mesenrun'))
    ap.add_argument('--compare', nargs=2)
    ap.add_argument('--mouse', default='', help="SNES mouse input per rendered frame: 'r<f>:x=<dx>,y=<dy>,l,r[@hold]'")
    ap.add_argument('--mouse-port', type=int, default=2, help='mouse in port 2 (with the joypad in port 1) or port 1 (mouse only)')
    ap.add_argument('--dump-at', default='', help='CPU symbols: dump the GSU RAM each time one runs (gsuram_<sym><n>.bin)')
    ap.add_argument('--dump', default='', help='rendered frames to dump the GSU RAM at (gsuram_NNNN.bin)')
    ap.add_argument('--menu', default='', help="menu button steps at a rendered frame: 'r<f>:start,down,a+b;...' (- = no button)")
    ap.add_argument('--skill', type=int, default=-1, help='force the skill (0-4, 4 = Nightmare)')
    ap.add_argument('--watch', default='', help='GSU RAM word variables (symbols) whose maximum written value is recorded in watch.txt')
    ap.add_argument('--profile', type=int, default=0, help='count GSU instructions per routine, print the top N')
    ap.add_argument('--profile-from', type=int, default=20, help='first rendered frame to profile')
    ap.add_argument('--level', type=int, default=-1, help='force the starting level number')
    ap.add_argument('--gsuclock', type=int, default=1000, help='GSU clock in %% (fast => frame pacing identical between builds)')
    a = ap.parse_args()
    if a.compare: sys.exit(compare(*a.compare))
    run(a)
