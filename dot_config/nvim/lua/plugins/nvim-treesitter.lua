return {
    'nvim-treesitter/nvim-treesitter',
    event = { "BufReadPost", "BufNewFile" },
    build = ":TSUpdate",
    init = function()

        local ensure_installed = {
	    'bash',
	    'bibtex',
	    'c',
	    'css',
	    'dockerfile',
	    'go',
	    'html',
	    'latex',
	    'lua',
	    'php',
	    'python',
	    'query',
	    'rust',
	    'sql',
	    'terraform',
	    'typescript',
	    'vim',
	    'vimdoc',
	    'yaml'
        }
        local treesitter = require('nvim-treesitter')

        function enable_treesitter(lang)
            if vim.list_contains (
                treesitter.get_installed(),
                vim.treesitter.language.get_lang(lang)
            ) then
                -- syntax highlighting
                vim.treesitter.start() 
                -- folds
                vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
                vim.wo[0][0].foldmethod = 'expr'
                -- indendation (experimental)
                vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
        end

        vim.api.nvim_create_autocmd('FileType', {
            callback = function(ft) 

                local lang = ft.match
                treesitter.install(ensure_installed):await(function(err)
                    if err then
                        return
                    end
                    enable_treesitter(lang)
                end)

                enable_treesitter(lang)
            end,
        })

    end,
}
