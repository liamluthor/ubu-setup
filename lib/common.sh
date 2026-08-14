#!/usr/bin/env bash
# ==========================================================
# lib/common.sh — shared helpers for ubu-setup
# Sourced by install.sh and every module. Not executable on its own.
#
# Contract every helper here honours:
#   * idempotent  — running twice changes nothing the second time
#   * dry-runnable — DRY_RUN=1 makes it print, never write
#   * backed up   — anything it would destroy is copied aside first
# ==========================================================

set -o pipefail

# ---------- paths ----------
REPO_DIR="${REPO_DIR:?REPO_DIR must be set by install.sh}"
TEMPLATE_DIR="$REPO_DIR/templates"
STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ubu-setup"
BACKUP_ROOT="$STATE_DIR/backups"

# ---------- flags (install.sh overrides these) ----------
DRY_RUN="${DRY_RUN:-0}"
FORCE="${FORCE:-0}"
LINK_MODE="${LINK_MODE:-symlink}"   # symlink | copy

# ---------- counters, reported in the summary ----------
CHANGED=0
SKIPPED=0
FAILED=0

# ---------- output ----------
# Colors only when stdout is a tty, so logs and pipes stay clean.
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
    C_PINK=$'\e[1;38;2;255;59;255m'
    C_CYAN=$'\e[38;2;0;217;217m'
    C_DIM=$'\e[38;2;126;99;168m'
    C_RED=$'\e[1;38;2;255;59;59m'
    C_GREEN=$'\e[38;2;59;255;158m'
    C_YELL=$'\e[38;2;255;216;102m'
    C_OFF=$'\e[0m'
else
    C_PINK= C_CYAN= C_DIM= C_RED= C_GREEN= C_YELL= C_OFF=
fi

_prefix() { [ "$DRY_RUN" = 1 ] && printf '%s[dry-run]%s ' "$C_DIM" "$C_OFF"; }

