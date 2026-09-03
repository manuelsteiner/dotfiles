if command -q fzf
    fzf --fish | source
end

set -l theme_state "$HOME/.local/state/dotfiles-theme/current/fzf.fish"
if test -r "$theme_state"
    source "$theme_state"
end
