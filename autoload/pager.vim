" vim: ft=vim

function! pager#start()
endfunction

function! pager#start2()
  call s:Detect_file_type()
  call s:Set_options()
  call s:Set_maps()
  redraw!
endfunction

function! s:Detect_file_type()
  let mod = &modifiable
  set modifiable
  let doc = s:detect_doc_viewer_from_pstree()
  if doc == 'none'
    if s:detect_man_page_in_current_buffer()
      setfiletype man
    endif
  else
    execute 'setfiletype ' doc
  endif
  let &modifiable = mod
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

function! s:detect_doc_viewer_from_pstree()
  let pslist = systemlist('ps aw -o pid= -o ppid= -o command=')
  if type(pslist) == type('') && pslist == ''
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
    if cur.cmd =~ '^man'
      return 'man'
    elseif cur.cmd =~ '\v\C^[Pp]y(thon|doc)?[0-9.]*'
      return 'pydoc'
    elseif cur.cmd =~ '\v\C^[Rr](uby|i)[0-9.]*'
      return 'ri'
    elseif cur.cmd =~ '\v\C^perl(doc)?'
      return 'perdoc'
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
