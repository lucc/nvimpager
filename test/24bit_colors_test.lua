local function assert_color(line, column, foreground, background)
  local pos = vim.inspect_pos(0, line, column)
  if #pos.extmarks >= 1 then
    local group = pos.extmarks[1].opts.hl_group
    local attrs = vim.api.nvim_get_hl(0, { name = group, link = true })
    vim.fn.assert_equal(foreground, attrs.fg)
    vim.fn.assert_equal(background, attrs.bg)
    return group, attrs
  else
    vim.fn.assert_report("no extmarks at position " .. line .. "," .. column)
  end
end

vim.cmd.edit("test/fixtures/ansi-escape-true-color")

assert_color(0, 32, 0x00ffff, 0xff0000)
assert_color(0, 69, 0x03f8fb, 0xfb0603)
assert_color(0, 187, 0x0de4f1, 0xf11a0d)
assert_color(0, 227, 0x10ddee, 0xee2110)
