if vim.g.loaded_iflsp then
  return
end
vim.g.loaded_iflsp = true

local subcmds = {
  hover = function(l)
    l.hover()
  end,
  definition = function(l)
    l.definition()
  end,
  code_action = function(l, o)
    l.code_action(o.range > 0 and { line1 = o.line1, line2 = o.line2 } or nil)
  end,
  rename = function(l)
    l.rename()
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

vim.api.nvim_create_user_command("IfLsp", function(opts)
  local iflsp = require "if.lsp"
  local args = opts.fargs

  if #args == 0 then
    iflsp.hover()
    return
  end

  local subcmd = args[1]
  local handler = subcmds[subcmd]

  if handler then
    handler(iflsp, opts)
  else
    vim.notify("[if.lsp] Unknown subcommand: " .. subcmd, vim.log.levels.ERROR)
  end
end, {
  nargs = "*",
  range = true,
  complete = function(arg_lead)
    local subcommands = vim.tbl_keys(subcmds)
    table.sort(subcommands)
    return vim.tbl_filter(function(s)
      return s:match("^" .. arg_lead)
    end, subcommands)
  end,
  desc = "LSP UI layer for Neovim",
})
