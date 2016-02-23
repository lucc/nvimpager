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
endfunction

function! s:Set_maps()
  nnoremap q :quitall!<CR>
endfunction

function! s:Unset_maps()
  nunmap q
endfunction

function! s:Help()
endfunction
