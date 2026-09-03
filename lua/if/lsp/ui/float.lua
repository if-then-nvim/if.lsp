local extmarks = require "if.lsp.ui.extmarks"
local meta_ui = require "if.lsp.ui.meta"
local scrollbar = require "if.lsp.ui.scrollbar"
local window = require "if.lsp.ui.window"

---@class IfLsp.FloatPanel
local FloatPanel = {}
FloatPanel.__index = FloatPanel

function FloatPanel:new(name)
  return setmetatable({
    name = name,
    win = nil,
    buf = nil,
    source_bufnr = nil,
    augroup = nil,
    _enter = false,
    _place = nil,
  }, self)
end

function FloatPanel:is_open()
  return self.win ~= nil and vim.api.nvim_win_is_valid(self.win)
end

function FloatPanel:close()
  local win, buf = self.win, self.buf
  local augroup = self.augroup
  local source = self.source_bufnr
  self.win = nil
  self.buf = nil
  self.source_bufnr = nil
  self.augroup = nil
  self._place = nil

  if source and vim.api.nvim_buf_is_valid(source) then
    pcall(vim.diagnostic.enable, true, { bufnr = source })
  end

  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, vim.api.nvim_create_namespace "iflsp_diff_syntax", 0, -1)
  end
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  if augroup then
    pcall(vim.api.nvim_del_augroup_by_id, augroup)
  end
end

function FloatPanel:show(source_bufnr, ...)
  self:close()
  self.source_bufnr = source_bufnr

  local lines, ext_list = self:build_content(...)
  if not lines or #lines == 0 then
    return
  end

  self:open_win(lines)
  if not self:is_open() then
    return
  end

  local cfg = self:get_config()
  if cfg.hide_diagnostic then
    vim.diagnostic.enable(false, { bufnr = source_bufnr })
  end

  self:apply_extmarks(ext_list, lines)

  self:setup_keymaps()
  self:setup_autocmds()
  self:after_open()
end

function FloatPanel:open_win(lines)
  local cfg = self:get_config()
  local win_opts = window.compute(lines, {
    max_width = cfg.max_width,
    max_height = cfg.max_height,
    pad_right = cfg.pad_right,
    min_width = cfg.min_width,
    min_height = cfg.min_height,
    extra_height = cfg.extra_height,
  })

  local enter = cfg.enter or false
  self._enter = enter

  local place = self:placement(win_opts.width, win_opts.height)
  self._place = place
  self.win = vim.api.nvim_open_win(self.buf, enter, {
    relative = "cursor",
    row = place.row,
    col = place.col,
    anchor = place.anchor,
    width = win_opts.width,
    height = place.height,
    border = cfg.border,
    style = "minimal",
  })

  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:IfLspNormal,FloatBorder:IfLspBorder,SignColumn:IfLspNormal",
    { win = self.win }
  )
  vim.api.nvim_set_option_value("signcolumn", "yes", { win = self.win })
  vim.api.nvim_set_option_value("wrap", true, { win = self.win })

  -- An editable panel is one the user types into; the rest are read-only and
  -- kick you back out of insert mode if you land there by accident.
  if cfg.editable then
    vim.bo[self.buf].modifiable = true
  else
    vim.bo[self.buf].modifiable = false
    vim.api.nvim_create_autocmd("InsertEnter", {
      buffer = self.buf,
      callback = function()
        vim.cmd.stopinsert()
      end,
    })
  end

  if cfg.conceal then
    vim.api.nvim_set_option_value("conceallevel", 2, { win = self.win })
    vim.api.nvim_set_option_value("concealcursor", "niv", { win = self.win })
  end

  if cfg.cursorline then
    vim.api.nvim_set_option_value("cursorline", true, { win = self.win })
  end

  if enter then
    vim.api.nvim_set_current_win(self.win)
  end
end

function FloatPanel:apply_extmarks(ext_list, lines)
  extmarks.apply(self.buf, "iflsp_" .. self.name, ext_list, lines, 0)
end

function FloatPanel:setup_keymaps()
  local cfg = self:get_config()
  local panel = self
  vim.api.nvim_buf_set_keymap(self.buf, "n", cfg.close_key, "", {
    callback = function()
      panel:close()
    end,
    nowait = true,
  })
