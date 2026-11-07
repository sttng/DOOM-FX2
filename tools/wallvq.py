#!/usr/bin/env python3
"""
wallvq.py - block vector quantisation of the wall set (wall format 3).

Each slot texture (or, for a half size slot, its 2x2 box means) is cut into
blocks of 2 columns x 4 rows; a block is stored as one byte, an index into a
codebook of 256 blocks.  The walls are put in groups of similar colours; each
group has its own codebook (2048 bytes, k-means in RGB weighted by the wall
area a texel stands for, each texel the SNES colour nearest the centroid's).
A group (codebook + the indices of its walls) is placed in one ROM bank, so
the engine reads index and codebook without a bank switch.

ROM layout of one wall's indices: block columns left to right, each the
column's blocks bottom up (rowbytes = stored height / 4 bytes per block
column).  A codebook is 8 planes of 256 bytes, plane p = 4 * column + row
(the block's column 0-1 and row 0-3 from the bottom) holding that texel of
every entry.  Texel (stored column sc, row r from the bottom):
    codebook + 1024 * (sc & 1) + 256 * (r & 3) + index[(sc >> 1) * rowbytes + (r >> 2)]

used by wad2gfx.py --vq (map_walls_vq, place3, wall_header3, read_rldata).
"""
import numpy as np

BW, BH = 2, 4                       # block: 2 columns x 4 rows
NE = 256                            # codebook entries
CB_BYTES = NE * BW * BH
MIN_GROUPS = 24                     # fewer codebooks than this: more walls at half size instead
SWITCH_WEIGHT = 8                   # switches (SW1*/SW2*): their texels count this much more in the
                                    # codebooks (small lamps and levers need colours of their own)


def is_switch(n):
    return n[:3] in ('SW1', 'SW2')


def can_half(t):
    return t.h >= 2 * BH and t.w >= 2 * BW