say()  { printf '%s%s%s\n' "$C_CYAN" "$*" "$C_OFF"; }
head1(){ printf '\n%s==> %s%s\n' "$C_PINK" "$*" "$C_OFF"; }
ok()   { _prefix; printf '  %s+%s %s\n' "$C_GREEN" "$C_OFF" "$*"; CHANGED=$((CHANGED+1)); }
skip() { _prefix; printf '  %s=%s %s\n' "$C_DIM"   "$C_OFF" "$*"; SKIPPED=$((SKIPPED+1)); }
warn() { _prefix; printf '  %s!%s %s\n' "$C_YELL"  "$C_OFF" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }
fail() { printf '  %sx%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; FAILED=$((FAILED+1)); }

# run CMD... — execute unless dry-running.
run() {
    if [ "$DRY_RUN" = 1 ]; then
        printf '  %s$ %s%s\n' "$C_DIM" "$*" "$C_OFF"
        return 0
    fi
    "$@"
}

# ---------- backup ----------
# One timestamped directory per install run, created lazily so a no-op run
# leaves no litter behind.
BACKUP_DIR=""
BACKUP_PREFIX="${BACKUP_PREFIX:-}"      # uninstall uses "pre-uninstall-"
# uninstall.sh sets this to 0: its own safety copies must NOT become "latest",
# or restoring from "latest" would just restore the state it saved seconds ago.
UPDATE_LATEST="${UPDATE_LATEST:-1}"

# Sets $BACKUP_DIR in the CURRENT shell. Deliberately not a value-returning
# function: `dir="$(_backup_dir)"` would run it in a subshell, the assignment
# would be discarded, and every call would mint a fresh timestamped directory —
# scattering one run's backups across several dirs and breaking both
# first-copy-wins and the "latest" pointer.
_ensure_backup_dir() {
    [ -n "$BACKUP_DIR" ] && return 0
    BACKUP_DIR="$BACKUP_ROOT/${BACKUP_PREFIX}$(date +%Y%m%d-%H%M%S)"
    if [ "$DRY_RUN" != 1 ]; then
        mkdir -p "$BACKUP_DIR" || die "cannot create $BACKUP_DIR"
        if [ "$UPDATE_LATEST" = 1 ]; then
            ln -sfn "$BACKUP_DIR" "$BACKUP_ROOT/latest"
        fi
    fi
    return 0
}

# backup PATH — copy PATH into this run's backup dir, preserving its layout
# relative to $HOME so restores are unambiguous. No-op if PATH doesn't exist.
#
# FIRST COPY WINS. A single run can touch one file more than once (~/.bashrc
# gets both a legacy-line strip and a block append). Only the first copy is the
# pristine pre-run state; re-copying would overwrite it with a half-modified
# version and quietly make the backup useless for a restore.
backup() {
    local src="$1" rel dest
    [ -e "$src" ] || [ -L "$src" ] || return 0
    _ensure_backup_dir
    rel="${src#"$HOME"/}"
    dest="$BACKUP_DIR/$rel"
    if [ "$DRY_RUN" = 1 ]; then
        printf '  %s$ backup %s -> %s%s\n' "$C_DIM" "$src" "$dest" "$C_OFF"
        return 0
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        return 0
    fi
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest" || die "backup of $src failed"
}

# ---------- file identity ----------
# same_content A B — true when both exist and are byte-identical.
same_content() { [ -f "$1" ] && [ -f "$2" ] && cmp -s "$1" "$2"; }

# is_our_link PATH TARGET — true when PATH is already a symlink to TARGET.
is_our_link() { [ -L "$1" ] && [ "$(readlink -f "$1")" = "$(readlink -f "$2")" ]; }

# ---------- the core install primitive ----------
# install_file SRC DEST [mode]
#   mode: "" (use $LINK_MODE) | symlink | copy
#
# symlink: edits to DEST land back in the repo, which is what you want for
#          files only you edit (vimrc, synth.rc).
# copy:    required for anything an app rewrites itself. KConfig (Konsole)
#          saves via write-temp-then-rename, which REPLACES a symlink rather
#          than writing through it, silently detaching the file from the repo.
install_file() {
    local src="$1" dest="$2" mode="${3:-$LINK_MODE}" rel
    rel="${dest/#$HOME/\~}"

    [ -f "$src" ] || { fail "missing template: $src"; return 1; }

    case "$mode" in
      symlink)
        if is_our_link "$dest" "$src"; then
            skip "$rel already linked"
            return 0
        fi
        # A regular file here is the user's own — never silently discard it.
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            if same_content "$src" "$dest"; then
                : # identical content, safe to replace with the link
            elif [ "$FORCE" != 1 ]; then
                backup "$dest"
                warn "$rel existed and differs — backed up, replacing (--force to silence)"
            else
                backup "$dest"
            fi
        else
            backup "$dest"
        fi
        run mkdir -p "$(dirname "$dest")" || { fail "mkdir for $rel"; return 1; }
        run ln -sfn "$src" "$dest"       || { fail "link $rel"; return 1; }
        ok "$rel -> repo"
        ;;

      copy)
        if same_content "$src" "$dest"; then
            skip "$rel already current"
            return 0
        fi
        backup "$dest"
        run mkdir -p "$(dirname "$dest")" || { fail "mkdir for $rel"; return 1; }
        run cp -f "$src" "$dest"          || { fail "copy $rel"; return 1; }
        ok "$rel updated"
        ;;

      *) die "install_file: unknown mode '$mode'" ;;
    esac
}

# ---------- managed block in a file we don't own ----------
BLOCK_BEGIN='# >>> ubu-setup >>>'
BLOCK_END='# <<< ubu-setup <<<'

