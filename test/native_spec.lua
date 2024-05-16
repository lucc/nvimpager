--- Wrapper for test cases written with neovim's native assert funtions.
--- @module test.native_spec

-- Busted defines these objects but luacheck doesn't know them.  So we
-- redefine them and tell luacheck to ignore it.
local describe, it, assert = describe, it, assert  -- luacheck: ignore

local helpers = require("test/helpers")

--- Run a test file in nvimpager's pager mode
---
--- The test case will start nvimpager in pager mode and source the given file.
--- The messages from v:errors will be collected from within nvimpager and
--- returned by this function (as a single string)
local function run_test_file(filename, extra_args)
  extra_args = extra_args or ""
  -- create an output file to transport the errors from within neovim to
  -- busted (it is complicated to write to stdout or stderr from within neovim
  -- and catch that from the outside)
  local outfile = os.tmpname()
  local output

  -- We write a marker to the output file in order to detect if the
  -- nvimpager command below really writes to the file.  If it does write to
  -- the file our marker should be overwritten.
  local handle, err1 = io.open(outfile, "w")
  if handle == nil then
    error(err1)
  end
  handle:write("This should be overwritten")
  handle:close()

  -- run the actual test in protected mode in order to clean up the temp file
  -- if anything fails
  local status, err2 = pcall(function()
    -- Run the given test file in nvimpager and write all errors from the
    -- assert_* functions into outfile.
    helpers.run(
      -- define an environment variable to hold the output file name
      "OUTFILE='" .. outfile:gsub("'", [['\'']]) .. "' " ..
      -- run nvimpager in pager mode
      "./nvimpager -p -- " ..
      -- source the given lua test file
      "-S " .. filename ..
      -- write all errors reported by assert_* functions to the output file
      " -c 'call writefile(v:errors, $OUTFILE)' " ..
      -- force quit nvimpager
      "-c 'quitall!' " ..
      extra_args
    )
  end)

  if status then
    output = helpers.read(outfile)
  end

  -- clean up the temp file
  os.remove(outfile)

  -- return the contents of the output file or re-through the error
  if status then
    return output
  else
    error(err2)
  end
end

local function test(title, filename, extra_args)
  it(title, function()
    assert.equal("", run_test_file(filename, extra_args))
  end)
end

describe("native", function()

  -- tests for the custom test framework of this file
  describe("test framework", function()
    it("reports assert_* failures from neovim", function()
      local output = run_test_file("test/meta_test.lua")
      assert.not_nil(output:find("this is an error"))
    end)
    it("detects aborted test scripts", function()
      local output = run_test_file("test/abort_test.lua")
      assert.equal("This should be overwritten", output)
    end)
  end)

  describe("pager mode", function()
    test("loads the nvimpager table", "test/first_test.lua")
    test("detects diffs correctly", "test/diff_test.lua")
    test("maps can be deactivated", "test/no_map_test.lua",
      "--cmd 'lua nvimpager.maps = false'")
  end)

end)
