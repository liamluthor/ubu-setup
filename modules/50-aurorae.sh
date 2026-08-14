#!/usr/bin/env bash
# 50-aurorae — the Synthwave window decoration.
#
# Aurorae is KWin's SVG-driven decoration engine: a theme is a directory of
# SVGs plus an INI file, with no compilation, which is why this is a template
# rather than a C++ KDecoration plugin.
#
# Files are COPIED rather than symlinked for the same reason as Konsole: this
# is a KPackage directory, and KWin/KPackage may rewrite or cache it.
#
# Installing the theme and *selecting* it are separate steps. Selecting it
# rewrites kwinrc and restyles every window on the desktop, so it only happens
# with --apply-decoration (or AURORAE_APPLY=1).

AURORAE_THEME_NAME="Synthwave"

module_aurorae() {
    head1 "aurorae window decoration"

    require_plasma "the window decoration" || return 0

    local src="$TEMPLATE_DIR/aurorae/$AURORAE_THEME_NAME"
    local dst="${XDG_DATA_HOME:-$HOME/.local/share}/aurorae/themes/$AURORAE_THEME_NAME"

    [ -d "$src" ] || { fail "theme template missing: $src"; return 1; }

    # The engine ships with KWin itself; without it the theme is inert.
    if [ ! -e /usr/share/kwin/aurorae/aurorae.qml ]; then
        warn "KWin's aurorae engine not found — installing files anyway,"
        warn "but the theme will not appear until kwin-* is present"
    fi

    _aurorae_validate "$src" || return 1

    local f rc=0
    while IFS= read -r f; do
        install_file "$src/$f" "$dst/$f" copy || rc=1
    done < <(cd "$src" && find . -maxdepth 1 -type f -printf '%P\n' | sort)
    [ $rc -ne 0 ] && return 1

    if [ "${AURORAE_APPLY:-0}" = 1 ]; then
        _aurorae_apply
    else
        skip "not selecting it (pass --apply-decoration to switch to it)"
    fi
}

# Run the repo's own checker if python3 is around. Catches the failure mode
# that has no visible symptom: a missing element id makes KWin fall back
# silently rather than report anything.
_aurorae_validate() {
    local src="$1" checker="$REPO_DIR/tools/check-aurorae.py"
    [ -f "$checker" ] || return 0
    command -v python3 >/dev/null 2>&1 || { skip "python3 absent; skipping theme validation"; return 0; }

    local out
    if out="$(python3 "$checker" "$src" 2>&1)"; then
        skip "theme validates against the aurorae contract"
        return 0
    fi
    fail "theme failed validation:"
    printf '%s\n' "$out" | sed 's/^/      /' >&2
    return 1
}

_aurorae_apply() {
    # Both groups get written, deliberately.
    #
    # KWin 6.x moved to the KDecoration3 API — the plugins live in
    # qt6/plugins/org.kde.kdecoration3/ and there is no kdecoration2 plugin
    # directory at all — but it still reads the LEGACY [org.kde.kdecoration2]
    # config group. On this box the proof was ~/.config/kdedefaults/kwinrc,
    # the Global Theme defaults file, which sets Breeze under kdecoration2
    # while kdecoration3 was empty; Breeze was nonetheless what rendered.
    #
    # Writing only kdecoration3 is accepted without complaint and does
    # nothing: the title bar stays Breeze and nothing is logged. Writing both
    # costs one extra key and survives whichever group a future release
    # settles on.
    local groups=(org.kde.kdecoration2 org.kde.kdecoration3)

    # Only poke kwin if the config actually moved. Reloading is not a config
    # change, so counting it would mean a settled system never reports
    # "0 changed" — and it would nag a live session on every run.
    local before="$CHANGED" group

    for group in "${groups[@]}"; do
        ini_set "$HOME/.config/kwinrc" "$group" "library" "org.kde.kwin.aurorae" || return 1
        # The __aurorae__svg__ prefix is how KWin distinguishes an SVG theme
        # from a native decoration plugin; the bare directory name will not
        # resolve.
        ini_set "$HOME/.config/kwinrc" "$group" "theme" \
            "__aurorae__svg__$AURORAE_THEME_NAME" || return 1
    done

    if [ "$CHANGED" -eq "$before" ]; then
        skip "decoration already selected; not reloading kwin"
        return 0
    fi
    _aurorae_reload
}

_aurorae_reload() {
    [ "$DRY_RUN" = 1 ] && { skip "would ask kwin to reconfigure"; return 0; }

    local qdbus
    qdbus="$(command -v qdbus6 || command -v qdbus || echo /usr/lib/qt6/bin/qdbus)"
    if [ ! -x "$qdbus" ]; then
        warn "qdbus not found — log out and back in to load the decoration"
        return 0
    fi
    if "$qdbus" org.kde.KWin /KWin reconfigure >/dev/null 2>&1; then
        skip "kwin reloaded"
    else
        warn "could not reach kwin over dbus — log out and back in"
    fi
}
