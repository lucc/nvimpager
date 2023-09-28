vim.fn.assert_equal("table", type(nvimpager))
vim.fn.assert_equal("boolean", type(nvimpager.maps))
vim.fn.assert_equal("boolean", type(nvimpager.follow))
vim.fn.assert_equal("number", type(nvimpager.follow_interval))
