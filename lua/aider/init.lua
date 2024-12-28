---@class ToggletermConfig
---@field direction string Window layout type ('float'|'vertical'|'horizontal'|'tab')
---@field size function Size function for terminal
---@field float_opts table<string, any>? flat config options, see toggleterm.nvim for valid options

---@class AiderConfig
---@field spawn_on_comment boolean
---@field editor_command string|nil Command to use for editor
---@field fzf_action_key string Key to trigger aider load in fzf
---@field aider_args table Additional arguments for aider CLI
---@field win ToggletermConfig window options
---@field spawn_on_startup boolean|nil
---@field after_update_hook function|nil
---@field watch_files boolean
---@field telescope_action_key string
---@field auto_insert true
---@field dark_mode function|boolean
---@field model_picker_search table
---@field on_term_open function|nil
---@field restart_on_chdir boolean
---@field auto_scroll boolean
---@field theme table|nil
---@field code_theme_dark string
---@field code_theme_light string
---@field progress_notifier table|nil
---@field log_notifier boolean
---@field git_pager string
---@field use_tmux boolean
---@field auto_show table

local M = {}

-- Table to store temporary file names
vim.g.aider_temp_files = {}

---Default configuration values
---@type AiderConfig
M.defaults = {
	-- start aider when ai comment is written (e.x. `ai!|ai?|ai`)
	spawn_on_comment = true,

	-- auto show aider terminal window
	auto_show = {
		on_ask = true, -- e.x. `ai? comment`
		on_change_req = false, -- e.x. `ai! comment`
		on_file_add = false, -- e.x. when using Telescope or `AiderLoad` to add files
	},

	-- function to run when aider updates file/s, useful for triggering git diffs
	after_update_hook = nil,

	-- action key for adding files to aider from fzf-lua file pickers
	fzf_action_key = "ctrl-l",

	-- action key for adding files to aider from Telescope file pickers
	telescope_action_key = "<C-l>",

	-- filter `Telescope model_picker` model picker
	model_picker_search = { "^anthropic/", "^openai/", "^gemini/" },

	-- enable the --watch-files flag for Aider
	-- Aider will automatically start when valid comments are created
	watch_files = true,

	-- for snacks progress notifications
	progress_notifier = {
		style = "compact",
		-- * compact: use border for icon and title
		-- * minimal: no border, only icon and message
		-- * fancy: similar to the default nvim-notify style
	},

	-- print logs of Aider's output in the right corner, requires fidget.nvim
	log_notifier = true,

	-- code theme to use for markdown blocks when in dark mode
	-- code_theme_dark = "gruvbox-dark",
	code_theme_dark = "monokai",

	-- code theme to use for markdown blocks when in light mode
	-- code_theme_light = "gruvbox-light",
	code_theme_light = "default",

	-- command to run for opening nested editor when invoking `/editor` from Aider terminal
	-- requires flatten.nvim to work
	editor_command = "nvim --cmd 'let g:flatten_wait=1' --cmd 'cnoremap wq write<bar>bdelete<bar>startinsert'",

	-- auto insert mode
	auto_insert = true,

	-- additional arguments for aider CLI
	aider_args = {},

	-- always start aider on startup
	spawn_on_startup = false,

	-- restart aider when directory changes
	-- aider.nvim will keep separate terminal for each directory so restarting isn't typically necessary
	restart_on_chdir = false,

	-- used to determine whether to use dark themes for code blocks and whether to use `--dark-mode`
	-- if supported theme is not available
	dark_mode = function()
		return vim.o.background == "dark"
	end,

	-- auto scroll terminal on output
	auto_scroll = false,

	-- window layout settings
	win = {
		-- type of window layout to use
		direction = "vertical", -- can be 'float', 'vertical', 'horizontal', 'tab'
		-- size function for terminal
		size = function(term)
			if term.direction == "horizontal" then
				return math.floor(vim.api.nvim_win_get_height(0) * 0.4)
			elseif term.direction == "vertical" then
				return math.floor(vim.api.nvim_win_get_width(0) * 0.4)
			end
		end,
		-- flat config options, see toggleterm.nvim for valid options
		float_opts = {
			border = "single",
			width = function()
				return vim.api.nvim_win_get_width(0)
			end,
			height = function()
				return vim.api.nvim_win_get_height(0)
			end,
		},
	},
	-- theme colors for aider
	theme = nil,

	-- git pager to use, defaults to 'cat' to prevent blocking after_update_hook
	git_pager = "cat",

	-- function to run (e.x. for term mappings) when terminal is opened
	on_term_open = function()
		local function tmap(key, val)
			local opt = { buffer = 0 }
			vim.keymap.set("t", key, val, opt)
		end
		-- exit insert mode
		tmap("<Esc>", "<C-\\><C-n>")
		tmap("jj", "<C-\\><C-n>")
		-- enter command mode
		tmap(":", "<C-\\><C-n>:")
		-- scrolling up/down
		tmap("<C-u>", "<C-\\><C-n><C-u>")
		tmap("<C-d>", "<C-\\><C-n><C-d>")
		vim.opt.number = false
		vim.opt.wrap = true
		vim.opt.showbreak = ""
	end,

	-- enable tmux mode (highly experimental!)
	use_tmux = false,
}

