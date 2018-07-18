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
    let concealid = -1
    let output = s:group_to_ansi(last) . "\<Esc>[K" " Clear to right

    let line = getline(lnum)
    let conceals = map(range(1, len(line)), {index, cnum->synconcealed(lnum, cnum)})

    for cnum in range(1, len(line))
      let last_conceal_id = concealid
      let [conceal, replace, concealid] = conceals[cnum-1]
      if conceal && &conceallevel != 0
	" FIXME These items should be highlighted with the "Conceal" group.
	if &conceallevel == 3 || last_conceal_id == concealid
	  " Concealed text is completely hidden or was already replaced for an
	  " earlier character position.
	  continue
	elseif &conceallevel == 1 && replace == ''
	    let append_text = ' '
	else " conceallevel == 2 or (conceallevel == 1 and replace != '')
	  let append_text = replace
	endif
      else " no conceal for this position or conceallevel == 0
	let append_text = line[cnum-1]
      endif
      let curid = synIDtrans(synID(lnum, cnum, 1))
      if curid != last
        let last = curid
        let output .= s:group_to_ansi(last)
      endif
      let output .= append_text
    endfor
    let retv += [output]
  endfor
  " Reset the colors to default after displaying the file
  let retv[-1] .= "\<Esc>[0m"

  return writefile(retv, '/dev/stdout')
endfunction

" Find the terminal color code for a nvim highlight group id.
function! s:group_to_ansi(groupnum) abort
  let groupnum = a:groupnum
  if groupnum == 0
    let groupnum = hlID('Normal')
  endif
  return luaeval('require("nvimpager").group2ansi(_A.id)', {'id': groupnum})
endfunction
