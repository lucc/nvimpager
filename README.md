# Nvimpager

Using [neovim] as a pager to view man pages, git diffs, whatnot with neovim's
syntax highlighting and mouse support.

## About

The `nvimpager` script calls neovim in a fashion that turns it into something
like a pager.  The idea is not new, this is actually rewrite of [vimpager] but
with less (but stricter) dependencies and specifically for neovim.

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

### Dependencies

* [neovim] ≥ v0.3.0
* [bash]
* ([curl] during installation)
* ([bats] for running the tests)
* ([pandoc] to build the man page)

### Installation instructions

Use the makefile to install the script and its dependencies.  It supports the
usual `PREFIX` (defaults to `/usr/local`) and `DESTDIR` (defaults to empty)
variables:

```sh
make PREFIX=$HOME/.local install
```

### Development

Nvimpager is developed on [Github][nvimpager] where you are very much invited
to [post][issues] bug reports, feature or pull requests!  The test can be run
with `make test`.

### Known Bugs (and non features)

* if reading from stdin, nvimpager (like nvim) waits for EOF until it starts up
* large files are slowing down neovim on startup (less does a better, i.e.
  faster and more memory efficient job at paging large files)

#### TODO List

* show a short message in the cmdline like less and vimpager do (file and help
  information)
* see how [neovim#7428](https://github.com/neovim/neovim/issues/7438) is
  resolved and maybe move more code (logic) from bash to vimscript
* check if terminal buffers can be used to render ansi escape codes,
  alternatively ...
* check license options for bundling the AnsiEsc plugin
* implement some more keybindings that make it behave more like less
* see what parts can reasonably be implemented in lua (speed improvement?)
* proper lazy pipe reading while paging (like less) to improve startup time and
  also memory usage for large input on pipes

## License

The project is licensed under a BSD-2-clause license.  See the
[LICENSE](./LICENSE) file.

[nvimpager]: https://github.com/lucc/nvimpager
[issues]: https://github.com/lucc/nvimpager/issues
[neovim]: https://github.com/neovim/neovim
[vimpager]: https://github.com/rkitover/vimpager
[bash]: http://www.gnu.org/software/bash/bash.html
[curl]: https://curl.haxx.se
[bats]: https://github.com/sstephenson/bats
[pandoc]: http://pandoc.org/
