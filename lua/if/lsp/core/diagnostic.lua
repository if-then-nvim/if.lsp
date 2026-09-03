local M = {}

local glyph = require "if.lsp.glyph"
local extmarks_ui = require "if.lsp.ui.extmarks"
local footer = require "if.lsp.ui.footer"
local FloatPanel = require "if.lsp.ui.float"
local window = require "if.lsp.ui.window"
local PreviewManager = require "if.lsp.ui.preview"

local DiagnosticPanel = setmetatable({}, { __index = FloatPanel })
DiagnosticPanel.__index = DiagnosticPanel

local panel = DiagnosticPanel:new "diagnostic"
local preview = PreviewManager:new(panel)

local function get_client_name(namespace_id, bufnr)
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    local ok, ns = pcall(vim.lsp.diagnostic.get_namespace, client.id)
    if ok and ns == namespace_id then
      return client.name
    end
    local ok2, pull_ns = pcall(vim.lsp.diagnostic.get_namespace, client.id, true)
    if ok2 and pull_ns == namespace_id then
      return client.name
    end
  end
  return nil
end

function DiagnosticPanel:get_config()
  return vim.tbl_extend("force", FloatPanel.get_config(self), {
    enter = false,
    diff_context = 3,
  })
end

function DiagnosticPanel:close()
  local src = self.source_bufnr
  FloatPanel.close(self)
  preview:reset()
  self._actions = nil
  self._cursor_pos = nil
  self._action_start_line = 0
  if src and vim.api.nvim_buf_is_valid(src) then
    pcall(vim.keymap.del, "n", "<CR>", { buffer = src })
  end
end

function DiagnosticPanel:build_content(cursor_pos)
  self._cursor_pos = cursor_pos
  self._action_start_line = 0
  local lnum = cursor_pos[1] - 1

  local diagnostics = vim.diagnostic.get(self.source_bufnr, { lnum = lnum })
  if #diagnostics == 0 then
    return {}, {}
  end

  table.sort(diagnostics, function(a, b)
    local code_a = tostring(a.code or "")
    local code_b = tostring(b.code or "")
    if code_a ~= code_b then
      local sev_a = math.huge
      local sev_b = math.huge
      for _, d in ipairs(diagnostics) do
        if tostring(d.code or "") == code_a and d.severity < sev_a then
          sev_a = d.severity
        end
        if tostring(d.code or "") == code_b and d.severity < sev_b then
          sev_b = d.severity
        end
      end
      if sev_a ~= sev_b then
        return sev_a < sev_b
      end
      return code_a < code_b
    end
    if a.severity ~= b.severity then
      return a.severity < b.severity
    end
    return (a.source or "") < (b.source or "")
  end)

  local lines = {}
  local ext_list = {}

  local provider_cache = {}
  local function resolve_provider(diag)
    local ns = diag.namespace
    if ns and provider_cache[ns] ~= nil then
      return provider_cache[ns]
    end
    local name = (ns and get_client_name(ns, self.source_bufnr)) or diag.source or "LSP"
    if ns then
      provider_cache[ns] = name
    end
    return name
  end

  local seen_provider = {}
  local providers = {}
  for _, diag in ipairs(diagnostics) do
    local p = resolve_provider(diag)
    if not seen_provider[p] then
      seen_provider[p] = true
      providers[#providers + 1] = p
    end
  end

  local meta_lines, meta_ext = self:build_meta(table.concat(providers, ", "))
  for i, _ in ipairs(meta_lines) do
    table.insert(lines, meta_lines[i])
    table.insert(ext_list, meta_ext[i])
  end

  if #lines > 0 then
    table.insert(lines, "")
    table.insert(ext_list, {})
  end

  local last_code = nil
  for _, diag in ipairs(diagnostics) do
    local code = diag.code and tostring(diag.code) or nil
    local msg = diag.message:gsub("\n", " "):gsub("%.$", "")
    local s = glyph.severity[diag.severity] or glyph.severity[4]

    if code and code == last_code then
      table.insert(lines, "↳ " .. msg)
      table.insert(ext_list, { line_hl = s.hl })
    else
      local provider = resolve_provider(diag)
      local header = code and (provider .. " · " .. code) or provider
      table.insert(lines, header)
      table.insert(ext_list, { sign = { icon = s.icon, hl = s.hl }, line_hl = s.hl })
      table.insert(lines, msg)
      table.insert(ext_list, { line_hl = s.hl })
    end

    last_code = code
  end

  self.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.bo[self.buf].modifiable = false
  vim.bo[self.buf].buftype = "nofile"

  return lines, ext_list
end

local function apply_action(action, client)
  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding or "utf-16")
  end
  if action.command then
    local command = type(action.command) == "table" and action.command or action
    client:exec_cmd(command)
  end
end

