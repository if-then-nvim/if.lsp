local function reset_iflsp()
  for name in pairs(package.loaded) do
    if name:match "^if%.lsp" then
      package.loaded[name] = nil
    end
  end
end

describe("if.lsp.glyph", function()
  before_each(reset_iflsp)

  it("returns defaults when setup is not called", function()
    local glyph = require "if.lsp.glyph"
    assert.is_table(glyph.get().numeric)
    assert.equal("󰎤", glyph.get().numeric[1])
  end)

  it("merges user opts over defaults for dict-like tables", function()
    local glyph = require "if.lsp.glyph"
    glyph.setup { tag = { param = "P" } }
    assert.equal("P", glyph.get().tag.param)
    assert.equal("󰌑", glyph.get().tag.returns)
  end)

  it("exposes top-level fields via __index metamethod", function()
    local glyph = require "if.lsp.glyph"
    glyph.setup {}
    assert.is_table(glyph.tag)
    assert.is_table(glyph.inlay)
    assert.is_table(glyph.severity)
  end)

  it("user opts persist across multiple get() calls", function()
    local glyph = require "if.lsp.glyph"
    glyph.setup { tag = { custom = "" } }
    assert.equal("", glyph.get().tag.custom)
    assert.equal("", glyph.tag.custom)
  end)

  it("setup with nil uses defaults", function()
    local glyph = require "if.lsp.glyph"
    glyph.setup(nil)
    assert.is_not_nil(glyph.get().numeric)
  end)
end)
