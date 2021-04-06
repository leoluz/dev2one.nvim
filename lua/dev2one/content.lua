local content = {}

local function new()
  local o = {}
  o.items = {}
  setmetatable(o, content)
  content.__index = content
  return o
end

function content.from_document_symbol(result, bufnr)
  local instance = new()
  local filepath = vim.fn.expand('#'..bufnr..':p')
  for _, doc in ipairs(result) do
    local kind = vim.lsp.protocol.SymbolKind[doc.kind]
    local line = doc.selectionRange.start.line + 1
    local key = kind.." "..doc.name
    local value = {
      filepath = filepath,
      detail = doc.detail,
      kind = kind,
      name = doc.name,
      line = line
    }
    instance.items[key] = value
  end
  table.sort(instance.items, function(a, b) return a.kind..a.name < b.kind..b.name end)
  return instance
end

function content:list()
  local list = vim.tbl_keys(self.items)
  table.sort(list)
  return list
end

function content:get(key)
  return self.items[key]
end

return content
