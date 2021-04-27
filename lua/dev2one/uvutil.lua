local uv = vim.loop
local M = {}

function M.process(cmd, args, cwd, on_done, on_stdout, on_stderr)
  assert(cmd~=nil)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  --local cmd_string = cmd
  --for _, arg in ipairs(args) do
    --cmd_string = cmd_string .. " " .. arg
  --end
  --print("running command:", cmd_string)
  Handle = uv.spawn(cmd, {
      args = args,
      cwd = cwd,
      stdio = {nil, stdout, stderr}
    },
    vim.schedule_wrap(
      function()
        stdout:read_stop()
        stderr:read_stop()
        stdout:close()
        stderr:close()
        Handle:close()
        if type(on_done) == 'function' then
          on_done()
        end
      end
    )
  )
  if type(on_stdout) == 'function' then
    uv.read_start(stdout, function(err, data)
      on_stdout(err, data)
    end)
  end
  if type(on_stderr) == 'function' then
    uv.read_start(stderr, function(err, data)
      on_stderr(err, data)
    end)
  end
end

function M.read_file(path, callback)
    uv.fs_open(path, 'r', tonumber('644', 8), function (err_open, fd)
      assert(not err_open, err_open)
      uv.fs_fstat(fd, function (err_stat, stat)
        assert(not err_stat, err_stat)
        uv.fs_read(fd, stat.size, 0, function (err_read, chunk)
          assert(not err_read, err_read)
          assert(#chunk == stat.size)
          uv.fs_close(fd, function (err_close)
            assert(not err_close, err_close)
            callback(chunk)
          end)
        end)
      end)
    end)
end

return M
