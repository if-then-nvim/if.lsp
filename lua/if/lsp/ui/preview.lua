local glyph = require "if.lsp.glyph"
local diff = require "if.lsp.ui.diff"
local extmarks = require "if.lsp.ui.extmarks"

---@class IfLsp.PreviewManager
local PreviewManager = {}
PreviewManager.__index = PreviewManager

function PreviewManager:new(panel)
  return setmetatable({
    panel = panel,
    action_cache = {},
    resolve_cache = {},
    diff_cache = {},
    current_idx = 0,
    updating = false,
    list_end_line = 0,
  }, self)
end

function PreviewManager:reset()
  self.action_cache = {}
  self.resolve_cache = {}
  self.diff_cache = {}
  self.current_idx = 0
  self.updating = false
  self.list_end_line = 0
end

function PreviewManager:attach(actions, list_end_line)
  self.action_cache = actions
  self.list_end_line = list_end_line
end

function PreviewManager:get_resolved(idx)
  return self.resolve_cache[idx]
end

function PreviewManager:update(idx)
  local panel = self.panel
  if not panel.buf or not vim.api.nvim_buf_is_valid(panel.buf) then
    return
  end
  if not panel:is_open() then
    return
  end
  if idx == self.current_idx then
    return
  end
  if self.updating then
    return
  end

  self.current_idx = idx
  local entry = self.action_cache[idx]
  if not entry then
    return
  end

  local ns_name = "iflsp_" .. panel.name
  local ns = vim.api.nvim_create_namespace(ns_name)
  local separator_start = self.list_end_line
  local preview_ft = nil
  local preview_code_info = nil
  local preview_mgr = self

  local function render_preview(diff_lines, diff_extmarks)
    if preview_mgr.current_idx ~= idx then
      return
    end
    if not panel.buf or not vim.api.nvim_buf_is_valid(panel.buf) then
      return
    end

    local cfg = panel:get_config()
    -- Action titles are a poor guess at how wide a diff will be. Widen to fit
    -- one, bounded by max_width and by the screen; grow_width never gives the
    -- space back, so moving through the list does not resize the window.
    local widest = 0
    for _, l in ipairs(diff_lines) do
      local w = vim.fn.strdisplaywidth(l)
      if w > widest then
        widest = w
      end
    end
    local cap = math.floor(vim.o.columns * (cfg.max_width or 0.8))
    panel:grow_width(math.min(widest + 2 + (cfg.pad_right or 0), cap))
    local new_width = vim.api.nvim_win_get_width(panel.win)

    vim.bo[panel.buf].modifiable = true

    local total = vim.api.nvim_buf_line_count(panel.buf)
    if total > separator_start then
      vim.api.nvim_buf_set_lines(panel.buf, separator_start, total, false, {})
    end

    local separator = string.rep("─", new_width - 2)
    local preview_block = { separator }
    for _, l in ipairs(diff_lines) do
      table.insert(preview_block, l)
    end

    vim.api.nvim_buf_set_lines(panel.buf, separator_start, separator_start, false, preview_block)
    vim.bo[panel.buf].modifiable = false

    vim.api.nvim_buf_clear_namespace(panel.buf, ns, separator_start, -1)
    vim.api.nvim_buf_set_extmark(panel.buf, ns, separator_start, 0, {
      end_col = #separator,
      hl_group = "FloatBorder",
    })
    extmarks.apply(panel.buf, ns_name, diff_extmarks, diff_lines, separator_start + 1)
    diff.apply_syntax(panel.buf, preview_code_info, preview_ft, separator_start + 1)

    local new_total = vim.api.nvim_buf_line_count(panel.buf)
    local editor_lines = vim.api.nvim_get_option_value("lines", {})
    local max_height = math.floor(editor_lines * cfg.max_height)
    local new_height = math.min(new_total, max_height)
    new_height = math.max(new_height, separator_start + 1)
    panel:resize_height(new_height)

    preview_mgr.updating = false
  end

  if self.diff_cache[idx] then
    preview_ft = self.diff_cache[idx].ft
    preview_code_info = self.diff_cache[idx].code_info
    render_preview(self.diff_cache[idx].lines, self.diff_cache[idx].extmarks)
    return
  end

  if self.resolve_cache[idx] then
    local resolved = self.resolve_cache[idx]
    if not resolved.edit then
      local lines = { "No preview available — Enter to execute" }
      local ext =
        { { sign = { icon = glyph.ui.info, hl = "DiagnosticInfo" }, line_hl = "Comment", text_hl = "Comment" } }
      self.diff_cache[idx] = { lines = lines, extmarks = ext }
      render_preview(lines, ext)
      return
    end
    local diff_context = panel:get_config().diff_context or 3
    local diffs =
      diff.compute(resolved.edit, vim.lsp.get_client_by_id(entry.client_id).offset_encoding or "utf-16", diff_context)
    if #diffs == 0 then
      local lines = { "No changes detected" }
      local ext =
        { { sign = { icon = glyph.ui.info, hl = "DiagnosticInfo" }, line_hl = "Comment", text_hl = "Comment" } }
      self.diff_cache[idx] = { lines = lines, extmarks = ext }
      render_preview(lines, ext)
    else
      local lines, ext, ft, code_info = diff.build_lines(diffs)
      preview_ft = ft
      preview_code_info = code_info
      self.diff_cache[idx] = { lines = lines, extmarks = ext, ft = ft, code_info = code_info }
      render_preview(lines, ext)
    end
    return
  end

  local action = entry.action

  if action.edit then
    self.resolve_cache[idx] = action
    local client = vim.lsp.get_client_by_id(entry.client_id)
    local encoding = client and client.offset_encoding or "utf-16"
    local diff_context = panel:get_config().diff_context or 3
    local diffs = diff.compute(action.edit, encoding, diff_context)
    if #diffs == 0 then
      local lines = { "No changes detected" }
      local ext =
        { { sign = { icon = glyph.ui.info, hl = "DiagnosticInfo" }, line_hl = "Comment", text_hl = "Comment" } }
      self.diff_cache[idx] = { lines = lines, extmarks = ext }
      render_preview(lines, ext)
    else
      local lines, ext, ft, code_info = diff.build_lines(diffs)
      preview_ft = ft
      preview_code_info = code_info
      self.diff_cache[idx] = { lines = lines, extmarks = ext, ft = ft, code_info = code_info }
      render_preview(lines, ext)
    end
    return
  end

  local client = vim.lsp.get_client_by_id(entry.client_id)
  if not client then
    self.updating = false
    return
  end

  ---An action with nothing to show is not a failure. A command runs on the
  ---server and has no edit to draw; so does one from a server that cannot
  ---resolve. Say so in the same voice as the other two empty states.
  ---@param cached lsp.CodeAction|lsp.Command
  local function show_no_preview(cached)
    preview_mgr.resolve_cache[idx] = cached
    local lines = { "No preview available — Enter to execute" }
    local ext = { { sign = { icon = glyph.ui.info, hl = "DiagnosticInfo" }, line_hl = "Comment", text_hl = "Comment" } }
    preview_mgr.diff_cache[idx] = { lines = lines, extmarks = ext }
    preview_mgr.updating = false
    if preview_mgr.current_idx == idx then
      render_preview(lines, ext)
    end
  end

  -- Neovim's own code_action checks both of these before spending a round
  -- trip, and so should this.
  if action.command or not client:supports_method "codeAction/resolve" then
    show_no_preview(action)
    return
  end

  self.updating = true
  local loading_lines = { "Resolving..." }
  local loading_ext =
    { { sign = { icon = glyph.ui.loading, hl = "DiagnosticInfo" }, line_hl = "Comment", text_hl = "Comment" } }
  render_preview(loading_lines, loading_ext)

  client:request("codeAction/resolve", action, function(err, resolved)
    vim.schedule(function()
      if err or not resolved then
        -- Only a real error when the action is unusable without the resolve.
        if action.edit or action.command then
          show_no_preview(action)
          return
        end
        preview_mgr.resolve_cache[idx] = action
        local lines = { err and ((err.code or "?") .. ": " .. (err.message or "resolve failed")) or "Resolve failed" }
        local ext = {
          {
            sign = { icon = glyph.ui.error, hl = "DiagnosticError" },
            line_hl = "DiagnosticError",
            text_hl = "DiagnosticError",
          },
        }
        preview_mgr.diff_cache[idx] = { lines = lines, extmarks = ext }
        preview_mgr.updating = false
        if preview_mgr.current_idx == idx then
          render_preview(lines, ext)
        end
        return
      end

      preview_mgr.resolve_cache[idx] = resolved
      local encoding = client.offset_encoding or "utf-16"

      if not resolved.edit then
        local lines = { "No preview available — Enter to execute" }
        local ext =
          { { sign = { icon = glyph.ui.info, hl = "DiagnosticInfo" }, line_hl = "Comment", text_hl = "Comment" } }
        preview_mgr.diff_cache[idx] = { lines = lines, extmarks = ext }
        preview_mgr.updating = false
        if preview_mgr.current_idx == idx then
          render_preview(lines, ext)
        end
        return
      end

      local diff_context = panel:get_config().diff_context or 3
      local diffs = diff.compute(resolved.edit, encoding, diff_context)
      if #diffs == 0 then
        local lines = { "No changes detected" }
        local ext =
          { { sign = { icon = glyph.ui.info, hl = "DiagnosticInfo" }, line_hl = "Comment", text_hl = "Comment" } }
        preview_mgr.diff_cache[idx] = { lines = lines, extmarks = ext }
        preview_mgr.updating = false
        if preview_mgr.current_idx == idx then
          render_preview(lines, ext)
        end
        return
      end

      local lines, ext, ft, code_info = diff.build_lines(diffs)
      preview_ft = ft
      preview_code_info = code_info
      preview_mgr.diff_cache[idx] = { lines = lines, extmarks = ext, ft = ft, code_info = code_info }
      preview_mgr.updating = false
      if preview_mgr.current_idx == idx then
        render_preview(lines, ext)
      end
    end)
  end, panel.buf)
end

function PreviewManager:clear_preview()
  local panel = self.panel
  if not panel.buf or not vim.api.nvim_buf_is_valid(panel.buf) then
    return
  end
  self.current_idx = 0
  local preview_start = self.list_end_line
  vim.bo[panel.buf].modifiable = true
  local total = vim.api.nvim_buf_line_count(panel.buf)
  if total > preview_start then
    vim.api.nvim_buf_set_lines(panel.buf, preview_start, total, false, {})
  end
  vim.bo[panel.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(panel.buf, vim.api.nvim_create_namespace "iflsp_diff_syntax", 0, -1)

  if panel:is_open() then
    local new_height = vim.api.nvim_buf_line_count(panel.buf)
    panel:resize_height(new_height)
  end
end

return PreviewManager
