local window = require('dev2one.win')
local content = require('dev2one.content')

local function document_symbol(err, _, result, _, bufnr)
  assert(not err, err)
  local winnr = vim.api.nvim_get_current_win()
  local c = content.from_document_symbol(result, bufnr)

  local opt = {
    main_win = winnr,
    main_buf = bufnr
  }
  local w = window.new(c, opt)
  w.open()
end

return {
  document_symbol=document_symbol
}
