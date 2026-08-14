" ==========================================================
" synthwave.vim
" Install to ~/.vim/colors/synthwave.vim
"   (or ~/.config/nvim/colors/synthwave.vim)
" Then in your vimrc:
"   set termguicolors
"   colorscheme synthwave
" ==========================================================

set background=dark
hi clear
if exists("syntax_on")
  syntax reset
endif
let g:colors_name = "synthwave"

" ----- palette ---------------------------------------------
"   bg          #000000
"   fg / cyan   #00E5E5   body text
"   cyan-dim    #0FA8B0   delimiters
"   cyan-lo     #6BFFFF   accents
"   purple      #B84DFF   strings
"   purple+     #D07BFF   identifiers, types
"   purple-dim  #7E63A8   comments
"   magenta     #FF3BFF   keywords
"   magenta+    #FF7BFF   numbers, operators
"   green       #3BFF9E   function names, props
"   yellow      #FFD866   preproc, special
"   red         #FF3B3B
" -----------------------------------------------------------

" --- editor chrome
hi Normal        guifg=#00E5E5 guibg=#000000 ctermfg=44  ctermbg=NONE
hi NonText       guifg=#3A3A3A guibg=NONE    ctermfg=237 ctermbg=NONE
hi EndOfBuffer   guifg=#1A1A1A guibg=NONE    ctermfg=234 ctermbg=NONE
hi LineNr        guifg=#4A4A4A guibg=NONE    ctermfg=239 ctermbg=NONE
hi CursorLineNr  guifg=#FF3BFF guibg=#101010 ctermfg=201 ctermbg=234 gui=bold cterm=bold
hi CursorLine    guibg=#101010 ctermbg=234   gui=NONE    cterm=NONE
hi CursorColumn  guibg=#101010 ctermbg=234
hi ColorColumn   guibg=#141414 ctermbg=234
hi SignColumn    guibg=NONE    ctermbg=NONE
hi VertSplit     guifg=#00D9D9 guibg=NONE    ctermfg=44  ctermbg=NONE gui=NONE cterm=NONE
hi Folded        guifg=#00D9D9 guibg=#101010 ctermfg=44  ctermbg=234
hi FoldColumn    guifg=#4A4A4A guibg=NONE    ctermfg=239 ctermbg=NONE
hi Conceal       guifg=#4A4A4A guibg=NONE    ctermfg=239 ctermbg=NONE

" --- status line: black on cyan, mirrors the less status bar
hi StatusLine    guifg=#000000 guibg=#00D9D9 ctermfg=16  ctermbg=44  gui=bold cterm=bold
hi StatusLineNC  guifg=#00E5E5 guibg=#2A2A2A ctermfg=44  ctermbg=236 gui=NONE cterm=NONE
hi WildMenu      guifg=#000000 guibg=#FF3BFF ctermfg=16  ctermbg=201 gui=bold cterm=bold
hi TabLine       guifg=#7E63A8 guibg=#101010 ctermfg=97  ctermbg=234 gui=NONE cterm=NONE
hi TabLineSel    guifg=#000000 guibg=#00D9D9 ctermfg=16  ctermbg=44  gui=bold cterm=bold
hi TabLineFill   guifg=#101010 guibg=#101010 ctermfg=234 ctermbg=234
hi Title         guifg=#00D9D9 guibg=NONE    ctermfg=44  gui=bold cterm=bold
hi Directory     guifg=#00D9D9 guibg=NONE    ctermfg=44  gui=bold cterm=bold
hi ModeMsg       guifg=#FF3BFF guibg=NONE    ctermfg=201 gui=bold cterm=bold
hi MoreMsg       guifg=#00D9D9 guibg=NONE    ctermfg=44
hi Question      guifg=#00D9D9 guibg=NONE    ctermfg=44

" --- cursor and selection
hi Cursor        guifg=#000000 guibg=#FF3BFF ctermfg=16 ctermbg=201
hi lCursor       guifg=#000000 guibg=#00D9D9 ctermfg=16 ctermbg=44
hi Visual        guifg=NONE    guibg=#3D1060 ctermbg=54
hi VisualNOS     guifg=NONE    guibg=#2E0C48 ctermbg=54
hi MatchParen    guifg=#000000 guibg=#FF3BFF ctermfg=16 ctermbg=201 gui=bold cterm=bold

" --- search
hi Search        guifg=#000000 guibg=#FFD866 ctermfg=16 ctermbg=221
hi IncSearch     guifg=#000000 guibg=#FF3BFF ctermfg=16 ctermbg=201

