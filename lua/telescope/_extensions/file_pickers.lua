local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	error("This plugin requires nvim-telescope/telescope.nvim")
end

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local terminal = require("aider.terminal")
local config = require("aider").config

local function aider_action(prompt_bufnr)
	local picker = action_state.get_current_picker(prompt_bufnr)
	local paths = {}

	for _, entry in ipairs(picker:get_multi_selection()) do
		local path = entry.path or entry.filename or entry.value
		if path then
			-- Create a file_info-like object
			table.insert(paths, path)
		end
	end

	if #paths == 0 then
		local selection = action_state.get_selected_entry()
		if selection then
			local path = selection.path or selection.filename or selection.value
			if path then
				-- Create a file_info-like object
				table.insert(paths, path)
			end
		end
	end

	actions.close(prompt_bufnr)
	terminal.load_files(paths)
end

return telescope.register_extension({
	setup = function()
		-- Add mappings only to file pickers
		local files_attach_mappings = function(_, map)
			map("i", config.telescope_action_key, aider_action)
			map("n", config.telescope_action_key, aider_action)
			return true
		end

		-- Override just the file-related pickers
		telescope.setup({
			pickers = {
				find_files = {
					attach_mappings = files_attach_mappings,
				},
				git_files = {
					attach_mappings = files_attach_mappings,
				},
				buffers = {
					attach_mappings = files_attach_mappings,
				},
				oldfiles = {
					attach_mappings = files_attach_mappings,
				},
			},
		})
	end,
})
