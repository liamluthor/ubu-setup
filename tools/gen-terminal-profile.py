#!/usr/bin/env python3
"""Generate the Synthwave macOS Terminal.app profile into templates/terminal/.

    python3 tools/gen-terminal-profile.py [outdir]

Nothing here invents colours. Both inputs already exist in the repo, and
deriving from them is what keeps the Mac matching the Ubuntu boxes:

  templates/konsole/Synthwave.colorscheme  -> background, foreground and the
                                              16 ANSI slots, so Terminal.app
                                              and Konsole render identically
  templates/konsole/Synthwave.profile      -> font, window size, scrollback
                                              and the blinking cursor

Re-run after changing either one; do not hand-edit templates/terminal/.

----------------------------------------------------------------------------
Why this file is 200 lines instead of 20

A .terminal file is a plist, but the colours inside it are not. Each one is an
NSColor serialised by NSKeyedArchiver and stored as an opaque <data> blob. The
obvious way to write those is pyobjc (`NSArchiver.archivedDataWithRootObject_`),
which is not installed with the stock python3 on macOS and does not exist at
all on the Ubuntu boxes this repo is otherwise for. So the archive is built by
hand below.

The format was not guessed. It was read back out of Terminal.app's own
built-in profiles (`defaults export com.apple.Terminal -`, then plistlib on
the blobs), which is also where the three quirks encoded here came from:

  * NSColorSpace 2 is device RGB, and its components live under the NSRGB key
    as a SPACE-SEPARATED ASCII string with a TRAILING NUL. Not floats, not an
    array -- a C string. Alpha is an optional fourth component, present only
    when the colour is actually translucent (Apple's own "Red Sands" has four,
    "Grass" has three).
  * Those components are float32. Apple's encoder rounds through a single and
    prints 8 significant digits, so 19/255 serialises as "0.074509807", not
    "0.0745098039215686". Emitting full double precision works, but then every
    colour differs from what Terminal writes back the moment you open the
    settings dialog, and `install.sh --dry-run` reports permanent drift.
  * NSFont wants the POSTSCRIPT name ("Hack-Regular"), not the family name
    that Konsole stores ("Hack"). Give it the family and Terminal silently
    falls back to Menlo, which looks like the profile simply didn't apply.
"""
import os
import plistlib
import struct
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TPL = f'{HERE}/templates'

PROFILE_NAME = 'Synthwave'

# Terminal.app stamps this into every profile it writes. Omitting it makes
# Terminal treat the profile as pre-10.7 and re-interpret some keys.
PROFILE_VERSION = 2.09

# Konsole stores a font family; NSFont needs the PostScript name. For the
# regular weight of most monospace families that is "<Family>-Regular" with
# spaces removed, but the mapping is not guaranteed, so known fonts are listed
# explicitly and the rule is only the fallback.
FONT_POSTSCRIPT = {
    'Hack': 'Hack-Regular',
    'Menlo': 'Menlo-Regular',
    'Monaco': 'Monaco',               # no -Regular suffix; Apple's own naming
    'Courier New': 'CourierNewPSMT',
    'SF Mono': 'SFMono-Regular',
    'JetBrains Mono': 'JetBrainsMono-Regular',
    'Fira Code': 'FiraCode-Regular',
}

# Konsole colour slot -> Terminal.app key. Konsole numbers the slots; Apple
# names them. The order is the ANSI order, so Color0..Color7 maps straight
# across, and the Intense variants are Apple's Bright set.
ANSI_ORDER = ['Black', 'Red', 'Green', 'Yellow', 'Blue', 'Magenta', 'Cyan', 'White']


# ---------- inputs ----------------------------------------------------------

def kconfig(path):
    """Parse an INI-ish KConfig file into {section: {key: value}}."""
    out, sec = {}, None
    for line in open(path):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('['):
            sec = line.strip('[]')
            out[sec] = {}
        elif sec is not None and '=' in line:
            k, v = line.split('=', 1)
            out[sec][k.strip()] = v.strip()
    return out


def rgb_triple(value):
    """'255,59,255' -> (1.0, 0.23137255, 1.0), each component 0..1."""
    parts = [int(x) for x in value.split(',')]
    if len(parts) != 3:
        raise ValueError(f'expected three components, got {value!r}')
    return tuple(p / 255.0 for p in parts)


# ---------- NSKeyedArchiver ------------------------------------------------

def f32(value):
    """Format a float the way Apple's encoder does: round to float32, 8 s.f.

    Exact 0 and 1 come out as "0" and "1", matching the built-in profiles.
    """
    single = struct.unpack('f', struct.pack('f', value))[0]
    return '%.8g' % single


def keyed_archive(obj_fields, classname, extra_objects=()):
    """Wrap one object in the $archiver/$objects/$top envelope, as binary plist.

    obj_fields is the object's own dictionary; $class is appended pointing at
    the class record, which is always the LAST entry in $objects. extra_objects
    are interned values (strings, for NSFont's name) placed between the two, so
    their UIDs start at 2.
    """
    objects = ['$null', obj_fields]
    objects.extend(extra_objects)
    obj_fields['$class'] = plistlib.UID(len(objects))
    objects.append({
        '$classname': classname,
        '$classes': [classname, 'NSObject'],
    })
    return plistlib.dumps({
        '$version': 100000,
        '$archiver': 'NSKeyedArchiver',
        '$top': {'root': plistlib.UID(1)},
        '$objects': objects,
    }, fmt=plistlib.FMT_BINARY)


