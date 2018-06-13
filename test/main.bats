#!/usr/bin/env bats

load helpers

setup () {
  export XDG_CONFIG_HOME=$BATS_TMPDIR
}

@test "display a small file with syntax highlighting to stdout" {
  run ./nvimpager -c test/fixtures/makefile
  diff <(echo "$output") test/fixtures/makefile.ansi
  status_ok
}

@test "ansi escape sequences are returned unchanged" {
  run ./nvimpager -c < test/fixtures/makefile.ansi
  diff <(echo "$output") test/fixtures/makefile.ansi
  status_ok
}

@test "auto mode selects cat mode for small files" {
  # Make nvim an alias with a semicolon so potential redirections in the
  # original nvim execution don't take effect.  Also mock exec and trap.
  mock nvim='return; ' exec=: trap=:
  source ./nvimpager test/fixtures/makefile
  release_mocks
  # $mode might still be auto so we check the generated command line.
  in_array --headless "${default_args[@]}"
}

@test "auto mode selects pager mode for big inputs" {
  # Make nvim an alias with a semicolon so potential redirections in the
  # original nvim execution don't take effect.  Also mock exec and trap.
  mock nvim='return; ' exec=: trap=:
  source ./nvimpager ./README.md ./nvimpager
  release_mocks
  # $mode might still be auto so we check the generated command line.
  ! in_array --headless "${default_args[@]}"
}

@test "hidden concoeal characters" {
  run ./nvimpager -c test/fixtures/help.txt
  diff <(echo "$output") test/fixtures/help.txt.ansi
  status_ok
}

@test "conceal replacements" {
  run ./nvimpager -c test/fixtures/conceal.tex --cmd "let g:tex_flavor='latex'"
  diff <(echo "$output") test/fixtures/conceal.tex.ansi
  status_ok
}
