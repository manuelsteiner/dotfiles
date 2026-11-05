#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    dark)
        gtk_theme="adw-gtk3-dark"
        color_scheme="prefer-dark"
        ;;
    light)
        gtk_theme="adw-gtk3"
        color_scheme="prefer-light"
        ;;
    *)
        printf 'Expected Darkman mode "dark" or "light", got: %s\n' "${1:-}" >&2
        exit 2
        ;;
esac

gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"
gsettings set org.gnome.desktop.interface color-scheme "$color_scheme"
