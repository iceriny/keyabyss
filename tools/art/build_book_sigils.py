"""Bake Arcana384 lettering and scale-specific book diagrams into SVG textures.

Runtime imports rasterize these masks once. No font shaping, SVG parsing or
per-glyph distance equations are needed during a frame.
"""
from pathlib import Path
import json
import math
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs/art/Arcana384"
TARGET = ROOT / "assets/art/runes"
ET.register_namespace("", "http://www.w3.org/2000/svg")
IDS = {item["char"]: item["index"] for item in json.loads((SOURCE / "concepts.json").read_text(encoding="utf-8"))["concepts"]}
ROOTS = "存生灭始终命时循复空域光力水火电雷风灵凝冷热流聚散击反护全形界能"
BOOKS = {
    "frost": ("凝", "凝水冷域循流", 6),
    "flame": ("火", "火热光散生流", 3),
    "storm": ("雷", "雷电力光聚击", 4),
    "spirit": ("灵", "灵复空命护循", 5),
}


def glyph(char, x, y, size, rotation=0):
    group = list(ET.parse(SOURCE / f"svg-clean/rune-{IDS[char]:03}.svg").getroot())[1]
    group.set("stroke", "#ffffff")
    return f'<g transform="translate({x:.3f} {y:.3f}) rotate({rotation:.3f}) scale({size/128:.5f}) translate(-64 -64)">{ET.tostring(group, encoding="unicode")}</g>'


def point(radius, angle):
    a = math.radians(angle)
    return radius * math.sin(a), -radius * math.cos(a)


def arc(radius, angle, span, width=1.6, alpha=0.7):
    x, y = point(radius, angle)
    ex, ey = point(radius, angle + span)
    return f'<path d="M{x:.3f} {y:.3f} A{radius} {radius} 0 {int(span>180)} 1 {ex:.3f} {ey:.3f}" stroke-width="{width}" opacity="{alpha}"/>'


def polygon(radius, count, step=1, rotation=0, alpha=.4, width=1.3):
    points = [point(radius, rotation + 360 * ((i * step) % count) / count) for i in range(count)]
    return '<path d="M' + ' L'.join(f'{x:.3f} {y:.3f}' for x, y in points) + f' Z" opacity="{alpha}" stroke-width="{width}"/>'


def open_chord(a, b, holes):
    """Keep interlocking geometry out of the central and satellite inscriptions."""
    vx, vy = b[0] - a[0], b[1] - a[1]
    length2 = vx * vx + vy * vy
    intervals = [(0., 1.)]
    for cx, cy, radius in holes:
        dx, dy = a[0] - cx, a[1] - cy
        middle = -(dx * vx + dy * vy) / length2
        discriminant = middle * middle - (dx * dx + dy * dy - radius * radius) / length2
        if discriminant <= 0: continue
        lo, hi = middle - math.sqrt(discriminant), middle + math.sqrt(discriminant)
        remaining = []
        for start, end in intervals:
            if hi <= start or lo >= end: remaining.append((start, end))
            else:
                if lo > start: remaining.append((start, lo))
                if hi < end: remaining.append((hi, end))
        intervals = remaining
    return ''.join(f'M{a[0]+vx*s:.3f} {a[1]+vy*s:.3f} L{a[0]+vx*e:.3f} {a[1]+vy*e:.3f} ' for s, e in intervals)


