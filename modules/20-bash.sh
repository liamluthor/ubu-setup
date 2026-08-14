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

    ensure_block "$bashrc" \
        '# Synthwave shell colors. Loaded last so its LS_COLORS wins over dircolors.' \
        '[ -f "$HOME/synth.rc" ] && . "$HOME/synth.rc"'
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
