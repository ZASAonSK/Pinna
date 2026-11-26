#!/usr/bin/env python3
"""Render the Pinna app icon (1024x1024, opaque) without third-party libs.

Design: deep indigo -> teal diagonal gradient, a soft glass disc, a white
earbud (round head + angled stem) and two sound-wave arcs. Rendered with
signed distance functions and 3x3 supersampling, written as a PNG via zlib.
Usage: python3 tools/make_icon.py out.png [size]
"""
import math, struct, sys, zlib

def png(path, w, h, rows):
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(data)

def mix(a, b, t): return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))
def clamp(x, lo=0.0, hi=1.0): return lo if x < lo else hi if x > hi else x

def sd_circle(px, py, cx, cy, r): return math.hypot(px - cx, py - cy) - r
def sd_capsule(px, py, ax, ay, bx, by, r):
    pax, pay, bax, bay = px - ax, py - ay, bx - ax, by - ay
    h = clamp((pax * bax + pay * bay) / (bax * bax + bay * bay))
    return math.hypot(pax - bax * h, pay - bay * h) - r
def sd_arc(px, py, cx, cy, r, w, a0, a1):
    ang = math.atan2(py - cy, px - cx)
    if a0 <= ang <= a1:
        return abs(math.hypot(px - cx, py - cy) - r) - w
    e0 = (cx + r * math.cos(a0), cy + r * math.sin(a0))
    e1 = (cx + r * math.cos(a1), cy + r * math.sin(a1))
    return min(math.hypot(px - e0[0], py - e0[1]), math.hypot(px - e1[0], py - e1[1])) - w

TOP = (0.20, 0.16, 0.62)     # indigo
BOT = (0.05, 0.72, 0.70)     # teal
GLOW = (0.55, 0.95, 0.90)

def shade(x, y):
    # background: diagonal gradient + soft vignette highlight
    t = clamp((x + y) / 2)
    c = mix(TOP, BOT, t)
    hl = math.exp(-((x - 0.28) ** 2 + (y - 0.22) ** 2) / 0.08) * 0.18
    c = tuple(clamp(v + hl) for v in c)
    # glass disc behind the bud
    d = sd_circle(x, y, 0.5, 0.52, 0.34)
    if d < 0:
        c = mix(c, (1, 1, 1), 0.10 + 0.06 * (1 - (y - 0.18) / 0.68))
    ring = abs(d) - 0.004
    if ring < 0: c = mix(c, (1, 1, 1), 0.35)
    # sound waves (right side)
    for r, a in ((0.21, 0.85), (0.29, 0.55)):
        dw = sd_arc(x, y, 0.47, 0.45, r, 0.018, -0.75, 0.55)
        if dw < 0: c = mix(c, GLOW, a)
    # earbud: head + stem, white with slight shading
    head = sd_circle(x, y, 0.43, 0.45, 0.135)
    stem = sd_capsule(x, y, 0.40, 0.52, 0.35, 0.70, 0.062)
    tip = sd_capsule(x, y, 0.47, 0.40, 0.50, 0.38, 0.050)
    bud = min(head, stem)
    shadow = min(sd_circle(x, y, 0.445, 0.47, 0.135), sd_capsule(x, y, 0.415, 0.54, 0.365, 0.72, 0.062))
    if bud >= 0 and shadow < 0.02:
        c = mix(c, (0.03, 0.05, 0.15), 0.22 * clamp(1 - (shadow + 0.0) / 0.02))
    if bud < 0:
        s = 0.92 + 0.08 * clamp(1 - (x + y - 0.7) * 1.4)
        c = (s, s, s * 1.0)
        if tip < 0: c = mix(c, (0.10, 0.16, 0.30), 0.85)
    return c

def render(size):
    ss = 3
    rows = []
    for j in range(size):
        row = []
        for i in range(size):
            acc = [0.0, 0.0, 0.0]
            for sj in range(ss):
                for si in range(ss):
                    c = shade((i + (si + 0.5) / ss) / size, (j + (sj + 0.5) / ss) / size)
                    acc[0] += c[0]; acc[1] += c[1]; acc[2] += c[2]
            n = ss * ss
            row += [int(clamp(acc[0] / n) * 255 + 0.5), int(clamp(acc[1] / n) * 255 + 0.5), int(clamp(acc[2] / n) * 255 + 0.5)]
        rows.append(row)
    return rows

if __name__ == "__main__":
    out = sys.argv[1]; size = int(sys.argv[2]) if len(sys.argv) > 2 else 1024
    png(out, size, size, render(size))
