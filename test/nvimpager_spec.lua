-- Busted tests for nvimpager

-- Busted defines these objects but luacheck doesn't know them.  So we
-- redefine them and tell luacheck to ignore it.
local describe, it, assert, pending = describe, it, assert, pending  -- luacheck: ignore

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
