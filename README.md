# Dotfiles

Chezmoi source for Linux machines. Every machine has an explicit `host` and a
`role`: `private` or `work`.

## Set up a machine

Clone this repository to `~/Projects/dotfiles`, then initialize chezmoi from
that directory:

```sh
chezmoi init --source="$HOME/Projects/dotfiles"
chezmoi apply
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
- `~/.config/himalaya/config.local.toml` for the Proton Bridge username and
  credential. Fish sets `HIMALAYA_CONFIG` to merge it with the managed config.

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
