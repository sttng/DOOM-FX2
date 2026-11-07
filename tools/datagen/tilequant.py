"""
tilequant.py -- convert a full-colour (e.g. FX3 8bpp) SNES screen into 4bpp tiles with
N sub-palettes of 16 colours (index 0 = shared backdrop colour), as needed by the
engine's Mode-1 screens (title: 7 palettes, intermission maps: 6 palettes).

Iterative tile-palette k-means:
  1. cluster tiles by colour content into N groups
  2. per group k-means 15 colours (+ fixed backdrop colour as index 0)
  3. reassign every tile to the palette with least squared error, repeat
Colours are snapped to BGR555.  dedupe() then removes duplicate tiles (incl. H/V flips).
"""
import numpy as np

def _snap555(c):
    c = np.clip(np.round(np.asarray(c, float) / 255.0 * 31.0), 0, 31)
    return (c * 255.0 / 31.0)

def _kmeans(px, w, k, init=None, iters=12, rng=None):
    """weighted k-means on Nx3 points. returns centers kx3"""
    rng = rng or np.random.default_rng(1)
    n = len(px)
    if n == 0: return np.zeros((k, 3))
    uniq, inv = np.unique(px, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    uw = np.bincount(inv, weights=w, minlength=len(uniq))
    if len(uniq) <= k:
        c = np.zeros((k, 3)); c[:len(uniq)] = uniq
        if len(uniq): c[len(uniq):] = uniq[0]
        return c
    if init is None:
        # k-means++ on unique colours
        c = [uniq[np.argmax(uw)]]
        for _ in range(1, k):
            d = np.min(((uniq[:, None, :] - np.array(c)[None]) ** 2).sum(-1), axis=1) * uw
            if d.sum() <= 0: c.append(uniq[rng.integers(len(uniq))]); continue
            c.append(uniq[rng.choice(len(uniq), p=d / d.sum())])
        c = np.array(c, float)
    else:
        c = np.array(init, float)
    for _ in range(iters):
        d = ((uniq[:, None, :] - c[None]) ** 2).sum(-1)
        a = np.argmin(d, axis=1)
        for j in range(k):
            m = a == j
            if uw[m].sum() > 0: c[j] = (uniq[m] * uw[m, None]).sum(0) / uw[m].sum()
    return c

W = np.array([0.30, 0.59, 0.11]) * 3   # luminance-ish weighting of squared errors

def quantize(img, npal, backdrop=(0, 0, 0), iters=6, seed=1, fixed_pals=None):
    """img: HxWx3 uint8 (H,W multiples of 8).  Returns (tiles[n,8,8] idx, tilepal[n],
    palettes[npal,16,3], mean squared error per pixel); tile order = raster order of
    the screen (no dedupe).  fixed_pals is not used."""
    rng = np.random.default_rng(seed)
    H, Wd, _ = img.shape
    ty, tx = H // 8, Wd // 8
    T = img.reshape(ty, 8, tx, 8, 3).transpose(0, 2, 1, 3, 4).reshape(ty * tx, 64, 3).astype(float)
    bd = _snap555(backdrop)
    nt = len(T)
    # init: cluster tiles by mean colour + spread
    feat = np.concatenate([T.mean(1), T.std(1)], 1)
    # simple k-means on features
    cent = feat[rng.choice(nt, npal, replace=False)]
    for _ in range(25):
        a = np.argmin(((feat[:, None] - cent[None]) ** 2).sum(-1), 1)
        for j in range(npal):
            if (a == j).any(): cent[j] = feat[a == j].mean(0)
    assign = a
    pals = np.zeros((npal, 16, 3))
    def fit_palettes(assign):
        for j in range(npal):
            pts = T[assign == j].reshape(-1, 3)
            if len(pts) == 0:
                pts = T[rng.integers(nt)].reshape(-1, 3)
            # pixels close to backdrop are served by index 0: drop them from fitting
            dbd = (((pts - bd) ** 2) * W).sum(1)
            keep = dbd > 3 * 3 * 3
            if keep.sum() < 15: keep[:] = True
            c = _kmeans(pts[keep], np.ones(keep.sum()), 15, rng=rng)
            pals[j, 0] = bd
            pals[j, 1:] = _snap555(c)
    def tile_errors():
        # nt x npal error
        E = np.zeros((nt, npal))
        for j in range(npal):
            d = (((T[:, :, None, :] - pals[j][None, None]) ** 2) * W).sum(-1)   # nt,64,16
            E[:, j] = d.min(-1).sum(1)
        return E
    fit_palettes(assign)
    for it in range(iters):
        E = tile_errors()
        assign = np.argmin(E, 1)
        fit_palettes(assign)
    E = tile_errors(); assign = np.argmin(E, 1)
    tiles = np.zeros((nt, 8, 8), np.uint8)
    for j in range(npal):
        m = assign == j
        if not m.any(): continue
        d = (((T[m][:, :, None, :] - pals[j][None, None]) ** 2) * W).sum(-1)
        tiles[m] = d.argmin(-1).reshape(-1, 8, 8)
    err = float(E[np.arange(nt), assign].sum() / (nt * 64))
    return tiles, assign, pals.round().astype(int), err

def dedupe(tiles, tilepal, start=0, allow_flip=True):
    """-> (unique_tiles list, map entries list(int16) raster order)."""
    uniq = []; lut = {}; entries = []
    for t, p in zip(tiles, tilepal):
        found = None
        variants = [(t, 0)]
        if allow_flip:
            variants += [(t[:, ::-1], 0x4000), (t[::-1, :], 0x8000), (t[::-1, ::-1], 0xc000)]
        for v, fl in variants:
            k = v.tobytes()
            if k in lut: found = (lut[k], fl); break
        if found is None:
            idx = len(uniq); uniq.append(t.copy()); lut[t.tobytes()] = idx; found = (idx, 0)
        entries.append(((found[0] + start) & 0x3ff) | (int(p) << 10) | found[1])
    return uniq, entries
