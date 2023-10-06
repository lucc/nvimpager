local function get_extmark(line, column)
  local pos = vim.inspect_pos(0, line, column)
  if #pos.extmarks >= 1 then
    local group = pos.extmarks[1].opts.hl_group
    return vim.api.nvim_get_hl(0, { name = group, link = true })
  else
    vim.fn.assert_report("no extmarks at position " .. line .. "," .. column)
  end
end

vim.cmd.edit("test/fixtures/ansi-escape-attributes")

local attr = get_extmark(0, 18)
vim.fn.assert_true(attr.bold,"bold attribute missing")

attr = get_extmark(0, 39)
vim.fn.assert_true(attr.italic, "italic attribute missing")

attr = get_extmark(0, 51)
vim.fn.assert_true(attr.underline, "underline attribute missing")

attr = get_extmark(0, 105)
vim.fn.assert_true(attr.strikethrough, "strikethrough attribute missing")