---@class AiderConfig
M.config = {}

---@type tokyonight.HighlightsFn
local function set_tokyonight_theme(c, _)
	return {
		user_input_color = c.git.add,
		tool_output_color = c.blue,
		tool_error_color = c.red1,
		tool_warning_color = c.orange,
		assistant_output_color = c.purple,
		completion_menu_color = c.fg_float,
		completion_menu_bg_color = c.bg_float,
		completion_menu_current_color = c.fg_dark,
		completion_menu_current_bg_color = c.bg_highlight,
	}
end

---@param c table
local function set_catppuccin_colors(c)
	return {
		user_input_color = c.green,
		tool_output_color = c.blue,
		tool_error_color = c.red,
		tool_warning_color = c.yellow,
		assistant_output_color = c.mauve,
		completion_menu_color = c.text,
		completion_menu_bg_color = c.base,
		completion_menu_current_color = c.crust,
		completion_menu_current_bg_color = c.pink,
	}
end

local function tokyonight_theme()
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

local function catppuccin_theme()
	local ok, _ = pcall(require, "catppuccin.palettes")
	if not ok then
		return
	end

	local current_color = vim.g.colors_name
	local flavour = require("catppuccin").flavour or vim.g.catppuccin_flavour

	if current_color and current_color:match("^catppuccin") and flavour then
		local colors = require("catppuccin.palettes").get_palette()
		return set_catppuccin_colors(colors)
	end
end

local function gruvbox_theme()
	local ok, gruvbox = pcall(require, "gruvbox")
	if not ok then
		return
	end

	local p = gruvbox.palette

	local color_groups = {
		dark = {
			bg0 = p.dark0,
			bg1 = p.dark1,
			bg2 = p.dark2,
			bg3 = p.dark3,
			bg4 = p.dark4,
			fg0 = p.light0,
			fg1 = p.light1,
			fg2 = p.light2,
			fg3 = p.light3,
			fg4 = p.light4,
			red = p.bright_red,
			green = p.bright_green,
			yellow = p.bright_yellow,
			blue = p.bright_blue,
			purple = p.bright_purple,
			aqua = p.bright_aqua,
			orange = p.bright_orange,
			neutral_red = p.neutral_red,
			neutral_green = p.neutral_green,
			neutral_yellow = p.neutral_yellow,
			neutral_blue = p.neutral_blue,
			neutral_purple = p.neutral_purple,
			neutral_aqua = p.neutral_aqua,
			dark_red = p.dark_red,
			dark_green = p.dark_green,
			dark_aqua = p.dark_aqua,
			gray = p.gray,
			code_theme = "gruvbox-dark",
		},
		light = {
			bg0 = p.light0,
			bg1 = p.light1,
			bg2 = p.light2,
			bg3 = p.light3,
			bg4 = p.light4,
			fg0 = p.dark0,
			fg1 = p.dark1,
			fg2 = p.dark2,
			fg3 = p.dark3,
			fg4 = p.dark4,
			red = p.faded_red,
			green = p.faded_green,
			yellow = p.faded_yellow,
			blue = p.faded_blue,
			purple = p.faded_purple,
			aqua = p.faded_aqua,
			orange = p.faded_orange,
			neutral_red = p.neutral_red,
			neutral_green = p.neutral_green,
			neutral_yellow = p.neutral_yellow,
			neutral_blue = p.neutral_blue,
			neutral_purple = p.neutral_purple,
			neutral_aqua = p.neutral_aqua,
			dark_red = p.light_red,
			dark_green = p.light_green,
			dark_aqua = p.light_aqua,
			gray = p.gray,
			code_theme = "gruvbox-light",
		},
	}
	local colors = color_groups[vim.o.background or "dark"]

	return {
		user_input_color = colors.green,
		tool_output_color = colors.blue,
		tool_error_color = colors.red,
		tool_warning_color = colors.yellow,
		assistant_output_color = colors.fg1,
		completion_menu_color = colors.fg1,
		completion_menu_bg_color = colors.bg1,
		completion_menu_current_color = colors.fg4,
		completion_menu_current_bg_color = colors.bg4,
		code_theme = colors.code_theme,
	}
end

---Initialize configuration with user options
---@param opts AiderConfig|nil User configuration options
function M.setup(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", {}, M.defaults, opts)

	local theme = tokyonight_theme() or catppuccin_theme() or gruvbox_theme()
	if theme then
		M.config.theme = theme
	end

	-- Setup fzf-lua integration if available
	require("aider.fzf").setup(M.config)

	-- Setup telescope integration if available
	local telescope_ok, telescope = pcall(require, "telescope")
	if telescope_ok then
		telescope.load_extension("file_pickers")
		telescope.load_extension("model_picker")
	end
	require("aider.commands").setup(M.config)
end

return M
