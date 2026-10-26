local M = {}

local zettelkasten_dir = vim.fn.expand("~/Zettelkasten")
local template_dir = zettelkasten_dir .. "/Templates"
local inbox_dir = zettelkasten_dir .. "/Inbox"
local notes_dir = zettelkasten_dir .. "/Zettelkasten"

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function absolute_path(path)
    return vim.fn.fnamemodify(path, ":p"):gsub("/+$", "")
end

local function is_inside(path, directory)
    local candidate = absolute_path(path)
    local parent = absolute_path(directory)
    return candidate:sub(1, #parent + 1) == parent .. "/"
end

local function find_note_conflict(destination, current_buffer)
    local destination_name = vim.fn.fnamemodify(destination, ":t"):lower()

    for _, path in ipairs(vim.fn.globpath(notes_dir, "*", false, true)) do
        if vim.fn.isdirectory(path) == 0
            and vim.fn.fnamemodify(path, ":t"):lower() == destination_name then
            return path
        end
    end

    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if buffer ~= current_buffer then
            local name = vim.api.nvim_buf_get_name(buffer)
            if name ~= "" and absolute_path(name):lower() == absolute_path(destination):lower() then
                return name
            end
        end
    end
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

function M.accept()
    local buffer = vim.api.nvim_get_current_buf()
    local source = absolute_path(vim.api.nvim_buf_get_name(buffer))
    local inbox = absolute_path(inbox_dir)

    if not is_inside(source, inbox) or not source:lower():match("%.md$") then
        vim.notify("NoteAccept only works on Markdown notes inside the Zettelkasten Inbox", vim.log.levels.WARN)
        return
    end

    local basename = vim.fn.fnamemodify(source, ":t")
    local title = basename:match("^%d%d%d%d%d%d%d%d%s%-%s(.+)%.[mM][dD]$")
    if not title or title == "" then
        vim.notify("Inbox note filename must use YYYYMMDD - Title.md", vim.log.levels.ERROR)
        return
    end

    if vim.fn.isdirectory(notes_dir) ~= 1 then
        vim.notify("Zettelkasten notes folder does not exist: " .. notes_dir, vim.log.levels.ERROR)
        return
    end

    local destination = notes_dir .. "/" .. title .. ".md"
    local conflict = find_note_conflict(destination, buffer)
    if conflict then
        vim.notify("A note with this title already exists: " .. conflict .. ". Inbox note left unchanged.",
            vim.log.levels.WARN)
        return
    end

    if vim.fn.filereadable(source) ~= 1 then
        vim.notify("Inbox note file no longer exists: " .. source, vim.log.levels.ERROR)
        return
    end

    if vim.bo[buffer].modified then
        local ok, err = pcall(vim.api.nvim_buf_call, buffer, function() vim.cmd("write") end)
        if not ok then
            vim.notify("Could not save Inbox note before moving it: " .. tostring(err), vim.log.levels.ERROR)
            return
        end
    end

    -- A hard link creates the destination only if it does not already exist;
    -- unlinking the Inbox name then completes the move without overwriting.
    local linked, link_error = vim.uv.fs_link(source, destination)
    if not linked then
        vim.notify("Could not move Inbox note: " .. tostring(link_error), vim.log.levels.ERROR)
        return
    end

    local unlinked, unlink_error = vim.uv.fs_unlink(source)
    if not unlinked then
        vim.uv.fs_unlink(destination)
        vim.notify("Could not remove the old Inbox path: " .. tostring(unlink_error), vim.log.levels.ERROR)
        return
    end

    local renamed, rename_error = pcall(vim.api.nvim_buf_set_name, buffer, destination)
    if not renamed then
        vim.uv.fs_link(destination, source)
        vim.uv.fs_unlink(destination)
        vim.notify("Note moved back to Inbox because Neovim could not rename its buffer: "
            .. tostring(rename_error), vim.log.levels.ERROR)
        return
    end

    vim.bo[buffer].modified = false
    vim.notify("Accepted note: " .. vim.fn.fnamemodify(destination, ":t"), vim.log.levels.INFO)
end

function M.delete()
    local buffer = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(buffer)
    local path = absolute_path(name)
    local templates = absolute_path(template_dir)
    local obsidian = absolute_path(zettelkasten_dir .. "/.obsidian")

    if name == "" or not is_inside(path, zettelkasten_dir) or not path:lower():match("%.md$")
        or is_inside(path, templates) or is_inside(path, obsidian) then
        vim.notify("NoteDelete only works on Markdown notes in the Zettelkasten vault", vim.log.levels.WARN)
        return
    end

    local filename = vim.fn.fnamemodify(path, ":t")
    local prompt = "Delete " .. filename .. " permanently"
    if vim.bo[buffer].modified then
        prompt = prompt .. " and discard unsaved changes"
    end
    local confirmation = trim(vim.fn.input(prompt .. "? [y/N] ") or ""):lower()
    if confirmation ~= "y" and confirmation ~= "yes" then
        return
    end

    if vim.fn.filereadable(path) == 1 then
        local deleted, delete_error = vim.uv.fs_unlink(path)
        if not deleted then
            vim.notify("Could not delete note: " .. tostring(delete_error), vim.log.levels.ERROR)
            return
        end
    end

    local ok, err = pcall(vim.api.nvim_buf_delete, buffer, { force = true })
    if not ok then
        vim.notify("Note file was deleted, but Neovim could not close its buffer: " .. tostring(err),
            vim.log.levels.ERROR)
        return
    end

    vim.notify("Deleted note: " .. filename, vim.log.levels.INFO)
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

    vim.api.nvim_create_user_command("NoteAccept", function() M.accept() end, {
        desc = "Move the current Inbox note into Zettelkasten",
        force = true,
    })

    vim.api.nvim_create_user_command("NoteDelete", function() M.delete() end, {
        desc = "Delete the current Zettelkasten note",
        force = true,
    })
end

return M
