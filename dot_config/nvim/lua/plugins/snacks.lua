return {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
        picker = {
            enabled = true,

            -- layout = {
            --     cycle = true,
            --     --- Use the default layout or vertical if the window is too narrow
            --     preset = function()
            --         return vim.o.columns >= 120 and "my_borderless_horizontal" or "my_borderless_vertical"
            --     end,
            -- },

            layouts = {
                my_borderless_horizontal = {
                    layout = {
                        box = 'horizontal',
                        fullscreen = true,
                        border = 'none',
                        {
                            box = 'vertical',
                            { win = 'input', height = 1, border = 'rounded', title = '{title} {live} {flags}', title_pos = 'center' },
                            { win = 'list', title = ' Results ', title_pos = 'center', border = 'right' },
                        },
                        {
                            win = 'preview',
                            title = '{preview:Preview}',
                            width = 0.7,
                            border = 'none',
                            title_pos = 'center',
                        },
                    },
                },
                my_borderless_vertical = {
                    layout = {
                        box = 'vertical',
                        fullscreen = true,
                        border = 'none',
                        { win = 'input', height = 1, border = 'rounded', title = '{title} {live} {flags}', title_pos = 'center' },
                        { win = 'list', title = ' Results ', title_pos = 'center', border = 'none' },
                        {
                            win = 'preview',
                            height = 0.7,
                            title = '{preview:Preview}',
                            border = 'top',
                            title_pos = 'center',
                        },
                    },
                },
            },
        },
    },
    keys = {
        { "<leader><space>", function() Snacks.picker.smart() end,                                   desc = "Smart Find Files" },
        { "<leader>,",       function() Snacks.picker.buffers() end,                                 desc = "Buffers" },
        { "<leader>/",       function() Snacks.picker.grep() end,                                    desc = "Grep" },
        { "<leader>fb",      function() Snacks.picker.buffers() end,                                 desc = "Buffers" },
        { "<leader>fc",      function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
        { "<leader>ff",      function() Snacks.picker.files() end,                                   desc = "Find Files" },
        { "<leader>fg",      function() Snacks.picker.git_files() end,                               desc = "Find Git Files" },
        { "<leader>fr",      function() Snacks.picker.recent() end,                                  desc = "Recent" },
        { "<leader>gb",      function() Snacks.picker.git_branches() end,                            desc = "Git Branches" },
        { "<leader>gl",      function() Snacks.picker.git_log() end,                                 desc = "Git Log" },
        { "<leader>gL",      function() Snacks.picker.git_log_line() end,                            desc = "Git Log Line" },
        { "<leader>gs",      function() Snacks.picker.git_status() end,                              desc = "Git Status" },
        { "<leader>gS",      function() Snacks.picker.git_stash() end,                               desc = "Git Stash" },
        { "<leader>gd",      function() Snacks.picker.git_diff() end,                                desc = "Git Diff (Hunks)" },
        { "<leader>gf",      function() Snacks.picker.git_log_file() end,                            desc = "Git Log File" },
        { "<leader>fG",      function() Snacks.picker.grep() end,                                    desc = "Grep" },
        { "<leader>fs",      function() Snacks.picker.spelling() end,                                desc = "Spelling" },
        { "<leader>fm",      function() Snacks.picker.marks() end,                                desc = "Marks" },
    },
}
