local IfLsp = {}

local config = require "if.lsp.config"

---@param opts? IfLsp.Config
function IfLsp.setup(opts)
  config.setup(opts)
  require("if.lsp.glyph").setup(config.get().glyph)
  require("if.lsp.ui.highlights").setup()
  require("if.lsp.core.signature_help").setup_auto()
  require("if.lsp.core.inlay_hint").setup()
  require("if.lsp.core.scope").setup()
  _G.IfLsp = IfLsp
end

function IfLsp.diagnostic_next()
  require("if.lsp.core.diagnostic").goto_next()
end

function IfLsp.diagnostic_prev()
  require("if.lsp.core.diagnostic").goto_prev()
end

function IfLsp.diagnostic_open()
  require("if.lsp.core.diagnostic").open_float()
end

return setmetatable(IfLsp, {
  __index = function(t, k)
    local ok, mod = pcall(require, "if.lsp.core." .. k)
    if ok then
      rawset(t, k, mod)
      return mod
    end
  end,
})
