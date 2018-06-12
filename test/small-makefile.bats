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

# vim: filetype=sh
