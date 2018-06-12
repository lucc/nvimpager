# NAME

nvimpager - using neovim as a pager

# SYNOPSIS

    nvimpager [-acp] [--] [nvim options and files]
    nvimpager -h
    nvimpager -v

# DESCRIPTION

Nvimpager is a small program that can be used like most other pagers.
Internally it uses neovim with the default TUI to display the text. This means
it has all the fancy syntax highlighting, mouse support and other features of
neovim available in the pager, possibly including plugins!

# OPTIONS

Neovim itself interprets only very few options but all neovim options can also
be specified.  If options to neovim are specified before the first file name
they must be preceded by "--" to prevent neovim from trying to interpret them.

The following options are interpreted by neovim itself:

*-a* run in "auto mode" (default)

*-c* run in "cat mode"

*-h* show the help screen and exit

*-p* run in "pager mode"

*-v* show version information and exit

# CONFIGURATION

Like neovim itself nvimpager will honour `$XDG_CONFIG_HOME` and
`$XDG_DATA_HOME`, which default to `~/.config` and `~/.local` respectively.
The main config directory is `$XDG_CONFIG_HOME/nvimpager` and the main user
config file is `$XDG_CONFIG_HOME/nvimpager/init.vim`.

The `&runtimepath` is configured like for neovim

# EXAMPLES

# AUTHORS

# SEE ALSO

