local M = {}

local beacon = require "if.lsp.ui.beacon"
local diff = require "if.lsp.ui.diff"
local footer = require "if.lsp.ui.footer"
local glyph = require "if.lsp.glyph"
local lsp_util = require "if.lsp.util.lsp"
local FloatPanel = require "if.lsp.ui.float"

---@return table
local function cfg()
  return require("if.lsp.config").get().rename
end

-- ── input ────────────────────────────────────────────────────────────────
-- One editable line at the cursor, prefilled with the name being replaced.

local InputPanel = setmetatable({}, { __index = FloatPanel })
InputPanel.__index = InputPanel

function InputPanel:get_config()
  local c = cfg()
  return vim.tbl_extend("force", FloatPanel.get_config(self), {
    editable = true,
    enter = true,
    cursorline = false,
    min_height = 1,
    max_height = 0.1,
    min_width = c.min_width,
    max_width = c.max_width,
  })
end

function InputPanel:build_content(placeholder)
  return { placeholder }, {}
end

function InputPanel:setup_keymaps()
  local c = cfg()
  local opts = { buffer = self.buf, nowait = true, silent = true }

  local function confirm()
    local line = vim.api.nvim_buf_get_lines(self.buf, 0, 1, false)[1] or ""
    local name = vim.trim(line)
    vim.cmd.stopinsert()
    self:close()
    M._submit(name)
  end

  for _, mode in ipairs { "n", "i" } do
    vim.keymap.set(mode, c.confirm_key, confirm, opts)
  end
  vim.keymap.set("n", c.close_key, function()
    self:close()
    M._reset()
  end, opts)
  for _, mode in ipairs { "n", "i" } do
    vim.keymap.set(mode, "<Esc>", function()
      vim.cmd.stopinsert()
      self:close()
      M._reset()
    end, opts)
  end
end

