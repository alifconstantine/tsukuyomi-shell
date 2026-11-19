#!/usr/bin/env bash
# Seed a fresh test profile from the Ryoku QML matching the installed binaries.
set -euo pipefail

if (( $# < 1 || $# > 2 )); then
    echo "Usage: $0 NEW_PROFILE_DIR [BROWSER_DESKTOP_ID]" >&2
    exit 2
fi

profile=$1
browser=${2:-}
if [[ -n $browser && ! $browser =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.desktop$ ]]; then
    echo "Expected a browser desktop ID such as firefox.desktop" >&2
    exit 2
fi

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
runtime_version='1:1.0.9.r6109.g08ff328'
for spec in "ryoku-shell $runtime_version-1" "ryoku-blobs $runtime_version-1" \
    "ryoku-hub $runtime_version-1" "ryogami $runtime_version-1" \
    "ryoku-desktop-hyprland $runtime_version-2" "ryoku-desktop $runtime_version-5"; do
    if [[ $(pacman -Q "${spec%% *}" 2>/dev/null) != "$spec" ]]; then
        echo "This preview requires $spec" >&2
        exit 1
    fi
done

if [[ -e $profile || -L $profile ]]; then
    echo "Choose a new profile directory: $profile" >&2
    exit 1
fi

source_config=/usr/share/ryoku/config
draft=$(mktemp -d -- "$(dirname -- "$profile")/.tsukuyomi-preview.XXXXXXXX")
trap 'rm -rf -- "$draft"' EXIT
install -d "$draft/.config/quickshell" "$draft/.config/ryoku" "$draft/.local/share/applications" \
    "$draft/Pictures/Wallpapers"
find "$source_config/quickshell" -mindepth 1 -maxdepth 1 ! -name ryostore \
    -exec cp -a -t "$draft/.config/quickshell/" -- {} +

jq --arg browser "${browser%.desktop}" \
    '.dock.pinned = (["tsukuyomi-launcher", "org.kde.dolphin"] +
        ([$browser] | map(select(length > 0))) + ["kitty"])' \
    "$here/shell.json" > "$draft/.config/ryoku/shell.json"
printf '{"clockEnabled":false,"calendarEnabled":false}\n' > "$draft/.config/ryoku/widgets.json"
printf '{"enabled":false}\n' > "$draft/.config/ryoku/visualizer.json"
printf '{"scheme":"dark","followWallpaper":false}\n' > "$draft/.config/ryoku/theme.json"
printf '{"general":{"notifyOnWallpaperChange":false}}\n' > "$draft/.config/ryoku/ryogami.json"

install -m 644 "$here/../dots/.config/quickshell/ii/assets/images/default_wallpaper.webp" \
    "$draft/Pictures/Wallpapers/Black Hole.webp"
install -m 644 "$here/tsukuyomi-launcher.desktop" "$draft/.local/share/applications/"
install -m 644 "$here/ryoku-hub.desktop" "$draft/.local/share/applications/"
for app in ryostore rashin-app; do
    printf '[Desktop Entry]\nType=Application\nName=%s\nHidden=true\n' "$app" \
        > "$draft/.local/share/applications/$app.desktop"
done

shopt -s nullglob
for change in "$here"/patches/*.patch; do
    patch --batch --forward --fuzz=0 -d "$draft/.config/quickshell" -p1 < "$change"
done

mv -T --no-clobber -- "$draft" "$profile"
if [[ -d $draft ]]; then
    echo "Profile already exists: $profile" >&2
    exit 1
fi
printf 'Staged Tsukuyomi desktop preview in %s\n' "$profile"
