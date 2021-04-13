local storage = require('dev2one.storage')
local win = require('dev2one.win')
local Win = {}
local M = {}

local function _get_instance()
  assert(Win.id~=nil, "win error: M.id is nil")
  return storage.get(Win.id)
end

function Win.new(...)
  local w = win.new(...)
  Win.id = w.id
  return Win
end

function Win.open()
  local instance = _get_instance()
  instance:open()
end

function Win.update(...)
  local instance = _get_instance()
  instance:update(...)
end

function Win.previous()
  local instance = _get_instance()
  instance:previous()
end

function Win.next()
  local instance = _get_instance()
  instance:next()
end

function Win.select()
  local instance = _get_instance()
  instance:select()
end

function Win.delete()
  local instance = _get_instance()
  instance:delete()
end

function Win.prev_pagedown()
  local instance = _get_instance()
  instance:prev_pagedown()
end

function Win.prev_pageup()
  local instance = _get_instance()
  instance:prev_pageup()
end

function Win.prev_lineup()
  local instance = _get_instance()
  instance:prev_lineup()
end

function Win.prev_linedown()
  local instance = _get_instance()
  instance:prev_linedown()
end

function Win.prev_scrollright()
  local instance = _get_instance()
  instance:prev_scrollright()
end

function Win.prev_scrollleft()
  local instance = _get_instance()
  instance:prev_scrollleft()
end

M.window = Win

return M
