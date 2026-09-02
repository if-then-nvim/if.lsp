local M = {}

---@param bufnr integer
---@param method string
---@param make_params fun(client: vim.lsp.Client): table
---@param is_useful fun(result: any): boolean
---@param on_result fun(result: any, client: vim.lsp.Client)
---@param on_none? fun()
function M.request_first(bufnr, method, make_params, is_useful, on_result, on_none)
  local clients = vim.lsp.get_clients { bufnr = bufnr, method = method }

  local function try(i)
    local client = clients[i]
    if not client then
      if on_none then
        on_none()
      end
      return
    end

    local sent = client:request(method, make_params(client), function(err, result)
      if err or not is_useful(result) then
        try(i + 1)
        return
      end
      on_result(result, client)
    end, bufnr)

    if not sent then
      try(i + 1)
    end
  end

  try(1)
end

return M
