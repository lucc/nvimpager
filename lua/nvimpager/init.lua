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

local cat = require("nvimpager/cat")
local pager = require("nvimpager/pager")

-- names that will be exported from this module
local nvimpager = require("nvimpager/options")

-- These variables will be initialized during the first call to cat_mode() or
-- pager_mode().
--
-- This variable holds the name of the detected parent process for pager mode.
local doc

-- Replace a string prefix in all items in a list
local function replace_prefix(table, old_prefix, new_prefix)
  -- Escape all punctuation chars to protect from lua pattern chars.
  old_prefix = old_prefix:gsub('[^%w]', '%%%0')
  for index, value in ipairs(table) do
    table[index] = value:gsub('^' .. old_prefix, new_prefix, 1)
  end
  return table
end

-- Parse the command of the given pid to detect some common
-- documentation programs (man, pydoc, perldoc, git, ...).
local function detect_process(pid)
  if not pid then return nil end
  -- FIXME saving and resetting gcr after nvim_get_proc is a workaround for
  -- https://github.com/neovim/neovim/issues/23122, reported in #84
  local old_gcr = vim.o.gcr
  vim.o.gcr = ''
  local proc = nvim.nvim_get_proc(pid)
  vim.o.gcr =  old_gcr
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

-- Parse the command of the calling process
-- $PARENT was exported by the calling bash script and points to the calling
-- program.
local function detect_parent_process()
  return detect_process(tonumber(os.getenv('PARENT')))
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


-- Setup function to be called from --cmd.
function nvimpager.stage1()
  -- Don't remember file names and positions
  nvim.nvim_set_option('shada', '')
  -- prevent messages when opening files (especially for the cat version)
  nvim.nvim_set_option('shortmess', nvim.nvim_get_option('shortmess')..'F')
  -- Define autocmd group for nvimpager.
  local group = nvim.nvim_create_augroup('NvimPager', {})
  local tmp = os.getenv('TMPFILE')
  if tmp and tmp ~= "" then
    nvim.nvim_create_autocmd("BufReadPost", {pattern = tmp, once = true,
      group = group, callback = function()
	nvim.nvim_buf_set_option(0, "buftype", "nofile")
      end})
    nvim.nvim_create_autocmd("VimLeavePre", {pattern = "*", once = true,
      group = group, callback = function() os.remove(tmp) end})
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
    callback, events = cat.cat_mode, 'VimEnter'
  else
    callback, events = pager.pager_mode, {'VimEnter', 'BufWinEnter'}
  end
  local group = nvim.nvim_create_augroup('NvimPager', {clear = false})
  -- The "nested" in these autocomands enables nested executions of
  -- autocomands inside the *_mode() functions.  See :h autocmd-nested.
  nvim.nvim_create_autocmd(events, {pattern = '*', callback = callback,
    nested = true, group = group})
end

-- functions only exported for tests
nvimpager._testable = {
  detect_man_page_helper = detect_man_page_helper,
  detect_process = detect_process,
  detect_parent_process = detect_parent_process,
  replace_prefix = replace_prefix,
}

return nvimpager
