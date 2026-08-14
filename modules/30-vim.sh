#!/usr/bin/env bash
# 30-vim — ~/.vimrc and ~/.vim/colors/synthwave.vim
#
# Both are symlinked, so tweaking either one in a live edit session writes
# straight back into the repo and shows up in `git diff`.

module_vim() {
    head1 "vim"

    install_file "$TEMPLATE_DIR/vim/vimrc"               "$HOME/.vimrc"                    symlink || return 1
    install_file "$TEMPLATE_DIR/vim/colors/synthwave.vim" "$HOME/.vim/colors/synthwave.vim" symlink || return 1

    # Neovim reads its own tree. Mirror the colorscheme there if nvim is
    # installed, so `:colorscheme synthwave` works in both.
    if command -v nvim >/dev/null 2>&1; then
        install_file "$TEMPLATE_DIR/vim/colors/synthwave.vim" \
            "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/colors/synthwave.vim" symlink || return 1
    fi

    _verify_vim
}

# Load the real vimrc in a throwaway Vim and surface any error it raises.
# Cheap, and it catches a template that references an option this build lacks.
_verify_vim() {
    [ "$DRY_RUN" = 1 ] && return 0
    command -v vim >/dev/null 2>&1 || { warn "vim not installed; skipping verify"; return 0; }

    local out
    out="$(vim -es -u "$HOME/.vimrc" -c 'quit' 2>&1)" || true
    if [ -n "$out" ]; then
        warn "vim reported while loading ~/.vimrc:"
        printf '%s\n' "$out" | sed 's/^/      /' >&2
    else
        skip "~/.vimrc loads clean"
    fi
}
