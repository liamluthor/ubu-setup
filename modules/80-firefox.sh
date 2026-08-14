#!/usr/bin/env bash
# 80-firefox — synthwave chrome for Firefox (tabs, toolbars, menus).
#
# Two files land in the profile: chrome/userChrome.css, and a user.js that
# turns on the pref which makes Firefox read it at all.
#
# Why userChrome.css and not a theme: a static theme (.xpi) is the supported
# route, but release Firefox will only install extensions signed by Mozilla.
# An unsigned local theme can only be side-loaded temporarily via
# about:debugging and is gone on restart, so it is no use for a setup script.
#
# Why user.js and not prefs.js: Firefox rewrites prefs.js on exit, discarding
# anything written there while it runs. user.js is re-read at every startup.
#
# The profile directory name is random per install (uqw8a64x.default here), so
# it is discovered from profiles.ini rather than hardcoded. Snap and non-snap
# Firefox keep that file in different places; both are checked.

FIREFOX_PROFILE_ROOTS=(
    "$HOME/snap/firefox/common/.mozilla/firefox"
    "$HOME/.mozilla/firefox"
)

module_firefox() {
    head1 "firefox chrome"

    local src="$TEMPLATE_DIR/firefox"
    [ -d "$src" ] || { fail "firefox template missing: $src"; return 1; }

    _firefox_profile || return 0                   # not an error: no firefox yet
    local profile="$FIREFOX_PROFILE"

    skip "profile: ${profile/#$HOME/\~}"

    install_file "$src/userChrome.css" "$profile/chrome/userChrome.css" copy || return 1
    _firefox_user_js "$src/user.js" "$profile/user.js" || return 1

    if pgrep -x firefox >/dev/null 2>&1; then
        warn "firefox is running — restart it (a full quit, not just the window)"
    fi
}

# Resolve the default profile directory into $FIREFOX_PROFILE.
#
# Sets a global rather than printing, deliberately. Called as
# profile="$(_firefox_profile)" it would run in a subshell, which swallows
# every skip/fail message into the variable and loses the counter increments
# with the subshell — so a box with no Firefox printed nothing at all and
# claimed "0 skipped". Same trap lib/common.sh documents for _ensure_backup_dir.
FIREFOX_PROFILE=""
_firefox_profile() {
    local root ini path rel
    FIREFOX_PROFILE=""
    for root in "${FIREFOX_PROFILE_ROOTS[@]}"; do
        ini="$root/profiles.ini"
        [ -f "$ini" ] || continue

        # The [Profile*] section carrying Default=1. Not the [Install*]
        # section's Default= key, which holds a path rather than a flag and
        # would match first if we just grepped for "Default".
        path="$(awk -F= '
            /^\[/                     { inprofile = ($0 ~ /^\[Profile/); p = ""; d = 0 }
            inprofile && $1 == "Path"    { p = $2 }
            inprofile && $1 == "Default" { d = ($2 == 1) }
            inprofile && p != "" && d    { print p; exit }
        ' "$ini")"

        # Single-profile installs sometimes omit Default= entirely.
        if [ -z "$path" ]; then
            path="$(awk -F= '/^\[Profile/ { p = 1 } p && $1 == "Path" { print $2; exit }' "$ini")"
        fi

        if [ -n "$path" ]; then
            case "$path" in
                /*) rel="$path" ;;
                *)  rel="$root/$path" ;;
            esac
            if [ -d "$rel" ]; then
                FIREFOX_PROFILE="$rel"
                return 0
            fi
            fail "profiles.ini points at $rel, which does not exist"
            return 1
        fi
    done

    skip "no firefox profile found — run firefox once, then re-run this module"
    return 1
}

# user.js is JavaScript, so the repo's '#'-delimited managed block cannot be
# used here. It is installed as a whole file instead, which means an existing
# one gets replaced — worth saying out loud, since anyone who hand-tuned prefs
# there would otherwise lose them silently. install_file backs it up first.
_firefox_user_js() {
    local src="$1" dst="$2"

    if [ -f "$dst" ] && ! grep -q 'ubu-setup' "$dst" && ! same_content "$src" "$dst"; then
        warn "$(basename "$dst") exists and is not ours — replacing it (backed up)"
        warn "  merge anything you want to keep back in afterwards"
    fi

    install_file "$src" "$dst" copy
}
