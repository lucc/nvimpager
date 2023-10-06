local function get_extmark(line, column)
  local pos = vim.inspect_pos(0, line, column)
  if #pos.extmarks >= 1 then
    local group = pos.extmarks[1].opts.hl_group
    local attrs = vim.api.nvim_get_hl(0, { name = group, link = true })
    return group, attrs
  else
    vim.fn.assert_report("no extmarks at position " .. line .. "," .. column)
  end
end

vim.cmd.edit("test/fixtures/ansi-escape-256-colors")

local group, attrs = get_extmark(0, 122)
vim.fn.assert_equal("NvimPagerFG_black_BG_blue", group)
vim.fn.assert_equal(4, attrs.ctermbg)
vim.fn.assert_equal(0, attrs.ctermfg)

group, attrs = get_extmark(0, 123)
vim.fn.assert_equal("NvimPagerFG_black_BG_blue", group)
vim.fn.assert_equal(4, attrs.ctermbg)
vim.fn.assert_equal(0, attrs.ctermfg)

group, attrs = get_extmark(0, 254)
vim.fn.assert_equal("NvimPagerFG_black_BG_lightred", group)
vim.fn.assert_equal(9, attrs.ctermbg)
vim.fn.assert_equal(0, attrs.ctermfg)


group, attrs = get_extmark(2, 22)
vim.fn.assert_equal("NvimPagerFG_white_BG_000000", group)
vim.fn.assert_equal(16, attrs.ctermbg)
vim.fn.assert_equal(0, attrs.bg)
vim.fn.assert_equal(15, attrs.ctermfg)
vim.fn.assert_equal(0xffffff, attrs.fg)

group, attrs = get_extmark(3, 22)
vim.fn.assert_equal("NvimPagerFG_white_BG_005f00", group)
vim.fn.assert_equal(22, attrs.ctermbg)
vim.fn.assert_equal(0x005f00, attrs.bg)
vim.fn.assert_equal(15, attrs.ctermfg)
vim.fn.assert_equal(0xffffff, attrs.fg)

group, attrs = get_extmark(10, 22)
vim.fn.assert_equal("NvimPagerFG_white_BG_af5f00", group)
vim.fn.assert_equal(130, attrs.ctermbg)
vim.fn.assert_equal(0xaf5f00, attrs.bg)
vim.fn.assert_equal(15, attrs.ctermfg)
vim.fn.assert_equal(0xffffff, attrs.fg)

group, attrs = get_extmark(13, 22)
vim.fn.assert_equal("NvimPagerFG_black_BG_afd700", group)
vim.fn.assert_equal(148, attrs.ctermbg)
vim.fn.assert_equal(0xafd700, attrs.bg)
vim.fn.assert_equal(0, attrs.ctermfg)
vim.fn.assert_equal(0, attrs.fg)
