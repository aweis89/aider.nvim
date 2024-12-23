local terminal = require("aider.terminal")
local selection = require("aider.selection")

local M = {}

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

		terminal.ask(input, selected)
	end

	---@param opt table Command options containing arguments
	local function handle_aider_ask(opt)
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

	local function get_comments(bufnr)
		local success, parser = pcall(vim.treesitter.get_parser, bufnr)
		if not success or not parser then
			print("No Tree-sitter parser found for buffer " .. bufnr)
			return nil
		end
		local tree = parser:parse()[1]
		if not tree then
			print("Failed to parse buffer " .. bufnr)
			return nil
		end
		local filetype = vim.bo[bufnr].filetype
		if not filetype then
			print("No filetype detected for buffer " .. bufnr)
			return nil
		end
		local query_string = [[
(comment) @comment
]]
		local ok, query = pcall(vim.treesitter.query.parse, filetype, query_string)
		if not ok then
			print("Failed to parse query for filetype: " .. filetype)
			return nil
		end
		local comments = {}
		for _, captures, _ in query:iter_matches(tree:root(), bufnr) do
			if captures[1] then -- captures[1] corresponds to @comment
				local node = captures[1]
				local start_row, start_col, end_row, end_col = node:range()

				-- Get all lines of the comment
				local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)

				-- Process each line to remove delimiter and trim
				local comment_lines = {}
				for i, line in ipairs(lines) do
					if i == 1 then
						-- Find and remove the comment delimiter only on the first line
						line = line:gsub("^%s*([%-%-/%#]+%s*)", "")
					end
					-- Trim leading and trailing whitespace
					line = line:match("^%s*(.-)%s*$")
					table.insert(comment_lines, line)
				end

				-- Join the processed lines
				local text = table.concat(comment_lines, "\n")
				table.insert(comments, text)
			end
		end
		return comments
	end

	vim.api.nvim_create_augroup("ReadCommentsTSTree", { clear = true })
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = "ReadCommentsTSTree",
		pattern = "*",
		callback = function()
			local bufnr = vim.fn.bufnr("%")
			local comments = get_comments(bufnr)
			if comments and #comments > 0 then
				for _, comment in ipairs(comments) do
					local lowered = comment:lower()

					-- Check for ai/ai!/ai? at start OR end
					local commentMatch = lowered:match("^%s*ai!?%??%s*$") -- standalone "ai/ai!/ai?"
						or lowered:match("^%s*ai%?%s+") -- starts with "ai? "
						or lowered:match("^%s*ai%s+") -- starts with "ai "
						or lowered:match("%s+ai%?%s*$") -- ends with " ai?"
						or lowered:match("%s+ai%s*$") -- ends with " ai"

					if commentMatch then
						if not terminal.is_running() then
							terminal.spawn()

							vim.defer_fn(function()
								vim.api.nvim_buf_call(bufnr, function()
									vim.cmd("silent w")
								end)
							end, 2000)
						end

						if lowered:match("^%s*ai%?%s+") or lowered:match("%s+ai%?%s*$") then
							local term = terminal.terminal()
							if not term:is_open() then
								terminal.toggle_window(nil, nil)
							end
							term:focus()
						end
					end
				end
			end
		end,
	})
end
return M
