-- Neovim defines this object but luacheck doesn't know it.  So we define a
-- shortcut and tell luacheck to ignore it.
local nvim = vim.api -- luacheck: ignore

-- A neovim highlight namespace to group together all highlights added to
-- buffers by this module.
local namespace

-- A cache to remember which syntax groups have already been defined.
local cache = {}

-- A mapping of ansi color numbers to neovim color names
local colors = {
  [0] = "black",     [8] = "darkgray",
  [1] = "red",       [9] = "lightred",
  [2] = "green",     [10] = "lightgreen",
  [3] = "yellow",    [11] = "lightyellow",
  [4] = "blue",      [12] = "lightblue",
  [5] = "magenta",   [13] = "lightmagenta",
  [6] = "cyan",      [14] = "lightcyan",
  [7] = "lightgray", [15] = "white",
}

-- the names of neovim's highlighting attributes that are handled by this
-- module
-- Most attributes are refered to by their highlighting attribute name in
-- neovim's :highlight command.
local attributes = {
  [1] = "bold",
  --[2] = "faint", -- not handled by neovim
  [3] = "italic",
  [4] = "underline",
  --[5] = "slow blink", -- not handled by neovim
  --[6] = "underline", -- not handled by neovim
  [7] = "reverse",
  [8] = "conceal",
  [9] = "strikethrough",
  -- TODO when to use the gui attribute "standout"?
}

local function hexformat_rgb_numbers(r, g, b)
  return string.format("#%06x", r * 2^16 + g * 2^8 + b)
end

local function split_predifined_terminal_color(color_number)
  local r = math.floor(color_number / 36)
  local g = math.floor(math.floor(color_number / 6) % 6)
  local b = math.floor(color_number % 6)
  local lookup = {[0]=0, [1]=95, [2]=135, [3]=175, [4]=215, [5]=255}
  return lookup[r], lookup[g], lookup[b]
end

-- Create an iterator that tokenizes the given input string into ansi escape
-- sequences.
--
-- Lua patterns for string.gmatch
local function tokenize(input_string)
  -- The empty input string is a special case where we return one single
  -- token.
  if input_string == "" then return string.gmatch("", "") end
  -- we keep track of the position in the input with a local variable so that
  -- our "next" function does not need to rely on the second argument.
  -- Especially if a token appears twice in the input that might be of
  -- importance.
  local position = 1
  local function next(input)
    -- If the position we are currently tokenizing is beyond the input string
    -- return nil => stop tokenizing.
    if input:len() < position then return nil end

    -- If we are on the last character and it is a semicolon, return an empty
    -- token and move position beyond the input to stop on the next call.
    -- This is hard to handle properly in the tokenizer below.
    if input:len() == position and input:sub(-1) == ";" then
      position = position + 1
      return ""
    end

    -- first check for the special sequences "38;" "48;"
    local init = input:sub(position, position+2)
    if init == "38;" or init == "48;" then
      -- Try to match an 8 bit or a 24 bit color sequence
      local patterns = {"([34])8;5;(%d+);?", "([34])8;2;(%d+);(%d+);(%d+);?"}
      for _, pattern in ipairs(patterns) do
	local start, stop, token, c1, c2, c3 = input:find(pattern, position)
	if start == position then
	  position = stop + 1
	  return token == "3" and "foreground" or "background", c1, c2, c3
	end
      end
      -- If no valid special sequence was found we fall through to the normal
      -- tokenization.
    end

    -- handle all other tokens, we expect a simple number followed by either a
    -- semicolon or the end of the string, or the end of the input string
    -- directly.
    local oldpos = position
    local next_pos = input:find(";", position)
    if next_pos == nil then
      -- no further semicolon was found, we reached the end of the input
      -- string, the next call to this function will return nil
      position = input:len() + 1
      return input:sub(oldpos, -1)
    else
      position = next_pos
      -- We only skip the semicolon if it was not at the end of the input
      -- string.
      if next_pos < input:len() then
	position = next_pos + 1
      end
      return input:sub(oldpos, next_pos - 1)
    end
  end

  return next, input_string, nil
end

local state = {
  -- The line and column where the currently described state starts
  line = 1,
  column = 1,
}

function state:clear()
  self.foreground = ""
  self.background = ""
  self.ctermfg = ""
  self.ctermbg = ""
  for _, k in pairs(attributes) do self[k] = false end
end

function state:state2highlight_group_name()
  if self.conceal then return "NvimPagerConceal" end
  local name = "NvimPagerFG_" .. self.foreground:gsub("#", "") ..
	       "_BG_" .. self.background:gsub("#", "")
  for _, field in pairs(attributes) do
    if self[field] then
      name = name .. "_" .. field
    end
  end
  return name
end

