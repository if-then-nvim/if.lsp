if vim.g.loaded_glose then
  return
end
vim.g.loaded_glose = true

local subcmds = {
  hover = function(l)
    l.hover()
  end,
  definition = function(l)
    l.definition()
  end,
  code_action = function(l)
    l.code_action()
  end,
  signature_help = function(l)
    l.signature_help()
  end,
  inlay_hint = function(l)
    l.inlay_hint.toggle()
  end,
  scope = function(l)
    l.scope.toggle()
  end,
}

vim.api.nvim_create_user_command("Glose", function(opts)
  local glose = require "glose"
  local args = opts.fargs

  if #args == 0 then
    glose.hover()
    return
  end

  local subcmd = args[1]
  local handler = subcmds[subcmd]

  if handler then
    handler(glose)
  else
    vim.notify("[glose] Unknown subcommand: " .. subcmd, vim.log.levels.ERROR)
  end
end, {
  nargs = "*",
  complete = function(arg_lead)
    local subcommands = vim.tbl_keys(subcmds)
    table.sort(subcommands)
    return vim.tbl_filter(function(s)
      return s:match("^" .. arg_lead)
    end, subcommands)
  end,
  desc = "LSP Easy More On Neovim",
})
