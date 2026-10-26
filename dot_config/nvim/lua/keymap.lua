vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set('i', 'jk', '<ESC>')
vim.keymap.set('i', 'kj', '<ESC>')

vim.keymap.set("n", "<leader>j", ":move .+1<CR>==")
vim.keymap.set("n", "<leader>k", ":move .-2<CR>==")
vim.keymap.set("v", "<C-j>", ":move '>+1<CR>gv=gv")
vim.keymap.set("v", "<C-k>", ":move '<-2<CR>gv=gv")

vim.keymap.set({ "n", "v" }, "<leader>y", '"+y')
vim.keymap.set({ "n", "v" }, "<leader>d", '"+d')
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p')

vim.keymap.set({ "n", "v" }, "<leader>Y", '"+Y')
vim.keymap.set({ "n", "v" }, "<leader>D", '"+D')
vim.keymap.set({ "n", "v" }, "<leader>P", '"+P')

local notes = require("notes")
notes.setup()

vim.keymap.set("n", "<leader>nn", function() notes.new("Note") end,
    { desc = "New note" })
vim.keymap.set("n", "<leader>nm", function() notes.new("Meeting") end,
    { desc = "New meeting note" })
vim.keymap.set("n", "<leader>nd", function() notes.new("Note", "Daily Notes") end,
    { desc = "Open daily note" })
