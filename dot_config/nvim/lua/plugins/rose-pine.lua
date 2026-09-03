local function active_theme()
    local path = vim.fn.expand("~/.local/state/dotfiles-theme/current/nvim.lua")
    local ok, theme = pcall(dofile, path)
    return ok and theme or { colorscheme = "rose-pine", oled = false }
end

local active_theme = active_theme()
local colorscheme = active_theme.colorscheme
local oled = active_theme.oled == true

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
        for _, group in ipairs({ "Normal", "NormalNC", "EndOfBuffer", "SignColumn", "LineNr", "FoldColumn" }) do
            local highlight = vim.api.nvim_get_hl(0, { name = group, link = false })
            highlight.bg = "#000000"
            vim.api.nvim_set_hl(0, group, highlight)
        end
    end
end

return { spec }
