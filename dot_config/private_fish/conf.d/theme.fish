set -l theme_state "$HOME/.local/state/dotfiles-theme/current/fish.fish"
if test -r "$theme_state"
    source "$theme_state"
end
