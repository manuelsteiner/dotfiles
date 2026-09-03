-- lua_ls runs in a container (see lua/lsp.lua). $VIMRUNTIME and the Hyprland
-- Lua type stubs are bind-mounted read-only at their real paths so the `vim`
-- and Hyprland `hl` globals resolve. The nvim config tree is indexed when it is
-- itself the workspace root.
return {
    settings = {
        Lua = {
            diagnostics = {
                globals = { "vim" },
            },
            hint = {
                enable = true,
                arrayIndex = "Disable",
            },
            workspace = {
                library = {
                    vim.env.VIMRUNTIME,
                    "/usr/share/hypr/stubs",
                },
            },
        },
    },
}
