#!/bin/sh
set -eu

legacy_theme="${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lua/plugins/rose-pine.lua"
if [ -e "$legacy_theme" ] || [ -L "$legacy_theme" ]; then
    rm -f "$legacy_theme"
fi
