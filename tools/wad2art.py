#!/usr/bin/env python3
"""
wad2art.py -- title screen, menus, menu skull and fonts from a DOOM WAD.

Menu lettering is DOOM's scaled 0.6 across, 0.8 down (SX, SY), in the reds of
BG palette 2, drawn where the cartridge draws each line (the cursor positions
are fixed in rlmenus.asm).  Built by convert:

  title       TITLEPIC -> 256x224, 7 palettes of 15 colours (palette 7 holds
              the system text colours); --title PNG: a 256x224 picture instead
  menus       pause (with Music/Sounds/Rumble On/Off), skill, episode, save/load.
              Words the WAD has as pictures (M_NGAME, M_SKILL, ...) are used
              whole; others are assembled from letters cut out of them.  At
              most 256 tiles per menu (8 KB buffer): extra tiles are merged.
  skull       M_SKULL1/2 -> 16x16, OBJ palette 0
  rlfont      in-game message font from STCFN033-090, cartridge font colours
  --textfont      also the start screen/credits/end-text font (TextFont.def0)
                  from STCFN033-095; lower case drawn as capitals
  --intermission  also the Episode 1-3 score screens from WIMAP0-2 (ScoreE<n>)
  --interpic      the DOOM II score screen: INTERPIC -> ScoreE1, behind every level
  --level-names   the level names above FINISHED on the score page (CWILVnn / WILVem)
  --order LUMP    also the order screen (Order.*) from this picture (shareware: HELP2)
  --episodes N    the episode menu lists only the first N episodes
  --cart ITEM,... keep the cartridge's version of these items

  learn    back up the cartridge versions (DATA/RLART.fx3) and record where
           each menu line is drawn (DATA/wad2art.json)
  convert  write the WAD versions into DATA/RLDATA
  compare  PNG sheet: cartridge vs converted (DIR/art.png)
  restore  put the cartridge versions back

usage: wad2art.py learn   --data DATA
       wad2art.py convert --data DATA --wad DOOM.WAD [--wad PWAD] [--textfont] [--intermission | --interpic]
                          [--level-names] [--episodes N] [--title PNG] [--order LUMP]
                          [--cart skill,episode,skull,font,textfont]
       wad2art.py compare --data DATA [--png DIR]
       wad2art.py restore --data DATA
"""
import argparse, json, os, shutil, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'datagen'))
import numpy as np                                                   # noqa: E402
from PIL import Image                                                # noqa: E402
import snescomp as sc                                                # noqa: E402
from snesgfx import encode_tile, decode_tile, bgr555_to_rgb, rgb_to_bgr555   # noqa: E402
from tilequant import quantize, dedupe                               # noqa: E402
from wad2gfx import WadArt                                           # noqa: E402

FILES = ['COMP/' + n for n in (
    'title.def.0', 'title.def.1', 'title.map0', 'title.rgb', 'PauseMenu.def0', 'PauseMenu.map0',
    'SkillMenu.def0', 'SkillMenu.map0', 'EpisodeMenu.def0', 'EpisodeMenu.map0', 'SlotMenu.def0',
    'SaveMenu.map0', 'LoadMenu.map0', 'menus.inc', 'MenuSkulls.def0')] + ['ART/rlfont.def0']
CART_ITEMS = {'skill': ['COMP/SkillMenu.def0', 'COMP/SkillMenu.map0'],          # for --cart
              'episode': ['COMP/EpisodeMenu.def0', 'COMP/EpisodeMenu.map0'],
              'skull': ['COMP/MenuSkulls.def0'], 'font': ['ART/rlfont.def0'],
              'textfont': ['COMP/TextFont.def0']}
SCOREFILES = lambda ep: ['COMP/ScoreE%d.def.0' % ep, 'COMP/ScoreE%d.def.1' % ep, 'COMP/ScoreE%d.map0' % ep,
                         'ART/ScoreE%d.rgb' % ep]           # (--intermission / --interpic)
PAL, PRIO = 2, 0x2000          # menu text: BG palette 2, priority
MENU_COLOURS = [i for i in range(1, 16) if i not in (13, 15)]       # the reds of palette 2 (menus.py)
MAXTILES = 256                 # MenuDeCompBuffer: 8 KB of 4bpp tiles
SX, SY = 0.6, 0.8                # menu lettering: 15-pixel words -> 12 lines; 0.6 keeps the letter shapes on
                                 # the SNES's wider pixels (the cartridge uses 0.59-0.63)
SCALE = 0.8                      # menu skull
CORE = 0.2                       # share of a SNES pixel that must be letter core
SPACE = 8                      # word space (PC pixels)
LINES = {                      # menu -> text of each line, top to bottom (as on the cartridge)
    'PauseMenu': ['Restart Level', 'New Game', 'Save Game', 'Load Game', 'Music: on', 'Sounds: on', 'Rumble: on'],
    'SkillMenu': ['Choose Skill Level:', "I'm too young to die.", 'Hey, not too rough.', 'Hurt me plenty.',
                  'Ultra-Violence.', 'Nightmare!'],
    'EpisodeMenu': ['Which Episode?', 'Knee-Deep in the Dead', 'The Shores of Hell', 'Inferno',
                    'Thy Flesh Consumed'],
    'SaveMenu': ['Save Game'],
    'LoadMenu': ['Load Game'],
}
WORDS = {                      # DOOM menu pictures and their text
    'M_NGAME': 'New Game', 'M_OPTION': 'Options', 'M_LOADG': 'Load Game', 'M_SAVEG': 'Save Game',
    'M_RDTHIS': 'Read This!', 'M_QUITG': 'Quit Game', 'M_SKILL': 'Choose Skill Level:',
    'M_EPISOD': 'Which Episode?', 'M_JKILL': "I'm too young to die.", 'M_ROUGH': 'Hey, not too rough.',
    'M_HURT': 'Hurt me plenty.', 'M_ULTRA': 'Ultra-Violence.', 'M_NMARE': 'Nightmare!',
    'M_EPI1': 'Knee-Deep in the Dead', 'M_EPI2': 'The Shores of Hell', 'M_EPI3': 'Inferno',
    'M_EPI4': 'Thy Flesh Consumed', 'M_ENDGAM': 'End Game', 'M_MESSG': 'Messages:', 'M_MSGOFF': 'off',
    'M_MSGON': 'on', 'M_DETAIL': 'Graphic Detail:', 'M_GDHIGH': 'high', 'M_GDLOW': 'low',
    'M_SCRNSZ': 'Screen Size', 'M_MSENS': 'Mouse sensitivity', 'M_SVOL': 'Sound Volume',
    'M_SFXVOL': 'Sfx Volume', 'M_MUSVOL': 'Music Volume', 'M_DISP': 'Display', 'M_PAUSE': 'PAUSE',
}


