---
title: NVIMPAGER
section: 1
author: Lucas Hoffmann
date: 2018-06-12
footer: Version 0.3
header: General Commands Manual
...

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

Nvimpager itself interprets only very few options but all neovim options can
also be specified.  If options to neovim are specified before the first file
name they must be preceded by "--" to prevent nvimpager from trying to
interpret them.

The following options are interpreted by nvimpager itself:

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

The rest of the `&runtimepath` is configured like for neovim.

# EXAMPLES

To use nvimpager to view a file (with neovim's syntax highlighting if the
filetype is detected):

    nvimpager file

Pipe text into nvimpager to view it:

    echo text | nvimpager

Use nvimpager as your default \$PAGER to view man pages or git diffs:

    export PAGER=nvimpager
    man nvimpager
    git diff

# SEE ALSO

*nvim*(1) https://github.com/neovim/neovim

*vimpager*(1) https://github.com/rkitover/vimpager
