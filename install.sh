#!/usr/bin/env bash
# ==========================================================
# ubu-setup — recreate the Synthwave vim / konsole / bash color setup.
#
# Safe to run repeatedly: every step checks the current state first and only
# writes when something actually differs. Anything it would overwrite is
# copied into ~/.local/share/ubu-setup/backups/<timestamp>/ first.
#
#   ./install.sh --dry-run     show what would change, touch nothing
#   ./install.sh               install everything
#   ./install.sh --only vim    just one module
#   ./install.sh --list        list module names
# ==========================================================

set -uo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export REPO_DIR

# shellcheck source=lib/common.sh
. "$REPO_DIR/lib/common.sh"

MODULES=(packages bash vim konsole aurorae colors icons firefox vscode widget)
SELECTED=()

usage() {
    cat <<EOF
usage: install.sh [options]

  -n, --dry-run       print what would change; write nothing
  -f, --force         don't warn when replacing a differing file (still backed up)
      --only NAME     run only this module (repeatable)
      --skip NAME     run everything except this module (repeatable)
      --no-packages   never call apt-get; warn about missing packages instead
      --copy          copy files instead of symlinking them into the repo
      --apply-decoration
                      also SELECT the Synthwave window decoration in kwinrc.
                      Off by default: it restyles every window on the desktop.
      --colors-global set the Plasma color scheme for EVERY Qt/KDE app.
                      Off by default: only Konsole is pointed at it.
      --apply-icons   also SELECT the Synthwave icon theme in kdeglobals.
                      Off by default: it repaints every icon on the desktop.
      --add-widget    also PLACE the system monitor widget on the desktop.
                      Off by default: it mutates the desktop containment.
      --apply-vscode  also SELECT the Synthwave theme in vscode settings.json.
                      Off by default: settings.json is yours, not ours.
  -l, --list          list modules and exit
  -h, --help          this

modules: ${MODULES[*]}

state:
  backups   ${BACKUP_ROOT/#$HOME/\~}/<timestamp>/
  latest    ${BACKUP_ROOT/#$HOME/\~}/latest -> most recent run
EOF
}

skip_list=()
while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run)  DRY_RUN=1 ;;
        -f|--force)    FORCE=1 ;;
        --only)        [ $# -ge 2 ] || die "--only needs a module name"; SELECTED+=("$2"); shift ;;
        --skip)        [ $# -ge 2 ] || die "--skip needs a module name"; skip_list+=("$2"); shift ;;
        --no-packages) NO_PACKAGES=1 ;;
        --copy)        LINK_MODE=copy ;;
        --apply-decoration) AURORAE_APPLY=1 ;;
        --colors-global)    COLORS_GLOBAL=1 ;;
        --apply-icons)      ICONS_APPLY=1 ;;
        --add-widget)       WIDGET_ADD=1 ;;
        --apply-vscode)     VSCODE_APPLY=1 ;;
        -l|--list)     printf '%s\n' "${MODULES[@]}"; exit 0 ;;
        -h|--help)     usage; exit 0 ;;
        *)             die "unknown option: $1 (try --help)" ;;
    esac
    shift
done
export DRY_RUN FORCE LINK_MODE NO_PACKAGES="${NO_PACKAGES:-0}" AURORAE_APPLY="${AURORAE_APPLY:-0}" COLORS_GLOBAL="${COLORS_GLOBAL:-0}" ICONS_APPLY="${ICONS_APPLY:-0}" WIDGET_ADD="${WIDGET_ADD:-0}" VSCODE_APPLY="${VSCODE_APPLY:-0}"

# ---------- preflight ----------
[ "$(id -u)" -eq 0 ] && die "run as your normal user, not root — this installs into \$HOME"
[ -d "$TEMPLATE_DIR" ] || die "templates/ not found next to install.sh"

# ---------- resolve module list ----------
if [ ${#SELECTED[@]} -eq 0 ]; then
    SELECTED=("${MODULES[@]}")
fi
for want in "${SELECTED[@]}"; do
    printf '%s\n' "${MODULES[@]}" | grep -qx "$want" || die "no such module: $want (try --list)"
done
if [ ${#skip_list[@]} -gt 0 ]; then
    filtered=()
    for m in "${SELECTED[@]}"; do
        printf '%s\n' "${skip_list[@]}" | grep -qx "$m" || filtered+=("$m")
    done
    SELECTED=("${filtered[@]}")
fi
[ ${#SELECTED[@]} -eq 0 ] && die "every module was skipped; nothing to do"

# ---------- go ----------
printf '%subu-setup%s  %s\n' "$C_PINK" "$C_OFF" "${REPO_DIR/#$HOME/\~}"
[ "$DRY_RUN" = 1 ] && say "dry run — no files will be written"
say "modules: ${SELECTED[*]}   mode: $LINK_MODE"

for m in "${SELECTED[@]}"; do
    src="$REPO_DIR/modules/"*"-$m.sh"
    # shellcheck disable=SC2086
    src="$(echo $src)"
    [ -f "$src" ] || die "module script missing for '$m'"
    # shellcheck source=/dev/null
    . "$src"
    "module_$m" || fail "module '$m' did not complete"
done

# ---------- summary ----------
printf '\n%s%s%s changed, %s skipped' "$C_PINK" "$CHANGED" "$C_OFF" "$SKIPPED"
[ "$FAILED" -gt 0 ] && printf ', %s%s failed%s' "$C_RED" "$FAILED" "$C_OFF"
printf '\n'

if [ -n "$BACKUP_DIR" ] && [ "$DRY_RUN" != 1 ]; then
    say "backups: ${BACKUP_DIR/#$HOME/\~}"
fi

if [ "$DRY_RUN" != 1 ] && [ "$CHANGED" -gt 0 ]; then
    cat <<EOF

to see it:
  bash     exec bash -l          (or open a new terminal)
  vim      vim anything.ts
  konsole  restart konsole; new windows use the Synthwave profile
  icons    restart plasmashell, or log out, to repaint the panel
  firefox  fully quit firefox and start it again
  vscode   reload the window (Ctrl+Shift+P, Reload Window)
  widget   restart plasmashell; it does not reload QML on its own
EOF
fi

exit $(( FAILED > 0 ? 1 : 0 ))
