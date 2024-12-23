local terminal = require("aider.terminal")
local selection = require("aider.selection")
local config = require("aider").config
local utils = require("aider.utils")

local M = {}

local function handle_ai_comments()
	vim.api.nvim_create_augroup("ReadCommentsTSTree", { clear = true })
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = "ReadCommentsTSTree",
		pattern = "*",
		callback = function()
			local bufnr = vim.fn.bufnr("%")
			local matches = utils.get_comment_matches(bufnr)

			if matches.any then
				if not terminal.is_running() then
					terminal.spawn()
					vim.defer_fn(function()
						vim.api.nvim_buf_call(bufnr, function()
							vim.cmd("silent w")
						end)
					end, 2000)
				end

				if config.auto_show_on_ask then
					if matches["ai?"] then
						local term = terminal.terminal()
						if not term:is_open() then
							terminal.toggle_window(nil, nil)
						end
					end
				end
			end
		end,
	})
end

local function handle_aider_send(opt)
	if opt.range == 0 then
		if not opt.args or opt.args == "" then
			vim.notify("Empty input provided", vim.log.levels.WARN)
			return
		end
		terminal.send_command(opt.args)
		return
	end
	-- Get the selected text
	local selected = selection.get_visual_selection_with_header()
	if not selected then
		vim.notify("Failed to get visual selection", vim.log.levels.ERROR)
		return
	end
	-- Combine selection with any additional arguments
	local input = opt.args and opt.args ~= "" and string.format("%s\n%s", opt.args, selected) or selected
	terminal.send_command(input)
end

---@param opt table Command options containing arguments
local function handle_aider_ask(opt)
	local function process_prompt(input)
		if not input or input == "" then
			vim.notify("Empty input provided", vim.log.levels.WARN)
			return
		end
		local selected = selection.get_visual_selection_with_header()
		if not selected then
			vim.notify("Failed to get visual selection", vim.log.levels.ERROR)
			return
		end
		terminal.ask(input, selected)
	end

	if #opt.args > 0 then
		process_prompt(opt.args)
	else
		vim.schedule(function()
			vim.ui.input({ prompt = "Prompt: " }, function(input)
				process_prompt(input)
			end)
		end)
	end
end

---Create user commands for aider functionality
---@param opts AiderConfig
function M.setup(opts)
	opts = opts or {}
	vim.api.nvim_create_user_command("AiderToggle", function(opt)
		if not opt.args or opt.args == "" then
			terminal.toggle_window(nil, nil)
			return
		end
		terminal.toggle_window(nil, opt.args)
	end, {
		desc = "Toggle Aider window",
		nargs = "?",
		complete = function()
			return { "vertical", "horizontal", "tab", "float" }
		end,
	})

	vim.api.nvim_create_user_command("AiderLoad", function(opt)
		local files = opt.fargs
		if #files == 0 then
			files = { vim.api.nvim_buf_get_name(0) }
		end
		terminal.load_files(files)
	end, {
		nargs = "*",
		desc = "Load files into Aider",
		complete = "file",
	})

	vim.api.nvim_create_user_command("AiderSend", handle_aider_send, {
		nargs = "*",
		range = true, -- This enables the command to work with selections
		desc = "Send command to Aider",
		bang = true,
	})

	vim.api.nvim_create_user_command("AiderAsk", handle_aider_ask, {
		range = true,
		nargs = "*",
		desc = "Send a prompt to the AI with optional visual selection context",

		bang = true,
	})

	vim.api.nvim_create_user_command("AiderSpawn", function()
		terminal.spawn()
	end, {
		range = true,
		nargs = "*",
		desc = "Ask with visual selection",
		bang = true,
	})

	vim.api.nvim_create_user_command("AiderClear", function()
		terminal.clear()
	end, {
		desc = "Clear current Aider terminal",
	})

	vim.api.nvim_create_user_command("AiderClearAll", function()
		terminal.clear_all()
	end, {
		desc = "Clear all Aider terminals",
	})

	if opts.restart_on_chdir then
		vim.api.nvim_create_autocmd("DirChanged", {
			pattern = "*",
			callback = function()
				-- restart terminal
				vim.notify("Restarting terminal..")
				if terminal.is_running() then
					terminal.clear()
					terminal.spawn()
				end
			end,
		})
	end

	if opts.on_term_open then
		vim.api.nvim_create_autocmd("TermOpen", {
			callback = opts.on_term_open,
		})
	end

	if opts.spawn_on_startup then
		vim.schedule(function()
			vim.cmd("AiderSpawn")
		end)
	end

	if opts.spawn_on_comment then
		handle_ai_comments()
	end
end
return M
