local window = require('dev2one.win')
local content = require('dev2one.content')
local M = {}

function M.document_symbol(err, _, result, _, bufnr)
  assert(not err, err)
  local winnr = vim.api.nvim_get_current_win()
  local c = content.from_document_symbol(result, bufnr)
  local opts = {
    main_win = winnr,
    main_buf = bufnr
  }
  local w = window.new(c, opts)
  w.open()
end


function M.document_references(err, _, result, _, bufnr)
  assert(not err, err)
  local winnr = vim.api.nvim_get_current_win()
  local c = content.from_document_references(result)
  local opts = {
    main_win = winnr,
    main_buf = bufnr
  }
  local w = window.new(c, opts)
  w.open()
end

return M