local function execute_action(idx)
  local entry = preview.action_cache[idx]
  if not entry then
    if #preview.action_cache == 0 then
      vim.notify("IfLsp: No code actions available yet", vim.log.levels.INFO)
    end
    return
  end

  local source_bufnr = panel.source_bufnr

  panel:close()

  local client = vim.lsp.get_client_by_id(entry.client_id)
  if not client then
    vim.notify("IfLsp: Client not found for action", vim.log.levels.ERROR)
    return
  end

  local resolved = preview:get_resolved(idx)
  if resolved then
    apply_action(resolved, client)
    return
  end

  local action = entry.action
  if action.data and not action.edit then
    client:request("codeAction/resolve", action, function(err, r)
      if err then
        vim.notify("Code action resolve failed: " .. (err.message or "unknown error"), vim.log.levels.ERROR)
        return
      end
      vim.schedule(function()
        apply_action(r or action, client)
      end)
    end, source_bufnr)
  else
    apply_action(action, client)
  end
end

local function get_action_idx_at_cursor()
  if not panel:is_open() then
    return nil
  end
  if #preview.action_cache == 0 then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(panel.win)[1]
  local action_idx = row - panel._action_start_line
  if action_idx >= 1 and action_idx <= #preview.action_cache then
    return action_idx
  end
  return nil
end

