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
  elseif foreground then
    prefix = '38;5;'
  else
    prefix = '48;5;'
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
  -- empty file and a file with just one empty line.
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
      if conceal and last_conceal_id == conceal_id then -- luacheck: ignore
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
  runtimepath = os.getenv("RUNTIME") .. "," .. table.concat(runtimepath, ",")
  nvim.nvim_set_option("runtimepath", runtimepath)
  new = new .. '/rplugin.vim'
  nvim.nvim_command("let $NVIM_RPLUGIN_MANIFEST = '" .. new .. "'")
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
      nvim.nvim_buf_set_option(0, 'filetype', 'man')
    end
  else
    if doc == 'git' then
      -- Use nvim's syntax highlighting for git buffers instead of git's
      -- internal highlighting.
      strip_ansi_escape_sequences_from_current_buffer()
    elseif doc == 'pydoc' or doc == 'perldoc' or doc == 'ri' then
      doc = 'man'
    end
    nvim.nvim_buf_set_option(0, 'filetype', doc)
  end
end

-- Split a string at a seperator
--
-- The seperator must not be a special character in regex, otherwise this
-- function will break.
--
-- Because neovim uses lua 5.1 the gmatch method on strings includes an empty
-- match at the end *in some cases* (not with ";").  Therefore this function
-- is needed.  Code adopted from https://stackoverflow.com/questions/61053903.
local function split(input, seperator)
  local seperator = seperator or ";"
  return string.gmatch(input..seperator, '([^'..seperator..']*)'..seperator)
end

local namespace
local ansi2highlight_table = {
  [0] = "black",
  [1] = "red",
  [2] = "green",
  [3] = "yellow",
  [4] = "blue",
  [5] = "magenta",
  [6] = "cyan",
  [7] = "white",
}
local state = {
  -- The line and column where the currently described state starts
  line = 1,
  column = 1,
  -- the list of terminal attributes that we can handle (this is used for
  -- iteration)
  attrs = {
    "bold", "italic", "reverse", "standout", "strikethrough", "underline"
  }
}

state.clear = function(self)
  self.foreground = ""
  self.background = ""
  for _, k in ipairs(self.attrs) do self[k] = false end
end

state.state2highlight_group_name = function(self)
  local name = "NvimPagerFG_" .. self.foreground .. "_BG_" .. self.background
  for _, field in ipairs(self.attrs) do
    if self[field] then
      name = name .. "_" .. field
    end
  end
  return name
end

state.parse = function(self, string)
  for token in split(string, ";") do
    if token == "" then token = 0 else token = tonumber(token) end
    if token == 0 then
      self:clear()
    elseif token == 1 then
      self.bold = true
    elseif token >= 30 and token <= 37 then -- foreground color
      self.foreground = ansi2highlight_table[token - 30]
    elseif token == 39 then -- reset foreground
      self.foreground = ""
    elseif token >= 40 and token <= 47 then -- background color
      self.background = ansi2highlight_table[token - 40]
    elseif token == 49 then -- reset background
      self.background = ""
    elseif token >= 90 and token <= 97 then -- bright foreground color
      self.foreground = ansi2highlight_table[token - 90]
      self.standout = true
    elseif token >= 100 and token <= 107 then -- bright foreground color
      self.background = ansi2highlight_table[token - 100]
      self.standout = true
    end
  end
end

state.compute_highlight_command = function(self, groupname)
  local args = ""
  if self.foreground ~= "" then args = args.." guifg="..self.foreground end
  if self.background ~= "" then args = args.." guibg="..self.background end
  local attrs = ""
  for _, key in ipairs(self.attrs) do
    if self[key] then
      attrs = attrs .. "," .. key
    end
  end
  attrs = attrs:sub(2)
  if attrs ~= "" then
    args = args .. " gui=" .. attrs .. " cterm=" .. attrs
  end
  if args == "" then
    return "highlight default link " .. groupname .. " Normal"
  else
    return "highlight default " .. groupname .. args
  end
end

state.render = function(self, from_line, from_column, to_line, to_column)
  if self.color == "" then
    return
  end
  if from_line == to_line and from_column == to_column then
    return
  end
  local groupname = self:state2highlight_group_name()
  -- check if the hl group already exists
  if not pcall(nvim.nvim_get_hl_by_name, groupname, false) then
    nvim.nvim_command(self:compute_highlight_command(groupname))
  end

  local function add_hl(line, from, to)
    -- This function expects 0 based line numbers and column numbers.
    -- Set the start column to 0, the end column to -1 if not given.
    local line_0 = line - 1
    local from_0 = (from or 1) - 1
    local to_0 = (to or 0) - 1
    nvim.nvim_buf_add_highlight(0, namespace, groupname, line_0, from_0, to_0)
  end
  if from_line == to_line then
    add_hl(from_line, from_column, to_column)
  else
    add_hl(from_line, from_column)
    for line = from_line+1, to_line-1 do
      add_hl(line)
    end
    add_hl(to_line, 1, to_column)
  end
end

-- Parse the current buffer for ansi escape sequences and add buffer
-- highlights to the buffer instead.
local function ansi2highlight()
  nvim.nvim_command("syntax match NvimPagerConceal conceal '\\e\\[[0-9;]*m'")
  nvim.nvim_win_set_option(0, "conceallevel", 3)
  nvim.nvim_win_set_option(0, "concealcursor", "nv")
  local pattern = "\27%[([0-9;]*)m"
  state:clear()
  namespace = nvim.nvim_create_namespace("")
  for lnum, line in ipairs(nvim.nvim_buf_get_lines(0, 0, -1, false)) do
    local start, end_, spec = nil, nil, nil
    local col = 1
    repeat
      start, end_, spec = line:find(pattern, col)
      if start ~= nil then
	state:render(state.line, state.column, lnum, start)
	state.line = lnum
	state.column = end_
	state:parse(spec)
	-- update the position to find the next match in the line
	col = end_
      end
    until start == nil
  end
end

-- Set up mappings to make nvim behave a little more like a pager.
local function set_maps()
  local function map(mode, lhs, rhs)
    nvim.nvim_set_keymap(mode, lhs, rhs, {noremap = true})
  end
  map('n', 'q', ':quitall!<CR>')
  map('v', 'q', ':<C-U>quitall!<CR>')
  map('n', '<Space>', '<PageDown>')
  map('n', '<S-Space>', '<PageUp>')
  map('n', 'g', 'gg')
  map('n', '<Up>', '<C-Y>')
  map('n', '<Down>', '<C-E>')
  map('n', 'k', '<C-Y>')
  map('n', 'j', '<C-E>')
end

-- Setup function for the VimEnter autocmd.
-- This function will be called for each buffer once
local function pager_mode()
  if check_escape_sequences() then
    -- Try to highlight ansi escape sequences.
    ansi2highlight()
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
local function stage2()
  detect_filetype()
  local mode, events
  if #nvim.nvim_list_uis() == 0 then
    mode, events = 'cat', 'VimEnter'
  else
    set_maps()
    mode, events = 'pager', 'VimEnter,BufWinEnter'
  end
  -- The "nested" in these autocomands enables nested executions of
  -- autocomands inside the *_mode() functions.  See :h autocmd-nested, for
  -- compatibility with nvim < 0.4 we use "nested" and not "++nested".
  nvim.nvim_command(
    'autocmd NvimPager '..events..' * nested lua nvimpager.'..mode..'_mode()')
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
    init_cat_mode = init_cat_mode,
    replace_prefix = replace_prefix,
    split = split,
    split_rgb_number = split_rgb_number,
    state = state,
  }
}
