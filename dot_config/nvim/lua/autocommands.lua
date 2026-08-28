local group = vim.api.nvim_create_augroup('vimrc', { clear = true })

local default_diagnostics = {
    virtual_text = {
        current_line = true,
    },
    virtual_lines = false,
}

local detailed_diagnostics = {
    virtual_lines = {
        current_line = true,
    },
    virtual_text = false,
}

vim.api.nvim_create_autocmd("LspAttach", {
    group = group,

    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        local opts = { buffer = args.buf }

        if client and client.server_capabilities.inlayHintProvider then
            vim.lsp.inlay_hint.enable(true,  { buffer = opts.buffer })
        end

        if client and client.name == "markdown_oxide" then

          vim.api.nvim_create_user_command(
            "Daily",
            function(args)
              local input = args.args

              vim.lsp.buf.execute_command({command="jump", arguments={input}})

            end,
            {desc = 'Open daily note', nargs = "*"}
          )
        end

        opts.desc = "Show document symbols"
        vim.keymap.set("n", "<leader>ls", function() Snacks.picker.lsp_symbols() end, opts)

        opts.desc = "Show LSP references"
        vim.keymap.set("n", "<leader>lr", function() Snacks.picker.lsp_references() end, opts)

        opts.desc = "Go to declaration"
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

        opts.desc = "Go to definition"
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)

        opts.desc = "Show LSP definitions"
        vim.keymap.set("n", "<leader>ld", function() Snacks.picker.lsp_definitions() end, opts)

        opts.desc = "Show LSP implementations"
        vim.keymap.set("n", "<leader>li", function() Snacks.picker.lsp_implementations() end, opts)

        opts.desc = "Show LSP type definitions"
        vim.keymap.set("n", "<leader>lt", function() Snacks.picker.lsp_type_definitions() end, opts)

        opts.desc = "See available code actions"
        vim.keymap.set({ "n", "v" }, "<leader>la", vim.lsp.buf.code_action, opts)

        opts.desc = "Smart rename"
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

        opts.desc = "Show buffer diagnostics"
        vim.keymap.set("n", "<leader>D", function() Snacks.picker.diagnostics_buffer() end, opts)

        opts.desc = "Show line diagnostics"
        vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)

        opts.desc = "Go to previous diagnostic"
        vim.keymap.set("n", "]d", function() vim.diagnostic.jump({count = 1, float = false}) end, opts)

        opts.desc = "Go to next diagnostic"
        vim.keymap.set("n", "[d", function() vim.diagnostic.jump({count = -1, float = false}) end, opts)

        opts.desc = "Show documentation for what is under cursor"
        vim.keymap.set("n", "<leader>lh", vim.lsp.buf.hover, opts)

        opts.desc = "Format the current buffer"
        vim.keymap.set("n", "<leader>lf", function()
            vim.lsp.buf.format({ async = true })
        end, opts)

        opts.desc = "Switch between default and detailed diagnostics view"
        vim.keymap.set("n", "<leader>dt", function()
            if vim.diagnostic.config().virtual_lines then
                vim.diagnostic.config(default_diagnostics)
            else
                vim.diagnostic.config(detailed_diagnostics)
            end
        end, opts)

        opts.desc = "Toggle inlay hints"
        vim.keymap.set("n", "<leader>it", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
        end, opts)
    end,
})

vim.api.nvim_create_autocmd({ 'BufReadPost', "BufWritePost" }, {
  pattern = '*.md',
  group = group,

  callback = function(args)
    local frontmatter_pattern = "^%-%-%-\n.-\n%-%-%-\n"

    local content = table.concat(vim.api.nvim_buf_get_lines(args.buf, 0, vim.api.nvim_buf_line_count(args.buf), false), "\n")

    local frontmatter = content:match(frontmatter_pattern)

    if frontmatter == nil then
      return
    end

    local _, count = frontmatter:gsub("\n","\n")

    vim.cmd("1," .. count .. "fold")
  end,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = {
        "markdown",
        "text",
        "gitcommit",
    },
    callback = function()
        vim.opt_local.spell = true
        vim.opt_local.spelllang = { "en", "de" }
    end,
})