end

function FloatPanel:setup_autocmds()
  local cfg = self:get_config()
  local panel = self
  local augroup = vim.api.nvim_create_augroup("iflsp_" .. self.name .. "_close", { clear = true })
  self.augroup = augroup

  for _, event in ipairs(cfg.close_events) do
    vim.api.nvim_create_autocmd(event, {
      group = augroup,
      buffer = self.source_bufnr,
      once = true,
      callback = function()
        panel:close()
      end,
    })
  end

  local total_lines = vim.api.nvim_buf_line_count(self.buf)
  local win_height = vim.api.nvim_win_get_height(self.win)
  local scrollable = total_lines > win_height

  if scrollable and cfg.scroll_indicator then
    scrollbar.update(self.win, total_lines)
    vim.api.nvim_create_autocmd("WinScrolled", {
      group = augroup,
      callback = function()
        if panel:is_open() then
          scrollbar.update(panel.win, vim.api.nvim_buf_line_count(panel.buf))
        end
      end,
    })
  end

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    pattern = tostring(self.win),
    once = true,
    callback = function()
      panel:close()
    end,
  })
end

function FloatPanel:resize(w, h)
  if not self:is_open() then
    return
  end
  vim.api.nvim_win_set_config(self.win, { width = w, height = h })
end

---Height only. The width a panel opens at is the width it keeps: letting the
---preview recompute it meant the window changed size under the cursor as you
---moved between actions that carry a diff and ones that do not.
---@param h integer
function FloatPanel:resize_height(h)
  if not self:is_open() then
    return
  end
  local place = self._place
  if not place then
    vim.api.nvim_win_set_config(self.win, { height = h })
    return
  end
  -- Height and nothing else. The window is positioned relative to the cursor,
  -- and once you are inside the panel the cursor is one of its own lines — so
  -- passing relative again re-anchors it to wherever the selection has got to
  -- and the panel walks down the screen as you move through the list.
  vim.api.nvim_win_set_config(self.win, { height = math.max(1, math.min(h, place.room)) })
end

---Where the window goes, given how big it wants to be.
---
---A float anchored a line under the cursor has nowhere to grow once the
---cursor is near the bottom of the screen: it opens clipped and stays that
---way however tall the content gets. So the side with more room wins, and
---the height is trimmed to whatever that side actually has.
---@param width integer
---@param height integer
---@return { row: integer, col: integer, anchor: string, height: integer }
function FloatPanel:placement(width, height)
  local border = (self:get_config().border or "none") ~= "none" and 2 or 0
  local screen_row = vim.fn.winline() + vim.fn.win_screenpos(0)[1] - 1
  local screen_col = vim.fn.wincol() + vim.fn.win_screenpos(0)[2] - 1
  local total_rows = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)

  local below = total_rows - screen_row - border
  local above = screen_row - 1 - border

  local row, anchor, room
  if height <= below or below >= above then
    row, anchor, room = 1, "NW", below
  else
    row, anchor, room = 0, "SW", above
  end
  room = math.max(room, 1)

  -- Keep the right edge on screen; a panel wider than the terminal starts at
  -- column one rather than off the left of it.
  local col = 0
  local overflow = (screen_col + width + border) - vim.o.columns
  if overflow > 0 then
    col = -math.min(overflow, screen_col - 1)
  end

  return { row = row, col = col, anchor = anchor, height = math.min(height, room), room = room }
end

function FloatPanel:append_lines(lines)
  if not self.buf or not vim.api.nvim_buf_is_valid(self.buf) then
    return
  end
  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, -1, -1, false, lines)
  vim.bo[self.buf].modifiable = false
end

function FloatPanel:get_config()
  return require("if.lsp.config").get()[self.name] or {}
end

function FloatPanel:build_meta(server_name, code)
  local cfg = self:get_config()
  local meta = meta_ui.build(self.source_bufnr, server_name, code, cfg)
  return meta_ui.to_lines(meta)
end

function FloatPanel:build_content(_)
  return {}, {}
end

function FloatPanel:after_open() end

return FloatPanel
