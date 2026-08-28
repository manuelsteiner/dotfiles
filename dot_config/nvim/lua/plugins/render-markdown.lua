return {
    "MeanderingProgrammer/render-markdown.nvim",
    lazy = true,
    ft = "markdown",
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        { "echasnovski/mini.icons", config = {} }
    },

    opts = {
        checkbox = {
            custom = {
                cancelled = { raw = "[-]", rendered = "󰜺 ", highlight = "DiagnosticError" },
                important = { raw = "[!]", rendered = " ", highlight = "DiagnosticWarn" },
                forwarded = { raw = "[>]", rendered = "󰊍 ", highlight = "DiagnosticHint" },
            },
        },
    },
}