" --- popup menu
hi Pmenu         guifg=#00E5E5 guibg=#1A1A1A ctermfg=44 ctermbg=234
hi PmenuSel      guifg=#000000 guibg=#00D9D9 ctermfg=16 ctermbg=44 gui=bold cterm=bold
hi PmenuSbar     guibg=#2A2A2A ctermbg=236
hi PmenuThumb    guibg=#B84DFF ctermbg=135

" --- syntax
hi Comment       guifg=#7E63A8 guibg=NONE ctermfg=97  gui=italic cterm=NONE

hi Constant      guifg=#B84DFF guibg=NONE ctermfg=135
hi String        guifg=#B84DFF guibg=NONE ctermfg=135
hi Character     guifg=#B84DFF guibg=NONE ctermfg=135
hi Number        guifg=#FF7BFF guibg=NONE ctermfg=213
hi Boolean       guifg=#FF7BFF guibg=NONE ctermfg=213 gui=bold cterm=bold
hi Float         guifg=#FF7BFF guibg=NONE ctermfg=213

hi Identifier    guifg=#D07BFF guibg=NONE ctermfg=177 gui=NONE cterm=NONE
hi Function      guifg=#3BFF9E guibg=NONE ctermfg=48  gui=bold cterm=bold

hi Statement     guifg=#FF3BFF guibg=NONE ctermfg=201 gui=bold cterm=bold
hi Conditional   guifg=#FF3BFF guibg=NONE ctermfg=201 gui=bold cterm=bold
hi Repeat        guifg=#FF3BFF guibg=NONE ctermfg=201 gui=bold cterm=bold
hi Label         guifg=#FF3BFF guibg=NONE ctermfg=201
hi Operator      guifg=#FF7BFF guibg=NONE ctermfg=213
hi Keyword       guifg=#FF3BFF guibg=NONE ctermfg=201 gui=bold cterm=bold
hi Exception     guifg=#FF3B3B guibg=NONE ctermfg=203 gui=bold cterm=bold

hi PreProc       guifg=#FFD866 guibg=NONE ctermfg=221
hi Include       guifg=#FFD866 guibg=NONE ctermfg=221
hi Define        guifg=#FFD866 guibg=NONE ctermfg=221
hi Macro         guifg=#FFD866 guibg=NONE ctermfg=221
hi PreCondit     guifg=#FFD866 guibg=NONE ctermfg=221

hi Type          guifg=#D07BFF guibg=NONE ctermfg=177 gui=bold cterm=bold
hi StorageClass  guifg=#D07BFF guibg=NONE ctermfg=177
hi Structure     guifg=#D07BFF guibg=NONE ctermfg=177
hi Typedef       guifg=#D07BFF guibg=NONE ctermfg=177

hi Special       guifg=#FFD866 guibg=NONE ctermfg=221
hi SpecialChar   guifg=#FF7BFF guibg=NONE ctermfg=213
hi Tag           guifg=#FF3BFF guibg=NONE ctermfg=201
hi Delimiter     guifg=#0FA8B0 guibg=NONE ctermfg=37
hi SpecialComment guifg=#D07BFF guibg=NONE ctermfg=177
hi Debug         guifg=#FF3B3B guibg=NONE ctermfg=203

hi Underlined    guifg=#00D9D9 guibg=NONE ctermfg=44 gui=underline cterm=underline
hi Ignore        guifg=#4A4A4A guibg=NONE ctermfg=239
hi Error         guifg=#FFFFFF guibg=#A00000 ctermfg=231 ctermbg=88
hi Todo          guifg=#000000 guibg=#FFD866 ctermfg=16  ctermbg=221 gui=bold cterm=bold

