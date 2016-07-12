" vim: ft=vim

function! pager#start()
endfunction

function! pager#start2()
  call s:Set_options()
  call s:Set_maps()
  redraw!
endfunction

function! s:Set_options()
  set nomodifiable
  set nomodified

  syntax on
  set scrolloff=0
  set hlsearch
  set incsearch
  nohlsearch
  " Don't remember file names and positions
  set shada=
  set nowrapscan
  " Inhibit screen updates while searching
  let s:lz = &lz
  set lazyredraw
  set laststatus=0

endfunction

function! s:Set_maps()
  nnoremap q :quitall!<CR>
endfunction

function! s:Unset_maps()
  nunmap q
endfunction

function! s:Help()
endfunction
