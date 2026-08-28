function fcd -a dir
    if not command -q fd; or not command -q fzf
        return 1
    end

    if test -z "$dir"
        set folder (fd --hidden --glob .git --type d --maxdepth 3 --format '{//}' ~/Projects | fzf --reverse --height ~100%)
    else
        set folder (fd --hidden --glob .git --type d --format '{//}' "$dir" | fzf --reverse --height ~100%)
    end

    if set -q folder
        cd "$folder"
    end
end
