local function reset_glose()
  for name in pairs(package.loaded) do
    if name:match "^glose" then
      package.loaded[name] = nil
    end
  end
end

local function apply_style(style)
  reset_glose()
  require("glose.config").setup {
    scope = { biscuit = { style = style } },
  }
  require("glose.ui.highlights").setup()
end

local function get_bg(name)
  return vim.api.nvim_get_hl(0, { name = name }).bg
end

local function get_fg(name)
  return vim.api.nvim_get_hl(0, { name = name }).fg
end

describe("biscuit highlight style", function()
  before_each(function()
    vim.api.nvim_set_hl(0, "Normal", { bg = "#1e1e2e" })
    vim.api.nvim_set_hl(0, "Comment", { fg = "#6c7086" })
  end)

  describe("style = 'fg'", function()
    it("has fg but no bg on all kinds", function()
      apply_style "fg"
      for _, kind in ipairs { 5, 10, 12, 15 } do
        local name = "GloseScopeBiscuit_" .. kind
        assert.is_not_nil(get_fg(name), "fg missing for " .. name)
        assert.is_nil(get_bg(name), "bg should be nil for " .. name)
      end
    end)

    it("keyword has no bg", function()
      apply_style "fg"
      assert.is_nil(get_bg "GloseScopeBiscuitKeyword")
    end)
  end)

  describe("style = 'tinted'", function()
    it("each kind has a distinct bg derived from fg", function()
      apply_style "tinted"
      local bg_10 = get_bg "GloseScopeBiscuit_10"
      local bg_5 = get_bg "GloseScopeBiscuit_5"
      assert.is_not_nil(bg_10)
      assert.is_not_nil(bg_5)
      assert.are_not.equal(bg_10, bg_5)
    end)
  end)

  describe("style = 'muted'", function()
    it("all kinds share the same bg", function()
      apply_style "muted"
      local bg_first = get_bg "GloseScopeBiscuit_5"
      assert.is_not_nil(bg_first)
      for _, kind in ipairs { 10, 12, 15, 25 } do
        assert.equal(bg_first, get_bg("GloseScopeBiscuit_" .. kind))
      end
    end)

    it("keyword shares the same muted bg", function()
      apply_style "muted"
      assert.equal(get_bg "GloseScopeBiscuit_10", get_bg "GloseScopeBiscuitKeyword")
    end)
  end)

  describe("default style", function()
    it("defaults to 'muted' when style not set", function()
      reset_glose()
      require("glose.config").setup {}
      require("glose.ui.highlights").setup()
      local bg_first = get_bg "GloseScopeBiscuit_5"
      for _, kind in ipairs { 10, 12, 15 } do
        assert.equal(bg_first, get_bg("GloseScopeBiscuit_" .. kind))
      end
    end)
  end)
end)
