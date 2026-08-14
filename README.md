# ubu-setup

Recreates the Synthwave look on a fresh Ubuntu/Plasma box: Bash, Vim, Konsole,
the window decoration, the Plasma colour scheme, app icons, Firefox chrome, the
VS Code theme, and a desktop system monitor. Idempotent — run it as often as
you like, it only writes when something actually differs.

```bash
git clone <this repo> ~/Repos/ubu-setup
cd ~/Repos/ubu-setup
./bootstrap-plasma.sh        # only on a box without KDE yet — see below
./install.sh --dry-run       # see what it would do
./install.sh --apply-all     # install everything and switch it all on
```

Plain `./install.sh` installs the files but does not *select* the desktop-wide
pieces — decoration, colour scheme, icon theme, VS Code theme, widget. That is
deliberate, since each one repaints something; `--apply-all` turns them all on.

Afterwards:

```
exec bash -l                                  # prompt, LS_COLORS
kquitapp6 plasmashell && kstart plasmashell   # icons and the widget
```

then restart Konsole, fully quit and restart Firefox, and reload the VS Code
window. Drag the monitor widget where you want it with Meta+D (Edit Mode).

## Starting from a stock Ubuntu

`install.sh` themes Plasma; it does not install it. On a machine that has
never had KDE, run this first:

```bash
./bootstrap-plasma.sh --dry-run   # print every command, change nothing
./bootstrap-plasma.sh             # do it
./bootstrap-plasma.sh --dm keep   # install Plasma, leave GDM as the login screen
```

It is deliberately a separate script. `install.sh` only ever writes inside
`$HOME` and needs no privileges; this one installs packages and rewrites the
display manager, which is root's business and a different kind of risk.

It does three things: installs `kde-plasma-desktop` and the handful of extras
this repo uses, optionally makes SDDM the display manager, and records Plasma
as the login default for your user. Then log out, pick Plasma, and run
`install.sh --apply-all`.

Three details that are easy to get wrong:

* **`kde-plasma-desktop`, not the alternatives.** `plasma-desktop` alone omits
  pieces used here — `plasma-apply-colorscheme` lives in `plasma-workspace` —
  and `kubuntu-desktop` drags in a full application suite nobody asked for.
* **The Breeze icon package changes name between releases** —
  `kf6-breeze-icon-theme` on current Ubuntu, `breeze-icon-theme` on older
  ones. Every icon in this repo inherits from it, so the script probes for
  whichever exists rather than hardcoding one and failing on the other.
* **Recent Ubuntu ships Plasma Wayland-only.** There is no
  `/usr/share/xsessions` at all, so the default session is recorded as
  `Session=plasma` rather than `XSession=`. Writing the X key would name
  something nothing can resolve. The script looks for the session file and
  uses whichever key matches.

Switching the display manager is the one step that can leave you staring at a
black screen, so it prints the recovery line before doing it: from a TTY
(Ctrl+Alt+F3), `sudo systemctl disable --now sddm && sudo systemctl enable
--now gdm3`. `--dm keep` skips that step entirely — GDM can start a Plasma
session perfectly well.

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
| VS Code extension `ubu-setup.synthwave-theme` | colour theme | `code --install-extension` |
| `~/.config/Code/User/settings.json` | `workbench.colorTheme` — only with `--apply-vscode` | keyed edit |
| `<firefox profile>/chrome/userChrome.css` | synthwave browser chrome | **copy** |
| `<firefox profile>/user.js` | the pref that makes Firefox read it | **copy** |
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
    --apply-vscode  also SELECT the Synthwave theme in vscode settings.json
    --apply-all     all of the above at once
