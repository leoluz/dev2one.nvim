local uv = vim.loop
local M = {}


function M.readFile(path, callback)
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
