#!/usr/bin/env python3
"""
Generate the Synthwave Aurorae window decoration.

    ./tools/gen-aurorae.py                 # regenerate templates/aurorae/Synthwave/
    ./tools/gen-aurorae.py --out /tmp/x    # somewhere else

Everything you'd want to retune lives in PALETTE and METRICS at the top.
Edit, re-run, re-run install.sh.

Two hard constraints on the SVG this emits, both verified against this box:

  1. KWin renders these through Qt's SVG module, which implements roughly
     SVG 1.2 Tiny. No <filter>, so no feGaussianBlur — the neon glow is faked
     with concentric strokes of decreasing opacity. No <style> selectors
     either; everything is presentation attributes.

  2. KSvg (KF6) dropped the hint-<edge>-margin elements that older Plasma
     FrameSvg supported, so a frame's margins are exactly the bounding boxes
     of its corner elements. Corner size IS border size; they cannot be
     decoupled. That's why the side borders are as wide as the corner radius.
"""

import argparse
import os
import sys

# ---------------------------------------------------------------- palette
# Same values as the Konsole colorscheme and the vim theme, so a window
# frame, its terminal, and the editor inside all agree.
PALETTE = {
    "bg":        "#000000",
    "pink":      "#FF3BFF",
    "pink_hi":   "#FF7BFF",
    "cyan":      "#00D9D9",
    "cyan_hi":   "#6BFFFF",
    "purple":    "#B84DFF",
    "purple_hi": "#D07BFF",
    "red":       "#FF3B3B",
    "green":     "#3BFF9E",
    "yellow":    "#FFD866",
    "dim":       "#7E63A8",   # inactive text
    "dim_edge":  "#4A3A5E",   # inactive frame line
}

# ---------------------------------------------------------------- metrics
# BORDER_* are both the rc values and the corner-element sizes in the SVG.
# They must agree — see constraint 2 above.
METRICS = {
    "BORDER_SIDE":   4,    # left/right frame thickness
    "BORDER_BOTTOM": 4,
    "TITLE_EDGE_TOP":    5,
    "TITLE_HEIGHT":     24,
    "TITLE_EDGE_BOTTOM": 5,
    "BUTTON":       24,    # button width and height
    "BUTTON_RING_R": 8.5,  # neon ring radius inside the button box
    "EDGE":         32,    # nominal length of a stretched edge element
}
# borderTop is the whole title bar: edge + text + edge.
BORDER_TOP = (METRICS["TITLE_EDGE_TOP"] + METRICS["TITLE_HEIGHT"]
              + METRICS["TITLE_EDGE_BOTTOM"])

# Which accent each button wears.
BUTTON_COLORS = {
    "close":       PALETTE["pink"],
    "maximize":    PALETTE["cyan"],
    "restore":     PALETTE["cyan"],
    "minimize":    PALETTE["purple"],
    "keepabove":   PALETTE["green"],
    "keepbelow":   PALETTE["green"],
    "alldesktops": PALETTE["cyan_hi"],
    "shade":       PALETTE["yellow"],
    "help":        PALETTE["yellow"],
    "applicationmenu": PALETTE["purple_hi"],
}


# ------------------------------------------------------------ svg helpers
def esc(v):
    return str(v)


def rect(x, y, w, h, **kw):
    a = " ".join(f'{k.replace("_", "-")}="{esc(v)}"' for k, v in kw.items())
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" {a}/>'


def bbox_anchor(x, y, w, h):
    """An invisible but *painted* rect pinning an element's bounding box.

    Qt computes an element's rect from its geometry, so every state group
    needs something that spans the full cell. fill-opacity 0 keeps it from
    showing while still counting.
    """
    return rect(x, y, w, h, fill=PALETTE["bg"], fill_opacity="0")


def neon(shape_fn, color, widths=((5.0, 0.10), (3.0, 0.22), (1.6, 1.0))):
    """Fake a glow: same shape stroked repeatedly, wide+faint to thin+solid.

    Qt has no filter support, so this layering is the only way to get the
    bloom that makes the palette read as neon rather than as flat lines.
    """
    return "".join(shape_fn(color, w, o) for w, o in widths)


# ------------------------------------------------------------ button art
def ring(color, sw, op):
    return (f'<circle cx="12" cy="12" r="{METRICS["BUTTON_RING_R"]}" '
            f'fill="none" stroke="{color}" stroke-width="{sw}" '
            f'stroke-opacity="{op}"/>')


