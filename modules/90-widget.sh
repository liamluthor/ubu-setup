#!/usr/bin/env bash
# 90-widget — the Synthwave system monitor plasmoid.
#
# A KPackage applet directory (metadata.json + contents/ui/*.qml), so it needs
# no compilation, same as the Aurorae theme. Metrics come from ksystemstats
# through the KSysGuard sensor API rather than by polling /proc, so there is no
# process spawn per tick.
#
# Installing the package and PLACING it on the desktop are separate steps, as
# everywhere else here: adding a widget mutates the desktop containment, so it
# waits for --add-widget.
#
# Two things about plasmoids that are not obvious:
#   * plasmashell does not hot-reload QML. Editing a file under a running shell
#     changes nothing until it restarts, which is why this module says so
#     rather than leaving you to conclude the edit failed.
#   * a widget's STORED size wins over a smaller preferred size. Making the
#     layout narrower does not shrink an already-placed widget; that needs the
#     containment config rewritten while plasmashell is stopped, or a drag.

WIDGET_ID="org.kde.synthwave.sysmon"

module_widget() {
    head1 "system monitor widget"

    require_plasma "the system monitor widget" || return 0

    local src="$TEMPLATE_DIR/plasmoids/$WIDGET_ID"
    local dst="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/$WIDGET_ID"

    [ -d "$src" ] || { fail "plasmoid template missing: $src"; return 1; }

    _widget_validate "$src" || return 1

    # The sensor daemon is what feeds it. plasmashell starts it on demand, so
    # a missing binary is not fatal, but it is worth flagging: without it every
    # value renders as zero and the widget looks broken rather than empty.
    if ! command -v ksystemstats >/dev/null 2>&1; then
        warn "ksystemstats not found — the widget will install but read all zeroes"
    fi

    local f rc=0 before="$CHANGED"
    while IFS= read -r f; do
        install_file "$src/$f" "$dst/$f" copy || rc=1
    done < <(cd "$src" && find . -type f -printf '%P\n' | sort)
    [ $rc -ne 0 ] && return 1

    if [ "$CHANGED" -ne "$before" ] && pgrep -x plasmashell >/dev/null 2>&1; then
        warn "plasmashell does not reload QML — restart it to pick this up:"
        warn "  kquitapp6 plasmashell && kstart plasmashell"
    fi

    if [ "${WIDGET_ADD:-0}" = 1 ]; then
        _widget_add
    else
        skip "not placing it on the desktop (pass --add-widget)"
    fi
}

# metadata.json has to agree with the directory it lives in: KPackage resolves
# an applet by its Id, and a mismatch between Id and directory name installs
# fine and then never loads. Same class of silent failure as the Aurorae
# KPackageStructure key.
_widget_validate() {
    local src="$1"
    command -v python3 >/dev/null 2>&1 || { skip "python3 absent; skipping widget validation"; return 0; }

    local out
    if ! out="$(python3 - "$src" "$WIDGET_ID" <<'PY' 2>&1
import json, os, sys
src, want_id = sys.argv[1], sys.argv[2]
errs = []
try:
    meta = json.load(open(os.path.join(src, 'metadata.json')))
except Exception as e:
    print(f"metadata.json does not parse: {e}")
    sys.exit(1)
if meta.get('KPackageStructure') != 'Plasma/Applet':
    errs.append('KPackageStructure must be "Plasma/Applet"')
got = meta.get('KPlugin', {}).get('Id')
if got != want_id:
    errs.append(f'KPlugin.Id is "{got}", expected "{want_id}"')
if os.path.basename(src.rstrip('/')) != want_id:
    errs.append(f'directory name must match the Id ({want_id})')
if not os.path.exists(os.path.join(src, 'contents', 'ui', 'main.qml')):
    errs.append('contents/ui/main.qml is missing')
for e in errs:
    print(e)
sys.exit(1 if errs else 0)
PY
    )"; then
        fail "plasmoid failed validation:"
        printf '%s\n' "$out" | sed 's/^/      /' >&2
        return 1
    fi
    skip "plasmoid metadata is consistent"
    return 0
}

# Place it on the desktop, once. Adding twice would give you two widgets, so
# this checks every containment first and is a no-op when one is already there.
_widget_add() {
    local qdbus
    qdbus="$(command -v qdbus6 || command -v qdbus || echo /usr/lib/qt6/bin/qdbus)"

    if [ ! -x "$qdbus" ] || ! pgrep -x plasmashell >/dev/null 2>&1; then
        warn "plasmashell not running (or no qdbus) — add the widget by hand:"
        warn "  right-click the desktop, Add Widgets, search Synthwave"
        return 0
    fi

    if [ "$DRY_RUN" = 1 ]; then
        skip "would add the widget to the desktop if absent"
        return 0
    fi

    local script out
    script='
var found = false;
var ds = desktops();
for (var i = 0; i < ds.length; ++i) {
    var ws = ds[i].widgets();
    for (var j = 0; j < ws.length; ++j) {
        if (ws[j].type == "'"$WIDGET_ID"'") { found = true; }
    }
}
if (found) { print("PRESENT"); }
else { ds[0].addWidget("'"$WIDGET_ID"'"); print("ADDED"); }
'
    out="$("$qdbus" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" 2>&1)"

    case "$out" in
        *PRESENT*) skip "widget already on the desktop" ;;
        *ADDED*)
            ok "widget added to the desktop"
            # It lands centred: the scripting API exposes geometry, but Qt.rect
            # is not defined in that sandbox and assigning a plain object is
            # ignored, so position cannot be set from here.
            warn "it lands in the middle — press Meta+D for Edit Mode and drag it"
            ;;
        *) fail "could not add the widget: $out"; return 1 ;;
    esac
}
