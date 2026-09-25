#!/usr/bin/env bash
# 87-ghidra — the Synthwave Ghidra theme.
#
# The palette is the same one the Konsole, Plasma, vim and VS Code templates
# use, and token colours follow the vim mapping (keywords pink, types purple,
# functions green, numbers soft pink, comments dim), so a function reads the
# same in the decompiler as it does in the editor.
#
# COPIED, not symlinked. Ghidra rewrites a theme file whenever it saves one —
# on import, and every time Edit > Theme > Configure is saved — and the
# rewrite sorts the keys and drops every comment. So the installed copy is
# compared by its parsed key/value pairs, not byte for byte: a copy Ghidra has
# merely reformatted is still current, and only a real colour change counts as
# drift.
#
# Ghidra keeps settings per version, in ~/.config/ghidra/ghidra_<ver>_<rel>/,
# and creates that directory on first launch. The theme goes into every one
# that exists. On a box where Ghidra has never been started there is nowhere
# to put it yet, so this skips and says so rather than guessing a version.
#
# Installing and SELECTING are separate steps, as with vscode: selecting writes
# the Theme key in Ghidra's own preferences file.

GHIDRA_THEME_NAME="synthwave"

module_ghidra() {
    head1 "ghidra theme"

    local src="$TEMPLATE_DIR/ghidra/$GHIDRA_THEME_NAME.theme"
    [ -f "$src" ] || { fail "ghidra theme template missing: $src"; return 1; }

    local root="${XDG_CONFIG_HOME:-$HOME/.config}/ghidra" dirs=() d
    for d in "$root"/ghidra_*/; do
        [ -d "$d" ] && dirs+=("${d%/}")
    done

    if [ ${#dirs[@]} -eq 0 ]; then
        if command -v ghidra >/dev/null 2>&1 || command -v ghidraRun >/dev/null 2>&1; then
            skip "ghidra has never been started; launch it once, then re-run --only ghidra"
        else
            skip "ghidra not installed; skipping"
        fi
        return 0
    fi

    for d in "${dirs[@]}"; do
        _ghidra_install "$src" "$d/themes/$GHIDRA_THEME_NAME.theme" || return 1
        if [ "${GHIDRA_APPLY:-0}" = 1 ]; then
            _ghidra_select "$d" || return 1
        fi
    done

    if [ "${GHIDRA_APPLY:-0}" != 1 ]; then
        skip "not selecting it (pass --apply-ghidra, or Edit > Theme > Switch... in Ghidra)"
    fi

    if _ghidra_running; then
        warn "ghidra is running — quit and restart it; it rewrites its preferences on exit"
    fi
}

# Print a theme file as sorted "key=value" lines with comments and spacing
# stripped — the form Ghidra's own rewrite cannot change.
_ghidra_normalize() {
    awk '
        { sub(/[ \t]*\/\/.*$/, "") }
        /^[ \t]*$/ { next }
        {
            i = index($0, "=")
            if (i == 0) { print; next }
            k = substr($0, 1, i - 1); v = substr($0, i + 1)
            gsub(/^[ \t]+|[ \t]+$/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", v)
            print k "=" v
        }
    ' "$1" | LC_ALL=C sort
}

# True when both files exist and define the same keys with the same values.
_ghidra_same_theme() {
    [ -f "$1" ] && [ -f "$2" ] || return 1
    [ "$(_ghidra_normalize "$1")" = "$(_ghidra_normalize "$2")" ]
}

_ghidra_install() {
    local src="$1" dest="$2" rel
    rel="${dest/#$HOME/\~}"

    if _ghidra_same_theme "$src" "$dest"; then
        skip "$rel already current"
        return 0
    fi

    # A differing copy is most likely one you tuned in Edit > Theme >
    # Configure. It is backed up before being replaced, same as every other
    # copied file here.
    if [ -f "$dest" ] && [ "$FORCE" != 1 ]; then
        warn "$rel differs from the template — backed up, replacing (--force to silence)"
    fi
    backup "$dest"
    run mkdir -p "$(dirname "$dest")" || { fail "mkdir for $rel"; return 1; }
    run cp -f "$src" "$dest"          || { fail "copy $rel"; return 1; }
    ok "$rel updated"
}

# Point Ghidra's Theme preference at the installed file.
#
# The preferences file is a Java properties file, which escapes ':' in values
# — hence "File\:". It is not KConfig, so ini_set does not apply: there are no
# [groups], and kwriteconfig would mangle it.
_ghidra_select() {
    local dir="$1" prefs rel want cur tmp
    prefs="$dir/preferences"
    rel="${prefs/#$HOME/\~}"
    want="File\\:$dir/themes/$GHIDRA_THEME_NAME.theme"

    cur="$(sed -n 's/^Theme=//p' "$prefs" 2>/dev/null | head -1)"
    if [ "$cur" = "$want" ]; then
        skip "$rel already selects $GHIDRA_THEME_NAME"
        return 0
    fi

    backup "$prefs"
    if [ "$DRY_RUN" = 1 ]; then
        printf '  %s$ set Theme=%s in %s%s\n' "$C_DIM" "$want" "$rel" "$C_OFF"
    else
        [ -f "$prefs" ] || : > "$prefs"
        tmp="$(mktemp)"
        # awk -v would expand the backslash in "File\:", so the value goes in
        # through the environment instead.
        GHIDRA_WANT="$want" awk '
            BEGIN { want = ENVIRON["GHIDRA_WANT"] }
            /^Theme=/ { if (!done) print "Theme=" want; done = 1; next }
            { print }
            END { if (!done) print "Theme=" want }
        ' "$prefs" 2>/dev/null > "$tmp" && mv "$tmp" "$prefs" \
            || { rm -f "$tmp"; fail "edit $rel"; return 1; }
    fi
    ok "$rel Theme=$GHIDRA_THEME_NAME"
}

# Ghidra runs as a JVM whose command line carries its launcher class.
_ghidra_running() {
    pgrep -f 'ghidra\.GhidraRun' >/dev/null 2>&1
}
