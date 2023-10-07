-- ensure that we open a file
vim.cmd.edit("test/meta_test.lua")
-- generate an error
vim.fn.assert_report("this is an error")
vim.fn.assert_report("this is an error")
vim.fn.assert_report("this is an error")
vim.fn.assert_report("this is an error")
