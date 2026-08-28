#!/usr/bin/env bash
# rofi -show window for Hyprland, basically

state="$(hyprctl -j clients)"
active_window="$(hyprctl -j activewindow)"

current_addr="$(echo "$active_window" | jq -r '.address')"

window="$(echo "$state" |
    jq -r '.[] | select(.monitor != -1 ) | "\(.address) \(.workspace.name) \(.title)"' |
    sed "s|$current_addr|*$current_addr|" |
    sort -r |
    fuzzel --dmenu)"

addr="$(echo "$window" | awk '{print $1}')"
ws="$(echo "$window" | awk '{print $2}')"

if [[ "$addr" =~ '\*'* ]]; then
    exit 0
fi

fullscreen_on_same_ws="$(echo "$state" | jq -r ".[] | select(.fullscreen == true) | select(.workspace.name == \"$ws\") | .address")"

if [[ "$window" != "" ]]; then
    if [[ "$fullscreen_on_same_ws" == "" ]]; then
        hyprctl dispatch "hl.dsp.focus({ window = \"address:${addr}\" })"
    else
        # If we want to focus app_A and app_B is fullscreen on the same workspace,
        # app_A will get focus, but app_B will remain on top.
        # This monstrosity is to make sure app_A will end up on top instead.
        # XXX: doesn't handle fullscreen 0, but I don't care.
        hyprctl --batch "dispatch hl.dsp.focus({ window = \"address:${fullscreen_on_same_ws}\" }); dispatch hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" }); dispatch hl.dsp.focus({ window = \"address:${addr}\" }); dispatch hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })"
    fi
fi
