# ==========================================================
# synth.zshrc — the macOS/zsh counterpart of bash/synth.rc.
#
# Installed to ~/.synthwave-shell.zshrc by the macos module, which also adds
# the line that loads it to ~/.zshrc:
#     [ -f ~/.synthwave-shell.zshrc ] && . ~/.synthwave-shell.zshrc
#
# Same palette, same LS_COLORS, same GREP_COLORS as the bash version — those
# strings are deliberately byte-identical, so a Mac and an Ubuntu box colour
# the same `ls` output the same way. What differs is everything shell-specific:
#
#   prompt      zsh expands %n/%m/%~ itself, so there is no $(...) per prompt
#               and no \[ \] width markers. The two bash fixes those markers
#               needed (hardcoded username, git segment wrapping the line) do
#               not apply here; zsh's %{ %} does the same job structurally.
#   git branch  vcs_info rather than shelling out to git twice per prompt.
#   ls          BSD ls reads LSCOLORS, a completely different format from
#               LS_COLORS, so both are exported — see the ls section below.
#   truecolor   Terminal.app never sets COLORTERM, so the palette has a
#               256-colour fallback the bash version does not need.
# ==========================================================

# ----------------------------------------------------------
# palette
# Truecolor when the terminal advertises it, 256-color otherwise.
# Terminal.app never advertises truecolor. iTerm2, Ghostty,
# WezTerm, kitty and Alacritty all do.
# ----------------------------------------------------------
if [[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]]; then
    SW_PINK=$'\e[38;2;255;59;255m'
    SW_PINK_HI=$'\e[1;38;2;255;59;255m'
    SW_PINK_LO=$'\e[38;2;255;123;255m'
    SW_CYAN=$'\e[38;2;0;217;217m'
    SW_CYAN_HI=$'\e[1;38;2;107;255;255m'
    SW_CYAN_LO=$'\e[38;2;0;229;229m'
    SW_PURPLE=$'\e[38;2;184;77;255m'
    SW_PURPLE_HI=$'\e[38;2;208;123;255m'
    SW_RED=$'\e[1;38;2;255;59;59m'
    SW_GREEN=$'\e[38;2;59;255;158m'
    SW_DIM=$'\e[38;2;126;99;168m'
    SW_STANDOUT=$'\e[38;2;0;0;0;48;2;0;217;217m'
    SW_UNDER=$'\e[4;38;2;208;123;255m'
else
    SW_PINK=$'\e[38;5;201m'
    SW_PINK_HI=$'\e[1;38;5;201m'
    SW_PINK_LO=$'\e[38;5;213m'
    SW_CYAN=$'\e[38;5;44m'
    SW_CYAN_HI=$'\e[1;38;5;87m'
    SW_CYAN_LO=$'\e[38;5;44m'
    SW_PURPLE=$'\e[38;5;135m'
    SW_PURPLE_HI=$'\e[38;5;177m'
    SW_RED=$'\e[1;38;5;203m'
    SW_GREEN=$'\e[38;5;48m'
    SW_DIM=$'\e[38;5;97m'
    SW_STANDOUT=$'\e[38;5;16;48;5;44m'
    SW_UNDER=$'\e[4;38;5;177m'
fi
SW_OFF=$'\e[0m'

# ----------------------------------------------------------
# man / less colors
# ----------------------------------------------------------
export GROFF_NO_SGR=1

export LESS_TERMCAP_mb="$SW_PINK_HI"
export LESS_TERMCAP_md="$SW_PINK_HI"
export LESS_TERMCAP_me="$SW_OFF"
export LESS_TERMCAP_so="$SW_STANDOUT"
export LESS_TERMCAP_se="$SW_OFF"
export LESS_TERMCAP_us="$SW_UNDER"
export LESS_TERMCAP_ue="$SW_OFF"

export LESS='-R -M -i'
export PAGER=less
export MANPAGER='less -R -M -i'

# macOS ships an old groff. If man output comes through uncolored,
# install a current one and point man at it:
#     brew install groff
#     export MANROFFOPT=""
#     export GROFF_NO_SGR=1

# ----------------------------------------------------------
# prompt
# ----------------------------------------------------------
setopt PROMPT_SUBST

