nvimpager(1)

# NAME

nvimpager - using neovim as a pager

# SYNOPSIS

*nvimpager* [*-acp*] [\--] [nvim options and files] ++
*nvimpager* *-h* ++
*nvimpager* *-v*

# DESCRIPTION

Nvimpager is a small program that can be used like most other pagers.
Internally it uses neovim with the default TUI to display the text. This means
it has all the fancy syntax highlighting, mouse support and other features of
neovim available in the pager, possibly including plugins!

# COMMAND LINE OPTIONS

Nvimpager itself interprets only very few options but all neovim options can
also be specified. If options to neovim are specified before the first file
name they must be preceded by "\--" to prevent nvimpager from trying to
interpret them.

The following options are interpreted by nvimpager itself:

*-a*
	Run in "auto mode" (default). Auto mode will detect the terminal size and
	switch to pager mode if the content to display would not fit on one screen. If
	the content will fit on one screen it will switch to cat mode. This overrides
	any previous *-c* and *-p* options.

*-c*
	Run in "cat mode". Do not start the neovim TUI, only use neovim for syntax
	highlighting and print the result to stdout. This overrides any previous *-a*
	and *-p* options.

*-h*
	Show the help screen and exit

*-p*
	Run in "pager mode". Start the neovim TUI to display the given content. This
	overrides any previous *-a* and *-c* options.

*-v*
	Show version information and exit

# CONFIGURATION

Like neovim itself nvimpager will honour *$XDG_CONFIG_HOME* and
*$XDG_DATA_HOME*, which default to *~/.config* and *~/.local* respectively.
The main config directory is *$XDG_CONFIG_HOME/nvimpager* and the main user
config file is *$XDG_CONFIG_HOME/nvimpager/init.vim*. The site directory is
*$XDG_DATA_HOME/.local/share/nvimpager/site*. The manifest for remote plugins
is read from (and written to) *$XDG_DATA_HOME/nvimpager/rplugin.vim*.

The rest of the *&runtimepath* is configured like for neovim. The *-u* option
of *nvim*(1) itself can be used to change the main config file from the command
line.

The default config files for neovim are not used by design as these
potentially load many plugins and do a lot of configuration that is only
relevant for editing. If one really wants to use the same config files for
both nvimpager and nvim it is possible to do so by symlinking the config and
site directories and the rplugin file.

## Environment variables

The environment variable *$NVIMPAGER_NVIM* can be used to specify an nvim
executable to use.  If unset it defaults to *nvim*.

## Configuration variables

The script exposes a lua table called *nvimpager* to *--cmd*/*-c* options and
the *init.vim* file. It can be modified to change some options that are
specific to nvimpager.

The following fields (options) exist:

[[ *option*
:- *type*
:- *default*
:< *explanation*
|  follow
:  bool
:  false
:  start in follow mode, i.e. continuously load changes to the opened file and
   scroll to the bottom (like *less +F* or *tail -f*)
|  follow_intervall
:  number
:  500
:  how often in ms the underlying file should be checked in follow mode
|  git_colors
:  bool
:  false
:  use git command highlighting instead of nvim syntax highlighting,
   set this to true if you use an external diff
|  maps
:  bool
:  true
:  if some default less like maps should be defined inside pager mode

So to start nvimpager and follow changes to the opened file the user can put

```
lua nvimpager.follow = true
```

in the init file (or on the command line).

## Default key mappings

Nvimpager defines some mappings to make it feel more like a pager than an
editor.  These mappings are inspired by *less*(1) which are very close to the
defaults in neovim.  These mappings can be deactivated altogether by putting

```
lua nvimpager.maps = false
```

in the init file (or on the command line).

The following mappings are defined by default:

- *q* is mapped to quit nvimpager in normal and visual mode
- *<Space>* and *<S-Space>* move down or up a page respectively
- *g* goes to the top of the file
- *<Down>* and *j* scroll the window down one line
- *<Up>* and *k* scroll the window up one line
- *F* toggles "follow mode" where nvimpager continuously loads changes to the
  underlying file and scrolls to the bottom.  This is usefull for watching log
  files.  It is modeled after the *F* command in *less*(1) or the *-f* option
  of *tail*(1)


# EXAMPLES

To use nvimpager to view a file (with neovim's syntax highlighting if the
filetype is detected):

```
nvimpager file
```

Pipe text into nvimpager to view it:

```
echo text | nvimpager
```

Use nvimpager as your default *$PAGER* to view man pages or git diffs:

```
export PAGER=nvimpager
man nvimpager
git diff
```

Options for *nvim*(1) can be specified if they are separated from the options
for nvimpager itself.  Either by separating them with *--* or by putting the
nvim options after at least one non option argument:

```
nvimpager -p -- -c 'echo "option for nvim"' file
nvimpager -p file -u custom_init.vim
```

Start nvimpager in "follow mode" to watch a growing log file:

```
nvimpager log_file -c 'lua nvimpager.follow = true'
```

# LIMITATIONS

If reading from stdin, nvimpager (like *nvim*(1)) waits for EOF until it starts
up.  This means that it can not be used to continuously watch output from a
long running command even in follow mode.

# SEE ALSO

*nvim(1)* https://github.com/neovim/neovim

*vimpager(1)* https://github.com/rkitover/vimpager

# AUTHORS

Lucas Hoffmann