def log(*a):
    print(*a, flush=True)


def comp_read(path):
    return sc.decompress(open(path, 'rb').read())[0]


def menu_image(comp, name, defname=None):
    """decode a menu (4bpp tiles + 32-wide map) -> colour indices (rows*8, 256)"""
    d = comp_read(os.path.join(comp, (defname or name) + '.def0'))
    m = comp_read(os.path.join(comp, name + '.map0'))
    w = struct.unpack('<%dH' % (len(m) // 2), m)
    img = np.zeros((len(w) // 32 * 8, 256), np.uint8)
    for i, e in enumerate(w):
        t = decode_tile(d, 32 * (e & 0x3FF), 4)
        t = t[:, ::-1] if e & 0x4000 else t
        t = t[::-1] if e & 0x8000 else t
        r, c = divmod(i, 32)
        img[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = t
    return img


def line_boxes(img):
    rows = (img > 0).any(1)
    out, y = [], 0
    while y < len(rows):
        if rows[y]:
            s = y
            while y < len(rows) and rows[y]:
                y += 1
            cols = np.nonzero((img[s:y] > 0).any(0))[0]
            out.append([s, y, int(cols.min()), int(cols.max()) + 1])
        else:
            y += 1
    return out


# ---------------------------------------------------------------- learn
def learn(a):
    rl = os.path.join(a.data, 'RLDATA')
    keep = os.path.join(a.data, 'RLART.fx3')
    if not os.path.isdir(keep):
        for f in FILES:
            os.makedirs(os.path.dirname(os.path.join(keep, f)), exist_ok=True)
            shutil.copy2(os.path.join(rl, f), os.path.join(keep, f))
    comp = os.path.join(keep, 'COMP')
    lay = {}
    for menu, texts in LINES.items():
        img = menu_image(comp, menu, 'SlotMenu' if menu in ('SaveMenu', 'LoadMenu') else None)
        boxes = line_boxes(img)
        if menu == 'PauseMenu':
            boxes = boxes[:len(texts)]
        assert len(boxes) == len(texts), (menu, boxes)
        lay[menu] = dict(rows=img.shape[0] // 8, lines=[dict(text=t, y=b[0], x=b[2]) for t, b in zip(texts, boxes)])
        log('%-11s %2d rows: %s' % (menu, img.shape[0] // 8, ', '.join('%s @%d,%d' % (t, b[2], b[0])
                                                                     for t, b in zip(texts, boxes))))
    json.dump(lay, open(os.path.join(a.data, 'wad2art.json'), 'w'), indent=1)


# ---------------------------------------------------------------- DOOM lettering
class Lettering:
    """DOOM menu pictures, cut at letter boundaries (a letter = a run of columns
    with colour brighter than the outline, +-1 outline column)"""
    def __init__(self, wa):
        self.pal = wa.palette
        lum = self.pal.mean(1)
        self.pics, self.cuts = {}, {}
        for lump, text in WORDS.items():
            d = wa.get(lump)
            if d is None:
                continue
            a = WadArt.patch(d)
            dy = max(0, -struct.unpack('<h', d[6:8])[0])     # drawn lower by -topoffset (on, off, high, low)
            if dy:
                a = np.vstack([np.full((dy, a.shape[1]), -1, int), a])
            self.pics[text] = a
            core = np.where(a >= 0, lum[np.where(a >= 0, a, 0)] > 30, False).any(0)
            pieces, x = [], 0
            while x < len(core):
                if core[x]:
                    s = x
                    while x < len(core) and core[x]:
                        x += 1
                    pieces.append((max(s - 1, 0), min(x + 1, a.shape[1])))
                else:
                    x += 1
            chars = [c for c in text if c != ' ']
            if len(pieces) == len(chars):                   # letters found: substrings can be cut out
                self.cuts[text] = (a, chars, pieces)

    def piece(self, s):
        """the longest picture substring for s at letter boundaries (no spaces): (img, n chars)"""
        for n in range(len(s), 0, -1):
            want = s[:n]
            for text, (a, chars, pieces) in self.cuts.items():
                joined = ''.join(chars)
                k = joined.find(want)
                # inside one word of the picture only (no space between the letters)
                while k >= 0:
                    pos = [i for i, c in enumerate(text) if c != ' ']
                    if pos[k + n - 1] - pos[k] == n - 1:
                        return a[:, pieces[k][0]:pieces[k + n - 1][1]], n
                    k = joined.find(want, k + 1)
        return None, 0

    def phrase(self, text):
        """PC-scale index image (-1 = clear) of text, or None if a letter is missing"""
        if text in self.pics:
            return self.pics[text]
        parts = []
        for k, tok in enumerate(text.split(' ')):
            if k:
                parts.append(None)
            i = 0
            while i < len(tok):
                img, n = self.piece(tok[i:])
                if img is None:
                    return None
                parts.append(img); i += n
        h = max(p.shape[0] for p in parts if p is not None)
        w = sum(p.shape[1] for p in parts if p is not None) + SPACE * text.count(' ')
        out = np.full((h, w), -1, int)
        x, prev = 0, None
        for p in parts:
            if p is None:
                x += SPACE; prev = None; continue
            if prev is not None:
                x -= 1                                   # neighbouring letters share one outline column
            sub = out[:p.shape[0], x:x + p.shape[1]]
            sub[:] = np.where(p >= 0, p, sub)
            x += p.shape[1]; prev = p
        return out[:, :x]


def scale_rgba(idx, pal, factor, size=None):
    """index image -> RGB, alpha (area average; factor = (x, y) or size)"""
    if size is None:                                     # exact grid: same pixels for a shared prefix
        h, w = idx.shape
        idx = np.pad(idx, ((0, -h % 5), (0, -w % 5)), constant_values=-1)
    h, w = idx.shape
    size = size or (round(w * factor[0]), round(h * factor[1]))
    rgb = pal[np.where(idx >= 0, idx, 0)]
    al = (idx >= 0).astype(float)
    pm = np.dstack([rgb * al[..., None], al * 255]).astype(np.float32)
    out = np.dstack([np.asarray(Image.fromarray(pm[..., k], 'F').resize(size, Image.BOX)) for k in range(4)])
    a = out[..., 3:4] / 255.0
    return np.where(a > 0, out[..., :3] / np.maximum(a, 1e-6), 0), a[..., 0]


def lettering(idx, pal, cand, colours, outline, lumtab=None):
    """DOOM lettering at SNES scale: the bright letter core scaled (a pixel is core
    from CORE coverage on), coloured with the cartridge's brightness ramp, and a
    1-pixel dark edge below and right of it, as the cartridge letters have
    (scaling the PC outline with the letters would make it eat the thin cores)"""
    lum = pal.mean(1)
    core = np.where(idx >= 0, lum[np.where(idx >= 0, idx, 0)] > 30, False)
    crgb, ca = scale_rgba(np.where(core, idx, -1), pal, (SX, SY))
    C = ca >= CORE
    edge = np.zeros_like(C)
    for dy, dx in ((1, 0), (0, 1)):
        edge |= np.roll(np.roll(np.pad(C, 1), dy, 0), dx, 1)[1:-1, 1:-1]
    if lumtab is not None:                               # brightness ramp learned from the cartridge
        core_q = lumtab[np.clip(crgb.mean(-1).round().astype(int), 0, 255)]
    else:
        core_q = nearest(crgb, cand, colours)
    return np.where(C, core_q, outline), C | edge


def nearest(rgb, cand, colours):
    d = ((rgb[..., None, :] - colours[None, None, :, :]) ** 2).sum(-1)
    return np.array(cand)[d.argmin(-1)]


# ---------------------------------------------------------------- tiles
class Tiler:
    """4bpp 8x8 tiles, tile 0 blank; flips allowed; lossy merge to a limit"""
    def __init__(self):
        self.tiles = [np.zeros((8, 8), np.uint8)]
        self.index = {self.tiles[0].tobytes(): (0, 0)}
        self.maps = []

    def add(self, t, flips=True):
        for v, fl in (((t, 0), (t[:, ::-1], 0x4000), (t[::-1], 0x8000), (t[::-1, ::-1], 0xC000))
                      if flips else ((t, 0),)):
            k = v.tobytes()
            if k in self.index:
                n, f0 = self.index[k]
                return n, f0 ^ fl
        n = len(self.tiles)
        self.tiles.append(t.copy()); self.index[t.tobytes()] = (n, 0)
        return n, 0

    def entry(self, t):
        n, fl = self.add(t)
        return 0 if n == 0 else n | fl | (PAL << 10) | PRIO

    def map_image(self, img):
        words = [self.entry(img[r * 8:r * 8 + 8, c * 8:c * 8 + 8])
                 for r in range(img.shape[0] // 8) for c in range(32)]
        self.maps.append(words)
        return words

    def fit(self, colours, keep=()):
        """merge the most similar tiles until <= MAXTILES; returns how many were merged"""
        merged = 0
        rep = list(range(len(self.tiles)))
        while len(set(rep)) > MAXTILES:
            alive = sorted(set(rep) - {0} - set(keep))
            X = np.array([colours[self.tiles[i]].reshape(-1) for i in alive])
            d = ((X[:, None, :] - X[None, :, :]) ** 2).sum(-1)
            np.fill_diagonal(d, np.inf)
            i, j = np.unravel_index(d.argmin(), d.shape)
            a_, b_ = alive[i], alive[j]
            rep = [a_ if r == b_ else r for r in rep]
            merged += 1
        live = sorted(set(rep))
        new = {o: k for k, o in enumerate(live)}
        for m in self.maps:
            for q, e in enumerate(m):
                n = e & 0x3FF
                if e:
                    m[q] = (e & ~0x3FF) | new[rep[n]]
        self.tiles = [self.tiles[o] for o in live]
        self.remap = lambda e: 0 if not e else (e & ~0x3FF) | new[rep[e & 0x3FF]]
        return merged

    def data(self):
        return b''.join(encode_tile(t, 4) for t in self.tiles)


# ---------------------------------------------------------------- convert
def convert(a):
    lay = json.load(open(os.path.join(a.data, 'wad2art.json')))
    keep = os.path.join(a.data, 'RLART.fx3')
    rl = os.path.join(a.data, 'RLDATA')
    wa = WadArt(a.wad)
    L = Lettering(wa)
    rgb = open(os.path.join(rl, 'COLOUR', 'BASERGB.RGB'), 'rb').read()[:512]
    cg = np.array(bgr555_to_rgb(rgb), float)                         # game CGRAM (palette 0 of BASERGB)
    menu_cols = cg[PAL * 16 + np.array(MENU_COLOURS)]
    tile_cols = np.zeros((16, 3)); tile_cols[1:] = cg[PAL * 16 + 1:PAL * 16 + 16]
    outline = MENU_COLOURS[int(((menu_cols - wa.palette[191]) ** 2).sum(-1).argmin())]   # DOOM's outline red
    # brightness of the letter cores: the WAD's core colours, by rank, onto the cartridge's
    # menu reds (the cartridge draws them brighter than a nearest-colour match)
    cartpix = np.concatenate([menu_image(os.path.join(keep, 'COMP'), n).flatten()
                              for n in ('PauseMenu', 'SkillMenu', 'EpisodeMenu')])
    cartpix = cartpix[(cartpix > 0) & (cartpix != outline)]
    clum = cg[PAL * 16 + cartpix].mean(-1)
    lumw = wa.palette.mean(1)
    wadpix = np.concatenate([a[a >= 0] for a in L.pics.values()])
    wlum = lumw[wadpix]; wlum = np.sort(wlum[wlum > 30])
    order = np.argsort(clum, kind='stable'); cart_sorted = cartpix[order]
    lumtab = np.zeros(256, int)
    for v in range(256):
        qtl = np.searchsorted(wlum, v) / max(len(wlum), 1)
        lumtab[v] = cart_sorted[min(int(qtl * len(cart_sorted)), len(cart_sorted) - 1)]
    report = {}

    def put(rel, data, raw=False):
        open(os.path.join(rl, rel), 'wb').write(data if raw else sc.compress(data))

    def render(text, img, x0, y0):
        """draw text into the menu image (colour indices of palette 2); False if a letter is missing"""
        idx = L.phrase(text)
        if idx is None:
            return False
        q, m = lettering(idx, wa.palette, MENU_COLOURS, menu_cols, outline, lumtab)
        h, w = q.shape
        w = min(w, 256 - x0)
        reg = img[y0:y0 + h, x0:x0 + w]
        reg[:] = np.where(m[:reg.shape[0], :w], q[:reg.shape[0], :w], reg)
        return True

    def build_menu(name, cart):
        ml = lay[name]
        img = np.zeros((ml['rows'] * 8, 256), np.uint8)
        kept = []
        for k, ln in enumerate(ml['lines']):
            if name == 'EpisodeMenu' and a.episodes and k > a.episodes:
                continue                                 # (--episodes: the menu offers only these)
            text = ln['text'][:-3] if ln['text'].endswith(' on') else ln['text']   # On/Off: drawn separately
            if not render(text, img, ln['x'], ln['y']):
                # a letter the WAD lacks: the cartridge's line
                b = [bb for bb in line_boxes(cart) if bb[0] <= ln['y'] < bb[1]][0]
                img[b[0]:b[1]] = np.where(cart[b[0]:b[1]] > 0, cart[b[0]:b[1]], img[b[0]:b[1]])
                kept.append(ln['text'])
        return img, kept

    ccomp = os.path.join(keep, 'COMP')
    # --- pause menu with the On/Off toggles
    cart = menu_image(ccomp, 'PauseMenu')
    P, kept = build_menu('PauseMenu', cart)
    tp = Tiler()
    tog = {}
    togpos = {}
    # On/Off: the words drawn once, at a tile boundary after "Music:"/"Sounds:"/"Rumble:",
    # so that the lines use the same 3x2 tiles (the code has one set)
    words = {st: lettering(L.phrase(st), wa.palette, MENU_COLOURS, menu_cols, outline, lumtab)
             for st in ('on', 'off')}
    for key, ln in zip(('MUSIC', 'SOUNDS', 'RUMBLE'), lay['PauseMenu']['lines'][4:7]):
        label = ln['text'].rsplit(' ', 1)[0]
        if L.phrase(label) is None:                      # a letter the WAD lacks ("Rumble"): build_menu kept
            b = [bb for bb in line_boxes(P) if bb[0] <= ln['y'] < bb[1]][0]     # the cartridge's line;
            cols = np.nonzero((P[b[0]:b[1]] > 0).any(0))[0]                     # its "O" (after a word
            gap = [i for i in range(1, len(cols)) if cols[i] - cols[i - 1] > 4][-1]   # space) goes, as the
            P[b[0]:b[1], cols[gap]:] = 0                                       # toggle draws On/Off
            lw = cols[gap - 1] + 1 - ln['x']
        else:
            lw = lettering(L.phrase(label), wa.palette, MENU_COLOURS, menu_cols, outline, lumtab)[1].any(0).nonzero()[0].max() + 1
        bx = -(-(ln['x'] + lw + round(SPACE * SX)) // 8) * 8
        top = min(np.nonzero(m.any(1))[0].min() for q, m in words.values())
        by = (ln['y'] + top) // 8 * 8                    # the words' first row decides the tile rows
        tiles = {}
        for st, (q, m) in words.items():
            box = np.zeros((16, 24), np.uint8)
            rows = np.nonzero(m.any(1))[0]
            assert m.shape[1] <= 24 and ln['y'] + rows.max() < by + 16, 'On/Off does not fit 3x2 tiles'
            for r in rows:                               # word row r is screen row ln.y + r
                box[ln['y'] + r - by, :m.shape[1]] = np.where(m[r], q[r], 0)
            for r in range(2):
                for c in range(3):
                    tiles['%s%d%d' % (st, r, c)] = box[8 * r:8 * r + 8, 8 * c:8 * c + 8]
            if st == 'on':
                P[by:by + 16, bx:bx + 24] = np.where(box > 0, box, P[by:by + 16, bx:bx + 24])
        togpos[key] = (by // 8) * 32 + bx // 8
        tog[key] = tiles
    togw = {k: tp.entry(t) for k, t in tog['MUSIC'].items()}
    pw = tp.map_image(P)
    mp = tp.fit(tile_cols, keep=[e & 0x3FF for e in togw.values()])
    togw = {k: tp.remap(v) if hasattr(tp, 'remap') else v for k, v in togw.items()}
    put('COMP/PauseMenu.def0', tp.data())
    put('COMP/PauseMenu.map0', struct.pack('<%dH' % len(tp.maps[0]), *tp.maps[0]))
    report['PauseMenu'] = (len(tp.tiles), mp, kept)

    # --- skill / episode menus
    for name in ('SkillMenu', 'EpisodeMenu'):
        img, kept = build_menu(name, menu_image(ccomp, name))
        t = Tiler(); t.map_image(img); mg = t.fit(tile_cols)
        put('COMP/%s.def0' % name, t.data())
        put('COMP/%s.map0' % name, struct.pack('<%dH' % len(t.maps[0]), *t.maps[0]))
        report[name] = (len(t.tiles), mg, kept)

    # --- save/load menus: titles + DOOM's HUD font for the slot texts (as menus.py build)
    ts = Tiler()
    font = {}
    hud_cols = cg[PAL * 16 + np.array(MENU_COLOURS)]
    for ch in range(32, 91):
        t = np.zeros((8, 8), np.uint8)
        d = wa.get('STCFN%03d' % ch) if ch > 32 else None
        if d:
            g = WadArt.patch(d)[:8, :8]
            m = g >= 0
            if m.any():
                q = nearest(wa.palette[np.where(m, g, 0)], MENU_COLOURS, hud_cols)
                t[:g.shape[0], :g.shape[1]] = np.where(m, q, 0)
        font[ch] = ts.add(t, flips=False)[0] if d else 0
    slot_kept = []
    for name in ('SaveMenu', 'LoadMenu'):
        cart = menu_image(ccomp, name, 'SlotMenu')
        img, kept = build_menu(name, cart)
        slot_kept += kept
        ts.map_image(img)
    ms = ts.fit(tile_cols, keep=list(font.values()))
    if hasattr(ts, 'remap'):
        font = {k: ts.remap(v | 0x0400) & 0x3FF if v else 0 for k, v in font.items()}
    put('COMP/SlotMenu.def0', ts.data())
    put('COMP/SaveMenu.map0', struct.pack('<%dH' % len(ts.maps[0]), *ts.maps[0]))
    put('COMP/LoadMenu.map0', struct.pack('<%dH' % len(ts.maps[1]), *ts.maps[1]))
    report['SlotMenu'] = (len(ts.tiles), ms, slot_kept)

    inc = ['; generated by tools/wad2art.py -- do not edit']
    for k, v in togw.items():
        inc.append('!MENUTOG_%s = $%04X' % (k, v))
    inc.append('!MENUTOG_MUSIC = %d\t; map position of the Music On/Off tiles (menu rows)' % togpos['MUSIC'])
    inc.append('!MENUTOG_SOUNDS = %d' % togpos['SOUNDS'])
    inc.append('!MENUTOG_RUMBLE = %d' % togpos['RUMBLE'])
    inc.append('!SLOTFONT_PAL = $%04X\t; palette/priority bits of a slot font map entry' % ((PAL << 10) | PRIO))
    inc.append('macro slotfont_table()')
    for ch in range(32, 91):
        inc.append('\tdb $%02X\t; %r' % (font[ch], chr(ch)))
    inc.append('endmacro')
    open(os.path.join(rl, 'COMP', 'menus.inc'), 'w').write('\n'.join(inc) + '\n')

    # --- menu skull: M_SKULL1/2, 16x16, OBJ palette 0 (CGRAM 128-143)
    obj = cg[128:144]
    frames = []
    for lump in ('M_SKULL1', 'M_SKULL2'):
        g = WadArt.patch(wa.get(lump))
        col, al = scale_rgba(g, wa.palette, SCALE, size=(16, 16))
        q = np.where(al >= 0.5, nearest(col, list(range(1, 16)), obj[1:]), 0).astype(np.uint8)
        frames.append(q)
    tl = lambda f, y, x: encode_tile(frames[f][y:y + 8, x:x + 8], 4)
    put('COMP/MenuSkulls.def0', tl(0, 0, 0) + tl(0, 0, 8) + tl(1, 0, 0) + tl(1, 0, 8) +
        tl(0, 8, 0) + tl(0, 8, 8) + tl(1, 8, 0) + tl(1, 8, 8))

    # --- title: TITLEPIC -> 256x224, 7 palettes (palette 7: system text colours, as datagen/fx3_art.py)
    if a.title:                                          # --title: a 256x224 picture instead
        img = np.asarray(Image.open(a.title).convert('RGB'))
        if img.shape[:2] != (224, 256):
            sys.exit('%s: the title picture must be 256x224' % a.title)
    else:
        tp_ = WadArt.patch(wa.get('TITLEPIC'))
        src = wa.palette[np.where(tp_ >= 0, tp_, 0)].astype(np.uint8)
        img = np.asarray(Image.fromarray(src).resize((256, 224), Image.LANCZOS))
    tiles, tpal, pals, err = quantize(img, 7, backdrop=(0, 0, 0))
    u, e = dedupe(tiles, tpal)
    assert len(u) <= 1024, len(u)
    chars = b''.join(encode_tile(t, 4) for t in u)
    full = bytearray(512)
    full[:7 * 32] = rgb_to_bgr555([tuple(int(v) for v in c) for p in pals for c in p])
    full[(7 * 16 + 7) * 2:(7 * 16 + 8) * 2] = struct.pack('<H', 0x0007)
    full[(7 * 16 + 11) * 2:(7 * 16 + 12) * 2] = struct.pack('<H', 0x001F)
    put('COMP/title.def.0', chars[:0x4000])
    put('COMP/title.def.1', chars[0x4000:] or bytes(32))
    put('COMP/title.map0', struct.pack('<%dH' % len(e), *e))
    put('COMP/title.rgb', bytes(full))
    report['title'] = (len(u), 0, [])

    # --- order screen (--order LUMP, the shareware set: HELP2): a picture in the title's
    #     format (Order.def.0/.def.1/.map0/.rgb), shown for an episode the set does not have
    if a.order:
        lump = wa.get(a.order)
        if lump is None:
            sys.exit('--order: no %s in the WAD' % a.order)
        op = WadArt.patch(lump)
        src = wa.palette[np.where(op >= 0, op, 0)].astype(np.uint8)
        img = np.asarray(Image.fromarray(src).resize((256, 224), Image.LANCZOS))
        tiles, tpal, pals, oerr = quantize(img, 8, backdrop=(0, 0, 0))
        u, e = dedupe(tiles, tpal)
        assert len(u) <= 1024, len(u)
        chars = b''.join(encode_tile(t, 4) for t in u)
        put('COMP/Order.def.0', chars[:0x4000])
        put('COMP/Order.def.1', chars[0x4000:] or bytes(32))
        put('COMP/Order.map0', struct.pack('<%dH' % len(e), *e))
        put('COMP/Order.rgb', rgb_to_bgr555([tuple(int(v) for v in c) for p in pals for c in p]) + bytes(256))
        log('order      %s -> Order: %d tiles, 8 palettes (mean squared error %.0f)' % (a.order, len(u), oerr))

    # --- intermission maps (--intermission): WIMAP0-2 -> ScoreE1-3, stretched to 256x224 as on
    #     the cartridge (so the level markers keep their places), 6 palettes (CGRAM 0-95)
    #     --interpic (DOOM II sets): the WAD's INTERPIC -> ScoreE1, the picture behind every
    #     level's score (score.asm: !RLEPISODELEN = 99, no map, no splats)
    if a.intermission or a.interpic:
        for ep, name in ([(1, 'INTERPIC')] if a.interpic else [(ep, 'WIMAP%d' % (ep - 1)) for ep in (1, 2, 3)]):
            lump = wa.get(name)
            if not lump:
                if a.interpic:
                    sys.exit('--interpic: the WAD has no INTERPIC')
                continue
            for f in SCOREFILES(ep):                     # the cartridge's, for restore
                k = os.path.join(keep, f)
                if not os.path.exists(k):
                    os.makedirs(os.path.dirname(k), exist_ok=True)
                    shutil.copy2(os.path.join(rl, f), k)
            wm = WadArt.patch(lump)
            src = wa.palette[np.where(wm >= 0, wm, 0)].astype(np.uint8)
            img = np.asarray(Image.fromarray(src).resize((256, 224), Image.LANCZOS))
            tiles, tpal, pals, serr = quantize(img, 6, backdrop=(0, 0, 0))
            u, e = dedupe(tiles, tpal)
            assert len(u) <= 896, len(u)
            chars = b''.join(encode_tile(t, 4) for t in u)
            put('COMP/ScoreE%d.def.0' % ep, chars[:0x4000])
            put('COMP/ScoreE%d.def.1' % ep, chars[0x4000:] or bytes(32))
            put('COMP/ScoreE%d.map0' % ep, struct.pack('<%dH' % len(e), *e))
            put('ART/ScoreE%d.rgb' % ep, rgb_to_bgr555([tuple(int(v) for v in c) for p in pals for c in p]), raw=True)
            report['ScoreE%d' % ep] = (len(u), 0, [])
            log('intermission %s -> ScoreE%d: %d tiles, 6 palettes (mean squared error %.0f)'
                % (name, ep, len(u), serr))

    # --- level names (--level-names): the WAD's name pictures (DOOM II sets CWILVnn, else
    #     WILVem) above "FINISHED" on the score page (score.asm ScoreName), scaled as the rest of
    #     the page (320x200 -> 256x224), centred on BG2 rows 1-2, tiles from $6800 (BG2 tile 128),
    #     one palette for all (BG palette 6 but colours 7 and 11: the text font's black and grey)
    if a.level_names:
        for f in os.listdir(os.path.join(rl, 'COMP')):
            if f.startswith('ScoreName'):
                os.remove(os.path.join(rl, 'COMP', f))
        if os.path.exists(os.path.join(rl, 'ART', 'ScoreName.rgb')):
            os.remove(os.path.join(rl, 'ART', 'ScoreName.rgb'))
        inc = open(os.path.join(a.data, 'RLLEV', 'levels.inc')).read()
        import re
        nlev = int(re.search(r'^!NUMLEVELS = (\d+)', inc, re.M).group(1))
        doom2 = re.search(r'^!RLEPISODELEN = 99', inc, re.M) is not None
        slots = re.findall(r'^!lvl\d+ = (\w+)$', inc, re.M)
        used = dict(re.findall(r'^!use(\w+) #= (\d)', inc, re.M))
        pics = {}
        for i in range(nlev):
            if used.get(slots[i], '1') != '1':
                continue
            name = 'CWILV%02d' % i if doom2 else 'WILV%d%d' % (i // 9, i % 9)
            lump = wa.get(name)
            if not lump:
                continue
            g = WadArt.patch(lump)
            rgba = np.zeros(g.shape + (4,), np.uint8)
            rgba[..., :3] = wa.palette[np.where(g >= 0, g, 0)].astype(np.uint8)
            rgba[..., 3] = np.where(g >= 0, 255, 0)
            w2 = max(1, int(round(g.shape[1] * 0.8)))
            h2 = min(16, max(1, int(round(g.shape[0] * 1.12))))
            pics[i] = (name, np.asarray(Image.fromarray(rgba, 'RGBA').resize((w2, h2), Image.LANCZOS)))
        if pics:
            SLOTS = [1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 13, 14, 15]
            px = np.concatenate([im[im[..., 3] >= 128][:, :3] for _, im in pics.values()])
            q = Image.fromarray(px.reshape(-1, 1, 3)).quantize(colors=len(SLOTS), method=Image.Quantize.MEDIANCUT)
            pal = np.array(q.getpalette()[:3 * len(SLOTS)], float).reshape(-1, 3)
            rgb = [(0, 0, 0)] * 16
            for k, c in enumerate(pal):
                rgb[SLOTS[k]] = tuple(int(v) for v in c)
            rgb[11] = (240, 240, 240)                            # (the text font's, score.asm)
            put('ART/ScoreName.rgb', rgb_to_bgr555(rgb), raw=True)
            ntile = 0
            for i, (name, im) in sorted(pics.items()):
                h2, w2 = im.shape[:2]
                can = np.zeros((16, 256), np.uint8)              # colour slot per pixel, 0 = clear
                x0, y0 = (256 - w2) // 2, 15 - h2                # bottom-aligned, 1 line above FINISHED
                op = im[..., 3] >= 128
                d = ((im[..., :3][:, :, None, :].astype(float) - pal[None, None]) ** 2).sum(-1)
                can[y0:y0 + h2, x0:x0 + w2] = np.where(op, np.array(SLOTS)[d.argmin(-1)], 0)
                tiles, mp = [], [0] * 64
                for r in range(2):
                    for c in range(32):
                        t = can[r * 8:r * 8 + 8, c * 8:c * 8 + 8]
                        if t.any():
                            mp[r * 32 + c] = 0x3800 | (128 + len(tiles))      # priority, palette 6
                            tiles.append(t)
                assert len(tiles) <= 64, (name, len(tiles))
                put('COMP/ScoreName%d.def0' % i, b''.join(encode_tile(t, 4) for t in tiles))
                put('COMP/ScoreName%d.map0' % i, struct.pack('<64H', *mp))
                ntile = max(ntile, len(tiles))
            log('level names: %d (%s..%s), up to %d tiles each, %d colours'
                % (len(pics), pics[min(pics)][0], pics[max(pics)][0], ntile, len(SLOTS)))

    # --- text font (--textfont): TextFont.def0, chars 32-130, 4bpp (colour 11 letter, 7 shadow)
    #     from STCFN033-095; the WAD has capitals only, so lower case gets the capitals
    if a.textfont:
        f = 'COMP/TextFont.def0'
        k = os.path.join(keep, f)
        if not os.path.exists(k):
            shutil.copy2(os.path.join(rl, f), k)
        out = bytearray()
        for ch in range(32, 131):
            c = ch - 32 if 97 <= ch <= 122 else ch
            t = np.zeros((8, 8), np.uint8)
            d = wa.get('STCFN%03d' % c) if 33 <= c <= 95 else None
            if d:
                g = WadArt.patch(d)                              # the letter: its bright pixels
                lum = wa.palette[np.where(g >= 0, g, 0)].astype(int).sum(2)
                b = (g >= 0) & (lum > 120)                       # (not the dark outline)
                if not b.any():
                    out += encode_tile(t, 4)
                    continue
                ys, xs = np.where(b)
                g = g[ys.min():ys.max() + 1, xs.min():xs.max() + 1][:7, :7]
                m = b[ys.min():ys.max() + 1, xs.min():xs.max() + 1][:7, :7]
                y0 = 7 - g.shape[0]                              # on the baseline (row 6)
                for y in range(g.shape[0]):
                    for x in range(g.shape[1]):
                        if m[y, x]:
                            if y0 + y + 1 < 8 and x + 1 < 8 and t[y0 + y + 1, x + 1] == 0:
                                t[y0 + y + 1, x + 1] = 7         # shadow
                for y in range(g.shape[0]):
                    for x in range(g.shape[1]):
                        if m[y, x]:
                            t[y0 + y, x] = 11
            out += encode_tile(t, 4)
        put(f, bytes(out))
        log('text font  STCFN033-095 from the WAD (lower case as capitals)')

    # --- message font: STCFN033-090 in the cartridge font's colours
    old = open(os.path.join(keep, 'ART', 'rlfont.def0'), 'rb').read()
    cand = sorted(set(old) - {0})
    fcols = cg[np.array(cand)]
    out = bytearray(64)                                  # char 32: blank
    for ch in range(33, 91):
        t = np.zeros((8, 8), np.uint8)
        d = wa.get('STCFN%03d' % ch)
        if d:
            g = WadArt.patch(d)[:8, :8]
            m = g >= 0
            q = nearest(wa.palette[np.where(m, g, 0)], cand, fcols)
            t[:g.shape[0], :g.shape[1]] = np.where(m, q, 0)
        else:
            t = np.frombuffer(old[64 * (ch - 32):64 * (ch - 31)], np.uint8).reshape(8, 8)
        out += t.tobytes()
    put('ART/rlfont.def0', bytes(out), raw=True)

    for k, (n, mg, kept) in report.items():
        log('%-11s %4d tiles%s%s' % (k, n, ', %d merged to fit 256' % mg if mg else '',
                                     ', from the cartridge: ' + ', '.join(kept) if kept else ''))
    log('title       quantised to 7 palettes (mean squared error %.0f), skull and message font from the WAD' % err)

    # --- --cart ITEM,...: keep the cartridge's version of these
    for item in filter(None, (a.cart or '').split(',')):
        if item not in CART_ITEMS:
            sys.exit('--cart: %s? (%s)' % (item, ', '.join(CART_ITEMS)))
        for f in CART_ITEMS[item]:
            if os.path.exists(os.path.join(keep, f)):    # (no backup: never converted, still the cartridge's)
                shutil.copy2(os.path.join(keep, f), os.path.join(rl, f))
        log('%-11s the cartridge\'s' % item)


# ---------------------------------------------------------------- compare / restore
def sheet(a, comp, rgbfile):
    """title + menus of a COMP directory as one RGB image"""
    cg = bgr555_to_rgb(open(rgbfile, 'rb').read()[:512])
    pal = np.array([(0, 0, 0)] + [cg[PAL * 16 + i] for i in range(1, 16)], np.uint8)
    parts = []
    t0 = comp_read(os.path.join(comp, 'title.def.0')); t1 = comp_read(os.path.join(comp, 'title.def.1'))
    chars = t0 + bytes(0x4000 - len(t0)) + t1
    m = comp_read(os.path.join(comp, 'title.map0'))
    tp = bgr555_to_rgb(comp_read(os.path.join(comp, 'title.rgb')))
    w = struct.unpack('<%dH' % (len(m) // 2), m)
    ti = np.zeros((224, 256, 3), np.uint8)
    for i, e in enumerate(w[:896]):
        t = decode_tile(chars, 32 * (e & 0x3FF), 4)
        t = t[:, ::-1] if e & 0x4000 else t
        t = t[::-1] if e & 0x8000 else t
        r, c = divmod(i, 32)
        p = (e >> 10) & 7
        ti[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = np.array([tp[p * 16 + v] for v in t.flatten()]).reshape(8, 8, 3)
    parts.append(ti)
    for name, d in (('PauseMenu', None), ('SkillMenu', None), ('EpisodeMenu', None), ('SaveMenu', 'SlotMenu')):
        parts.append(pal[menu_image(comp, name, d)])
    sk = comp_read(os.path.join(comp, 'MenuSkulls.def0'))
    obj = np.array([(0, 0, 0)] + [cg[128 + i] for i in range(1, 16)], np.uint8)
    s = np.zeros((16, 32), np.uint8)
    for k, (y, x) in enumerate([(0, 0), (0, 8), (0, 16), (0, 24), (8, 0), (8, 8), (8, 16), (8, 24)]):
        s[y:y + 8, x:x + 8] = decode_tile(sk, 32 * k, 4)
    sk_img = np.zeros((16, 256, 3), np.uint8); sk_img[:, :32] = obj[s]
    parts.append(sk_img)
    return np.concatenate([np.pad(p, ((0, 6), (0, 0), (0, 0))) for p in parts])


def compare(a):
    rl = os.path.join(a.data, 'RLDATA')
    A = sheet(a, os.path.join(a.data, 'RLART.fx3', 'COMP'), os.path.join(rl, 'COLOUR', 'BASERGB.RGB'))
    B = sheet(a, os.path.join(rl, 'COMP'), os.path.join(rl, 'COLOUR', 'BASERGB.RGB'))
    im = Image.fromarray(np.concatenate([A, np.zeros((A.shape[0], 8, 3), np.uint8), B], 1))
    os.makedirs(a.png, exist_ok=True)
    im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(os.path.join(a.png, 'art.png'))
    log('sheet (cartridge left, converted right): %s' % os.path.join(a.png, 'art.png'))


def restore(a):
    keep = os.path.join(a.data, 'RLART.fx3')
    for f in FILES + [f for ep in (1, 2, 3) for f in SCOREFILES(ep)] + ['COMP/TextFont.def0']:
        if os.path.exists(os.path.join(keep, f)):         # (score screens / TextFont: saved by --intermission, --interpic / --textfont)
            shutil.copy2(os.path.join(keep, f), os.path.join(a.data, 'RLDATA', f))
    for f in os.listdir(os.path.join(a.data, 'RLDATA', 'COMP')):   # (--level-names: none on the cartridge)
        if f.startswith('ScoreName'):
            os.remove(os.path.join(a.data, 'RLDATA', 'COMP', f))
    if os.path.exists(os.path.join(a.data, 'RLDATA', 'ART', 'ScoreName.rgb')):
        os.remove(os.path.join(a.data, 'RLDATA', 'ART', 'ScoreName.rgb'))
    log('cartridge title, menus and fonts restored')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[1])
    ap.add_argument('cmd', choices=('learn', 'convert', 'compare', 'restore'))
    ap.add_argument('--data', default=os.path.join(HERE, '..', 'data'))
    ap.add_argument('--wad', action='append', default=[])
    ap.add_argument('--png', default='.')
    ap.add_argument('--cart', metavar='ITEM,...', help='convert: keep the cartridge version of these: skill, episode, skull, font, textfont')
    ap.add_argument('--order', metavar='LUMP', help='convert: the order screen from this picture lump (shareware: HELP2)')
    ap.add_argument('--title', help='convert: this 256x224 picture as the title screen instead of TITLEPIC')
    ap.add_argument('--textfont', action='store_true',
                    help='convert: also the start screen/credits/end-text font from the WAD (STCFN033-095)')
    ap.add_argument('--level-names', action='store_true',
                    help='convert: the level names above FINISHED on the score page (CWILVnn / WILVem)')
    ap.add_argument('--interpic', action='store_true',
                    help='convert: the DOOM II score screen from the WAD (INTERPIC -> ScoreE1, every level)')
    ap.add_argument('--intermission', action='store_true',
                    help='convert: also the Episode 1-3 score screens from the WAD (WIMAP0-2)')
    ap.add_argument('--episodes', type=int, default=0,
                    help='convert: the episode menu shows only the first N episodes (as levels.inc !RLEPISODES)')
    a = ap.parse_args()
    {'learn': learn, 'convert': convert, 'compare': compare, 'restore': restore}[a.cmd](a)


if __name__ == '__main__':
    main()