def stored_ref(t, half):
    """RGB the wall stores, top row first: the texture or its 2x2 box means"""
    r = t.ref
    if half:
        r = r.reshape(t.h // 2, 2, t.w // 2, 2, 3).mean((1, 3))
    return r


def blocks(S):
    """stored image S (hs, ws, ...) top row first -> (blocks in ROM order, BW*BH*...) and (rowbytes, block columns)"""
    Sb = S[::-1]                                     # bottom row first, as the engine counts
    hs, ws = Sb.shape[:2]
    H4, W2 = -(-hs // BH) * BH, -(-ws // BW) * BW
    if H4 != hs:
        Sb = np.concatenate([Sb, np.repeat(Sb[-1:], H4 - hs, 0)], 0)
    if W2 != ws:
        Sb = np.concatenate([Sb, np.repeat(Sb[:, -1:], W2 - ws, 1)], 1)
    rest = Sb.shape[2:]
    g = Sb.reshape((H4 // BH, BH, W2 // BW, BW) + rest)         # k, r, bx, sub
    g = g.transpose((2, 0, 3, 1) + tuple(range(4, 4 + len(rest))))   # bx, k, sub, r
    return g.reshape((-1, BW * BH * int(np.prod(rest, dtype=int)))), (H4 // BH, W2 // BW)


def decode(idx, cb, rb, nbx, hs, ws):
    """indices + codebook (NE, BW*BH) -> stored image (hs, ws) of palette values, top row first"""
    e = cb[np.asarray(idx, int)].reshape(nbx, rb, BW, BH)      # bx, k, sub, r
    Sb = e.transpose(1, 3, 0, 2).reshape(rb * BH, nbx * BW)
    return Sb[:hs, :ws][::-1]


def cb_bytes(cb):
    """codebook (NE, BW*BH) -> ROM bytes (planes)"""
    return bytes(int(v) for v in np.asarray(cb).T.flatten())


def cb_from_bytes(b):
    return np.array(list(b[:CB_BYTES]), int).reshape(BW * BH, NE).T


def full_size(S, half):
    return np.repeat(np.repeat(S, 2, 0), 2, 1) if half else S


def _nearest(X, Y, chunk=4096):
    """index of the nearest row of Y for each row of X (squared distance)"""
    out = np.empty(len(X), int)
    yy = (Y * Y).sum(1)
    for i in range(0, len(X), chunk):
        x = X[i:i + chunk]
        out[i:i + chunk] = (yy[None, :] - 2 * x @ Y.T).argmin(1)
    return out


def train(X, sw, rgb, colours, iters=3, seed=0, log=None):
    """codebook (NE, BW*BH) of palette values for blocks X (n, BW*BH*3) with weights sw"""
    from sklearn.cluster import KMeans, MiniBatchKMeans
    C = rgb[colours]
    k = min(NE, len(np.unique(X.round(0), axis=0)))
    km = (KMeans(n_clusters=k, n_init=1, random_state=seed, max_iter=60) if len(X) < 20000 else
          MiniBatchKMeans(n_clusters=k, random_state=seed, batch_size=4096, n_init=3, max_iter=200)).fit(X, sample_weight=sw)
    cent = km.cluster_centers_
    for it in range(iters):
        # each texel of an entry: the SNES colour nearest the centroid's
        cb = colours[_nearest(cent.reshape(-1, 3), C)].reshape(k, -1)
        cbrgb = rgb[cb].reshape(k, -1)
        lab = _nearest(X, cbrgb)
        if it == iters - 1:
            break
        # centroids again of the blocks each (palette) entry got
        tot = np.zeros((k, X.shape[1])); w = np.zeros(k)
        np.add.at(tot, lab, X * sw[:, None]); np.add.at(w, lab, sw)
        live = w > 0
        cent = np.where(live[:, None], tot / np.maximum(w, 1e-9)[:, None], cent)
    full = np.zeros((NE, BW * BH), int)
    full[:k] = cb
    return full, lab


def encode(texs, slots, wsum, rgb, colours, budget, nhalf, maxblob, fits=None, log=print, seed=0):
    """-> dict(half, groups=[dict(cb, members)], walls={n: dict(group, idx, rb, nbx, hs, ws, half)},
              arts={n: full size palette art}, bytes=dict(...))
    FITS(list of group sizes in bytes) -> True if the groups can be placed; fewer groups until they can"""
    nhalf = enough_half(texs, slots, wsum, budget, nhalf, log)
    G = None
    while True:
        out = _encode(texs, slots, wsum, rgb, colours, budget, nhalf, maxblob, G, log, seed, dry=fits is not None)
        if fits is None:
            return out
        if fits(out['sizes']):
            return _encode(texs, slots, wsum, rgb, colours, budget, nhalf, maxblob, out['G'], log, seed)
        G = out['G'] - 1
        if G < 1:
            raise RuntimeError('the wall groups do not fit the banks')


def enough_half(texs, slots, wsum, budget, nhalf, log, min_groups=MIN_GROUPS):
    """at least NHALF slots at half size, more if the indices would leave room for
    fewer than MIN_GROUPS codebooks (lowest weight first)"""
    def nb(n, h):
        t = texs[n]
        hs, ws = (t.h // 2, t.w // 2) if h else (t.h, t.w)
        return -(-hs // BH) * -(-ws // BW)
    order = [n for n in sorted(slots, key=lambda n: (wsum[n], n)) if can_half(texs[n])]
    full = sum(nb(n, 0) for n in slots)
    room = budget - 9 * len(slots) - min_groups * CB_BYTES
    k, idx = 0, full
    while k < len(order) and (k < nhalf or idx > room):
        idx -= nb(order[k], 0) - nb(order[k], 1)
        k += 1
    if k > nhalf:
        log('walls  : VQ: %d slots at half size (not %d) to leave room for %d codebooks' % (k, nhalf, min_groups))
    return k


def _encode(texs, slots, wsum, rgb, colours, budget, nhalf, maxblob, ngroups, log, seed, dry=False):
    from sklearn.cluster import KMeans
    colours = np.array(sorted(colours))
    a_tex = {n: max(wsum[n], 1.0) / (texs[n].h * texs[n].w) for n in slots}
    half = set([n for n in sorted(slots, key=lambda n: (wsum[n], n)) if can_half(texs[n])][:nhalf])
    B, shape = {}, {}
    for n in slots:
        S = stored_ref(texs[n], n in half)
        B[n], (rb, nbx) = blocks(S)
        shape[n] = (rb, nbx, S.shape[0], S.shape[1])
    nidx = {n: len(B[n]) for n in slots}
    G = ngroups or max(1, (budget - sum(nidx.values()) - 9 * len(slots)) // CB_BYTES)
    G = min(G, len(slots))
    # groups: k-means on each wall's colour signature (mean + spread), weighted by its blocks
    sig = np.array([np.concatenate([B[n].reshape(-1, 3).mean(0), B[n].reshape(-1, 3).std(0)]) for n in slots])
    wts = np.array([a_tex[n] * nidx[n] for n in slots])
    lab = KMeans(n_clusters=G, n_init=4, random_state=seed).fit(sig, sample_weight=wts).labels_
    groups = [[n for n, k in zip(slots, lab) if k == g] for g in range(G)]
    groups = [g for g in groups if g]
    # a group must fit a bank: split the big ones
    while True:
        big = max(groups, key=lambda g: sum(nidx[n] for n in g))
        if CB_BYTES + sum(nidx[n] for n in big) <= maxblob:
            break
        if len(big) == 1:
            raise RuntimeError('wall %s alone needs %d bytes, more than %d' % (big[0], CB_BYTES + nidx[big[0]], maxblob))
        ii = [slots.index(n) for n in big]
        sub = KMeans(n_clusters=2, n_init=4, random_state=seed).fit(sig[ii], sample_weight=wts[ii]).labels_
        if sub.min() == sub.max():
            sub = np.arange(len(big)) % 2
        groups.remove(big)
        groups += [[n for n, k in zip(big, sub) if k == 0], [n for n, k in zip(big, sub) if k == 1]]
    sizes = [CB_BYTES + sum(nidx[n] for n in g) for g in groups]
    if dry:
        return dict(G=G, sizes=sizes)
    out = dict(half=half, groups=[], walls={}, arts={}, G=G, sizes=sizes)
    wt = {n: a_tex[n] * (4 if n in half else 1) * (SWITCH_WEIGHT if is_switch(n) else 1) for n in slots}

    def fit(members):
        X = np.concatenate([B[n] for n in members])
        sw = np.concatenate([np.full(nidx[n], wt[n]) for n in members])
        return train(X, sw, rgb, colours, seed=seed)
    fitted = [fit(m) for m in groups]
    for gi, members in enumerate(groups):
        cb, lab = fitted[gi]
        out['groups'].append(dict(cb=cb, members=members))
        o = 0
        for n in members:
            idx = lab[o:o + nidx[n]]; o += nidx[n]
            rb, nbx, hs, ws = shape[n]
            out['walls'][n] = dict(group=gi, idx=idx.astype(np.uint8), rb=rb, nbx=nbx, hs=hs, ws=ws, half=n in half)
            out['arts'][n] = full_size(decode(idx, cb, rb, nbx, hs, ws), n in half)
    out['bytes'] = dict(indices=sum(nidx.values()), codebooks=len(groups) * CB_BYTES)
    log('walls  : VQ %dx%d blocks: %d slots (%d at half size), %d groups; indices %d + codebooks %d bytes'
        % (BW, BH, len(slots), len(half), len(groups), out['bytes']['indices'], out['bytes']['codebooks']))
    return out
