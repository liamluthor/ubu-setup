# ubu-setup

Recreates the Synthwave color setup — Vim, Konsole, and Bash — on a fresh
Ubuntu box. Idempotent: run it as often as you like, it only writes when
something actually differs.

```bash
git clone <this repo> ~/Repos/ubu-setup
cd ~/Repos/ubu-setup
./install.sh --dry-run     # see what it would do
./install.sh               # do it
```

Then `exec bash -l`, and restart Konsole.

## What it installs

| Where | What | How |
|---|---|---|
| `~/synth.rc` | prompt, `LS_COLORS`, `GREP_COLORS`, man/less colors | symlink |
| `~/.bashrc` | a marker-delimited block that sources `~/synth.rc` | in-place block |
| `~/.vimrc` | truecolor + colorscheme + mouse/clipboard/paste handling | symlink |
| `~/.vim/colors/synthwave.vim` | the Vim colorscheme | symlink |
| `~/.config/nvim/colors/synthwave.vim` | same file, if `nvim` is installed | symlink |
| `~/.local/share/konsole/Synthwave.{profile,colorscheme}` | Konsole theme | **copy** |
| `~/.config/konsolerc` | `DefaultProfile` | keyed edit |
| `~/.local/share/aurorae/themes/Synthwave/` | KWin window decoration (frame + buttons) | **copy** |
| `~/.config/kwinrc` | decoration selection — only with `--apply-decoration` | keyed edit |
| `~/.local/share/color-schemes/Synthwave.colors` | Plasma app color scheme (toolbars, menus, dialogs) | **copy** |
| `~/.config/konsolerc` | `UiSettings/ColorScheme` — Konsole's per-app override | keyed edit |
| `~/.config/kdeglobals` | the scheme for every Qt app — only with `--colors-global` | `plasma-apply-colorscheme` |
| `~/.local/share/icons/Synthwave/` | icon theme: terminal, dolphin, firefox, vscode | **copy** |
| `~/.local/share/applications/firefox_firefox.desktop` | shadows the snap's entry to reach a themed icon | **copy** |
| `~/.config/kdeglobals` | `Icons/Theme` — only with `--apply-icons` | keyed edit |
| `~/.local/share/plasma/plasmoids/org.kde.synthwave.sysmon/` | desktop system-monitor widget | **copy** |
| apt | `vim less groff-base git fonts-hack konsole` | only if missing |

## Options

```
-n, --dry-run       print what would change; write nothing
-f, --force         don't warn when replacing a differing file (still backed up)
    --only NAME     run only this module (repeatable)
    --skip NAME     run everything except this module (repeatable)
    --no-packages   never call apt-get; warn about missing packages instead
    --copy          copy files instead of symlinking them into the repo
    --apply-decoration
                    also SELECT the window decoration in kwinrc
    --colors-global set the Plasma color scheme for EVERY Qt/KDE app
    --apply-icons   also SELECT the icon theme in kdeglobals
    --add-widget    also PLACE the system monitor widget on the desktop
-l, --list          list modules
```

Modules: `packages`, `bash`, `vim`, `konsole`, `aurorae`, `colors`, `icons`, `widget`.

## Four layers, not one

Easy to conflate, since they all land in the same window:

| Layer | Paints | Changed by |
|---|---|---|
| Konsole colorscheme | the terminal grid and its 16 ANSI slots | `konsole` module |
| Aurorae theme | title bar and window frame, drawn by KWin | `aurorae` module |
| Plasma color scheme | menu/tool/tab bars, scrollbars, dialogs — every Qt app | `colors` module |
| Icon theme | app icons in the panel, menus, and file lists | `icons` module |

A gray toolbar with a themed terminal inside it means layer 3 is untouched.
Three of the four are colour; the icon theme is separate machinery and is
documented further down.

Color values in a `.colors` file are decimal `R,G,B`. KConfig does not reject
a hex string — it substitutes a default and carries on, so the symptom is
"my edit did nothing". The module validates every value before writing.

