local window = require('dev2one.win')
local cmd = require('dev2one.cmd')
local handlers = require('dev2one.handlers')
local uvutil = require('dev2one.uvutil')
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

function M.gotest()
  local results = {}
  local c = {}

  function c.list()
    local list = {}
    for k,v in pairs(results) do
      local str = string.format("[%s] %s %s", v.status, k, v.elapsed)
      table.insert(list, str)
      if v.status == 'fail' then
        for test, values in pairs(v.tests) do
          if values.status == 'fail' then
            str = string.format("\t%s", test)
            table.insert(list, str)
            if values.error then
              local err = string.format("file: %s line: %s error: %s", values.file, values.line, values.error)
              table.insert(list, string.format("\t\t%s", err))
            end
            --for _, output in ipairs(values.output) do
              --local lines = vim.split(output, '[\r]?\n')
              --for _, line in ipairs(lines) do
                --if line ~= '' then
                  --table.insert(list, string.format("\t\t%s", line))
                --end
              --end
            --end
          end
        end
      end
    end
    return list
  end

  local w = cmd.window.new(c)
  w.open()

  local function on_done()
    --w.update(results)
  end

  local function handle_gotest(test_event)
    assert(test_event)
    if not test_event.Package then
      return
    end
    dump(test_event)
    local pkg = test_event.Package
    if results[pkg] == nil then
      results[pkg] = {
        status = '',
        elapsed = '',
        tests = {}
      }
    end
    if test_event.Elapsed and not test_event.Test then
      results[pkg].elapsed = test_event.Elapsed
    end
    if test_event.Action ~= 'output' and
      test_event.Action ~= 'bench' and
      results[pkg].status ~= 'fail' then
      results[pkg].status = test_event.Action
    end
    if test_event.Test then
      local test = test_event.Test
      if results[pkg].tests[test] == nil then
        results[pkg].tests[test] = {
          status = '',
          elapsed = '',
          output = {}
        }
      end
      if test_event.Action ~= 'output' then
        results[pkg].tests[test].status = test_event.Action
        if test_event.Elapsed then
          results[pkg].tests[test].elapsed = test_event.Elapsed
        end
      else
        local out = test_event.Output
        if not string.find(out, "===") and not string.find(out, "---") then
          local file, line, err = string.match(out, "%s*(.+):(%d+):%s([%g%s]+)")
          if file and line and err then
            results[pkg].tests[test].file = file
            results[pkg].tests[test].line = line
            results[pkg].tests[test].error = err:gsub("[\n\r]", "")
          end
        end
        table.insert(results[pkg].tests[test].output, test_event.Output)
      end
    end
  end

  local function on_stdout(err, data)
    w.update(c.list())
    if err then
      error('on_stdout error: ' .. err)
    end
    if data then
      local vals = vim.split(data, "\n")
      for _, d in pairs(vals) do
        if d ~= "" then
          vim.schedule(
            function ()
              local test_event = vim.fn.json_decode(d)
              handle_gotest(test_event)
            end)
        end
      end
    end
  end

  local args = {
    "test",
    --"./internal/pkg/...",
    "./internal/pkg/datastore",
    "-count=1",
    --"-run",
    --"TestPubSubBasic",
    "-json"
  }
  uvutil.process("go", args, "/Users/leoluz/dev/git/dw/saas_app", on_done, on_stdout)
end

M.window = cmd.window
M.handlers = handlers
return M
