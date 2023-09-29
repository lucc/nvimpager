vim.fn.assert_equal({}, vim.api.nvim_buf_get_keymap(0, "n"))
vim.fn.assert_equal({}, vim.api.nvim_buf_get_keymap(0, "v"))
