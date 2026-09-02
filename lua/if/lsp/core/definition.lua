local M = {}

local lsp = require "if.lsp.util.lsp"

function M.goto_definition()
  local cfg = require("if.lsp.config").get()

  vim.cmd "normal! m'"

  local from_bufnr = vim.api.nvim_get_current_buf()
  local from_pos = vim.api.nvim_win_get_cursor(0)
  local from_word = vim.fn.expand "<cword>"

  lsp.request_first(from_bufnr, "textDocument/definition", function(client)
    return vim.lsp.util.make_position_params(0, client.offset_encoding or "utf-16")
  end, function(result)
    if not result then
      return false
    end
    if vim.islist(result) then
      return #result > 0
    end
    return true
  end, function(result)
    local item = vim.islist(result) and result[1] or result
    local uri = item.targetUri or item.uri
    local range = item.targetSelectionRange or item.targetRange or item.range

    if not uri or not range then
      vim.notify("No definition found", vim.log.levels.INFO)
      return
    end

    local target_bufnr = vim.uri_to_bufnr(uri)
    vim.fn.bufload(target_bufnr)

    if cfg.definition.tagstack then
      local tagstack = { { tagname = from_word, from = { from_bufnr, from_pos[1], from_pos[2] + 1, 0 } } }
      vim.fn.settagstack(vim.fn.win_getid(), { items = tagstack }, "t")
    end

    local target_lnum = range.start.line
    local target_col = range.start.character

    if target_bufnr ~= vim.api.nvim_get_current_buf() then
      vim.api.nvim_set_current_buf(target_bufnr)
    end
    vim.api.nvim_win_set_cursor(0, { target_lnum + 1, target_col })

    vim.schedule(function()
      require("if.lsp.ui.beacon").beacon(target_bufnr, target_lnum, target_col)
    end)
  end, function()
    vim.notify("No definition found", vim.log.levels.INFO)
  end)
end

return setmetatable(M, {
  __call = function(_)
    return M.goto_definition()
  end,
})
