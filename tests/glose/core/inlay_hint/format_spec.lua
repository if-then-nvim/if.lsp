local function reset_glose()
  for name in pairs(package.loaded) do
    if name:match "^glose" then
      package.loaded[name] = nil
    end
  end
end

describe("glose.core.inlay_hint.format", function()
  local format

  before_each(function()
    reset_glose()
    require("glose.glyph").setup {}
    format = require "glose.core.inlay_hint.format"
  end)

  describe("parse_object_fields", function()
    it("parses simple object", function()
      local fields = format.parse_object_fields "{ a: number; b: string }"
      assert.equal(2, #fields)
      assert.equal("a", fields[1].name)
      assert.equal("number", fields[1].type)
      assert.equal("b", fields[2].name)
      assert.equal("string", fields[2].type)
    end)

    it("accepts comma separator", function()
      local fields = format.parse_object_fields "{ a: number, b: string }"
      assert.equal(2, #fields)
    end)

    it("handles optional fields", function()
      local fields = format.parse_object_fields "{ a?: number }"
      assert.equal(1, #fields)
      assert.equal("a", fields[1].name)
      assert.equal("number", fields[1].type)
    end)

    it("does not split inside nested generics", function()
      local fields = format.parse_object_fields "{ a: Map<string, number>; b: string }"
      assert.equal(2, #fields)
      assert.equal("Map<string, number>", fields[1].type)
    end)

    it("does not split inside nested braces", function()
      local fields = format.parse_object_fields "{ a: { x: number; y: number }; b: string }"
      assert.equal(2, #fields)
      assert.equal("{ x: number; y: number }", fields[1].type)
    end)

    it("returns nil for empty object", function()
      assert.is_nil(format.parse_object_fields "{}")
      assert.is_nil(format.parse_object_fields "{ }")
    end)

    it("returns nil for non-object strings", function()
      assert.is_nil(format.parse_object_fields "string")
      assert.is_nil(format.parse_object_fields "Array<number>")
    end)
  end)

  describe("parse_generic_params", function()
    it("parses simple single-param generic", function()
      local base, params = format.parse_generic_params "Array<string>"
      assert.equal("Array", base)
      assert.equal(1, #params)
      assert.equal("string", params[1])
    end)

    it("parses multi-param generic", function()
      local base, params = format.parse_generic_params "Map<string, number>"
      assert.equal("Map", base)
      assert.equal(2, #params)
      assert.equal("string", params[1])
      assert.equal("number", params[2])
    end)

    it("does not split inside nested generics", function()
      local base, params = format.parse_generic_params "Foo<Bar<string, number>, baz>"
      assert.equal("Foo", base)
      assert.equal(2, #params)
      assert.equal("Bar<string, number>", params[1])
      assert.equal("baz", params[2])
    end)

    it("returns nil base for non-generic input", function()
      local base, params = format.parse_generic_params "string"
      assert.is_nil(base)
      assert.is_nil(params)
    end)
  end)
end)
