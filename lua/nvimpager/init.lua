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
local vim = vim      -- luacheck: ignore

local ansi2highlight = require("nvimpager/ansi2highlight")

-- names that will be exported from this module
local nvimpager = {
  -- user facing options
  maps = true,          -- if the default mappings should be defined
  git_colors = false,   -- if the highlighting from the git should be used
  -- follow the end of the file when it changes (like tail -f or less +F)
  follow = false,
  follow_interval = 500, -- intervall to check the underlying file in ms
}

-- These variables will be initialized during the first call to cat_mode() or
-- pager_mode().
--
-- A cache to map syntax groups to ansi escape sequences in cat mode or
-- remember defined syntax groups in the ansi rendering functions.
local cache = {}
-- A local copy of the termguicolors option, used for color output in cat
-- mode.
local colors_24_bit
local color2escape
-- This variable holds the name of the detected parent process for pager mode.
local doc
-- A neovim highlight namespace to group together all highlights added to
-- buffers by this module.
local namespace

-- Split a 24 bit color number into the three red, green and blue values
local function split_rgb_number(color_number)
  -- The lua implementation of these bit shift operations is taken from
  -- http://nova-fusion.com/2011/03/21/simulate-bitwise-shift-operators-in-lua
  local r = math.floor(color_number / 2 ^ 16)
  local g = math.floor(math.floor(color_number / 2 ^ 8) % 2 ^ 8)
  local b = math.floor(color_number % 2 ^ 8)
  return r, g, b
end

-- Compute the escape sequences for a 24 bit color number.
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

-- Compute the escape sequences for a 8 bit color number.
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

-- Compute a ansi escape sequences to render a syntax group on the terminal.
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

-- Initialize some module level variables for cat mode.
local function init_cat_mode()
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

-- Check if the begining of the current buffer contains ansi escape sequences.
--
-- For performance only the first 100 lines are checked.
local function check_escape_sequences()
  local filetype = nvim.nvim_buf_get_option(0, 'filetype')
  if filetype == '' or filetype == 'text' then
    for _, line in ipairs(nvim.nvim_buf_get_lines(0, 0, 100, false)) do
      if line:find('\27%[[;?]*[0-9.;]*[A-Za-z]') ~= nil then return true end
    end
  end
  return false
end

-- turn a listchars string into a table
local function parse_listchars(listchars)
  local t = {}
  for item in vim.gsplit(listchars, ",", true) do
    local kv = vim.split(item, ":", true)
    t[kv[1]] = kv[2]
  end
  return t
end

-- Iterate through the current buffer and print it to stdout with terminal
-- color codes for highlighting.
local function highlight()
  -- Detect an empty buffer.
  if nvim.nvim_buf_get_offset(0, 0) == -1 then
    return
  elseif check_escape_sequences() then
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
  local listchars = list and parse_listchars(vim.o.listchars) or {}
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

-- Call the highlight function to write the highlighted version of all buffers
-- to stdout and quit nvim.
function nvimpager.cat_mode()
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
  runtimepath = table.concat(runtimepath, ",")
  nvim.nvim_set_option("packpath", runtimepath)
  runtimepath = os.getenv("RUNTIME") .. "," .. runtimepath
  nvim.nvim_set_option("runtimepath", runtimepath)
  vim.env.NVIM_RPLUGIN_MANIFEST = new .. '/rplugin.vim'
end

-- Parse the command of the calling process to detect some common
-- documentation programs (man, pydoc, perldoc, git, ...).  $PARENT was
-- exported by the calling bash script and points to the calling program.
local function detect_parent_process()
  local ppid = os.getenv('PARENT')
  if not ppid then return nil end
  local proc = nvim.nvim_get_proc(tonumber(ppid))
  if proc == nil then return 'none' end
  local command = proc.name
  if command == 'man' then
    return 'man'
  elseif command:find('^[Pp]ython[0-9.]*') ~= nil or
	 command:find('^[Pp]ydoc[0-9.]*') ~= nil then
    return 'pydoc'
  elseif command == 'ruby' or command == 'irb' or command == 'ri' then
    return 'ri'
  elseif command == 'perl' or command == 'perldoc' then
    return 'perldoc'
  elseif command == 'git' then
    return 'git'
  end
  return nil
end

--- Check if a string uses poor man's bold or underline tricks
---
--- Return true if all characters are followed by backspace and themself again
--- or if all characters are preceeded by underscore and backspace.  Spaces
--- are ignored.
---
--- @param line string
local function detect_man_page_helper(line)
  if line == "" then return false end
  local index = 1
  while index <= #line do
    local cur = line:sub(index, index)
    local next = line:sub(index+1, index+1)
    local third = line:sub(index+2, index+2)
    if (cur == third and next == '\b')
      or (cur == '_' and next == '\b' and third ~= nil) then
      index = index + 3  -- continue after the overwriting character
    elseif cur == " " then
      index = index + 1
    else
      return false
    end
  end
  return true
end

