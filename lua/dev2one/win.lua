local fzy = require('dev2one.vendor.fzy-lua')
local uvutil = require('dev2one.uvutil')
local fnutil = require('dev2one.fnutil')
local storage = require('dev2one.storage')
local api = vim.api
local win = {}
win.__index = win

function win.new(content, opts)
  local w = {
    opts = opts or {},
    prompt = {},
    list = {},
    border = {},
    split = {},
    preview = {},
    content = content
  }
  setmetatable(w, win)
  w.id = storage.save(w)
  return w
end

function win:_with_border(opts)
  self.border.buf = api.nvim_create_buf(false, true)
  local horizontal_top_line = ''
  local horizontal_bottom_line = ''
  if self.opts.with_preview then
    self.border.left_line_size = math.ceil((opts.width-2)/2)
    self.border.right_line_size = opts.width - 2 - self.border.left_line_size - 1
    local left_line = string.rep('─', self.border.left_line_size)
    local right_line = string.rep('─', self.border.right_line_size)
    horizontal_top_line = left_line..'┬'..right_line
    horizontal_bottom_line = left_line..'┴'..right_line
  else
    horizontal_top_line = string.rep('─', opts.width-2)
    horizontal_bottom_line = string.rep('─', opts.width-2)
  end
  local top_line = '╭'..horizontal_top_line..'╮'
  local border_lines = { top_line }
  local middle_line = '│' .. string.rep(' ', opts.width-2) .. '│'
  for _=1, opts.height-2 do
    table.insert(border_lines, middle_line)
  end
  local bottom_line = '╰'..horizontal_bottom_line..'╯'
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
  api.nvim_buf_set_option(self.list.buf, 'bufhidden', 'wipe')
  self.list.win = api.nvim_open_win(self.list.buf, true, opts)
  api.nvim_win_set_option(self.list.win, 'cursorline', true)
  api.nvim_win_set_option(self.list.win, 'signcolumn', 'yes')
  api.nvim_win_set_option(self.list.win, 'winhighlight', 'NormalFloat:Normal')
  local selection_char = '▶'
  vim.fn.sign_define('dev2one-curline', {text=selection_char})
  vim.schedule(function() self:update(content) end)
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
  self.preview.buf = api.nvim_create_buf(false, true)
  preview_opts.width = preview_opts.width-1
  preview_opts.col = preview_opts.col+1
  self.preview.opts = preview_opts
  self.preview.win = api.nvim_open_win(self.preview.buf, true, preview_opts)
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

  fnutil.imap(self.prompt.buf, '<CR>', "<cmd>lua require'dev2one'.window.select()<CR>")
  fnutil.imap(self.prompt.buf, '<C-k>', "<cmd>lua require'dev2one'.window.previous()<CR>")
  fnutil.imap(self.prompt.buf, '<C-j>', "<cmd>lua require'dev2one'.window.next()<CR>")
  fnutil.imap(self.prompt.buf, '<C-f>', "<cmd>lua require'dev2one'.window.prev_pagedown()<CR>")
  fnutil.imap(self.prompt.buf, '<C-b>', "<cmd>lua require'dev2one'.window.prev_pageup()<CR>")
  fnutil.imap(self.prompt.buf, '<C-y>', "<cmd>lua require'dev2one'.window.prev_lineup()<CR>")
  fnutil.imap(self.prompt.buf, '<C-e>', "<cmd>lua require'dev2one'.window.prev_linedown()<CR>")
  fnutil.imap(self.prompt.buf, '<C-l>', "<cmd>lua require'dev2one'.window.prev_scrollright()<CR>")
  fnutil.imap(self.prompt.buf, '<C-h>', "<cmd>lua require'dev2one'.window.prev_scrollleft()<CR>")

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
    return
  end
  local results = fzy.filter(prompt, self.list.content)
  local lines = {}
  table.sort(results, function(a, b) return a[3] > b[3] end)
  for _, result in ipairs(results) do
    local line = self.list.content[result[1]]
    table.insert(lines, line)
  end
  vim.schedule(function() self:update(lines) end)
end

function win:_with_cleaner()
  api.nvim_set_current_buf(self.prompt.buf)
  local on_ins_leave = [[au InsertLeave <buffer> :lua require'dev2one'.window.delete()]]
  local on_buf_leave = [[au BufLeave <buffer> :lua require'dev2one'.window.delete()]]
  api.nvim_command('augroup dev2oneCleanWin')
  api.nvim_command('  autocmd!')
  api.nvim_command(   on_ins_leave)
  api.nvim_command(   on_buf_leave)
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

  local panel_width = win_width
  if self.opts.with_preview then
    panel_width = math.floor(win_width/2)
    local preview_opts = win_opts(panel_width, win_height, row, col+math.ceil(win_width/2))
    self:_with_preview(preview_opts)
  end

  local list_opts = win_opts(panel_width, win_height-1, row, col)
  self:_with_list(self.content:list(), list_opts)

  if self.opts.with_prompt then
    local prompt_opts = win_opts(panel_width, 1, row + win_height - 1, col)
    self:_with_prompt(prompt_opts)
  end

  local border_opts = win_opts(win_width+2, win_height+2, row-1, col-1)
  self:_with_border(border_opts)

  self:_with_cleaner()
  api.nvim_set_current_buf(self.prompt.buf)
