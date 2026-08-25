local function reset_glose()
  for name in pairs(package.loaded) do
    if name:match "^glose" then
      package.loaded[name] = nil
    end
  end
end

describe("glose.core.scope.treesitter", function()
  describe("keyword_icon", function()
    it("returns icon from default glyph table for 'if'", function()
      reset_glose()
      require("glose.glyph").setup {}
      local ts = require "glose.core.scope.treesitter"
      assert.is_string(ts.keyword_icon "if")
    end)

    it("returns overridden icon when user provides scope_keyword", function()
      reset_glose()
      require("glose.glyph").setup { scope_keyword = { ["if"] = "IF" } }
      local ts = require "glose.core.scope.treesitter"
      assert.equal("IF", ts.keyword_icon "if")
    end)

    it("returns nil for unknown keyword", function()
      reset_glose()
      require("glose.glyph").setup {}
      local ts = require "glose.core.scope.treesitter"
      assert.is_nil(ts.keyword_icon "nonexistent_keyword_xyz")
    end)
  end)
end)
