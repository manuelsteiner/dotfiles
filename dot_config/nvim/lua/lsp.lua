-- Language servers run in per-server Podman containers, built locally from the
-- Containerfiles in <chezmoi>/lsp-containers/ (tag localhost/nvim-lsp/<name>:local).
-- Build them once with `lsp-containers/build.sh`; Podman never auto-pulls them.
--
-- Sandbox defaults (see lua/lsp/container.lua): --network=none, --read-only
-- root fs, --userns=keep-id, --cap-drop=all, --security-opt=no-new-privileges,
-- tmpfs /tmp + /home/lsp, HOME=/home/lsp. The project root is bind-mounted at
-- its real absolute path (rw) and used as the workdir.
--
-- Every server: toolchain/binary baked into the image (see lsp-containers/), only
-- read-only host *data* mounted for analysis.
--
--   Server                  Net   Host mounts beyond the project          Reason
--   ansiblels               none  ~/.ansible/collections (ro, if present)  lint playbooks that use Galaxy collections
--   basedpyright            none  -                                       in-project venv resolves (same-path mount)
--   bashls                  none  -                                       shellcheck/shfmt + tmpfs /tmp in image
--   cssls / html / jsonls   none  -                                       shared vscode-langservers-extracted image
--   docker_language_server  none  -                                       replaces dockerls + docker_compose_language_service
--   gopls                   none  ~/go/pkg/mod (ro)                        consume modules; Go + GOTOOLCHAIN=local in image
--   lua_ls                  none  /usr/share/hypr/stubs, $VIMRUNTIME (ro)  resolve Hyprland hl + Neovim vim globals
--   markdown_oxide          none  -                                       file watching is client-side (Neovim)
--   phpactor                none  -                                       vendor/ resolves (same-path mount)
--   qmlls                   none  -                                       Qt + Quickshell QML baked into image
--   rust_analyzer           none  ~/.cargo/registry (ro, same path)        crate sources for go-to-def; toolchain + rust-src in image
--   tailwindcss             none  -                                       needs a real Tailwind project (workspace_required)
--   terraformls             none  -                                       provider schemas from host `terraform init`; terraform bin in image
--   texlab                  none  -                                       no TeX Live; build/chktex disabled in settings
--   ts_ls                   none  -                                       workspace node_modules resolves (same-path mount)
--   yamlls                  none  -                                       SchemaStore off (offline); modelines still work
--
-- No network exception, no writable-root exception. Dependencies are populated
-- by normal host tooling (go mod download, cargo fetch/build, terraform init,
-- composer/npm install, ansible-galaxy collection install) and consumed from
-- the read-only mounts above.
--
-- vscode-languageserver based servers (cssls, html, jsonls, ts_ls, yamlls,
-- bashls, tailwindcss) watchdog the editor's processId, which does not exist in
-- the container PID namespace; the `processId = nil` override below stops them
-- self-exiting after a few seconds.

local container = require("lsp.container").container

local home = vim.env.HOME
local go_modcache = home .. "/go/pkg/mod"
local cargo_home = home .. "/.cargo"
local cargo_registry = cargo_home .. "/registry"

local ansible_collections = home .. "/.ansible/collections"

