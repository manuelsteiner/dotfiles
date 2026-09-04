# Dotfiles

Chezmoi source for Linux machines. Every machine has an explicit `host` and a
`role`: `private` or `work`.

## Set up a machine

Clone this repository to `~/Projects/dotfiles`, then initialize chezmoi from
that directory:

```sh
chezmoi init --source="$HOME/Projects/dotfiles"
chezmoi apply
theme-set rose-pine
```

Chezmoi prompts for the host and role on first run. Use `nuc` / `private` on
this desktop and `thinkpad` / `private` on the laptop. The work computer uses
the `work` role and its own host name.

Review a change before applying it with `chezmoi diff`. To change stored
values, force the prompts again:

```sh
chezmoi init --source="$HOME/Projects/dotfiles" --prompt
```

## Local-only configuration

These files deliberately stay outside chezmoi:

- `~/.config/fish/config.local.fish` for machine-specific Fish setup.
- `~/.config/git/config.local` for Git identity, work remotes, and other
  personal settings.
- `~/.config/himalaya/config.local.toml` for the Proton email address, display
  name, Bridge username, and credential. Fish sets `HIMALAYA_CONFIG` to merge
  it over the managed config.
- `~/.local/state/dotfiles-theme/current` for the selected desktop and terminal
  theme. Theme definitions and `theme-set` are managed, but the selection is
  deliberately local.

## Themes

Run `theme-set` to search and choose a theme with FZF, or pass one explicitly:

```sh
theme-set kanagawa-dragon
```

`theme-set --list` shows the available names. It updates Kitty, Fuzzel, Fish,
FZF, Starship, bat, eza, Delta, Hyprland, Hyprlock, Quickshell, and Neovim's colorscheme. It
reloads Hyprland, Kitty, and a running Quickshell. New Fish, Fuzzel, and
Neovim sessions read the selected theme when they start. It also selects
htop's Nord color layout while keeping your htop settings intact; restart htop
after switching.

An already-open Fish shell refreshes its colors, `LS_COLORS`, and FZF options
at its next prompt after switching.

OpenCode uses its built-in `system` theme, which follows the active Kitty ANSI
palette. Himalaya likewise uses terminal colors. Obsidian is intentionally not
managed by the switcher because its themes and CSS are vault-specific GUI state.

Each theme also has an opt-in `-oled` variant with a pure-black base, for
example `theme-set rose-pine-oled`. Its panels retain the original theme's dark
surface colors for separation. Neovim keeps the corresponding upstream syntax
palette while explicitly setting its main editing surfaces to black; floating
windows retain their theme backgrounds.

Each palette chooses Quickshell's default accent. Leave `accentColor` as
`"default"` in `Config.qml` to use it, or set a palette role there when a
machine needs a fixed accent.

## Neovim language servers

Neovim runs every language server in a restricted Podman container instead of
installing servers with Mason. The image recipes live in `lsp-containers/` (kept in
the repo, not deployed). Build them once:

```sh
cd ~/Projects/dotfiles/lsp-containers && ./build.sh
```

Podman never auto-pulls these; an enabled-but-unbuilt server just fails to start
until it is built. `lsp-containers/README.md` documents the sandbox, per-server
mounts, and version management (`lsp-containers/versions.env`). The Neovim side is
`.config/nvim/lua/lsp.lua` plus the helper `.config/nvim/lua/lsp/container.lua`.

Old Mason-installed server binaries under `~/.local/share/nvim/mason/` are now
unused and can be removed.

## Private services

Private machines receive user-unit files for the SSH agent, GeoClue agent, and
Proton Mail Bridge. Chezmoi installs files but does not enable services. Enable
the ones wanted on a new machine explicitly:

```sh
systemctl --user enable --now ssh-agent.service
systemctl --user enable --now geoclue-agent.service
systemctl --user enable --now protonmail-bridge.service
```

## Quickshell values

The internal template `quickshell/default.qml` is the complete shared private
configuration. `Config.qml` is rendered from it. Add the internal
`quickshell/thinkpad.qml` template from the laptop's configuration when it is
available; that is where laptop-only values such as `wg-home` belong. These
value files exist only in chezmoi and are not deployed to Quickshell.

The work role ignores private desktop files, including Hyprland, Quickshell,
Fuzzel, Darkman, GTK preferences, MIME associations, Himalaya, and the private
user units.

## Hyprland displays and wallpaper

Monitor layout is host-specific. `nuc` uses its HDMI output; `thinkpad` uses
its internal `eDP-1` display plus a generic external-display fallback. Other
hosts use a generic fallback. We may replace these declarations with
Hyprmoncfg later.

Wallpaper images are not tracked. Hyprpaper and Hyprlock both refer to
`~/Pictures/wallpaper.png`, so each private machine can use its own image at
that path.
