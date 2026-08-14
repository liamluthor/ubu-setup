#!/usr/bin/env bash
# 40-konsole — Synthwave colorscheme + profile, and making it the default.
#
# These are COPIED, not symlinked, on purpose. Konsole writes its config
# through KConfig, which saves atomically (write temp file, rename over the
# target). A rename REPLACES a symlink instead of writing through it, so a
# symlinked profile would silently detach from the repo the first time you
# touched Konsole's settings dialog. Copying keeps the repo authoritative and
# makes drift visible via `install.sh --dry-run`.

module_konsole() {
    head1 "konsole"

    # Self-sufficient so `--only konsole` works without the packages module.
    # Both calls are dpkg checks when konsole is already there, so running
    # both costs nothing.
    if ! pkg_installed konsole; then
        need_pkgs konsole || { fail "cannot configure konsole: install failed"; return 1; }
    fi
    verify_cmd konsole --version || return 1

    local kdir="${XDG_DATA_HOME:-$HOME/.local/share}/konsole"
    install_file "$TEMPLATE_DIR/konsole/Synthwave.colorscheme" "$kdir/Synthwave.colorscheme" copy || return 1
    install_file "$TEMPLATE_DIR/konsole/Synthwave.profile"     "$kdir/Synthwave.profile"     copy || return 1

    local krc="${XDG_CONFIG_HOME:-$HOME/.config}/konsolerc"
    ini_set "$krc" "Desktop Entry" "DefaultProfile" "Synthwave.profile" || return 1

    # konsolerc's [UiSettings] ColorScheme — the widget chrome around the
    # terminal grid — belongs to the colors module, which points it at
    # Synthwave. This module used to set it to BreezeDark; both wrote the same
    # key, so a full run only landed right because 40 runs before 60, and
    # `--only konsole` put the gray back.

    if pgrep -x konsole >/dev/null 2>&1; then
        warn "konsole is running — restart it (or open a new window) to pick this up"
    fi
}
