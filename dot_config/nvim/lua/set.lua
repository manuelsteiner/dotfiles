vim.opt['timeoutlen'] = 1000
vim.opt['ttimeoutlen'] = 10

vim.opt['termguicolors'] = true

vim.opt['syntax'] = 'on'

vim.opt['conceallevel'] = 0
vim.opt['foldlevelstart'] = 99

vim.opt['number'] = true
vim.opt['relativenumber'] = true

vim.opt['cursorline'] = false

vim.opt['laststatus'] = 0

vim.opt['showmode'] = true
vim.opt['showcmd'] = true

vim.opt['tabstop'] = 4
vim.opt['softtabstop'] = 4
vim.opt['shiftwidth'] = 4
vim.opt['expandtab'] = true

vim.opt['colorcolumn'] = { 80 }

vim.opt['backupdir'] = vim.fn.expand('~/.nvim/backup/')
vim.opt['directory'] = vim.fn.expand('~/.nvim/swap/')
vim.opt['undodir'] = vim.fn.expand('~/.nvim/undo/')
