#!/usr/bin/env python3
"""
wallset.py -- a wall set made for the maps of a WAD (wad2gfx.py convert --map-walls).

The cartridge has 67 wall slots, chosen for DOOM; a DOOM II map converted with
them shows DOOM walls in place of most of its textures.  This builds the wall
set from the textures the maps use, as close to the PC as the GamePak ROM
allows:

  usage   each texture's area in the maps (wall length x visible height of
          every upper, lower and one-sided middle part), and how it is pegged
          (top/bottom); two-sided middles are not walls: masked_usage ranks
          them for wad2gfx.py add_masked (see-through ones drawn as images)
  slots   up to 252 walls besides the 4 skies (wall format 2/3: faces name
          walls by index).  Textures are ranked by area x how different they look
          from the closest other texture (choose_slots), or chosen to keep the
          area-weighted 1-SSIM lowest (choose_slots_ssim, --slots-by likeness);
          the rest are shown as the closest slot.  A switch (SW1*) brings its
          other state (SW2*) along, with the same area also when the maps never
          show that state (usage): the alternate texture of TEXTURE2.TBL.
  art     the WAD texture in the SNES colours, its height padded to a power of
          two by repeating it (laid out for the pegging most of its area uses),
          cut to one repeat where it repeats exactly
  columns (wall format 2, run-length strips; format 3 is tools/wallvq.py)
          every stored wall column is a pointer to a strip, so columns of any
          wall of the same height can share one strip.  Two ways to fit:
          * column step: a wall keeps every 2nd or 4th column (wall format 2's
            header byte), for the wall table (3 bytes per stored column, in
            the GamePak ROM space the levels share)
          * strip sharing: clusters of similar columns shown as one stored
            strip, merged least visible error per byte saved first (error:
            squared RGB distance to the WAD colours x area per texel), until
            the strips fit the banks
          (wad2gfx.py map_walls: half size walls, every 2nd column and texel row
          pair as the 2x2 block means; chosen per wall by the blurred error)
Nothing here is game data: everything is computed from the user's WAD.
"""
import collections, heapq, sys, os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

MAXSLOTS = 252                       # + 4 skies = 256 wall indexes (one byte in the faces)
GAMMA = 0.75                         # weight = area ** GAMMA (big walls count, small ones still do)


def pow2ceil(n):
    p = 1
    while p < n:
        p *= 2
    return p


# ------------------------------------------------------------------ usage
def usage(wadfiles, maps):
    """{texture: area}, {texture: [top-pegged area, bottom-pegged area]}"""
    from wad2rl import Wad
    w = Wad(*wadfiles)
    area = collections.Counter()
    peg = collections.defaultdict(lambda: [0.0, 0.0])
    for mn in maps:
        try:
            m = w.map(mn)
        except KeyError:
            continue
        V = m.vertexes
        for l in m.lines:
            (x1, y1), (x2, y2) = V[l['v1']], V[l['v2']]
            ln = ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5
            for sd, od in ((l['right'], l['left']), (l['left'], l['right'])):
                if sd < 0:
                    continue
                s = m.sides[sd]
                me = m.sectors[s['sector']]
                parts = []
                if od >= 0 and s['mid'] not in ('-', ''):
                    area[s['mid']] += 0           # (not a wall: only named, so the wall map shows it as a look-alike)
                if od < 0:
                    parts.append((s['mid'], me['ceil'] - me['floor'], 1 if l['flags'] & 0x10 else 0))
                else:
                    ot = m.sectors[m.sides[od]['sector']]
                    if ot['floor'] > me['floor']:
                        parts.append((s['lower'], ot['floor'] - me['floor'], 0))
                    if ot['ceil'] < me['ceil'] and not (me['ctex'] == 'F_SKY1' and ot['ctex'] == 'F_SKY1'):
                        h = me['ceil'] - max(ot['ceil'], me['floor'])
                        parts.append((s['upper'], h, 0 if l['flags'] & 0x08 else 1))
                for nm, h, bot in parts:
                    if nm in ('-', '') or h <= 0:
                        continue
                    a = ln * min(h, 256)
                    area[nm] += a
                    peg[nm][bot] += a
    # a switch shows its other state once pressed (SW1 <-> SW2, TEXTURE2.TBL): as much area
    for nm in [n for n in area if n[:3] in ('SW1', 'SW2')]:
        o = ('SW2' if nm[:3] == 'SW1' else 'SW1') + nm[3:]
        if area[nm] > area.get(o, 0):
            area[o] = area[nm]; peg[o] = list(peg[nm])
    return area, peg


