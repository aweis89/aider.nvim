local terminal = require("aider.terminal")
local selection = require("aider.selection")

local M = {}

---Create user commands for aider functionality
function M.setup(opts)
	vim.api.nvim_create_user_command("AiderToggle", function(opts)
		if not opts.args or opts.args == "" then
			terminal.toggle_aider_window(nil, nil)
			return
		end
		terminal.toggle_aider_window(nil, opts.args)
	end, {
		desc = "Toggle Aider window",
		nargs = "?",
		complete = function()
			return { "vertical", "horizontal", "tab", "float" }
		end,
	})

	vim.api.nvim_create_user_command("AiderLoad", function(opts)
		local files = opts.fargs
		if #files == 0 then
			files = { vim.api.nvim_buf_get_name(0) }
		end
		terminal.laod_files_in_aider(files)
	end, {
		nargs = "*",
		desc = "Load files into Aider",
		complete = "file",
	})

	-- remove comments in this func ai!
	local function handle_aider_send(opts)
		if opts.range == 0 then
			-- No selection, just use the arguments
			if not opts.args or opts.args == "" then
				vim.notify("Empty input provided", vim.log.levels.WARN)
				return
			end
			terminal.send_command_to_aider(opts.args)
			return
		end

		-- Get the selected text
		local selected = selection.get_visual_selection_with_header()
		if not selected then
			vim.notify("Failed to get visual selection", vim.log.levels.ERROR)
			return
		end

		-- Combine selection with any additional arguments
		local input = opts.args and opts.args ~= "" and string.format("%s\n%s", opts.args, selected) or selected

		terminal.send_command_to_aider(input)
	end

	vim.api.nvim_create_user_command("AiderSend", handle_aider_send, {
		nargs = "*",
		range = true, -- This enables the command to work with selections
		desc = "Send command to Aider",
		bang = true,
	})

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

		terminal.ask_aider(input, selected)
	end

	local function handle_aider_ask(opts)
		if #opts.args > 0 then
			process_prompt(opts.args)
		else
			vim.schedule(function()
				vim.ui.input({ prompt = "Prompt: " }, function(input)
					process_prompt(input)
				end)
			end)
		end
	end

	vim.api.nvim_create_user_command("AiderAsk", handle_aider_ask, {
		range = true,
		nargs = "*",
		desc = "Ask with visual selection",
		bang = true,
	})

	vim.api.nvim_create_user_command("AiderUpdatedHook", function()
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if
				vim.api.nvim_buf_is_loaded(bufnr)
				and vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == ""
			then
				vim.api.nvim_buf_call(bufnr, function()
					vim.cmd("checktime")
				end)
			end
		end

		if opts.update_hook_cmd then
			local current_buf = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_call(current_buf, function()
				vim.cmd(opts.update_hook_cmd)
			end)
		end
		vim.notify("File updated by AI!", vim.log.levels.INFO)
	end, {
		desc = "Ran after aider makes file update",
		bang = true,
	})

	vim.api.nvim_create_user_command("AiderSpawn", function()
		terminal.spawn()
		vim.notify("Aider running in background")
	end, {
		range = true,
		nargs = "*",
		desc = "Ask with visual selection",
		bang = true,
	})

	-- Create the autocmd right after defining the command
	if opts and opts.spawn_on_startup then
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				vim.cmd("AiderSpawn")
			end,
		})
	end
end

return M