# ensure_block FILE PAYLOAD...
# Appends a marker-delimited block, or rewrites it in place if the payload
# changed. Everything outside the markers is left untouched.
ensure_block() {
    local file="$1"; shift
    local payload rel tmp
    payload="$(printf '%s\n' "$@")"
    rel="${file/#$HOME/\~}"

    local desired
    desired="$(printf '%s\n%s\n%s\n' "$BLOCK_BEGIN" "$payload" "$BLOCK_END")"

    if [ -f "$file" ] && grep -qF "$BLOCK_BEGIN" "$file"; then
        local current
        current="$(awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" \
            'index($0,b){f=1} f{print} index($0,e){f=0}' "$file")"
        if [ "$current" = "$desired" ]; then
            skip "$rel block already current"
            return 0
        fi
        backup "$file"
        if [ "$DRY_RUN" = 1 ]; then
            printf '  %s$ rewrite ubu-setup block in %s%s\n' "$C_DIM" "$rel" "$C_OFF"
        else
            tmp="$(mktemp)"
            awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" -v repl="$desired" '
                index($0,b){print repl; skipping=1; next}
                index($0,e){skipping=0; next}
                !skipping{print}
            ' "$file" > "$tmp" && mv "$tmp" "$file" || { rm -f "$tmp"; fail "rewrite $rel"; return 1; }
        fi
        ok "$rel block updated"
    else
        backup "$file"
        if [ "$DRY_RUN" = 1 ]; then
            printf '  %s$ append ubu-setup block to %s%s\n' "$C_DIM" "$rel" "$C_OFF"
        else
            mkdir -p "$(dirname "$file")"
            printf '\n%s\n' "$desired" >> "$file" || { fail "append to $rel"; return 1; }
        fi
        ok "$rel block added"
    fi
}

# ---------- INI / KConfig key ----------
# ini_set FILE GROUP KEY VALUE
# Idempotent single-key edit. Prefers kwriteconfig (KDE's own writer, which
# understands cascading config); falls back to awk for non-KDE boxes.
ini_get() {
    local file="$1" group="$2" key="$3"
    [ -f "$file" ] || return 1
    awk -v g="[$group]" -v k="$key" '
        $0==g {inb=1; next}
        /^\[/ {inb=0}
        inb && index($0, k "=")==1 {sub("^" k "=",""); print; exit}
    ' "$file"
}

ini_set() {
    local file="$1" group="$2" key="$3" value="$4" cur rel writer tmp
    rel="${file/#$HOME/\~}"

    cur="$(ini_get "$file" "$group" "$key" 2>/dev/null || true)"
    if [ "$cur" = "$value" ]; then
        skip "$rel [$group] $key already $value"
        return 0
    fi

    backup "$file"

    writer="$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)"
    if [ -n "$writer" ] && [ "${file#"${XDG_CONFIG_HOME:-$HOME/.config}"/}" != "$file" ]; then
        run "$writer" --file "$(basename "$file")" --group "$group" --key "$key" "$value" \
            || { fail "$writer on $rel"; return 1; }
    elif [ "$DRY_RUN" = 1 ]; then
        printf '  %s$ set [%s] %s=%s in %s%s\n' "$C_DIM" "$group" "$key" "$value" "$rel" "$C_OFF"
    else
        mkdir -p "$(dirname "$file")"
        [ -f "$file" ] || : > "$file"
        tmp="$(mktemp)"
        awk -v g="[$group]" -v k="$key" -v v="$value" '
            $0==g { inb=1; seen=1; print; next }
            /^\[/ { if (inb && !done) { print k "=" v; done=1 } inb=0 }
            inb && index($0, k "=")==1 { print k "=" v; done=1; next }
            { print }
            END {
                if (!seen) { print ""; print g; print k "=" v }
                else if (!done) { print k "=" v }
            }
        ' "$file" > "$tmp" && mv "$tmp" "$file" || { rm -f "$tmp"; fail "edit $rel"; return 1; }
    fi
    ok "$rel [$group] $key=$value"
}

# ---------- desktop environment ----------
# Half the modules here only mean anything under KDE Plasma: a KWin
# decoration, a Plasma colour scheme, an icon theme selected through
# kdeglobals, a plasmoid. On GNOME or a bare server every one of those would
# write files that are never read — which looks like a successful install and
# changes nothing.
#
# Two different questions, deliberately kept apart:
#   is_plasma        — is the CURRENT SESSION Plasma? (can we apply anything?)
#   plasma_installed — is Plasma on the box at all? (is installing worthwhile?)
# Running over SSH from a TTY is the case that needs both: Plasma is installed,
# the session is not Plasma, and the files are still worth writing.

is_plasma() {
    case "${XDG_CURRENT_DESKTOP:-}" in
        *KDE*|*plasma*|*Plasma*) return 0 ;;
    esac
    [ -n "${KDE_FULL_SESSION:-}" ] && return 0
    [ "${XDG_SESSION_DESKTOP:-}" = "KDE" ] && return 0
    return 1
}

plasma_installed() {
    command -v plasmashell >/dev/null 2>&1
}

# require_plasma DESCRIPTION — returns 1 when the module should skip entirely.
require_plasma() {
    local what="$1"

    if is_plasma; then
        return 0
    fi

    if plasma_installed; then
        warn "not in a Plasma session (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset})"
        warn "  installing $what anyway; log into Plasma for it to take effect"
        return 0
    fi

    skip "$what needs KDE Plasma, which is not installed here"
    return 1
}

# ---------- packages ----------
# pkg_installed PKG — true when dpkg considers it fully installed.
pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null \
        | grep -q '^install ok installed$'
}

