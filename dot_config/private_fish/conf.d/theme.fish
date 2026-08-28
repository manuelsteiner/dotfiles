if command -q fish_config
    fish_config theme choose "Rose Pine"
end

if command -q vivid
    set -gx LS_COLORS "$(vivid generate rose-pine)"
end