def _stroke(d, color, sw, op, cap="round"):
    return (f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{sw}" '
            f'stroke-opacity="{op}" stroke-linecap="{cap}" '
            f'stroke-linejoin="round"/>')


GLYPHS = {
    "close":       "M8.6 8.6 L15.4 15.4 M15.4 8.6 L8.6 15.4",
    "maximize":    "M8.2 8.2 H15.8 V15.8 H8.2 Z",
    "restore":     "M7.4 10.2 H13.4 V16.2 H7.4 Z M10.2 10.2 V7.8 H16.2 V13.8 H13.4",
    "minimize":    "M8.0 14.4 H16.0",
    "keepabove":   "M8.2 13.4 L12 9.4 L15.8 13.4 M8.4 16.4 H15.6",
    "keepbelow":   "M8.2 10.6 L12 14.6 L15.8 10.6 M8.4 7.6 H15.6",
    "alldesktops": "M12 8.0 A4 4 0 1 1 11.99 8.0 Z",
    "shade":       "M8.0 9.2 H16.0",
    "help":        "M9.6 9.6 A2.6 2.6 0 1 1 12 13.2 M12 15.6 V15.9",
    "applicationmenu": "M8.0 9.4 H16.0 M8.0 12.0 H16.0 M8.0 14.6 H16.0",
}


def glyph(name, color, sw=1.6, op=1.0):
    return _stroke(GLYPHS[name], color, sw, op)


def button_state(name, state, color, ox):
    """One 24x24 cell for a single visual state, translated to x=ox."""
    b = METRICS["BUTTON"]
    out = [f'<g id="{state}-center" transform="translate({ox},0)">',
           bbox_anchor(0, 0, b, b)]

    if state == "active":
        out.append(neon(lambda c, w, o: ring(c, w, o), color))
        out.append(glyph(name, color))

    elif state == "hover":
        # Brighter, plus a soft interior wash so the whole button lights up.
        out.append(f'<circle cx="12" cy="12" r="{METRICS["BUTTON_RING_R"]}" '
                   f'fill="{color}" fill-opacity="0.18"/>')
        out.append(neon(lambda c, w, o: ring(c, w, min(1.0, o * 1.6)), color))
        out.append(glyph(name, "#FFFFFF", 1.8))

    elif state == "pressed":
        # Inverted: the neon fills in and the glyph punches through in black.
        out.append(f'<circle cx="12" cy="12" r="{METRICS["BUTTON_RING_R"]}" '
                   f'fill="{color}" fill-opacity="1"/>')
        out.append(glyph(name, PALETTE["bg"], 1.9))

    elif state == "inactive":
        out.append(ring(PALETTE["dim_edge"], 1.4, 1.0))
        out.append(glyph(name, PALETTE["dim"], 1.4, 0.85))

    elif state == "deactivated":
        out.append(ring(PALETTE["dim_edge"], 1.2, 0.45))
        out.append(glyph(name, PALETTE["dim_edge"], 1.2, 0.45))

    out.append("</g>")
    return "".join(out)


BUTTON_STATES = ["active", "hover", "pressed", "inactive", "deactivated"]


def button_svg(name, color):
    b = METRICS["BUTTON"]
    gap = 8  # keep cells apart so no stroke bleeds into a neighbour's bbox
    cells = [button_state(name, st, color, i * (b + gap))
             for i, st in enumerate(BUTTON_STATES)]
    w = len(BUTTON_STATES) * (b + gap)
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" version="1.1" '
            f'width="{w}" height="{b}" viewBox="0 0 {w} {b}">\n'
            f'<!-- {name} button: one cell per Aurorae state prefix -->\n'
            + "\n".join(cells) + "\n</svg>\n")