autoload -Uz vcs_info
zstyle ':vcs_info:*'     enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr "%{$SW_PINK_LO%}*"
zstyle ':vcs_info:git:*' stagedstr   "%{$SW_GREEN%}+"
zstyle ':vcs_info:git:*' formats \
    " %{$SW_DIM%}(%{$SW_CYAN%}%b%u%c%{$SW_DIM%})%{$SW_OFF%}"
zstyle ':vcs_info:git:*' actionformats \
    " %{$SW_DIM%}(%{$SW_CYAN%}%b%{$SW_PINK_LO%}|%a%u%c%{$SW_DIM%})%{$SW_OFF%}"

precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )

# pink user, purple separators, cyan host, cyan path
# sigil turns red on a nonzero exit status
PROMPT='%{$SW_PINK_HI%}%n%{$SW_PURPLE%}@%{$SW_CYAN_HI%}%m%{$SW_PURPLE%}:%{$SW_CYAN_LO%}%~${vcs_info_msg_0_}%(?.%{$SW_PINK_HI%}.%{$SW_RED%}) %#%{$SW_OFF%} '

# two line variant, swap the PROMPT above for this
# PROMPT=$'\n%{$SW_PINK%}%n%{$SW_PURPLE%}@%{$SW_CYAN_HI%}%m%{$SW_PURPLE%} in %{$SW_CYAN_LO%}%~${vcs_info_msg_0_}\n%(?.%{$SW_PINK_HI%}.%{$SW_RED%})%#%{$SW_OFF%} '

# right prompt: clock, remove if you do not want it
RPROMPT='%{$SW_DIM%}%D{%H:%M:%S}%{$SW_OFF%}'

PS2="%{$SW_PURPLE%}... %{$SW_OFF%}"
PS3="%{$SW_CYAN%}?> %{$SW_OFF%}"
PS4="%{$SW_DIM%}+ %{$SW_OFF%}"

# ----------------------------------------------------------
# ls colors
# ----------------------------------------------------------
# BSD ls (the macOS default) reads CLICOLOR + LSCOLORS.
# 11 fg/bg pairs, in order:
#   dir, symlink, socket, pipe, executable, block, char,
#   setuid exe, setgid exe, sticky other-writable dir,
#   other-writable dir
# lowercase = normal, uppercase = bold, x = terminal default
export CLICOLOR=1
export LSCOLORS="GxFxfxdxFxDxDxAbAdGxGx"

# GNU ls (brew install coreutils, binary is gls) reads LS_COLORS
export LS_COLORS='rs=0:di=1;36:ln=1;35:mh=00:pi=33:so=1;35:do=1;35:bd=33;40:cd=33;40:or=1;31:mi=1;31:su=37;41:sg=30;43:ca=30;41:tw=30;46:ow=1;36:st=37;44:ex=1;35:*.tar=35:*.tgz=35:*.zip=35:*.gz=35:*.bz2=35:*.xz=35:*.zst=35:*.7z=35:*.rpm=35:*.deb=35:*.jpg=1;33:*.png=1;33:*.gif=1;33:*.svg=1;33:*.mp4=1;33:*.mkv=1;33:*.pdf=1;33:*.md=1;36:*.txt=36:*.log=90:*.json=1;33:*.yaml=1;33:*.yml=1;33:*.sh=1;35:*.py=1;35:*.tf=1;35:*.tsx=1;35:*.ts=1;35'
export TREE_COLORS="$LS_COLORS"

if command -v gls >/dev/null 2>&1; then
    alias ls='gls --color=auto'
    alias ll='gls -lAh --color=auto'
else
    alias ls='ls -G'
    alias ll='ls -lAhG'
fi
alias grep='grep --color=auto'

export GREP_COLORS='ms=1;35:mc=1;35:sl=:cx=:fn=1;36:ln=35:bn=35:se=90'

# ----------------------------------------------------------
# zsh completion menu colors, matched to ls
# ----------------------------------------------------------
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions' format "%{$SW_CYAN%}%d%{$SW_OFF%}"
zstyle ':completion:*:warnings'     format "%{$SW_RED%}no matches%{$SW_OFF%}"
zstyle ':completion:*' menu select