def masked_usage(wadfiles, maps):
    """{texture: area} of the middle textures of two-sided lines (masked: grates, bars, fences)"""
    from wad2rl import Wad
    w = Wad(*wadfiles)
    area = collections.Counter()
    for mn in maps:
        try:
            m = w.map(mn)
        except KeyError:
            continue
        V = m.vertexes
        for l in m.lines:
            if l['left'] < 0 or l['right'] < 0:
                continue
            (x1, y1), (x2, y2) = V[l['v1']], V[l['v2']]
            ln = ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5
            for sd in (l['right'], l['left']):
                nm = m.sides[sd]['mid']
                if nm not in ('-', ''):
                    area[nm] += max(ln, 1.0)
    return area


# ------------------------------------------------------------------ art
class Tex:
    """one WAD texture as a wall: pix[y, x] = SNES pixel value, ref[y, x] = WAD RGB"""
    def __init__(self, name, idx, palw, wadrgb, bottom):
        H, W = idx.shape
        self.name, self.H0, self.W0 = name, H, W
        Hp, Wp = min(pow2ceil(H), 128), min(pow2ceil(W), 256)       # (the engine: at most 256 wide; TNT has 512)
        r0 = (Hp - H) % H if bottom and Hp > H else 0       # bottom pegged: WAD row H-1 at Hp-1
        ys = (np.arange(Hp) - r0) % H
        xs = np.arange(Wp) % W
        a = idx[ys][:, xs]
        a = np.where(a >= 0, a, 0)
        self.r0, self.bottom = r0, bottom
        # one repeat where it repeats exactly
        for axis in ((1, 0) if Hp == H else (1,)):        # (padded: rows keep the layout r0)
            n = a.shape[axis]
            p = 1
            while p < n and not (n % p == 0 and np.array_equal(a, np.roll(a, p, axis=axis))):
                p *= 2
            a = a[:, :p] if axis == 1 else a[:p]
        self.idx = a
        self.pix = palw[a]
        self.ref = wadrgb[a].astype(np.float32)
        self.h, self.w = a.shape


