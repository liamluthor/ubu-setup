#!/usr/bin/env bash
# 25-banner — the login banner (banner.sh).
#
# The ~/.bashrc line that loads this lives in the bash module's managed block,
# not here: ensure_block owns exactly one marker-delimited block per file, so a
# second module writing to ~/.bashrc would rewrite the first one's block.
#
# That line is guarded on the file existing, so `--skip banner` leaves an inert
# line behind rather than a broken shell, and installing the banner later needs
# no ~/.bashrc change at all.

BANNER_RC="$HOME/banner.sh"

module_banner() {
    head1 "login banner"

    install_file "$TEMPLATE_DIR/bash/banner.sh" "$BANNER_RC" symlink || return 1

    # The art needs a true-color terminal and bash 4+ for its associative-array
    # font. Neither is fatal -- the banner just degrades or prints nothing -- so
    # this reports rather than fails.
    case "${COLORTERM:-}" in
        truecolor|24bit) ;;
        *) warn "COLORTERM is not truecolor; the gradient will be approximated" ;;
    esac
    if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
        warn "bash ${BASH_VERSION:-?} is older than 4; the banner will not render"
    fi
}
