-- Functions to use neovim as a pager.

-- Neovim defines this object but luacheck doesn't know it.  So we define a
-- shortcut and tell luacheck to ignore it.
local nvim = vim.api -- luacheck: ignore

-- We cache the calculated escape sequences for the syntax groups.
local cache = {}

local function split_rgb_number(color_number)
  -- The lua implementation of these bit shift operations is taken from
  -- http://nova-fusion.com/2011/03/21/simulate-bitwise-shift-operators-in-lua/
  local r = math.floor(color_number / 2 ^ 16)
  local g = math.floor(math.floor(color_number / 2 ^ 8) % 2 ^ 8)
  local b = math.floor(color_number % 2 ^ 8)
  return r, g, b
end

local function group2ansi(groupid)
  if cache[groupid] then
    return cache[groupid]
  end
  local info = nvim.nvim_get_hl_by_id(groupid, true)
  if info.reverse then
    info.foreground, info.background = info.background, info.foreground
  end
  local escape = '\x1b[0'

  if info.bold then escape = escape .. ';1' end
  if info.italic then escape = escape .. ';3' end
  if info.underline then escape = escape .. ';4' end

  if info.foreground then
    local red, green, blue = split_rgb_number(info.foreground)
    escape = escape .. ';38;2;' .. red .. ';' .. green .. ';' .. blue
  end
  if info.background then
    local red, green, blue = split_rgb_number(info.background)
    escape = escape .. ';48;2;' .. red .. ';' .. green .. ';' .. blue
  end

  escape = escape .. 'm'
  cache[groupid] = escape
  return escape
end

return {
  group2ansi = group2ansi,
  split_rgb_number = split_rgb_number,
}
