local Glose = {}

local config = require "glose.config"

---@param opts? Glose.Config
function Glose.setup(opts)
  config.setup(opts)
  require("glose.glyph").setup(config.get().glyph)
  require("glose.ui.highlights").setup()
  require("glose.core.signature_help").setup_auto()
  require("glose.core.inlay_hint").setup()
  require("glose.core.scope").setup()
  _G.Glose = Glose
end

function Glose.diagnostic_next()
  require("glose.core.diagnostic").goto_next()
end

function Glose.diagnostic_prev()
  require("glose.core.diagnostic").goto_prev()
end

function Glose.diagnostic_open()
  require("glose.core.diagnostic").open_float()
end

return setmetatable(Glose, {
  __index = function(t, k)
    local ok, mod = pcall(require, "glose.core." .. k)
    if ok then
      rawset(t, k, mod)
      return mod
    end
  end,
})
