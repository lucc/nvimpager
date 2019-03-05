#!/bin/sh
# A small wrapper script for the tests.  It can be linked to any name in order
# to simulate different parent processes.

# We export PPID with the help of env as the shell might complain that it is a
# readonly variable otherwise.  We set PPID to the process id of the current
# script in order to allow nvimpager's lua code to be called directly here.
# This variable is otherwise set up by the bash script and passed to the lua
# code.
env PPID=$$ "$@" 2>&1
