-- Busted tests for nvimpager

-- Busted defines these objects but luacheck doesn't know them.  So we
-- redefine them and tell luacheck to ignore it.
local describe, it, assert = describe, it, assert  -- luacheck: ignore

local helpers = require("test/helpers")
local run, read, write = helpers.run, helpers.read, helpers.write

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
      NVIMPAGER_NVIM=:
      alias exec=:
      alias trap=:
      source ]] .. command .. "\nset"
    local filename = os.tmpname()
    write(filename, script)
    local output = run("bash " .. filename)
    os.remove(filename)
    return output
  end

  it("selects cat mode for small files", function()
    local output = bash('./nvimpager test/fixtures/makefile')
    -- $mode might still be auto so we check the generated command line.
    local args = output:match("\nargs[^\n]*\n")
    assert.truthy(args:match('--headless'))
  end)

  it("auto mode selects pager mode for big inputs", function()
    local output = bash('./nvimpager ./README.md ./nvimpager')
    -- $mode might still be auto so we check the generated command line.
    local args = output:match("\nargs[^\n]*\n")
    assert.is_nil(args:match('--headless'))
  end)
end)

describe("cat mode", function()
  it("displays a small file with syntax highlighting to stdout", function()
    local output = run("./nvimpager -c test/fixtures/makefile")
    local expected = read("test/fixtures/makefile.ansi")
    assert.equal(expected, output)
  end)

  it("reads stdin with syntax highlighting", function()
    local output = run("./nvimpager -c -- " ..
		       "-c 'set filetype=make' " ..
                       "< test/fixtures/makefile")
    local expected = read("test/fixtures/makefile.ansi")
    assert.equal(expected, output)
  end)

  it("returns ansi escape sequences unchanged", function()
    local output = run("./nvimpager -c < test/fixtures/makefile.ansi")
    local expected = read("test/fixtures/makefile.ansi")
    assert.equal(expected, output)
  end)

  it("handles color schemes with a non trivial Normal group", function()
    local output = run("./nvimpager -c test/fixtures/conceal.tex " ..
		       "--cmd 'hi Normal ctermfg=Red'")
    local expected = read("test/fixtures/conceal.tex.red")
    assert.equal(expected, output)
  end)

  it("highlights all files", function()
    local output = run("./nvimpager -c test/fixtures/makefile " ..
                                      "test/fixtures/help.txt ")
    local expected = read("test/fixtures/makefile.ansi") ..
                     read("test/fixtures/help.txt.ansi")
    assert.equal(expected, output)
  end)

  it("concatenates the same file twice", function()
    local output = run("./nvimpager -c test/fixtures/makefile " ..
                                      "test/fixtures/makefile ")
    local expected = read("test/fixtures/makefile.ansi")
    expected = expected .. expected
    assert.equal(expected, output)
  end)

  it("produces no output for empty files", function()
    local tmp = os.tmpname()
    finally(function() os.remove(tmp) end)
    -- This hangs if /dev/null is used instead.
    local output = run("./nvimpager -c "..tmp)
    assert.equal('', output)
  end)

  it("produces no output for empty stdin", function()
    local output = run("./nvimpager -c </dev/null")
    assert.equal('', output)
  end)

  it("explicit - as file argument means stdin", function()
    local shell_command = "echo foo | ./nvimpager -c - test/fixtures/makefile"
    local output = run("sh -c '" .. shell_command .. "'")
    local expected = "\27[0mfoo\27[0m\n" ..
		     read("test/fixtures/makefile.ansi")
    assert.equal(expected, output)
  end)

  it("prefers file arguments over stdin", function()
    local shell_command = "echo foo | ./nvimpager -c test/fixtures/makefile"
    local output = run("sh -c '" .. shell_command .. "'")
    assert.equal(read("test/fixtures/makefile.ansi"), output)
  end)

  it("can show stdin as the second file",  function()
    local output = run("echo foo | ./nvimpager -c test/fixtures/makefile -")
    local expected = read("test/fixtures/makefile.ansi") .. "\27[0mfoo\27[0m\n"
    assert.equal(expected, output)
  end)

  describe("can change the default foreground color", function()
    for termguicolors, extension in pairs({termguicolors = "red24", notermguicolors = "red"}) do
      for _, command in pairs({"--cmd", "-c"}) do
	for stdin, redirect in pairs({[false] = "", [true] = "<"}) do
	  it("with "..command..", setting "..termguicolors..(stdin and " input via stdin" or ""), function()
	    local script = "./nvimpager -c -- " .. command ..
	      " 'highlight Normal ctermfg=red guifg=red | set " ..
	      termguicolors .. "' " .. redirect .. "test/fixtures/plain.txt"
	    local output = run(script)
	    local expected = read("test/fixtures/plain." .. extension)
	    assert.equal(expected, output)
	  end)
	end
      end
    end
  end)

  describe("with modeline", function()
    it("highlights files even after mode line files", function()
      local output = run("./nvimpager -c test/fixtures/conceal.tex " ..
			 "test/fixtures/makefile " ..
			 "--cmd \"let g:tex_flavor='latex'\"")
      local expected = read("test/fixtures/conceal.tex.cole0.ansi") ..
		       read("test/fixtures/makefile.ansi")
      assert.equal(expected, output)
    end)

    it("honors mode lines in later files", function()
      local output = run("./nvimpager -c test/fixtures/makefile " ..
			 "test/fixtures/conceal.tex " ..
			 "--cmd \"let g:tex_flavor='latex'\"")
      local expected = read("test/fixtures/makefile.ansi") ..
		       read("test/fixtures/conceal.tex.cole0.ansi")
      assert.equal(expected, output)
    end)

    it("ignores mode lines in diffs", function()
      local output = run("./nvimpager -c test/fixtures/diff-modeline 2>&1")
      local expected = read("test/fixtures/diff-modeline.ansi")
      assert.equal(expected, output)
    end)

    it("ignores mode lines in git diffs", function()
      local output = run("test/fixtures/bin/git ./nvimpager -c " ..
			 "test/fixtures/diff-modeline 2>&1")
      local expected = read("test/fixtures/diff-modeline.ansi")
      assert.equal(expected, output)
    end)

    it("ignores mode lines in git log diffs #mac", function()
      local output = run("test/fixtures/bin/git ./nvimpager -c " ..
			 "test/fixtures/git-log 2>&1")
      local expected = read("test/fixtures/git-log.ansi")
      assert.equal(expected, output)
    end)
  end)

  describe("conceals", function()
    local function test_level(level)
      local output = run("./nvimpager -c test/fixtures/help.txt " ..
				      "-c 'set cole="..level.."'")
      local expected = read("test/fixtures/help.txt.cole"..level..".ansi")
      assert.equal(expected, output)
    end
    it("are removed at conceallevel=2", function() test_level(2) end)
    it("are hidden at conceallevel=1", function() test_level(1) end)
    it("are highlighted at conceallevel=0", function() test_level(0) end)
  end)

  describe("conceal replacements", function()
    local function test_replace(level)
      local output = run("./nvimpager -c test/fixtures/conceal.tex "..
			 "--cmd \"let g:tex_flavor='latex'\" "..
			 "-c 'set cole="..level.."'")
      local expected = read("test/fixtures/conceal.tex.cole"..level..".ansi")
      assert.equal(expected, output)
    end
    it("are replaced at conceallevel=2", function() test_replace(2) end)
    it("are replaced at conceallevel=1", function() test_replace(1) end)
    it("are highlighted at conceallevel=0", function() test_replace(0) end)
  end)

  describe("listchars", function()
    it("handle spaces, trailing spaces and eol with termguicolors", function()
      local output = run("./nvimpager -c test/fixtures/listchars1.txt " ..
			 "--cmd 'se tgc list lcs+=space:_,eol:$'")
      local expected = read("test/fixtures/listchars1.txt.24bit")
      assert.equal(expected, output)
    end)
    it("handle spaces, trailing spaces and eol with 256 colors", function()
      local output = run("./nvimpager -c test/fixtures/listchars1.txt " ..
			 "--cmd 'se list lcs+=space:_,eol:$'")
      local expected = read("test/fixtures/listchars1.txt.8bit")
      assert.equal(expected, output)
    end)
    describe("handles non breaking spaces", function()
      local expected = read("test/fixtures/nbsp.ansi")
      it("in utf8 files", function()
	local output = run("./nvimpager -c test/fixtures/nbsp.utf8.txt " ..
			   "--cmd 'se list'")
	assert.equal(expected, output)
      end)
      it("in latin1 files", function()
	local output = run("./nvimpager -c test/fixtures/nbsp.latin1.txt " ..
			   "--cmd 'se list'")
	assert.equal(expected, output)
      end)
    end)
  end)
end)

