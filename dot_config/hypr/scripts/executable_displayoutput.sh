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

    hyprctl workspaces -j |
        jq --arg monitor "$right_monitor" \
            '[.[] | select(.monitor == $monitor and (.type == "normal" or .type == "special")) |
             select((.name | ascii_downcase | contains("multimedia")) | not) |
             {type, name, id}]' >"$temporary_file"
    mv "$temporary_file" "$workspace_state"
}

move_saved_workspaces() {
    local target_monitor="$1"
    local workspace workspace_type workspace_id workspace_name

    while IFS= read -r workspace; do
        workspace_type=$(jq -r '.type' <<<"$workspace")
        workspace_id=$(jq -r '.id // empty' <<<"$workspace")
        workspace_name=$(jq -r '.name' <<<"$workspace")

        if [[ "$workspace_type" == "normal" ]]; then
            hyprctl eval \
                "local ws = hl.get_workspace($workspace_id); local mon = hl.get_monitor(\"$target_monitor\"); if ws and mon then hl.dispatch(hl.dsp.workspace.move({ workspace = ws, monitor = mon })) end" \
                >/dev/null
        else
            hyprctl eval \
                "local ws = hl.get_workspace(\"$workspace_name\"); local mon = hl.get_monitor(\"$target_monitor\"); if ws and mon then mon:set_special_workspace(ws) end" \
                >/dev/null
        fi
    done < <(jq -c '.[]' "$workspace_state")
}

saved_workspaces_are_on() {
    local target_monitor="$1"
    local workspace workspace_type workspace_id workspace_name

    while IFS= read -r workspace; do
        workspace_type=$(jq -r '.type' <<<"$workspace")
        workspace_id=$(jq -r '.id // empty' <<<"$workspace")
        workspace_name=$(jq -r '.name' <<<"$workspace")

        if [[ "$workspace_type" == "normal" ]]; then
            if ! hyprctl workspaces -j |
                jq -e --arg monitor "$target_monitor" --argjson id "$workspace_id" \
                    'any(.[]; .id == $id and .monitor == $monitor)' >/dev/null; then
                return 1
            fi
        elif ! hyprctl workspaces -j |
            jq -e --arg monitor "$target_monitor" --arg name "$workspace_name" \
                'any(.[]; .name == $name and .type == "special" and .monitor == $monitor)' >/dev/null; then
            return 1
        fi
    done < <(jq -c '.[]' "$workspace_state")
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
