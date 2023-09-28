-- Wrapper for test cases written with neovim's native assert funtions.

-- Busted defines these objects but luacheck doesn't know them.  So we
-- redefine them and tell luacheck to ignore it.
local describe, it, assert = describe, it, assert  -- luacheck: ignore

local helpers = require("test/helpers")
local env_var = "NVIMPAGER_NATIVE_OUT_FILE"

describe("native", function()

  describe("pager mode", function()

    it("loads the nvimpager table", function()
      local out = os.tmpname()
      finally(function() os.remove(out) end)
      helpers.run(
	env_var .. "=" .. out ..
	" ./nvimpager -p -- -c 'so %' "..
	"-c 'cal writefile(v:errors, $" ..
	env_var .. ")' -c 'qa!' test/first_test.lua"
      )
      local output = helpers.read(out)
      assert.equal("", output)
    end)

  end)

end)
