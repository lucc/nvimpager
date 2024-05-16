--- Functions for nvimpager's cat mode

-- Neovim defines this object but luacheck doesn't know it.  So we define a
-- shortcut and tell luacheck to ignore it.
local vim = vim      -- luacheck: ignore
local nvim = vim.api -- luacheck: ignore

local util = require("nvimpager/util")

-- These variables will be initialized during the first call to cat_mode()
--
-- A local copy of the termguicolors option, used for color output in cat
-- mode.
local colors_24_bit
local color2escape

--- A cache to map syntax groups to ansi escape sequences in cat mode or
--- remember defined syntax groups in the ansi rendering functions.
local cache = {}

--- Split a 24 bit color number into the three red, green and blue values
---
--- @param color_number number
local function split_rgb_number(color_number)
  -- The lua implementation of these bit shift operations is taken from
  -- http://nova-fusion.com/2011/03/21/simulate-bitwise-shift-operators-in-lua
  local r = math.floor(color_number / 2 ^ 16)
  local g = math.floor(math.floor(color_number / 2 ^ 8) % 2 ^ 8)
  local b = math.floor(color_number % 2 ^ 8)
  return r, g, b
end

--- Compute the escape sequences for a 24 bit color number.
---
--- @param color_number number a 24 bit color number
--- @param foreground boolean wether to return the escape sequences for fg or
--- bg colors
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

--- Compute the escape sequences for a 8 bit color number.
---
--- @param color_number number an 8 bit color number
--- @param foreground boolean wether to return the escape sequences for fg or
--- bg colors
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
  elseif foreground then
    prefix = '38;5;'
  else
    prefix = '48;5;'
  end
  return prefix .. color_number
end

--- Compute a ansi escape sequences to render a syntax group on the terminal.
---
--- @param groupid integer
local function group2ansi(groupid)
  if cache[groupid] then
    return cache[groupid]
  end
  local info = nvim.nvim_get_hl(0, {id = groupid, link = false})
  if colors_24_bit then
    info.foreground = info.fg
    info.background = info.bg
  else
    info.foreground = info.ctermfg
    info.background = info.ctermbg
    if info.cterm ~= nil then
      info.bold = info.cterm.bold
      info.italic = info.cterm.italic
      info.underline = info.cterm.underline
    else
      info.bold = nil
      info.italic = nil
      info.underline = nil
    end
  end
  if info.reverse then
    info.foreground, info.background = info.background, info.foreground
  end
  -- Reset all attributes before setting new ones.  The vimscript version did
  -- use sevel explicit reset codes: 22, 24, 25, 27 and 28.  If no foreground
  -- or background color was defined for a syntax item they were reset with
  -- 39 or 49.
  local escape = '\27[0'

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

--- Check if the current buffer is empty
local function check_empty()
  if nvim.nvim_buf_line_count(0) <= 1 and nvim.nvim_buf_get_offset(0, 0) <= 0 then
    local handle = io.open(nvim.nvim_buf_get_name(0))
    if handle == nil then
      return true
    end
    local eof = handle:read(0)
    handle:close()
    if eof == nil then
      return true
    end
  end
  return false
end

--- Iterate through the current buffer and print it to stdout with terminal
--- color codes for highlighting.
local function highlight()
  -- Detect an empty buffer.
  if check_empty() then
    return
  elseif util.check_escape_sequences() then
    for _, line in ipairs(nvim.nvim_buf_get_lines(0, 0, -1, false)) do
      io.write(line, '\n')
    end
    return
  end
  local conceallevel = nvim.nvim_win_get_option(0, 'conceallevel')
  local syntax_id_conceal = nvim.nvim_call_function('hlID', {'Conceal'})
  local syntax_id_whitespace = nvim.nvim_call_function('hlID', {'Whitespace'})
  local syntax_id_non_text = nvim.nvim_call_function('hlID', {'NonText'})
  local list = nvim.nvim_win_get_option(0, "list")
  local listchars = list and vim.opt.listchars:get() or {}
  local last_syntax_id = -1
  local last_conceal_id = -1
  local linecount = nvim.nvim_buf_line_count(0)
  for lnum, line in ipairs(nvim.nvim_buf_get_lines(0, 0, -1, false)) do
    local outline = ''
    local skip_next_char = false
    local syntax_id
    for cnum = 1, line:len() do
      local conceal_info = nvim.nvim_call_function('synconcealed',
	{lnum, cnum})
      local conceal = conceal_info[1] == 1
      local replace = conceal_info[2]
      local conceal_id = conceal_info[3]
      if skip_next_char then
	skip_next_char = false
      elseif conceal and last_conceal_id == conceal_id then -- luacheck: ignore
	-- skip this char
      else
	local append
	if conceal then
	  syntax_id = syntax_id_conceal
	  if replace == '' and conceallevel == 1 then replace = ' ' end
	  append = replace
	  last_conceal_id = conceal_id
	else
	  append = line:sub(cnum, cnum)
	  if list and string.find(" \194", append, 1, true) ~= nil then
	    syntax_id = syntax_id_whitespace
	    if append == " " then
	      if line:find("^ +$", cnum) ~= nil then
		append = listchars.trail or listchars.space or append
	      else
		append = listchars.space or append
	      end
	    elseif append == "\194" and line:sub(cnum + 1, cnum + 1) == "\160" then
	      -- Utf8 non breaking space is "\194\160", neovim represents all
	      -- files as utf8 internally, regardless of the actual encoding.
	      -- See :help 'encoding'.
	      append = listchars.nbsp or "\194\160"
	      skip_next_char = true
	    end
	  else
	    syntax_id = nvim.nvim_call_function('synID', {lnum, cnum, true})
	  end
	end
	if syntax_id ~= last_syntax_id then
	  outline = outline .. group2ansi(syntax_id)
	  last_syntax_id = syntax_id
	end
	outline = outline .. append
      end
    end
    -- append a eol listchar if &list is set
    if list and listchars.eol ~= nil then
      syntax_id = syntax_id_non_text
      if syntax_id ~= last_syntax_id then
	outline = outline .. group2ansi(syntax_id)
	last_syntax_id = syntax_id
      end
      outline = outline .. listchars.eol
    end
    -- Write the whole line and a newline char.  If this was the last line
    -- also reset the terminal attributes.
    io.write(outline, lnum == linecount and cache[0] or '', '\n')
  end
end

--- Initialize some module level variables for cat mode.
local function init()
  -- Get the value of &termguicolors from neovim.
  colors_24_bit = nvim.nvim_get_option('termguicolors')
  -- Select the correct coloe escaping function.
  if colors_24_bit then
    color2escape = color2escape_24bit
  else
    color2escape = color2escape_8bit
  end
  -- Initialize the ansi group to color cache with the "Normal" hl group.
  cache[0] = group2ansi(nvim.nvim_call_function('hlID', {'Normal'}))
end

--- Call the highlight function to write the highlighted version of all buffers
--- to stdout and quit nvim.
local function cat_mode()
  init()
  highlight()
  -- We can not use nvim_list_bufs() as a file might appear on the command
  -- line twice.  In this case we want to behave like cat(1) and display the
  -- file twice.
  for _ = 2, nvim.nvim_call_function('argc', {}) do
    nvim.nvim_command('next')
    highlight()
  end
  nvim.nvim_command('quitall!')
end

--- @export
return {
  cat_mode = cat_mode,
  init = init,
  color2escape_24bit = color2escape_24bit,
  color2escape_8bit = color2escape_8bit,
  split_rgb_number = split_rgb_number,
  group2ansi = group2ansi,
}
