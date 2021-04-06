local fzy = require('dev2one.vendor.fzy-lua')
local storage = require('dev2one.storage')
local api = vim.api
local win = {}
win.__index = win
local Win = {}

function win.new(content, opt)
  local w = {}
  w.opt = opt or {}
  w.prompt = {}
  w.list = {}
  w.border = {}
  w.split = {}
  w.preview = {}
  w.content = content
  setmetatable(w, win)
  return w
end

function win:_with_border(opts)
  self.border.buf = api.nvim_create_buf(false, true)
  self.border.left_line_size = math.ceil((opts.width-2)/2)
  self.border.right_line_size = opts.width - 2 - self.border.left_line_size - 1
  local left_line = string.rep('─', self.border.left_line_size)
  local right_line = string.rep('─', self.border.right_line_size)
  local top_line = '╭'..left_line..'┬'..right_line..'╮'
  local border_lines = { top_line }
  local middle_line = '│' .. string.rep(' ', opts.width-2) .. '│'
  for _=1, opts.height-2 do
    table.insert(border_lines, middle_line)
  end
  local bottom_line = '╰'..left_line..'┴'..right_line..'╯'
  table.insert(border_lines, bottom_line)
  api.nvim_buf_set_lines(self.border.buf, 0, -1, false, border_lines)
  api.nvim_buf_set_option(self.border.buf, 'modifiable', false)
  api.nvim_buf_set_option(self.border.buf, 'bufhidden', 'wipe')
  self.border.win = api.nvim_open_win(self.border.buf, false, opts)
  api.nvim_win_set_option(self.border.win, 'winhighlight', 'NormalFloat:Normal')
  return self.border.buf, self.border.win
end

function win:_with_list(content, opts)
  self.list.content = content
  self.list.buf = api.nvim_create_buf(false, true)
  local selection_char = '▶'
  api.nvim_buf_set_option(self.list.buf, 'bufhidden', 'wipe')
  self.list.win = api.nvim_open_win(self.list.buf, true, opts)
  api.nvim_win_set_option(self.list.win, 'cursorline', true)
  api.nvim_win_set_option(self.list.win, 'signcolumn', 'yes')
  api.nvim_win_set_option(self.list.win, 'winhighlight', 'NormalFloat:Normal')
  vim.fn.sign_define('dev2one-curline', {text=selection_char})
end

function win:_with_preview(opts)
  local split_char = '│'
  local split_lines = {}
  for _=1, opts.height do
    table.insert(split_lines, split_char)
  end
  self.split.buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(self.split.buf, 0, -1, false, split_lines)
  local split_opts = vim.deepcopy(opts)
  split_opts.width = 1
  self.split.win = api.nvim_open_win(self.split.buf, false, split_opts)
  api.nvim_win_set_option(self.split.win, 'winhighlight', 'NormalFloat:Normal')

  local preview_opts = vim.deepcopy(opts)
  preview_opts.width = preview_opts.width-1
  preview_opts.col = preview_opts.col+1
  self.preview.win = api.nvim_open_win(self.opt.main_buf, true, preview_opts)
  api.nvim_win_set_option(self.preview.win, 'cursorline', true)
  api.nvim_win_set_option(self.preview.win, 'winhighlight', 'NormalFloat:Normal')
end

function win:_with_prompt(opts)
  self.prompt.buf = api.nvim_create_buf(false, true)
  local prompt_char = '% '
  api.nvim_buf_set_option(self.prompt.buf, 'buftype', 'prompt')
  vim.fn.prompt_setprompt(self.prompt.buf, prompt_char)
  api.nvim_buf_set_option(self.prompt.buf, 'bufhidden', 'wipe')
  self.prompt.win = api.nvim_open_win(self.prompt.buf, true, opts)
  api.nvim_win_set_option(self.prompt.win, 'winhighlight', 'NormalFloat:Normal')
  local mapOpts = { noremap = true, silent = true }
  api.nvim_buf_set_keymap(self.prompt.buf, 'i', '<CR>', "<cmd>lua require'dev2one'.window.select()<CR>", mapOpts)
  api.nvim_buf_set_keymap(self.prompt.buf, 'i', '<C-k>', "<cmd>lua require'dev2one'.window.previous()<CR>", mapOpts)
  api.nvim_buf_set_keymap(self.prompt.buf, 'i', '<C-j>', "<cmd>lua require'dev2one'.window.next()<CR>", mapOpts)
  local function on_lines(_, _, _, first_line, last_line)
    self:_on_lines(first_line, last_line, prompt_char)
  end
  api.nvim_buf_attach(self.prompt.buf, false, { on_lines=on_lines })
  api.nvim_command('startinsert')
end

