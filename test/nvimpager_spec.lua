-- Busted tests for nvimpager

-- Busted defines these objects but luacheck doesn't know them.  So we
-- redefine them and tell luacheck to ignore it.
local describe, it, assert, pending, mock =
      describe, it, assert, pending, mock  -- luacheck: ignore

-- gloabl varables to set $XDG_CONFIG_HOME and $XDG_DATA_HOME to for the
-- tests.
local confdir = "test/fixtures/no-config"
local datadir = "test/fixtures/no-data"

-- Run a shell command, assert it terminates with return code 0 and return its
-- output.
--
-- command: string -- the shell command to execute
-- returns: string -- the output of the command
local function run(command)
  command = 'XDG_CONFIG_HOME='..confdir..' ' .. command
  command = 'XDG_DATA_HOME='..datadir..' ' .. command
  command = 'env ' .. command
  local proc = io.popen(command)
  local output = proc:read('*all')
  local status = {proc:close()}
  assert.equal(status[1], true)
  return output
end

-- Read contents of a file and return them.
--
-- filename: string -- the name of the file to read
-- returns: string -- the contents of the file
local function read(filename)
  local file = io.open(filename)
  local contents = file:read('*all')
  return contents
end

describe("auto mode", function()
  -- Auto mode only exists during the run of the bash script.  At the end of
  -- the bash script it has to decide if pager or cat mode is used.  This
  -- makes these tests a little more difficult.  We have to inspect the state
  -- of the bash script in some way.

  -- Source the given command line in a bash script with some mocks and print
  -- all set variables at the end.
  --
  -- command: string -- the shell command to execute
  -- returns: string -- the output of the sourced command and all set
  -- variables
  local function bash(command)
    -- Make nvim an alias with a semicolon so potential redirections in the
    -- original nvim execution don't take effect.  Also mock exec and trap.
    local script = [[
      set -e
      set -u
      shopt -s expand_aliases
      alias nvim='return; '
      alias exec=:
      alias trap=:
      source ]] .. command .. "\nset"
    local filename = os.tmpname()
    local file = io.open(filename, "w")
    file:write(script)
    file:close()
    local output = run("bash " .. filename)
    --os.remove(filename)
    return output
  end

  it("selects cat mode for small files", function()
    local output = bash('./nvimpager test/fixtures/makefile')
    -- $mode might still be auto so we check the generated command line.
    local default_args = output:match("\ndefault_args[^\n]*\n")
    assert.truthy(default_args:match('--headless'))
  end)

  it("auto mode selects pager mode for big inputs", function()
    local output = bash('./nvimpager ./README.md ./nvimpager')
    -- $mode might still be auto so we check the generated command line.
    local default_args = output:match("\ndefault_args[^\n]*\n")
    assert.is_nil(default_args:match('--headless'))
  end)
end)

