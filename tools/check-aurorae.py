#!/usr/bin/env python3
"""
Validate an Aurorae theme against what KWin's engine actually looks for.

    ./tools/check-aurorae.py [themedir]

The contract checked here was read off this box, not off documentation:
  * prefixes in /usr/share/kwin/aurorae/aurorae.qml and AuroraeButton.qml
  * FrameSvg's "does this prefix exist" test in libKF6Svg, which is purely
    "is there an element named <prefix>-center"
  * Qt's SVG module being SVG-1.2-Tiny-ish: no <filter>, no <style>

Exits non-zero on anything that would render wrong or silently vanish.
"""

import os
import sys
import xml.etree.ElementTree as ET

SVG = "http://www.w3.org/2000/svg"

# From aurorae.qml. Only "decoration" is mandatory; the rest degrade to it.
DECO_PREFIXES = {
    "decoration": True,
    "decoration-inactive": False,
    "decoration-maximized": False,
    "decoration-maximized-inactive": False,
    "innerborder": False,
    "innerborder-inactive": False,
}
# A 9-slice frame needs all nine; -center alone is what marks the prefix as
# present, so a missing edge is a silent visual hole rather than an error.
SLICES = ["center", "top", "bottom", "left", "right",
          "topleft", "topright", "bottomleft", "bottomright"]

# From AuroraeButton.qml.
BTN_PREFIXES = {
    "active": True,
    "hover": False,
    "pressed": False,
    "inactive": False,
    "deactivated": False,
    "hover-inactive": False,
    "pressed-inactive": False,
    "deactivated-inactive": False,
}
# From AuroraeButton.pathForButton(); menu.svg is handled by MenuButton.qml
# and falls back to the window icon, so it is not required.
BUTTONS = ["close", "maximize", "restore", "minimize", "keepabove",
           "keepbelow", "alldesktops", "shade", "help", "applicationmenu"]

errors, warnings = [], []


def err(m):
    errors.append(m)


def warn(m):
    warnings.append(m)


def load(path):
    try:
        return ET.parse(path).getroot()
    except ET.ParseError as e:
        err(f"{os.path.basename(path)}: XML parse error: {e}")
        return None


def ids(root):
    return {el.get("id") for el in root.iter() if el.get("id")}


def check_qt_safe(root, fname):
    for el in root.iter():
        tag = el.tag.split("}")[-1]
        if tag == "filter":
            err(f"{fname}: <filter> — Qt's SVG renderer ignores it; "
                f"the element will render with no effect at all")
        if tag == "style":
            err(f"{fname}: <style> block — Qt does not apply CSS selectors; "
                f"use presentation attributes instead")
        if tag == "text":
            warn(f"{fname}: <text> depends on font availability at render "
                 f"time; a path is safer")
        if el.get("class"):
            warn(f"{fname}: class= attribute has no effect without CSS")


def check_prefixes(root, fname, spec, slices):
    have = ids(root)
    for prefix, required in spec.items():
        if f"{prefix}-center" not in have:
            if required:
                err(f"{fname}: missing '{prefix}-center' — FrameSvg decides a "
                    f"prefix exists by that element alone, so this whole "
                    f"state is invisible")
            continue
        if not slices:
            continue
        missing = [s for s in slices if f"{prefix}-{s}" not in have]
        if missing:
            err(f"{fname}: prefix '{prefix}' has -center but is missing "
                f"{', '.join(missing)}")


def main():
    theme = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "templates", "aurorae", "Synthwave")

    if not os.path.isdir(theme):
        print(f"no such theme dir: {theme}", file=sys.stderr)
        return 2
    name = os.path.basename(theme)
    print(f"checking {theme}")

    # --- required files ---
    for f in ["decoration.svg", f"{name}rc", "metadata.json"]:
        if not os.path.isfile(os.path.join(theme, f)):
            err(f"missing required file: {f}")

    # The rc must be named <ThemeDirName>rc or KWin reads no config at all
    # and every metric silently falls back to a built-in default.
    rc = os.path.join(theme, f"{name}rc")
    if not os.path.isfile(rc):
        err(f"config must be named '{name}rc' to match the directory name")

    # metadata.json must declare its package type. Omit KPackageStructure and
    # KPackage still parses the file, then rejects it as the wrong format, so
    # the theme is simply absent from System Settings with nothing logged.
    meta = os.path.join(theme, "metadata.json")
    if os.path.isfile(meta):
        import json
        try:
            m = json.load(open(meta))
        except ValueError as e:
            err(f"metadata.json: invalid JSON: {e}")
            m = None
        if m is not None:
            if m.get("KPackageStructure") != "KWin/Aurorae":
                err('metadata.json: needs "KPackageStructure": "KWin/Aurorae" '
                    'at top level, or KPackage rejects the theme as the wrong '
                    'package type and it never appears in System Settings')
            pid = m.get("KPlugin", {}).get("Id")
            if pid != name:
                err(f'metadata.json: KPlugin.Id is "{pid}" but the directory '
                    f'is "{name}"; they must match')

    # --- decoration.svg ---
    p = os.path.join(theme, "decoration.svg")
    if os.path.isfile(p):
        root = load(p)
        if root is not None:
            check_qt_safe(root, "decoration.svg")
            check_prefixes(root, "decoration.svg", DECO_PREFIXES, SLICES)

    # --- buttons ---
    for b in BUTTONS:
        p = os.path.join(theme, f"{b}.svg")
        if not os.path.isfile(p):
            warn(f"{b}.svg absent — that button renders as nothing "
                 f"(visible = imagePath != \"\")")
            continue
        root = load(p)
        if root is None:
            continue
        check_qt_safe(root, f"{b}.svg")
        check_prefixes(root, f"{b}.svg", BTN_PREFIXES, None)

    # --- rc/svg agreement -------------------------------------------------
    # KSvg (KF6) has no hint-<edge>-margin support, so a frame's margins are
    # exactly its corner elements' bounding boxes. If the rc claims a border
    # the SVG doesn't draw, the frame and the layout disagree.
    if os.path.isfile(rc) and os.path.isfile(os.path.join(theme, "decoration.svg")):
        cfg = {}
        for line in open(rc):
            line = line.strip()
            if "=" in line and not line.startswith(("#", "[")):
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip()
        root = load(os.path.join(theme, "decoration.svg"))
        if root is not None:
            geom = {el.get("id"): el for el in root.iter() if el.get("id")}
            tl = geom.get("decoration-topleft")
            if tl is not None:
                anchor = tl.find(f"{{{SVG}}}rect")
                if anchor is not None:
                    w = float(anchor.get("width"))
                    h = float(anchor.get("height"))
                    for key, got, what in (("BorderLeft", w, "width"),
                                           ("BorderTop", h, "height")):
                        want = cfg.get(key)
                        if want and abs(float(want) - got) > 0.01:
                            err(f"{key}={want} in {name}rc but "
                                f"decoration-topleft {what} is {got:g}; "
                                f"corner size IS the border size")

    for w in warnings:
        print(f"  warn  {w}")
    for e in errors:
        print(f"  ERROR {e}")
    if not errors and not warnings:
        print("  all checks passed")
    elif not errors:
        print(f"\n{len(warnings)} warning(s), no errors")
    else:
        print(f"\n{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