function InputPanel:after_open()
  local c = cfg()
  footer.set(self.win, {
    { icon = glyph.footer.execute, desc = "rename", key = c.confirm_key },
    { icon = glyph.footer.close, desc = "cancel", key = c.close_key },
  }, c.footer)

  vim.cmd.startinsert()
  if c.select_all then
    -- Put the cursor past the last character so typing replaces nothing and
    -- <C-w> clears the whole name in one stroke.
    vim.api.nvim_win_set_cursor(self.win, { 1, #(vim.api.nvim_buf_get_lines(self.buf, 0, 1, false)[1] or "") })
  end
end

-- ── preview ──────────────────────────────────────────────────────────────
-- The edit the server sent back, as a diff, before anything touches disk.

local PreviewPanel = setmetatable({}, { __index = FloatPanel })
PreviewPanel.__index = PreviewPanel

function PreviewPanel:get_config()
  local c = cfg()
  return vim.tbl_extend("force", FloatPanel.get_config(self), {
    enter = true,
    cursorline = false,
    min_width = 40,
    extra_height = 1,
    max_width = c.max_width,
    max_height = c.max_height,
  })
end

function PreviewPanel:build_content(diffs, old_name, new_name)
  local lines, extmarks = diff.build_lines(diffs)

  -- compute() hands back a unified diff per file, as text. Added lines are
  -- the ones that carry the new name; the +++ header is not one of them.
  local files, edits = #diffs, 0
  for _, entry in ipairs(diffs) do
    for line in tostring(entry.diff or ""):gmatch "[^\n]+" do
      if line:sub(1, 1) == "+" and line:sub(1, 3) ~= "+++" then
        edits = edits + 1
      end
    end
  end

  local summary = string.format(
    "%s %s → %s   %d %s, %d %s",
    glyph.rename.summary,
    old_name,
    new_name,
    edits,
    edits == 1 and "edit" or "edits",
    files,
    files == 1 and "file" or "files"
  )
  table.insert(lines, 1, summary)
  table.insert(lines, 2, "")

  for _, m in ipairs(extmarks) do
    m.line = m.line + 2
  end
  table.insert(extmarks, 1, { line = 0, col = 0, end_col = #summary, hl = "IfLspRenameSummary" })

  return lines, extmarks
end

function PreviewPanel:setup_keymaps()
  local c = cfg()
  local opts = { buffer = self.buf, nowait = true, silent = true }
  vim.keymap.set("n", c.confirm_key, function()
    self:close()
    M._apply()
  end, opts)
  for _, key in ipairs { c.close_key, "<Esc>" } do
    vim.keymap.set("n", key, function()
      self:close()
      M._reset()
    end, opts)
  end
end

function PreviewPanel:after_open()
  local c = cfg()
  footer.set(self.win, {
    { icon = glyph.footer.execute, desc = "apply", key = c.confirm_key },
    { icon = glyph.footer.close, desc = "cancel", key = c.close_key },
  }, c.footer)
end

-- ── flow ─────────────────────────────────────────────────────────────────

local input = InputPanel:new "rename"
local preview = PreviewPanel:new "rename"

---@type table|nil
local pending = nil

function M._reset()
  pending = nil
end

---Ask the server what the rename would do, then show it or do it.
---@param new_name string
function M._submit(new_name)
  local p = pending
  if not p then
    return
  end
  if new_name == "" or new_name == p.old_name then
    M._reset()
    return
  end
  p.new_name = new_name

  local client = vim.lsp.get_client_by_id(p.client_id)
  if not client then
    vim.notify("IfLsp: Client not found", vim.log.levels.ERROR)
    M._reset()
    return
  end

  local params = vim.lsp.util.make_position_params(p.win, client.offset_encoding)
  params.textDocument = { uri = vim.uri_from_bufnr(p.bufnr) }
  params.position = p.position
  params.newName = new_name

  client:request("textDocument/rename", params, function(err, edit)
    if err then
      vim.schedule(function()
        vim.notify("IfLsp: " .. (err.message or "rename failed"), vim.log.levels.ERROR)
        M._reset()
      end)
      return
    end
    if not edit or (not edit.changes and not edit.documentChanges) then
      vim.schedule(function()
        vim.notify("IfLsp: Nothing to rename", vim.log.levels.INFO)
        M._reset()
      end)
      return
    end

    p.edit = edit
    p.encoding = client.offset_encoding or "utf-16"

    vim.schedule(function()
      if not cfg().preview then
        M._apply()
        return
      end
      local diffs = diff.compute(p.edit, p.encoding, cfg().diff_context)
      if #diffs == 0 then
        M._apply()
        return
      end
      preview:show(p.bufnr, diffs, p.old_name, p.new_name)
    end)
  end, p.bufnr)
end

function M._apply()
  local p = pending
  if not p or not p.edit then
    M._reset()
    return
  end
  vim.lsp.util.apply_workspace_edit(p.edit, p.encoding)
  if vim.api.nvim_buf_is_valid(p.bufnr) then
    beacon.beacon(p.bufnr, p.position.line, p.position.character)
  end
  M._reset()
end

function M.rename()
  input:close()
  preview:close()

  local bufnr = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  local position = { line = cursor[1] - 1, character = cursor[2] }

  local function start(old_name, client_id)
    if old_name == "" then
      vim.notify("IfLsp: Nothing under the cursor to rename", vim.log.levels.INFO)
      return
    end
    pending = {
      bufnr = bufnr,
      win = win,
      position = position,
      old_name = old_name,
      client_id = client_id,
    }
    input:show(bufnr, old_name)
  end

  local clients = vim.lsp.get_clients { bufnr = bufnr, method = "textDocument/rename" }
  if #clients == 0 then
    vim.notify("IfLsp: No LSP clients support rename", vim.log.levels.INFO)
    return
  end

  -- prepareRename is optional; when a server has it, it tells us the exact
  -- span and the name to prefill, which beats guessing with <cword>.
  lsp_util.request_first(bufnr, "textDocument/prepareRename", function(client)
    local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
    params.position = position
    return params
  end, function(result)
    return result ~= nil
  end, function(result, client)
    local name = result.placeholder
    if not name and result.start then
      local line = vim.api.nvim_buf_get_lines(bufnr, result.start.line, result.start.line + 1, false)[1] or ""
      name = line:sub(result.start.character + 1, result["end"].character)
    end
    start(name or vim.fn.expand "<cword>", client.id)
  end, function()
    start(vim.fn.expand "<cword>", clients[1].id)
  end)
end

return setmetatable(M, {
  __call = function(_)
    return M.rename()
  end,
})
