-- Functions to use neovim as a pager.

-- Neovim defines this object but luacheck doesn't know it.  So we define a
-- shortcut and tell luacheck to ignore it.
local nvim = vim.api -- luacheck: ignore

-- We cache the calculated escape sequences for the syntax groups.
local cache = {}

local function split_rgb_number(color_number)
  local hex = string.format('%x', color_number)
  local r = tonumber('0x' .. hex:sub(1, 2))
  local g = tonumber('0x' .. hex:sub(3, 4))
  local b = tonumber('0x' .. hex:sub(5, 6))
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
  local escape = '\xb1[0'

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
