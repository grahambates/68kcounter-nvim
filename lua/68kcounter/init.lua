local M = {}

local state = {
  winid=nil,
  bufnr=nil,
  srcwin=nil,
  srcbuf=nil,
}

local last_line = nil

local bin_path = "68kcounter"

function M.setup(options)
  if options and options.bin_path then
    bin_path = options.bin_path
  end
end

function M.toggle()
  if window_exists() then
    M.hide()
  else
    M.show()
  end
end

function M.show()
  local srcwin = vim.fn.win_getid()

  -- hide open instance for other window
  if state.srcwin ~= nil and state.srcwin ~= srcwin then
    M.hide()
  end

  -- detect switching buffers
  vim.cmd[[
    augroup VisibleBufferChange
      autocmd!
      autocmd BufEnter * lua vis_buf_change()
    augroup END
  ]]

  vim.cmd("set scrollbind")
  vim.cmd("set scrollopt=ver")

  -- store source window and buffer
  state.srcwin = srcwin
  state.srcbuf = vim.fn.bufnr('%')

  -- create window and buffer if they don't exist
  if not window_exists() then
    state.winid = create_window()
  end
  if not buffer_exists() then
    state.bufnr = create_buffer()
  end
  vim.api.nvim_win_set_buf(state.winid, state.bufnr)

  init_buffer()
end

function M.hide()
  -- disable scrollbind for all windows
  vim.cmd('windo setlocal noscrollbind')

  -- close window and buffer if they exist
  if window_exists() then
    vim.api.nvim_win_close(state.winid, true)
  end
  if buffer_exists() then
    vim.api.nvim_buf_delete(state.bufnr, { force = true })
  end
  state.bufnr = nil
  state.winid = nil
end

function get_counts()
  if not window_exists() then
    return
  end

  -- get buffer contents as a string
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local input = table.concat(lines, "\n")

  -- reset last line
  -- this tells us to replace on the first packet, not append
  last_line = nil

  -- try to start node bin job if not running
  if not job_running() then
    state.job = create_job()
  end

  -- there's still a chance it didn't start successfully
  if job_running() then
    vim.fn.chansend(state.job, input .. "\x26")
  else
    print("process not started")
  end
end

function window_exists()
  return state.winid ~= nil
    and vim.api.nvim_win_is_valid(state.winid)
    and vim.api.nvim_win_get_number(state.winid) > 0
end

function buffer_exists()
  return state.bufnr ~= nil
    and vim.api.nvim_buf_is_valid(state.bufnr)
    and vim.api.nvim_buf_get_number(state.bufnr) > 0
end

function job_running()
  return state.job ~= nil
end

function create_window()
  -- ensure split is to left
  -- we'll restore previous option after opening the window
  local previous_splitright = vim.o.splitright
  vim.o.splitright = false

  local winid = vim.api.nvim_win_call(0, function()
    vim.api.nvim_command(
      string.format(
        "silent noswapfile vertical %ssplit",
        31
      )
    )
    vim.api.nvim_command("set scrollbind")
    return vim.api.nvim_get_current_win()

  end)

  -- restore option
  vim.o.splitright = previous_splitright

  -- set window options
  local win_options = {
    number = false,
    relativenumber = false,
    spell = false,
    list = false,
  }
  for name, value in pairs(win_options) do
    vim.api.nvim_win_set_option(winid, name, value)
  end

  return winid
end

function create_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, "68kcounter")

  -- set buffer options
  local buf_options = {
    swapfile = false,
    undolevels = -1,
    filetype = "m68kcounter"
  }
  for name, value in pairs(buf_options) do
    vim.api.nvim_buf_set_option(bufnr, name, value)
  end

  return bufnr
end

-- create job for node bin
function create_job()
  return vim.fn.jobstart({bin_path, "-i", "timings,bytes,totals"}, {
    on_stdout = function(_, data)
      -- may have been closed in the meantime
      if window_exists() and buffer_exists() then
        if last_line ~= nil then
          data[1] = last_line .. data[1]
          vim.api.nvim_buf_set_lines(state.bufnr, -2, -1, true, data)
        else
          vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, true, data)
        end
        last_line = data[#data]

        -- set initial scroll position
        local scrolloff = vim.api.nvim_get_option('scrolloff')
        local top = vim.fn.line('w0') + scrolloff

        vim.api.nvim_win_call(state.winid, function()
          vim.api.nvim_command("execute 'normal! " .. top .. "zt'")
        end)
      end
    end,
    on_exit = function()
      state.job = nil
    end,
  })
end

function init_buffer()
  local ft = vim.bo.filetype
  if ft == "asm68k" or ft == "asm" then
    -- attach event listener for buffer changes and get initial counts
    vim.api.nvim_exec([[
      augroup m68kcounter_buf_change
        autocmd!
        autocmd TextChanged,TextChangedP <buffer> lua get_counts()
      augroup END
    ]], true)

    get_counts()
  else
    -- clear buffer for non asm buffers
    vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, true, {})
  end
end

-- Define a function to detect visible buffer changes
function vis_buf_change()
  local new_bufnr = vim.fn.bufnr("%")
  -- new buffer in src window?
  if window_exists() and state.srcwin == vim.fn.win_getid() and new_bufnr ~= state.srcbuf then
    state.srcbuf = new_bufnr
    init_buffer()
  end
end

return M