end

function win:previous()
  local pos = api.nvim_win_get_cursor(self.list.win)
  if pos[1] == 1 then
    return
  end
  vim.fn.sign_unplace('', {buffer=self.list.buf, id='dev2one-curline'})
  vim.fn.sign_place(0, '', 'dev2one-curline', self.list.buf, {lnum=pos[1]-1})
  api.nvim_win_set_cursor(self.list.win, {pos[1]-1,0})
  vim.api.nvim_buf_call(self.list.buf, function() vim.cmd("normal! $") end)
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
  vim.api.nvim_buf_call(self.list.buf, function() vim.cmd("normal! $") end)
  self:_update_preview()
end

function win:prev_pagedown()
  local height = self.preview.opts.height
  vim.api.nvim_buf_call(self.preview.buf, function()
    vim.cmd("normal! L"..height.."jz-")
  end)
end

function win:prev_pageup()
  local height = self.preview.opts.height
  vim.api.nvim_buf_call(self.preview.buf, function()
    vim.cmd("normal! H"..height.."kzt")
  end)
end

function win:prev_lineup()
  vim.api.nvim_buf_call(self.preview.buf, function()
    vim.cmd("normal! Hk")
  end)
end

function win:prev_linedown()
  vim.api.nvim_buf_call(self.preview.buf, function()
    vim.cmd("normal! Lj")
  end)
end

function win:prev_scrollright()
  vim.api.nvim_buf_call(self.preview.buf, function()
    vim.cmd("normal! zl")
  end)
end

function win:prev_scrollleft()
  vim.api.nvim_buf_call(self.preview.buf, function()
    vim.cmd("normal! zh")
  end)
end

function win:update(lines)
  vim.schedule(
    function()
      -- if list buffer had previous content then clean up first
      if self.list.cur_lines then
            api.nvim_buf_set_lines(self.list.buf, 0, -1, false, {})
      end
      if next(lines) ~= nil then
          api.nvim_buf_set_lines(self.list.buf, 0, -1, false, lines)
          self.list.cur_lines = lines
          api.nvim_win_set_cursor(self.list.win, {1,0})
          vim.fn.sign_unplace('', {buffer=self.list.buf, id='dev2one-curline'})
          vim.fn.sign_place(0, '', 'dev2one-curline', self.list.buf, {lnum=1})
          vim.api.nvim_buf_call(self.list.buf, function()
            vim.cmd("normal! $")
          end)
          self:_update_preview()
      end
    end)
end

function win:_update_preview()
  if self.preview.win == nil or not api.nvim_win_is_valid(self.preview.win) then
    return
  end
  local content_details = self:_content_details()
  local function update_cursor()
    local line = content_details.line
    api.nvim_win_set_cursor(self.preview.win, {line,0})
    vim.fn.sign_unplace('', {buffer=self.preview.buf, id='dev2one-curline'})
    vim.fn.sign_place(0, '', 'dev2one-curline', self.preview.buf, {lnum=line})
  end
  if self.preview.cur_file ~= content_details.filepath then
    self.preview.cur_file = content_details.filepath
    uvutil.read_file(self.preview.cur_file, vim.schedule_wrap(function(chunk)
      local ok = pcall(vim.api.nvim_buf_set_lines, self.preview.buf, 0, -1, false, vim.split(chunk, '[\r]?\n'))
      if not ok then return end
      local filetype = vim.fn.fnamemodify(content_details.filepath, ":e")
      vim.api.nvim_buf_set_option(self.preview.buf, "ft", filetype)
      update_cursor()
    end))
  else
    update_cursor()
  end
end

function win:select()
  local content_details = self:_content_details()
  api.nvim_set_current_win(self.opts.main_win)
  if content_details.location then
    vim.lsp.util.jump_to_location(content_details.location)
  else
    local pos = {content_details.line,0}
    api.nvim_win_set_cursor(self.opts.main_win, pos)
  end
  api.nvim_command('normal z.')
  api.nvim_command('stopinsert')
end

function win:_content_details()
  local pos = api.nvim_win_get_cursor(self.list.win)
  local key = api.nvim_buf_get_lines(self.list.buf, pos[1]-1, pos[1], false)
  return self.content:get(key[1])
end

function win:delete()
  local bufs = string.format("%s %s", self.list.buf, self.border.buf)
  if self.opts.with_prompt then
    bufs = bufs.." "..self.prompt.buf
  end
  if self.opts.with_preview then
    bufs = bufs.." "..self.split.buf.." "..self.preview.buf
  end
  api.nvim_command('silent bwipeout! '..bufs)
  storage.delete(self.id)
end

return win