" --- typescript / tsx
" Vim's bundled typescript syntax leaves imported names, object labels and
" member expressions unmatched, so they fall through to Normal. These links
" pull them into the palette.
hi typescriptVariable      guifg=#FF3BFF guibg=NONE ctermfg=201 gui=bold cterm=bold
hi typescriptIdentifier    guifg=#D07BFF guibg=NONE ctermfg=177
hi typescriptProp          guifg=#3BFF9E guibg=NONE ctermfg=48
hi typescriptObjectLabel   guifg=#3BFF9E guibg=NONE ctermfg=48
hi typescriptCall          guifg=#00E5E5 guibg=NONE ctermfg=44
hi typescriptMember        guifg=#D07BFF guibg=NONE ctermfg=177
hi typescriptTypeReference guifg=#D07BFF guibg=NONE ctermfg=177 gui=bold cterm=bold
hi typescriptBraces        guifg=#0FA8B0 guibg=NONE ctermfg=37
hi typescriptParens        guifg=#0FA8B0 guibg=NONE ctermfg=37
hi typescriptFuncName      guifg=#3BFF9E guibg=NONE ctermfg=48  gui=bold cterm=bold
hi typescriptFuncKeyword   guifg=#FF3BFF guibg=NONE ctermfg=201 gui=bold cterm=bold
hi typescriptImport        guifg=#FF3BFF guibg=NONE ctermfg=201 gui=bold cterm=bold
hi typescriptExport        guifg=#FF3BFF guibg=NONE ctermfg=201 gui=bold cterm=bold
hi typescriptNull          guifg=#FF7BFF guibg=NONE ctermfg=213 gui=bold cterm=bold
hi typescriptBOM           guifg=#D07BFF guibg=NONE ctermfg=177
hi typescriptGlobal        guifg=#D07BFF guibg=NONE ctermfg=177
hi typescriptDOMGlobal     guifg=#D07BFF guibg=NONE ctermfg=177

" jsx / tsx tags
hi link tsxTag         Statement
hi link tsxTagName     Type
hi link tsxCloseTag    Statement
hi link tsxCloseString Statement
hi link tsxAttrib      Special
hi link tsxEqual       Operator
hi link jsxTag         Statement
hi link jsxTagName     Type
hi link jsxAttrib      Special
hi link jsxCloseTag    Statement

" treesitter (neovim only). Plain vim rejects '@' in group names with W18,
" so this block is guarded.
if has('nvim')
  hi link @variable              Normal
  hi link @property              typescriptProp
  hi link @field                 typescriptProp
  hi link @constructor           Type
  hi link @type                  Type
  hi link @function.call         typescriptCall
  hi link @punctuation.bracket   Delimiter
  hi link @punctuation.delimiter Delimiter
  hi link @tag                   Statement
  hi link @tag.attribute         Special
  hi link @tag.delimiter         Delimiter
endif

" --- diff
hi DiffAdd       guifg=#3BFF9E guibg=#0A2418 ctermfg=48  ctermbg=22
hi DiffChange    guifg=#FFD866 guibg=#241F0A ctermfg=221 ctermbg=58
hi DiffDelete    guifg=#FF3B3B guibg=#240A0A ctermfg=203 ctermbg=52
hi DiffText      guifg=#000000 guibg=#FFD866 ctermfg=16  ctermbg=221 gui=bold cterm=bold

" --- spell
hi SpellBad      guisp=#FF3B3B gui=undercurl ctermfg=203 cterm=underline
hi SpellCap      guisp=#00D9D9 gui=undercurl ctermfg=44  cterm=underline
hi SpellRare     guisp=#B84DFF gui=undercurl ctermfg=135 cterm=underline
hi SpellLocal    guisp=#FFD866 gui=undercurl ctermfg=221 cterm=underline

" --- vim's built-in man page viewer (:Man) so it matches the pager
hi link manSectionHeading Title
hi link manSubHeading     Type
hi link manOptionDesc     Statement
hi link manReference      Statement
hi link manHeader         Title

" --- terminal palette used by :terminal and Neovim
let g:terminal_ansi_colors = [
      \ '#1A1A1A', '#FF3B3B', '#3BFF9E', '#FFD866',
      \ '#B84DFF', '#FF3BFF', '#00D9D9', '#00E5E5',
      \ '#4A4A4A', '#FF6B6B', '#7BFFC4', '#FFE699',
      \ '#D07BFF', '#FF7BFF', '#6BFFFF', '#FFFFFF' ]

if has('nvim')
  let g:terminal_color_0  = '#1A1A1A'
  let g:terminal_color_1  = '#FF3B3B'
  let g:terminal_color_2  = '#3BFF9E'
  let g:terminal_color_3  = '#FFD866'
  let g:terminal_color_4  = '#B84DFF'
  let g:terminal_color_5  = '#FF3BFF'
  let g:terminal_color_6  = '#00D9D9'
  let g:terminal_color_7  = '#00E5E5'
  let g:terminal_color_8  = '#4A4A4A'
  let g:terminal_color_9  = '#FF6B6B'
  let g:terminal_color_10 = '#7BFFC4'
  let g:terminal_color_11 = '#FFE699'
  let g:terminal_color_12 = '#D07BFF'
  let g:terminal_color_13 = '#FF7BFF'
  let g:terminal_color_14 = '#6BFFFF'
  let g:terminal_color_15 = '#FFFFFF'
endif
