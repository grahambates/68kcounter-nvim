" Title:        68k Counter
" Description:  Motorola 68000 cycle counts and instruction sizes
" Maintainer:   Graham Bates <https://github.com/grahambates>

if exists("g:loaded_68kcounter")
  finish
endif
let g:loaded_68kcounter = 1

command! -nargs=0 CounterShow lua require("68kcounter").show()
command! -nargs=0 CounterHide lua require("68kcounter").hide()
command! -nargs=0 CounterToggle lua require("68kcounter").toggle()
