local M = {}

local glyph = require "if.lsp.glyph"
local footer = require "if.lsp.ui.footer"
local FloatPanel = require "if.lsp.ui.float"

---@class IfLsp.DiagnosticListPanel : IfLsp.FloatPanel
---@field _scope "buffer"|"workspace"
---@field _entries table<number, {bufnr: number, lnum: number, col: number}>
local DiagnosticListPanel = setmetatable({}, { __index = FloatPanel })
DiagnosticListPanel.__index = DiagnosticListPanel

local panel = DiagnosticListPanel:new "diagnostic_list" --[[@as IfLsp.DiagnosticListPanel]]

function DiagnosticListPanel:get_config()
  return vim.tbl_extend("force", FloatPanel.get_config(self), {
    enter = true,
    cursorline = true,
    min_width = 40,
  })
end

function DiagnosticListPanel:close()
  FloatPanel.close(self)
  self._entries = nil
end

function DiagnosticListPanel:open_win(lines)
  local cfg = self:get_config()
  if cfg.layout ~= "split" then
    return FloatPanel.open_win(self, lines)
  end

  vim.cmd "botright split"
  self.win = vim.api.nvim_get_current_win()
  self._enter = true
  vim.api.nvim_win_set_buf(self.win, self.buf)
  vim.api.nvim_win_set_height(self.win, cfg.height or 10)

  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:IfLspNormal,SignColumn:IfLspNormal,CursorLine:CursorLine",
    { win = self.win }
  )
  vim.api.nvim_set_option_value("signcolumn", "yes", { win = self.win })
  vim.api.nvim_set_option_value("wrap", false, { win = self.win })
  vim.api.nvim_set_option_value("number", false, { win = self.win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = self.win })
  vim.api.nvim_set_option_value("cursorline", true, { win = self.win })
  vim.api.nvim_set_option_value("winfixheight", true, { win = self.win })

  vim.bo[self.buf].modifiable = false
  vim.api.nvim_create_autocmd("InsertEnter", {
    buffer = self.buf,
    callback = function()
      vim.cmd.stopinsert()
    end,
  })
end

local function build_ns_map()
  local map = {}
  for _, client in ipairs(vim.lsp.get_clients()) do
    for _, pull in ipairs { false, true } do
      local ok, ns = pcall(vim.lsp.diagnostic.get_namespace, client.id, pull)
      if ok and ns then
        map[ns] = client.name
      end
    end
  end
  return map
end

local function provider_of(diag, ns_map)
  return (diag.namespace and ns_map[diag.namespace]) or diag.source or "LSP"
end

local function clean(msg)
  return (msg:gsub("\n", " "):gsub("%.$", ""))
end

local function group_key(provider, code)
  return provider .. "\0" .. (code or "")
end

