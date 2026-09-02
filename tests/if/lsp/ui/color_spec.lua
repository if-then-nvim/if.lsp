local color = require "if.lsp.ui.color"

describe("if.lsp.ui.color", function()
  describe("hex_to_rgb", function()
    it("parses #RRGGBB form", function()
      local r, g, b = color.hex_to_rgb "#ff8040"
      assert.equal(255, r)
      assert.equal(128, g)
      assert.equal(64, b)
    end)

    it("parses RRGGBB without hash", function()
      local r, g, b = color.hex_to_rgb "000000"
      assert.equal(0, r)
      assert.equal(0, g)
      assert.equal(0, b)
    end)
  end)

  describe("rgb_to_hex", function()
    it("formats lowercase #rrggbb", function()
      assert.equal("#ff8040", color.rgb_to_hex(255, 128, 64))
    end)

    it("zero pads single hex digits", function()
      assert.equal("#010203", color.rgb_to_hex(1, 2, 3))
    end)
  end)

  describe("blend", function()
    it("alpha=1 returns fg", function()
      assert.equal("#ff0000", color.blend("#ff0000", "#000000", 1))
    end)

    it("alpha=0 returns bg", function()
      assert.equal("#000000", color.blend("#ff0000", "#000000", 0))
    end)

    it("alpha=0.5 midpoint of white and black is gray", function()
      assert.equal("#808080", color.blend("#ffffff", "#000000", 0.5))
    end)

    it("round-trips through rgb precision", function()
      local mixed = color.blend("#112233", "#ffeedd", 0.25)
      local r, g, b = color.hex_to_rgb(mixed)
      assert.equal(r, math.floor(0x11 * 0.25 + 0xff * 0.75 + 0.5))
      assert.equal(g, math.floor(0x22 * 0.25 + 0xee * 0.75 + 0.5))
      assert.equal(b, math.floor(0x33 * 0.25 + 0xdd * 0.75 + 0.5))
    end)
  end)

  describe("get_hl_color", function()
    it("returns hex string for set highlight", function()
      vim.api.nvim_set_hl(0, "IfLspColorTestA", { fg = "#abcdef" })
      assert.equal("#abcdef", color.get_hl_color("IfLspColorTestA", "fg"))
    end)

    it("returns nil when attribute missing", function()
      vim.api.nvim_set_hl(0, "IfLspColorTestEmpty", {})
      assert.is_nil(color.get_hl_color("IfLspColorTestEmpty", "fg"))
    end)

    it("returns hex string for bg attr", function()
      vim.api.nvim_set_hl(0, "IfLspColorTestB", { bg = "#123456" })
      assert.equal("#123456", color.get_hl_color("IfLspColorTestB", "bg"))
    end)
  end)
end)