def great_seal(book):
    """One radial order: inscription, petal chambers, school motifs and core."""
    core, letters, _ = BOOKS[book]
    order = {"frost": 6, "flame": 6, "storm": 8, "spirit": 5}[book]
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="-512 -512 1024 1024" fill="none" stroke="white" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">']
    for radius, alpha, width in [(492,.75,2),(456,.42,1.3),(417,.38,1.3),(168,.6,1.8),(124,.42,1.3)]:
        parts.append(f'<circle r="{radius}" opacity="{alpha}" stroke-width="{width}"/>')
    # Two separately spaced inscriptions with small caesuras at the main axes.
    for radius, count, size in [(474,48,29),(145,18,22)]:
        for i in range(count):
            angle = (i + .5) * 360 / count
            x, y = point(radius, angle)
            parts.append(glyph(letters[i % len(letters)], x, y, size, angle))
    for i in range(order * 6):
        angle = i * 360 / (order * 6)
        a, b = point(432 if i % 6 == 0 else 438, angle), point(445, angle)
        parts.append(f'<path d="M{a[0]:.3f} {a[1]:.3f} L{b[0]:.3f} {b[1]:.3f}" opacity="{.55 if i%6==0 else .2}"/>')
    satellites = [point(285, i * 360 / order) for i in range(order)]
    for i in range(order):
        angle = i * 360 / order
        x, y = satellites[i]
        parts.append(f'<g transform="translate({x:.3f} {y:.3f}) rotate({angle})">')
        for radius, alpha in [(53,.55),(47,.22)]:
            parts.append(f'<circle r="{radius}" opacity="{alpha}"/>')
        parts.append(glyph(letters[i % len(letters)], 0, 0, 60))
        parts.append('</g>')
        parts.append(f'<g transform="rotate({angle})">')
        parts.append('<path d="M0 -177 C-88 -214 -102 -335 0 -397 C102 -335 88 -214 0 -177 Z M0 -397 L0 -417" opacity=".48" stroke-width="1.6"/>')
        parts.append('</g>')
        parts.append(f'<g transform="rotate({angle+180/order})">')
        if book == "frost":
            parts.append('<path d="M0 -187 L0 -400 M-26 -375 L0 -400 L26 -375 M-18 -235 L0 -217 L18 -235 M-34 -288 L0 -254 L34 -288 M-48 -337 L0 -289 L48 -337 M-57 -369 L0 -312 L57 -369" opacity=".73" stroke-width="1.7"/>')
            parts.append('<path d="M-32 -345 L-32 -323 L-53 -323 M32 -345 L32 -323 L53 -323 M-19 -292 L-19 -273 L-38 -273 M19 -292 L19 -273 L38 -273 M0 -386 L-9 -368 L0 -350 L9 -368 Z" opacity=".4"/>')
        elif book == "flame":
            parts.append('<path d="M-8 -185 C-92 -241 -67 -331 24 -401 C-30 -337 90 -292 26 -226 C64 -296 -19 -280 -8 -185 Z M-29 -204 C-113 -270 -48 -365 6 -399 M14 -193 C78 -256 102 -316 54 -358" opacity=".73" stroke-width="1.7"/>')
            parts.append('<path d="M-12 -251 C-48 -302 8 -317 6 -363 M20 -326 Q51 -291 31 -265 M-63 -306 Q-76 -353 -36 -385" opacity=".35"/>')
        elif book == "storm":
            parts.append('<path d="M-18 -191 L24 -256 L-4 -254 L37 -315 L8 -311 L39 -399 M-44 -209 L-13 -265 L-37 -262 L-7 -333 M39 -248 L65 -287 L43 -285 L65 -347" opacity=".8" stroke-width="1.75"/>')
            parts.append('<path d="M-51 -346 L-27 -379 L-3 -346 L-27 -313 Z M-27 -365 L-27 -329 M-40 -347 L-14 -347 M18 -372 L29 -401 L44 -381" opacity=".4"/>')
        else:
            parts.append('<path d="M0 -186 C-106 -247 -113 -355 0 -403 C116 -352 104 -245 0 -186 Z M0 -196 C-28 -256 36 -334 0 -391 M-15 -212 C-100 -268 -87 -347 -12 -382 M15 -212 C102 -269 87 -349 12 -382" opacity=".7" stroke-width="1.7"/>')
            parts.append('<path d="M-56 -268 Q0 -253 56 -268 M-63 -286 Q0 -271 63 -286 M-65 -305 Q0 -290 65 -305 M-57 -325 Q0 -310 57 -325 M-44 -345 Q0 -330 44 -345" opacity=".32"/>')
        parts.append('</g>')
    parts.append(glyph(core, 0, 0, 160))
    for i in range(order * 2):
        x, y = point(173, i*180/order)
        parts.append(f'<circle cx="{x:.3f}" cy="{y:.3f}" r="2.4" fill="white" opacity=".65"/>')
    parts.append('</svg>')
    return '\n'.join(parts)


