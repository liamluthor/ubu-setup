#!/usr/bin/env bash
# ==========================================================
# uninstall.sh — undo what install.sh did.
#
# Removes the symlinks and managed blocks this repo owns, then restores the
# most recent backup over the top so you land back where you started.
# Packages installed by 10-packages are NOT removed; that's apt's business
# and removing them could take other things with it.
#
#   ./uninstall.sh --dry-run
#   ./uninstall.sh                    restore from backups/latest
#   ./uninstall.sh --from <dir>       restore from a specific backup
#   ./uninstall.sh --no-restore       just remove our files, restore nothing
# ==========================================================

set -uo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export REPO_DIR

# Our own safety copies go in their own namespace and must not claim "latest";
# "latest" has to keep pointing at the snapshot install.sh took.
BACKUP_PREFIX="pre-uninstall-"
UPDATE_LATEST=0

# shellcheck source=lib/common.sh
. "$REPO_DIR/lib/common.sh"

RESTORE_FROM="$BACKUP_ROOT/latest"
DO_RESTORE=1

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run)  DRY_RUN=1 ;;
        --from)        [ $# -ge 2 ] || die "--from needs a directory"; RESTORE_FROM="$2"; shift ;;
        --no-restore)  DO_RESTORE=0 ;;
        -h|--help)     sed -n '2,16p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *)             die "unknown option: $1" ;;
    esac
    shift
done

# Resolve the snapshot to a real directory NOW, before any step below takes a
# backup of its own. "latest" is a symlink, and find(1) will not descend into a
# symlinked start point unless it is resolved (or -L is used).
if [ "$DO_RESTORE" = 1 ]; then
    if [ -e "$RESTORE_FROM" ]; then
        RESTORE_FROM="$(readlink -f "$RESTORE_FROM")"
    fi
fi

# Files this repo installs. Symlinks are removed only if they still point at
# us — a file you replaced by hand since is yours, and stays.
# Destination -> the template it came from. Only needed where basename alone
# is ambiguous, which a directory theme makes it: six files are all called
# utilities-terminal.svg, and matching by name would compare every size
# against whichever one find(1) hit first.
#
# Held as "dest<TAB>template" strings in a plain indexed array rather than the
# associative array this obviously wants. macOS ships bash 3.2 — bash 4 went
# GPLv3 and Apple never shipped it — and `declare -A` there fails outright,
# after which ${OWNED_TPL[$f]} evaluates the path as ARITHMETIC and dies with
# "operand expected" once per file. A tab is safe as the separator because
# every key is an absolute path.
OWNED_TPL=()

_owned_tpl_set() { OWNED_TPL+=("$1	$2"); }

# Prints the template for $1, or nothing. The ${arr[@]+...} guard is for the
# empty case: under `set -u`, bash 3.2 treats "${arr[@]}" on an empty array as
# an unbound variable and aborts.
_owned_tpl_get() {
    local want="$1" e
    for e in ${OWNED_TPL[@]+"${OWNED_TPL[@]}"}; do
        case "$e" in
            "$want	"*) printf '%s' "${e#*	}"; return 0 ;;
        esac
    done
    return 1
}

OWNED=(
    "$HOME/synth.rc"
    "$HOME/banner.sh"
    "$HOME/.synthwave-shell.zshrc"
    "$HOME/.synthwave-banner.zsh"
    "$HOME/.vimrc"
    "$HOME/.vim/colors/synthwave.vim"
    "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/colors/synthwave.vim"
    "${XDG_DATA_HOME:-$HOME/.local/share}/konsole/Synthwave.colorscheme"
    "${XDG_DATA_HOME:-$HOME/.local/share}/konsole/Synthwave.profile"
    "${XDG_DATA_HOME:-$HOME/.local/share}/color-schemes/Synthwave.colors"
)

# The icon theme is a directory too, and a deeper one — apps/<size>/ and
# apps/scalable/ — so this walk is recursive where aurorae's is flat.
_icons_dir="${XDG_DATA_HOME:-$HOME/.local/share}/icons/Synthwave"
if [ -d "$_icons_dir" ]; then
    while IFS= read -r _f; do
        OWNED+=("$_icons_dir/$_f")
        _owned_tpl_set "$_icons_dir/$_f" "$TEMPLATE_DIR/icons/Synthwave/$_f"
    done < <(cd "$_icons_dir" && find . -type f -printf '%P\n')
