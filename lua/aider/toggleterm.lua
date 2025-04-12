local Terminal = require("toggleterm.terminal").Terminal
local config = require("aider").config
local utils = require("aider.utils")
local notify = require("aider.notify")
local aider = require("aider.aider")

---@class AiderToggleterm
---@field __term table<string, Terminal> Map of CWD to Terminal instances
local M = {
  __term = {},
}

---@return boolean
function M.is_running()
  return M.__term[utils.cwd()] ~= nil
end

function M.clear()
  local term = M.__term[utils.cwd()]
  if term then
    term:close()
  end
  M.__term[utils.cwd()] = nil
end

function M.clear_all()
  for _, term in ipairs(M.__term) do
    if term then
      term:close()
    end
  end
  M.__term = {}
end

function M.close_all()
  for _, term in ipairs(M.__term) do
    term:close()
  end
end

function M.is_open()
  local term = M.terminal()
  return term:is_open()
end

--- Get or generate a terminal object for Aider
---@return Terminal
function M.terminal()
  local cwd = utils.cwd()
  if M.__term[cwd] then
    local term = M.__term[cwd]
    return term
  end
  local term = Terminal:new({
    -- requires delay so aider can detect size correctly
    cmd = aider.command(),
    env = aider.env(),
    display_name = "Aider.nvim",
    close_on_exit = true,
    direction = config.win.direction,
    size = config.win.size,
    float_opts = config.win.float_opts,
    auto_scroll = false,
    ---@param term Terminal
    on_open = function(term)
      vim.api.nvim_buf_call(term.bufnr, function()
        vim.opt.number = false
        vim.opt.wrap = true
        vim.opt.showbreak = ""
        vim.opt.list = false
        term:scroll_bottom()
      end)
    end,
    on_exit = function()
      M.clear_all()
    end,
  })
  term.on_stdout = function(_, _, data, _)
    notify.on_stdout(M, data)
  end
  term:spawn()
  M.__term[cwd] = term
  return term
end

---Load files into aider session
---@param files table|nil Files or path
function M.add(files)
  files = files or {}
  if #files > 0 then
    -- Convert relative paths to absolute paths
    local abs_files = {}
    for _, file in ipairs(files) do
      table.insert(abs_files, vim.fn.fnamemodify(file, ":p"))
    end
    local cmd = "/add " .. table.concat(abs_files, " ")
    M.send_command(cmd)
  end
end

---Load files into aider session
---@param files table|nil Files or path
function M.read_only(files)
  files = files or {}
  if #files > 0 then
    local cmd = "/read-only " .. table.concat(files, " ")
    M.send_command(cmd)
  end
end

function M.drop(files)
  files = files or {}
  if #files > 0 then
    local cmd = "/drop " .. table.concat(files, " ")
    M.send_command(cmd)
  end
end

function M.open()
  local term = M.terminal()
  if not term:is_open() then
    M.toggle_window(nil, nil)
  end
end

function M.spawn()
  M.terminal()
end

---@param size? number|nil
---@param direction? string|nil
function M.toggle_window(size, direction)
  local term = M.terminal()
  if size then
    config.win.size = function()
      return size(term)
    end
  end
  if direction then
    config.win.direction = direction
  end

  if term:is_open() then
    if direction and direction ~= term.direction then
      term:close()
    end
  end

  term:toggle(config.win.size(term), config.win.direction)
end

--- Send a command to the active Aider terminal session
--- If no terminal is currently open, it will first create a new terminal
--- @param command string The command to send to the Aider session
function M.send_command(command)
  local term = M.terminal()
  if string.find(command, "\n") then
    local cmd_start = "{EOL\n"
    local cmd_end = "\nEOL}\n"
    command = cmd_start .. command .. cmd_end
  end
  term:send(command)

  if config.auto_show.on_command_send then
    M.open()
  end
end

--- Send an AI query to the Aider session
--- @param prompt string The query or instruction to send
--- @param selection string? Optional selected text to include with the prompt
function M.ask(prompt, selection)
  if not prompt or #vim.trim(prompt) == 0 then
    vim.notify("No input provided", vim.log.levels.WARN)
    return
  end

  local command
  if selection then
    prompt = string.format("%s\n%s", prompt, selection)
  end

  command = "/ask " .. prompt
  M.send_command(command)
end

return M
