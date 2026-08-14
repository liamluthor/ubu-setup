#!/usr/bin/env bash
# ==========================================================
# bootstrap-plasma.sh — put KDE Plasma on a fresh Ubuntu and make it the
# default session, so that install.sh has something to theme.
#
# Separate from install.sh on purpose. install.sh only ever writes inside
# $HOME and needs no privileges; this one installs packages and rewrites the
# display manager, which is root's business and a different kind of risk.
#
#   ./bootstrap-plasma.sh --dry-run    # print every command, change nothing
#   ./bootstrap-plasma.sh              # do it
#   ./bootstrap-plasma.sh --dm keep    # install Plasma, leave GDM alone
#
# Afterwards: log out (or reboot), pick the Plasma session, then run
#   ./install.sh --apply-all
# ==========================================================

set -uo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export REPO_DIR
# shellcheck source=lib/common.sh
. "$REPO_DIR/lib/common.sh"

DM_CHOICE="sddm"
TARGET_USER="${SUDO_USER:-$USER}"

usage() {
    cat <<EOF
usage: bootstrap-plasma.sh [options]

  -n, --dry-run     print what would happen; change nothing
      --dm WHICH    display manager: sddm (default) | keep
      --user NAME   whose default session to set (default: $TARGET_USER)
  -h, --help        this

Installs Plasma, optionally makes SDDM the display manager, and records
Plasma as the default session for the user. Run install.sh afterwards.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=1 ;;
        --dm)   [ $# -ge 2 ] || die "--dm needs a value"; DM_CHOICE="$2"; shift ;;
        --user) [ $# -ge 2 ] || die "--user needs a name"; TARGET_USER="$2"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
    shift
done
export DRY_RUN

case "$DM_CHOICE" in
    sddm|keep) ;;
    *) die "--dm must be sddm or keep" ;;
esac

# ---------- preflight ----------
command -v apt-get >/dev/null 2>&1 || die "no apt-get; this script is for Debian/Ubuntu"
id "$TARGET_USER" >/dev/null 2>&1 || die "no such user: $TARGET_USER"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || die "not root and no sudo available"
    SUDO="sudo"
fi

printf '%sbootstrap-plasma%s  %s\n' "$C_PINK" "$C_OFF" \
    "$( . /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" )"
[ "$DRY_RUN" = 1 ] && say "dry run — nothing will be installed or changed"
say "user: $TARGET_USER   display manager: $DM_CHOICE"

# ---------- packages ----------
head1 "plasma packages"

# kde-plasma-desktop is the middle option deliberately: plasma-desktop alone
# misses pieces this repo uses (plasma-apply-colorscheme lives in
# plasma-workspace), while kubuntu-desktop drags in a full application suite
# nobody asked for.
PKGS=(kde-plasma-desktop plasma-workspace konsole dolphin ksystemstats)

# The Breeze icon theme is the one package whose name moves between releases,
# and every icon in this repo inherits from it. Pick whichever name exists
# rather than hardcoding one and failing on the other.
for cand in kf6-breeze-icon-theme breeze-icon-theme; do
    if apt-cache show "$cand" >/dev/null 2>&1; then
        PKGS+=("$cand")
        skip "breeze icons provided by $cand"
        break
    fi
done

[ "$DM_CHOICE" = sddm ] && PKGS+=(sddm)

missing=()
for p in "${PKGS[@]}"; do
    pkg_installed "$p" || missing+=("$p")
done

