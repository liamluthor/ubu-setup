#!/usr/bin/env python3
"""Generate the Synthwave icon theme into templates/icons/Synthwave/.

Run this, don't hand-edit the output:

    python3 tools/gen-icons.py [outdir]

The theme is deliberately tiny — it overrides five names and inherits
breeze-dark for everything else. Two kinds of icon come out of it:

  apps/<size>/utilities-terminal.svg   breeze-dark's own terminal icon with
                                       every colour run through the ramp
                                       below. Per-size because breeze hand-
                                       hints its small sizes and those hints
                                       are worth keeping.

  apps/scalable/<name>.svg             breeze's 48px terminal chassis — same
                                       rect, same gradient coordinates, same
                                       bevel — with the mark swapped out.

Everything shares one luminance ramp, which is what makes the set look like a
set: near-black tile, mark in the same cyan Synthwave.colorscheme uses for
terminal body text (0,229,229).

Needs the Breeze icon theme installed — the package is kf6-breeze-icon-theme
on current Ubuntu, breeze-icon-theme on older releases — plus python3-gi and
librsvg's gdk-pixbuf loader (for measuring glyph bounding boxes by rendering).
"""
import os
import re
import sys
import tempfile

import gi
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import GdkPixbuf

BREEZE = '/usr/share/icons/breeze-dark/apps'
FIREFOX_SYMBOLIC = '/usr/share/icons/hicolor/symbolic/apps/firefox-symbolic.svg'
FILEMANAGER_SYMBOLIC = f'{BREEZE}/22/system-file-manager-symbolic.svg'

SIZES = [16, 22, 24, 32, 48, 64]

# The ramp. Dark end is the tile, bright end is the mark. Pure #000000 and
# #ffffff are exempt: in breeze's files those are not colours, they are bevel
# overlays drawn at 0.3 opacity, and tinting them muddies the edges.
RAMP = [(0.0, (6, 6, 10)), (0.45, (22, 30, 64)), (1.0, (0, 229, 229))]
KEEP = {'#000000', '#ffffff'}

# Chassis colours, which are just the ramp applied to breeze's own values.
TILE_0, TILE_1 = '#0c0f1e', '#131936'
GLYPH_0, GLYPH_1 = '#0895a2', '#00dfe0'
SHADOW = '#0c0f1e'

TARGET = 23.0          # glyph box inside the 48-unit tile
CENTER = (24.0, 23.5)

HEX = re.compile(r'#([0-9a-fA-F]{6})\b')


def ramp(lum):
    for i in range(len(RAMP) - 1):
        p0, c0 = RAMP[i]
        p1, c1 = RAMP[i + 1]
        if p0 <= lum <= p1:
            t = (lum - p0) / (p1 - p0)
            return tuple(int(c0[k] + t * (c1[k] - c0[k])) for k in range(3))
    return RAMP[-1][1]


def recolor(match):
    h = '#' + match.group(1).lower()
    if h in KEEP:
        return match.group(0)
    r, g, b = (int(h[i:i + 2], 16) for i in (1, 3, 5))
    return '#%02x%02x%02x' % ramp((0.2126 * r + 0.7152 * g + 0.0722 * b) / 255)


CHASSIS = '''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" version="1.1">
 <defs>
  <linearGradient id="a" y1="547.634" y2="499.679" x2="388.865" gradientUnits="userSpaceOnUse" gradientTransform="translate(-384.57,-499.8)" x1="428.816">
   <stop stop-color="%(TILE_0)s"/>
   <stop offset="1" stop-color="%(TILE_1)s"/>
  </linearGradient>
  <linearGradient id="b" y1="44" y2="12" x2="14" gradientUnits="userSpaceOnUse" x1="36">
   <stop stop-color="%(GLYPH_0)s"/>
   <stop offset="1" stop-color="%(GLYPH_1)s"/>
  </linearGradient>
  <linearGradient id="c" y1="527.014" x1="406.501" y2="539.825" x2="419.974" gradientUnits="userSpaceOnUse" gradientTransform="translate(-384.57,-499.8)">
   <stop stop-color="%(SHADOW)s"/>
   <stop offset="1" stop-opacity="0"/>
  </linearGradient>
 </defs>
 <rect style="fill:url(#a)" height="40" rx="1" y="4" x="4" width="40" ry="1"/>
 <path style="fill:#000000;fill-opacity:1;opacity:0.3" d="M 4 42 L 4 43 C 4 43.554007 4.4459958 44 5 44 L 43 44 C 43.554004 44 44 43.554007 44 43 L 44 42 C 44 42.554007 43.554004 43 43 43 L 5 43 C 4.4459958 43 4 42.554007 4 42 z"/>
%(GLYPH)s
 <path d="M 4,6 4,5 C 4,4.445993 4.445996,4 5,4 l 38,0 c 0.554004,0 1,0.445993 1,1 l 0,1 C 44,5.445993 43.554004,5 43,5 L 5,5 C 4.445996,5 4,5.445993 4,6 Z" style="opacity:0.3;fill:#ffffff;fill-opacity:1"/>
</svg>
'''

# VS Code ships only a 1024px PNG, so its ribbon is authored here in a
# 0 0 100 100 box. The inner triangle is a second subpath and needs evenodd,
# or the fold fills solid.
VSCODE_D = ('M70.9 99.3a5.9 5.9 0 0 0 4.7-.2l18.3-8.8a6 6 0 0 0 3.4-5.4V14.9a6 6 0 0 0-3.4-5.4'
            'L75.6.7a5.9 5.9 0 0 0-6.8 1.2L33.8 34.4 18.6 22.8a4 4 0 0 0-5.1.2l-4.9 4.5'
            'a4 4 0 0 0 0 5.9L21.8 50 8.6 62.6a4 4 0 0 0 0 5.9l4.9 4.5a4 4 0 0 0 5.1.2'
            'l15.2-11.6 35 32.5a5.9 5.9 0 0 0 2.1 1.2z M75.2 27.3 48.4 50l26.8 22.7z')


