#!/bin/sh
# A small wrapper script for the tests.  It can be linked to any name in order
# to simulate different parent processes.

# We set PARENT to the process id of the current script in order to allow
# nvimpager's lua code to be called directly here.  This variable is otherwise
# set up by the bash script and passed to the lua code.
PARENT=$$ "$@" 2>&1
