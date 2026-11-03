#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

monitor_serial="W5LMAS021679"

current=$(ddcutil --sn "$monitor_serial" getvcp 0x60 |
    sed -nE 's/.*\(sl=0x([[:xdigit:]]+)\).*/\1/p' |
    tr '[:upper:]' '[:lower:]')

# The PG32UCDM3 reports DP-1 as 0x0f and USB-C as 0x1a.
case $current in
    0f)
        output=0x1a
        ;;
    1a)
        output=0x0f
        ;;

    *)
        printf 'Unknown input source on ASUS PG32UCDM3 (serial %s): %s\n' \
            "$monitor_serial" "${current:-unreadable}" >&2
        exit 1
        ;;
esac

ddcutil --sn "$monitor_serial" setvcp 0x60 "$output"
