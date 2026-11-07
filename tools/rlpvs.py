#!/usr/bin/env python3
"""
rlpvs.py - sector visibility (the REJECT / PVS table) for DOOM maps.

The engine uses this table twice: monsters only look for the player in
sectors visible from theirs, and the BSP walk skips subtrees whose sectors
the player's sector can't see.  It has to be conservative: a pair marked
hidden that is visible makes walls disappear.  The REJECT lump in a WAD is
often loose (E3M4: 87 % of sector pairs "visible") or empty, so it is
computed here with 2D portal flow:

  * a portal is a two-sided line between two different sectors
  * from every portal S of a sector, the walk follows chains of portals
    S -> T -> N ...; N is clipped to the half-planes beyond S and T and to the
    region between the separating lines of S and T (the 2D antipenumbra), the
    source S is clipped to the part that sees N through T
  * a sector reached by a non-empty clipped portal is visible

Heights are ignored (doors and lifts move), so the result is a superset of
the true 2D line-of-sight visibility.  Clipping keeps a small tolerance on
the visible side, so rounding never hides anything.
"""
import time

EPS = 1e-6


def cross(ax, ay, bx, by, px, py):
    return (bx - ax) * (py - ay) - (by - ay) * (px - ax)


def clip(seg, p, q, keep):
    """keep the part of segment SEG on the KEEP side (+1 left / -1 right) of line p->q"""
    if seg is None:
        return None
    (x1, y1), (x2, y2) = seg
    d1 = cross(p[0], p[1], q[0], q[1], x1, y1) * keep
    d2 = cross(p[0], p[1], q[0], q[1], x2, y2) * keep
    tol = EPS * (abs(q[0] - p[0]) + abs(q[1] - p[1]) + 1.0) * 64
    if d1 >= -tol and d2 >= -tol:
        return seg
    if d1 < -tol and d2 < -tol:
        return None
    t = d1 / (d1 - d2)
    mx, my = x1 + (x2 - x1) * t, y1 + (y2 - y1) * t
    return ((x1, y1), (mx, my)) if d1 >= -tol else ((mx, my), (x2, y2))


def side(p, q, r):
    c = cross(p[0], p[1], q[0], q[1], r[0], r[1])
    return 1 if c > EPS else -1 if c < -EPS else 0


def antipenumbra(seg, S, T):
    """clip SEG to the region lines through S and T can reach beyond T"""
    for si in (0, 1):
        for tj in (0, 1):
            p, q = S[si], T[tj]
            if abs(p[0] - q[0]) + abs(p[1] - q[1]) < 1e-3:
                continue
            ds = side(p, q, S[1 - si])
            dt = side(p, q, T[1 - tj])
            if ds and dt and ds != dt:
                seg = clip(seg, p, q, dt)
                if seg is None:
                    return None
    return seg


def merge_collinear(lst):
    """join portals of one sector to the same sector that continue each other
    on one line (long windows are often several linedefs): fewer branches"""
    out = []
    used = [False] * len(lst)
    for i, (pid, a, b, to, k) in enumerate(lst):
        if used[i]:
            continue
        used[i] = True
        changed = True
        while changed:
            changed = False
            for j, (q, c, d, to2, k2) in enumerate(lst):
                if used[j] or to2 != to or k2 != k:
                    continue
                if side(a, b, c) or side(a, b, d):
                    continue
                if c == b and (d[0] - b[0]) * (b[0] - a[0]) + (d[1] - b[1]) * (b[1] - a[1]) > 0:
                    b = d
                elif d == a and (a[0] - c[0]) * (b[0] - a[0]) + (a[1] - c[1]) * (b[1] - a[1]) > 0:
                    a = c
                else:
                    continue
                used[j] = True
                changed = True
        out.append((pid, a, b, to, k))
    return out


def compute(m, budget=None, log=None):
    """m: wad2rl.Map (after sector merging).  Returns vis[a] = set of sectors a sees.

    For every portal S of a sector A, a breadth-first pass over the portals
    behind it keeps for each portal N one interval: the hull of the parts of N
    that lines through S and the previous portal can reach.  Intervals only
    grow, so the pass ends; the hull makes the result a little looser than
    following every portal chain on its own (still conservative)."""
    from collections import deque
    n = len(m.sectors)
    V = m.vertexes
    out = [[] for _ in range(n)]          # (portal id, a, b, to, side of a->b that is 'to')
    pid = 0
    for l in m.lines:
        if l['left'] < 0:
            continue
        R, L = m.sec(l['right']), m.sec(l['left'])
        if R == L:
            continue
        a, b = tuple(map(float, V[l['v1']])), tuple(map(float, V[l['v2']]))
        if a == b:
            continue
        out[R].append((pid, a, b, L, +1))
        out[L].append((pid + 1, a, b, R, -1))
        pid += 2
    out = [merge_collinear(o) for o in out]
    P = {}
    for C in range(n):
        for (i, a, b, D, k) in out[C]:
            P[i] = (a, b, C, D, k)
    vis = [set([s]) for s in range(n)]
    t0 = time.time()
    steps = 0

    def param(a, b, p):
        dx, dy = b[0] - a[0], b[1] - a[1]
        return ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)

    def point(a, b, t):
        return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)

    for A in range(n):
        for (i, sa, sb, B, sk) in out[A]:
            S = (sa, sb)
            vis[A].add(B)
            reach = {}
            q = deque()

            def offer(j, seg):
                a, b = P[j][0], P[j][1]
                t0_, t1_ = sorted((param(a, b, seg[0]), param(a, b, seg[1])))
                t0_, t1_ = max(0.0, t0_), min(1.0, t1_)
                old = reach.get(j)
                if old is None:
                    reach[j] = (t0_, t1_)
                    q.append(j)
                elif t0_ < old[0] - 1e-6 or t1_ > old[1] + 1e-6:
                    reach[j] = (min(old[0], t0_), max(old[1], t1_))
                    q.append(j)

            for (j, c, d, D, k) in out[B]:
                if (j ^ 1) == i and P[j][3] == A:
                    continue
                N = clip((c, d), sa, sb, sk)
                if N is None or clip(S, c, d, -k) is None:
                    continue
                offer(j, N)
            while q:
                j = q.popleft()
                a, b, C, D, k = P[j]
                vis[A].add(D)
                t0_, t1_ = reach[j]
                T = (point(a, b, t0_), point(a, b, t1_))
                for (x, c, d, E, kk) in out[D]:
                    steps += 1
                    if (x ^ 1) == j and P[x][3] == C:
                        continue
                    N = clip((c, d), sa, sb, sk)
                    if N is None:
                        continue
                    N = clip(N, a, b, k)
                    if N is None:
                        continue
                    N = antipenumbra(N, S, T)
                    if N is None:
                        continue
                    S2 = clip(S, c, d, -kk)
                    if S2 is None or antipenumbra(S2, N, T) is None:
                        continue
                    offer(x, N)
        if budget and time.time() - t0 > budget:
            raise TimeoutError('PVS over the time budget at sector %d of %d' % (A, n))
    for a in range(n):                          # symmetric
        for b in list(vis[a]):
            vis[b].add(a)
    if log:
        log('PVS: %d portals, %d steps, %.1f s' % (len(P), steps, time.time() - t0))
    return vis


def to_rows(vis, n):
    """FX3 REJECT format: rows of (n+7)>>3 bytes, bit (b&7) of byte (b>>3) = a sees b"""
    rb = (n + 7) >> 3
    out = bytearray(n * rb)
    for a in range(n):
        for b in vis[a]:
            out[a * rb + (b >> 3)] |= 1 << (b & 7)
    return bytes(out)