describe("cat mode", function()
  it("displays a small file with syntax highlighting to stdout", function()
    local output = run("./nvimpager -c test/fixtures/makefile")
    local expected = read("test/fixtures/makefile.ansi")
    assert.equal(output, expected)
  end)

  it("reads stdin with syntax highlighting", function()
    local output = run("./nvimpager -c -- -c 'set filetype=make' " ..
                       "< test/fixtures/makefile")
    local expected = read("test/fixtures/makefile.ansi")
    assert.equal(output, expected)
  end)

  it("returns ansi escape sequences unchanged", function()
    local output = run("./nvimpager -c < test/fixtures/makefile.ansi")
    local expected = read("test/fixtures/makefile.ansi")
    assert.equal(output, expected)
  end)

  it("hides concoealed characters", function()
    local output = run("./nvimpager -c test/fixtures/help.txt")
    local expected = read("test/fixtures/help.txt.ansi")
    assert.equal(output, expected)
  end)

  it("replaces conceal replacements", function()
    local output = run("./nvimpager -c test/fixtures/conceal.tex " ..
                       "--cmd \"let g:tex_flavor='latex'\"")
    local expected = read("test/fixtures/conceal.tex.ansi")
    assert.equal(output, expected)
  end)

  it("highlights all files", function()
    local output = run("./nvimpager -c test/fixtures/makefile " ..
                                      "test/fixtures/help.txt")
    local expected = read("test/fixtures/makefile.ansi") ..
                     read("test/fixtures/help.txt.ansi")
    assert.equal(output, expected)
  end)

  it("concatenates the same file twice", function()
    local output = run("./nvimpager -c test/fixtures/makefile " ..
                                      "test/fixtures/makefile")
    local expected = read("test/fixtures/makefile.ansi")
    expected = expected .. expected
    assert.equal(output, expected)
  end)

  it("produces no output for empty files", function()
    local tmp = os.tmpname()
    -- This hangs if /dev/null is used instead.
    local output = run("./nvimpager -c "..tmp)
    os.execute('rm '..tmp)
    assert.equal(output, '')
  end)

  it("produces no output for empty stdin", function()
    local output = run("./nvimpager -c </dev/null")
    assert.equal(output, '')
  end)

  pending("highlights files even after mode line files", function()
    local output = run("./nvimpager -c test/fixtures/conceal.tex " ..
		       "test/fixtures/makefile " ..
		       "--cmd \"let g:tex_flavor='latex'\"")
    local expected = read("test/fixtures/conceal.tex.ansi") ..
                     read("test/fixtures/makefile.ansi")
    assert.equal(output, expected)
  end)

  pending("honors mode lines in later files", function()
    local output = run("./nvimpager -c test/fixtures/makefile " ..
		       "test/fixtures/conceal.tex " ..
		       "--cmd \"let g:tex_flavor='latex'\"")
    local expected = read("test/fixtures/makefile.ansi") ..
                     read("test/fixtures/conceal.tex.ansi")
    assert.equal(output, expected)
  end)
end)

describe("pager mode", function()
  it("starts up and quits correctly", function()
    run("./nvimpager -p makefile -c quit")
  end)
end)

describe("backend:", function()
  it("runtimepath doesn't include nvim's user dirs", function()
    local cmd = "RUNTIME=special-test-value " ..
      "nvim --headless " ..
      "--cmd 'set runtimepath+=.' " ..
      "--cmd 'call pager#start()' " ..
      "--cmd 'let rtp = nvim_list_runtime_paths()' " ..
      "--cmd 'if index(rtp, $RUNTIME) == -1 | cquit | endif' " ..
      "--cmd 'if index(rtp, stdpath(\"config\")) != -1 | cquit | endif' " ..
      "--cmd 'if index(rtp, stdpath(\"data\")) != -1 | cquit | endif' " ..
      "--cmd quit"
    run(cmd)
  end)

  it("plugin manifest doesn't contain nvim's value", function()
    -- Nvim writes this message to stderr so we have to redirect this.
    local output = run("./nvimpager -c -- README.md " ..
                       "-c 'echo $NVIM_RPLUGIN_MANIFEST' -c quit 2>&1")
    assert.equal(output, datadir..'/nvimpager/rplugin.vim')
  end)
end)

describe("lua functions", function()

  -- Create a local mock of the vim module that is provided by neovim.
  local vim = {
    api = {
      nvim_get_hl_by_id = function() return {} end
    }
  }
  _G.vim = vim
  local nvimpager = require("lua/nvimpager")

  describe("split_rgb_number", function()
    it("handles numbers from 0 to 16777215", function()
      local r, g, b = nvimpager.split_rgb_number(0x000000)
      assert.equal(r, 0)
      assert.equal(g, 0)
      assert.equal(b, 0)
      r, g, b = nvimpager.split_rgb_number(0xFFFFFF)
      assert.equal(r, 255)
      assert.equal(g, 255)
      assert.equal(b, 255)
    end)

    it("correctly splits rgb values", function()
      local r, g, b = nvimpager.split_rgb_number(0x55AACC)
      assert.equal(r, 0x55)
      assert.equal(g, 0xAA)
      assert.equal(b, 0xCC)
    end)
  end)

  describe("group2ansi", function()
    it("calls nvim_get_hl_by_id", function()
      local m = mock(vim)
      local escape = nvimpager.group2ansi(100)
      assert.stub(m.api.nvim_get_hl_by_id).was.called_with(100, true)
      assert.equal(escape, '\x1b[0m')
    end)
  end)
end)
