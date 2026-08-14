#!/usr/bin/env bash
# 10-packages — everything the other modules assume exists.
#
#   vim         the editor the colorscheme targets
#   less        the pager synth.rc themes via LESS_TERMCAP
#   groff-base  man rendering; GROFF_NO_SGR in synth.rc is aimed at it
#   fonts-hack  the font named in Synthwave.profile
#   konsole     the terminal the profile and colorscheme are for
#   git         the prompt's branch indicator shells out to it
#
# Each one is checked with dpkg first, installed only if missing, then verified
# by actually running the binary — apt can exit 0 having left a package
# unconfigured, and a Konsole profile is worthless if Konsole isn't really there.

module_packages() {
    head1 "packages"

    need_pkgs vim less groff-base git fonts-hack konsole || return 1

    head1 "verifying"
    local rc=0
    verify_cmd vim     --version || rc=1
    verify_cmd less    --version || rc=1
    verify_cmd git     --version || rc=1
    verify_cmd konsole --version || rc=1

    # fonts-hack ships no binary; confirm fontconfig can actually resolve it,
    # since Synthwave.profile asks for "Hack" by name and silently falls back
    # to something else if it's missing.
    _verify_font "Hack" || rc=1

    return $rc
}

_verify_font() {
    local want="$1" got
    if ! command -v fc-match >/dev/null 2>&1; then
        skip "fc-match unavailable; cannot verify font '$want'"
        return 0
    fi
    got="$(fc-match -f '%{family}' "$want" 2>/dev/null)"
    if [ "$got" = "$want" ]; then
        skip "font verified: $want"
        return 0
    fi
    warn "font '$want' not found — fontconfig substitutes '${got:-nothing}';"
    warn "Konsole will render the Synthwave profile in that instead"
    return 1
}
