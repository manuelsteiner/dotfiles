return {
    "theprimeagen/harpoon",
    branch = "harpoon2",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },

    config = function()
        local harpoon = require("harpoon"):setup()

        local normalize_list = function(t)
            local normalized = {}
            for _, v in pairs(t) do
                if v ~= nil then
                    table.insert(normalized, v)
                end
            end
            return normalized
        end

        vim.keymap.set("n", "<leader>fh", function()
            Snacks.picker({
                title = "Harpoon Windows",
                finder = function()
                    local file_paths = {}
                    local list = normalize_list(harpoon:list().items)
                    for i, item in ipairs(list) do
                        table.insert(file_paths, { text = item.value, file = item.value })
                    end
                    return file_paths
                end,
                win = {
                    input = {
                        keys = { ["dd"] = { "harpoon_delete", mode = { "n", "x" } } },
                    },
                    list = {
                        keys = { ["dd"] = { "harpoon_delete", mode = { "n", "x" } } },
                    },
                },
                actions = {
                    harpoon_delete = function(picker, item)
                        local to_remove = item or picker:selected()
                        harpoon:list():remove({ value = to_remove.text })
                        harpoon:list().items = normalize_list(harpoon:list().items)
                        picker:find({ refresh = true })
                    end,
                },
            })
        end,
            { desc = "Find harpoon windows in snacks picker" })
    end,

    keys = {
        { "<leader>h", function() require("harpoon"):list():add() end,                                    desc = "Harpoon file", },
        { "<leader>H", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "Open harpoon window", },
        { "[h",        function() require("harpoon"):list():prev() end,                                   desc = "Harpoon to previous file", },
        { "]h",        function() require("harpoon"):list():next() end,                                   desc = "Harpoon to next file", },
        { "<leader>1", function() require("harpoon"):list():select(1) end,                                desc = "Harpoon to file 1", },
        { "<leader>2", function() require("harpoon"):list():select(2) end,                                desc = "Harpoon to file 2", },
        { "<leader>3", function() require("harpoon"):list():select(3) end,                                desc = "Harpoon to file 3", },
        { "<leader>4", function() require("harpoon"):list():select(4) end,                                desc = "Harpoon to file 4", },
        { "<leader>5", function() require("harpoon"):list():select(5) end,                                desc = "Harpoon to file 5", },
    },
}
