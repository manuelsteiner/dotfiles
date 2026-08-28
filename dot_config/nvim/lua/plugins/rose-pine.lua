return {
    {
        "rose-pine/neovim",
        lazy = false,
        name = "rose-pine",
        priority = 1000,
        config = function()
            require("rose-pine").setup({
                highlight_groups = {
                    LspInlayHint = { fg = "muted", bg = "base", inherit = false }
                }
            })
            vim.cmd.colorscheme "rose-pine"

        end
    }
}