# verify_cmd COMMAND [VERSION_FLAG] — confirm a binary is on PATH and runs.
# Reports the version it printed so the log shows what actually landed.
# stdout only: Qt tools (konsole among them) scribble warnings to stderr even
# on a clean --version, and that noise is not a failure.
verify_cmd() {
    local cmd="$1" flag="${2:---version}" out path

    path="$(command -v "$cmd" 2>/dev/null)"
    if [ -z "$path" ]; then
        fail "$cmd not on PATH after install"
        return 1
    fi

    out="$("$cmd" "$flag" 2>/dev/null | head -n1)"
    if [ -n "$out" ]; then
        skip "$cmd verified: $out"
        return 0
    fi

    # No version output. Present and executable is good enough. Note that
    # `command -v` yields a bare name for a shell builtin or function, not a
    # path — testing that with -x would look at a file in $PWD and wrongly fail.
    case "$path" in
        /*)
            if [ -x "$path" ]; then
                skip "$cmd present ($path)"
                return 0
            fi
            fail "$cmd exists at $path but is not executable"
            return 1
            ;;
        *)
            skip "$cmd present (shell builtin)"
            return 0
            ;;
    esac
}

# need_pkgs PKG... — apt-install only the ones dpkg says are missing.
need_pkgs() {
    local missing=() p
    for p in "$@"; do
        pkg_installed "$p" || missing+=("$p")
    done

    if [ ${#missing[@]} -eq 0 ]; then
        skip "packages present: $*"
        return 0
    fi

    if [ "${NO_PACKAGES:-0}" = 1 ]; then
        warn "missing packages not installed (--no-packages): ${missing[*]}"
        return 1
    fi

    if ! command -v apt-get >/dev/null 2>&1; then
        fail "no apt-get; install manually: ${missing[*]}"
        return 1
    fi

    local sudo=""
    [ "$(id -u)" -ne 0 ] && sudo="sudo"

    say "  installing: ${missing[*]}"
    run $sudo apt-get update -qq || warn "apt-get update failed, trying install anyway"
    run $sudo apt-get install -y "${missing[@]}" || { fail "apt-get install ${missing[*]}"; return 1; }

    # apt can exit 0 having not actually configured a package (held, or a
    # dependency conflict it "resolved" by leaving it out). Confirm with dpkg
    # rather than trusting the exit status.
    [ "$DRY_RUN" = 1 ] && { ok "would install ${missing[*]}"; return 0; }

    local still=()
    for p in "${missing[@]}"; do
        pkg_installed "$p" || still+=("$p")
    done
    if [ ${#still[@]} -gt 0 ]; then
        fail "apt-get exited 0 but these are still not installed: ${still[*]}"
        return 1
    fi
    ok "installed ${missing[*]}"
}
