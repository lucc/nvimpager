-- assert some things about the nvimpager module that we export
vim.fn.assert_equal("table", type(nvimpager))
vim.fn.assert_equal("boolean", type(nvimpager.maps))
vim.fn.assert_equal("boolean", type(nvimpager.follow))
vim.fn.assert_equal("number", type(nvimpager.follow_interval))

-- assert that the stage2 function has run, i.e. by checking the autocommands
-- it should set up
local cmds = vim.api.nvim_get_autocmds({group = "NvimPager"})
vim.fn.assert_equal(2, #cmds)