def ns_color(rgb, alpha=None):
    """An NSColor in device RGB. alpha is omitted entirely when fully opaque."""
    comps = [f32(c) for c in rgb]
    if alpha is not None and alpha < 1.0:
        comps.append(f32(alpha))
    packed = (' '.join(comps) + '\x00').encode('ascii')
    return keyed_archive({'NSColorSpace': 2, 'NSRGB': packed}, 'NSColor')


def ns_font(postscript_name, size):
    """An NSFont. NSfFlags 16 is what Terminal.app writes for a plain face."""
    return keyed_archive(
        {'NSName': plistlib.UID(2), 'NSSize': float(size), 'NSfFlags': 16},
        'NSFont',
        extra_objects=[postscript_name],
    )


# ---------- build ----------------------------------------------------------

def build(scheme_path, profile_path):
    scheme = kconfig(scheme_path)
    profile = kconfig(profile_path)

    # Konsole's Opacity is the whole window's; Terminal.app has no equivalent
    # knob and instead bakes alpha into the background colour itself.
    opacity = float(scheme.get('General', {}).get('Opacity', '1'))

    out = {
        'name': PROFILE_NAME,
        'type': 'Window Settings',
        'ProfileCurrentVersion': PROFILE_VERSION,
        'BackgroundColor': ns_color(rgb_triple(scheme['Background']['Color']), opacity),
        'TextColor': ns_color(rgb_triple(scheme['Foreground']['Color'])),
        'TextBoldColor': ns_color(rgb_triple(scheme['ForegroundIntense']['Color'])),
    }

    # Konsole leaves the cursor and selection to the widget theme, which has no
    # Terminal.app counterpart. Both are taken from slots the scheme already
    # defines rather than picked: the cursor is the bold foreground (hot pink,
    # the brightest thing in the palette), the selection is the faint magenta,
    # dim enough to keep selected text readable against it.
    out['CursorColor'] = ns_color(rgb_triple(scheme['ForegroundIntense']['Color']))
    out['SelectionColor'] = ns_color(rgb_triple(scheme['Color5Faint']['Color']))

    for i, name in enumerate(ANSI_ORDER):
        out[f'ANSI{name}Color'] = ns_color(rgb_triple(scheme[f'Color{i}']['Color']))
        out[f'ANSIBright{name}Color'] = ns_color(
            rgb_triple(scheme[f'Color{i}Intense']['Color']))

    # Font=Hack,11,-1,5,50,0,0,0,0,0 — Qt's font spec. Only the first two
    # fields carry over; the rest are Qt style hints with no Apple equivalent.
    font_spec = profile.get('Appearance', {}).get('Font', 'Menlo,11')
    family, _, rest = font_spec.partition(',')
    size = rest.split(',')[0] or '11'
    postscript = FONT_POSTSCRIPT.get(family, family.replace(' ', '') + '-Regular')
    out['Font'] = ns_font(postscript, float(size))
    out['FontAntialias'] = True
    out['UseBoldFonts'] = True

    general = profile.get('General', {})
    out['columnCount'] = int(general.get('TerminalColumns', 120))
    out['rowCount'] = int(general.get('TerminalRows', 40))

    # Konsole HistoryMode: 0 none, 1 fixed, 2 unlimited.
    if profile.get('Scrolling', {}).get('HistoryMode') == '2':
        out['ShouldLimitScrollback'] = 0
    else:
        out['ShouldLimitScrollback'] = 1
        out['ScrollbackLines'] = int(profile.get('Scrolling', {}).get('HistorySize', 10000))

    features = profile.get('Terminal Features', {})
    out['CursorBlink'] = features.get('BlinkingCursorEnabled') == 'true'

    # Konsole's Blur is a boolean, Terminal's BackgroundBlur is a 0..1 radius.
    out['BackgroundBlur'] = 0.5 if scheme.get('General', {}).get('Blur') == 'true' else 0.0

    return out


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else f'{TPL}/terminal'
    profile = build(f'{TPL}/konsole/Synthwave.colorscheme',
                    f'{TPL}/konsole/Synthwave.profile')

    os.makedirs(outdir, exist_ok=True)
    dest = f'{outdir}/{PROFILE_NAME}.terminal'
    # XML, not binary: this one is checked into git, and `defaults -dict-add`
    # in the macos module parses it as text.
    with open(dest, 'wb') as fh:
        plistlib.dump(profile, fh, fmt=plistlib.FMT_XML, sort_keys=True)

    colours = sum(1 for k in profile if k.endswith('Color'))
    print(f'wrote {dest}')
    print(f'  {colours} colours, {profile["columnCount"]}x{profile["rowCount"]}, '
          f'scrollback {"unlimited" if not profile["ShouldLimitScrollback"] else profile.get("ScrollbackLines")}')


if __name__ == '__main__':
    main()