def seal(book, level):
    if level == 2: return great_seal(book)
    core, letters, symmetry = BOOKS[book]
    pixels = [128, 384][level]
    # Coordinate design is shared; stroke and complexity are authored per size.
    width = [7.0, 3.0][level]
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{pixels}" height="{pixels}" viewBox="-512 -512 1024 1024" fill="none" stroke="white" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round">']
    parts.append(glyph(core, 0, 0, [410, 255][level]))
    for i in range(symmetry):
        angle = 360 * i / symmetry
        parts.append(arc(445, angle + 5, 360 / symmetry - 16, width, .75))
        parts.append(f'<g transform="rotate({angle})">')
        if book == "frost":
            parts.append('<path d="M0 -390 L0 -240 M-45 -328 L0 -285 L45 -328" opacity=".85"/>')
            if level: parts.append('<path d="M-64 -379 L0 -327 L64 -379 M-126 -241 L0 -205 L126 -241" opacity=".38"/>')
        elif book == "flame":
            parts.append('<path d="M-56 -216 C-156 -300 -86 -367 22 -402 C-30 -340 90 -278 52 -224" opacity=".8"/>')
            if level: parts.append('<path d="M-92 -214 C-207 -304 -84 -405 43 -419 M76 -226 C163 -302 99 -350 63 -367" opacity=".32"/>')
        elif book == "storm":
            parts.append('<path d="M-61 -235 L20 -328 L-20 -325 L43 -401 M-106 -256 L-72 -320" opacity=".82"/>')
            if level: parts.append('<path d="M-40 -251 L43 -345 L12 -346 L55 -409 M80 -251 L118 -327 L142 -290" opacity=".32"/>')
        else:
            parts.append('<path d="M0 -222 C-144 -272 -100 -365 0 -404 C96 -363 135 -270 0 -222 Z M0 -235 Q-37 -320 0 -392" opacity=".78"/>')
            if level: parts.append('<path d="M-35 -216 C-167 -270 -120 -387 0 -424 C124 -378 155 -266 35 -216" opacity=".3"/>')
        parts.append('</g>')
    if level:
        count = 8
        for i in range(count):
            angle = 360 * (i + .5) / count
            x, y = point(475, angle)
            parts.append(glyph(letters[i % len(letters)], x, y, 64, angle))
        for i in range(symmetry):
            angle = 360 * (i + .5) / symmetry
            parts.append(arc(178, angle, 360 / symmetry - 14, width, .55))
    parts.append('</svg>')
    return "\n".join(parts)


def main():
    TARGET.mkdir(parents=True, exist_ok=True)
    for book in BOOKS:
        for level, suffix in enumerate(["small", "medium", "large"]):
            name = f"{book}-seal.svg" if suffix == "large" else f"{book}-seal-{suffix}.svg"
            (TARGET / name).write_text(seal(book, level), encoding="utf-8")
    atlas = ['<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="512" viewBox="0 0 1024 512">']
    for i, char in enumerate(ROOTS):
        atlas.append(glyph(char, (i % 8) * 128 + 64, (i // 8) * 128 + 64, 96))
    atlas.append('</svg>')
    (TARGET / "arcana-atlas.svg").write_text("\n".join(atlas), encoding="utf-8")
    print("12 book sigils; 32 Arcana384 glyphs in one padded atlas")


if __name__ == "__main__":
    main()