fi

# The firefox desktop entry is a copy, not a symlink, so the loop below can
# only match it by content. Add it only when it still matches our template —
# if the snap's entry drifted and you refreshed it by hand, it is yours.
_ff_dst="${XDG_DATA_HOME:-$HOME/.local/share}/applications/firefox_firefox.desktop"
_ff_src="$REPO_DIR/templates/applications/firefox_firefox.desktop"
if [ -f "$_ff_dst" ] && [ -f "$_ff_src" ] && cmp -s "$_ff_dst" "$_ff_src"; then
    OWNED+=("$_ff_dst")
    _owned_tpl_set "$_ff_dst" "$_ff_src"
fi

# Firefox's two files live in a profile whose directory name is random, so it
# has to be discovered the same way the module discovers it.
for _root in "$HOME/snap/firefox/common/.mozilla/firefox" "$HOME/.mozilla/firefox"; do
    [ -f "$_root/profiles.ini" ] || continue
    _pp="$(awk -F= '
        /^\[/                     { inp = ($0 ~ /^\[Profile/); p = ""; d = 0 }
        inp && $1 == "Path"        { p = $2 }
        inp && $1 == "Default"     { d = ($2 == 1) }
        inp && p != "" && d        { print p; exit }
    ' "$_root/profiles.ini")"
    [ -n "$_pp" ] || continue
    case "$_pp" in /*) _pd="$_pp" ;; *) _pd="$_root/$_pp" ;; esac
    for _f in chrome/userChrome.css user.js; do
        if [ -f "$_pd/$_f" ]; then
            OWNED+=("$_pd/$_f")
            _owned_tpl_set "$_pd/$_f" "$TEMPLATE_DIR/firefox/$(basename "$_f")"
        fi
    done
done

# The plasmoid is a KPackage directory, same shape as the icon theme.
_widget_dir="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/org.kde.synthwave.sysmon"
if [ -d "$_widget_dir" ]; then
    while IFS= read -r _f; do
        OWNED+=("$_widget_dir/$_f")
        _owned_tpl_set "$_widget_dir/$_f" "$TEMPLATE_DIR/plasmoids/org.kde.synthwave.sysmon/$_f"
    done < <(cd "$_widget_dir" && find . -type f -printf '%P\n')
fi

# The aurorae theme is a whole directory; add its files to the list.
_aurorae_dir="${XDG_DATA_HOME:-$HOME/.local/share}/aurorae/themes/Synthwave"
if [ -d "$_aurorae_dir" ]; then
    while IFS= read -r _f; do
        OWNED+=("$_aurorae_dir/$_f")
        _owned_tpl_set "$_aurorae_dir/$_f" "$TEMPLATE_DIR/aurorae/Synthwave/$_f"
    done < <(cd "$_aurorae_dir" && find . -maxdepth 1 -type f -printf '%P\n')
fi

head1 "removing installed files"
for f in "${OWNED[@]}"; do
    rel="${f/#$HOME/\~}"
    if [ -L "$f" ]; then
        target="$(readlink -f "$f" 2>/dev/null || true)"
        case "$target" in
            "$REPO_DIR"/*) run rm -f "$f" && ok "removed $rel" ;;
            *)             skip "$rel is a symlink we don't own — left alone" ;;
        esac
    elif [ -f "$f" ]; then
        # copy-mode install, or Konsole rewrote it. Remove only if it still
        # matches a template byte for byte.
        tpl="$(_owned_tpl_get "$f" || true)"
        if [ -z "$tpl" ]; then
            # Unambiguous single files still resolve by name.
            name="$(basename "$f")"
            tpl="$(find "$TEMPLATE_DIR" -name "$name" -type f -print -quit 2>/dev/null)"
        fi
        if [ -n "$tpl" ] && cmp -s "$tpl" "$f"; then
            run rm -f "$f" && ok "removed $rel"
        else
            skip "$rel differs from the template — left alone"
        fi
    else
        skip "$rel not present"
    fi
done

head1 "removing managed blocks"
for f in "$HOME/.bashrc" "$HOME/.zshrc"; do
    rel="${f/#$HOME/\~}"
    if [ -f "$f" ] && grep -qF "$BLOCK_BEGIN" "$f"; then
        backup "$f"
        if [ "$DRY_RUN" = 1 ]; then
            printf '  %s$ strip ubu-setup block from %s%s\n' "$C_DIM" "$rel" "$C_OFF"
        else
            tmp="$(mktemp)"
            awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
                index($0,b){inb=1; next}
                index($0,e){inb=0; next}
                !inb{print}
            ' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; fail "strip block from $rel"; }
        fi
        ok "stripped block from $rel"
    else
        skip "$rel has no ubu-setup block"
    fi
done

head1 "terminal.app profile"
# The two default keys are reset BEFORE the profile is deleted, not after.
# Terminal does fall back to Basic for a name it cannot resolve, but it also
# writes that unresolvable name straight back into its prefs when it quits, so
# deleting a profile that is still named as the default leaves a ghost entry in
# the settings list that cannot be selected or removed from the UI.
if ! is_macos; then
    skip "Terminal.app profile is macOS-only"
else
    _tdom="com.apple.Terminal"
    _tprof="Synthwave"
    _tprefs="$HOME/Library/Preferences/com.apple.Terminal.plist"

    for _k in "Default Window Settings" "Startup Window Settings"; do
        if [ "$(defaults read "$_tdom" "$_k" 2>/dev/null || true)" = "$_tprof" ]; then
            backup "$_tprefs"
            run defaults write "$_tdom" "$_k" -string Basic && ok "$_k reset to Basic"
        else
            skip "$_k does not use $_tprof"
        fi
    done

    # `defaults` has no way to remove one key from a dict value, so the domain
    # is exported, edited with PlistBuddy, and imported whole. Going through
    # defaults rather than writing the plist directly keeps cfprefsd — which
    # owns and caches that file — in the loop.
    _tdump="$(mktemp)"
    if defaults export "$_tdom" "$_tdump" 2>/dev/null \
        && /usr/libexec/PlistBuddy -c "Print :'Window Settings':$_tprof:name" "$_tdump" >/dev/null 2>&1; then
        backup "$_tprefs"
        if /usr/libexec/PlistBuddy -c "Delete :'Window Settings':$_tprof" "$_tdump" >/dev/null 2>&1; then
            run defaults import "$_tdom" "$_tdump" && ok "removed Terminal profile '$_tprof'"
        else
            fail "could not delete '$_tprof' from the exported prefs"
        fi
    else
        skip "Terminal has no '$_tprof' profile"
    fi
    rm -f "$_tdump"

    # Counted, not `pgrep`/`grep -q` — see the note on _terminal_running in
    # modules/45-macos.sh for why both of those report false here.
    if [ "$(ps -Awwo comm= 2>/dev/null | grep -c '/Terminal\.app/Contents/MacOS/Terminal$')" -gt 0 ]; then
        warn "Terminal is running — quit it completely (cmd-Q) for this to stick"
    fi
fi

head1 "window decoration"
# Leaving kwinrc pointing at a theme whose files are gone gives you an
# unstyled frame with no clue why, so put Breeze back.
_kwinrc="${XDG_CONFIG_HOME:-$HOME/.config}/kwinrc"
for _g in org.kde.kdecoration3 org.kde.kdecoration2; do
    if [ "$(ini_get "$_kwinrc" "$_g" theme 2>/dev/null || true)" = "__aurorae__svg__Synthwave" ]; then
        ini_set "$_kwinrc" "$_g" library org.kde.breeze
        ini_set "$_kwinrc" "$_g" theme Breeze
        _reverted=1
    fi
done
if [ "${_reverted:-0}" = 1 ]; then
    if [ "$DRY_RUN" != 1 ]; then
        _qdbus="$(command -v qdbus6 || command -v qdbus || echo /usr/lib/qt6/bin/qdbus)"
        [ -x "$_qdbus" ] && "$_qdbus" org.kde.KWin /KWin reconfigure >/dev/null 2>&1
    fi
else
    skip "kwinrc does not use the Synthwave decoration"
fi

head1 "vscode theme"
# The extension is installed through vscode's own CLI, so remove it the same
# way. Deleting the directory by hand would leave it listed in vscode's
# extensions.json and it would report a missing extension on every launch.
if command -v code >/dev/null 2>&1 \
   && code --list-extensions 2>/dev/null | grep -qx ubu-setup.synthwave-theme; then
    if [ "$DRY_RUN" = 1 ]; then
        skip "would code --uninstall-extension ubu-setup.synthwave-theme"
    elif code --uninstall-extension ubu-setup.synthwave-theme >/dev/null 2>&1; then
        ok "uninstalled ubu-setup.synthwave-theme"
    else
        warn "code --uninstall-extension failed; remove it from the Extensions view"
    fi
else
    skip "synthwave theme extension not installed"
fi

# Leaving settings.json naming a theme whose extension is gone makes vscode
# complain on every launch, so put the stock dark theme back.
_vsc_settings="$HOME/.config/Code/User/settings.json"
if [ ! -f "$_vsc_settings" ]; then
    skip "no vscode settings.json"
elif [ "$DRY_RUN" = 1 ]; then
    skip "would reset workbench.colorTheme if it names Synthwave"
else
    _vsc_out="$(python3 "$REPO_DIR/tools/vscode-unselect.py" "$_vsc_settings" 2>&1 || echo ERROR)"
    case "$_vsc_out" in
        RESET)   ok "settings.json colorTheme reset to Dark Modern" ;;
        NOTOURS) skip "settings.json does not select Synthwave" ;;
        *)       warn "left settings.json alone ($_vsc_out)" ;;
    esac
fi

head1 "ghidra theme"
# The installed copy is not byte-comparable with the template — Ghidra
# rewrites theme files, sorting keys and dropping comments — so it is matched
# by the same parsed comparison the module installs with.
# shellcheck source=modules/87-ghidra.sh
. "$REPO_DIR/modules/87-ghidra.sh"
_gh_found=0
for _gd in "${XDG_CONFIG_HOME:-$HOME/.config}"/ghidra/ghidra_*/; do
    [ -d "$_gd" ] || continue
    _gd="${_gd%/}"
    _gh_found=1
    _gt="$_gd/themes/$GHIDRA_THEME_NAME.theme"
    _gp="$_gd/preferences"

    # Clear the selection BEFORE deleting the file. Ghidra pointed at a theme
    # file that no longer exists logs an error on every launch; with no Theme
    # key at all it quietly uses its default.
    if [ -f "$_gp" ] && grep -qxF "Theme=File\\:$_gt" "$_gp"; then
        backup "$_gp"
        _gok=1
        if [ "$DRY_RUN" = 1 ]; then
            printf '  %s$ remove Theme from %s%s\n' "$C_DIM" "${_gp/#$HOME/\~}" "$C_OFF"
        else
            _tmp="$(mktemp)"
            # grep -v exits 1 when it prints nothing, which is the normal
            # outcome when Theme was the file's only line.
            { grep -vxF "Theme=File\\:$_gt" "$_gp" > "$_tmp" || [ $? -eq 1 ]; } \
                && mv "$_tmp" "$_gp" \
                || { rm -f "$_tmp"; fail "edit ${_gp/#$HOME/\~}"; _gok=0; }
        fi
        [ "$_gok" = 1 ] && ok "${_gp/#$HOME/\~} no longer selects $GHIDRA_THEME_NAME"
    else
        skip "${_gp/#$HOME/\~} does not select $GHIDRA_THEME_NAME"
    fi

    if [ ! -f "$_gt" ]; then
        skip "${_gt/#$HOME/\~} not present"
    elif _ghidra_same_theme "$TEMPLATE_DIR/ghidra/$GHIDRA_THEME_NAME.theme" "$_gt"; then
        run rm -f "$_gt" && ok "removed ${_gt/#$HOME/\~}"
    else
        skip "${_gt/#$HOME/\~} differs from the template — left alone"
    fi
done
[ "$_gh_found" = 1 ] || skip "no ghidra settings directory"
if _ghidra_running; then
    warn "ghidra is running — quit it, or it writes the old Theme back on exit"
fi

head1 "system monitor widget"
# Deleting the package while the applet is still on the desktop leaves
# plasmashell rendering an error placeholder where the widget was, so take it
# off the containment first.
_qd="$(command -v qdbus6 || command -v qdbus || echo /usr/lib/qt6/bin/qdbus)"
if [ -x "$_qd" ] && pgrep -x plasmashell >/dev/null 2>&1; then
    if [ "$DRY_RUN" = 1 ]; then
        skip "would remove the widget from the desktop"
    else
        _out="$("$_qd" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
var n = 0;
var ds = desktops();
for (var i = 0; i < ds.length; ++i) {
    var ws = ds[i].widgets();
    for (var j = 0; j < ws.length; ++j) {
        if (ws[j].type == "org.kde.synthwave.sysmon") { ws[j].remove(); n++; }
    }
}
print("REMOVED " + n);
' 2>&1)"
        case "$_out" in
            *"REMOVED 0"*) skip "widget was not on the desktop" ;;
            *REMOVED*)     ok "removed the widget from the desktop" ;;
            *)             warn "could not remove the widget: $_out" ;;
        esac
    fi
