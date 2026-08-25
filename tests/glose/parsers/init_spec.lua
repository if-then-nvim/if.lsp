local function reset_glose()
  for name in pairs(package.loaded) do
    if name:match "^glose" then
      package.loaded[name] = nil
    end
  end
end

describe("glose.parsers", function()
  before_each(function()
    reset_glose()
    require("glose.glyph").setup {}
    require("glose.config").setup {}
  end)

  describe("get_all_tags", function()
    it("includes builtin jsdoc tags", function()
      local tags = require("glose.parsers").get_all_tags()
      assert.is_not_nil(tags["@param"])
      assert.is_not_nil(tags["@returns?"])
    end)

    it("includes builtin doxygen tags", function()
      local tags = require("glose.parsers").get_all_tags()
      assert.is_not_nil(tags["\\param"])
      assert.is_not_nil(tags["\\brief"])
    end)

    it("includes builtin python tags", function()
      local tags = require("glose.parsers").get_all_tags()
      assert.is_not_nil(tags["Args:"])
      assert.is_not_nil(tags["Returns:"])
    end)

    it("each tag has icon and hl keys", function()
      local tags = require("glose.parsers").get_all_tags()
      for pattern, def in pairs(tags) do
        assert.is_not_nil(def.icon, "missing icon for " .. pattern)
        assert.is_not_nil(def.hl, "missing hl for " .. pattern)
      end
    end)
  end)

  describe("register", function()
    it("merges user-registered parser tags", function()
      local parsers = require "glose.parsers"
      parsers.register("custom", {
        ["@mytag"] = { icon = "", hl = "Custom" },
      })
      local tags = parsers.get_all_tags()
      assert.equal("Custom", tags["@mytag"].hl)
    end)

    it("user-registered tag overrides builtin", function()
      local parsers = require "glose.parsers"
      parsers.register("override", {
        ["@param"] = { icon = "!", hl = "Overridden" },
      })
      local tags = parsers.get_all_tags()
      assert.equal("Overridden", tags["@param"].hl)
    end)
  end)

  describe("config.parsers has highest precedence", function()
    it("overrides both builtin and registered tags", function()
      local parsers = require "glose.parsers"
      parsers.register("reg", { ["@param"] = { icon = "R", hl = "Reg" } })
      require("glose.config").setup {
        parsers = { ["@param"] = { icon = "C", hl = "FromConfig" } },
      }
      local tags = parsers.get_all_tags()
      assert.equal("FromConfig", tags["@param"].hl)
    end)
  end)
end)
