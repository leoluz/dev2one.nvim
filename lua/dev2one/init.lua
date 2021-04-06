local window = require('dev2one.win')
local handlers = require('dev2one.handlers')
local uv = vim.loop
local M = {}
local LS = {}

function LS:new(o)
  local obj = o or {}
  setmetatable(obj, self)
  self.__index = self
  obj.results = {}
  return obj
end

function LS:onStderr (err, data)
  if err then
    error('onStderr error: ' .. err)
  end
  if data then
    self.err = data
  end
end

function LS:onStdout (err, data)
  if err then
    error('onStdout error: ' .. err)
  end
  if data then
    local vals = vim.split(data, "\n")
    for _, d in pairs(vals) do
      if d ~= "" then
        table.insert(self.results, d)
      end
    end
  end
end

function LS:showResults()
  if self.err then
    error("List error: " .. self.err)
  end
  window.show(self.results)
end

function LS:execute(dir)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  Handle = uv.spawn('ls', {
      args = {'-l', dir},
      stdio = {nil, stdout, stderr}
    },
    vim.schedule_wrap(
      function()
        stdout:read_stop()
        stderr:read_stop()
        stdout:close()
        stderr:close()
        Handle:close()
        self:showResults()
      end
    )
  )
  uv.read_start(stdout, function(err, data)
    self:onStdout(err, data)
  end)
  uv.read_start(stderr, function(err, data)
    self:onStderr(err, data)
  end)
end

function M.list(dir)
  local ls = LS:new()
  ls:execute(dir)
end

M.window = window
M.handlers = handlers
return M
