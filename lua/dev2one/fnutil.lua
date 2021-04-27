local M = {}

local function map(buf, mode, lhs, rhs)
  local mapOpts = { noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(buf, mode, lhs, rhs, mapOpts)
end

function M.imap(buf, lhs, rhs)
  map(buf, 'i', lhs, rhs)
end

function M.nmap(buf, lhs, rhs)
  map(buf, 'n', lhs, rhs)
end

return M
