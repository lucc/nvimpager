-- Functions to use neovim as a pager.

-- This code is a rewrite of two sources: vimcat and vimpager (which also
-- conatins a version of vimcat).
-- Vimcat back to Matthew J. Wozniski and can be found at
-- https://github.com/godlygeek/vim-files/blob/master/macros/vimcat.sh
-- Vimpager was written by Rafael Kitover and can be found at
-- https://github.com/rkitover/vimpager

-- Information about terminal escape codes:
-- https://en.wikipedia.org/wiki/ANSI_escape_code

-- Neovim defines this object but luacheck doesn't know it.  So we define a
-- shortcut and tell luacheck to ignore it.
local nvim = vim.api -- luacheck: ignore

-- These variables will be initialized by the first call to init_cat_mode():
-- We cache the calculated escape sequences for the syntax groups.
local cache = {}
-- A local copy of the termguicolors option, used for color output in cat
-- mode.
local colors_24_bit
local color2escape

local function split_rgb_number(color_number)
  -- The lua implementation of these bit shift operations is taken from
  -- http://nova-fusion.com/2011/03/21/simulate-bitwise-shift-operators-in-lua/
  local r = math.floor(color_number / 2 ^ 16)
  local g = math.floor(math.floor(color_number / 2 ^ 8) % 2 ^ 8)
  local b = math.floor(color_number % 2 ^ 8)
  return r, g, b
end

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

local function group2ansi(groupid)
  if cache[groupid] then
    return cache[groupid]
  end
  local info = nvim.nvim_get_hl_by_id(groupid, colors_24_bit)
  if info.reverse then
    info.foreground, info.background = info.background, info.foreground
  end
  -- Reset all attributes before setting new ones.  The vimscript version did
  -- use sevel explicit reset codes: 22, 24, 25, 27 and 28.  If no foreground
  -- or background color was defined for a syntax item they were reset with
  -- 39 or 49.
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

local function init_cat_mode()
  -- Initialize the ansi group to color cache with the "Normal" hl group.
  cache[0] = group2ansi(nvim.nvim_call_function('hlID', {'Normal'}))
  -- Get the value of &termguicolors from neovim.
  colors_24_bit = nvim.nvim_get_option('termguicolors')
  -- Select the correct coloe escaping function.
  if colors_24_bit then
    color2escape = color2escape_24bit
  else
    color2escape = color2escape_8bit
  end
end

-- Iterate through the current buffer and print it to stdout with terminal
-- color codes for highlighting.
local function highlight()
  -- Detect an empty buffer, see :help line2byte().  We can not use
  -- nvim_buf_get_lines as the table will contain one empty string for both an
  -- empty file and a file with just one emptay line.
  if nvim.nvim_buf_line_count(0) == 1 and
    nvim.nvim_call_function("line2byte", {2}) == -1 then
    return
  elseif nvim.nvim_call_function('pager#check_escape_sequences', {}) == 1 then
    for _, line in ipairs(nvim.nvim_buf_get_lines(0, 0, -1, false)) do
      io.write(line, '\n')
    end
    return
  end
  local conceallevel = nvim.nvim_win_get_option(0, 'conceallevel')
  local last_syntax_id = -1
  local last_conceal_id = -1
  local linecount = nvim.nvim_buf_line_count(0)
  for lnum, line in ipairs(nvim.nvim_buf_get_lines(0, 0, -1, false)) do
    local outline = ''
    for cnum = 1, line:len() do
      local conceal_info = nvim.nvim_call_function('synconcealed', {lnum, cnum})
      local conceal = conceal_info[1] == 1
      local replace = conceal_info[2]
      local conceal_id = conceal_info[3]
      if conceal and last_conceal_id == conceal_id then
	-- skip this char
      else
	local syntax_id, append
	if conceal then
	  syntax_id = nvim.nvim_call_function('hlID', {'Conceal'})
	  if replace == '' and conceallevel == 1 then replace = ' ' end
	  append = replace
	  last_conceal_id = conceal_id
	else
	  syntax_id = nvim.nvim_call_function('synID', {lnum, cnum, true})
	  append = line:sub(cnum, cnum)
	end
	if syntax_id ~= last_syntax_id then
	  outline = outline .. group2ansi(syntax_id)
	  last_syntax_id = syntax_id
	end
	outline = outline .. append
      end
    end
    -- Write the whole line and a newline char.  If this was the last line
    -- also reset the terminal attributes.
    io.write(outline, lnum == linecount and cache[0] or '', '\n')
  end
end

-- Call the highlight function to write the highlighted version of all buffers
-- to stdout and quit nvim.
local function cat_mode()
  init_cat_mode()
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

-- Join a table with a string
local function join(table, seperator)
  if #table == 0 then return '' end
  local index = 1
  local ret = table[index]
  index = index + 1
  while index <= #table do
    ret = ret .. seperator .. table[index]
    index = index + 1
  end
  return ret
end

-- Replace a string prefix in all items in a list
local function replace_prefix(table, old_prefix, new_prefix)
  -- Escape all punctuation chars to protect from lua pattern chars.
  old_prefix = old_prefix:gsub('[^%w]', '%%%0')
  for index, value in ipairs(table) do
    table[index] = value:gsub('^' .. old_prefix, new_prefix, 1)
  end
  return table
end

-- Fix the runtimepath.  All user nvim folders are replaced by corresponding
-- nvimpager folders.
local function fix_runtime_path()
  local runtimepath = nvim.nvim_list_runtime_paths()
  -- Remove the custom nvimpager entry that was added on the command line.
  runtimepath[#runtimepath] = nil
  local new
  for _, name in ipairs({"config", "data"}) do
    local original = nvim.nvim_call_function("stdpath", {name})
    new = original .."pager"
    runtimepath = replace_prefix(runtimepath, original, new)
  end
  runtimepath = os.getenv("RUNTIME") .. "," .. join(runtimepath, ",")
  nvim.nvim_set_option("runtimepath", runtimepath)
  new = new .. '/rplugin.vim'
  nvim.nvim_command("let $NVIM_RPLUGIN_MANIFEST = '" .. new .. "'")
end

-- Parse the command of the calling process to detect some common
-- documentation programs (man, pydoc, perldoc, git, ...).  $PPID was exported
-- by the calling bash script and points to the calling program.
local function detect_doc_viewer_from_ppid()
  local ppid = os.getenv('PPID')
  local proc = nvim.nvim_get_proc(tonumber(ppid))
  if proc == nil then return 'none' end
  local command = proc.name
  if command:find('^man') ~= nil then
    return 'man'
  elseif command:find('^[Pp]y(thon|doc)?[0-9.]*') ~= nil then
    return 'pydoc'
  elseif command:find('^[Rr](uby|i)[0-9.]*') ~= nil then
    return 'ri'
  elseif command:find('^perl(doc)?') ~= nil then
    return 'perldoc'
  elseif command:find('^git') ~= nil then
    return 'git'
  end
  return 'none'
end

return {
  cat_mode = cat_mode,
  color2escape_24bit = color2escape_24bit,
  color2escape_8bit = color2escape_8bit,
  detect_doc_viewer_from_ppid = detect_doc_viewer_from_ppid,
  fix_runtime_path = fix_runtime_path,
  group2ansi = group2ansi,
  highlight = highlight,
  init_cat_mode = init_cat_mode,
  join = join,
  replace_prefix = replace_prefix,
  split_rgb_number = split_rgb_number,
}
