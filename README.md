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
all of neovim's command line options.  Use `nvimpager -h` to see the [help
text][options].  The configuration is separated from the users config for
neovim.  The main config file is `~/.config/nvimpager/init.vim`.  See [the
manpage][configuration] for further explanation.

## Installation

<a href="https://repology.org/metapackage/nvimpager/versions">
    <img src="https://repology.org/badge/vertical-allrepos/nvimpager.svg"
	 alt="Packaging status" align="right">
</a>

Nvimpager is already packaged for some distributions. If not for yours, you can
install it manually, read on.

### Dependencies

* [neovim] ≥ v0.4.0
* [bash]
* [busted] (for running the tests)
* [scdoc] (to build the man page)

### Installation instructions

Use the makefile to configure and install the script.  It supports the usual
`PREFIX` (defaults to `/usr/local`) and `DESTDIR` (defaults to empty)
variables:

```sh
make PREFIX=$HOME/.local install
```

Additionally the variable `BUSTED` can be used to specify the executable for
the test suite.

## Development

Nvimpager is developed on [GitHub][nvimpager] where you are very much invited
to [post][issues] bug reports, feature or pull requests!  The test can be run
with `make test`.  They are also run on travis: [![Build Status]][travis]

### Known Bugs (and non features)

* if reading from stdin, nvimpager (like nvim) waits for EOF until it starts up
* large files are slowing down neovim on startup (less does a better, i.e.
  faster and more memory efficient job at paging large files)

### TODO and ideas list

* see how [neovim#7428](https://github.com/neovim/neovim/issues/7438) and
  [neovim#8246](https://github.com/neovim/neovim/issues/8246) are resolved and
  maybe move more code (logic) from bash to lua (bash's `[[ -t ... ]]` can be
  replaced by `has('ttyin')`, `has('ttyout')`)
* proper lazy pipe reading while paging (like less) to improve startup time and
  also memory usage for large input on pipes (maybe `stdioopen()` can be used?)
* properly kill the nvim process when the bash script is killed, alternatively
  ...
* move temp file handling (removal) to nvim/lua (in a VimLeave autocommand) and
  exec nvim

## License

The project is licensed under a BSD-2-clause license.  See the
[LICENSE](./LICENSE) file.

[nvimpager]: https://github.com/lucc/nvimpager
[issues]: https://github.com/lucc/nvimpager/issues
[options]: ./nvimpager.md#command-line-options
[configuration]: ./nvimpager.md#configuration
[neovim]: https://github.com/neovim/neovim
[vimpager]: https://github.com/rkitover/vimpager
[bash]: https://www.gnu.org/software/bash/bash.html
[busted]: https://olivinelabs.com/busted/
[scdoc]: https://git.sr.ht/~sircmpwn/scdoc
[Build Status]: https://travis-ci.com/lucc/nvimpager.svg?branch=develop
[travis]: https://travis-ci.com/github/lucc/nvimpager
