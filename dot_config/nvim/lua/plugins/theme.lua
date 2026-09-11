local function active_theme()
    local path = vim.fn.expand("~/.local/state/dotfiles-theme/current/nvim.lua")
    local ok, theme = pcall(dofile, path)
    return ok and theme or { colorscheme = "rose-pine", oled = false }
end

local active_theme = active_theme()
local colorscheme = active_theme.colorscheme
local oled = active_theme.oled == true

local function resolved_highlight(name, seen)
    seen = seen or {}
    if seen[name] then return {} end
    seen[name] = true

    local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
    if next(highlight) ~= nil then return highlight end

    local linked = vim.api.nvim_get_hl(0, { name = name, link = true })
    return linked.link and resolved_highlight(linked.link, seen) or {}
end

local function set_background(groups, background, create)
    for _, group in ipairs(groups) do
        local highlight = resolved_highlight(group)
        if create or next(highlight) ~= nil then
            highlight.default = nil
            highlight.link = nil
            highlight.bg = background
            vim.api.nvim_set_hl(0, group, highlight)
        end
    end
end

local function apply_oled_ui()
    set_background({ "Normal", "NormalNC", "EndOfBuffer", "SignColumn", "LineNr", "FoldColumn" }, "#000000")

    local surface = active_theme.highlight_low or "#18181a"
    local overlay = active_theme.overlay or "#2a2a2d"
    local selection = active_theme.highlight_med or "#353539"

    set_background({
        "NormalFloat", "Float", "NvimFloat", "FloatBorder", "FloatTitle", "FloatFooter",
        "Pmenu", "PmenuKind", "PmenuExtra",
        "BlinkCmpMenu", "BlinkCmpDoc", "BlinkCmpSignatureHelp",
    }, surface)
    set_background({ "PmenuSbar", "BlinkCmpScrollBarGutter" }, overlay)
    set_background({
        "PmenuSel", "PmenuKindSel", "PmenuExtraSel", "PmenuMatchSel", "PmenuThumb",
        "BlinkCmpMenuSelection", "BlinkCmpDocCursorLine", "BlinkCmpSignatureHelpActiveParameter",
        "BlinkCmpScrollBarThumb",
    }, selection)

    set_background({
        "SnacksNormal", "SnacksNormalNC", "SnacksPicker", "SnacksPickerBox",
        "SnacksPickerInput", "SnacksPickerList", "SnacksPickerPreview",
    }, surface, true)
    local preview = resolved_highlight("Normal")
    preview.default = nil
    preview.link = nil
    preview.bg = surface
    vim.api.nvim_set_hl(0, "SnacksPickerPreview", preview)
    local prompt = resolved_highlight("Special")
    prompt.default = nil
    prompt.link = nil
    prompt.bg = surface
    vim.api.nvim_set_hl(0, "SnacksPickerPrompt", prompt)
    set_background({ "SnacksPickerListCursorLine", "SnacksPickerPreviewCursorLine" }, selection, true)
end

local function apply_oled_preview_columns()
    local groups = { "Normal", "SignColumn", "FoldColumn", "LineNr", "EndOfBuffer" }
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.w[win].snacks_picker_preview then
            local entries = {}
            for entry in vim.gsplit(vim.wo[win].winhighlight, ",", { plain = true, trimempty = true }) do
                local source = entry:match("^([^:]+):")
                if not vim.tbl_contains(groups, source) then
                    table.insert(entries, entry)
                end
            end
            for _, group in ipairs(groups) do
                table.insert(entries, group .. ":SnacksPickerPreview")
            end
            vim.wo[win].winhighlight = table.concat(entries, ",")
        end
    end
end

local themes = {
    ["rose-pine"] = {
        "rose-pine/neovim",
        name = "rose-pine",
        config = function()
            require("rose-pine").setup({
                highlight_groups = {
                    LspInlayHint = { fg = "muted", bg = oled and "#000000" or "base", inherit = false },
                },
            })
        end,
    },
    ["carbonfox"] = {
        "EdenEast/nightfox.nvim",
    },
    ["everforest"] = {
        "neanias/everforest-nvim",
        config = function()
            require("everforest").setup({ background = "hard" })
        end,
    },
    ["kanagawa-dragon"] = {
        "rebelot/kanagawa.nvim",
    },
    ["mellow"] = {
        "mellow-theme/mellow.nvim",
    },
    ["moonfly"] = {
        "bluz71/vim-moonfly-colors",
    },
    ["no-clown-fiesta"] = {
        "aktersnurra/no-clown-fiesta.nvim",
        config = function()
            require("no-clown-fiesta").setup({ theme = "dim" })
        end,
    },
    ["poimandres"] = {
        "olivercederborg/poimandres.nvim",
        config = function()
            require("poimandres").setup({})
        end,
    },
    ["tokyonight-night"] = {
        "folke/tokyonight.nvim",
    },
    ["zenbones"] = {
        "zenbones-theme/zenbones.nvim",
        dependencies = { "rktjmp/lush.nvim" },
    },
}

local name = colorscheme
local spec = themes[name]
if not spec then
    name = "rose-pine"
    spec = themes[name]
end

spec.lazy = false
spec.priority = 1000

local configure = spec.config
spec.config = function()
    if configure then configure() end
    vim.cmd.colorscheme(name)
    if oled then
        apply_oled_ui()
        local oled_preview_group = vim.api.nvim_create_augroup("dotfiles_oled_preview_surface", { clear = true })
        vim.api.nvim_create_autocmd({ "WinNew", "BufWinEnter" }, {
            group = oled_preview_group,
            callback = function()
                vim.defer_fn(apply_oled_preview_columns, 50)
            end,
        })
        vim.api.nvim_create_autocmd("VimEnter", {
            once = true,
            callback = function()
                vim.schedule(function()
                    apply_oled_ui()
                    apply_oled_preview_columns()
                end)
            end,
        })
    end
end

return { spec }
