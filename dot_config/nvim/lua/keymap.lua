vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set('i', 'jk', '<ESC>')
vim.keymap.set('i', 'kj', '<ESC>')

vim.keymap.set("n", "<leader>j", "ddp")
vim.keymap.set("n", "<leader>k", "ddkP")
vim.keymap.set("v", "<C-j>", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "<C-k>", ":m '<-2<CR>gv=gv")