# --------------------------------------------------------- decoration art
def frame_block(prefix, ox, oy, accent_from, accent_to, line_op, fill_op):
    """A full 9-slice frame under one FrameSvg prefix.

    Element sizes are load-bearing: topleft's width becomes the left border
    and its height becomes the title bar height. See constraint 2.
    """
    s = METRICS["BORDER_SIDE"]
    bb = METRICS["BORDER_BOTTOM"]
    bt = BORDER_TOP
    e = METRICS["EDGE"]
    gid = prefix.replace("-", "_")
    g = []

    # Horizontal pink -> purple -> cyan sweep. The top edge element is
    # stretched to window width, so this becomes a full-width gradient.
    g.append(f'<defs><linearGradient id="g_{gid}" x1="0" y1="0" x2="1" y2="0">'
             f'<stop offset="0" stop-color="{accent_from}"/>'
             f'<stop offset="0.5" stop-color="{PALETTE["purple"]}"/>'
             f'<stop offset="1" stop-color="{accent_to}"/>'
             f'</linearGradient></defs>')

    def cell(eid, x, y, w, h, body=""):
        return (f'<g id="{prefix}-{eid}" transform="translate({x},{y})">'
                + bbox_anchor(0, 0, w, h) + body + "</g>")

    # --- title bar row -------------------------------------------------
    # Solid black plate, a bright rule along its bottom lip, and a dimmer
    # one along the very top.
    tl = (rect(0, 0, s, bt, fill=PALETTE["bg"], fill_opacity=fill_op)
          + _stroke(f"M0.5 {bt} V2.5 A2 2 0 0 1 2.5 0.5 H{s}",
                    accent_from, 1.0, line_op, cap="butt"))
    g.append(cell("topleft", ox, oy, s, bt, tl))

    top = (rect(0, 0, e, bt, fill=PALETTE["bg"], fill_opacity=fill_op)
           + rect(0, bt - 1, e, 1, fill=f"url(#g_{gid})", fill_opacity=line_op)
           + rect(0, 0, e, 0.5, fill=f"url(#g_{gid})",
                  fill_opacity=round(line_op * 0.45, 3)))
    g.append(cell("top", ox + s, oy, e, bt, top))

    tr = (rect(0, 0, s, bt, fill=PALETTE["bg"], fill_opacity=fill_op)
          + _stroke(f"M{s - 0.5} {bt} V2.5 A2 2 0 0 0 {s - 2.5} 0.5 H0",
                    accent_to, 1.0, line_op, cap="butt"))
    g.append(cell("topright", ox + s + e, oy, s, bt, tr))

    # --- middle row: sides frame the client area, centre stays clear ----
    g.append(cell("left", ox, oy + bt, s, e,
                  rect(0, 0, s, e, fill=PALETTE["bg"], fill_opacity=fill_op)
                  + rect(0, 0, 1, e, fill=accent_from, fill_opacity=line_op)))
    g.append(cell("center", ox + s, oy + bt, e, e))  # transparent: window content
    g.append(cell("right", ox + s + e, oy + bt, s, e,
                  rect(0, 0, s, e, fill=PALETTE["bg"], fill_opacity=fill_op)
                  + rect(s - 1, 0, 1, e, fill=accent_to, fill_opacity=line_op)))

    # --- bottom row ----------------------------------------------------
    y = oy + bt + e
    g.append(cell("bottomleft", ox, y, s, bb,
                  rect(0, 0, s, bb, fill=PALETTE["bg"], fill_opacity=fill_op)
                  + _stroke(f"M0.5 0 V{bb - 2.5} A2 2 0 0 0 2.5 {bb - 0.5} H{s}",
                            accent_from, 1.0, line_op, cap="butt")))
    g.append(cell("bottom", ox + s, y, e, bb,
                  rect(0, 0, e, bb, fill=PALETTE["bg"], fill_opacity=fill_op)
                  + rect(0, bb - 1, e, 1, fill=f"url(#g_{gid})",
                         fill_opacity=line_op)))
    g.append(cell("bottomright", ox + s + e, y, s, bb,
                  rect(0, 0, s, bb, fill=PALETTE["bg"], fill_opacity=fill_op)
                  + _stroke(f"M{s - 0.5} 0 V{bb - 2.5} A2 2 0 0 1 {s - 2.5} "
                            f"{bb - 0.5} H0", accent_to, 1.0, line_op, cap="butt")))
    return "".join(g)


def decoration_svg():
    s = METRICS["BORDER_SIDE"]
    e = METRICS["EDGE"]
    block_w = s + e + s
    block_h = BORDER_TOP + e + METRICS["BORDER_BOTTOM"]
    gap = 24

    # Focused window: full neon. Unfocused: same geometry, drained colour.
    variants = [
        ("decoration",                    PALETTE["pink"],     PALETTE["cyan"],     1.0,  1.0),
        ("decoration-inactive",           PALETTE["dim_edge"], PALETTE["dim_edge"], 0.75, 1.0),
        ("decoration-maximized",          PALETTE["pink"],     PALETTE["cyan"],     1.0,  1.0),
        ("decoration-maximized-inactive", PALETTE["dim_edge"], PALETTE["dim_edge"], 0.75, 1.0),
    ]

    parts = []
    for i, (prefix, a, b, lop, fop) in enumerate(variants):
        parts.append(frame_block(prefix, i * (block_w + gap), 0, a, b, lop, fop))

    w = len(variants) * (block_w + gap)
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" version="1.1" '
            f'width="{w}" height="{block_h}" viewBox="0 0 {w} {block_h}">\n'
            f'<!-- Synthwave window frame. One 9-slice block per state. -->\n'
            + "\n".join(parts) + "\n</svg>\n")


