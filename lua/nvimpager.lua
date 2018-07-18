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

local colors_24_bit = nvim.nvim_get_option('termguicolors')

local function color2escape_24bit(color_number, foreground)
  local red, green, blue = split_rgb_number(color_number)
  local escape
  if foreground then
    escape = '38;2;'
  else
    escape = '48;2;'
  end
  return escape .. red .. ';' .. green .. ';' .. blue
end

local function color2escape_8bit(color_number, foreground)
  local prefix
  if color_number < 8 then
    if foreground then
      prefix = '3'
    else
      prefix = '4'
    end
  elseif color_number < 16 then
    color_number = color_number - 8
    if foreground then
      prefix = '9'
    else
      prefix = '10'
    end
  else
    if foreground then
      prefix = '38;5;'
    else
      prefix = '48;5;'
    end
  end
  return prefix .. color_number
end

local color2escape
if colors_24_bit then
  color2escape = color2escape_24bit
else
  color2escape = color2escape_8bit
end

local function group2ansi(groupid)
  if cache[groupid] then
    return cache[groupid]
  end
  local info = nvim.nvim_get_hl_by_id(groupid, colors_24_bit)
  if info.reverse then
    info.foreground, info.background = info.background, info.foreground
  end
  local escape = '\x1b[0'

  if info.bold then escape = escape .. ';1' end
  if info.italic then escape = escape .. ';3' end
  if info.underline then escape = escape .. ';4' end

  if info.foreground then
    escape = escape .. ';' .. color2escape(info.foreground, true)
  end
  if info.background then
    escape = escape .. ';' .. color2escape(info.background, false)
  end

  escape = escape .. 'm'
  cache[groupid] = escape
  return escape
end

return {
  color2escape_24bit = color2escape_24bit,
  color2escape_8bit = color2escape_8bit,
  group2ansi = group2ansi,
  split_rgb_number = split_rgb_number,
}
