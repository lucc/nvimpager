" This is a rewrite of the functionality of the vimcat script.  The script can
" be found in different places on the internet and ultimatly goes back to
" Matthew J. Wozniski <mjw@drexel.edu> (as far as I can tell).
" https://github.com/godlygeek/vim-files/blob/master/macros/vimcat.sh
" https://github.com/trapd00r/utils/blob/master/_v
" https://gist.github.com/echristopherson/4090959
" http://github.com/rkitover/vimpager

let s:ansicache = {}

" I suspect that we will never see anything other than this.
let s:type = 'cterm'

function! cat#prepare() abort
  autocmd NvimPager VimEnter * call cat#run()
endfunction

function! cat#run() abort
  " Write output directly to stdout of the parent process (the shell script).
  let outfile = '/proc/'.$PID.'/fd/1'
  while bufnr('%') < bufnr('$')
    call s:highlight(outfile)
    bdelete
  endwhile
  call s:highlight(outfile)
  quitall!
endfunction

function! s:highlight(outfile) abort
  " Detect an empty buffer, see :help line2byte().
  if line2byte(line('$')+1) == -1
    return
  endif

  let retv = []

  for lnum in range(1, line('$'))
    let last = hlID('Normal')
    let output = s:group_to_ansi(last) . "\<Esc>[K" " Clear to right

        " Hopefully fix highlighting sync issues
    exe "norm! " . lnum . "G$"

    let line = getline(lnum)

    for cnum in range(1, col('.'))
      if synIDtrans(synID(lnum, cnum, 1)) != last
        let last = synIDtrans(synID(lnum, cnum, 1))
        let output .= s:group_to_ansi(last)
      endif

      let output .= matchstr(line, '\%(\zs.\)\{'.cnum.'}')
      "let line = substitute(line, '.', '', '')
            "let line = matchstr(line, '^\@<!.*')
    endfor
    let retv += [output]
  endfor
  " Reset the colors to default after displaying the file
  let retv[-1] .= "\<Esc>[0m"

  return writefile(retv, a:outfile)
endfunction

function! s:group_to_ansi(groupnum) abort
  let groupnum = a:groupnum

  if groupnum == 0
    let groupnum = hlID('Normal')
  endif

  if has_key(s:ansicache, groupnum)
    return s:ansicache[groupnum]
  endif

  let fg = synIDattr(groupnum, 'fg', s:type)
  let bg = synIDattr(groupnum, 'bg', s:type)
  let rv = synIDattr(groupnum, 'reverse', s:type)
  let bd = synIDattr(groupnum, 'bold', s:type)

  " FIXME other attributes?

  if rv == "" || rv == -1
    let rv = 0
  endif

  if bd == "" || bd == -1
    let bd = 0
  endif

  if rv
    let temp = bg
    let bg = fg
    let fg = temp
  endif

  if fg == "" || fg == -1
    unlet fg
  endif

  if !exists('fg') && !groupnum == hlID('Normal')
    let fg = synIDattr(hlID('Normal'), 'fg', s:type)
    if fg == "" || fg == -1
      unlet fg
    endif
  endif

  if bg == "" || bg == -1
    unlet bg
  endif

  if !exists('bg')
    let bg = synIDattr(hlID('Normal'), 'bg', s:type)
    if bg == "" || bg == -1
      unlet bg
    endif
  endif

  let retv = "\<Esc>[22;24;25;27;28"

  if bd
    let retv .= ";1"
  endif

  if exists('fg') && fg < 8
    let retv .= ";3" . fg
  elseif exists('fg')  && fg < 16    "use aixterm codes
    let retv .= ";9" . (fg - 8)
  elseif exists('fg')                "use xterm256 codes
    let retv .= ";38;5;" . fg
  else
    let retv .= ";39"
  endif

  if exists('bg') && bg < 8
    let retv .= ";4" . bg
  elseif exists('bg') && bg < 16     "use aixterm codes
    let retv .= ";10" . (bg - 8)
  elseif exists('bg')                "use xterm256 codes
    let retv .= ";48;5;" . bg
  else
    let retv .= ";49"
  endif

  let retv .= "m"

  let s:ansicache[groupnum] = retv

  return retv
endfunction
