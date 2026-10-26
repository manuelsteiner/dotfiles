local M = {}

local zettelkasten_dir = vim.fn.expand("~/Zettelkasten")
local template_dir = zettelkasten_dir .. "/Templates"
local inbox_dir = zettelkasten_dir .. "/Inbox"

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function resolve_template(name)
    name = trim(name or "Note")
    name = name:gsub("%.[mM][dD]$", "")
    local wanted = name:lower()

    for _, path in ipairs(vim.fn.globpath(template_dir, "*", false, true)) do
        if vim.fn.isdirectory(path) == 0 and path:lower():match("%.md$") then
            local stem = vim.fn.fnamemodify(path, ":t:r")
            if stem:lower() == wanted then
                return path
            end
        end
    end
end

local function complete_template(arg_lead, command_line, cursor_pos)
    local before_cursor = command_line:sub(1, cursor_pos)
    local command, arguments = before_cursor:match("^%s*(%S+)%s*(.*)$")
    if not command or command:gsub("^:", ""):lower() ~= "notefromtemplate" then
        return {}
    end

    local preceding = arguments:sub(1, #arguments - #arg_lead)
    if preceding:match("%S") then
        return {}
    end

    local lead = arg_lead:lower()
    local names = {}
    for _, path in ipairs(vim.fn.globpath(template_dir, "*", false, true)) do
        if vim.fn.isdirectory(path) == 0 and path:lower():match("%.md$") then
            local name = vim.fn.fnamemodify(path, ":t:r"):lower()
            if name:sub(1, #lead) == lead then
                names[#names + 1] = name
            end
        end
    end

    table.sort(names)
    return names
end

local function replace_template_tokens(lines, title, created_at)
    local iso_date = os.date("%Y-%m-%d", created_at)
    local long_date = os.date("%d %B %Y", created_at)
    local time = os.date("%H:%M", created_at)

    for i, line in ipairs(lines) do
        line = line:gsub("{{date:DD MMMM YYYY}}", long_date)
        line = line:gsub("{{date}}", iso_date)
        line = line:gsub("{{time}}", time)
        line = line:gsub("{{title}}", function() return title end)
        lines[i] = line
    end

    return lines
end

local function open_note(template_name, title)
    local template_path = resolve_template(template_name)
    if not template_path then
        vim.notify("No Markdown template named '" .. (template_name or "Note") .. "' in " .. template_dir,
            vim.log.levels.ERROR)
        return
    end

    title = trim(title or "")
    if title == "" then
        vim.notify("A note title is required", vim.log.levels.WARN)
        return
    end

    local filename_title = title:gsub("[/\\]", "-"):gsub("%s+", " ")
    if filename_title == "." or filename_title == ".." then
        vim.notify("That title cannot be used as a note filename", vim.log.levels.ERROR)
        return
    end

    local created_at = os.time()
    local destination = string.format("%s/%s - %s.md", inbox_dir, os.date("%Y%m%d", created_at), filename_title)

    -- Reopening an existing same-day note is safer than replacing its contents.
    if vim.fn.filereadable(destination) == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(destination))
        return
    end

    local lines = vim.fn.readfile(template_path)
    vim.cmd("edit " .. vim.fn.fnameescape(destination))
    local buffer = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, replace_template_tokens(lines, title, created_at))
    vim.bo[buffer].modified = true
end

function M.new(template_name, title)
    template_name = trim(template_name or "Note")
    if template_name == "" then
        template_name = "Note"
    end

    if title ~= nil then
        open_note(template_name, title)
        return
    end

    vim.ui.input({ prompt = "Note title: " }, function(input)
        if input == nil then
            return
        end
        open_note(template_name, input)
    end)
end

function M.setup()
    vim.api.nvim_create_user_command("NoteFromTemplate", function(command)
        local template_name = command.fargs[1]
        local title = table.concat(command.fargs, " ", 2)
        M.new(template_name, title ~= "" and title or nil)
    end, {
        nargs = "*",
        complete = complete_template,
        desc = "Create a Zettelkasten note from a template",
        force = true,
    })
end

return M
