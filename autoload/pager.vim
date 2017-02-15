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
  nnoremap <buffer> q :quitall!<CR>
  nnoremap <buffer> <Space> <PageDown>
  nnoremap <buffer> <S-Space> <PageUp>
  nnoremap <buffer> g gg
endfunction

function! s:Unset_maps()
  nunmap q
  nunmap <Space>
  nunmap <S-Space>
  nunmap g
endfunction

function! s:Help()
endfunction

function! s:detect_man_page_in_current_buffer()
  let pattern = '\v\C^N(\b.)?A(\b.)?M(\b.)?E(\b.)?[ \t]*$'
  let l:pos = getpos('.')
  keepjumps call cursor(1, 1)
  let match = search(pattern, 'cnW', 12, 100)
  keepjumps call cursor(l:pos)
  return match != 0
endfunction
