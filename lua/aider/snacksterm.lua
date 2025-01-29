local Terminal = require("snacks.terminal")
local config = require("aider").config
local utils = require("aider.utils")
local notify = require("aider.notify")
local aider = require("aider.aider")

---@class AiderSnacks
---@field __terms table<string, snacks.win> Map of CWD to Terminal instances
local T = {
  __terms = {},
}

---@return boolean
function T.is_running()
  return T.__terms[utils.cwd()] ~= nil
end

function T.clear()
  local term = T.__terms[utils.cwd()]
  if term then
    term:close()
  end
  T.__terms[utils.cwd()] = nil
end

function T.clear_all()
  for _, term in ipairs(T.__terms) do
    if term then
      term:close()
    end
  end
  T.__terms = {}
end

function T.close_all()
  for _, term in ipairs(T.__terms) do
    term:close()
  end
end

--- Get the buffer IDs of all listed split windows
---@return table<number, number> table of buffer IDs
local function get_split_buf_ids()
  local bufs = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      bufs[#bufs + 1] = buf
    end
  end
  return bufs
end

---@return boolean
function T.is_open()
  local term = T.get()
  if not term then
    return false
  end

  if term:is_floating() then
    return true
  end
  for _, buf in ipairs(get_split_buf_ids()) do
    if buf == term.buf then
      return true
    end
  end
  return false
end

---@return string
local function get_root()
  return Snacks.git.get_root(vim.uv.cwd()) or vim.uv.cwd() or ""
end

--- Get or generate a terminal object for Aider
---@param opts? {create: boolean, cwd: string?, position: string?}
---@return snacks.win?, boolean?
function T.get(opts)
  opts = opts or {}
  local position = opts.position or "float"
  local get = Snacks.terminal.get

  if opts.create then
    T.position = position
  end

  local term, created = get(aider.command(), {
    cwd = opts.cwd or get_root(),
    env = aider.env(),
    create = opts.create or false,
    interactive = true,
    win = {
      --@field position? "float"|"bottom"|"top"|"left"|"right"
      position = position,
    }
  })
  return term, created
end

--- Get or generate a terminal object for Aider
---@return snacks.win?, boolean?
function T.terminal(opts)
  opts = opts or {}
  opts.create = true
  local term, created = T.get(opts)
  if not term then
    notify.error("Failed to create terminal")
    return nil, false
  end
  T.buf_id = term.buf
  if not T.buf_id then
    notify.error("Failed to get terminal buf")
    return nil, false
  end
  T.win_id = term.win
  T.job_id = vim.b[T.buf_id].terminal_job_id
  local cwd = get_root()
  vim.b[T.buf_id].term_title = "Aider.nvim: " .. vim.fn.fnamemodify(cwd, ":~")
  term:set_title(vim.b[T.buf_id].term_title, "center")
  if not T.job_id then
    notify.error("Failed to get terminal job id")
    return nil, false
  end
  if cwd then
    T.__terms[cwd] = term
  end

  return term, created
end

---Load files into aider session
---@param files table|nil Files or path
function T.add(files)
  files = files or {}
  if #files > 0 then
    -- Convert relative paths to absolute paths
    local abs_files = {}
    for _, file in ipairs(files) do
      local abs_file = vim.fn.fnamemodify(file, ":p")
      table.insert(abs_files, abs_file)
    end
    local cmd = "/add " .. table.concat(abs_files, " ")
    T.send_command(cmd)
  end
end

---Load files into aider session
---@param files table|nil Files or path
function T.read_only(files)
  files = files or {}
  if #files > 0 then
    local cmd = "/read-only " .. table.concat(files, " ")
    T.send_command(cmd)
  end
end

---@param files table|nil Files or path
function T.drop(files)
  files = files or {}
  if #files > 0 then
    local cmd = "/drop " .. table.concat(files, " ")
    T.send_command(cmd)
  end
end

function T.spawn()
  T.terminal()
end

local directions_mapping = {
  tab = "float",
  vertical = "right",
  horizontal = "bottom",
}

---@param size? number|nil
---@param direction? string|nil
function T.toggle_window(size, direction)
  if directions_mapping[direction] then
    direction = directions_mapping[direction]
  end
  local opts = { position = direction }
  local term = T.get(opts)

  -- local style = "split"
  -- if direction == "float" then
  --   style = "float"
  -- end

  if term then
    -- vim.notify("style " .. style .. " position " .. direction)
    -- term.opts.position = direction
    -- term.opts.style = style
    term:toggle()
  else
    local term, created = T.terminal(opts)
    if not created then
      if not term then
        vim.notify("Failed to create terminal", vim.log.levels.ERROR)
        return
      end
      term:show()
    end
  end
end

--- Send a command to the active Aider terminal session
--- If no terminal is currently open, it will first create a new terminal
--- @param command string The command to send to the Aider session
function T.send_command(command)
  if string.find(command, "\n") then
    local cmd_start = "{EOL\n"
    local cmd_end = "\nEOL}"
    command = cmd_start .. command .. cmd_end
  end
  command = command .. "\n"

  local term = T.terminal()
  if not term then
    vim.notify("Failed to create terminal", vim.log.levels.ERROR)
  end
  vim.fn.chansend(T.job_id, command)
end

--- Send an AI query to the Aider session
--- @param prompt string The query or instruction to send
--- @param selection string? Optional selected text to include with the prompt
function T.ask(prompt, selection)
  if not prompt or #vim.trim(prompt) == 0 then
    notify.warn("No input provided")
    return
  end

  local command
  if selection then
    prompt = string.format("%s\n%s", prompt, selection)
  end

  command = "/ask " .. prompt
  T.send_command(command)
end

return T