else
    skip "plasmashell not running; leaving the desktop containment alone"
fi

head1 "color scheme"
# Deleting the .colors file un-paints nothing. The colours live as [Colors:*]
# groups merged into kdeglobals; the file is only where they came from. So the
# revert has to go back through the same applier that put them there, or every
# Qt app keeps the Synthwave palette with no file left to explain it.
_kdeglobals="${XDG_CONFIG_HOME:-$HOME/.config}/kdeglobals"
if [ "$(ini_get "$_kdeglobals" General ColorScheme 2>/dev/null || true)" = "Synthwave" ]; then
    _applier="$(command -v plasma-apply-colorscheme || true)"
    if [ -n "$_applier" ]; then
        if run "$_applier" BreezeDark >/dev/null 2>&1; then
            ok "restored BreezeDark for every Qt app"
        else
            fail "plasma-apply-colorscheme BreezeDark"
        fi
    else
        warn "plasma-apply-colorscheme absent — kdeglobals keeps the Synthwave"
        warn "  [Colors:*] groups; pick a scheme in System Settings to clear them"
    fi
else
    skip "kdeglobals does not select the Synthwave color scheme"
fi

# Konsole's per-app override is a name key and nothing else, so unlike the
# global path this one really does revert by writing it.
_krc="${XDG_CONFIG_HOME:-$HOME/.config}/konsolerc"
if [ "$(ini_get "$_krc" UiSettings ColorScheme 2>/dev/null || true)" = "Synthwave" ]; then
    ini_set "$_krc" UiSettings ColorScheme BreezeDark
