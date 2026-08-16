#!/usr/bin/env bash
# ==========================================================
# banner.sh — solid-pixel synthwave login banner.
#
# Sourced from ~/.bashrc by the ubu-setup block, after synth.rc. Bash 4+ for
# the associative-array font, and a true-color terminal for the gradient.
# ==========================================================

# Interactive shells only. scp and rsync open a non-interactive shell and read
# its stdout as protocol; printing art into that stream corrupts the transfer.
[[ $- == *i* ]] || return 0 2>/dev/null || exit 0
[[ ${TERM:-dumb} != dumb ]] || return 0 2>/dev/null || exit 0

# Once per session. Without this, every `bash` nested inside an existing shell
# repaints the whole banner.
[[ -n ${SYNTHWAVE_BANNER_SHOWN:-} ]] && return 0
export SYNTHWAVE_BANNER_SHOWN=1

# The art is a fixed 73 columns. Narrower than that and every row soft-wraps
# into an unreadable smear, so print nothing rather than something broken.
_sw_banner_cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
if [[ $_sw_banner_cols -lt 76 ]]; then
    unset _sw_banner_cols
    return 0 2>/dev/null || exit 0
fi
unset _sw_banner_cols

# 5x7 bitmap font, one string per glyph: rows joined by ':', 1 = lit pixel.
# Only the letters the banner below actually uses are defined.
declare -A _sw_font=(
  [A]='01110:10001:10001:11111:10001:10001:10001'
  [C]='01111:10000:10000:10000:10000:10000:01111'
  [D]='11110:10001:10001:10001:10001:10001:11110'
  [H]='10001:10001:10001:11111:10001:10001:10001'
  [J]='00111:00010:00010:00010:00010:10010:01100'
  [K]='10001:10010:10100:11000:10100:10010:10001'
  [N]='10001:11001:11001:10101:10011:10011:10001'
  [O]='01110:10001:10001:10001:10001:10001:01110'
  [S]='01111:10000:10000:01110:00001:00001:11110'
  [T]='11111:00100:00100:00100:00100:00100:00100'
  [U]='10001:10001:10001:10001:10001:10001:01110'
  [' ']='000:000:000:000:000:000:000'
)

# One color per pixel row: hot pink at the top fading to cyan at the bottom.
_sw_colors=('255;45;163' '255;50;191' '239;55;255' '192;70;255' '132;92;255' '72;149;255' '25;225;255')

_sw_render() {
  local text=$1 row char glyph bits col pos
  for ((row=0; row<7; row++)); do
    printf '\033[38;2;%sm' "${_sw_colors[row]}"
    for ((pos=0; pos<${#text}; pos++)); do
      char=${text:pos:1}
      if [[ $char == ' ' ]]; then
        glyph='000:000:000:000:000:000:000'
      else
        glyph=${_sw_font[$char]}
      fi
      IFS=: read -ra _sw_rows <<< "$glyph"
      bits=${_sw_rows[row]}
      for ((col=0; col<${#bits}; col++)); do
        [[ ${bits:col:1} == 1 ]] && printf '██' || printf '  '
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

unset _sw_font _sw_colors _sw_rows
unset -f _sw_render
