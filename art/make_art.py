"""Draws the Roblox game icon and thumbnail for Cherry Blossom Tower.

Writes icon.html (512x512) and thumbnail.html (1920x1080) next to this file. Render them to PNG with:

    python3 art/make_art.py && art/render.sh

Everything is plain SVG, so colours and sizes below are easy to tweak.
"""

import math
import random
from pathlib import Path

HERE = Path(__file__).parent

SKY = ("#cdb4ff", "#ffb8d9", "#ffe0ee")  # top, middle, bottom
RAINBOW = ("#ff6b6b", "#ffa94d", "#ffe066", "#8ce99a", "#74c0fc", "#b197fc")
TOWER = ("#ff8cc1", "#ff6fb0")  # alternating floors
TOWER_LINE = "#e0458f"
LEDGE = "#ffd1e6"
ROOF = "#ff4f9a"
ROOF_LINE = "#d63a84"
WINDOW = "#fff0f7"
TITLE_LINE = "#ff4f9a"
TITLE_SHADOW = "#b8336f"
PLATFORMS = ("#8ce99a", "#ffe066", "#74c0fc", "#b197fc")
BLOSSOMS = ("#ffd6e8", "#ffb3d1", "#ff9cc6", "#ffc4dd")  # tree tops, mixed
BLOSSOM_SHADOW = "#f07fb0"
FLOWER_PETAL = "#ffe8f2"
FLOWER_EDGE = "#ff8fbf"
FLOWER_CENTER = "#ff4f9a"
BARK = "#9a6250"
BARK_LINE = "#6e3f33"
LANTERN = "#ff5a6e"
LANTERN_LINE = "#c93a55"
GOLD = "#ffcf4d"


def defs():
    return f"""
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{SKY[0]}"/>
      <stop offset="0.55" stop-color="{SKY[1]}"/>
      <stop offset="1" stop-color="{SKY[2]}"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.85"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>
    <filter id="titleShadow" x="-10%" y="-10%" width="120%" height="140%">
      <feDropShadow dx="0" dy="9" stdDeviation="0" flood-color="{TITLE_SHADOW}" flood-opacity="0.9"/>
    </filter>
    <filter id="soft" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="6" stdDeviation="6" flood-color="#c2477f" flood-opacity="0.35"/>
    </filter>
  </defs>"""


def cloud(cx, cy, s=1.0, opacity=1.0):
    puffs = [(-62, 14, 38), (-24, -12, 52), (28, -4, 46), (66, 16, 34), (0, 22, 44)]
    shadow = "".join(
        f'<circle cx="{cx + dx * s:.1f}" cy="{cy + (dy + 9) * s:.1f}" r="{r * s:.1f}"/>' for dx, dy, r in puffs
    )
    body = "".join(f'<circle cx="{cx + dx * s:.1f}" cy="{cy + dy * s:.1f}" r="{r * s:.1f}"/>' for dx, dy, r in puffs)
    return (
        f'<g opacity="{opacity}"><g fill="#f3a3c8" opacity="0.45">{shadow}</g>'
        f'<g fill="#ffffff">{body}</g></g>'
    )


def sparkle(x, y, r, color="#ffffff", opacity=1.0):
    return (
        f'<path d="M{x},{y - r} Q{x},{y} {x + r},{y} Q{x},{y} {x},{y + r} Q{x},{y} {x - r},{y} Q{x},{y} {x},{y - r}Z" '
        f'fill="{color}" opacity="{opacity}"/>'
    )


def rainbow(cx, cy, r_outer, band, opacity=0.85):
    arcs = []
    for i, color in enumerate(RAINBOW):
        r = r_outer - band * i - band / 2
        arcs.append(
            f'<path d="M{cx - r:.1f},{cy} A{r:.1f},{r:.1f} 0 0 1 {cx + r:.1f},{cy}" '
            f'stroke="{color}" stroke-width="{band + 1}" fill="none"/>'
        )
    return f'<g opacity="{opacity}">{"".join(arcs)}</g>'


def heart(cx, top, s, fill=WINDOW):
    x, y = cx, top
    return (
        f'<path d="M{x},{y + s * 0.3} C{x},{y} {x - s * 0.5},{y} {x - s * 0.5},{y + s * 0.3} '
        f"C{x - s * 0.5},{y + s * 0.6} {x},{y + s * 0.8} {x},{y + s} "
        f"C{x},{y + s * 0.8} {x + s * 0.5},{y + s * 0.6} {x + s * 0.5},{y + s * 0.3} "
        f'C{x + s * 0.5},{y} {x},{y} {x},{y + s * 0.3}Z" fill="{fill}"/>'
    )