if [ ${#missing[@]} -eq 0 ]; then
    skip "all Plasma packages already present"
else
    say "  installing: ${missing[*]}"
    run $SUDO apt-get update -qq || warn "apt-get update failed; trying anyway"
    run $SUDO apt-get install -y "${missing[@]}" || die "apt-get install failed"
    if [ "$DRY_RUN" != 1 ]; then
        still=()
        for p in "${missing[@]}"; do
            pkg_installed "$p" || still+=("$p")
        done
        [ ${#still[@]} -gt 0 ] && die "apt exited 0 but these are not installed: ${still[*]}"
    fi
    ok "installed ${missing[*]}"
fi

# ---------- display manager ----------
head1 "display manager"

if [ "$DM_CHOICE" = keep ]; then
    skip "leaving the display manager alone (--dm keep)"
else
    current="$(cat /etc/X11/default-display-manager 2>/dev/null || true)"
    if [ "$current" = /usr/bin/sddm ]; then
        skip "sddm is already the default display manager"
    else
        warn "switching the display manager from ${current:-none} to sddm"
        warn "  if the desktop fails to come back, from a TTY (Ctrl+Alt+F3):"
        warn "  sudo systemctl disable --now sddm && sudo systemctl enable --now gdm3"

        # debconf first: without it, the next package operation that touches a
        # display manager re-asks and can silently put the old one back.
        run $SUDO debconf-set-selections <<<"sddm shared/default-x-display-manager select sddm"
        if [ "$DRY_RUN" = 1 ]; then
            printf '  %s$ write /usr/bin/sddm to /etc/X11/default-display-manager%s\n' "$C_DIM" "$C_OFF"
        else
            printf '/usr/bin/sddm\n' | $SUDO tee /etc/X11/default-display-manager >/dev/null
        fi
        run $SUDO systemctl disable gdm3 >/dev/null 2>&1 || true
        run $SUDO systemctl enable sddm >/dev/null 2>&1 \
            || warn "could not enable sddm.service"
        ok "sddm set as the default display manager (takes effect on reboot)"
    fi
fi

# ---------- default session for the user ----------
head1 "default session"

# Find the session id the same way a display manager does: the basename of the
# .desktop file. Wayland first — recent Ubuntu ships Plasma Wayland-only and
# has no /usr/share/xsessions at all, so assuming an X session would write a
# name nothing can resolve.
SESSION=""
SESSION_KEY=""
for f in /usr/share/wayland-sessions/plasma.desktop \
         /usr/share/wayland-sessions/plasmawayland.desktop; do
    if [ -f "$f" ]; then
        SESSION="$(basename "$f" .desktop)"
        SESSION_KEY="Session"
        break
    fi
done
if [ -z "$SESSION" ]; then
    for f in /usr/share/xsessions/plasma.desktop /usr/share/xsessions/plasmax11.desktop; do
        if [ -f "$f" ]; then
            SESSION="$(basename "$f" .desktop)"
            SESSION_KEY="XSession"
            break
        fi
    done
fi

if [ -z "$SESSION" ]; then
    if [ "$DRY_RUN" = 1 ]; then
        skip "no Plasma session file yet (it arrives with the packages above)"
    else
        fail "no Plasma session file found after install — not setting a default"
    fi
else
    skip "session file: $SESSION ($SESSION_KEY)"
    ACCOUNTS="/var/lib/AccountsService/users/$TARGET_USER"
    if [ -f "$ACCOUNTS" ] && grep -qx "$SESSION_KEY=$SESSION" "$ACCOUNTS"; then
        skip "$TARGET_USER already defaults to $SESSION"
    elif [ "$DRY_RUN" = 1 ]; then
        printf '  %s$ record %s=%s for %s in %s%s\n' \
            "$C_DIM" "$SESSION_KEY" "$SESSION" "$TARGET_USER" "$ACCOUNTS" "$C_OFF"
        ok "would set the default session"
    else
        $SUDO mkdir -p "$(dirname "$ACCOUNTS")"
        # Rewrite rather than append: a second [User] section or a duplicate
        # key makes AccountsService take the first and ignore the rest.
        $SUDO tee "$ACCOUNTS" >/dev/null <<EOF
[User]
$SESSION_KEY=$SESSION
SystemAccount=false
EOF
        ok "$TARGET_USER now defaults to the $SESSION session"
    fi
fi

# ---------- done ----------
printf '\n%s%s changed, %s skipped%s\n' "$C_PINK" "$CHANGED" "$SKIPPED" "$C_OFF"
[ "$FAILED" -gt 0 ] && printf '%s%s failed%s\n' "$C_RED" "$FAILED" "$C_OFF"

cat <<EOF

next:
  1. reboot (or log out) and pick the Plasma session at the login screen
  2. cd $REPO_DIR && ./install.sh --apply-all
EOF

exit $(( FAILED > 0 ? 1 : 0 ))
