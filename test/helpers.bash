# Helper functions for the test suite.

status_ok () {
  [[ $status -eq 0 ]]
}

in_array () {
  # This code is taken from https://stackoverflow.com/questions/3685970.
  for e in "${@:2}"; do
    [[ "$e" = "$1" ]] && return 0
  done
  return 1
}