def _petal_path(r):
    """One cherry blossom petal pointing up from (0, 0), with the little notch at its tip."""
    return (
        f"M0,0 C{-r * 0.62:.1f},{-r * 0.3:.1f} {-r * 0.55:.1f},{-r * 0.98:.1f} {-r * 0.2:.1f},{-r:.1f} "
        f"L0,{-r * 0.8:.1f} L{r * 0.2:.1f},{-r:.1f} C{r * 0.55:.1f},{-r * 0.98:.1f} {r * 0.62:.1f},{-r * 0.3:.1f} 0,0Z"
    )


def sakura(x, y, r, rot=0):
    """A five-petal cherry blossom flower."""
    petals = "".join(f'<path d="{_petal_path(r)}" transform="rotate({i * 72})"/>' for i in range(5))
    dots = "".join(
        f'<circle cx="{r * 0.34 * math.cos(a):.1f}" cy="{r * 0.34 * math.sin(a):.1f}" r="{max(r * 0.07, 0.8):.1f}"/>'
        for a in (i * 2 * math.pi / 5 + 0.63 for i in range(5))
    )
    return (
        f'<g transform="translate({x:.1f} {y:.1f}) rotate({rot:.0f})">'
        f'<g fill="{FLOWER_PETAL}" stroke="{FLOWER_EDGE}" stroke-width="{max(r * 0.1, 1):.1f}" stroke-linejoin="round">{petals}</g>'
        f'<circle r="{r * 0.24:.1f}" fill="{FLOWER_CENTER}"/><g fill="{GOLD}">{dots}</g></g>'
    )


def petal(x, y, size, rot, color, opacity=0.9):
    """A single petal drifting through the air."""
    return (
        f'<path d="{_petal_path(size)}" transform="translate({x:.1f} {y:.1f}) rotate({rot:.0f})" '
        f'fill="{color}" stroke="{FLOWER_EDGE}" stroke-width="{max(size * 0.08, 0.8):.1f}" opacity="{opacity}"/>'
    )


def canopy(cx, cy, s, rng, flowers=8):
    """A puffy pink clump of blossoms, like a cloud made of flowers."""
    puffs = [(-70, 10, 48), (-30, -25, 58), (25, -30, 55), (70, 0, 46), (0, 22, 56), (-42, 36, 40), (42, 36, 42)]
    shadow = "".join(
        f'<circle cx="{cx + dx * s:.1f}" cy="{cy + (dy + 10) * s:.1f}" r="{r * s:.1f}"/>' for dx, dy, r in puffs
    )
    body = "".join(
        f'<circle cx="{cx + dx * s:.1f}" cy="{cy + dy * s:.1f}" r="{r * s:.1f}" fill="{rng.choice(BLOSSOMS)}"/>'
        for dx, dy, r in puffs
    )
    shine = "".join(
        f'<circle cx="{cx + (dx - r * 0.3) * s:.1f}" cy="{cy + (dy - r * 0.35) * s:.1f}" r="{r * 0.35 * s:.1f}"/>'
        for dx, dy, r in puffs[:4]
    )
    blooms = []
    for _ in range(flowers):
        dx, dy, r = rng.choice(puffs)
        angle, dist = rng.uniform(0, 2 * math.pi), rng.uniform(0, r * 0.7)
        blooms.append(
            sakura(cx + (dx + math.cos(angle) * dist) * s, cy + (dy + math.sin(angle) * dist) * s,
                   rng.uniform(9, 13) * s, rng.uniform(0, 72))
        )
    return (
        f'<g><g fill="{BLOSSOM_SHADOW}" opacity="0.55">{shadow}</g>{body}'
        f'<g fill="#ffffff" opacity="0.3">{shine}</g>{"".join(blooms)}</g>'
    )


def branch(d, width):
    """A bark-coloured branch along an SVG path, with a darker outline."""
    return (
        f'<path d="{d}" stroke="{BARK_LINE}" stroke-width="{width + 5:.1f}" fill="none" stroke-linecap="round"/>'
        f'<path d="{d}" stroke="{BARK}" stroke-width="{width:.1f}" fill="none" stroke-linecap="round"/>'
    )


