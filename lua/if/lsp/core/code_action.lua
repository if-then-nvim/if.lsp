local M = {}

local glyph = require "if.lsp.glyph"
local footer = require "if.lsp.ui.footer"
local FloatPanel = require "if.lsp.ui.float"
local PreviewManager = require "if.lsp.ui.preview"

local CodeActionPanel = setmetatable({}, { __index = FloatPanel })
CodeActionPanel.__index = CodeActionPanel

local panel = CodeActionPanel:new "code_action"
local preview = PreviewManager:new(panel)

function CodeActionPanel:get_config()
  -- Sized to its content. The preview no longer touches the width, so
  -- whatever this settles on at open is what the panel keeps.
  return vim.tbl_extend("force", FloatPanel.get_config(self), {
    cursorline = true,
    enter = true,
    min_width = 30,
    extra_height = 2,
  })
end

function CodeActionPanel:close()
  FloatPanel.close(self)
  preview:reset()
  self._actions = nil
end

function CodeActionPanel:build_content(actions, diag_code)
  self._actions = actions

  local lines = {}
  local ext_list = {}

  local client = vim.lsp.get_client_by_id(actions[1].client_id)
  local server_name = client and client.name or "LSP"

  local meta_lines, meta_ext = self:build_meta(server_name, diag_code)
  for i, _ in ipairs(meta_lines) do
    table.insert(lines, meta_lines[i])
    table.insert(ext_list, meta_ext[i])
  end

  if #lines > 0 then
    table.insert(lines, "")
    table.insert(ext_list, {})
  end

  self._meta_count = #lines

  for i, entry in ipairs(actions) do
    local title = entry.action.title or "Action"
    table.insert(lines, title)
    local icon = glyph.numeric[i] or glyph.numeric[#glyph.numeric]
    table.insert(ext_list, { sign = { icon = icon, hl = "IfLspActionNumber" }, line_hl = "Normal", text_hl = "Normal" })
  end

  self.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.bo[self.buf].modifiable = false
  vim.bo[self.buf].buftype = "nofile"

  return lines, ext_list
end

local function apply_action_at(idx)
  local entry = panel._actions[idx]
  if not entry then
    return
  end

  local client = vim.lsp.get_client_by_id(entry.client_id)
  if not client then
    vim.notify("IfLsp: Client not found", vim.log.levels.ERROR)
    return
  end

  local resolved = preview:get_resolved(idx) or entry.action

  panel:close()

  if resolved.edit then
    vim.lsp.util.apply_workspace_edit(resolved.edit, client.offset_encoding or "utf-16")
  end
  if resolved.command then
    local command = type(resolved.command) == "table" and resolved.command or resolved
    client:exec_cmd(command)
  end
end

local function get_cursor_action_idx()
  if not panel:is_open() then
    return nil
  end
  local offset = panel._meta_count or 0
  local row = vim.api.nvim_win_get_cursor(panel.win)[1]
  local idx = row - offset
  if idx >= 1 and idx <= #panel._actions then
    return idx
  end
  return nil
end

local function clamp_cursor()
  if not panel:is_open() then
    return
  end
  local offset = panel._meta_count or 0
  local count = #panel._actions
  local row = vim.api.nvim_win_get_cursor(panel.win)[1]
  if row - offset > count then
    vim.api.nvim_win_set_cursor(panel.win, { offset + count, 0 })
  elseif row - offset < 1 then
    vim.api.nvim_win_set_cursor(panel.win, { offset + 1, 0 })
  end
end

function CodeActionPanel:setup_keymaps()
  FloatPanel.setup_keymaps(self)

  local cfg = self:get_config()

  vim.keymap.set("n", cfg.back_key, function()
    panel:close()
  end, { buffer = self.buf, nowait = true, silent = true })

  vim.keymap.set("n", cfg.confirm_key, function()
    local idx = get_cursor_action_idx()
    if idx then
      apply_action_at(idx)
    end
  end, { buffer = self.buf, nowait = true, silent = true })

  vim.keymap.set("n", "h", "<Nop>", { buffer = self.buf, nowait = true, silent = true })
  vim.keymap.set("n", "l", "<Nop>", { buffer = self.buf, nowait = true, silent = true })

  for i = 1, math.min(9, #self._actions) do
    vim.keymap.set("n", tostring(i), function()
      if panel._actions[i] then
        apply_action_at(i)
      end
    end, { buffer = self.buf, nowait = true, silent = true })
  end
end

function CodeActionPanel:setup_autocmds()
  FloatPanel.setup_autocmds(self)

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = self.augroup,
    buffer = self.buf,
    callback = function()
      clamp_cursor()
      local idx = get_cursor_action_idx()
      if idx then
        preview:update(idx)
      end
    end,
  })
