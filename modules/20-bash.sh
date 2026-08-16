#!/usr/bin/env bash
# 20-bash — synth.rc (prompt, LS_COLORS, GREP_COLORS, man/less colors)
#           plus the hook in ~/.bashrc that loads it.
#
# The hook has to be the LAST thing ~/.bashrc does. Stock Ubuntu ~/.bashrc
# runs `eval "$(dircolors -b)"` partway through, which would otherwise stomp
# the LS_COLORS synth.rc exports.

SYNTH_RC="$HOME/synth.rc"

module_bash() {
    head1 "bash colors"

    install_file "$TEMPLATE_DIR/bash/synth.rc" "$SYNTH_RC" symlink || return 1

    local bashrc="$HOME/.bashrc"
    if [ ! -f "$bashrc" ]; then
        warn "~/.bashrc does not exist; creating one that only loads synth.rc"
    fi

    _strip_legacy_source "$bashrc"
    _strip_legacy_banner "$bashrc"

    # The banner line lives here rather than in the banner module because
    # ensure_block owns one block per file; two modules writing to ~/.bashrc
    # would clobber each other. It is guarded on the file existing, so
    # `--skip banner` leaves it inert instead of breaking the shell.
    ensure_block "$bashrc" \
        '# Synthwave shell colors. Loaded last so its LS_COLORS wins over dircolors.' \
        '[ -f "$HOME/synth.rc" ] && . "$HOME/synth.rc"' \
        '# Login banner. Sourced after synth.rc; no-op when the banner is not installed.' \
        '[ -f "$HOME/banner.sh" ] && . "$HOME/banner.sh"'
}

# A hand-added `source ~/synth.rc` from before this repo existed would double
# up with our block: harmless but confusing, and it re-runs PROMPT_COMMAND
# setup. Drop any such line that lives outside our markers.
_strip_legacy_source() {
    local file="$1" tmp
    [ -f "$file" ] || return 0

    local n
    n="$(awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
        index($0,b){inb=1} index($0,e){inb=0; next}
        !inb && /^[[:space:]]*(source|\.)[[:space:]]+.*synth\.rc[[:space:]]*$/ {c++}
        END{print c+0}
    ' "$file")"

    [ "$n" -eq 0 ] && return 0

    backup "$file"
    if [ "$DRY_RUN" = 1 ]; then
        printf '  %s$ remove %s legacy synth.rc source line(s) from ~/.bashrc%s\n' \
            "$C_DIM" "$n" "$C_OFF"
        return 0
    fi

    tmp="$(mktemp)"
    awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
        index($0,b){inb=1} index($0,e){inb=0; print; next}
        !inb && /^[[:space:]]*(source|\.)[[:space:]]+.*synth\.rc[[:space:]]*$/ {next}
        {print}
    ' "$file" > "$tmp" && mv "$tmp" "$file" || { rm -f "$tmp"; fail "strip legacy source"; return 1; }
    ok "removed $n legacy synth.rc source line(s) from ~/.bashrc"
}

# The banner started life as a hand-added pair of lines pointing at whatever
# directory it happened to be checked out in. Now that the repo ships it, drop
# any such line living outside our markers, along with the comment above it —
# otherwise the banner is sourced twice and the second copy prints nothing
# (SYNTHWAVE_BANNER_SHOWN), which looks like the new one is broken.
_strip_legacy_banner() {
    local file="$1" tmp n
    [ -f "$file" ] || return 0

    n="$(awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
        index($0,b){inb=1} index($0,e){inb=0; next}
        !inb && /(^|[[:space:]])(source|\.)[[:space:]]+.*banner\.sh/ {c++}
        END{print c+0}
    ' "$file")"

    [ "$n" -eq 0 ] && return 0

    backup "$file"
    if [ "$DRY_RUN" = 1 ]; then
        printf '  %s$ remove %s legacy banner line(s) from ~/.bashrc%s\n' \
            "$C_DIM" "$n" "$C_OFF"
        return 0
    fi

    # `held` is a one-line lookbehind: a comment mentioning the banner is only
    # dropped once the following line turns out to be the source line itself.
    tmp="$(mktemp)"
    awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
        function flush() { if (held != "") { print held; held = "" } }
        index($0,b){ flush(); inb=1; print; next }
        index($0,e){ inb=0; print; next }
        inb { print; next }
        /^[[:space:]]*#.*[Bb]anner/ { flush(); held=$0; next }
        /(^|[[:space:]])(source|\.)[[:space:]]+.*banner\.sh/ { held=""; next }
        { flush(); print }
        END { flush() }
    ' "$file" > "$tmp" && mv "$tmp" "$file" || { rm -f "$tmp"; fail "strip legacy banner"; return 1; }
    ok "removed $n legacy banner line(s) from ~/.bashrc"
}
