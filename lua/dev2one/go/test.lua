local ts_utils = require'nvim-treesitter.ts_utils'
local parsers = require'nvim-treesitter.parsers'
local uvutil = require('dev2one.uvutil')
local cmd = require('dev2one.cmd')

local content = {}
content.__index = content
local gotest = {}
gotest.__index = gotest
local M = {}

local subtests_query = [[
(call_expression
  function: (selector_expression
    operand: (identifier)
    field: (field_identifier) @run)
  arguments: (argument_list
    (interpreted_string_literal) @testname
    (func_literal))
  (#eq? @run "Run")) @parent
]]

local tests_query = [[
(function_declaration
  name: (identifier) @testname
  parameters: (parameter_list
    . (parameter_declaration
      type: (pointer_type) @type) .)
  (#eq? @type "*testing.T")) @parent
]]

function content.new(opts)
  local o = {
    opts = opts,
    items = {}
  }
  setmetatable(o, content)
  return o
end

local function handle_opts(opts)
  local options =  {
    icon_test_fail = '🔴',
    icon_test_run = '🟡',
    icon_test_pass = '🟢',
    icon_test_skip = '🔵'
  }
  if opts then
    for k, v in pairs(opts) do
      options[k] = v
    end
  end
  return options
end

function gotest.new(opts)
  local options = handle_opts(opts)
  local c = content.new(options)
  local o = {
    opts = options,
    content = c,
    results = {}
  }
  setmetatable(o, gotest)
  return o
end

function content:status_icon(status)
  if status then
    if status == "pause" then return self.opts.icon_test_run
    elseif status == "cont" then return self.opts.icon_test_run
    elseif status == "run" then return self.opts.icon_test_run
    elseif status == "fail" then return self.opts.icon_test_fail
    elseif status == "pass" then return self.opts.icon_test_pass
    elseif status == "skip" then return self.opts.icon_test_skip
    end
  end
end

function content:update(results)
  local keys = vim.tbl_keys(results)
  table.sort(keys, function(a, b)
    return a < b
  end)
  self.items = {}
  for _, pkg_name in ipairs(keys) do
    local pkg = results[pkg_name]
    local text = string.format("%s %s %s", self:status_icon(pkg.status), pkg_name, pkg.elapsed)
    local entry = {
      text = text,
      pkg = pkg_name,
      status = pkg.status,
      elapsed = pkg.elapsed
    }

    table.insert(self.items, entry)
    if pkg.status == 'fail' then
      local test_found = false
      for test_name, test in pairs(pkg.tests) do
        if test.status == 'fail' and test.output and next(test.output) ~= nil then
          test_found = true
          text = string.format("\t%s", test_name)
          entry = vim.deepcopy(entry)
          entry.text = text
          entry.test = test_name
          entry.status = test.status
          entry.line = tonumber(test.line)
          table.insert(self.items, entry)

          for _, output in ipairs(test.output) do
            entry = vim.deepcopy(entry)
            entry.text = string.format("\t%s", output)
            local file, line = string.match(output, "%s*(%g+%.go):(%d+)%s.+")
            if file and line then
              entry.file = file
              entry.line = tonumber(line)
            end
            table.insert(self.items, entry)
          end
        end
      end
      -- this means that the package has errors but no test actually failed
      if not test_found then
        for _, out in ipairs(pkg.output) do
          text = string.format("\t%s", out)
          table.insert(self.items, { text=text })
        end
      end
    end
  end
end

function content:list()
  local lines = {}
  if self.title then
    table.insert(lines, self.title)
    table.insert(lines, "")
  end
  if self.items then
    for _, item in ipairs(self.items) do
      table.insert(lines, item.text)
    end
  end
  return lines
end

function content:get(line)
  return self.items[line-2]
end

function gotest:get_test_case()
  local test_tree = {}
  local w = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  local lang = parsers.get_buf_lang()
  local parser = parsers.get_parser()
  local root = parser:parse()[1]:root()
  local cur_node = ts_utils.get_node_at_cursor(w)

  local tq = vim.treesitter.parse_query(lang, tests_query)
  for _, match, _ in tq:iter_matches(root, buf) do
    local test_match = {}
    for id, node in pairs(match) do
      local capture = tq.captures[id]
      if capture == "testname" then
        local name = ts_utils.get_node_text(node)[1]
        test_match.name = name
      end
      if capture == "parent" then
        test_match.node = node
      end
    end
    if ts_utils.is_parent(test_match.node, cur_node) then
      table.insert(test_tree, test_match)
      break
    end
  end

  local stq = vim.treesitter.parse_query(lang, subtests_query)
  for _, match, _ in stq:iter_matches(root, buf) do
    local test_match = {}
    for id, node in pairs(match) do
      local capture = stq.captures[id]
      if capture == "testname" then
        local name = ts_utils.get_node_text(node)[1]
        test_match.name = string.gsub(string.gsub(name, ' ', '_'), '"', '')
      end
      if capture == "parent" then
        test_match.node = node
      end
    end
    if ts_utils.is_parent(test_match.node, cur_node) then
      table.insert(test_tree, test_match)
    end
  end

  table.sort(test_tree, function(a, b)
    return ts_utils.is_parent(a.node, b.node)
  end)
  local result
  for _, item in ipairs(test_tree) do
    if not result then
      result = item.name
    else
      result = result .. '/' .. item.name
    end
  end

  return result
end

function gotest:get_root_dir()
  local id, client = next(vim.lsp.buf_get_clients())
  if id == nil then
    error({error_msg="lsp client not attached"})
  end
  if not client.config.root_dir then
    error({error_msg="lsp root_dir not defined"})
  end
  return client.config.root_dir
end

function gotest:get_package_name(root_dir)
  local test_dir = vim.fn.expand('#'..vim.api.nvim_get_current_buf()..':p:h')
  local package_name = string.gsub(test_dir, root_dir, '.')
  return package_name
end

function gotest:clean_output(out)
  if not string.find(out, "%s*===.+") and not string.find(out, "%s*%-%-%-.+") then
    local file, line = string.match(out, "%s*(.+):(%d+):%s.+")
    return file, line, out
  end
end

function gotest:handle_output(test_event)
  assert(test_event)
  if not test_event.Package then
    return
  end
  local pkg = test_event.Package
  if self.results[pkg] == nil then
    self.results[pkg] = {
      status = '',
      elapsed = '',
      output = {},
      tests = {}
    }
  end
  if test_event.Elapsed and not test_event.Test then
    self.results[pkg].elapsed = test_event.Elapsed
  end
  if test_event.Action ~= 'output' and
    test_event.Action ~= 'bench' and
    self.results[pkg].status ~= 'fail' then
    self.results[pkg].status = test_event.Action
  end
  if test_event.Test then
    local test = test_event.Test
    if self.results[pkg].tests[test] == nil then
      self.results[pkg].tests[test] = {
        status = '',
        elapsed = '',
        output = {}
      }
    end
    if test_event.Action ~= 'output' then
      self.results[pkg].tests[test].status = test_event.Action
      if test_event.Elapsed then
        self.results[pkg].tests[test].elapsed = test_event.Elapsed
      end
    else
      local file, line_nr, output = self:clean_output(test_event.Output)
      if file then
        self.results[pkg].tests[test].file = file
      end
      if line_nr then
        self.results[pkg].tests[test].line = line_nr
      end

      if output then
        local lines = vim.split(output, "\n")
        for _, line in ipairs(lines) do
          if line ~= "" then
            table.insert(self.results[pkg].tests[test].output, line)
          end
        end
      end
    end
  else
    if test_event.Action == 'output' then
      local out = test_event.Output
      local lines = vim.split(out, "\n")
      for _, line in ipairs(lines) do
        if line ~= "" then
          table.insert(self.results[pkg].output, line)
        end
      end
    end
  end
end

function gotest:on_stdout(data, window)
  self.content:update(self.results)
  window.update(self.content:list())
  if data then
    local vals = vim.split(data, "\n")
    for _, d in ipairs(vals) do
      if d ~= "" then
        vim.schedule(
          function ()
            local test_event = vim.fn.json_decode(d)
            self:handle_output(test_event)
          end)
      end
    end
  end
end

function gotest:test(pkg_param)
  local ok, root_dir = pcall(self.get_root_dir, self)
  if not ok then
    print("[dev2one]: error getting root dir:", root_dir.error_msg)
    return
  end

  local winnr = vim.api.nvim_get_current_win()
  local opts = {
    main_win = winnr
  }
  local w = cmd.window.new(self.content, opts)

  local function on_done()
    --w.update(results)
    --print(vim.inspect(self.results))
  end

  local function on_stdout(err, data)
    if err then
      error('on_stdout error: ' .. err)
    end
    self:on_stdout(data, w)
  end

  local args = { "test" }

  if pkg_param then
    table.insert(args, pkg_param)
  else
    local package_name = self:get_package_name(root_dir)
    table.insert(args, package_name)
    local test_case = self:get_test_case()
    if test_case then
      table.insert(args, "-run")
      table.insert(args, test_case)
      self.content.title = "Running Test: " .. test_case
    else
      self.content.title = "Running Tests for Package: " .. package_name
    end
  end
  --local args = {
    --"test",
    --package_name,
    --"-count=1"
  --}
  table.insert(args, "-count=1")
  table.insert(args, "-json")
  w.open()
  uvutil.process("go", args, root_dir, on_done, on_stdout)
end

function M.gotest(pkg)
  local gt = gotest.new()
  gt:test(pkg)
end

return M
