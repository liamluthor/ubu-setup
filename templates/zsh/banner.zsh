#!/usr/bin/env zsh
# ==========================================================
# banner.zsh — solid-pixel synthwave login banner, macOS edition.
#
# Sourced from ~/.zshrc by the ubu-setup block, after synth.zshrc.
#
# Same art as bash/banner.sh, but it cannot share that file's implementation.
# The original holds its 5x7 font in a bash 4 associative array, and macOS
# ships bash 3.2 (licensing: bash 4 went GPLv3) and uses zsh as the login
# shell. So the two data structures bash 4 gave us for free are rebuilt out of
# constructs both shells agree on:
#
#   the font        a case statement per glyph instead of declare -A, because
#                   zsh's associative arrays need `typeset -A` and index with
#                   a different syntax.
#   the row colours a case statement instead of an indexed array, because zsh
#                   arrays are 1-based and bash's are 0-based; any literal
#                   index would be off by one in one of the two shells.
#   the row split   walked with ${spec#*:} parameter expansion instead of
#                   `IFS=: read -ra`, which zsh spells `read -A`. Expansion is
#                   also the only option that stays subprocess-free: `cut`
#                   would fork 126 times to paint two words.
#
# Still wants a true-color terminal for the gradient. Terminal.app does NOT
# advertise one (it sets no COLORTERM) but does render \e[38;2;R;G;Bm
# correctly, so the gradient works there regardless — which is why this prints
# unconditionally rather than checking COLORTERM the way the module does.
# ==========================================================

# Interactive shells only. scp and rsync open a non-interactive shell and read
# its stdout as protocol; printing art into that stream corrupts the transfer.
[[ $- == *i* ]] || return 0 2>/dev/null || exit 0
[[ ${TERM:-dumb} != dumb ]] || return 0 2>/dev/null || exit 0

# Once per session. Without this, every `bash` nested inside an existing shell
# repaints the whole banner.
[[ -n ${SYNTHWAVE_BANNER_SHOWN:-} ]] && return 0
export SYNTHWAVE_BANNER_SHOWN=1

# The art is a fixed 104 columns. Narrower than that and every row soft-wraps
# into an unreadable smear, so print nothing rather than something broken.
#
# 104, not the 73 bash/banner.sh checks for: 73 is the width of the ━ rule,
# which is the narrowest thing here, not the widest. The widest is the "JUST
# HACK" glyph rows -- 9 glyphs, 8 of them 5 pixels wide at 2 columns per pixel
# plus a 2-column gap (8 x 12), one space glyph at 3 pixels (8) = 104. Measured,
# not derived: render it and strip the SGR escapes. The bash original therefore
# still wraps in an 80-column window; its Konsole profile asks for 120 columns,
# which is why nobody noticed.
_sw_banner_cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
if [[ $_sw_banner_cols -lt 104 ]]; then
    unset _sw_banner_cols
    return 0 2>/dev/null || exit 0
fi
unset _sw_banner_cols

# 5x7 bitmap font, one string per glyph: rows joined by ':', 1 = lit pixel.
# Only the letters the banner below actually uses are defined. Identical data
# to bash/banner.sh's _sw_font, reached through a case rather than a subscript.
#
# These three helpers ASSIGN to a variable rather than printf-ing a value the
# caller would capture with $(...). Command substitution forks a subshell, and
# the render loop below calls into them 7 rows x 9 glyphs deep — ~130 forks to
# paint two words, which is visible latency on every single login.
_sw_glyph() {
  case $1 in
    A) _sw_spec='01110:10001:10001:11111:10001:10001:10001' ;;
    C) _sw_spec='01111:10000:10000:10000:10000:10000:01111' ;;
    D) _sw_spec='11110:10001:10001:10001:10001:10001:11110' ;;
    H) _sw_spec='10001:10001:10001:11111:10001:10001:10001' ;;
    J) _sw_spec='00111:00010:00010:00010:00010:10010:01100' ;;
    K) _sw_spec='10001:10010:10100:11000:10100:10010:10001' ;;
    N) _sw_spec='10001:11001:11001:10101:10011:10011:10001' ;;
    O) _sw_spec='01110:10001:10001:10001:10001:10001:01110' ;;
    S) _sw_spec='01111:10000:10000:01110:00001:00001:11110' ;;
    T) _sw_spec='11111:00100:00100:00100:00100:00100:00100' ;;
    U) _sw_spec='10001:10001:10001:10001:10001:10001:01110' ;;
    *) _sw_spec='000:000:000:000:000:000:000' ;;
  esac
}

# One color per pixel row: hot pink at the top fading to cyan at the bottom.
# Rows are numbered 0..6 explicitly, so this reads the same under zsh's
# 1-based arrays and bash's 0-based ones.
_sw_row_color() {
  case $1 in
    0) _sw_color='255;45;163' ;;
    1) _sw_color='255;50;191' ;;
    2) _sw_color='239;55;255' ;;
    3) _sw_color='192;70;255' ;;
    4) _sw_color='132;92;255' ;;
    5) _sw_color='72;149;255' ;;
    *) _sw_color='25;225;255' ;;
  esac
}

# Field $2 (0-based) of a colon-joined glyph spec. Drops one leading field per
# step, then takes what is left up to the next colon.
_sw_glyph_row() {
  local spec=$1 n=$2
  while [ "$n" -gt 0 ]; do
    spec=${spec#*:}
    n=$((n - 1))
  done
  _sw_bits=${spec%%:*}
}

# Substring offsets are written ${text:$pos:1}, with the $ spelled out. Bash
# accepts a bare variable name there; zsh does not -- it parses the ":p" of
# ${text:pos:1} as a history modifier and dies with "unrecognized modifier `p'".
# With the $ present both shells read the form as a 0-based substring.
_sw_render() {
  local text=$1 row col pos
  for ((row=0; row<7; row++)); do
    _sw_row_color "$row"
    printf '\033[38;2;%sm' "$_sw_color"
    for ((pos=0; pos<${#text}; pos++)); do
      _sw_glyph "${text:$pos:1}"
      _sw_glyph_row "$_sw_spec" "$row"
      for ((col=0; col<${#_sw_bits}; col++)); do
        if [ "${_sw_bits:$col:1}" = 1 ]; then printf '██'; else printf '  '; fi
      done
      printf '  '
    done
    printf '\033[0m\n'
  done
}

printf '\n\033[38;2;26;225;255m  ◆ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ◆\033[0m\n'
printf '\n'
_sw_render 'DONT ASK'
printf '\n'
_sw_render 'JUST HACK'
printf '\n'
printf '%*s' 29 ''
printf '\033[38;2;255;45;163m▰▰▰▰▰▰\033[38;2;239;55;255m▰▰▰▰▰▰\033[0m'
printf '\033[1;38;2;25;225;255m  HACK THE PLANET  \033[0m'
printf '\033[38;2;132;92;255m▰▰▰▰▰▰\033[38;2;255;45;163m▰▰▰▰▰▰\033[0m\n'
printf '\033[38;2;72;149;255m  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n\n'

unset _sw_spec _sw_color _sw_bits
unset -f _sw_render _sw_glyph _sw_row_color _sw_glyph_row
