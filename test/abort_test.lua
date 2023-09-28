-- we will report an error
vim.fn.assert_report("this is an error")
-- and then immediately quit so that the test framework can not write the error
-- to the output file
vim.cmd.quit()
