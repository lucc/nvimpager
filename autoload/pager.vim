" Copyright (c) 2017 Lucas Hoffmann
" Licenced under a BSD-2-clause licence.  See the LICENSE file.

" Set up an VimEnter autocmd to print the files to stdout with highlighting.
" Should be called from -c.
function! pager#prepare_cat() abort
  lua nvimpager.detect_filetype()
  autocmd NvimPager VimEnter * lua require('nvimpager').cat_mode()
endfunction
