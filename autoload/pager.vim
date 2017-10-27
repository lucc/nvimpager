
augroup NvimPager
  autocmd!
augroup END

" Setup function to ba called from --cmd.  Some early options for both pager
" and cat mode are set here.
function! pager#start() abort
  " Don't remember file names and positions
  set shada=
  " prevent messages when opening files (especially for the cat version)
  set shortmess+=F
  autocmd NvimPager VimEnter * call pager#start3()
endfunction

" Setup function for pager mode.  Called from -c.
function! pager#start2() abort
  call pager#detect_file_type()
  call s:Set_options()
  call s:Set_maps()
  redraw!
endfunction

" Setup function for the VimEnter autocmd.
function! pager#start3() abort
  if &filetype ==# ''
    call s:try_ansi_esc()
  endif
  set nomodifiable
  set nomodified
endfunction

" Detect possible filetypes for the current buffer by looking at the pstree or
" ansi escape sequences or manpage sequences in the current buffer.
function! pager#detect_file_type() abort
  let l:doc = s:detect_doc_viewer_from_pstree()
  if l:doc ==# 'none'
    if s:detect_man_page_in_current_buffer()
      setfiletype man
    endif
  else
    if l:doc ==# 'git'
      call s:strip_ansi_escape_sequences_from_current_buffer()
    elseif l:doc ==# 'pydoc'
      call s:strip_overstike_from_current_buffer()
      let l:doc = 'man'
    elseif l:doc ==# 'perldoc'
      call s:strip_ansi_escape_sequences_from_current_buffer()
      call s:strip_overstike_from_current_buffer()
      let l:doc = 'man'
    endif
    execute 'setfiletype ' l:doc
  endif
endfunction

" Set options for interactive paging of a files.
function! s:Set_options() abort
  set mouse=a
  set scrolloff=0
  set hlsearch
  set incsearch
  nohlsearch
  set nowrapscan
  " Inhibit screen updates while searching
  set lazyredraw
  set laststatus=0
  syntax on
endfunction

" Set up mappings to make nvim behave a little more like a pager.
function! s:Set_maps() abort
  nnoremap <buffer> q :quitall!<CR>
  nnoremap <buffer> <Space> <PageDown>
  nnoremap <buffer> <S-Space> <PageUp>
  nnoremap <buffer> g gg
  nnoremap <buffer> <Up> <C-Y>
  nnoremap <buffer> <Down> <C-E>
endfunction

" Unset all mappings set in s:Set_maps().
function! s:Unset_maps() abort
  nunmap q
  nunmap <Space>
  nunmap <S-Space>
  nunmap g
  nunmap <Up>
  nunmap <Down>
endfunction

" Display some help text about mappings.
function! s:Help() abort
  " TODO
endfunction

" Search the begining of the current buffer to detect if it contains a man
" page.
function! s:detect_man_page_in_current_buffer() abort
  let l:pattern = '\v\C^N(\b.)?A(\b.)?M(\b.)?E(\b.)?[ \t]*$'
  let l:pos = getpos('.')
  keepjumps call cursor(1, 1)
  let l:match = search(l:pattern, 'cnW', 12, 100)
  keepjumps call cursor(l:pos)
  return l:match != 0
endfunction

" Parse the command of the calling process to detect some common documentation
" programs (man, pydoc, perldoc, git, ...).
function! s:detect_doc_viewer_from_pstree() abort
  let l:pslist = systemlist('ps aw -o pid= -o ppid= -o command=')
  if type(l:pslist) ==# type('') && l:pslist ==# ''
    return 0
  endif
  let l:pstree = {}
  for l:line in l:pslist
    let [l:pid, l:ppid, l:cmd; l:_] = split(l:line)
    let l:cmd = substitute(l:cmd, '^.*/', '', '')
    let l:pstree[l:pid] = {'ppid': l:ppid, 'cmd': l:cmd}
  endfor
  let l:cur = l:pstree[getpid()]
  while l:cur.ppid != 1
    if l:cur.cmd =~# '^man'
      return 'man'
    elseif l:cur.cmd =~# '\v\C^[Pp]y(thon|doc)?[0-9.]*'
      return 'pydoc'
    elseif l:cur.cmd =~# '\v\C^[Rr](uby|i)[0-9.]*'
      return 'ri'
    elseif l:cur.cmd =~# '\v\C^perl(doc)?'
      return 'perldoc'
    elseif l:cur.cmd =~# '\C^git'
      return 'git'
    else
      try
        let l:cur = l:pstree[l:cur.ppid]
      catch 'E716'
        return 'none'
      endtry
    endif
  endwhile
  return 'none'
endfunction

" Remove ansi escape sequences from the current buffer.
function! s:strip_ansi_escape_sequences_from_current_buffer() abort
  let l:mod = &modifiable
  let l:position = getpos('.')
  set modifiable
  keepjumps silent %substitute/\v\e\[[;?]*[0-9.;]*[a-z]//egi
  call setpos('.', l:position)
  let &modifiable = l:mod
endfunction

" Remove "overstrike" (like used in man pages) from current buffer.
function! s:strip_overstike_from_current_buffer() abort
  let l:mod = &modifiable
  let l:position = getpos('.')
  set modifiable
  keepjumps silent %substitute/\v.\b//eg
  call setpos('.', l:position)
  let &modifiable = l:mod
endfunction

" Check if the begining of the current buffer contains ansi escape sequences.
function! pager#check_escape_sequences() abort
  let l:ansi_regex = '\e\[[;?]*[0-9.;]*[A-Za-z]'
  return search(l:ansi_regex, 'cnW', 100) != 0
endfunction

" Try to highlight ansi escape sequences with the AnsiEsc plugin.
function! s:try_ansi_esc() abort
  if pager#check_escape_sequences()
    runtime plugin/AnsiEscPlugin.vim
    runtime plugin/cecutil.vim
    AnsiEsc
  endif
endfunction