By default the scheme is applied to Konsole only, through `konsolerc`'s
per-application `ColorScheme` key. `--colors-global` applies it to every Qt/KDE
app instead.

The two paths are not the same mechanism, and assuming they are costs an
evening. Per-app, the key is enough: the app looks up the named scheme file and
loads it. Globally, the name key in `kdeglobals` is only a label recording
what's selected — Qt reads the colors from the `[Colors:*]` groups in that same
file, and writing the name does not populate them. Set only the name and you get
a `kdeglobals` that claims Synthwave while every app stays Breeze gray, with no
error anywhere. The tell on a stock box: `~/.config/kdedefaults/kdeglobals`
names a scheme and has no color groups at all, while `~/.config/kdeglobals`
carries all ten.

So the global path shells out to `plasma-apply-colorscheme`, which merges the
groups in and notifies running apps over D-Bus — most repaint without a
restart. It needs a live Plasma session, so it is not usable from a chroot or a
first-boot script.

## Window decoration

`templates/aurorae/Synthwave/` is a hand-built [Aurorae](https://develop.kde.org/)
theme — KWin's SVG-driven decoration engine, so it needs no C++ plugin and no
compilation. Regenerate it from the palette with:

```bash
./tools/gen-aurorae.py      # writes templates/aurorae/Synthwave/
./tools/check-aurorae.py    # validate against the engine's contract
```

Installing the files and *selecting* the decoration are separate: `install.sh`
copies the theme, but only `--apply-decoration` writes `kwinrc` and restyles
every window on the desktop.

Two constraints govern the SVG, both verified against this box rather than
taken from docs:

* **Qt's SVG module is roughly SVG 1.2 Tiny.** `<filter>` is ignored outright,
  so `feGaussianBlur` glow is impossible — the neon bloom is faked with
  concentric strokes of decreasing opacity. `<style>` selectors don't apply
  either; everything is presentation attributes. `check-aurorae.py` fails the
  build if either creeps in.
* **KSvg in KF6 dropped `hint-<edge>-margin`.** In older Plasma those elements
  let a corner be visually large while the layout margin stayed thin. Without
  them a frame's margins are exactly its corner elements' bounding boxes, so
  corner size *is* border size — that's why the side borders are 4px, matching
  the corner radius. The checker cross-checks `BorderLeft`/`BorderTop` in the
  rc against the actual `decoration-topleft` geometry.

The engine's contract itself was read from `/usr/share/kwin/aurorae/*.qml`
(which FrameSvg prefixes each state uses) and from the plugin binary's string
table (exact rc key names — note the irregular casing KWin really reads:
`ButtonWidthAlldesktops`, `ButtonWidthKeepabove`, `ButtonWidthKeepbelow`).
A prefix counts as "present" purely because an element named
`<prefix>-center` exists, so a typo'd id doesn't error — that state just
silently never draws. That failure mode is why the checker exists.

## Icons

`templates/icons/Synthwave/` is a deliberately tiny theme: it overrides five
names and sets `Inherits=breeze-dark`, so everything it does not define falls
through rather than coming up blank. Regenerate it, never hand-edit it:

```bash
python3 tools/gen-icons.py
```

Two kinds of file come out. `apps/<size>/utilities-terminal.svg` is
breeze-dark's own terminal icon with every colour pushed through a luminance
ramp — per-size because breeze hand-hints its small sizes and those hints are
worth keeping. `apps/scalable/<name>.svg` reuses breeze's 48px terminal
chassis — same rect, same gradient coordinates, same bevel — and swaps only
the mark inside it. That is what keeps the set looking like a set instead of
separately-drawn icons.

The marks are single-path monochrome sources where one exists:
`firefox-symbolic` from hicolor, `system-file-manager-symbolic` from breeze.
VS Code ships only a 1024px PNG, so its ribbon is authored in the generator.
Glyph bounding boxes are measured by rendering each path and reading the alpha
extents, not by parsing path data — exact for arbitrary curves, and it is what
centres every mark identically.

### Why Firefox needs a desktop entry and the others do not

Dolphin and VS Code declare ordinary icon names, and an icon theme outranks
both hicolor and `/usr/share/pixmaps`. Dolphin is shipped under two names —
`org.kde.dolphin` on some builds, the generic `system-file-manager` on others —
so the theme provides both, pointing at the same artwork. Miss one and the file
manager is the single entry in the panel that stays Breeze. Firefox's
snap entry instead hardcodes

```
Icon=/snap/firefox/current/default256.png
```

an absolute path to a raster PNG. That bypasses icon themes completely — no
theme can override it, and the panel scales one 256px bitmap down to 22px. So
`templates/applications/firefox_firefox.desktop` is a copy of the snap's entry
with that single line changed, installed into `~/.local/share/applications`
where it shadows the original. Desktop entries replace rather than merge, which
is why the copy carries all 740 lines of Mozilla's localized names and
jump-list actions; the module warns when the snap's version drifts from the
template.

That entry is installed **only** with `--apply-icons`, together with the theme
selection. `firefox-synthwave` is a name only this theme provides, so writing
the entry without selecting the theme points Firefox at an icon nothing can
resolve and it loses the icon it had — worse than doing nothing.

One consequence: `firefox-synthwave` is a name only this theme provides, so
selecting a different icon theme leaves that entry pointing at nothing and
Firefox falls back to a generic icon. `uninstall.sh` removes the entry along
with the theme, but a manual theme switch will not. Switch the entry back to
the snap's absolute path if you want it to survive that.

### It will not repaint on its own

There is no `plasma-changeicons` or `plasma-apply-icontheme` on a stock
Ubuntu/Plasma box, so unlike the colour scheme there is nothing to push a live
icon-theme change over D-Bus. `kbuildsycoca6` refreshes the service cache, but
running applications keep their old icons until restarted — expect to restart
plasmashell or log out. That is not the theme failing.

### The trap this layer hides

`index.theme` and the artwork on disk have to agree in both directions.
KIconTheme only searches directories the index declares, so a file in an
undeclared directory is invisible; and a declared directory that is missing or
empty is a dead end. Neither is logged. `_icons_validate` in the module checks
both directions before installing anything.

## System monitor widget

`templates/plasmoids/org.kde.synthwave.sysmon/` is a Plasma applet — a
KPackage directory of `metadata.json` plus QML, so like the Aurorae theme it
needs no compilation. It draws htop-shaped per-core bars down the left, with
uptime, load and the memory bars on the right.

Metrics come from **ksystemstats via the KSysGuard sensor API**, not from
polling `/proc` on a timer: the daemon is already running for Plasma's own
monitor widgets, sensors are push-updated, and nothing is spawned per tick.
Every sensor id in `main.qml` was read off the daemon's own `allSensors()`
output rather than guessed —

```bash
qdbus6 org.kde.ksystemstats1 /org/kde/ksystemstats1 \
       org.kde.ksystemstats1.allSensors --literal
```

— which is worth repeating on any box where a value reads zero, since ids vary
with which `ksystemstats_plugin_*` are installed.

Installing the package and *placing* it are separate, as with the decoration
and the icon theme: `--add-widget` adds it to the first desktop containment,
and checks every containment first so running it twice does not give you two
widgets.

### Plasmoid facts that cost time

* **plasmashell does not hot-reload QML.** Editing a file under a running
  shell changes nothing until `kquitapp6 plasmashell && kstart plasmashell`.
  There is no warning; the old widget just keeps running.
* **A stored size beats a smaller preferred size.** Widening the layout grows
  a placed widget on the next restart, but narrowing it does not shrink it.
  Shrinking means rewriting `ItemGeometriesHorizontal` in
  `plasma-org.kde.plasma.desktop-appletsrc` *while plasmashell is stopped* —
  it owns that file at runtime and will clobber a live edit — or dragging the
  handle by hand.
* **Position cannot be set from the scripting API.** `Qt.rect` is not defined
  in plasmashell's script sandbox, and assigning a plain object to
  `widget.geometry` is accepted and ignored. Hence the config route above.
* **Widgets only move in Edit Mode** (Meta+D). Plasma 6 replaced "unlock
  widgets" with it, and outside it a desktop widget looks stuck with no hint
  as to why — `immutability=1` in the config means mutable, so a widget that
  will not drag is usually just Edit Mode being off.
* **Custom properties are fine here** — unlike Firefox's `userChrome.css`,
  QML resolves them normally. Colours are literal hex only for consistency
  with the rest of the repo.

## Design notes

**Symlink vs copy.** Most files are symlinked into the repo, so editing
`~/.vimrc` in a live session shows up in `git diff` for free. Konsole's files
are the exception: KConfig saves atomically (write temp, rename over target),
and a rename *replaces* a symlink rather than writing through it. A symlinked
profile would silently detach from the repo the first time you opened Konsole's
settings dialog. Those are copied, so drift shows up as a pending change in
`--dry-run` instead.

**Why the `~/.bashrc` hook must be last.** Stock Ubuntu's `~/.bashrc` runs
`eval "$(dircolors -b)"` partway through, which sets `LS_COLORS`. `synth.rc`
exports its own, so it has to load after. The block is appended at the end;
`install.sh` also strips any hand-added bare `source ~/synth.rc` line so the
file doesn't get sourced twice.

**Guarded Vim options.** `clipmethod` (Vim ≥ 9.1.1443), `pastetoggle`
(deprecated, gone in Neovim), `clipboard` (needs `+clipboard`) and
`termguicolors` are all behind `exists()`/`has()` checks, so the same vimrc
loads clean on an older Vim or a headless box. The colorscheme ships `cterm`
fallbacks, so a 16-color tty still gets something reasonable.

The clipboard settings are VirtualBox-specific: `clipmethod=x11` is what
`VBoxClient --clipboard` bridges to the host — GNOME Wayland's native clipboard
is not bridged. Harmless elsewhere.

**Packages are checked, installed, then verified.** dpkg decides what's
missing, apt installs only that, and then dpkg is re-consulted — `apt-get` can
exit 0 having left a package unconfigured (held, or a dependency conflict it
"resolved" by dropping it), so its exit status alone isn't trusted. Finally
each binary is actually run (`konsole --version`, etc.); Qt writes warnings to
stderr on a clean `--version`, so only stdout is read. `fonts-hack` ships no
binary, so it's verified with `fc-match` instead — `Synthwave.profile` asks for
"Hack" by name and Konsole silently substitutes another font if it's absent.

Konsole is installed unconditionally rather than only on a KDE session: the
whole point of a fresh-box run is that it isn't there yet. `--only konsole`
ensures and verifies it on its own, so it works without the packages module.
`--no-packages` skips installing and fails the run if anything required is
missing, rather than continuing and writing config for a terminal that isn't
there.

**Backups.** Anything about to be overwritten is copied to
`~/.local/share/ubu-setup/backups/<timestamp>/`, laid out relative to `$HOME`,
with `backups/latest` pointing at the most recent install. One directory per
run, and the first copy of a given file wins — a single run can touch
`~/.bashrc` twice, and only the first copy is the pristine pre-run state.

## Undoing it

```bash
./uninstall.sh --dry-run
./uninstall.sh                 # remove our files, restore backups/latest
./uninstall.sh --from <dir>    # restore a specific snapshot
./uninstall.sh --no-restore    # just remove our files
```

It removes symlinks only if they still point into this repo, and removes copied
files only if they still match the template byte for byte — anything you
changed by hand is left alone. Packages are never removed.

## Adding a module

Drop `modules/NN-name.sh` defining `module_name()`, add `name` to `MODULES` in
`install.sh`. Use `install_file`, `ensure_block`, `ini_set`, and `need_pkgs`
from `lib/common.sh` — they handle dry-run, backup, and idempotency for you.

## Provenance

Captured from a working Ubuntu 26.04 / KDE box on 2026-08-14. The vimrc is a
merge of the two files that were live there: `~/.vimrc` (colorscheme) and
`~/.vimrc-orig` (the clipboard and paste work). The live `~/.vimrc` had lost
the latter; this repo keeps both.
