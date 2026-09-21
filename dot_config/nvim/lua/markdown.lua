-- Formats the Markdown table under the cursor in Neovim:
--   * Adds a missing header separator row (e.g. | --- | --- |)
--   * Adds missing leading/trailing pipes
--   * Aligns all columns (respects :---, ---:, :---: if already present)

local M = {}

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function is_table_line(line)
    return line:match("|") ~= nil
end

function M.split_row(line)
    line = trim(line)
    line = line:gsub("^|", ""):gsub("|$", "")
    local cells = {}
    for cell in (line .. "|"):gmatch("(.-)|") do
        table.insert(cells, trim(cell))
    end
    return cells
end

local function is_separator_line(line)
    local cells = M.split_row(line)
    if #cells == 0 then return false end
    for _, c in ipairs(cells) do
        if not c:match("^:?%-+:?$") then
            return false
        end
    end
    return true
end

-- Walk up/down from the cursor to find the full contiguous block of
-- lines that contain a "|", i.e. the whole table.
local function find_table_bounds(bufnr, cur_line)
    local start_line = cur_line
    local end_line = cur_line
    local total = vim.api.nvim_buf_line_count(bufnr)

    while start_line > 1 do
        local line = vim.api.nvim_buf_get_lines(bufnr, start_line - 2, start_line - 1, false)[1]
        if line and is_table_line(line) then
            start_line = start_line - 1
        else
            break
        end
    end

    while end_line < total do
        local line = vim.api.nvim_buf_get_lines(bufnr, end_line, end_line + 1, false)[1]
        if line and is_table_line(line) then
            end_line = end_line + 1
        else
            break
        end
    end

    return start_line, end_line
end

function M.format_table()
    local bufnr = vim.api.nvim_get_current_buf()
    local cur_line = vim.api.nvim_win_get_cursor(0)[1]
    local cur_text = vim.api.nvim_buf_get_lines(bufnr, cur_line - 1, cur_line, false)[1]

    if not cur_text or not is_table_line(cur_text) then
        vim.notify("Cursor is not on a Markdown table line", vim.log.levels.WARN)
        return
    end

    local start_line, end_line = find_table_bounds(bufnr, cur_line)
    local raw_lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

    -- Parse every line into cells.
    local rows = {}
    for _, line in ipairs(raw_lines) do
        table.insert(rows, M.split_row(line))
    end

    -- Does row 2 already look like a separator?
    local has_separator = #rows >= 2 and is_separator_line(raw_lines[2])

    local ncols = 0
    for _, row in ipairs(rows) do
        if #row > ncols then ncols = #row end
    end

    -- Pull alignment (left / right / center) from an existing separator,
    -- default everything else to left.
    local aligns = {}
    if has_separator then
        for i, c in ipairs(rows[2]) do
            local left = c:sub(1, 1) == ":"
            local right = c:sub(-1) == ":"
            if left and right then
                aligns[i] = "center"
            elseif right then
                aligns[i] = "right"
            elseif left then
                aligns[i] = "left_colon"
            else
                aligns[i] = "left"
            end
        end
    end
    for i = 1, ncols do
        aligns[i] = aligns[i] or "left"
    end

    -- Collect the real data rows (header + body), dropping any existing separator.
    local data_rows = {}
    for i, row in ipairs(rows) do
        if not (has_separator and i == 2) then
            table.insert(data_rows, row)
        end
    end

    -- Pad every row out to ncols so ragged rows don't break formatting.
    for _, row in ipairs(data_rows) do
        for i = 1, ncols do
            row[i] = row[i] or ""
        end
    end

    -- Column widths (min 3 so "---" / ":--" / "--:" / ":-:" always fit).
    local widths = {}
    for i = 1, ncols do
        widths[i] = 3
    end
    for _, row in ipairs(data_rows) do
        for i = 1, ncols do
            local w = vim.fn.strdisplaywidth(row[i])
            if w > widths[i] then widths[i] = w end
        end
    end

    local function pad(text, width, align)
        local space = width - vim.fn.strdisplaywidth(text)
        if space < 0 then space = 0 end
        if align == "right" then
            return string.rep(" ", space) .. text
        elseif align == "center" then
            local left = math.floor(space / 2)
            return string.rep(" ", left) .. text .. string.rep(" ", space - left)
        else
            return text .. string.rep(" ", space)
        end
    end

    local function sep_cell(width, align)
        if align == "center" then
            return ":" .. string.rep("-", width - 2) .. ":"
        elseif align == "right" then
            return string.rep("-", width - 1) .. ":"
        elseif align == "left_colon" then
            return ":" .. string.rep("-", width - 1)
        else
            return string.rep("-", width)
        end
    end

    local out = {}

    -- Header row.
    local header = data_rows[1]
    local header_cells = {}
    for i = 1, ncols do
        local a = aligns[i] == "left_colon" and "left" or aligns[i]
        header_cells[i] = pad(header[i], widths[i], a)
    end
    table.insert(out, "| " .. table.concat(header_cells, " | ") .. " |")

    -- Separator row (always regenerated).
    local sep_cells = {}
    for i = 1, ncols do
        sep_cells[i] = sep_cell(widths[i], aligns[i])
    end
    table.insert(out, "| " .. table.concat(sep_cells, " | ") .. " |")

    -- Body rows.
    for i = 2, #data_rows do
        local row = data_rows[i]
        local cells = {}
        for j = 1, ncols do
            local a = aligns[j] == "left_colon" and "left" or aligns[j]
            cells[j] = pad(row[j], widths[j], a)
        end
        table.insert(out, "| " .. table.concat(cells, " | ") .. " |")
    end

    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, out)
end

function M.setup(bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, "MarkdownFormatTable", M.format_table, {
        desc = "Format the Markdown table under the cursor",
    })
end

return M
