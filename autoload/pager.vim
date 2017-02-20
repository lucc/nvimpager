" vim: ft=vim

augroup NvimPager
  autocmd!
augroup END

function! pager#start() abort
  autocmd NvimPager VimEnter * call pager#start3()
endfunction

function! pager#start2() abort
  call s:Detect_file_type()
  call s:Set_options()
  call s:Set_maps()
  redraw!
endfunction

function! pager#start3() abort
  if &filetype ==# ''
    call s:try_ansi_esc()
  endif
  set nomodifiable
  set nomodified
endfunction

function! s:Detect_file_type() abort
  let doc = s:detect_doc_viewer_from_pstree()
  if doc ==# 'none'
    if s:detect_man_page_in_current_buffer()
      setfiletype man
    endif
  else
    if doc ==# 'git'
      call s:strip_ansi_escape_sequences_from_current_buffer()
    endif
    execute 'setfiletype ' doc
  endif
endfunction

function! s:Set_options() abort
  syntax on
  set scrolloff=0
  set hlsearch
  set incsearch
  nohlsearch
  " Don't remember file names and positions
  set shada=
  set nowrapscan
  " Inhibit screen updates while searching
  set lazyredraw
  set laststatus=0
endfunction

function! s:Set_maps() abort
  nnoremap <buffer> q :quitall!<CR>
  nnoremap <buffer> <Space> <PageDown>
  nnoremap <buffer> <S-Space> <PageUp>
  nnoremap <buffer> g gg
  nnoremap <buffer> <Up> <C-Y>
  nnoremap <buffer> <Down> <C-E>
endfunction

function! s:Unset_maps() abort
  nunmap q
  nunmap <Space>
  nunmap <S-Space>
  nunmap g
  nunmap <Up>
  nunmap <Down>
endfunction

function! s:Help() abort
endfunction

function! s:detect_man_page_in_current_buffer() abort
  let pattern = '\v\C^N(\b.)?A(\b.)?M(\b.)?E(\b.)?[ \t]*$'
  let l:pos = getpos('.')
  keepjumps call cursor(1, 1)
  let match = search(pattern, 'cnW', 12, 100)
  keepjumps call cursor(l:pos)
  return match != 0
endfunction

function! s:detect_doc_viewer_from_pstree() abort
  let pslist = systemlist('ps aw -o pid= -o ppid= -o command=')
  if type(pslist) ==# type('') && pslist ==# ''
    return 0
  endif
  let pstree = {}
  for line in pslist
    let [pid, ppid, cmd; _] = split(line)
    let cmd = substitute(cmd, '^.*/', '', '')
    let pstree[pid] = {'ppid': ppid, 'cmd': cmd}
  endfor
  let cur = pstree[getpid()]
  while cur.ppid != 1
    if cur.cmd =~# '^man'
      return 'man'
    elseif cur.cmd =~# '\v\C^[Pp]y(thon|doc)?[0-9.]*'
      return 'pydoc'
    elseif cur.cmd =~# '\v\C^[Rr](uby|i)[0-9.]*'
      return 'ri'
    elseif cur.cmd =~# '\v\C^perl(doc)?'
      return 'perdoc'
    elseif cur.cmd =~# '\C^git'
      return 'git'
    else
      try
        let cur = pstree[cur.ppid]
      catch 'E716'
        return 'none'
      endtry
    endif
  endwhile
  return 'none'
endfunction

function! s:strip_ansi_escape_sequences_from_current_buffer() abort
  let mod = &modifiable
  let position = getpos('.')
  set modifiable
  keepjumps silent %substitute/\v\e\[[;?]*[0-9.;]*[a-z]//egi
  call setpos('.', position)
  let &modifiable = mod
endfunction

function! s:strip_overstike_from_current_buffer() abort
  let mod = &modifiable
  let position = getpos('.')
  set modifiable
  keepjumps silent %substitute/\v.\b//eg
  call setpos('.', position)
  let &modifiable = mod
endfunction

function! s:try_ansi_esc() abort
  let ansi_regex = '\e\[[;?]*[0-9.;]*[A-Za-z]'
  if search(ansi_regex, 'cnW', 100) != 0
    AnsiEsc
  endif
endfunction
