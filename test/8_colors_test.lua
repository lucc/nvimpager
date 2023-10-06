vim.cmd.edit("test/fixtures/ansi-escape-8-colors")

local pos = vim.inspect_pos(0, 10, 53)
vim.fn.assert_equal(1, #pos.extmarks)

local group = pos.extmarks[1].opts.hl_group
vim.fn.assert_equal("NvimPagerFG_green_BG_red_bold", group)

local attrs = vim.api.nvim_get_hl(0, {name = group, link = true})
vim.fn.assert_equal(1, attrs.ctermbg)
vim.fn.assert_equal(2, attrs.ctermfg)
vim.fn.assert_equal(true, attrs.bold)
