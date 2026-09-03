# Language-server containers

The Neovim config (`dot_config/nvim/lua/lsp.lua`) runs every language server in a
restricted Podman container instead of installing servers with Mason. These are
the image recipes — the transparent, reproducible replacement for Mason's
package definitions.

## Build

```sh
./build.sh                 # all images
./build.sh gopls texlab    # only some
```

Images are tagged `localhost/nvim-lsp/<name>:local`. Podman never auto-pulls
them; an enabled-but-unbuilt server simply fails to start until you build it, so
there is no cost to keeping rarely-used definitions around. Re-run `build.sh`
after bumping a version in `versions.env`.

`versions.env` is the single source of truth for *what* versions run;
Containerfiles describe only *how* to build. `build.sh` passes each `ARG` a
Containerfile declares from `versions.env`.

## Integrity

| Source | Verification |
|---|---|
| npm packages | npm checks the registry sha512 for the pinned version |
| `go install` | Go module checksum database |
| HashiCorp (terraform-ls, terraform) | `*_SHA256` copied from the signed `SHA256SUMS` |
| other release binaries (rust-analyzer, texlab, lua-language-server, markdown-oxide, phpactor) | upstream publishes no checksum; `*_SHA256` is trust-on-first-use, recorded in `versions.env`. A changed artifact fails the build |

## Sandbox

Applied by `lua/lsp/container.lua` to every server:

```
--interactive --rm --init
--network=none
--read-only            (root filesystem; the project tree is mounted rw)
--userns=keep-id       (container uid == host uid 1000; bind-mount writes stay user-owned)
--cap-drop=all
--security-opt=no-new-privileges
--tmpfs=/tmp --tmpfs=/home/lsp --env=HOME=/home/lsp
```

The LSP-resolved project root (not Neovim's cwd) is bind-mounted at its **real
absolute path** and used as the working directory, so paths in LSP requests and
responses need no translation. No SELinux on this host, so no `:z`/`:Z`.

## Per-server decisions

| Server | Image | Network | Host mounts (all RO, same path) | Notes |
|---|---|---|---|---|
| ansiblels | ansible-language-server | none | `~/.ansible/collections` (if present) | ansible + ansible-lint baked in; bound to all YAML by `lsp.lua`; mount is used only when it exists, populate with `ansible-galaxy collection install -r requirements.yml` |
| basedpyright | basedpyright | none | — | in-project venv resolves via project mount; out-of-project venv → `:LspPyrightSetPythonPath` |
| bashls | bash-language-server | none | — | `bash` + `git` + `shellcheck` in image; tmpfs `/tmp` for scratch |
| cssls / html / jsonls | vscode-langservers-extracted (shared) | none | — | one npm package, three entrypoints; jsonls/yamlls have no SchemaStore offline |
| docker_language_server | docker-language-server | none | — | unified Dockerfile/Compose/Bake server; replaces dockerls + docker_compose_language_service |
| gopls | gopls | none | `~/go/pkg/mod` | Go toolchain in image; `GOTOOLCHAIN=local`, `GOFLAGS=-mod=readonly`; run `go mod download` on host |
| lua_ls | lua-language-server | none | `/usr/share/hypr/stubs`, `$VIMRUNTIME` | resolves Hyprland `hl` + Neovim `vim` globals |
| markdown_oxide | markdown-oxide | none | — | file watching is client-side in Neovim |
| phpactor | phpactor | none | — | reads `vendor/` via project mount; run `composer install` on host; index cache is cold each start (tmpfs HOME) |
| qmlls | qmlls | none | — | Qt + Quickshell QML modules baked in; frozen to an Arch archive snapshot |
| rust_analyzer | rust-analyzer | none | `~/.cargo/registry` (ro, same absolute path) | toolchain + rust-src in image; `cargo check` runs offline against mounted crate sources; `CARGO_HOME` is a writable tmpfs at `~/.cargo` so go-to-definition into a dependency returns a host-openable path; needs a prior host `cargo fetch`/build |
| tailwindcss | tailwindcss-language-server | none | — | needs a real Tailwind project (`workspace_required`) |
| terraformls | terraform-ls | none | — | pinned `terraform` binary baked in; provider schemas from host `terraform init` |
| texlab | texlab | none | — | no TeX Live; build/chktex disabled in settings; `:LspTexlabBuild` runs on host |
| ts_ls | typescript-language-server | none | — | workspace `node_modules/typescript` resolves via project mount |
| yamlls | yaml-language-server | none | — | SchemaStore disabled (offline); `# yaml-language-server: $schema=` modeline still works |

**No server has network access or a writable root filesystem.** Anything that
would otherwise reach the network (Go/Rust/Terraform dependency fetching or
SchemaStore) is either satisfied from a read-only mount of
host-populated state or documented above as intentionally unavailable.

## Notes

- `lua/lsp.lua` sends `processId = nil` to every server. `vscode-languageserver`
  based servers (cssls, html, jsonls, ts_ls, yamlls, bashls, tailwindcss) poll
  the editor's PID and exit within seconds when it is missing — and it always is,
  because each container has its own PID namespace. Neovim still stops the
  container on exit and `--rm` removes it; only a hard `kill -9` of Neovim can
  leave one behind.
- `rust_analyzer` runs `cargo metadata` / `cargo check` offline against the
  read-only `~/.cargo/registry` mount, which is at its real host path so
  go-to-definition into a dependency opens the actual file. Run `cargo fetch`
  (or a normal build) on the host first so every crate is in the registry;
  otherwise it reports spurious errors on macro-heavy code.
- `gopls` needs the module cache populated (`go mod download`) and uses
  `GOFLAGS=-mod=readonly` + `GOTOOLCHAIN=local`.
- `phpactor` rebuilds its index on every start (HOME is tmpfs). For large
  projects, add a writable `~/.cache/phpactor` mount in `lua/lsp.lua`.
- YAML routing is decided in `.config/nvim/lua/filetype.lua`: `compose.yaml` /
  `docker-compose.yml` etc. → `yaml.docker-compose` (`docker_language_server` +
  `yamlls`); a `.yml`/`.yaml` file with an `ansible.cfg` ancestor →
  `yaml.ansible` (`ansiblels` only); everything else → `yaml` (`yamlls`).

## Known limitations

- Go, Rust, and TypeScript servers can return definitions for their bundled
  standard-library sources. Those paths exist only in the container, so Neovim
  cannot open them. Project files, Go module-cache dependencies, and Cargo
  registry dependencies use host-readable same-path URIs.
- `gopls` needs `go mod download` on the host. `rust-analyzer` needs a prior
  host `cargo fetch` or build. Containers do not download dependencies.
- SchemaStore and other network-backed LSP features are unavailable by design
  because every server runs with `--network=none`.
- phpactor uses tmpfs HOME, so it rebuilds its index after each server start.
