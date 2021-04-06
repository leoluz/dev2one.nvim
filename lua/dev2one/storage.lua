local storage = {}
local M = {}

function M.get_id(obj)
  return string.format("%p", obj)
end

function M.save(obj)
  assert(obj~=nil, "error saving in storage: t is nil")
  local id = M.get_id(obj)
  if storage == nil then
    storage = {}
  end
  storage[id] = obj
  return id
end

function M.get(id)
  assert(id~=nil, "error getting from storage: id is nil")
  assert(storage~=nil, "storage is nil")
  return storage[id]
end

function M.delete(id)
  assert(id~=nil, "error deleting from storage: id is nil")
  assert(storage~=nil, "storage is nil")
  storage[id] = nil
end

return M
