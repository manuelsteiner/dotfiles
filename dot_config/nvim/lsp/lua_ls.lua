-- lua_ls runs in a container (see lua/lsp.lua). $VIMRUNTIME and the Hyprland
-- Lua type stubs are bind-mounted read-only at their real paths so the `vim`
-- and Hyprland `hl` globals resolve. The nvim config tree is indexed when it is
-- itself the workspace root.
return {
    -- This identifies ~/.config/nvim when Neovim was started elsewhere. Keep
    -- the upstream Lua project markers so ordinary Lua projects still resolve
    -- to their own roots.
    root_markers = {
        "lazyvim.json",
        { ".emmyrc.json", ".luarc.json", ".luarc.jsonc" },
        { ".luacheckrc", ".stylua.toml", "stylua.toml", "selene.toml", "selene.yml" },
        { ".git" },
    },
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
