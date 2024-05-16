-- Config file for ldoc, see
-- https://stevedonovan.github.io/ldoc/manual/doc.md.html
-- vim: filetype=lua

project = "nvimpager"
file = {
  "lua",
  "test",
  exclude = {
    "test/diff_test.lua",
    "test/meta_test.lua",
    "test/no_map_test.lua",
  }}
all = true
readme = "README.md"
format = "markdown"
