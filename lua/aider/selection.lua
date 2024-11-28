local M = {}

---Get the current visual selection
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return string[] lines Selected lines
---@return number start_line Starting line number
---@return number start_col Starting column number
---@return number end_line Ending line number
---@return number end_col Ending column number
function M.get_visual_selection(bufnr)
    local api = vim.api
    local esc_feedkey = api.nvim_replace_termcodes("<ESC>", true, false, true)
    bufnr = bufnr or 0

    api.nvim_feedkeys(esc_feedkey, "n", true)
    api.nvim_feedkeys("gv", "x", false)
    api.nvim_feedkeys(esc_feedkey, "n", true)

    local end_line, end_col = unpack(api.nvim_buf_get_mark(bufnr, ">"))
    local start_line, start_col = unpack(api.nvim_buf_get_mark(bufnr, "<"))
    local lines = api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

    -- get whole buffer if there is no current/previous visual selection
    if start_line == 0 then
        lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
        start_line = 1
        start_col = 0
        end_line = #lines
        end_col = #lines[#lines]
    end

    -- use 1-based indexing and handle selections made in visual line mode
    start_col = start_col + 1
    end_col = math.min(end_col, #lines[#lines] - 1) + 1

    -- shorten first/last line according to start_col/end_col
    lines[#lines] = lines[#lines]:sub(1, end_col)
    lines[1] = lines[1]:sub(start_col)

    return lines, start_line, start_col, end_line, end_col
end

return M