function state:parse(string)
  for token, c1, c2, c3 in tokenize(string) do
    -- First we check for 256 colors and 24 bit color sequences.
    if c3 ~= nil then
	self[token] = hexformat_rgb_numbers(tonumber(c1), tonumber(c2),
					    tonumber(c3))
    elseif c1 ~= nil then
      self:parse8bit(token, c1)
      self["cterm"..token:sub(1, 1).."g"] = tonumber(c1)
    else
      if token == "" then token = 0 else token = tonumber(token) end
      if token == 0 then
	self:clear()
      elseif token == 1 or token == 3 or token == 4 or token == 7
	  or token == 8 or token == 9 then
	-- 2, 5 and 6 could be handled here if they were supported.
	self[attributes[token]] = true
      elseif token == 21 then
	-- 22 means "doubley underline" or "bold off", we could implement
	-- doubley underline by undercurl.
	--self.undercurl = true
      elseif token == 22 then
	self.bold = false
	--self.faint = false
      elseif token == 23 or token == 24 or token == 27 or token == 28
	  or token == 29 then
	-- 25 means blink off so it could also be handled here if it was
	-- supported.
	self[attributes[token - 20]] = false
      elseif token >= 30 and token <= 37 then -- foreground color
	self.foreground = colors[token - 30]
	self.ctermfg = token - 30
      elseif token == 39 then -- reset foreground
	self.foreground = ""
	self.ctermfg = ""
      elseif token >= 40 and token <= 47 then -- background color
	self.background = colors[token - 40]
	self.ctermbg = token - 40
      elseif token == 49 then -- reset background
	self.background = ""
	self.ctermbg = ""
      elseif token >= 90 and token <= 97 then -- bright foreground color
	self.foreground = colors[token - 82]
      elseif token >= 100 and token <= 107 then -- bright background color
	self.background = colors[token - 92]
      end
    end
  end
end

function state:parse8bit(fgbg, color)
  local colornr = tonumber(color)
  if colornr >= 0 and colornr <= 7 then
    color = colors[colornr]
  elseif colornr >= 8 and colornr <= 15 then -- high pallet colors
    color = colors[colornr] -- + 82 + 10 * (fgbg == "background" and 1 or 0)
  elseif colornr >= 16 and colornr <= 231 then -- color cube
    color = hexformat_rgb_numbers(split_predifined_terminal_color(colornr-16))
  else -- grayscale ramp
    colornr = 8 + 10 * (colornr - 232)
    color = hexformat_rgb_numbers(colornr, colornr, colornr)
  end
  self[fgbg] = ""..color
end

function state:compute_highlight_command(groupname)
  local args = ""
  if self.foreground ~= "" then
    args = args.." guifg="..self.foreground
    if self.ctermfg ~= "" then
      args = args .. " ctermfg=" .. self.ctermfg
    end
  end
  if self.background ~= "" then
    args = args.." guibg="..self.background
    if self.ctermbg ~= "" then
      args = args .. " ctermbg=" .. self.ctermbg
    end
  end
  local attrs = ""
  for _, key in pairs(attributes) do
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

-- Wrapper around nvim_buf_add_highlight to fix index offsets
--
-- The function nvim_buf_add_highlight expects 0 based line numbers and column
-- numbers.  Set the start column to 0, the end column to -1 if not given.
local function add_highlight(groupname, line, from, to)
  local line_0 = line - 1
  local from_0 = (from or 1) - 1
  local to_0 = (to or 0) - 1
  nvim.nvim_buf_add_highlight(0, namespace, groupname, line_0, from_0, to_0)
end

-- Apply a highlight to a range in the current buffer
--
-- The highlight attributes are generated from the current state (self).
function state:render(from_line, from_column, to_line, to_column)
  if from_line == to_line and from_column == to_column then
    return
  end
  local groupname = self:state2highlight_group_name()
  -- check if the hl group already exists
  if cache[groupname] == nil then
    nvim.nvim_command(self:compute_highlight_command(groupname))
    cache[groupname] = true
  end

  if from_line == to_line then
    add_highlight(groupname, from_line, from_column, to_column)
  else
    add_highlight(groupname, from_line, from_column)
    for line = from_line+1, to_line-1 do
      add_highlight(groupname, line)
    end
    add_highlight(groupname, to_line, 1, to_column)
  end
end

-- Parse the current buffer for ansi escape sequences and add buffer
-- highlights to the buffer instead.
local function ansi2highlight()
  nvim.nvim_command(
    "syntax match NvimPagerEscapeSequence conceal '\\e\\[[0-9;]*m'")
  nvim.nvim_command(
    "syntax match NvimPagerEscapeSequence conceal '\\e\\[[0-2]\\?K'")
  nvim.nvim_command("highlight NvimPagerConceal gui=NONE guisp=NONE " ..
		    "guifg=background guibg=background")
  nvim.nvim_win_set_option(0, "conceallevel", 3)
  nvim.nvim_win_set_option(0, "concealcursor", "nv")
  local pattern = "\27%[([0-9;]*)m"
  state:clear()
  namespace = nvim.nvim_create_namespace("")
  for lnum, line in ipairs(nvim.nvim_buf_get_lines(0, 0, -1, false)) do
    local start, end_, spec
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

return {
  hexformat_rgb_numbers = hexformat_rgb_numbers,
  run = ansi2highlight,
  split_predifined_terminal_color = split_predifined_terminal_color,
  state = state,
  tokenize = tokenize,
}