---Emit provider·code groups for a set of diagnostics into lines/ext_list, recording jump entries.
local function emit_groups(diags, ns_map, lines, ext_list, entries)
  local enriched = {}
  for _, d in ipairs(diags) do
    enriched[#enriched + 1] = {
      diag = d,
      provider = provider_of(d, ns_map),
      code = d.code and tostring(d.code) or nil,
    }
  end

  table.sort(enriched, function(a, b)
    if a.diag.severity ~= b.diag.severity then
      return a.diag.severity < b.diag.severity
    end
    if a.provider ~= b.provider then
      return a.provider < b.provider
    end
    local ca, cb = a.code or "", b.code or ""
    if ca ~= cb then
      return ca < cb
    end
    return a.diag.lnum < b.diag.lnum
  end)

  local last_key = nil
  for _, e in ipairs(enriched) do
    local d = e.diag
    local s = glyph.severity[d.severity] or glyph.severity[4]
    local key = group_key(e.provider, e.code)

    if key ~= last_key then
      local header = e.code and (e.provider .. " · " .. e.code) or e.provider
      lines[#lines + 1] = header
      ext_list[#ext_list + 1] = { sign = { icon = s.icon, hl = s.hl }, line_hl = s.hl }
      last_key = key
    end

    lines[#lines + 1] = string.format(" %d:%d  %s", d.lnum + 1, d.col + 1, clean(d.message))
    ext_list[#ext_list + 1] = { line_hl = s.hl }
    entries[#lines] = { bufnr = d.bufnr, lnum = d.lnum, col = d.col }
  end
end

function DiagnosticListPanel:build_content(scope, prefetched)
  self._scope = scope
  self._entries = {}
  local entries = self._entries

  local ns_map = build_ns_map()
  local lines = {}
  local ext_list = {}

  local diagnostics
  if scope == "workspace" then
    diagnostics = prefetched or vim.diagnostic.get()
  else
    diagnostics = vim.diagnostic.get(self.source_bufnr)
  end

  if #diagnostics == 0 then
    vim.notify("IfLsp: No diagnostics in " .. (scope == "workspace" and "workspace" or "buffer"), vim.log.levels.INFO)
    return {}, {}
  end

  local providers, seen = {}, {}
  for _, d in ipairs(diagnostics) do
    local p = provider_of(d, ns_map)
    if not seen[p] then
      seen[p] = true
      providers[#providers + 1] = p
    end
  end

  local meta_lines, meta_ext = self:build_meta(table.concat(providers, ", "))
  for i = 1, #meta_lines do
    lines[#lines + 1] = meta_lines[i]
    ext_list[#ext_list + 1] = meta_ext[i]
  end

  local scope_label = scope == "workspace" and "workspace" or "buffer"
  lines[#lines + 1] = string.format("%s · %d", scope_label, #diagnostics)
  ext_list[#ext_list + 1] = { sign = { icon = glyph.ui.info, hl = "@comment" }, line_hl = "@comment" }

  lines[#lines + 1] = ""
  ext_list[#ext_list + 1] = {}

  if scope == "workspace" then
    local by_buf = {}
    local order = {}
    for _, d in ipairs(diagnostics) do
      if not by_buf[d.bufnr] then
        by_buf[d.bufnr] = {}
        order[#order + 1] = d.bufnr
      end
      table.insert(by_buf[d.bufnr], d)
    end
    table.sort(order, function(a, b)
      return vim.api.nvim_buf_get_name(a) < vim.api.nvim_buf_get_name(b)
    end)

    for _, bufnr in ipairs(order) do
      local name = vim.api.nvim_buf_get_name(bufnr)
      local short = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or "[No Name]"
      local file_icon, file_hl = glyph.ui.file, "IfLspDiffFile"
      local ok, devicons = pcall(require, "nvim-web-devicons")
      if ok and name ~= "" then
        local di, dh =
          devicons.get_icon(vim.fn.fnamemodify(name, ":t"), vim.fn.fnamemodify(name, ":e"), { default = true })
        if di then
          file_icon, file_hl = di, dh
        end
      end
      lines[#lines + 1] = short
      ext_list[#ext_list + 1] = { sign = { icon = file_icon, hl = file_hl }, line_hl = "IfLspDiffFile" }
      emit_groups(by_buf[bufnr], ns_map, lines, ext_list, entries)
    end
  else
    emit_groups(diagnostics, ns_map, lines, ext_list, entries)
  end

  self.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.bo[self.buf].modifiable = false
  vim.bo[self.buf].buftype = "nofile"

  return lines, ext_list
end

local function entry_at_or_after(row)
  local total = panel.buf and vim.api.nvim_buf_line_count(panel.buf) or 0
  for r = row, total do
    if panel._entries[r] then
      return panel._entries[r]
    end
  end
  return nil
end

local function jump()
  if not panel:is_open() then
    return
  end
  local row = vim.api.nvim_win_get_cursor(panel.win)[1]
  local e = entry_at_or_after(row)
  if not e then
    return
  end
  panel:close()
  if not vim.api.nvim_buf_is_valid(e.bufnr) then
    return
  end
  vim.cmd "normal! m'"
  vim.api.nvim_set_current_buf(e.bufnr)
  pcall(vim.api.nvim_win_set_cursor, 0, { e.lnum + 1, e.col })
  vim.cmd "normal! zz"
end

local function move(dir)
  if not panel:is_open() then
    return
  end
  local total = vim.api.nvim_buf_line_count(panel.buf)
  local row = vim.api.nvim_win_get_cursor(panel.win)[1] + dir
  while row >= 1 and row <= total do
    if panel._entries[row] then
      vim.api.nvim_win_set_cursor(panel.win, { row, 0 })
      return
    end
    row = row + dir
  end
end

local function hint_items(cfg)
  return {
    { icon = glyph.footer.move, desc = "move", key = "jk" },
    { icon = glyph.footer.execute, desc = "jump", key = cfg.confirm_key },
    {
      icon = glyph.footer.select,
      desc = panel._scope == "buffer" and "workspace" or "buffer",
      key = cfg.scope_toggle_key,
    },
    { icon = glyph.footer.close, desc = "close", key = cfg.close_key },
  }
end

local function display_key(raw)
  return (raw:gsub("^<(.+)>$", "%1"))
end

local function set_footer()
  local cfg = panel:get_config()
  local items = hint_items(cfg)

  if cfg.layout == "split" then
    if not cfg.footer or not cfg.footer.enabled then
      return
    end
    local parts = { "%=" }
    for _, k in ipairs(items) do
      if cfg.footer.show_desc then
        parts[#parts + 1] = string.format(
          "%%#IfLspFooterIcon# %s%%#IfLspFooterDesc# %s%%#IfLspFooterKey#[%s] ",
          k.icon,
          k.desc,
          display_key(k.key)
        )
      else
        parts[#parts + 1] = string.format("%%#IfLspFooterIcon# %s%%#IfLspFooterKey#[%s] ", k.icon, display_key(k.key))
      end
    end
    vim.api.nvim_set_option_value("winbar", table.concat(parts), { win = panel.win })
  else
    footer.set(panel.win, items, cfg.footer)
  end
end

local function toggle_scope()
  local src = panel.source_bufnr
  local next_scope = panel._scope == "buffer" and "workspace" or "buffer"
  panel:close()
  M.open(next_scope, src)
end

function DiagnosticListPanel:setup_keymaps()
  FloatPanel.setup_keymaps(self)
  local cfg = self:get_config()

  vim.keymap.set("n", cfg.confirm_key, jump, { buffer = self.buf, nowait = true, silent = true })
  vim.keymap.set("n", cfg.scope_toggle_key, toggle_scope, { buffer = self.buf, nowait = true, silent = true })

  local function down()
    move(1)
  end
  local function up()
    move(-1)
  end
  vim.keymap.set("n", "j", down, { buffer = self.buf, nowait = true, silent = true })
  vim.keymap.set("n", "k", up, { buffer = self.buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Down>", down, { buffer = self.buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Up>", up, { buffer = self.buf, nowait = true, silent = true })
  vim.keymap.set("n", "h", "<Nop>", { buffer = self.buf, nowait = true, silent = true })
  vim.keymap.set("n", "l", "<Nop>", { buffer = self.buf, nowait = true, silent = true })
end

function DiagnosticListPanel:after_open()
  local first = entry_at_or_after(1)
  if first then
    for r = 1, vim.api.nvim_buf_line_count(self.buf) do
      if self._entries[r] then
        pcall(vim.api.nvim_win_set_cursor, self.win, { r, 0 })
        break
      end
    end
  end
  set_footer()
end

local function diag_key(bufnr, lnum, col, code, message)
  return table.concat({ bufnr or 0, lnum, col, tostring(code or ""), message }, ":")
end

local function to_diag(item, bufnr, fallback_source)
  return {
    bufnr = bufnr,
    lnum = item.range.start.line,
    col = item.range.start.character,
    end_lnum = item.range["end"].line,
    end_col = item.range["end"].character,
    severity = item.severity or vim.diagnostic.severity.HINT,
    message = item.message,
    source = item.source or fallback_source,
    code = item.code,
  }
end

---Gather workspace-wide diagnostics: loaded buffers + pull (workspace/diagnostic) when supported.
local function gather_workspace(source_bufnr, cb)
  local combined = vim.diagnostic.get()

  local clients = {}
  for _, c in ipairs(vim.lsp.get_clients()) do
    local dp = c.server_capabilities and c.server_capabilities.diagnosticProvider
    if type(dp) == "table" and dp.workspaceDiagnostics then
      clients[#clients + 1] = c
    end
  end

  if #clients == 0 then
    cb(combined, false)
    return
  end

  local seen = {}
  for _, d in ipairs(combined) do
    seen[diag_key(d.bufnr, d.lnum, d.col, d.code, d.message)] = true
  end

  local pending = #clients
  for _, client in ipairs(clients) do
    local dp = client.server_capabilities.diagnosticProvider
    client:request("workspace/diagnostic", { identifier = dp.identifier, previousResultIds = {} }, function(err, result)
      if not err and result and result.items then
        for _, report in ipairs(result.items) do
          if report.items and report.uri then
            local bufnr = vim.uri_to_bufnr(report.uri)
            for _, item in ipairs(report.items) do
              local key = diag_key(bufnr, item.range.start.line, item.range.start.character, item.code, item.message)
              if not seen[key] then
                seen[key] = true
                combined[#combined + 1] = to_diag(item, bufnr, client.name)
              end
            end
          end
        end
      end
      pending = pending - 1
      if pending == 0 then
        vim.schedule(function()
          cb(combined, true)
        end)
      end
    end, source_bufnr)
  end
end

---@param scope? "buffer"|"workspace"
---@param source_bufnr? number
function M.open(scope, source_bufnr)
  panel:close()
  source_bufnr = source_bufnr or vim.api.nvim_get_current_buf()
  scope = scope or require("if.lsp.config").get().diagnostic_list.scope or "buffer"

  if scope == "workspace" then
    gather_workspace(source_bufnr, function(diags)
      panel:show(source_bufnr, scope, diags)
    end)
  else
    panel:show(source_bufnr, scope)
  end
end

function M.toggle()
  if panel:is_open() then
    panel:close()
  else
    M.open()
  end
end

return setmetatable(M, {
  __call = function(_)
    return M.open()
  end,
})
