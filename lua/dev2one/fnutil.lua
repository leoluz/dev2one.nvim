local M = {}

function M.imap(buf, lhs, rhs)
  local mapOpts = { noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(buf, 'i', lhs, rhs, mapOpts)
end

return M
