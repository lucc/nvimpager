" Copyright (c) 2015 Matthew J. Wozniski, Rafael Kitover, 2017 Lucas Hoffmann
" Licenced under a BSD-2-clause licence.  See the LICENSE file.
"
" This is a modified version of the vimcat script.  The script can be found in
" different places on the internet and ultimatly goes back to Matthew J.
" Wozniski <mjw@drexel.edu>.
" https://github.com/godlygeek/vim-files/blob/master/macros/vimcat.sh
" Many newer features where also taken from
" https://github.com/rkitover/vimpager

" Iterate through the current buffer and print it to stdout with terminal
" color codes for highlighting.
function! cat#highlight() abort
  " Detect an empty buffer, see :help line2byte().
  if line2byte(line('$')+1) == -1
    return
  elseif pager#check_escape_sequences()
    silent %write >> /dev/stdout
    return
  endif

  let retv = []

  for lnum in range(1, line('$'))
    let last = hlID('Normal')
    let output = s:group_to_ansi(last) . "\<Esc>[K" " Clear to right

    " Hopefully fix highlighting sync issues
    execute 'normal! ' . lnum . 'G$'

    let line = getline(lnum)

    for cnum in range(1, col('.'))
      let curid = synIDtrans(synID(lnum, cnum, 1))
      if curid != last
        let last = curid
        let output .= s:group_to_ansi(last)
      endif

      let output .= line[cnum-1]
    endfor
    let retv += [output]
  endfor
  " Reset the colors to default after displaying the file
  let retv[-1] .= "\<Esc>[0m"

  return writefile(retv, '/dev/stdout')
endfunction

let s:ansicache = {}

" I suspect that we will never see anything other than this.
let s:type = 'cterm'

" Find the terminal color code for a nvim highlight group id.
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
