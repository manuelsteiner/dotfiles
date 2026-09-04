function __dotfiles_theme_refresh --on-event fish_prompt
    set -l state_dir "$HOME/.local/state/dotfiles-theme"
    set -l name_file "$state_dir/current.name"

    test -r "$name_file"; or return
    set -l theme (string trim < "$name_file")
    test -n "$theme"; or return
    test "$theme" = "$__dotfiles_theme_loaded"; and return

    set -g __dotfiles_theme_loaded "$theme"

    set -l fish_theme "$state_dir/current/fish.fish"
    test -r "$fish_theme"; and source "$fish_theme"

    set -l fzf_theme "$state_dir/current/fzf.fish"
    test -r "$fzf_theme"; and source "$fzf_theme"
end
