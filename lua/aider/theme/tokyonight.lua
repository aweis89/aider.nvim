local M = {}

---@type tokyonight.HighlightsFn
local function set_tokyonight_theme(c, _)
  local util = require("tokyonight.util")

  return {
    user_input_color = c.green2,
    tool_output_color = c.blue0,
    tool_error_color = c.red1,
    tool_warning_color = c.orange,
    assistant_output_color = c.blue0,
    completion_menu_color = c.fg_float,
    completion_menu_bg_color = c.bg_float,
    completion_menu_current_color = c.fg_dark,
    completion_menu_current_bg_color = c.bg_highlight,
  }
end

function M.tokyonight_theme()
  if not vim.startswith(vim.g.colors_name, "tokyonight") then
    return -- Do nothing if tokyonight is not active
  end
  local ok, tokyonight_config = pcall(require, "tokyonight.config")
  if not ok then
    return -- Do nothing if tokyonight.config is not found
  end
  local opts = tokyonight_config.options
  local ok, tokyonight_colors = pcall(require, "tokyonight.colors")
  if not ok then
    return -- Do nothing if tokyonight.colors is not found
  end
  return set_tokyonight_theme(tokyonight_colors.setup(opts), opts)
end

return M
