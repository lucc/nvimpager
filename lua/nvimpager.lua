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
-- This variable holds the name of the detected parent process for pager mode.
local doc = nil

local function split_rgb_number(color_number)
  -- The lua implementation of these bit shift operations is taken from
  -- http://nova-fusion.com/2011/03/21/simulate-bitwise-shift-operators-in-lua
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

-- Check if the begining of the current buffer contains ansi escape sequences.
local function check_escape_sequences()
  local filetype = nvim.nvim_buf_get_option(0, 'filetype')
  if filetype == '' or filetype == 'text' then
    for _, line in ipairs(nvim.nvim_buf_get_lines(0, 0, 100, false)) do
      if line:find('\27%[[;?]*[0-9.;]*[A-Za-z]') ~= nil then return true end
    end
  end
  return false
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
  elseif check_escape_sequences() then
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
      local conceal_info = nvim.nvim_call_function('synconcealed',
	{lnum, cnum})
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
local function detect_parent_process()
  local ppid = os.getenv('PPID')
  if not ppid then return nil end
  local proc = nvim.nvim_get_proc(tonumber(ppid))
  if proc == nil then return 'none' end
  local command = proc.name
  if command == 'man' then
    return 'man'
  elseif command:find('^[Pp]ython[0-9.]*') ~= nil or
	 command:find('^[Pp]ydoc[0-9.]*') ~= nil then
    return 'pydoc'
  elseif command == 'ruby' or command == 'ri' then
    return 'ri'
  elseif command == 'perl' or command == 'perldoc' then
    return 'perldoc'
  elseif command == 'git' then
    return 'git'
  end
  return nil
end

-- Search the begining of the current buffer to detect if it contains a man
-- page.
local function detect_man_page_in_current_buffer()
  -- Only check the first twelve lines (for speed).
  for _, line in ipairs(nvim.nvim_buf_get_lines(0, 0, 12, false)) do
    -- Check if the line contains the string "NAME" or "NAME" with every
    -- character overwritten by itself.
    -- An earlier version of this code did also check if there are whitespace
    -- characters at the end of the line.  I could not find a man pager where
    -- this was the case.
    -- FIXME This only works for man pages in languages where "NAME" is used
    -- as the headline.  Some (not all!) German man pages use "BBEZEICHNUNG"
    -- instead.
    if line == 'NAME' or line == 'N\bNA\bAM\bME\bE' then
      return true
    end
  end
  return false
end

-- Remove ansi escape sequences from the current buffer.
local function strip_ansi_escape_sequences_from_current_buffer()
  local modifiable = nvim.nvim_buf_get_option(0, "modifiable")
  nvim.nvim_buf_set_option(0, "modifiable", true)
  nvim.nvim_command(
    [=[keepjumps silent %substitute/\v\e\[[;?]*[0-9.;]*[a-z]//egi]=])
  nvim.nvim_win_set_cursor(0, {1, 0})
  nvim.nvim_buf_set_option(0, "modifiable", modifiable)
end

-- Detect possible filetypes for the current buffer by looking at the pstree
-- or ansi escape sequences or manpage sequences in the current buffer.
local function detect_filetype()
  if not doc then
    if detect_man_page_in_current_buffer() then
      -- FIXME: Why does this need to be the command?  Why doesn't this work:
      --nvim.nvim_buf_set_option(0, 'filetype', 'man')
      nvim.nvim_command('setfiletype man')
    end
  else
    if doc == 'git' then
      -- Use nvim's syntax highlighting for git buffers instead of git's
      -- internal highlighting.
      strip_ansi_escape_sequences_from_current_buffer()
    elseif doc == 'pydoc' or doc == 'perldoc' then
      doc = 'man'
    end
    -- FIXME: Why does this need to be the command?  Why doesn't this work:
    --nvim.nvim_buf_set_option(0, 'filetype', doc)
    nvim.nvim_command('setfiletype '..doc)
  end
end

-- Set up mappings to make nvim behave a little more like a pager.
local function set_maps()
  nvim.nvim_command('nnoremap q :quitall!<CR>')
  nvim.nvim_command('nnoremap <Space> <PageDown>')
  nvim.nvim_command('nnoremap <S-Space> <PageUp>')
  nvim.nvim_command('nnoremap g gg')
  nvim.nvim_command('nnoremap <Up> <C-Y>')
  nvim.nvim_command('nnoremap <Down> <C-E>')
end

-- Unset all mappings set in set_maps().
-- FIXME This is currently unused but keept for reference.
local function unset_maps()
  nvim.nvim_command("nunmap q")
  nvim.nvim_command("nunmap <Space>")
  nvim.nvim_command("nunmap <S-Space>")
  nvim.nvim_command("nunmap g")
  nvim.nvim_command("nunmap <Up>")
  nvim.nvim_command("nunmap <Down>")
end

-- Setup function for the VimEnter autocmd.
local function pager_mode()
  if check_escape_sequences() then
    -- Try to highlight ansi escape sequences with the AnsiEsc plugin.
    nvim.nvim_command('AnsiEsc')
  end
  nvim.nvim_buf_set_option(0, 'modifiable', false)
  nvim.nvim_buf_set_option(0, 'modified', false)
end

-- Setup function to be called from --cmd.
local function stage1()
  fix_runtime_path()
  -- Don't remember file names and positions
  nvim.nvim_set_option('shada', '')
  -- prevent messages when opening files (especially for the cat version)
  nvim.nvim_set_option('shortmess', nvim.nvim_get_option('shortmess')..'F')
  -- Define autocmd group for nvimpager.
  nvim.nvim_command('augroup NvimPager')
  nvim.nvim_command('  autocmd!')
  nvim.nvim_command('augroup END')
  doc = detect_parent_process()
  if doc == 'git' then
    --nvim.nvim_set_option('modeline', false)
    nvim.nvim_command('set nomodeline')
  end
  -- Theoretically these options only affect the pager mode so they could also
  -- be set in stage2() but that would overwrite user settings from the init
  -- file.
  nvim.nvim_set_option('mouse', 'a')
  nvim.nvim_set_option('laststatus', 0)
end

-- Set up autocomands to start the correct mode after startup or for each
-- file.  This function assumes that in "cat mode" we are called with
-- --headless and hence do not have a user interface.  This also means that
-- this function can only be called with -c or later as the user interface
-- would not be available in --cmd.
local function stage2()
  detect_filetype()
  if #nvim.nvim_list_uis() == 0 then
    -- cat mode
    nvim.nvim_command("autocmd NvimPager VimEnter * lua nvimpager.cat_mode()")
  else
    -- pager mode
    set_maps()
    nvim.nvim_command(
      'autocmd NvimPager BufWinEnter,VimEnter * lua nvimpager.pager_mode()')
  end
end

return {
  cat_mode = cat_mode,
  pager_mode = pager_mode,
  stage1 = stage1,
  stage2 = stage2,
  _testable = {
    color2escape_24bit = color2escape_24bit,
    color2escape_8bit = color2escape_8bit,
    detect_parent_process = detect_parent_process,
    group2ansi = group2ansi,
    highlight = highlight,
    init_cat_mode = init_cat_mode,
    join = join,
    replace_prefix = replace_prefix,
    set_maps = set_maps,
    split_rgb_number = split_rgb_number,
  }
}
