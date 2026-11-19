#!/usr/bin/env bash
# Invoked by the nested compositor once its Wayland socket is ready.
set -euo pipefail

dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
ryogami &
ryoku-shell daemon &

wallpaper="$HOME/Pictures/Wallpapers/Black Hole.webp"
for attempt in {1..40}; do
    if ryogami wallpaper set "$wallpaper" 2>/dev/null; then
        exit 0
    fi
    sleep 0.25
done
printf 'Could not seed the preview wallpaper: %s\n' "$wallpaper" >&2
exit 1
