-- Run a language server inside a restricted Podman container.
--
-- `container(opts)` returns a `cmd` function for `vim.lsp.config`. The project
-- root the LSP resolves for the buffer (`config.root_dir`, or the cwd in
-- single-file mode) is bind-mounted at the SAME absolute path inside the
-- container and used as the working directory, so file paths in LSP requests
-- and responses need no translation. `/` and `$HOME` are refused as roots.
--
-- This is intentionally small: one fixed set of hardening flags plus a few
-- per-server escape hatches. It is not a general container framework.

local M = {}

-- Applied to every server container. `--read-only` and `--network` are added by
-- the returned function so they can be relaxed per server.
local BASE_ARGS = {
  "--interactive",
  "--rm",
  "--init",
  "--userns=keep-id",
  "--cap-drop=all",
  "--security-opt=no-new-privileges",
  "--tmpfs=/tmp",
  "--tmpfs=/home/lsp",
  "--env=HOME=/home/lsp",
  "--label=nvim-lsp",
}

--- @class LspContainerOpts
--- @field image string              Fully-qualified, tag-pinned image reference.
--- @field cmd? string[]             Args appended after the image entrypoint (or the
---                                  full argv for an entrypoint-less image).
--- @field network? string          `podman run --network` value (default "none").
--- @field volumes? string[]         Extra `-v` specs, e.g. "/path:/path:ro".
--- @field tmpfs? string[]           Extra writable tmpfs paths, e.g. a CACHE_HOME.
--- @field env? table<string,string> Extra environment variables.
--- @field writable_root? boolean    Drop `--read-only` (documented per-server exception).
--- @field root_ro? boolean          Mount the resolved project root read-only.

--- @param opts LspContainerOpts
--- @return fun(dispatchers: table, config: table): table?
function M.container(opts)
  assert(opts.image, "lsp.container: `image` is required")

  return function(dispatchers, config)
    -- Prefer the LSP-resolved project root. Fall back to the cwd only in
    -- single-file mode (no root markers matched), and never mount a root so
    -- broad it would expose most of the filesystem.
    local root = config.root_dir
    if not root or root == "" then
      root = vim.fn.getcwd()
    end
    local home = vim.uv.os_homedir()
    if root == "/" or root == home or root == (home or "") .. "/" then
      error(("lsp.container[%s]: resolved workspace root %q is too broad to bind-mount"):format(
        config.name or "?", root
      ))
    end

    local argv = { "podman", "run" }
    vim.list_extend(argv, BASE_ARGS)
    table.insert(argv, "--network=" .. (opts.network or "none"))
    if not opts.writable_root then
      table.insert(argv, "--read-only")
    end

    -- Project root at an identical host/container path, as the working dir.
    table.insert(argv, "--volume")
    table.insert(argv, ("%s:%s:%s"):format(root, root, opts.root_ro and "ro" or "rw"))
    table.insert(argv, "--workdir")
    table.insert(argv, root)

    for _, path in ipairs(opts.tmpfs or {}) do
      table.insert(argv, "--tmpfs=" .. path)
    end

    for _, spec in ipairs(opts.volumes or {}) do
      table.insert(argv, "--volume")
      table.insert(argv, spec)
    end

    for name, value in pairs(opts.env or {}) do
      table.insert(argv, "--env")
      table.insert(argv, name .. "=" .. value)
    end

    table.insert(argv, opts.image)
    vim.list_extend(argv, opts.cmd or {})

    if vim.env.LSP_CONTAINER_DEBUG then
      vim.schedule(function()
        vim.notify(table.concat(argv, " "), vim.log.levels.DEBUG)
      end)
    end

    return vim.lsp.rpc.start(argv, dispatchers)
  end
end

return M
