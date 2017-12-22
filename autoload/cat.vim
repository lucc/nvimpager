" Copyright (c) 2015 Matthew J. Wozniski, Rafael Kitover, 2017 Lucas Hoffmann
" Licenced under a BSD-2-clause licence.  See the LICENSE file.
"
" This is a modified version of the vimcat script.  The script can be found in
" different places on the internet and ultimatly goes back to Matthew J.
" Wozniski <mjw@drexel.edu>.
" https://github.com/godlygeek/vim-files/blob/master/macros/vimcat.sh
" Many newer features where also taken from
" https://github.com/rkitover/vimpager

lua require('nvimpager').init_cat_mode()

" Iterate through the current buffer and print it to stdout with terminal
" color codes for highlighting.
function! cat#highlight() abort
  lua require("nvimpager").highlight()
endfunction
