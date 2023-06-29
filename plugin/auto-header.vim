if exists('g:loaded_autoheader') | finish | endif "prevent loading file twice

let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset them to defaults

" commands to run auto-header
command! AutoHeader lua require("auto-header").add_or_update_header()

let &cpo = s:save_cpo  " restore the user coptions
unlet s:save_cpo

let g:loaded_autoheader = 1