# ------------------------------------------------------------------- rc
def theme_rc():
    m = METRICS
    bw = m["BUTTON"]
    widths = "\n".join(
        f"ButtonWidth{k}={bw}" for k in
        ["", "Minimize", "MaximizeRestore", "Close", "Alldesktops",
         "Keepabove", "Keepbelow", "Shade", "Help", "Menu", "AppMenu"])
    return f"""\
# Synthwave Aurorae theme.
# Generated by tools/gen-aurorae.py — edit the generator, not this file.
#
# Key names here are exact: KConfig silently ignores anything it doesn't
# recognise, so a typo shows up as "the theme ignored my setting" and
# nothing else. Note the irregular casing that KWin actually reads:
# ButtonWidthAlldesktops, ButtonWidthKeepabove, ButtonWidthKeepbelow.

[General]
Animation=140
TitleAlignment=Left
TitleVerticalAlignment=Center
ActiveTextColor={PALETTE["pink"]}
InactiveTextColor={PALETTE["dim"]}
UseTextShadow=false
ActiveTextShadowColor={PALETTE["bg"]}
InactiveTextShadowColor={PALETTE["bg"]}
DecorationPosition=0

[Layout]
# Must match the corner-element sizes in decoration.svg.
BorderLeft={m["BORDER_SIDE"]}
BorderRight={m["BORDER_SIDE"]}
BorderBottom={m["BORDER_BOTTOM"]}
BorderTop={BORDER_TOP}

# No outer glow region: KWin draws its own drop shadow, and a non-zero
# padding would mean every corner element had to grow by the same amount.
PaddingLeft=0
PaddingRight=0
PaddingTop=0
PaddingBottom=0

TitleEdgeTop={m["TITLE_EDGE_TOP"]}
TitleEdgeBottom={m["TITLE_EDGE_BOTTOM"]}
TitleEdgeLeft=8
TitleEdgeRight=8
TitleEdgeTopMaximized=0
TitleEdgeBottomMaximized=3
TitleEdgeLeftMaximized=4
TitleEdgeRightMaximized=4
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight={m["TITLE_HEIGHT"]}

{widths}
ButtonHeight={bw}
ButtonSpacing=6
ButtonMarginTop=0
ButtonMarginTopMaximized=0
ExplicitButtonSpacer=8
"""


# KPackageStructure is load-bearing and easy to miss: without it KPackage
# finds the directory, reads the metadata, and then rejects it as the wrong
# package type. `kpackagetool6 --type KWin/Aurorae --list` says
#   "KPackageStructure of KPluginMetaData(...) does not match requested
#    format KWin/Aurorae"
# and the theme never appears in System Settings.
METADATA = """\
{
    "KPackageStructure": "KWin/Aurorae",
    "KPlugin": {
        "Description": "Neon-on-black window frame matching the Synthwave terminal and vim themes",
        "EnabledByDefault": true,
        "Id": "Synthwave",
        "License": "GPL-2.0-or-later",
        "Name": "Synthwave",
        "Version": "1.0"
    },
    "X-KDE-PluginInfo-Category": "Window Decoration"
}
"""


# ------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser()
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap.add_argument("--out", default=os.path.join(
        here, "templates", "aurorae", "Synthwave"))
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)

    written = []

    def write(name, data):
        p = os.path.join(args.out, name)
        with open(p, "w") as f:
            f.write(data)
        written.append((name, len(data)))

    write("decoration.svg", decoration_svg())
    for name, color in BUTTON_COLORS.items():
        write(f"{name}.svg", button_svg(name, color))
    write("Synthwaverc", theme_rc())
    write("metadata.json", METADATA)

    for name, n in written:
        print(f"  {name:24} {n:6d} bytes")
    print(f"\n{len(written)} files -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
