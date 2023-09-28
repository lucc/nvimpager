vim.cmd.edit("test/fixtures/diff2")

vim.fn.assert_equal("diff", vim.o.filetype)