def path_of(svg_file):
    t = open(svg_file).read()
    d = re.search(r'<path[^>]*\bd="([^"]+)"', t).group(1)
    vb = re.search(r'viewBox="([^"]+)"', t)
    return d, [float(x) for x in vb.group(1).split()]


def measure(d, vb, px=400):
    """Alpha bounding box of a path, in the path's own user units.

    Rendered rather than parsed: exact for arbitrary curves and arcs, where
    walking the path data would mean implementing a bezier hull.
    """
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{" ".join(str(v) for v in vb)}" '
           f'width="{px}" height="{px}"><path d="{d}" fill="#fff" fill-rule="evenodd"/></svg>')
    with tempfile.NamedTemporaryFile('w', suffix='.svg', delete=False) as f:
        f.write(svg)
        tmp = f.name
    try:
        pb = GdkPixbuf.Pixbuf.new_from_file(tmp)
    finally:
        os.unlink(tmp)
    w, h, rs, nc = pb.get_width(), pb.get_height(), pb.get_rowstride(), pb.get_n_channels()
    data = pb.get_pixels()
    xs, ys = [], []
    for y in range(h):
        row = y * rs
        for x in range(w):
            if data[row + x * nc + 3] > 8:
                xs.append(x)
                ys.append(y)
    if not xs:
        raise SystemExit('glyph rendered empty — bad path data?')
    sx, sy = vb[2] / w, vb[3] / h
    return (vb[0] + min(xs) * sx, vb[1] + min(ys) * sy,
            vb[0] + max(xs) * sx, vb[1] + max(ys) * sy)


def glyph_markup(d, vb):
    x0, y0, x1, y1 = measure(d, vb)
    gw, gh = x1 - x0, y1 - y0
    s = TARGET / max(gw, gh)
    t = (f'translate({CENTER[0] - (x0 + gw / 2) * s:.4f},'
         f'{CENTER[1] - (y0 + gh / 2) * s:.4f}) scale({s:.6f})')
    # breeze fakes depth with a gradient wedge cast off the chevron, which only
    # works for a chevron. An offset copy of the mark stands in, so every icon
    # in the set casts the same shadow.
    return (f' <g transform="translate(1.1,1.1) {t}" style="opacity:0.35">'
            f'<path d="{d}" fill="{SHADOW}" fill-rule="evenodd"/></g>\n'
            f' <g transform="{t}">'
            f'<path d="{d}" fill="url(#b)" fill-rule="evenodd"/></g>')


def main():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = sys.argv[1] if len(sys.argv) > 1 else f'{here}/templates/icons/Synthwave'

    for p in (BREEZE, FIREFOX_SYMBOLIC, FILEMANAGER_SYMBOLIC):
        if not os.path.exists(p):
            raise SystemExit(
                f'missing source: {p}\n'
                '(needs the Breeze icon theme — kf6-breeze-icon-theme on current\n'
                ' Ubuntu, breeze-icon-theme on older ones — and firefox for its\n'
                ' symbolic icon)')

    # --- per-size terminal: breeze's own icon, recoloured ---
    for s in SIZES:
        d = f'{out}/apps/{s}'
        os.makedirs(d, exist_ok=True)
        src = f'{BREEZE}/{s}/utilities-terminal.svg'
        open(f'{d}/utilities-terminal.svg', 'w').write(HEX.sub(recolor, open(src).read()))
        print(f'  apps/{s}/utilities-terminal.svg')

    # --- scalable: shared chassis, one glyph each ---
    # Dolphin does not declare a single icon name across packagings: some
    # builds use the reverse-DNS id, others the generic freedesktop name. Ship
    # both, pointing at the same artwork, or the file manager is the one entry
    # in the panel that stays Breeze while everything else themes.
    dolphin_glyph = path_of(FILEMANAGER_SYMBOLIC)
    glyphs = {
        'firefox-synthwave': path_of(FIREFOX_SYMBOLIC),
        'org.kde.dolphin': dolphin_glyph,
        'system-file-manager': dolphin_glyph,
        'vscode': (VSCODE_D, [0, 0, 100, 100]),
    }
    os.makedirs(f'{out}/apps/scalable', exist_ok=True)
    for name, (d, vb) in glyphs.items():
        svg = CHASSIS % dict(TILE_0=TILE_0, TILE_1=TILE_1, GLYPH_0=GLYPH_0,
                             GLYPH_1=GLYPH_1, SHADOW=SHADOW, GLYPH=glyph_markup(d, vb))
        open(f'{out}/apps/scalable/{name}.svg', 'w').write(svg)
        print(f'  apps/scalable/{name}.svg')

    # --- index.theme ---
    dirs = [f'apps/{s}' for s in SIZES] + ['apps/scalable']
    lines = ['[Icon Theme]', 'Name=Synthwave',
             'Comment=Synthwave overrides layered on Breeze Dark',
             'Inherits=breeze-dark,breeze,hicolor',
             'Directories=' + ','.join(dirs), '']
    for s in SIZES:
        lines += [f'[apps/{s}]', f'Size={s}', 'Context=Applications', 'Type=Fixed', '']
    lines += ['[apps/scalable]', 'Size=48', 'MinSize=8', 'MaxSize=512',
              'Context=Applications', 'Type=Scalable', '']
    open(f'{out}/index.theme', 'w').write('\n'.join(lines))
    print('  index.theme')


if __name__ == '__main__':
    main()