describe("pager mode", function()
  it("starts up and quits correctly #mac #appimage #ppa", function()
    run("./nvimpager -p makefile -c quit")
  end)
end)

describe("cat-exec mode", function()
  it("is selected when stdin is not a tty", function()
    local output = run("./nvimpager < README.md")
    local expected = read("README.md")
    assert.equal(expected, output)
  end)

  it("does not highlight files", function()
    local output = run("./nvimpager < test/fixtures/makefile")
    local expected = read("test/fixtures/makefile") -- NOTE: no highlight
    assert.equal(expected, output)
  end)
end)

describe("parent detection", function()
  -- Wrapper to execute some lua code in a --cmd argument.
  local function lua_with_parent(name, code)
    -- First we have to shellescape the lua code.
    code = code:gsub("'", "'\\''")
    local command = [[nvim --headless --clean --cmd 'set rtp+=.' --cmd 'lua ]]
		    ..code..[[' --cmd quit]]
    return run("test/fixtures/bin/"..name.." "..command)
  end

  it("detects git correctly #mac #appimage", function()
    local output = lua_with_parent(
      "git", "print(require('nvimpager')._testable.detect_parent_process())")
    assert.equal("git", output)
  end)

  it("detects man correctly #mac #appimage", function()
    local output = lua_with_parent(
      "man", "print(require('nvimpager')._testable.detect_parent_process())")
    assert.equal("man", output)
  end)

  it("handles git", function()
    local output = run("test/fixtures/bin/git ./nvimpager -c " ..
		       "test/fixtures/diff")
    local expected = read("test/fixtures/diff.ansi")
    assert.equal(expected, output)
  end)

  it("can pass though git colors", function()
    local output = run("test/fixtures/bin/git ./nvimpager -c " ..
		       "test/fixtures/difftastic --cmd 'lua nvimpager.git_colors=true'")
    local expected = read("test/fixtures/difftastic")
    assert.equal(expected, output)
  end)

  it("handles man #mac #nix", function()
    local output = run("test/fixtures/bin/man ./nvimpager -c " ..
		       "test/fixtures/man.cat")
    local expected = read("test/fixtures/man.ansi")
    assert.equal(expected, output)
  end)
end)

describe("init files", function()
  it("can be specified with -u", function()
    local init = os.tmpname()
    finally(function() os.remove(init) end)
    helpers.write(init, "let g:myvar = 42")
    local output = run("./nvimpager -c -- -u " .. init ..
      [[ -c 'lua io.write(vim.g.myvar, "\n")' -c qa]])
    assert.equal("42\n", output)
  end)

  local function tempdir()
    local dir = run("mktemp -d"):sub(1, -2)  -- remove the final newline
    finally(function() run("rm -r " .. dir) end)
    return dir
  end

  it("can be init.lua", function()
    local dir = tempdir()
    run("mkdir -p " .. dir .. "/nvimpager")
    helpers.write(dir .. "/nvimpager/init.lua", "vim.g.myvar = 42")
    local output = run("XDG_CONFIG_HOME=" .. dir ..
      [[ ./nvimpager -c -- -c 'lua io.write(vim.g.myvar, "\n")' -c qa]])
    assert.equal("42\n", output)
  end)

  it("can be init.vim", function()
    local dir = tempdir()
    run("mkdir -p " .. dir .. "/nvimpager")
    helpers.write(dir .. "/nvimpager/init.vim", "let myvar = 42")
    local output = run("XDG_CONFIG_HOME=" .. dir ..
      [[ ./nvimpager -c -- -c 'lua io.write(vim.g.myvar, "\n")' -c qa]])
    assert.equal("42\n", output)
  end)
end)
