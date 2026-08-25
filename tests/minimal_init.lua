local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)

local plenary_candidates = {
  root .. "/.tests/plenary.nvim",
  vim.fn.stdpath "data" .. "/site/pack/vendor/start/plenary.nvim",
  vim.fn.stdpath "data" .. "/lazy/plenary.nvim",
}
for _, path in ipairs(plenary_candidates) do
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.runtimepath:prepend(path)
    break
  end
end

vim.o.termguicolors = true
vim.o.swapfile = false

vim.cmd "runtime plugin/plenary.vim"
require "plenary.busted"
