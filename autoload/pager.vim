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

" Set up an VimEnter autocmd to print the files to stdout with highlighting.
" Should be called from -c.
function! pager#prepare_cat() abort
  lua nvimpager.detect_filetype()
  autocmd NvimPager VimEnter * lua require('nvimpager').cat_mode()
endfunction
