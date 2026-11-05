#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

monitor_serial="W5LMAS021679"
right_monitor="DP-1"
left_monitor="DP-3"
workspace_state="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/asus-right-workspaces.json"

current=$(ddcutil --sn "$monitor_serial" getvcp 0x60 |
    sed -nE 's/.*\(sl=0x([[:xdigit:]]+)\).*/\1/p' |
    tr '[:upper:]' '[:lower:]')

monitor_is_connected() {
    hyprctl monitors -j |
        jq -e --arg monitor "$1" 'any(.[]; .name == $monitor)' >/dev/null
}

save_right_workspaces() {
    local temporary_file="${workspace_state}.tmp.$$"
    local active_workspace

    active_workspace=$(hyprctl monitors -j |
        jq -er --arg monitor "$right_monitor" \
            '.[] | select(.name == $monitor) | .activeWorkspace.id')
    hyprctl workspaces -j |
        jq --arg monitor "$right_monitor" --argjson active "$active_workspace" \
            '{active: $active,
              workspaces: [
                .[] |
                select(.monitor == $monitor and .type == "normal") |
                select((.name | ascii_downcase | contains("multimedia")) | not) |
                {name, id}
              ]}' >"$temporary_file"
    mv "$temporary_file" "$workspace_state"
}

move_saved_workspaces() {
    local target_monitor="$1"
    local workspace_id

    while IFS= read -r workspace_id; do
        [[ -n "$workspace_id" ]] || continue
        hyprctl eval \
            "local ws = hl.get_workspace($workspace_id); local mon = hl.get_monitor(\"$target_monitor\"); if ws and mon then hl.dispatch(hl.dsp.workspace.move({ workspace = ws, monitor = mon })) end" \
            >/dev/null
    done < <(jq -r '.workspaces[].id' "$workspace_state")
}

saved_workspaces_are_on() {
    local target_monitor="$1"
    local workspace_id

    while IFS= read -r workspace_id; do
        [[ -n "$workspace_id" ]] || continue
        if ! hyprctl workspaces -j |
            jq -e --arg monitor "$target_monitor" --argjson id "$workspace_id" \
                'any(.[]; .id == $id and .monitor == $monitor)' >/dev/null; then
            return 1
        fi
    done < <(jq -r '.workspaces[].id' "$workspace_state")
}

focus_saved_workspace() {
    local target_monitor="$1"
    local active_workspace

    active_workspace=$(jq -r '.active // empty' "$workspace_state")
    [[ -n "$active_workspace" ]] || return 0
    jq -e --argjson id "$active_workspace" \
        'any(.workspaces[]; .id == $id)' "$workspace_state" >/dev/null || return 0

    hyprctl eval \
        "local ws = hl.get_workspace($active_workspace); local mon = hl.get_monitor(\"$target_monitor\"); if ws and mon then hl.dispatch(hl.dsp.focus({ workspace = ws })) end" \
        >/dev/null
}

settle_workspace_animation() {
    # The configured workspace animation lasts 194 ms; let it finish before
    # changing the monitor input or returning control to the user.
    sleep 0.3
}

wait_for_right_monitor() {
    local attempt

    for attempt in {1..30}; do
        if monitor_is_connected "$right_monitor"; then
            return 0
        fi
        sleep 0.25
    done
    return 1
}

restore_right_workspaces() {
    [[ -f "$workspace_state" ]] || return 0

    if ! wait_for_right_monitor; then
        printf 'Timed out waiting for %s to reconnect; saved workspace list kept at %s\n' \
            "$right_monitor" "$workspace_state" >&2
        return 1
    fi

    move_saved_workspaces "$right_monitor"
    if ! saved_workspaces_are_on "$right_monitor"; then
        printf 'Could not restore all saved workspaces to %s; saved workspace list kept at %s\n' \
            "$right_monitor" "$workspace_state" >&2
        return 1
    fi
    focus_saved_workspace "$right_monitor"
    settle_workspace_animation
    rm -f "$workspace_state"
}

# The PG32UCDM3 reports DP-1 as 0x0f and USB-C as 0x1a.
case $current in
    0f)
        # If a previous return to DP timed out, retry restoring its exact
        # workspace set instead of toggling the monitor back to USB-C.
        if [[ -f "$workspace_state" ]]; then
            restore_right_workspaces
            exit
        fi

        save_right_workspaces
        move_saved_workspaces "$left_monitor"
        if ! saved_workspaces_are_on "$left_monitor"; then
            printf 'Could not move the right monitor workspaces to %s; input unchanged\n' \
                "$left_monitor" >&2
            move_saved_workspaces "$right_monitor"
            if saved_workspaces_are_on "$right_monitor"; then
                rm -f "$workspace_state"
            else
                printf 'Some workspaces may have moved; recovery list kept at %s\n' \
                    "$workspace_state" >&2
            fi
            exit 1
        fi
        focus_saved_workspace "$left_monitor"
        settle_workspace_animation

        if ! ddcutil --sn "$monitor_serial" setvcp 0x60 0x1a; then
            move_saved_workspaces "$right_monitor"
            if saved_workspaces_are_on "$right_monitor"; then
                rm -f "$workspace_state"
            fi
            exit 1
        fi
        ;;
    1a)
        ddcutil --sn "$monitor_serial" setvcp 0x60 0x0f
        restore_right_workspaces
        ;;

    *)
        printf 'Unknown input source on ASUS PG32UCDM3 (serial %s): %s\n' \
            "$monitor_serial" "${current:-unreadable}" >&2
        exit 1
        ;;
esac
