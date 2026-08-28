return  {
    settings = {
        ['rust-analyzer'] = {
            procMacro = { enable = true },
            cargo = { allFeatures = true },
            inlayHints = {
                closingBraceHints = { enable = false },
            }
        },
    },
}
