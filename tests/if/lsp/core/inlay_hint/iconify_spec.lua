local function reset_iflsp()
  for name in pairs(package.loaded) do
    if name:match "^if%.lsp" then
      package.loaded[name] = nil
    end
  end
end

describe("if.lsp.core.inlay_hint.iconify", function()
  before_each(function()
    reset_iflsp()
    require("if.lsp.glyph").setup {}
  end)

  describe("split_union", function()
    local iconify

    before_each(function()
      iconify = require "if.lsp.core.inlay_hint.iconify"
    end)

    it("splits simple pipe-separated types", function()
      local parts = iconify.split_union "string | number | boolean"
      assert.equal(3, #parts)
      assert.equal("string", parts[1])
      assert.equal("number", parts[2])
      assert.equal("boolean", parts[3])
    end)

    it("ignores pipes inside angle brackets", function()
      local parts = iconify.split_union "Array<string | number> | null"
      assert.equal(2, #parts)
      assert.equal("Array<string | number>", parts[1])
      assert.equal("null", parts[2])
    end)

    it("ignores pipes inside braces", function()
      local parts = iconify.split_union "{ a: string | number } | null"
      assert.equal(2, #parts)
    end)

    it("returns single element when no pipe", function()
      local parts = iconify.split_union "string"
      assert.equal(1, #parts)
      assert.equal("string", parts[1])
    end)

    it("handles empty string", function()
      local parts = iconify.split_union ""
      assert.equal(0, #parts)
    end)

    it("ignores pipes inside parentheses", function()
      local parts = iconify.split_union "(a | b) | c"
      assert.equal(2, #parts)
      assert.equal("(a | b)", parts[1])
      assert.equal("c", parts[2])
    end)
  end)

  describe("detect_type", function()
    local iconify

    before_each(function()
      iconify = require "if.lsp.core.inlay_hint.iconify"
    end)

    it("detects number kind", function()
      local _, kind = iconify.detect_type "number"
      assert.equal("number", kind)
    end)

    it("detects rust integer kind as number", function()
      local _, kind = iconify.detect_type "i32"
      assert.equal("number", kind)
    end)

    it("detects string kind", function()
      local _, kind = iconify.detect_type "string"
      assert.equal("string", kind)
    end)

    it("detects boolean kind", function()
      local _, kind = iconify.detect_type "bool"
      assert.equal("boolean", kind)
    end)

    it("detects object kind", function()
      local _, kind = iconify.detect_type "{ a: number }"
      assert.equal("object", kind)
    end)

    it("detects function kind from arrow syntax", function()
      local _, kind = iconify.detect_type "(x: number) => string"
      assert.equal("function", kind)
    end)

    it("returns nil for unknown type", function()
      local _, kind = iconify.detect_type "SomeCustomType"
      assert.is_nil(kind)
    end)

    it("strips leading colon", function()
      local _, kind = iconify.detect_type ": string"
      assert.equal("string", kind)
    end)
  end)
end)
