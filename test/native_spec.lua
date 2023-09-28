-- Wrapper for test cases written with neovim's native assert funtions.

-- Busted defines these objects but luacheck doesn't know them.  So we
-- redefine them and tell luacheck to ignore it.
local describe, it, assert = describe, it, assert  -- luacheck: ignore

local helpers = require("test/helpers")
local env_var = "NVIMPAGER_NATIVE_OUT_FILE"

local function run_test_file(filename, outfile)
  helpers.run(
    env_var .. "=" .. outfile ..
    " ./nvimpager -p -- -c 'so %' "..
    "-c 'cal writefile(v:errors, $" ..
    env_var .. ")' -c 'qa!' " .. filename
  )
  return helpers.read(outfile)
end
local function assert_test_file(filename, outfile)
  local output = run_test_file(filename, outfile)
  assert.equal("", output)
end

describe("native", function()

  -- tests for the custom test framework of this file
  describe("test framework", function()
    it("reports assert_* failures from neovim", function()
      local out = os.tmpname()
      finally(function() os.remove(out) end)
      local output = run_test_file("test/meta_test.lua", out)
      assert.not_nil(output:find("this is an error"))
    end)
  end)

  describe("pager mode", function()

    it("loads the nvimpager table", function()
      local out = os.tmpname()
      finally(function() os.remove(out) end)
      assert_test_file("test/first_test.lua", out)
    end)

  end)

end)