local function request_code_actions()
  if not panel.buf or not vim.api.nvim_buf_is_valid(panel.buf) then
    return
  end

  local source_bufnr = panel.source_bufnr
  local cursor_pos = panel._cursor_pos
  local target_buf = panel.buf
  if not cursor_pos then
    return
  end

  local clients = vim.lsp.get_clients { bufnr = source_bufnr, method = "textDocument/codeAction" }
  if #clients == 0 then
    return
  end

  local lnum = cursor_pos[1] - 1
  local diagnostics = vim.diagnostic.get(source_bufnr, { lnum = lnum })

  local kinds = require("if.lsp.config").get().diagnostic.code_action_kinds
  local only = (type(kinds) == "table" and #kinds > 0) and kinds or nil

  -- The range has to cover the diagnostics, not just start of their line.
  -- lua_ls and tsserver answer from context.diagnostics and do not care, but
  -- rust-analyzer intersects by range and returns nothing at all for a
  -- zero-width range in the indent — no fix for a missing match arm, no fix
  -- for anything else either.
  local last = lnum
  local first_col, last_col = math.huge, 0
  for _, d in ipairs(diagnostics) do
    last = math.max(last, d.end_lnum or d.lnum)
    first_col = math.min(first_col, d.col)
    last_col = math.max(last_col, d.end_col or d.col)
  end
  if first_col == math.huge then
    first_col = 0
  end

  local function to_enc(line, byte_col, encoding)
    if byte_col <= 0 then
      return 0
    end
    local ok, v = pcall(vim.lsp.util.character_offset, source_bufnr, line, byte_col, encoding)
    return ok and v or byte_col
  end

  local function params_for(client)
    local enc = client.offset_encoding or "utf-16"
    return {
      textDocument = vim.lsp.util.make_text_document_params(source_bufnr),
      range = {
        start = { line = lnum, character = to_enc(lnum, first_col, enc) },
        ["end"] = { line = last, character = to_enc(last, last_col, enc) },
      },
      context = {
        diagnostics = vim.tbl_map(function(d)
          return {
            range = {
              start = { line = d.lnum, character = to_enc(d.lnum, d.col, enc) },
              ["end"] = {
                line = d.end_lnum or d.lnum,
                character = to_enc(d.end_lnum or d.lnum, d.end_col or d.col, enc),
              },
            },
            severity = d.severity,
            code = d.code,
            source = d.source,
            message = d.message,
          }
        end, diagnostics),
        only = only,
        triggerKind = 1,
      },
    }
  end

  local pending = #clients
  local all_actions = {}

  for _, client in ipairs(clients) do
    client:request("textDocument/codeAction", params_for(client), function(err, result)
      if not err and result then
        for _, action in ipairs(result) do
          table.insert(all_actions, { action = action, client_id = client.id })
        end
      end
      pending = pending - 1
      if pending == 0 then
        vim.schedule(function()
          if #all_actions == 0 or not target_buf or not vim.api.nvim_buf_is_valid(target_buf) then
            return
          end

          local current_lines = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
          panel._action_start_line = #current_lines + 1

          local action_lines = { "" }
          local action_extmarks = { {} }
          for i, entry in ipairs(all_actions) do
            local title = entry.action.title or "Action"
            table.insert(action_lines, title)
            local icon = glyph.numeric[i] or glyph.numeric[#glyph.numeric]
            table.insert(
              action_extmarks,
              { sign = { icon = icon, hl = "IfLspActionNumber" }, line_hl = "Normal", text_hl = "Normal" }
            )
          end

          vim.bo[target_buf].modifiable = true
          vim.api.nvim_buf_set_lines(target_buf, #current_lines, -1, false, action_lines)
          vim.bo[target_buf].modifiable = false

          extmarks_ui.apply(target_buf, "iflsp_diagnostic", action_extmarks, action_lines, #current_lines)

          -- The panel opened on the diagnostic alone; the titles are wider
          -- than the message almost every time, so the width is settled here,
          -- once, against everything the buffer now holds. Nothing widens it
          -- again after this.
          if panel:is_open() then
            local cfg = panel:get_config()
            local all = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
            local size = window.compute(all, {
              max_width = cfg.max_width,
              max_height = cfg.max_height,
              pad_right = cfg.pad_right,
              min_width = cfg.min_width,
              min_height = cfg.min_height,
            })
            panel:resize(math.max(size.width, vim.api.nvim_win_get_width(panel.win)), size.height)
          end

          preview:attach(all_actions, panel._action_start_line + #all_actions)
        end)
      end
    end, source_bufnr)
  end
end

function DiagnosticPanel:setup_keymaps()
  FloatPanel.setup_keymaps(self)

  vim.keymap.set("n", "h", "<Nop>", { buffer = self.buf, nowait = true, silent = true })
  vim.keymap.set("n", "l", "<Nop>", { buffer = self.buf, nowait = true, silent = true })

  vim.api.nvim_buf_set_keymap(self.buf, "n", "<CR>", "", {
    callback = function()
      local action_idx = get_action_idx_at_cursor()
      if action_idx then
        execute_action(action_idx)
        return
      end
      if #preview.action_cache > 0 then
        return
      end
      request_code_actions()
    end,
    nowait = true,
  })

  for i = 1, 9 do
    vim.keymap.set("n", tostring(i), function()
      execute_action(i)
    end, { buffer = self.buf, nowait = true, silent = true })
  end
end

function DiagnosticPanel:setup_autocmds()
  FloatPanel.setup_autocmds(self)

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = self.augroup,
    buffer = self.buf,
    callback = function()
      if #preview.action_cache > 0 then
        local row = vim.api.nvim_win_get_cursor(panel.win)[1]
        local first = panel._action_start_line + 1
        local last = panel._action_start_line + #preview.action_cache
        if row < first then
          vim.api.nvim_win_set_cursor(panel.win, { first, 0 })
        elseif row > last then
          vim.api.nvim_win_set_cursor(panel.win, { last, 0 })
        end
      end
      local action_idx = get_action_idx_at_cursor()
      if action_idx then
        preview:update(action_idx)
      elseif preview.current_idx ~= 0 then
        preview:clear_preview()
      end
    end,
  })
end

local function focus_panel()
  if not panel:is_open() then
    return
  end
  if panel.augroup and panel.source_bufnr then
    pcall(vim.api.nvim_clear_autocmds, { group = panel.augroup, buffer = panel.source_bufnr })
    pcall(vim.api.nvim_clear_autocmds, { group = panel.augroup, event = "WinScrolled" })
  end
  if panel.source_bufnr and vim.api.nvim_buf_is_valid(panel.source_bufnr) then
    pcall(vim.keymap.del, "n", "<CR>", { buffer = panel.source_bufnr })
  end
  vim.api.nvim_set_current_win(panel.win)
  if #preview.action_cache > 0 then
    vim.api.nvim_win_set_cursor(panel.win, { panel._action_start_line + 1, 0 })
    preview:update(1)
  end
  local cfg = panel:get_config()
  footer.set(panel.win, {
    { icon = glyph.footer.move, desc = "move", key = "jk" },
    { icon = glyph.footer.execute, desc = "execute", key = cfg.confirm_key or "<CR>" },
    { icon = glyph.footer.close, desc = "close", key = cfg.close_key },
  }, cfg.footer)
end

function DiagnosticPanel:after_open()
  local cfg = self:get_config()
  footer.set(self.win, {
    { icon = glyph.footer.enter, desc = "focus", key = cfg.confirm_key or "<CR>" },
  }, cfg.footer)
  vim.keymap.set("n", "<CR>", focus_panel, {
    buffer = self.source_bufnr,
    nowait = true,
    silent = true,
  })
  request_code_actions()
end

local function open_styled_float()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local source_bufnr = vim.api.nvim_get_current_buf()
  local lnum = cursor_pos[1] - 1
  local diagnostics = vim.diagnostic.get(source_bufnr, { lnum = lnum })
  if #diagnostics == 0 then
    return
  end

  panel:show(source_bufnr, cursor_pos)
end

function M.goto_next()
  vim.diagnostic.jump { count = 1, float = false }
  vim.schedule(function()
    open_styled_float()
  end)
end

function M.goto_prev()
  vim.diagnostic.jump { count = -1, float = false }
  vim.schedule(function()
    open_styled_float()
  end)
end

function M.open_float()
  if panel:is_open() then
    focus_panel()
    return
  end
  open_styled_float()
  if panel:is_open() then
    focus_panel()
  end
end

return M
