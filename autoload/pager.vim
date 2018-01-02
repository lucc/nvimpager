" Copyright (c) 2017 Lucas Hoffmann
" Licenced under a BSD-2-clause licence.  See the LICENSE file.

augroup NvimPager
  autocmd!
augroup END

lua nvimpager = require("nvimpager")

" Setup function to be called from --cmd.  Some early options for both pager
" and cat mode are set here.
function! pager#start() abort
  lua nvimpager.fix_runtime_path()
  " Don't remember file names and positions
  set shada=
  " prevent messages when opening files (especially for the cat version)
  set shortmess+=F
endfunction

" Setup function for pager mode.  Called from -c.
function! pager#prepare_pager() abort
  lua nvimpager.detect_filetype()
  lua nvimpager.set_options()
  call s:set_maps()
  autocmd NvimPager BufWinEnter,VimEnter * call s:pager()
endfunction

" Set up an VimEnter autocmd to print the files to stdout with highlighting.
" Should be called from -c.
function! pager#prepare_cat() abort
  lua nvimpager.detect_filetype()
  autocmd NvimPager VimEnter * lua require('nvimpager').cat_mode()
endfunction

" Setup function for the VimEnter autocmd.
function! s:pager() abort
  if luaeval('nvimpager.check_escape_sequences()')
    " Try to highlight ansi escape sequences with the AnsiEsc plugin.
    AnsiEsc
  endif
  set nomodifiable
  set nomodified
endfunction

" Set up mappings to make nvim behave a little more like a pager.
function! s:set_maps() abort
  nnoremap q :quitall!<CR>
  nnoremap <Space> <PageDown>
  nnoremap <S-Space> <PageUp>
  nnoremap g gg
  nnoremap <Up> <C-Y>
  nnoremap <Down> <C-E>
endfunction

" Unset all mappings set in s:set_maps().
function! s:unset_maps() abort
  nunmap q
  nunmap <Space>
  nunmap <S-Space>
  nunmap g
  nunmap <Up>
  nunmap <Down>
endfunction

" Display some help text about mappings.
function! s:help() abort
  " TODO
endfunction
