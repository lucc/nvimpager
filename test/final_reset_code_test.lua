local function assert_bg_color(line, column, background)
  local buffername = vim.api.nvim_buf_get_name(0)
  local pos = vim.inspect_pos(0, line, column)
  if #pos.extmarks >= 1 then
    local group = pos.extmarks[1].opts.hl_group
    local attrs = vim.api.nvim_get_hl(0, { name = group, link = true })
    vim.fn.assert_equal(background, attrs.bg, "background "..buffername)
    return group, attrs
  else
    vim.fn.assert_report("no extmarks at "..line..","..column.." in "..buffername)
  end
end

vim.cmd.edit("test/fixtures/ansi-no-final-clear.txt")
assert_bg_color(0, 25, 0x00a21f)

vim.cmd.edit("test/fixtures/ansi-no-final-clear2.txt")
assert_bg_color(0, 25, 0x00a21f)
local pos = vim.inspect_pos(0, 0, 50)
vim.fn.assert_equal(0, #pos.extmarks)
vim.fn.assert_equal(0, #pos.syntax)