def look(t, n=16):
    """the texture tiled to 256x128 and averaged in 16x16 blocks -> (8, 16, 3)"""
    r = t.ref
    ys, xs = np.arange(128) % r.shape[0], np.arange(256) % r.shape[1]
    big = r[ys][:, xs]
    return big.reshape(128 // n, n, 256 // n, n, 3).mean((1, 3))


def look_dist(a, b):
    """least mean squared distance over horizontal shifts of b"""
    best = None
    for dx in range(0, b.shape[1], 2):
        d = float(((a - np.roll(b, dx, axis=1)) ** 2).sum(-1).mean())
        best = d if best is None or d < best else best
    return best


# ------------------------------------------------------------------ slots
def choose_slots(texs, weight, maxslots=MAXSLOTS, force=()):
    """-> (slot names in order, {name: slot name shown})"""
    names = sorted(texs)
    L = {n: look(texs[n]) for n in names}
    near = {}
    for n in names:
        near[n] = min(((look_dist(L[n], L[c]), c) for c in names if c != n), default=(0.0, n))
    # value of a slot: its area x how far the closest other texture is
    rank = sorted(names, key=lambda n: -(weight.get(n, 0) * (near[n][0] + 1.0)))
    chosen, have = [], set()

    def add(n):
        if n not in have:
            chosen.append(n); have.add(n)
    for n in list(force):
        if n in texs:
            add(n)
    for n in rank:
        pair = []
        if n.startswith('SW1') or n.startswith('SW2'):
            o = ('SW2' if n.startswith('SW1') else 'SW1') + n[3:]
            if o in texs:
                pair = [o]
        need = [x for x in [n] + pair if x not in have]
        if len(chosen) + len(need) > maxslots:
            continue
        for x in need:
            add(x)
    alias = {}
    for n in names:
        if n in have:
            alias[n] = n
        else:
            alias[n] = min(((look_dist(L[n], L[c]), c) for c in chosen), key=lambda x: x[0])[1]
    return chosen, alias


# ------------------------------------------------------------------ slots by visible likeness
def thumb(t):
    """the texture tiled to 256x128, blurred and averaged in 4x4 blocks -> (32, 64, 3)"""
    r = t.ref
    ys, xs = np.arange(128) % r.shape[0], np.arange(256) % r.shape[1]
    big = blur(r[ys][:, xs])
    return big.reshape(32, 4, 64, 4, 3).mean((1, 3))


def _g(x):
    """gaussian (sigma 1) over the last two spatial axes, wrapping"""
    k = np.exp(-np.arange(-3, 4) ** 2 / 2.0); k /= k.sum()
    for ax in (-3, -2):
        x = sum(k[i] * np.roll(x, i - 3, ax) for i in range(7))
    return x


def likeness(texs, names):
    """D[i, j] = 1 - SSIM of texture i shown as texture j (best of 4 horizontal shifts),
    on 32x64 thumbnails: how different i looks when j stands in for it"""
    T = np.stack([thumb(texs[n]) for n in names])                    # (N, 32, 64, 3)
    C1, C2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    mu = _g(T); var = _g(T * T) - mu * mu
    N = len(names)
    D = np.ones((N, N))
    for sh in (0, 16, 32, 48):
        S = np.roll(T, sh, 2); ms = np.roll(mu, sh, 2); vs = np.roll(var, sh, 2)
        for i in range(N):
            cov = _g(T[i][None] * S) - mu[i][None] * ms
            ss = ((2 * mu[i][None] * ms + C1) * (2 * cov + C2)) / ((mu[i][None] ** 2 + ms ** 2 + C1) * (var[i][None] + vs + C2))
            D[i] = np.minimum(D[i], 1.0 - ss.mean((1, 2, 3)))
    np.fill_diagonal(D, 0.0)
    return np.maximum(D, 0.0)


# walls that tell the player something: always a slot of their own
KEEP = ('DOORBLU', 'DOORRED', 'DOORYEL', 'DOORBLU2', 'DOORRED2', 'DOORYEL2', 'EXITDOOR', 'EXITSIGN')


def choose_slots_ssim(texs, weight, maxslots=MAXSLOTS, own=0.07, boost=None, log=print, force=()):
    """slots that keep the area-weighted visible difference lowest: greedy facility
    location, each texture costs weight x (OWN if it has a slot, else 1 - SSIM to the
    slot shown for it).  A switch brings its other state along.
    -> (slot names in order, {name: slot name shown})"""
    names = sorted(texs)
    idx = {n: i for i, n in enumerate(names)}
    D = likeness(texs, names)
    # a switch is only shown as a switch in the same state (SW1 as SW1, SW2 as SW2: the
    # alternate texture table then flips it to the right partner), other walls never as one
    kind = np.array([n[:3] if n[:3] in ('SW1', 'SW2') else '' for n in names])
    D[kind[:, None] != kind[None, :]] = 1.0
    w = np.array([weight.get(n, 0.0) * (boost.get(n, 1.0) if boost else 1.0) for n in names])
    w = np.maximum(w, 1e-6)
    Dc = D + own * np.eye(len(names))                  # (shown as itself: OWN)
    best = np.full(len(names), 1.0)                     # nothing chosen: everything differs fully
    chosen, have = [], set()

    def gain(js):
        b = best.copy()
        for j in js:
            b = np.minimum(b, Dc[:, j])
        return float((w * (best - b)).sum())

    def take(js):
        nonlocal best
        for j in js:
            best = np.minimum(best, Dc[:, j])
            chosen.append(names[j]); have.add(names[j])
    for n in force:                                    # (wad2gfx.py passes KEEP)
        if n in texs and n not in have:
            take([idx[n]])
    while len(chosen) < maxslots:
        top = None
        for n in names:
            if n in have:
                continue
            grp = [n]
            if n[:3] in ('SW1', 'SW2'):
                o = ('SW2' if n[:3] == 'SW1' else 'SW1') + n[3:]
                if o in texs and o not in have:
                    grp.append(o)
            if len(chosen) + len(grp) > maxslots:
                continue
            g = gain([idx[x] for x in grp]) / len(grp)
            if top is None or g > top[0]:
                top = (g, grp)
        if top is None or top[0] <= 0:
            break
        take([idx[x] for x in top[1]])
    cj = [idx[c] for c in chosen]
    alias = {n: names[cj[int(np.argmin(Dc[idx[n], cj]))]] if n not in have else n for n in names}
    cost = float((w * best).sum() / w.sum())
    log('slots  : %d chosen by visible likeness; area-weighted 1-SSIM %.3f (thumbnails)' % (len(chosen), cost))
    return chosen, alias


# ------------------------------------------------------------------ column step
def group_error(t, s):
    """squared error of showing each group of 2**s columns as its group mean (per texel weight 1)"""
    g = 1 << s
    if t.w < g:
        return None
    R = t.ref.reshape(t.h, t.w // g, g, 3)
    return float(((R - R.mean(2, keepdims=True)) ** 2).sum())


def choose_steps(slots, texs, a_tex, dat_budget, ntbl, min_step=0):
    """column step per slot: 0 (all), 1 (every 2nd), 2 (every 4th) so that the wall
    table fits DAT_BUDGET, least added error per byte saved first; at least MIN_STEP
    (where the wall is that wide)"""
    ms = min_step if isinstance(min_step, dict) else {n: min_step for n in slots}
    s = {n: min(ms.get(n, 0), max(0, texs[n].w.bit_length() - 2)) for n in slots}

    def dat():
        return sum(3 + 3 * (texs[n].w >> s[n]) for n in slots) + 2 * ntbl
    ge = {n: [group_error(texs[n], k) for k in range(3)] for n in slots}
    heap = []
    for n in slots:
        k = s[n] + 1
        if k <= 2 and ge[n][k] is not None:
            w = texs[n].w
            heap.append((a_tex[n] * (ge[n][k] - ge[n][k - 1]) / (3 * ((w >> (k - 1)) - (w >> k))), n, k))
    heapq.heapify(heap)
    d = dat()
    lam = 0.0
    while d > dat_budget and heap:
        lam, n, k = heapq.heappop(heap)
        if s[n] != k - 1:
            continue
        w = texs[n].w
        d -= 3 * ((w >> (k - 1)) - (w >> k))
        s[n] = k
        if k < 2 and ge[n][k + 1] is not None:
            heapq.heappush(heap, (a_tex[n] * (ge[n][k + 1] - ge[n][k]) / (3 * ((w >> k) - (w >> (k + 1)))), n, k + 1))
    return s, d, lam


# ------------------------------------------------------------------ strip sharing
def share_strips(items, rgb, encode, budget, log=print):
    """items: list of (height, weight m, mean RGB vector mu (h*3), own strip (h pixel values,
    top->bottom)).  Clusters items with one stored strip each until the strip bytes fit
    BUDGET.  -> (strip per item (tuple of pixel values), strip bytes, last merge's error/byte)"""
    # clusters start as the distinct own strips
    key = {}
    cl_items = []
    for i, (h, m, mu, own) in enumerate(items):
        k = (h, own)
        if k not in key:
            key[k] = len(cl_items); cl_items.append([])
        cl_items[key[k]].append(i)
    n = len(cl_items)
    rep = [None] * n
    H = np.zeros(n, int)
    for k, c in key.items():
        rep[c] = k[1]; H[c] = k[0]
    nbytes = np.array([len(encode(list(rep[c])[::-1])) for c in range(n)])
    total = int(nbytes.sum())
    log('strips : %d distinct columns, %d bytes; budget %d' % (n, total, budget))
    if total <= budget:
        return [rep[key[(it[0], it[3])]] for it in items], total, 0.0
    # stats per cluster (float64 for the sums)
    M = np.zeros(n); Q = np.zeros(n)
    S = [None] * n
    for c in range(n):
        ii = cl_items[c]
        ms = np.array([items[i][1] for i in ii])
        mus = np.stack([items[i][2] for i in ii]).astype(np.float64)
        M[c] = ms.sum(); S[c] = (ms[:, None] * mus).sum(0); Q[c] = float((ms * (mus ** 2).sum(1)).sum())
    R = [rgb[np.array(rep[c])].reshape(-1).astype(np.float64) for c in range(n)]

    def err(c, r):
        return Q[c] - 2 * float(S[c] @ r) + M[c] * float(r @ r)
    E = np.array([err(c, R[c]) for c in range(n)])
    alive = np.ones(n, bool)
    version = np.zeros(n, int)
    byh = collections.defaultdict(list)
    for c in range(n):
        byh[int(H[c])].append(c)
    # per height: matrix of reps (float32) for the nearest search
    mats = {}
    for h, cs in byh.items():
        idx = np.array(cs)
        Rm = np.stack([R[c] for c in cs]).astype(np.float32)
        mats[h] = [idx, Rm, (Rm.astype(np.float64) ** 2).sum(1)]

    def best(c):
        idx, Rm, RR = mats[int(H[c])]
        sc = -2.0 * (Rm @ S[c].astype(np.float32)).astype(np.float64) + M[c] * RR
        sc[~alive[idx]] = np.inf
        sc[idx == c] = np.inf
        j = int(np.argmin(sc))
        if not np.isfinite(sc[j]):
            return None, None
        l = int(idx[j])
        return l, (Q[c] + sc[j]) - E[c]
    heap = []
    for h, (idx, Rm, RR) in mats.items():
        if len(idx) < 2:
            continue
        Sm = np.stack([S[c] for c in idx]).astype(np.float32)
        for a0 in range(0, len(idx), 2048):
            sc = -2.0 * (Sm[a0:a0 + 2048] @ Rm.T).astype(np.float64) + M[idx[a0:a0 + 2048], None] * RR[None, :]
            for r_, c in enumerate(idx[a0:a0 + 2048]):
                sc[r_, a0 + r_] = np.inf
            js = sc.argmin(1)
            for r_, c in enumerate(idx[a0:a0 + 2048]):
                l = int(idx[js[r_]])
                d = Q[c] + sc[r_, js[r_]] - E[c]
                heap.append((max(d, 0.0) / nbytes[c], int(c), l, 0, 0))
    heapq.heapify(heap)
    lam = 0.0
    merges = 0
    while total > budget and heap:
        p, c, l, vc, vl = heapq.heappop(heap)
        if not alive[c] or version[c] != vc:
            continue
        if not alive[l] or version[l] != vl:
            l2, d = best(c)
            if l2 is not None:
                heapq.heappush(heap, (max(d, 0.0) / nbytes[c], c, l2, int(version[c]), int(version[l2])))
            continue
        # merge c into l; l keeps the better of the two strips
        M[l] += M[c]; S[l] = S[l] + S[c]; Q[l] += Q[c]
        el, ec = err(l, R[l]), err(l, R[c])
        total -= int(nbytes[c])
        if ec < el:
            # l takes c's strip: l's bytes become c's
            total += int(nbytes[c]) - int(nbytes[l])
            rep[l], R[l], nbytes[l] = rep[c], R[c], nbytes[c]
            idx, Rm, RR = mats[int(H[l])]
            j = int(np.searchsorted(idx, l))
            Rm[j] = R[l].astype(np.float32); RR[j] = float(R[l] @ R[l])
            el = ec
        E[l] = el
        alive[c] = False
        cl_items[l] += cl_items[c]; cl_items[c] = []
        version[l] += 1
        lam = p
        merges += 1
        l2, d = best(l)
        if l2 is not None:
            heapq.heappush(heap, (max(d, 0.0) / nbytes[l], l, l2, int(version[l]), int(version[l2])))
        if merges % 2000 == 0:
            log('  %d merges, %d bytes' % (merges, total))
    out = [None] * len(items)
    for c in range(n):
        if alive[c]:
            for i in cl_items[c]:
                out[i] = rep[c]
    log('strips : %d merges, %d bytes in %d strips; last merge %.1f error/byte'
        % (merges, total, int(alive.sum()), lam))
    return out, total, lam


# ------------------------------------------------------------------ run-friendly strips
def blur(img):
    """[1 2 1]/4 twice in x and y, wrapping (about a 1-texel gaussian)"""
    x = img.astype(np.float64)
    for ax in (0, 1):
        for _ in range(2):
            x = (np.roll(x, 1, ax) + 2 * x + np.roll(x, -1, ax)) / 4.0
    return x


def edge_weights(ref, g, k, strength):
    """per stored texel weight 1 + STRENGTH * (horizontal edge strength): the texture
    smoothed across 7 columns (noise averages out, mortar lines and panel edges do not),
    then its change from row to row.  Lines across the texture are what a column-by-column
    simplification would drop first; this keeps them.  -> (h/k, w/g)"""
    h, w, _ = ref.shape
    sm = sum(np.roll(ref, d, axis=1) for d in range(-3, 4)) / 7.0
    dy = np.sqrt(((sm - np.roll(sm, 1, axis=0)) ** 2).sum(-1))
    e = np.maximum(dy, np.roll(dy, -1, axis=0))                     # both rows at an edge
    e = e.reshape(h // k, k, w // g, g).max((1, 3))
    return 1.0 + strength * np.minimum(e / 24.0, 3.0)


def simplify(items, rgb, colours, lam, kmax=32, log=print, weights=None):
    """Each item's own strip re-chosen to minimise  m * squared error + LAM * bytes  over
    encodings as literal pixels (1 byte each + 1 per group) and runs of 3..KMAX pixels of
    one colour (2 bytes): long smooth stretches become runs.  COLOURS: the pixel values a
    run may use.  WEIGHTS: per item, per texel error weights (edge_weights).
    -> items with the new own strips"""
    if lam <= 0:
        return items
    C = rgb[np.array(colours)].astype(np.float32)                   # (nc, 3)
    cc = (C ** 2).sum(1)
    out = list(items)
    byh = collections.defaultdict(list)
    for i, it in enumerate(items):
        byh[it[0]].append(i)
    for h, ii in byh.items():
        N = len(ii)
        T = np.stack([items[i][2].reshape(h, 3) for i in ii]).astype(np.float32)   # targets (N, h, 3)
        P = np.stack([np.array(items[i][3]) for i in ii])                          # pixels (N, h)
        m = np.array([items[i][1] for i in ii], np.float64)
        Wt = np.stack([weights[i] for i in ii]).astype(np.float64) if weights is not None else np.ones((N, h))
        elit = ((T - rgb[P]) ** 2).sum(-1) * m[:, None] * Wt                       # (N, h)
        P1 = np.concatenate([np.zeros((N, 1, 3), np.float32), np.cumsum(T * Wt[:, :, None].astype(np.float32), 1)], 1)
        P2 = np.concatenate([np.zeros((N, 1)), np.cumsum((T.astype(np.float64) ** 2).sum(-1) * Wt, 1)], 1)
        P0 = np.concatenate([np.zeros((N, 1)), np.cumsum(Wt, 1)], 1)
        INF = 1e30
        A = np.full((N, h + 1), INF); L = np.full((N, h + 1), INF)
        A[:, 0] = 0.0
        bA = np.zeros((N, h + 1), np.int16)        # run length that ended here
        bAc = np.zeros((N, h + 1), np.int16)       # its colour (index into colours)
        bAf = np.zeros((N, h + 1), np.int8)        # came from A (0) or L (1)
        bL = np.zeros((N, h + 1), np.int8)         # L: 0 = new group after A, 1 = continued
        for i in range(1, h + 1):
            new, cont = A[:, i - 1] + 2 * lam, L[:, i - 1] + lam
            bL[:, i] = cont < new
            L[:, i] = np.minimum(new, cont) + elit[:, i - 1]
            for k in range(3, min(kmax, i) + 1):
                j = i - k
                S1 = P1[:, i] - P1[:, j]                                   # (N, 3)
                D = (P0[:, i] - P0[:, j])[:, None] * cc[None, :] - 2 * (S1 @ C.T)   # (N, nc)
                c = D.argmin(1)
                err = (P2[:, i] - P2[:, j]) + D[np.arange(N), c]
                prev = np.minimum(A[:, j], L[:, j])
                cost = prev + 2 * lam + m * np.maximum(err, 0)
                better = cost < A[:, i]
                if better.any():
                    A[better, i] = cost[better]; bA[better, i] = k; bAc[better, i] = c[better]
                    bAf[better, i] = (L[better, j] < A[better, j])
        for r, idx in enumerate(ii):
            px = list(items[idx][3])
            i, inA = h, A[r, h] <= L[r, h]
            while i > 0:
                if inA:
                    k = int(bA[r, i]); c = colours[int(bAc[r, i])]
                    px[i - k:i] = [c] * k
                    inA = not bAf[r, i]
                    i -= k
                else:
                    inA = not bL[r, i]
                    i -= 1
            it = items[idx]
            out[idx] = (it[0], it[1], it[2], tuple(px))
    log('run-friendly strips (lambda %g): done' % lam)
    return out