local servers = {
  ansiblels = {
    image = "localhost/nvim-lsp/ansible-language-server:local",
    -- Galaxy collections installed on the host, for linting playbooks that use
    -- them. Populate with `ansible-galaxy collection install -r requirements.yml`.
    volumes = vim.uv.fs_stat(ansible_collections)
        and { ansible_collections .. ":" .. ansible_collections .. ":ro" }
      or nil,
  },

  basedpyright = { image = "localhost/nvim-lsp/basedpyright:local" },

  bashls = { image = "localhost/nvim-lsp/bash-language-server:local" },

  cssls = {
    image = "localhost/nvim-lsp/vscode-langservers-extracted:local",
    cmd = { "vscode-css-language-server", "--stdio" },
  },

  docker_language_server = { image = "localhost/nvim-lsp/docker-language-server:local" },

  gopls = {
    image = "localhost/nvim-lsp/gopls:local",
    volumes = { go_modcache .. ":" .. go_modcache .. ":ro" },
    env = {
      GOPATH = "/home/lsp/go",
      GOMODCACHE = go_modcache,
      GOFLAGS = "-mod=readonly",
      GOTOOLCHAIN = "local",
      GOCACHE = "/home/lsp/.cache/go-build",
    },
  },

  html = {
    image = "localhost/nvim-lsp/vscode-langservers-extracted:local",
    cmd = { "vscode-html-language-server", "--stdio" },
  },

  jsonls = {
    image = "localhost/nvim-lsp/vscode-langservers-extracted:local",
    cmd = { "vscode-json-language-server", "--stdio" },
  },

  lua_ls = {
    image = "localhost/nvim-lsp/lua-language-server:local",
    -- Extra args appended after the image entrypoint: redirect the log/meta
    -- dirs off the read-only rootfs onto the HOME tmpfs.
    cmd = {
      "--logpath=/home/lsp/.cache/lua-language-server/log",
      "--metapath=/home/lsp/.cache/lua-language-server/meta",
    },
    volumes = {
      "/usr/share/hypr/stubs:/usr/share/hypr/stubs:ro",
      vim.env.VIMRUNTIME .. ":" .. vim.env.VIMRUNTIME .. ":ro",
    },
  },

  markdown_oxide = { image = "localhost/nvim-lsp/markdown-oxide:local" },

  phpactor = { image = "localhost/nvim-lsp/phpactor:local" },

  qmlls = {
    image = "localhost/nvim-lsp/qmlls:local",
    -- Extra args after the image entrypoint: point qmlls at the Quickshell modules.
    cmd = { "-I", "/usr/lib/qt6/qml" },
    env = { QT_QPA_PLATFORM = "offscreen" },
  },

  rust_analyzer = {
    image = "localhost/nvim-lsp/rust-analyzer:local",
    -- Crate sources only; the toolchain + rust-src live in the image. The
    -- registry is mounted at its real host path so go-to-definition into a
    -- dependency returns a URI Neovim can open; CARGO_HOME is a writable tmpfs
    -- at that same path, with the read-only registry mounted inside it.
    tmpfs = { cargo_home },
    volumes = { cargo_registry .. ":" .. cargo_registry .. ":ro" },
    env = {
      CARGO_HOME = cargo_home,
      CARGO_NET_OFFLINE = "true",
    },
  },

  tailwindcss = { image = "localhost/nvim-lsp/tailwindcss-language-server:local" },

  terraformls = { image = "localhost/nvim-lsp/terraform-ls:local" },

  texlab = { image = "localhost/nvim-lsp/texlab:local" },

  ts_ls = { image = "localhost/nvim-lsp/typescript-language-server:local" },

  yamlls = { image = "localhost/nvim-lsp/yaml-language-server:local" },
}

for name, opts in pairs(servers) do
  vim.lsp.config(name, { cmd = container(opts) })
end

-- Each container keeps its own PID namespace (better isolation than sharing the
-- host's), so a language server that watchdogs the editor's `processId` -- every
-- vscode-languageserver based one: cssls, html, jsonls, ts_ls, yamlls, bashls,
-- tailwindcss -- sees it as gone and exits within seconds. Report no parent
-- process instead of weakening the sandbox. Neovim still stops the container on
-- exit and `--rm` removes it; the only leak is if Neovim is `kill -9`ed, which
-- leaves the container running until it is reaped manually.
vim.lsp.config("*", {
  before_init = function(params)
    params.processId = vim.NIL
  end,
})

vim.lsp.enable({
  "ansiblels",
  "basedpyright",
  "bashls",
  "cssls",
  "docker_language_server",
  "gopls",
  "html",
  "jsonls",
  "lua_ls",
  "markdown_oxide",
  "phpactor",
  "qmlls",
  "rust_analyzer",
  "tailwindcss",
  "terraformls",
  "texlab",
  "ts_ls",
  "yamlls",
})

-- Server-specific Neovim settings (merge on top of the container cmd and the
-- lsp/<name>.lua base files).

local capabilities = vim.lsp.protocol.make_client_capabilities()

-- ansiblels attaches only to `yaml.ansible` (nvim-lspconfig's default); the
-- `yaml`/`yaml.ansible`/`yaml.docker-compose` split is decided in lua/filetype.lua.
vim.lsp.config("ansiblels", {
  filetypes = { "yaml.ansible" },
})

-- nvim-lspconfig ships a `before_init` for tailwindcss, which shadows the
-- global `processId = nil` above. Re-apply it here (this explicit call wins
-- over the runtimepath file) while keeping the upstream tabSize default.
vim.lsp.config("tailwindcss", {
  before_init = function(params, config)
    params.processId = vim.NIL
    config.settings = vim.tbl_deep_extend("keep", config.settings or {}, {
      editor = { tabSize = vim.lsp.util.get_effective_tabstop() },
    })
  end,
})

-- ~/.config/quickshell has no .git; give qmlls markers that identify it as the
-- project root (explicit call, so it wins over nvim-lspconfig's `{ ".git" }`).
vim.lsp.config("qmlls", {
  root_markers = { "shell.qml", "quickshell.qml", ".qmlls.ini", ".git" },
})

vim.lsp.config("markdown_oxide", {
  -- Ensure that dynamicRegistration is enabled! This allows the LS to take into account actions like the
  -- Create Unresolved File code action, resolving completions for unindexed code blocks, ...
  capabilities = vim.tbl_deep_extend(
    "force",
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

vim.diagnostic.config({
  virtual_text = {
    current_line = true,
  },
})
