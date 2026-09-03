if command -q starship
    set -gx STARSHIP_CONFIG "$HOME/.local/state/dotfiles-theme/current/starship.toml"
    starship init fish | source
end