function win:_on_lines(first_line, last_line, prompt_char)
  local prompt = api.nvim_buf_get_lines(self.prompt.buf, first_line, last_line, false)
  prompt = string.sub(prompt[1], #prompt_char+1)
  if prompt == '' then
    vim.schedule(function() self:_update(self.list.content) end)
    return
  end
  local results = fzy.filter(prompt, self.list.content)
  local lines = {}
  table.sort(results, function(a, b) return a[3] > b[3] end)
  for _, result in ipairs(results) do
    local line = self.list.content[result[1]]
    table.insert(lines, line)
  end
  vim.schedule(function() self:_update(lines) end)
end

function win:_with_cleaner()
  api.nvim_set_current_buf(self.prompt.buf)
  local on_ins_leave = [[au InsertLeave <buffer> :lua require'dev2one'.window.delete()]]
  api.nvim_command('augroup dev2oneCleanWin')
  api.nvim_command('  autocmd!')
  api.nvim_command(   on_ins_leave)
  api.nvim_command('augroup END')
end

function win:open()
  local function win_opts(w, h, r, c)
    return {
      style = "minimal",
      relative = "editor",
      focusable = true,
      width = w,
      height = h,
      row = r,
      col = c
    }
  end
  local width = vim.o.columns
  local height = vim.o.lines

  local win_height = math.ceil(height * 0.9 - 4)
  local win_width = math.ceil(width * 0.9)
  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)
  assert(win_height>0, "not enough area to draw window")
  assert(win_width>20, "not enough area to draw window")

  local list_opts = win_opts(win_width, win_height-1, row, col)
  local prompt_opts = win_opts(math.floor(win_width/2), 1, row + win_height - 1, col)
  local border_opts = win_opts(win_width+2, win_height+2, row-1, col-1)
  local preview_opts = win_opts(math.floor(win_width/2), win_height, row, col+math.ceil(win_width/2))

  self:_with_preview(preview_opts)
  self:_with_list(self.content:list(), list_opts)
  self:_with_prompt(prompt_opts)
  self:_with_border(border_opts)
  self:_with_cleaner()
  api.nvim_set_current_buf(self.prompt.buf)
end

function win:_update(content)
  api.nvim_buf_set_option(self.list.buf, 'modifiable', true)

  -- if list buffer had previous content then clean up first
  if self.cur_content then
    api.nvim_buf_set_lines(self.list.buf, 0, -1, false, {})
  end
  if next(content) ~= nil then
    api.nvim_buf_set_lines(self.list.buf, 0, -1, false, content)
    api.nvim_buf_set_option(self.list.buf, 'modifiable', false)
    self.cur_content = content
    api.nvim_win_set_cursor(self.list.win, {1,0})
    vim.fn.sign_unplace('', {buffer=self.list.buf, id='dev2one-curline'})
    vim.fn.sign_place(0, '', 'dev2one-curline', self.list.buf, {lnum=1})
    self:_update_preview()
  end
end

function win:previous()
  local pos = api.nvim_win_get_cursor(self.list.win)
  if pos[1] == 1 then
    return
  end
  vim.fn.sign_unplace('', {buffer=self.list.buf, id='dev2one-curline'})
  vim.fn.sign_place(0, '', 'dev2one-curline', self.list.buf, {lnum=pos[1]-1})
  api.nvim_win_set_cursor(self.list.win, {pos[1]-1,0})
  self:_update_preview()
end

function win:next()
  local pos = api.nvim_win_get_cursor(self.list.win)
  local total_lines = api.nvim_buf_line_count(self.list.buf)
  if pos[1] == total_lines then
    return
  end
  vim.fn.sign_unplace('', {buffer=self.list.buf, id='dev2one-curline'})
  vim.fn.sign_place(0, '', 'dev2one-curline', self.list.buf, {lnum=pos[1]+1})
  api.nvim_win_set_cursor(self.list.win, {pos[1]+1,0})
  self:_update_preview()
end

function win:_update_preview()
  if self.preview.win == nil or not api.nvim_win_is_valid(self.preview.win) then
    return
  end
  local preview_pos = self:_target_pos()
  api.nvim_win_set_cursor(self.preview.win, preview_pos)
end

function win:select()
  local pos = self:_target_pos()
  api.nvim_win_set_cursor(self.opt.main_win, pos)
  api.nvim_set_current_win(self.opt.main_win)
  api.nvim_command('normal z.')
  api.nvim_command('stopinsert')
  self:delete()
end

function win:_target_pos()
  local pos = api.nvim_win_get_cursor(self.list.win)
  local key = api.nvim_buf_get_lines(self.list.buf, pos[1]-1, pos[1], false)
  local details = self.content:get(key[1])
  return {details.line,0}
end

function win:delete()
  local bufs = string.format("%s %s %s %s", self.list.buf, self.prompt.buf, self.border.buf, self.split.buf)
  api.nvim_command('silent bwipeout! '..bufs)
  vim.api.nvim_win_close(self.preview.win, false)
end

local function _get_instance()
  assert(Win.id~=nil, "win error: M.id is nil")
  return storage.get(Win.id)
end

function Win.new(...)
  local w = win.new(...)
  Win.id = storage.save(w)
  return Win
end

function Win.open()
  local instance = _get_instance()
  instance:open()
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
  storage.delete(Win.id)
  instance:select()
end

function Win.delete()
  local instance = _get_instance()
  storage.delete(Win.id)
  instance:delete()
end

return Win
