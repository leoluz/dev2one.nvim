local cmd = require('dev2one.cmd')
local content = require('dev2one.content')
local M = {}

local function handle(err, result, bufnr, content_fn)
  assert(not err, err)
  local winnr = vim.api.nvim_get_current_win()
  local c = content_fn(result, bufnr)
  local opts = {
    main_win = winnr,
    main_buf = bufnr,
    with_preview = true,
    with_prompt = true
  }
  local w = cmd.window.new(c, opts)
  w.open()
end

function M.document_symbol(err, _, result, _, bufnr)
  if result ~= nil then
    handle(err, result, bufnr, content.from_document_symbol)
  end
end

function M.document_references(err, _, result, _, bufnr)
  if result ~= nil then
    handle(err, result, bufnr, content.from_document_references)
  end
end

function M.document_implementation(err, _, result, _, bufnr)
  if result ~= nil then
    handle(err, result, bufnr, content.from_document_implementation)
  end
end

return M
