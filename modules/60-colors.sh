#!/usr/bin/env bash
# 60-colors — the Plasma application color scheme.
#
# This is what paints Qt widget chrome: menu bars, tool bars, tab bars,
# scrollbars, dialogs. It is a different layer from both the Konsole
# colorscheme (terminal grid only) and the Aurorae theme (title bar only).
#
# Scope is deliberately narrow by default. Applying a color scheme GLOBALLY
# repaints every Qt/KDE app on the system, so the default here only points
# Konsole at it, via konsolerc's per-application ColorScheme key. Pass
# --colors-global to set it for everything.

COLORS_SCHEME_NAME="Synthwave"

module_colors() {
    head1 "plasma color scheme"

    require_plasma "the Plasma colour scheme" || return 0

    local src="$TEMPLATE_DIR/color-schemes/$COLORS_SCHEME_NAME.colors"
    local dst="${XDG_DATA_HOME:-$HOME/.local/share}/color-schemes/$COLORS_SCHEME_NAME.colors"

    # Copied, not symlinked: System Settings' color editor rewrites this file
    # in place via KConfig's atomic save, which replaces a symlink.
    # Validate the template, not the destination: under --dry-run the
    # destination does not exist yet, and reading it would silently validate
    # nothing at all.
    _colors_validate "$src" || return 1

    install_file "$src" "$dst" copy || return 1

    local before="$CHANGED"

    if [ "${COLORS_GLOBAL:-0}" = 1 ]; then
        _colors_apply_global "$src" || return 1
    else
        skip "not setting it globally (pass --colors-global for every app)"
    fi

    # Konsole reads its own per-app override; without this it stays on
    # whatever kdeglobals says regardless of the file above existing.
    ini_set "$HOME/.config/konsolerc" "UiSettings" "ColorScheme" "$COLORS_SCHEME_NAME" || return 1

    if [ "$CHANGED" -eq "$before" ]; then
        skip "color scheme already selected"
        return 0
    fi

    warn "already-running apps keep the old scheme — restart Konsole to see it"
}

# Apply the scheme to every Qt/KDE app.
#
# Writing kdeglobals' [General] ColorScheme key does NOT repaint anything. That
# key is only a label recording which scheme is selected; Qt reads the actual
# colors out of the [Colors:*] groups in kdeglobals, and the key does not
# populate them. The tell on a stock box: ~/.config/kdedefaults/kdeglobals names
# a scheme and carries no color groups at all, while ~/.config/kdeglobals
# carries all ten. The per-app path is different — there the app loads the named
# scheme file itself, which is why konsolerc's single key is enough.
#
# plasma-apply-colorscheme merges the groups in AND notifies running apps over
# D-Bus, so the repaint is live. If it is missing, say so rather than writing a
# key that looks right and does nothing.
#
# (It leaves [General] ColorSchemeHash stale — that is System Settings' marker
# for "this scheme was hand-edited", cosmetic only.)
_colors_apply_global() {
    local src="$1" applier

    if _colors_applied_globally "$src"; then
        skip "scheme already applied to every Qt app"
        return 0
    fi

    applier="$(command -v plasma-apply-colorscheme || true)"
    if [ -z "$applier" ]; then
        fail "plasma-apply-colorscheme not found (ships with plasma-workspace)"
        return 1
    fi

    backup "$HOME/.config/kdeglobals"
    run "$applier" "$COLORS_SCHEME_NAME" \
        || { fail "plasma-apply-colorscheme $COLORS_SCHEME_NAME (needs a running Plasma session)"; return 1; }
    ok "~/.config/kdeglobals color scheme = $COLORS_SCHEME_NAME (every Qt app)"
}

# True only when the name key AND the colors themselves are in place. Checking
# the name alone would call the half-applied state — named but never merged,
# which is exactly what the old key-only write produced — already done, and
# skip the repair forever.
_colors_applied_globally() {
    local src="$1" want cur
    [ "$(ini_get "$HOME/.config/kdeglobals" "General" "ColorScheme")" = "$COLORS_SCHEME_NAME" ] || return 1
    want="$(ini_get "$src" "Colors:Window" "BackgroundNormal")"
    cur="$(ini_get "$HOME/.config/kdeglobals" "Colors:Window" "BackgroundNormal")"
    [ -n "$want" ] && [ "$want" = "$cur" ]
}

# KConfig will not tell you a color is malformed; it substitutes a default and
# carries on, so a hex value or a 2-component color reads as "my edit did
# nothing". Check the format before that can happen.
_colors_validate() {
    local f="$1" bad=0 line key val n
    if [ ! -r "$f" ]; then
        fail "cannot read color scheme: $f"
        return 1
    fi
    while IFS= read -r line; do
        case "$line" in
            \#*|\[*|"") continue ;;
        esac
        key="${line%%=*}"; val="${line#*=}"
        case "$key" in
            Background*|Foreground*|Decoration*|active*|inactive*|Color)
                n=$(printf '%s' "$val" | tr ',' '\n' | grep -c '^[0-9]\+$')
                if [ "$n" -ne 3 ]; then
                    fail "$(basename "$f"): $key=$val is not R,G,B decimal"
                    bad=1
                fi
                ;;
        esac
    done < "$f"
    [ "$bad" -eq 0 ] && skip "color values are well-formed R,G,B"
    return $bad
}
