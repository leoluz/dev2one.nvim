local cmd = require('dev2one.cmd')
local handlers = require('dev2one.handlers')
local test = require('dev2one.go.test')
local M = {}

M.gotest = test.gotest
M.window = cmd.window
M.handlers = handlers
return M
