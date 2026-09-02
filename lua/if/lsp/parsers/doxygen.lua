local g = require("if.lsp.glyph").tag

---@type table<string, IfLsp.TagDef>
return {
  ["\\param"] = { icon = g.param, hl = "IfLspTitle" },
  ["\\returns?"] = { icon = g.returns, hl = "@keyword.return" },
  ["\\brief"] = { icon = g.brief, hl = "IfLspTitle" },
  ["\\throws"] = { icon = g.throws, hl = "DiagnosticWarn" },
  ["\\see"] = { icon = g.see, hl = "@markup.link" },
  ["\\since"] = { icon = g.since, hl = "@number" },
  ["\\deprecated"] = { icon = g.deprecated, hl = "DiagnosticError" },
  ["\\note"] = { icon = g.note, hl = "DiagnosticInfo" },
  ["\\warning"] = { icon = g.throws, hl = "DiagnosticWarn" },
}
