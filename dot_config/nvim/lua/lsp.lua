vim.lsp.enable({
    "ansiblels",
    "basedpyright",
    "bashls",
    "cssls",
    "docker_compose_language_service",
    "dockerls",
    "gopls",
    "html",
    "jsonls",
    "lua_ls",
    "markdown_oxide",
    "phpactor",
    "qmlls",
    "rust_analyzer",
    "sqls",
    "tailwindcss",
    "terraformls",
    "texlab",
    "ts_ls",
    "yamlls",
})

local capabilities = vim.lsp.protocol.make_client_capabilities()

vim.lsp.config("ansiblels", {
  filetypes = { "yaml" },
})

vim.lsp.config('markdown_oxide', {
    -- Ensure that dynamicRegistration is enabled! This allows the LS to take into account actions like the
    -- Create Unresolved File code action, resolving completions for unindexed code blocks, ...
    capabilities = vim.tbl_deep_extend(
        'force',
        capabilities,
        {
            workspace = {
                didChangeWatchedFiles = {
                    dynamicRegistration = true,
                },
            },
        }
    ),
})

vim.lsp.config("qmlls", {
  cmd = { "qmlls6" },
})

vim.diagnostic.config({
    virtual_text = {
        current_line = true,
    },
})
