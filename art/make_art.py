"""Draws the Roblox game icon and thumbnail for Pretty Pink Tower.

Writes icon.html (512x512) and thumbnail.html (1920x1080) next to this file. Render them to PNG with:

    python3 art/make_art.py && art/render.sh

Everything is plain SVG, so colours and sizes below are easy to tweak.
"""

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


def tower(cx, base_y, levels, level_h, bottom_w, top_w, line=5, flag=True):
    parts = []
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
    # pointy roof
    roof_w = top_w + level_h * 0.55
    roof_h = level_h * 1.6
    tip = top_y - level_h * 0.07 - roof_h
    parts.append(
        f'<path d="M{cx - roof_w / 2:.1f},{top_y - level_h * 0.05:.1f} L{cx:.1f},{tip:.1f} L{cx + roof_w / 2:.1f},{top_y - level_h * 0.05:.1f}Z" '
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
    body = [f'<rect width="{w}" height="{h}" fill="url(#sky)"/>']
    body.append('<circle cx="1420" cy="330" r="420" fill="url(#glow)"/>')
    body.append(rainbow(1420, 1000, 900, 58))
    for cx, cy, s, o in [(260, 150, 1.1, 0.9), (930, 110, 0.8, 0.8), (1820, 200, 1.0, 0.85), (700, 330, 0.6, 0.6)]:
        body.append(cloud(cx, cy, s, o))
    for x, y, r, o in [
        (180, 520, 18, 0.9), (980, 250, 14, 0.8), (1110, 520, 22, 0.9), (1760, 380, 16, 0.9),
        (1560, 150, 12, 0.8), (620, 760, 14, 0.7), (1840, 650, 20, 0.9), (420, 90, 10, 0.7),
    ]:
        body.append(sparkle(x, y, r, opacity=o))
    body.append(tower(1420, 985, 8, 82, 330, 250, line=6))
    # floating platforms climbing up the right side, with a player jumping between them
    for x, y, pw, c in [(1640, 900, 150, 0), (1720, 780, 130, 1), (1640, 660, 120, 2), (1730, 545, 120, 3)]:
        body.append(platform(x, y, pw, PLATFORMS[c]))
    body.append(character(1700, 610, s=1.05))
    body.append(sparkle(1770, 470, 14, "#ffe066"))
    # fluffy cloud floor
    for i in range(12):
        body.append(cloud(80 + i * 170, 1040 + (i % 2) * 18, 1.5))
    body.append(title(110, 330, "Pretty Pink", 172, rotate=-4))
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
    body = [f'<rect width="{s}" height="{s}" fill="url(#sky)"/>']
    body.append('<circle cx="256" cy="330" r="230" fill="url(#glow)"/>')
    body.append(rainbow(256, 470, 235, 24))
    body.append(cloud(70, 250, 0.55, 0.85))
    body.append(cloud(445, 230, 0.5, 0.85))
    for x, y, r in [(88, 330, 11), (430, 320, 13), (120, 205, 7), (395, 395, 8)]:
        body.append(sparkle(x, y, r))
    body.append(tower(256, 468, 5, 44, 150, 118, line=4, flag=False))
    for i in range(5):
        body.append(cloud(10 + i * 125, 492 + (i % 2) * 8, 0.85))
    body.append(title(256, 92, "Pretty Pink", 74, anchor="middle"))
    body.append(title(256, 178, "Tower", 98, anchor="middle"))
    return page(s, s, "\n".join(body))


if __name__ == "__main__":
    (HERE / "thumbnail.html").write_text(thumbnail())
    (HERE / "icon.html").write_text(icon())
    print("wrote", HERE / "thumbnail.html", "and", HERE / "icon.html")
