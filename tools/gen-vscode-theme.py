#!/usr/bin/env python3
"""Generate the Synthwave VS Code theme into templates/vscode/.

    python3 tools/gen-vscode-theme.py [outdir]

Nothing here invents colours. All three inputs already exist in the repo, and
deriving from them is what makes the editor actually match the rest:

  templates/color-schemes/Synthwave.colors  -> workbench chrome (side bar,
                                               tabs, status bar), the same
                                               values Qt apps use
  templates/vim/colors/synthwave.vim        -> syntax token colours, so a file
                                               open in vim and the same file in
                                               VS Code highlight identically
  templates/konsole/Synthwave.colorscheme   -> the 16 ANSI slots for the
                                               integrated terminal, so it
                                               matches Konsole exactly

Re-run after changing any of those; do not hand-edit templates/vscode/.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TPL = f'{HERE}/templates'

VERSION = '1.0.0'


# ---------- inputs ----------------------------------------------------------

def kconfig(path):
    """Parse an INI-ish KConfig file into {section: {key: value}}."""
    out, sec = {}, None
    for line in open(path):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('['):
            sec = line.strip('[]')
            out[sec] = {}
        elif sec is not None and '=' in line:
            k, v = line.split('=', 1)
            out[sec][k.strip()] = v.strip()
    return out


def rgb_to_hex(triple):
    r, g, b = (int(x) for x in triple.split(','))
    return '#%02x%02x%02x' % (r, g, b)


def vim_groups(path):
    """{GroupName: {'fg':'#rrggbb', 'bg':..., 'bold':bool, 'italic':bool}}."""
    groups = {}
    for line in open(path):
        m = re.match(r'^\s*hi(?:ghlight)?\s+(\w+)\s+(.*)$', line)
        if not m:
            continue
        name, rest = m.group(1), m.group(2)
        g = {}
        fg = re.search(r'guifg=(#[0-9a-fA-F]{6})', rest)
        bg = re.search(r'guibg=(#[0-9a-fA-F]{6})', rest)
        gui = re.search(r'gui=([a-z,]+)', rest)
        if fg:
            g['fg'] = fg.group(1).lower()
        if bg:
            g['bg'] = bg.group(1).lower()
        if gui:
            g['bold'] = 'bold' in gui.group(1)
            g['italic'] = 'italic' in gui.group(1)
        if g:
            groups[name] = g
    return groups


colors = kconfig(f'{TPL}/color-schemes/Synthwave.colors')
konsole = kconfig(f'{TPL}/konsole/Synthwave.colorscheme')
vim = vim_groups(f'{TPL}/vim/colors/synthwave.vim')

W = colors['Colors:Window']
V = colors['Colors:View']
SEL = colors['Colors:Selection']

BG       = rgb_to_hex(V['BackgroundNormal'])        # #000000, as the terminal
CHROME   = rgb_to_hex(W['BackgroundNormal'])        # #0c0c10
CHROME_2 = rgb_to_hex(W['BackgroundAlternate'])     # #14141a
FG       = rgb_to_hex(W['ForegroundNormal'])        # cyan
ACCENT   = rgb_to_hex(W['ForegroundActive'])        # magenta
DIM      = rgb_to_hex(W['ForegroundInactive'])      # muted purple
LINK     = rgb_to_hex(W['ForegroundLink'])
SELBG    = rgb_to_hex(SEL['BackgroundNormal'])      # #b84dff
NEG      = rgb_to_hex(W['ForegroundNegative'])
NEU      = rgb_to_hex(W['ForegroundNeutral'])
POS      = rgb_to_hex(W['ForegroundPositive'])
EDGE     = '#2a1f3d'


def ansi(slot):
    return rgb_to_hex(konsole[slot]['Color'])


# ---------- workbench -------------------------------------------------------

workbench = {
    'editor.background': BG,
    'editor.foreground': FG,
    'editorLineNumber.foreground': '#4a4a4a',
    'editorLineNumber.activeForeground': ACCENT,
    'editorCursor.foreground': ACCENT,
    'editor.selectionBackground': SELBG + '55',
    'editor.selectionHighlightBackground': SELBG + '33',
    'editor.lineHighlightBackground': '#0c0c1a',
    'editor.findMatchBackground': NEU + '66',
    'editor.findMatchHighlightBackground': NEU + '33',
    'editorWhitespace.foreground': '#2a2a2a',
    'editorIndentGuide.background1': '#1a1a24',
    'editorIndentGuide.activeBackground1': EDGE,
    'editorBracketMatch.background': SELBG + '44',
    'editorBracketMatch.border': ACCENT,

    'editorGutter.addedBackground': POS,
    'editorGutter.modifiedBackground': LINK,
    'editorGutter.deletedBackground': NEG,
    'editorError.foreground': NEG,
    'editorWarning.foreground': NEU,
    'editorInfo.foreground': LINK,

    'activityBar.background': CHROME,
    'activityBar.foreground': FG,
    'activityBar.inactiveForeground': DIM,
    'activityBar.border': EDGE,
    'activityBarBadge.background': ACCENT,
    'activityBarBadge.foreground': '#000000',

    'sideBar.background': CHROME,
    'sideBar.foreground': FG,
    'sideBar.border': EDGE,
    'sideBarTitle.foreground': ACCENT,
    'sideBarSectionHeader.background': CHROME_2,
    'sideBarSectionHeader.foreground': FG,

    'list.activeSelectionBackground': SELBG + '55',
    'list.activeSelectionForeground': '#ffffff',
    'list.inactiveSelectionBackground': CHROME_2,
    'list.hoverBackground': '#1d1526',
    'list.highlightForeground': ACCENT,

    'editorGroupHeader.tabsBackground': CHROME,
    'tab.activeBackground': CHROME_2,
    'tab.activeForeground': ACCENT,
    'tab.inactiveBackground': CHROME,
    'tab.inactiveForeground': DIM,
    'tab.border': EDGE,
    'tab.activeBorderTop': ACCENT,

    'titleBar.activeBackground': CHROME,
    'titleBar.activeForeground': FG,
    'titleBar.inactiveBackground': CHROME,
    'titleBar.inactiveForeground': DIM,
    'titleBar.border': EDGE,

    'statusBar.background': CHROME,
    'statusBar.foreground': FG,
    'statusBar.border': EDGE,
    'statusBar.debuggingBackground': ACCENT,
    'statusBar.debuggingForeground': '#000000',
    'statusBar.noFolderBackground': CHROME,

    'panel.background': BG,
    'panel.border': EDGE,
    'panelTitle.activeForeground': ACCENT,
    'panelTitle.inactiveForeground': DIM,

    'menu.background': CHROME,
    'menu.foreground': FG,
    'menu.selectionBackground': SELBG,
    'menu.selectionForeground': '#ffffff',
    'menubar.selectionBackground': SELBG,

    'dropdown.background': CHROME_2,
    'dropdown.foreground': FG,
    'dropdown.border': EDGE,
    'input.background': BG,
    'input.foreground': FG,
    'input.border': EDGE,
    'inputOption.activeBorder': ACCENT,
    'focusBorder': ACCENT,

    'button.background': SELBG,
    'button.foreground': '#ffffff',
    'button.hoverBackground': ACCENT,

    'badge.background': ACCENT,
    'badge.foreground': '#000000',
    'progressBar.background': ACCENT,
    'scrollbarSlider.background': EDGE + 'aa',
    'scrollbarSlider.hoverBackground': SELBG + 'aa',
    'scrollbarSlider.activeBackground': ACCENT + 'aa',

    'widget.border': EDGE,
    'editorWidget.background': CHROME,
    'editorWidget.border': EDGE,
    'editorSuggestWidget.background': CHROME,
    'editorSuggestWidget.selectedBackground': SELBG + '55',
    'editorHoverWidget.background': CHROME,
    'peekViewEditor.background': '#0a0a12',

    'terminal.background': BG,
    'terminal.foreground': FG,
    'terminalCursor.foreground': ACCENT,
}

# The integrated terminal, straight off the Konsole scheme's 16 slots.
for i in range(8):
    name = ['Black', 'Red', 'Green', 'Yellow', 'Blue', 'Magenta', 'Cyan', 'White'][i]
    workbench[f'terminal.ansi{name}'] = ansi(f'Color{i}')
    workbench[f'terminal.ansiBright{name}'] = ansi(f'Color{i}Intense')


# ---------- tokens ----------------------------------------------------------
# Mapped off the vim colorscheme's own groups, so the two editors agree. A
# group that is absent from the vim file is simply skipped rather than
# guessed at.

VIM_TO_SCOPES = [
    ('Comment',    ['comment', 'punctuation.definition.comment']),
    ('String',     ['string', 'string.quoted', 'string.template']),
    ('Number',     ['constant.numeric', 'constant.language.boolean']),
    ('Constant',   ['constant.language', 'support.constant']),
    ('Identifier', ['variable', 'variable.other', 'meta.definition.variable.name',
                    'support.variable', 'entity.name.variable']),
    ('Function',   ['entity.name.function', 'support.function',
                    'meta.function-call', 'meta.function-call.generic']),
    ('Keyword',    ['keyword', 'keyword.control', 'storage.modifier',
                    'keyword.operator.new', 'keyword.operator.expression']),
    ('Statement',  ['keyword.control.flow', 'keyword.control.conditional']),
    ('PreProc',    ['keyword.control.import', 'keyword.control.from',
                    'meta.preprocessor', 'entity.name.tag']),
    ('Type',       ['entity.name.type', 'entity.name.class', 'support.type',
                    'support.class', 'storage.type']),
    ('Special',    ['constant.character.escape',
                    'punctuation.definition.template-expression']),
    ('Operator',   ['keyword.operator']),
    ('Delimiter',  ['punctuation', 'meta.brace']),
]

# Todo and Error are the two groups vim renders as coloured *backgrounds*
# (black on yellow, white on dark red). VS Code paints token colours as
# foreground on the editor background, so carrying guifg across would put
# black text on a black editor and a near-black red on top of it. Take the
# highlight colour as the foreground instead.
BG_AS_FG = [
    ('Todo',  ['keyword.other.todo', 'comment.keyword'], '#ffd866'),
    ('Error', ['invalid', 'invalid.illegal'],            None),   # None -> palette negative
]

token_colors = []
for group, scopes in VIM_TO_SCOPES:
    g = vim.get(group)
    if not g or 'fg' not in g:
        continue
    settings = {'foreground': g['fg']}
    styles = []
    if g.get('bold'):
        styles.append('bold')
    if g.get('italic'):
        styles.append('italic')
    if styles:
        settings['fontStyle'] = ' '.join(styles)
    token_colors.append({'name': group, 'scope': scopes, 'settings': settings})

for name, scopes, override in BG_AS_FG:
    if name not in vim:
        continue
    fg = override or NEG
    entry = {'name': name, 'scope': scopes, 'settings': {'foreground': fg}}
    if vim[name].get('bold'):
        entry['settings']['fontStyle'] = 'bold'
    token_colors.append(entry)


# ---------- emit ------------------------------------------------------------

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else f'{TPL}/vscode/synthwave-theme'
    os.makedirs(f'{out}/themes', exist_ok=True)

    package = {
        'name': 'synthwave-theme',
        'displayName': 'Synthwave',
        'description': 'Synthwave colours, derived from the same palette as the '
                       'Konsole, vim and Plasma themes in ubu-setup',
        'version': VERSION,
        'publisher': 'ubu-setup',
        'engines': {'vscode': '^1.70.0'},
        'categories': ['Themes'],
        'contributes': {
            'themes': [{
                'label': 'Synthwave',
                'uiTheme': 'vs-dark',
                'path': './themes/synthwave-color-theme.json',
            }],
        },
    }
    with open(f'{out}/package.json', 'w') as f:
        json.dump(package, f, indent=2)
        f.write('\n')

    theme = {
        '$schema': 'vscode://schemas/color-theme',
        'name': 'Synthwave',
        'type': 'dark',
        'colors': workbench,
        'tokenColors': token_colors,
    }
    with open(f'{out}/themes/synthwave-color-theme.json', 'w') as f:
        json.dump(theme, f, indent=2)
        f.write('\n')

    print(f'  package.json')
    print(f'  themes/synthwave-color-theme.json'
          f'  ({len(workbench)} workbench colours, {len(token_colors)} token rules)')


if __name__ == '__main__':
    main()