-- Search the begining of the current buffer to detect if it contains a man
-- page.
local function detect_man_page_in_current_buffer()
  -- Only check the first twelve lines (for speed).
  for _, line in ipairs(nvim.nvim_buf_get_lines(0, 0, 12, false)) do
    if detect_man_page_helper(line) then
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
  if not doc and detect_man_page_in_current_buffer() then doc = 'man' end
  if doc == 'git' then
    if nvimpager.git_colors then
      -- Use the highlighting from the git commands.
      doc = nil
    else
      -- Use nvim's syntax highlighting for git buffers instead of git's
      -- internal highlighting.
      strip_ansi_escape_sequences_from_current_buffer()
    end
  end
  -- python uses the same "highlighting" technique with backspace as roff.
  -- This means we have to load the full :Man plugin for python as well and
  -- not just set the filetype to man.
  if doc == 'man' or doc == 'pydoc' then
    nvim.nvim_buf_set_option(0, 'readonly', false)
    nvim.nvim_command("Man!")
    nvim.nvim_buf_set_option(0, 'readonly', true)
    -- do not set the file type again later on
    doc = nil
  elseif doc == 'perldoc' or doc == 'ri' then
    doc = 'man' -- only set the syntax, not the full :Man plugin
  end
  if doc ~= nil then
    nvim.nvim_buf_set_option(0, 'filetype', doc)
  end
end

local follow_timer = nil
function nvimpager.toggle_follow()
  if follow_timer ~= nil then
    vim.fn.timer_pause(follow_timer, nvimpager.follow)
    nvimpager.follow = not nvimpager.follow
  else
    follow_timer = vim.fn.timer_start(
      nvimpager.follow_interval,
      function()
	nvim.nvim_command("silent checktime")
	nvim.nvim_command("silent $")
      end,
      { ["repeat"] = -1 })
    nvimpager.follow = true
  end
end

-- Set up mappings to make nvim behave a little more like a pager.
local function set_maps()
  local function map(lhs, rhs, mode)
    -- we are using buffer local maps because we want to overwrite the buffer
    -- local maps from the man plugin (and maybe others)
    vim.keymap.set(mode or 'n', lhs, rhs, { buffer = true })
  end
  map('q', '<CMD>quitall!<CR>')
  map('q', '<CMD>quitall!<CR>', 'v')
  map('<Space>', '<PageDown>')
  map('<S-Space>', '<PageUp>')
  map('g', 'gg')
  map('<Up>', '<C-Y>')
  map('<Down>', '<C-E>')
  map('k', '<C-Y>')
  map('j', '<C-E>')
  map('F', nvimpager.toggle_follow)
end

-- Setup function for the VimEnter autocmd.
-- This function will be called for each buffer once
function nvimpager.pager_mode()
  if check_escape_sequences() then
    -- Try to highlight ansi escape sequences.
    ansi2highlight.run()
    -- Lines with concealed ansi esc sequences seem shorter than they are (by
    -- character count) so it looks like they wrap to early and the concealing
    -- of escape sequences only works for the first &synmaxcol chars.
    nvim.nvim_buf_set_option(0, "synmaxcol", 0) -- unlimited
    nvim.nvim_win_set_option(0, "wrap", false)
  end
  nvim.nvim_buf_set_option(0, 'modifiable', false)
  nvim.nvim_buf_set_option(0, 'modified', false)
  if nvimpager.maps then
    -- if this is done in VimEnter it will override any settings in the user
    -- config, if we do it globally we are not overwriting the mappings from
    -- the man plugin
    set_maps()
  end
  -- Check if the user requested follow mode on startup
  if nvimpager.follow then
    -- turn follow mode of so that we can use the init logic in toggle_follow
    nvimpager.follow = false
    nvimpager.toggle_follow()
  end
end

-- Setup function to be called from --cmd.
function nvimpager.stage1()
  fix_runtime_path()
  -- Don't remember file names and positions
  nvim.nvim_set_option('shada', '')
  -- prevent messages when opening files (especially for the cat version)
  nvim.nvim_set_option('shortmess', nvim.nvim_get_option('shortmess')..'F')
  -- Define autocmd group for nvimpager.
  local group = nvim.nvim_create_augroup('NvimPager', {})
  local tmp = os.getenv('TMPFILE')
  if tmp and tmp ~= "" then
    nvim.nvim_create_autocmd("VimEnter", {pattern = "*", once = true,
      group = group, callback = function()
	nvim.nvim_buf_set_option(0, "buftype", "nofile")
	os.remove(tmp)
      end})
  end
  doc = detect_parent_process()
  if doc == 'git' then
    -- We disable modelines for this buffer as they could disturb the git
    -- highlighting in diffs.
    nvim.nvim_buf_set_option(0, 'modeline', false)
    nvim.nvim_set_option('modelines', 0)
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
function nvimpager.stage2()
  detect_filetype()
  local callback, events
  if #nvim.nvim_list_uis() == 0 then
    callback, events = nvimpager.cat_mode, 'VimEnter'
  else
    callback, events = nvimpager.pager_mode, {'VimEnter', 'BufWinEnter'}
  end
  local group = nvim.nvim_create_augroup('NvimPager', {clear = false})
  -- The "nested" in these autocomands enables nested executions of
  -- autocomands inside the *_mode() functions.  See :h autocmd-nested.
  nvim.nvim_create_autocmd(events, {pattern = '*', callback = callback,
    nested = true, group = group})
end

-- functions only exported for tests
nvimpager._testable = {
  color2escape_24bit = color2escape_24bit,
  color2escape_8bit = color2escape_8bit,
  detect_man_page_helper = detect_man_page_helper,
  detect_parent_process = detect_parent_process,
  group2ansi = group2ansi,
  init_cat_mode = init_cat_mode,
  replace_prefix = replace_prefix,
  split_rgb_number = split_rgb_number,
}

return nvimpager