else
    skip "konsolerc does not use the Synthwave color scheme"
fi

head1 "icon theme"
# Same reasoning as the decoration: kdeglobals naming a theme whose files are
# gone means every overridden icon falls back with no explanation.
_kdeglobals="${XDG_CONFIG_HOME:-$HOME/.config}/kdeglobals"
if [ "$(ini_get "$_kdeglobals" Icons Theme 2>/dev/null || true)" = "Synthwave" ]; then
    ini_set "$_kdeglobals" Icons Theme breeze-dark
    if [ "$DRY_RUN" != 1 ] && command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 >/dev/null 2>&1 || true
    fi
    warn "running apps keep the old icons until restarted"
else
    skip "kdeglobals does not select the Synthwave icon theme"
fi

head1 "konsole default profile"
krc="${XDG_CONFIG_HOME:-$HOME/.config}/konsolerc"
if [ "$(ini_get "$krc" "Desktop Entry" "DefaultProfile" 2>/dev/null || true)" = "Synthwave.profile" ]; then
    warn "konsolerc still points at Synthwave.profile — set a profile in Konsole's settings,"
    warn "or it will fall back to the built-in default once the file is gone"
else
    skip "konsolerc does not point at Synthwave.profile"
fi

if [ "$DO_RESTORE" = 1 ]; then
    head1 "restoring backup"
    if [ ! -d "$RESTORE_FROM" ]; then
        warn "no backup at ${RESTORE_FROM/#$HOME/\~} — nothing to restore"
    else
        say "  from ${RESTORE_FROM/#$HOME/\~}"
        while IFS= read -r -d '' src; do
            rel="${src#"$RESTORE_FROM"/}"
            dest="$HOME/$rel"
            run mkdir -p "$(dirname "$dest")"
            run cp -a "$src" "$dest" && ok "restored ~/$rel"
        done < <(find "$RESTORE_FROM" \( -type f -o -type l \) -print0 2>/dev/null)
    fi
fi

printf '\n%s%s%s changed, %s skipped' "$C_PINK" "$CHANGED" "$C_OFF" "$SKIPPED"
[ "$FAILED" -gt 0 ] && printf ', %s%s failed%s' "$C_RED" "$FAILED" "$C_OFF"
printf '\n'
exit $(( FAILED > 0 ? 1 : 0 ))