end

function CodeActionPanel:after_open()
  local offset = self._meta_count or 0
  preview:attach(self._actions, offset + #self._actions)
  vim.api.nvim_win_set_cursor(self.win, { offset + 1, 0 })
  preview:update(1)

  local cfg = self:get_config()
  footer.set(self.win, {
    { icon = glyph.footer.move, desc = "move", key = "jk" },
    { icon = glyph.footer.execute, desc = "execute", key = cfg.confirm_key },
    { icon = glyph.footer.close, desc = "close", key = cfg.close_key },
  }, cfg.footer)
end

local function selection_bounds(bufnr, mode)
  local from, to = vim.fn.getpos "v", vim.fn.getpos "."
  local srow, scol, erow, ecol = from[2], from[3], to[2], to[3]
  if srow == erow and ecol < scol then
    scol, ecol = ecol, scol
  elseif erow < srow then
    srow, erow = erow, srow
    scol, ecol = ecol, scol
  end
  if mode == "V" then
    scol = 1
    ecol = #vim.api.nvim_buf_get_lines(bufnr, erow - 1, erow, true)[1]
  end
  return { srow, scol - 1 }, { erow, ecol - 1 }
end

function M.code_action(opts)
  panel:close()

  local source_bufnr = vim.api.nvim_get_current_buf()
  opts = opts or {}

  local clients = vim.lsp.get_clients { bufnr = source_bufnr, method = "textDocument/codeAction" }
  if #clients == 0 then
    vim.notify("IfLsp: No LSP clients support code actions", vim.log.levels.INFO)
    return
  end

  local mode = vim.api.nvim_get_mode().mode
  local live = mode == "v" or mode == "V" or mode == "\22"
  local from, to
  local first, last
  if live then
    from, to = selection_bounds(source_bufnr, mode)
    first, last = from[1] - 1, to[1] - 1
  elseif opts.range then
    first = vim.api.nvim_buf_get_mark(source_bufnr, "<")[1] - 1
    last = vim.api.nvim_buf_get_mark(source_bufnr, ">")[1] - 1
  else
    first = vim.api.nvim_win_get_cursor(0)[1] - 1
    last = first
  end

  local diagnostics = {}
  for l = first, last do
    vim.list_extend(diagnostics, vim.diagnostic.get(source_bufnr, { lnum = l }))
  end

  local diag_code = nil
  for _, d in ipairs(diagnostics) do
    if d.code then
      diag_code = tostring(d.code)
      break
    end
  end

  local context = {
    diagnostics = vim.tbl_map(function(d)
      return {
        range = {
          start = { line = d.lnum, character = d.col },
          ["end"] = { line = d.end_lnum or d.lnum, character = d.end_col or d.col },
        },
        severity = d.severity,
        code = d.code,
        source = d.source,
        message = d.message,
      }
    end, diagnostics),
    only = nil,
    triggerKind = 1,
  }

  local function params_for(client)
    local enc = client.offset_encoding or "utf-16"
    local p
    if live or opts.range then
      p = vim.lsp.util.make_given_range_params(from, to, source_bufnr, enc)
    else
      p = vim.lsp.util.make_position_params(0, enc)
      p.range = { start = p.position, ["end"] = p.position }
      p.position = nil
    end
    p.context = context
    return p
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
          if #all_actions == 0 then
            vim.notify("IfLsp: No code actions available", vim.log.levels.INFO)
            return
          end
          panel:show(source_bufnr, all_actions, diag_code)
        end)
      end
    end, source_bufnr)
  end
end

return setmetatable(M, {
  __call = function(_, opts)
    return M.code_action(opts)
  end,
})
