" Title:        68k Counter
" Description:  Motorola 68000 cycle counts and instruction sizes
" Maintainer:   Graham Bates <https://github.com/grahambates>

syn match m68kcounterParens /[()]/
syn match m68kcounterNumbers /\d\+/

hi link m68kcounterParens Delimiter
hi link m68kcounterNumbers Number
