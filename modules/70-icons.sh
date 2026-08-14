#!/usr/bin/env bash
# 70-icons — the Synthwave icon theme, and the one desktop entry that needs
# patching to reach it.
#
# The theme overrides five names and inherits breeze-dark for everything else,
# so a missing icon is a fall-through rather than a blank. Regenerate the
# artwork with tools/gen-icons.py; do not hand-edit templates/icons/.
#
# Installing the theme and SELECTING it are separate steps, as with the window
# decoration: selecting repaints every icon on the desktop, so it waits for
# --apply-icons.
#
# Firefox is the awkward one. Its snap desktop entry hardcodes
#   Icon=/snap/firefox/current/default256.png
# an absolute path to a raster PNG, which bypasses icon themes entirely — no
# theme can ever override it. So a copy of that entry, identical but for the
# Icon line, is installed into ~/.local/share/applications where it shadows
# the snap's. Dolphin and VS Code need no such thing: they declare ordinary
# icon names that a theme outranks. Dolphin is shipped under two of them
# though — org.kde.dolphin on some builds, the generic system-file-manager on
# others — so the theme provides both.

ICONS_THEME_NAME="Synthwave"

module_icons() {
    head1 "icon theme"

    require_plasma "the icon theme" || return 0

    local src="$TEMPLATE_DIR/icons/$ICONS_THEME_NAME"
    local dst="${XDG_DATA_HOME:-$HOME/.local/share}/icons/$ICONS_THEME_NAME"

    [ -d "$src" ] || { fail "icon theme template missing: $src"; return 1; }

    _icons_validate "$src" || return 1

    # Recursive, unlike the aurorae module's flat copy: this tree is
    # apps/<size>/ and apps/scalable/ deep.
    local f rc=0
    while IFS= read -r f; do
        install_file "$src/$f" "$dst/$f" copy || rc=1
    done < <(cd "$src" && find . -type f -printf '%P\n' | sort)
    [ $rc -ne 0 ] && return 1

    # The firefox override and the theme selection have to move together.
    # firefox-synthwave is a name ONLY this theme provides, so installing the
    # desktop entry without selecting the theme points Firefox at an icon
    # nothing can resolve — it loses the icon it had and falls back to a
    # generic one. Worse than doing nothing, and it looked like the installer
    # had simply failed.
    if [ "${ICONS_APPLY:-0}" = 1 ]; then
        _icons_firefox_entry || return 1
        _icons_apply
    else
        skip "not selecting it (pass --apply-icons to switch to it)"
        skip "not touching firefox's desktop entry either; it needs the theme"
    fi
}

# The theme's index.theme has to agree with what is on disk: KIconTheme only
# searches directories the index declares, so an artwork file in an
# undeclared directory is invisible, and a declared directory that does not
# exist is a silent dead end. Neither is reported anywhere.
_icons_validate() {
    local src="$1" line dirs d bad=0

    if [ ! -f "$src/index.theme" ]; then
        fail "$(basename "$src")/index.theme missing"
        return 1
    fi

    line="$(ini_get "$src/index.theme" "Icon Theme" "Directories")"
    if [ -z "$line" ]; then
        fail "index.theme declares no Directories"
        return 1
    fi

    IFS=',' read -ra dirs <<< "$line"
    for d in "${dirs[@]}"; do
        if [ ! -d "$src/$d" ]; then
            fail "index.theme declares $d, which does not exist"
            bad=1
        elif [ -z "$(find "$src/$d" -type f -print -quit)" ]; then
            fail "index.theme declares $d, which is empty"
            bad=1
        fi
    done

    # And the reverse: artwork sitting in a directory nobody declared.
    while IFS= read -r d; do
        printf '%s\n' "${dirs[@]}" | grep -qx "$d" || {
            fail "$d holds artwork but is not in Directories"
            bad=1
        }
    done < <(cd "$src" && find . -type f -name '*.svg' -printf '%h\n' | sed 's|^\./||' | sort -u)

    [ "$bad" -eq 0 ] && skip "index.theme agrees with the artwork on disk"
    return $bad
}

# Shadow the snap's entry with one that points at a themed icon name.
_icons_firefox_entry() {
    local src="$TEMPLATE_DIR/applications/firefox_firefox.desktop"
    local dst="${XDG_DATA_HOME:-$HOME/.local/share}/applications/firefox_firefox.desktop"
    local snap=/var/lib/snapd/desktop/applications/firefox_firefox.desktop

    [ -f "$src" ] || return 0          # nothing to do on a box without it

    if [ ! -f "$snap" ]; then
        skip "firefox snap entry absent; not installing the override"
        return 0
    fi

    # The copy is a full 740-line duplicate of Mozilla's entry — desktop files
    # replace rather than merge, so every localized name and jump-list action
    # has to come along. That means it can go stale. Say so rather than
    # silently shipping an old menu.
    local ours theirs
    ours="$(grep -cv '^Icon=' "$src")"
    theirs="$(grep -cv '^Icon=' "$snap")"
    if [ "$ours" != "$theirs" ]; then
        warn "the firefox snap's entry has changed since this template was made"
        warn "  (template $ours lines vs snap $theirs, ignoring Icon=)"
        warn "  refresh it: sed 's|^Icon=.*|Icon=firefox-synthwave|' $snap > $src"
    fi

    install_file "$src" "$dst" copy
}

_icons_apply() {
    local before="$CHANGED"

    ini_set "$HOME/.config/kdeglobals" "Icons" "Theme" "$ICONS_THEME_NAME" || return 1

    if [ "$CHANGED" -eq "$before" ]; then
        skip "icon theme already selected"
        return 0
    fi

    # Rebuild KDE's service cache or the panel keeps handing out the old
    # icons for pinned launchers.
    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        run kbuildsycoca6 >/dev/null 2>&1 || warn "kbuildsycoca6 failed"
    fi

    # Unlike the colour scheme, there is no CLI on a stock Ubuntu/Plasma box
    # that pushes a live icon-theme change: plasma-changeicons and
    # plasma-apply-icontheme both ship elsewhere or not at all. Running apps
    # therefore keep their old icons until restarted. Better to say so than to
    # let it read as "the theme did not work".
    if command -v plasma-changeicons >/dev/null 2>&1; then
        run plasma-changeicons "$ICONS_THEME_NAME" >/dev/null 2>&1 \
            || warn "plasma-changeicons failed"
    else
        warn "no plasma-changeicons here — running apps keep their old icons"
        warn "  restart plasmashell (or log out) to repaint the panel"
    fi
}
