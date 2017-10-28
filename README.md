# Nvimpager

Using [neovim][neovim] as a pager to view man pages, git diffs, whatnot with
neovim's syntax highlighting and mouse support.

## About

The `nvimpager` script calls neovim in a fashion that turns it into something
like a pager.  The idea is not new, this is actually rewrite of
[vimpager][vimpager] but with less (but stricter) dependencies and specifically
for neovim.

Some typical use cases:

```sh
# view a file in nvimpager
nvimpager file
# pipe text to nvimpager
echo some text | nvimpager
# use it as your default $PAGER
export PAGER=nvimpager
man bash
git diff
```

The script also has a "cat mode" which will not start up the neovim interface
but instead print a highlighted version of the file to the terminal.  Like cat
with neovim syntax highlighting!  If the input has less lines than the terminal
cat mode is activated automatically so nvimpager behaves similar to `less -F`.
Pager mode and cat mode can be enforced with the options `-p` and `-c`
respectively.

Nvimpager comes with a small set of command line options but you can also use
all of neovim's command line options.  Use `nvimpager -h` to see the help text.
Config files are searched as for plain neovim with the only difference that
`~/.config/nvimpager` is searched instead of `~/.config/nvim` (same for
`~/.local/share/nvimpager` and the `$XDG_..._HOME` variants).  In short: the
user config file is `~/.config/nvimpager/init.vim`.

## Technical stuff

### Dependencies:

* [neovim][neovim]
* [bash][bash]
* ([curl][curl] for installation)

### Installation instructions:

Use the makefile to install the script and its dependencies (the default
`PREFIX` is `/usr/local`):

```sh
make PREFIX=$HOME/.local install
```

### Known Bugs (and non features):

* if reading from stdin, nvimpager (like nvim) waits for EOF until it starts up
* large files are slowing down neovim on startup (less does a better, i.e.
  faster and more memory efficient job at paging large files)

[neovim]: https://github.com/neovim/neovim
[vimpager]: https://github.com/rkitover/vimpager
[bash]: http://www.gnu.org/software/bash/bash.html
[curl]: https://curl.haxx.se