-l, --list          list modules
```

Modules: `packages`, `bash`, `vim`, `konsole`, `aurorae`, `colors`, `icons`, `firefox`, `vscode`, `widget`.

## It checks for Plasma first

Four modules only mean anything under KDE Plasma — the window decoration, the
Plasma colour scheme, the icon theme selected through `kdeglobals`, and the
plasmoid. On GNOME or a bare server every one of them would write files that
are never read, which looks like a successful install and changes nothing.

`require_plasma` in `lib/common.sh` gates them, and it keeps two questions
apart on purpose:

| | |
|---|---|
| `is_plasma` | is the **current session** Plasma? (`XDG_CURRENT_DESKTOP`, `KDE_FULL_SESSION`, `XDG_SESSION_DESKTOP`) |
| `plasma_installed` | is Plasma **on the box** at all? (`plasmashell` on `PATH`) |

Three outcomes:

* **Plasma session** — everything runs as normal.
* **Plasma installed, different session** (over SSH from a TTY, or a box with
  both) — the files are still written, with a warning that they take effect
  when you log into Plasma. Installing from a console is a legitimate thing to
  want.
* **No Plasma at all** — those four modules skip entirely and write nothing.
  `bash`, `vim`, `konsole`, `firefox` and `vscode` still run, since none of
  them care which desktop you are on.

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

## Firefox chrome

`templates/firefox/` restyles the browser frame — tabs, toolbars, address bar,
menus — in the same palette as everything else. Page content is deliberately
untouched.

A static theme (`.xpi`) is the supported route and it is not usable here:
release Firefox installs only extensions signed by Mozilla, and an unsigned
local theme can only be side-loaded temporarily through `about:debugging`,
disappearing on restart. So `userChrome.css` it is, with
`toolkit.legacyUserProfileCustomizations.stylesheets` to make Firefox read it.

The pref goes in **`user.js`, not `prefs.js`**: Firefox rewrites `prefs.js` on
exit and discards anything written there while it is running, whereas `user.js`
is re-read at every startup.

The profile directory name is random per install, so the module finds it by
parsing `profiles.ini` for the `[Profile*]` section with `Default=1` — checking
the snap location first, then `~/.mozilla/firefox`. Run Firefox once before
this module, or there is no profile to write into and it skips.

### The trap that ate an evening

**`var()` custom properties do not resolve in the chrome document.** Define
`--my-colour` on `:root`, use `var(--my-colour)` in a rule below, and the rule
silently does nothing — an unresolved `var()` voids the whole declaration
rather than falling back. A stylesheet full of them looks completely correct
and has no effect, with no error anywhere. **Every colour in `userChrome.css`
is a literal hex value for this reason.** Do not "tidy" them into variables.

The way to tell the two failure modes apart is a deliberately hideous literal
rule at the top of the file — `#TabsToolbar { background-color:#ff00ff
!important }`. If that does not fire, the sheet is not being loaded; if it
fires and your rules do not, the rules are wrong. Verify the restart was real
first: closing the window can leave the process alive, so check `pgrep
firefox` is empty.

Two smaller ones: `@namespace url(...xul)` is optional and is best left out,
since without it type selectors match in any namespace. And menus are already
XUL here — `widget.gtk.native-context-menus` defaults to false — so grey menus
are the `var()` bug, not GTK.

## VS Code

VS Code takes unsigned local extensions, so this is a real named theme in the
picker rather than a stylesheet hack. Regenerate it, never hand-edit
`templates/vscode/`:

```bash
python3 tools/gen-vscode-theme.py
```

It invents no colours. All three inputs are already in the repo, and deriving
from them is what makes the editor genuinely match rather than merely rhyme:

| Input | Drives |
|---|---|
| `templates/color-schemes/Synthwave.colors` | workbench chrome — side bar, tabs, status bar; the same values every Qt app uses |
| `templates/vim/colors/synthwave.vim` | syntax token colours, so a file in vim and the same file in VS Code highlight identically |
| `templates/konsole/Synthwave.colorscheme` | the 16 ANSI slots, so the integrated terminal matches Konsole exactly |

Vim groups map onto TextMate scopes by name (`Comment` → `comment`, `Function`
→ `entity.name.function`, …). A group missing from the vim file is skipped
rather than guessed at. Two need special handling: `Todo` and `Error` are the
only groups vim renders as coloured *backgrounds*, and VS Code paints token
colours as foreground — carrying `guifg` across would put black text on a
black editor, so the highlight colour becomes the foreground instead.

### Copying the folder does not work

The obvious install — drop the extension directory into
`~/.vscode/extensions/` — **looks** like it works and does nothing. The folder
is there with the right name, and modern VS Code ignores it: it loads only
what is listed in that directory's own `extensions.json`, which it writes
itself. `code --list-extensions` will not show it, the theme never reaches the
picker, and nothing is logged. That is exactly how it failed on a fresh VM
while appearing fine on the box it was built on.

So the module packs a `.vsix` and runs `code --install-extension`. That needs
no npm or vsce — a vsix is a zip with `[Content_Types].xml` and an
`extension.vsixmanifest` beside the payload, which `tools/make-vsix.py` writes
in about forty lines. The build is deterministic (fixed timestamps, sorted
entries) so an unchanged theme produces an identical file.

`code --list-extensions --show-versions` is the only honest check of whether
it is installed; the directory existing proves nothing. Uninstall goes through
`code --uninstall-extension` for the same reason — deleting the directory
leaves it listed in `extensions.json` and VS Code complains on every launch.

### settings.json is yours

Selecting the theme is behind `--apply-vscode` because it writes to your
`settings.json`. That file is **JSONC** — comments and trailing commas are
legal in it — and rewriting one that has comments would silently strip them.
So the module parses it as strict JSON and, if that fails, leaves the file
untouched and prints the one line to add by hand. On a plain JSON file it
merges the single key and preserves everything else.

The check runs as two passes: the first only reports what would change, so the
backup is taken *before* anything is written. Backing up afterwards would
preserve the already-modified file and be worthless.

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