def cherry_tree(x, base_y, s, rng, lean=1):
    """A cherry blossom tree. (x, base_y) is the bottom of the trunk; lean=-1 mirrors it."""
    def pt(dx, dy):
        return f"{x + dx * s * lean:.1f},{base_y + dy * s:.1f}"

    fork = pt(8, -120)
    wood = [
        branch(f"M{pt(0, 0)} Q{pt(-12, -60)} {fork}", 30 * s),
        branch(f"M{fork} Q{pt(-40, -150)} {pt(-85, -190)}", 15 * s),
        branch(f"M{fork} Q{pt(32, -160)} {pt(75, -200)}", 15 * s),
        branch(f"M{fork} Q{pt(4, -175)} {pt(0, -235)}", 13 * s),
    ]
    tops = [
        canopy(x - 85 * s * lean, base_y - 205 * s, 0.85 * s, rng),
        canopy(x + 78 * s * lean, base_y - 212 * s, 0.85 * s, rng),
        canopy(x, base_y - 262 * s, s, rng, flowers=10),
    ]
    return f'<g filter="url(#soft)">{"".join(wood)}{"".join(tops)}</g>'


def corner_branch(points, s, rng, lanterns=()):
    """A blossom branch reaching in from the edge of the picture.
    points = (start, control, end) of the branch; blossoms sit along it, lanterns hang from it."""
    (x0, y0), (cx, cy), (x1, y1) = points

    def at(t):
        return ((1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t ** 2 * x1,
                (1 - t) ** 2 * y0 + 2 * (1 - t) * t * cy + t ** 2 * y1)

    parts = [branch(f"M{x0},{y0} Q{cx},{cy} {x1},{y1}", 16 * s)]
    for t in lanterns:
        lx, ly = at(t)
        parts.append(lantern(lx, ly, 70 * s))
    for t, size in [(0.25, 0.55), (0.6, 0.5), (0.95, 0.45)]:
        bx, by = at(t)
        parts.append(canopy(bx, by + 10 * s, size * s, rng, flowers=6))
    return f'<g filter="url(#soft)">{"".join(parts)}</g>'


def lantern(x, top_y, size, line=None):
    """A round red paper lantern hanging from (x, top_y)."""
    line = line or max(size * 0.05, 1.5)
    string_end = top_y + size * 0.35
    body_top = string_end + size * 0.1
    cy, rx, ry = body_top + size * 0.4, size * 0.36, size * 0.42
    return (
        "<g>"
        f'<line x1="{x:.1f}" y1="{top_y:.1f}" x2="{x:.1f}" y2="{string_end:.1f}" stroke="{LANTERN_LINE}" stroke-width="{line:.1f}"/>'
        f'<rect x="{x - size * 0.17:.1f}" y="{string_end:.1f}" width="{size * 0.34:.1f}" height="{size * 0.12:.1f}" rx="{size * 0.03:.1f}" fill="{GOLD}" stroke="{LANTERN_LINE}" stroke-width="{line * 0.7:.1f}"/>'
        f'<ellipse cx="{x:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{LANTERN}" stroke="{LANTERN_LINE}" stroke-width="{line:.1f}"/>'
        f'<ellipse cx="{x:.1f}" cy="{cy:.1f}" rx="{rx * 0.5:.1f}" ry="{ry:.1f}" fill="none" stroke="{LANTERN_LINE}" stroke-width="{line * 0.7:.1f}" opacity="0.6"/>'
        f'<ellipse cx="{x - rx * 0.45:.1f}" cy="{cy - ry * 0.35:.1f}" rx="{rx * 0.18:.1f}" ry="{ry * 0.3:.1f}" fill="#ffffff" opacity="0.35"/>'
        f'<rect x="{x - size * 0.15:.1f}" y="{cy + ry - size * 0.04:.1f}" width="{size * 0.3:.1f}" height="{size * 0.1:.1f}" rx="{size * 0.03:.1f}" fill="{GOLD}" stroke="{LANTERN_LINE}" stroke-width="{line * 0.7:.1f}"/>'
        f'<line x1="{x:.1f}" y1="{cy + ry + size * 0.06:.1f}" x2="{x:.1f}" y2="{cy + ry + size * 0.3:.1f}" stroke="{GOLD}" stroke-width="{line * 1.6:.1f}" stroke-linecap="round"/>'
        "</g>"
    )


def falling_petals(rng, count, width, height, keep_out=(), sizes=(10, 20)):
    """Petals scattered over the picture, except inside the keep_out boxes (x0, y0, x1, y1)."""
    colors = ("#ffc2dc", "#ffb3d1", "#ffd6e8", "#ff9cc6", "#ffffff")
    out, tries = [], 0
    while len(out) < count and tries < count * 20:
        tries += 1
        x, y = rng.uniform(0, width), rng.uniform(0, height * 0.92)
        if any(x0 <= x <= x1 and y0 <= y <= y1 for x0, y0, x1, y1 in keep_out):
            continue
        out.append(petal(x, y, rng.uniform(*sizes), rng.uniform(0, 360), rng.choice(colors), rng.uniform(0.75, 0.95)))
    return "".join(out)


def tower(cx, base_y, levels, level_h, bottom_w, top_w, line=5, flag=True):
    parts = []
    ledges = []  # (y, width) of each floor's ledge, to put flowers and lanterns on afterwards
    top_y = base_y - levels * level_h
    for i in range(levels):
        t = i / max(levels - 1, 1)
        w = bottom_w + (top_w - bottom_w) * t
        y = base_y - (i + 1) * level_h
        color = TOWER[i % 2]
        parts.append(
            f'<rect x="{cx - w / 2:.1f}" y="{y:.1f}" width="{w:.1f}" height="{level_h:.1f}" rx="{level_h * 0.12:.1f}" '
            f'fill="{color}" stroke="{TOWER_LINE}" stroke-width="{line}"/>'
        )
        # soft highlight down the left side for a bit of 3D
        parts.append(
            f'<rect x="{cx - w / 2 + line:.1f}" y="{y + line:.1f}" width="{w * 0.16:.1f}" height="{level_h - 2 * line:.1f}" '
            f'rx="{level_h * 0.08:.1f}" fill="#ffffff" opacity="0.28"/>'
        )
        if i == 0:
            door_w, door_h = w * 0.26, level_h * 0.72
            parts.append(
                f'<rect x="{cx - door_w / 2:.1f}" y="{base_y - door_h:.1f}" width="{door_w:.1f}" height="{door_h + 2:.1f}" '
                f'rx="{door_w / 2:.1f}" fill="{ROOF_LINE}"/>'
            )
            for side in (-1, 1):
                parts.append(heart(cx + side * w * 0.3, y + level_h * 0.24, level_h * 0.42))
        else:
            for side in (-1, 1):
                parts.append(heart(cx + side * w * 0.22, y + level_h * 0.24, level_h * 0.46))
        # ledge on top of each floor
        lw = w + level_h * 0.28
        parts.append(
            f'<rect x="{cx - lw / 2:.1f}" y="{y - level_h * 0.07:.1f}" width="{lw:.1f}" height="{level_h * 0.15:.1f}" '
            f'rx="{level_h * 0.07:.1f}" fill="{LEDGE}" stroke="{TOWER_LINE}" stroke-width="{line * 0.8:.1f}"/>'
        )
        ledges.append((y, lw))
    # pointy roof
    roof_w = top_w + level_h * 0.55
    roof_h = level_h * 1.6
    tip = top_y - level_h * 0.07 - roof_h
    eave_y = top_y - level_h * 0.05
    flick = level_h * 0.22  # how far the roof tips curl up and out
    left, right = cx - roof_w / 2 - flick, cx + roof_w / 2 + flick
    parts.append(
        f'<path d="M{left:.1f},{eave_y - flick:.1f} '
        f'Q{cx - roof_w * 0.16:.1f},{eave_y - roof_h * 0.18:.1f} {cx:.1f},{tip:.1f} '
        f'Q{cx + roof_w * 0.16:.1f},{eave_y - roof_h * 0.18:.1f} {right:.1f},{eave_y - flick:.1f} '
        f'Q{cx + roof_w * 0.4:.1f},{eave_y + level_h * 0.04:.1f} {cx + roof_w * 0.3:.1f},{eave_y:.1f} '
        f'L{cx - roof_w * 0.3:.1f},{eave_y:.1f} '
        f'Q{cx - roof_w * 0.4:.1f},{eave_y + level_h * 0.04:.1f} {left:.1f},{eave_y - flick:.1f}Z" '
        f'fill="{ROOF}" stroke="{ROOF_LINE}" stroke-width="{line}" stroke-linejoin="round"/>'
    )
    parts.append(
        f'<path d="M{cx - roof_w * 0.28:.1f},{top_y - level_h * 0.2:.1f} L{cx - roof_w * 0.04:.1f},{tip + roof_h * 0.18:.1f}" '
        f'stroke="#ffffff" stroke-width="{line * 1.4:.1f}" stroke-linecap="round" opacity="0.45"/>'
    )
    if flag:
        pole_top = tip - level_h * 0.9
        parts.append(
            f'<line x1="{cx}" y1="{tip:.1f}" x2="{cx}" y2="{pole_top:.1f}" stroke="{ROOF_LINE}" stroke-width="{line}" stroke-linecap="round"/>'
        )
        parts.append(heart(cx + level_h * 0.34, pole_top - level_h * 0.02, level_h * 0.5, fill=ROOF))
    # little cherry blossoms all along each ledge, and a lantern at both ends of every other one
    for i, (y, lw) in enumerate(ledges):
        ledge_y = y - level_h * 0.0
        count = max(3, int(lw / (level_h * 0.75)))
        for k in range(count):
            fx = cx - lw / 2 + level_h * 0.18 + k * (lw - level_h * 0.36) / (count - 1)
            parts.append(sakura(fx, ledge_y, level_h * 0.15, rot=(i * 37 + k * 23) % 72))
        if i % 2 == 1:
            for side in (-1, 1):
                parts.append(lantern(cx + side * (lw / 2 - level_h * 0.06), ledge_y + level_h * 0.06, level_h * 0.42))
    return f'<g filter="url(#soft)">{"".join(parts)}</g>'


def platform(x, y, w, color, h=26):
    return (
        f'<rect x="{x}" y="{y + 7}" width="{w}" height="{h}" rx="{h / 2}" fill="#c2477f" opacity="0.18"/>'
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{h / 2}" fill="{color}" stroke="#ffffff" stroke-width="4"/>'
    )


def character(x, y, s=1.0):
    """A little blocky player mid-jump, arms up. (x, y) is the feet."""
    skin, shirt, pants, line = "#ffd9b3", "#ff6fb0", "#ffffff", "#c94f8a"

    def r(rx, ry, w, h, fill, rot=0, ox=0, oy=0):
        transform = f' transform="rotate({rot} {x + ox * s:.1f} {y - oy * s:.1f})"' if rot else ""
        return (
            f'<rect x="{x + rx * s:.1f}" y="{y - ry * s:.1f}" width="{w * s:.1f}" height="{h * s:.1f}" rx="{3 * s:.1f}" '
            f'fill="{fill}" stroke="{line}" stroke-width="{3 * s:.1f}"{transform}/>'
        )

    return (
        "<g>"
        + r(-18, 40, 16, 40, pants, rot=14, ox=-10, oy=40)
        + r(2, 40, 16, 40, pants, rot=-14, ox=10, oy=40)
        + r(-36, 80, 14, 40, shirt, rot=140, ox=-29, oy=76)
        + r(22, 80, 14, 40, shirt, rot=-140, ox=29, oy=76)
        + r(-22, 82, 44, 44, shirt)
        + r(-20, 124, 40, 40, skin)
        + f'<circle cx="{x - 8 * s:.1f}" cy="{y - 106 * s:.1f}" r="{3.5 * s:.1f}" fill="#5b2a4a"/>'
        + f'<circle cx="{x + 8 * s:.1f}" cy="{y - 106 * s:.1f}" r="{3.5 * s:.1f}" fill="#5b2a4a"/>'
        + f'<path d="M{x - 9 * s:.1f},{y - 96 * s:.1f} Q{x:.1f},{y - 88 * s:.1f} {x + 9 * s:.1f},{y - 96 * s:.1f}" '
        f'stroke="#5b2a4a" stroke-width="{3 * s:.1f}" fill="none" stroke-linecap="round"/>'
        + "</g>"
    )


def title(x, y, text, size, rotate=0, anchor="start", stroke=None):
    stroke = stroke or size * 0.12
    rot = f' transform="rotate({rotate} {x} {y})"' if rotate else ""
    return (
        f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="Fredoka, \'Arial Rounded MT Bold\', sans-serif" '
        f'font-weight="700" font-size="{size}" fill="#ffffff" stroke="{TITLE_LINE}" stroke-width="{stroke:.1f}" '
        f'stroke-linejoin="round" paint-order="stroke" filter="url(#titleShadow)"{rot}>{text}</text>'
    )


def page(width, height, body):
    return f"""<!doctype html>
<html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@700&display=block" rel="stylesheet">
<style>html,body{{margin:0;padding:0;overflow:hidden;background:#ffb8d9}} svg{{display:block}}</style>
</head><body>
<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
{defs()}
{body}
</svg></body></html>
"""


def thumbnail():
    w, h = 1920, 1080
    rng = random.Random(7)  # fixed seed: the same picture every time
    body = [f'<rect width="{w}" height="{h}" fill="url(#sky)"/>']
    body.append('<circle cx="1420" cy="330" r="420" fill="url(#glow)"/>')
    body.append(rainbow(1420, 1000, 900, 58))
    for cx, cy, s, o in [(930, 110, 0.8, 0.8), (700, 330, 0.6, 0.6)]:
        body.append(cloud(cx, cy, s, o))
    for x, y, r, o in [
        (180, 520, 18, 0.9), (980, 250, 14, 0.8), (1110, 470, 22, 0.9), (1760, 380, 16, 0.9),
        (620, 760, 14, 0.7), (1840, 650, 20, 0.9), (420, 150, 10, 0.7),
    ]:
        body.append(sparkle(x, y, r, opacity=o))
    # cherry blossom trees on both sides of the tower
    body.append(cherry_tree(1065, 1005, 0.95, rng, lean=-1))
    body.append(cherry_tree(1885, 1010, 0.7, rng, lean=1))
    body.append(tower(1420, 985, 8, 82, 330, 250, line=6))
    # floating platforms climbing up the right side, with a player jumping between them
    for x, y, pw, c in [(1640, 900, 150, 0), (1720, 780, 130, 1), (1640, 660, 120, 2), (1730, 545, 120, 3)]:
        body.append(platform(x, y, pw, PLATFORMS[c]))
    body.append(character(1700, 610, s=1.05))
    body.append(sparkle(1770, 470, 14, "#ffe066"))
    # blossom branches reaching in from the top corners, one with a lantern
    body.append(corner_branch(((-30, 45), (170, 5), (390, 95)), 1.0, rng))
    body.append(corner_branch(((1955, 30), (1770, 15), (1600, 140)), 1.0, rng, lanterns=(0.42,)))
    # petals drifting everywhere except over the title
    body.append(falling_petals(rng, 55, w, h, keep_out=[(80, 150, 1140, 580), (130, 580, 770, 715), (1235, 110, 1605, 1000)]))
    # fluffy cloud floor
    for i in range(12):
        body.append(cloud(80 + i * 170, 1040 + (i % 2) * 18, 1.5))
    body.append(title(110, 325, "Cherry Blossom", 140, rotate=-4))
    body.append(title(150, 545, "Tower", 230, rotate=-4))
    body.append(
        '<g transform="rotate(-4 160 650)"><rect x="150" y="610" width="590" height="76" rx="38" fill="#ff4f9a" '
        'stroke="#ffffff" stroke-width="5"/>'
        '<text x="445" y="662" text-anchor="middle" font-family="Fredoka, \'Arial Rounded MT Bold\', sans-serif" '
        'font-weight="700" font-size="40" fill="#ffffff" letter-spacing="2">OBBY • ASMR • HANGOUT</text></g>'
    )
    return page(w, h, "\n".join(body))


def icon():
    s = 512
    rng = random.Random(3)
    body = [f'<rect width="{s}" height="{s}" fill="url(#sky)"/>']
    body.append('<circle cx="256" cy="330" r="230" fill="url(#glow)"/>')
    body.append(rainbow(256, 470, 235, 24))
    for x, y, r in [(40, 224, 8), (472, 216, 9), (150, 250, 6), (362, 248, 7)]:
        body.append(sparkle(x, y, r))
    body.append(cherry_tree(78, 480, 0.42, rng, lean=-1))
    body.append(cherry_tree(434, 480, 0.42, rng, lean=1))
    body.append(tower(256, 468, 5, 44, 150, 118, line=4, flag=False))
    body.append(falling_petals(rng, 14, s, s, keep_out=[(15, 15, 497, 205), (172, 185, 340, 480)], sizes=(6, 11)))
    for i in range(5):
        body.append(cloud(10 + i * 125, 492 + (i % 2) * 8, 0.85))
    body.append(title(256, 86, "Cherry Blossom", 60, anchor="middle"))
    body.append(title(256, 178, "Tower", 98, anchor="middle"))
    return page(s, s, "\n".join(body))


if __name__ == "__main__":
    (HERE / "thumbnail.html").write_text(thumbnail())
    (HERE / "icon.html").write_text(icon())
    print("wrote", HERE / "thumbnail.html", "and", HERE / "icon.html")
