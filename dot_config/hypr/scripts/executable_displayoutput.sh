#!/usr/bin/env bash

set -o nounset
set -o errexit

# Get current input
current=$(ddcutil getvcp 60 | sed -n "s/.*(sl=\(.*\))/\1/p")

# Get the other input
case $current in

    # USB-C
    0x1b)
        output=0x11
        ;;

    # HDMI-1
    0x11)
        output=0x1b
        ;;

    *)
        echo "Unknown input"
        exit 1
        ;;
esac

# Set new input
ddcutil setvcp 60 $output
