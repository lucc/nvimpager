# Helper functions for the test suite.

status_ok () {
  [[ $status -eq 0 ]]
}

in_array () {
  # This code is taken from https://stackoverflow.com/questions/3685970.
  for e in "${@:2}"; do
    [[ $e = $1 ]] && return 0
  done
  return 1
}

mock () {
  # Use aliases to mock commands.  This is more versatile than using functions
  # because aliases are expanded eariler and can redirect execution to a
  # function anyways.
  shopt -s expand_aliases
  for arg; do
    alias "$arg"
  done
}

release_mocks () {
  unalias -a
  shopt -u expand_aliases
}
