return {
    "saghen/blink.cmp",
    dependencies = {
        'saghen/blink.lib',
        "rafamadriz/friendly-snippets",
        "ribru17/blink-cmp-spell",
        { "echasnovski/mini.icons", config = {} }
    },

    build = function()
        require('blink.cmp').build():pwait()
    end,


    opts = {
        keymap = { 
            preset = "default",

            -- Restore Neovim's native digraph behavior
            ["<C-k>"] = { "fallback" },

            -- Use the same key as native LSP signature help,
            -- but let Blink provide the UI
            ["<C-s>"] = {
                "show_signature",
                "hide_signature",
                "fallback",
            },
        },

        appearance = {
            nerd_font_variant = "mono"
        },

        completion = {
            documentation = { auto_show = false },
            ghost_text = { enabled = true },
        },

        signature = {
            enabled = true,
            window = {
                show_documentation = false
            },
        },

        sources = {
            default = { "lsp", "path", "snippets", "buffer", "spell" },

            providers = {
                spell = {
                    name = "Spell",
                    module = "blink-cmp-spell",

                    -- Don't start throwing spelling suggestions at you
                    -- immediately after typing one character.
                    min_keyword_length = 3,

                    -- Slightly deprioritize spelling relative to LSP etc.
                    score_offset = -10,

                    opts = {
                        max_entries = 5,

                        -- Don't show the already-correct word as a suggestion.
                        preselect_current_word = false,

                        -- cmp-spell's sorting works nicely for partially
                        -- typed words and avoids needing custom fuzzy.sorts.
                        use_cmp_spell_sorting = true,

                        enable_in_context = function()
                            local curpos = vim.api.nvim_win_get_cursor(0)
                            local captures = vim.treesitter.get_captures_at_pos(
                                0,
                                curpos[1] - 1,
                                curpos[2]
                            )

                            for _, capture in ipairs(captures) do
                                if capture.capture == "nospell" then
                                    return false
                                end
                            end

                            return true
                        end,
                    },
                },
            },
        },

        fuzzy = { implementation = "prefer_rust_with_warning" },
    },
}
