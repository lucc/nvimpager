-- Busted tests for nvimpager

-- Busted defines these objects but luacheck doesn't know them.  So we
-- redefine them and tell luacheck to ignore it.
local describe, it, assert, mock, setup, before_each =
      describe, it, assert, mock, setup, before_each  -- luacheck: ignore

local helpers = require("test/helpers")
local run, read = helpers.run, helpers.read

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
    local file = io.open(filename, "w")
    file:write(script)
    file:close()
    local output = run("bash " .. filename)
    os.remove(filename)
    return output
  end

  it("selects cat mode for small files", function()
    local output = bash('./nvimpager test/fixtures/makefile')
    -- $mode might still be auto so we check the generated command line.
    local args = output:match("\nargs1[^\n]*\n")
    assert.truthy(args:match('--headless'))
  end)

  it("auto mode selects pager mode for big inputs", function()
    local output = bash('./nvimpager ./README.md ./nvimpager')
    -- $mode might still be auto so we check the generated command line.
    local args = output:match("\nargs1[^\n]*\n")
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

    it("ignores mode lines in git log diffs #osx_pending", function()
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
  it("starts up and quits correctly", function()
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

describe("backend:", function()
  it("runtimepath doesn't include nvim's user dirs", function()
    local cmd = [[RUNTIME=special-test-value nvim --clean --headless ]]..
    -- We have to end the --cmd after the lua command as it will eat the next
    -- lines otherwise.
    [[--cmd '
      set runtimepath+=.
      lua require("nvimpager").stage1()' ]]..
    [[--cmd '
      let rtp = split(&rtp, ",")
      call assert_equal(0, index(rtp, $RUNTIME), "$RUNTIME should be in &rtp")
      call assert_equal(-1, index(rtp, stdpath("config")), "default config path should not be in &rtp")
      call assert_equal(-1, index(rtp, stdpath("data")."/site"), "default site path should not be in &rtp")
      echo join(v:errors, "\n") . "\n"
      quit' 2>&1]]
    local output = run(cmd)
    assert.equal('\r\n', output)
  end)

  it("plugin manifest doesn't contain nvim's value", function()
    -- Nvim writes this message to stderr so we have to redirect this.
    local output = run("./nvimpager -c -- README.md " ..
                       "-c 'echo $NVIM_RPLUGIN_MANIFEST' -c quit 2>&1")
    assert.equal(helpers.datadir..'/nvimpager/rplugin.vim', output)
  end)
end)

describe("lua functions", function()
  local nvimpager

  setup(function() nvimpager = helpers.load_nvimpager("init") end)

  describe("split_rgb_number", function()
    local split_rgb_number = require("nvimpager/cat").split_rgb_number
    it("handles numbers from 0 to 16777215", function()
      local r, g, b = split_rgb_number(0x000000)
      assert.equal(0, r)
      assert.equal(0, g)
      assert.equal(0, b)
      r, g, b = split_rgb_number(0xFFFFFF)
      assert.equal(255, r)
      assert.equal(255, g)
      assert.equal(255, b)
    end)

    it("correctly splits rgb values", function()
      local r, g, b = split_rgb_number(0x55AACC)
      assert.equal(0x55, r)
      assert.equal(0xAA, g)
      assert.equal(0xCC, b)
    end)
  end)

  describe("group2ansi", function()
    it("calls nvim_get_hl_by_id with and without termguicolors", function()
      for _, termguicolors in pairs({true, false}) do
	local api = {
	  nvim_get_hl_by_id = function() return {} end,
	  nvim_get_option = function() return termguicolors end,
	  nvim_call_function = function() return 0 end,
	}
	local m = mock(api)
	local cat = helpers.load_nvimpager("cat", api)
	cat.init()
	local escape = cat.group2ansi(100)
	assert.stub(m.nvim_get_hl_by_id).was.called_with(100, termguicolors)
	assert.equal('\27[0m', escape)
      end
    end)
  end)

  describe("color2escape_24bit", function()
    local color2escape_24bit = require("nvimpager/cat").color2escape_24bit
    it("creates foreground escape sequences", function()
      local e = color2escape_24bit(0xaabbcc, true)
      assert.equal('38;2;170;187;204', e)
    end)

    it("creates background escape sequences", function()
      local e = color2escape_24bit(0xccbbaa, false)
      assert.equal('48;2;204;187;170', e)
    end)
  end)

  describe("color2escape_8bit", function()
    local color2escape_8bit = require("nvimpager/cat").color2escape_8bit
    it("creates 8 colors foreground escaape sequences", function()
      local e = color2escape_8bit(5, true)
      assert.equal('35', e)
    end)

    it("creates 8 colors background escaape sequences", function()
      local e = color2escape_8bit(7, false)
      assert.equal('47', e)
    end)

    it("creates 16 colors foreground escaape sequences", function()
      local e = color2escape_8bit(5 + 8, true)
      assert.equal('95', e)
    end)

    it("creates 16 colors background escaape sequences", function()
      local e = color2escape_8bit(7 + 8, false)
      assert.equal('107', e)
    end)

    it("creates foreground escape sequences", function()
      local e = color2escape_8bit(0xaa, true)
      assert.equal('38;5;170', e)
    end)

    it("creates background escape sequences", function()
      local e = color2escape_8bit(0xbb, false)
      assert.equal('48;5;187', e)
    end)
  end)

  describe("hexformat_rgb_numbers", function()
    local ansi2highlight = require("nvimpager/ansi2highlight")
    local function test(r, g, b, expected)
      local actual = ansi2highlight.hexformat_rgb_numbers(r, g, b)
      assert.equal(expected, actual)
    end
    it("small numbers", function() test(1, 2, 3, '#010203') end)
    it("big numbers", function() test(100, 200, 150, '#64c896') end)
    it("0,0,0 is black", function() test(0, 0, 0, '#000000') end)
    it("255,255,255 is white", function() test(255, 255, 255, '#ffffff') end)
  end)

  describe("split_predifined_terminal_color", function()
    local ansi2highlight = require("nvimpager/ansi2highlight")
    local function test(col, exp_r, exp_g, exp_b)
      local r, g, b = ansi2highlight.split_predifined_terminal_color(col)
      assert.equal(exp_r, r)
      assert.equal(exp_g, g)
      assert.equal(exp_b, b)
    end
    it("handles 0 as black", function() test(0, 0, 0, 0) end)
    it("handles 215 as white", function() test(215, 255, 255, 255) end)
    it("handles 137 as something", function() test(137, 175, 215, 255) end)
  end)

  describe("replace_prefix", function()
    it("can replace a simple prefix in a table of strings", function()
      local t = nvimpager._testable.replace_prefix({"foo", "bar", "baz"},
	"b", "XXX")
      assert.same({"foo", "XXXar", "XXXaz"}, t)
    end)

    it("can replace strings with slashes", function()
      local t = nvimpager._testable.replace_prefix(
	{"/a/b/c", "/a/b/d", "/g/e/f"}, "/a/b", "/x/y")
      assert.same({"/x/y/c", "/x/y/d", "/g/e/f"}, t)
    end)

    it("only replaces at the start of the items", function()
      local t = nvimpager._testable.replace_prefix(
	{"abc", "cab"}, "ab", "XXX")
      assert.same({"XXXc", "cab"}, t)
    end)

    it("can replace lua pattern chars",  function()
      local actual = nvimpager._testable.replace_prefix(
	  {"a-b-c"}, "a-b", "XXX")
      assert.same({"XXX-c"}, actual)
    end)
  end)

  describe("tokenize", function()
    local ansi2highlight = require("nvimpager/ansi2highlight")
    local function test(input, expected)
      local result = {}
      for token, c1, c2, c3 in ansi2highlight.tokenize(input) do
	table.insert(result, {token, c1, c2, c3})
      end
      assert.same(expected, result)
    end
    it("treats empty strings as a single empty token", function()
      test("", {{""}})
    end)
    it("simple numbers", function()
      test("42", {{"42"}})
    end)
    it("trailing semicolons as extra empty token", function()
      test("42;", {{"42"}, {""}})
    end)
    it("leading semicolons as extra empty token", function()
      test(";42", {{""}, {"42"}})
    end)
    it("splits simple numbers at semicolons", function()
      test("1;2", {{"1"}, {"2"}})
    end)
    it("recognizes special 8 bit color sequences", function()
      local input = "38;5;16"
      test(input, {{"foreground", "16"}})
    end)
    it("recognizes next token after 8 bit color sequences", function()
      test("38;5;22;42", {{"foreground", "22"}, {"42"}})
    end)
    it("recognizes special 24 bit color sequences", function()
      local input = "38;2;16;17;42"
      test(input, {{"foreground", "16", "17", "42"}})
    end)
    it("recognizes next token after 24 bit color sequences", function()
      test("48;2;101;102;103;99", {{"background", "101", "102", "103"},
				   {"99"}})
    end)
    it("two semicolon between proper tokens create an empty token", function()
      test("12;;13", {{"12"}, {""}, {"13"}})
    end)

    -- These create one empty token less than what might be expected but that
    -- is not a problem because empty token reset all attributes and that is
    -- an idempotent operation.
    describe("sequences of semicolons:", function()
      it("one single semicolon => one empty token", function()
	test(";", {{""}})
      end)
      it("two semicolons => two empty tokens", function()
	test(";;", {{""}, {""}})
      end)
    end)
  end)

  describe("ansi parser", function()
    local state
    local ansi2highlight = require("nvimpager/ansi2highlight")
    setup(function() state = ansi2highlight.state end)
    before_each(function() state:clear() end)

    it("clears all attributes on 0", function()
      state.foreground = "foo"
      state.background = "bar"
      state.strikethrough = true
      state:parse("0")
      for key, val in pairs(state) do
	if type(val) == "string" then assert.equal("", val)
	elseif type(val) == "boolean" then assert.is_false(val)
	end
      end
    end)

    describe("can parse special terminal attributes:", function()
      local attrs = {[1]="bold", [3]="italic", [4]="underline", [7]="reverse",
		     [8]="conceal", [9]="strikethrough"}
      for num, name in pairs(attrs) do
	it(""..num.." is "..name, function()
	state:parse(""..num) assert.is_true(state[name])
	end)
      end
    end)

    local colors = {[0]="black", [1]="red", [2]="green", [3]="yellow",
		    [4]="blue", [5]="magenta", [6]="cyan", [7]="lightgray"}
    describe("can parse foreground colors:", function()
      for num, name in pairs(colors) do
	it("3"..num.." is "..name, function()
	  state:parse("3"..num)
	  assert.equal(name, state.foreground)
	  assert.equal(num, state.ctermfg)
	end)
      end
    end)
    describe("can parse background colors:", function()
      for num, name in pairs(colors) do
	it("4"..num.." is "..name, function()
	  state:parse("4"..num)
	  assert.equal(name, state.background)
	  assert.equal(num, state.ctermbg)
	end)
      end
    end)
    it("can parse color combinations", function()
      state:parse("33;44")
      assert.equal("yellow", state.foreground)
      assert.equal(3, state.ctermfg)
      assert.equal("blue", state.background)
      assert.equal(4, state.ctermbg)
    end)
    it("parses sequences that partly override themself", function()
      state:parse("35;3;36")
      assert.equal("cyan", state.foreground)
      assert.equal(6, state.ctermfg)
      assert.is_true(state.italic)
    end)
    it("can turn off foreground colors", function()
      state:parse("37;45;39")
      assert.equal("", state.foreground)
      assert.equal("", state.ctermfg)
      assert.equal("magenta", state.background)
      assert.equal(5, state.ctermbg)
    end)
    it("can turn off background colors", function()
      state:parse("47;35;49")
      assert.equal("magenta", state.foreground)
      assert.equal(5, state.ctermfg)
      assert.equal("", state.background)
      assert.equal("", state.ctermbg)
    end)
    it("can turn off selected terminal attributes", function()
      state:parse("3;7;23")
      assert.is_false(state.italic)
      assert.is_true(state.reverse)
    end)

    describe("parses 24 bit sequences", function()
      it("parses simple 24 bit foreground colors", function()
	state:parse("38;2;1;2;3")
	assert.equal("#010203", state.foreground)
      end)
      it("parses 24 bit foreground colors", function()
	state:parse("38;2;100;200;250")
	assert.equal("#64c8fa", state.foreground)
      end)
      it("parses simple 24 bit background colors", function()
	state:parse("48;2;20;30;40")
	assert.equal("#141e28", state.background)
      end)
    end)

    describe("parse 256 colors", function()
      it("parses pallet terminal colors (fg)", function()
	state:parse("38;5;4")
	assert.equal("blue", state.foreground)
	assert.equal(4, state.ctermfg)
      end)
      it("parses pallet terminal colors (bg)", function()
	state:parse("48;5;5")
	assert.equal("magenta", state.background)
	assert.equal(5, state.ctermbg)
      end)
      it("parses high colors (fg)", function()
	state:parse("38;5;10")
	assert.equal("lightgreen", state.foreground)
	assert.equal(10, state.ctermfg)
      end)
      it("parses high colors (bg)", function()
	state:parse("48;5;11")
	assert.equal("lightyellow", state.background)
	assert.equal(11, state.ctermbg)
      end)
      it("parses color cube colors (fg)", function()
	state:parse("38;5;17")
	assert.equal("#00005f", state.foreground)
	assert.equal(17, state.ctermfg)
      end)
      it("parses color cube colors (bg)", function()
	state:parse("48;5;230")
	assert.equal("#ffffd7", state.background)
	assert.equal(230, state.ctermbg)
      end)
      it("parses grayscale ramp colors (fg)", function()
	state:parse("38;5;240")
	assert.equal("#585858", state.foreground)
	assert.equal(240, state.ctermfg)
      end)
      it("parses grayscale ramp colors (bg)", function()
	state:parse("48;5;250")
	assert.equal("#bcbcbc", state.background)
	assert.equal(250, state.ctermbg)
      end)
    end)

    describe("parse8bit", function()
      it("parses pallet terminal colors (fg)", function()
	state:parse8bit("foreground", "4")
	assert.equal("blue", state.foreground)
      end)
      it("parses pallet terminal colors (bg)", function()
	state:parse8bit("background", "5")
	assert.equal("magenta", state.background)
      end)
      it("parses high colors (fg)", function()
	state:parse8bit("foreground", "10")
	assert.equal("lightgreen", state.foreground)
      end)
      it("parses high colors (bg)", function()
	state:parse8bit("background", "11")
	assert.equal("lightyellow", state.background)
      end)
      it("parses color cube colors (fg)", function()
	state:parse8bit("foreground", "17")
	assert.equal("#00005f", state.foreground)
      end)
      it("parses color cube colors (bg)", function()
	state:parse8bit("background", "230")
	assert.equal("#ffffd7", state.background)
      end)
      it("parses grayscale ramp colors (fg)", function()
	state:parse8bit("foreground", "240")
	assert.equal("#585858", state.foreground)
      end)
      it("parses grayscale ramp colors (bg)", function()
	state:parse8bit("background", "250")
	assert.equal("#bcbcbc", state.background)
      end)
    end)
  end)

  describe("detect_man_page_helper", function()
    it("detects lines with each char overwritten by itself", function()
      local line = "N\bNA\bAM\bME\bE"
      assert.truthy(nvimpager._testable.detect_man_page_helper(line))
    end)
    it("works with leading whitespace", function()
      local line = "    N\bNA\bAM\bME\bE"
      assert.truthy(nvimpager._testable.detect_man_page_helper(line))
    end)
    it("works for non captial letters", function()
      local line = "N\bNa\bam\bme\be"
      assert.truthy(nvimpager._testable.detect_man_page_helper(line))
    end)
    it("fails if some chars are not overwritten", function()
      local line = "N\bNA\bAM\bME"
      assert.falsy(nvimpager._testable.detect_man_page_helper(line))
    end)
    it("detects lines with underscores overwritten by anything", function()
      local line = "_\bI_\bn_\bi_\bt_\bi_\ba_\bl_\bi_\bz_\ba_\bt_\bi_\bo_\bn"
      assert.truthy(nvimpager._testable.detect_man_page_helper(line))
    end)
    it("does not accept an empty line", function()
      assert.falsy(nvimpager._testable.detect_man_page_helper(""))
    end)
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

  it("detects git correctly #osx_pending", function()
    local output = lua_with_parent(
      "git", "print(require('nvimpager')._testable.detect_parent_process())")
    assert.equal("git", output)
  end)

  it("detects man correctly #osx_pending", function()
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

  it("handles man #osx_pending", function()
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

  it("can not coexist (.lua and .vim)", function()
    local dir = tempdir()
    local conf = dir .. "/nvimpager"
    run("mkdir -p " .. conf)
    helpers.write(conf .. "/init.lua", "vim.g.myvar = 41")
    helpers.write(conf .. "/init.vim", "let myvar = 43")
    local output = run("XDG_CONFIG_HOME=" .. dir ..
      [[ ./nvimpager -c -- -c 'lua io.write(vim.g.myvar, "\n")' -c qa;
      test $? -eq 2]])
    local expected = "Conflicting configs: " .. conf .. "/init.lua " ..
      conf .. "/init.vim\n"
    assert.equal(expected, output)
  end)
end)
