#!/usr/bin/env bats

load helpers

setup () {
  export XDG_CONFIG_HOME=$BATS_TMPDIR
}

@test "display a small file with syntax highlighting to stdout" {
  run ./nvimpager -c test/fixtures/makefile
  run diff <(echo "$output") test/fixtures/makefile.ansi
  status_ok
}

@test "ansi escape sequences are returned unchanged" {
  run ./nvimpager -c < test/fixtures/makefile.ansi
  run diff <(echo "$output") test/fixtures/makefile.ansi
  status_ok
}

@test "auto mode selects cat mode for small files" {
  # Use aliases to mock nvim in the sourced nvimpager script.
  shopt -s expand_aliases
  # Make nvim an alias with a semicolon so potential redirection in the
  # original nvim execution don't take effect.
  alias nvim='return; '
  # Also mock exec and trap when source the nvimpager script.
  alias exec=: trap=:
  source ./nvimpager test/fixtures/makefile
  # Disable aliases again (release mocks).
  shopt -u expand_aliases
  # $mode might still be auto so we check the generated command line.
  in_array --headless "${default_args[@]}"
}

@test "auto mode selects pager mode for big inputs" {
  # Use aliases to mock nvim in the sourced nvimpager script.
  shopt -s expand_aliases
  # Make nvim an alias with a semicolon so potential redirection in the
  # original nvim execution don't take effect.
  alias nvim='return; '
  # Also mock exec and trap when source the nvimpager script.
  alias exec=: trap=:
  source ./nvimpager ./README.md ./nvimpager
  # Disable aliases again (release mocks).
  shopt -u expand_aliases
  # $mode might still be auto so we check the generated command line.
  ! in_array --headless "${default_args[@]}"
}
