local data = require "glose.core.scope.data"

local function mk_range(sl, sc, el, ec)
  return { start = { line = sl, character = sc }, ["end"] = { line = el, character = ec } }
end

describe("glose.core.scope.data", function()
  describe("cursor_in_range", function()
    local r = mk_range(2, 0, 10, 0)

    it("inside range", function()
      assert.is_true(data.cursor_in_range(5, 3, r))
    end)

    it("before start line", function()
      assert.is_false(data.cursor_in_range(1, 0, r))
    end)

    it("after end line", function()
      assert.is_false(data.cursor_in_range(11, 0, r))
    end)

    it("same start line but before column", function()
      local range = mk_range(5, 4, 10, 0)
      assert.is_false(data.cursor_in_range(5, 2, range))
    end)
  end)

  describe("find_path", function()
    it("returns nested symbol chain", function()
      local symbols = {
        {
          name = "outer",
          kind = 10,
          range = mk_range(0, 0, 20, 0),
          children = {
            {
              name = "inner",
              kind = 12,
              range = mk_range(5, 0, 15, 0),
              children = {},
            },
          },
        },
      }
      local path = data.find_path(symbols, 7, 0)
      assert.equal(2, #path)
      assert.equal("outer", path[1].name)
      assert.equal("inner", path[2].name)
    end)

    it("returns empty when cursor outside all symbols", function()
      local symbols = { { name = "x", range = mk_range(0, 0, 2, 0) } }
      assert.equal(0, #data.find_path(symbols, 100, 0))
    end)

    it("stops at leaf when no matching child", function()
      local symbols = {
        {
          name = "parent",
          range = mk_range(0, 0, 20, 0),
          children = {
            { name = "sibling", range = mk_range(1, 0, 3, 0) },
          },
        },
      }
      local path = data.find_path(symbols, 10, 0)
      assert.equal(1, #path)
      assert.equal("parent", path[1].name)
    end)
  end)

  describe("find_ending_symbols", function()
    local symbols = {
      {
        name = "outerFn",
        kind = 10,
        range = mk_range(0, 0, 30, 0),
        children = {
          { name = "innerMethod", kind = 12, range = mk_range(5, 0, 15, 0) },
          { name = "literalNumber", kind = 17, range = mk_range(20, 0, 20, 4) },
        },
      },
    }

    it("filters by scope_kinds (ignores non-scope kinds like Number=17)", function()
      local results = data.find_ending_symbols(symbols, 10, 100, "off_screen", 0)
      local names = {}
      for _, r in ipairs(results) do
        names[r.symbol.name] = true
      end
      assert.is_true(names["outerFn"])
      assert.is_true(names["innerMethod"])
      assert.is_nil(names["literalNumber"])
    end)

    it("visible_mode='hover' only shows on cursor line", function()
      local results = data.find_ending_symbols(symbols, 0, 100, "hover", 15)
      assert.equal(1, #results)
      assert.equal("innerMethod", results[1].symbol.name)
    end)

    it("visible_mode='off_screen' only shows blocks that start above viewport", function()
      local results = data.find_ending_symbols(symbols, 10, 100, "off_screen", 0)
      assert.equal(2, #results)
    end)

    it("visible_mode='always' combines hover and off_screen", function()
      local results = data.find_ending_symbols(symbols, 10, 100, "always", 15)
      assert.equal(2, #results)
    end)

    it("skips end_lines outside visible window", function()
      local results = data.find_ending_symbols(symbols, 0, 10, "always", 15)
      local names = {}
      for _, r in ipairs(results) do
        names[r.symbol.name] = true
      end
      assert.is_nil(names["outerFn"])
    end)
  end)

  describe("format_path", function()
    it("returns empty table for empty path", function()
      assert.same({}, data.format_path({}, " > ", 0, "..."))
    end)

    it("places separator between items", function()
      local path = {
        { name = "A", kind = 10 },
        { name = "B", kind = 12 },
        { name = "C", kind = 12 },
      }
      local chunks = data.format_path(path, " > ", 0, "...")
      assert.equal(5, #chunks)
      assert.equal(" > ", chunks[2][1])
      assert.equal("GloseScopeSeparator", chunks[2][2])
      assert.equal(" > ", chunks[4][1])
    end)

    it("prepends indicator when depth exceeds limit", function()
      local path = {
        { name = "A", kind = 10 },
        { name = "B", kind = 12 },
        { name = "C", kind = 12 },
        { name = "D", kind = 12 },
      }
      local chunks = data.format_path(path, " > ", 2, "...")
      assert.equal("...", chunks[1][1])
      assert.equal("GloseScopeSeparator", chunks[1][2])
    end)

    it("uses GloseScopeKind_<kind> hl for symbol chunks", function()
      local path = { { name = "fn", kind = 10 } }
      local chunks = data.format_path(path, " > ", 0, "...")
      assert.equal("GloseScopeKind_10", chunks[1][2])
    end)
  end)

  describe("kind helpers", function()
    it("kind_name returns mapped name", function()
      assert.equal("Function", data.kind_name(10))
      assert.equal("Class", data.kind_name(5))
    end)

    it("kind_name returns Unknown for unknown kind", function()
      assert.equal("Unknown", data.kind_name(999))
    end)
  end)
end)
