#!/usr/bin/env bash
# Assemble the same profile for an ISO package or for the nested preview.
set -euo pipefail

quickshell=${1:?UPSTREAM_QUICKSHELL_DIR is required}
profile=${2:?NEW_PROFILE_DIR is required}
browser=${3:-}
if [[ -n $browser && ! $browser =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.desktop$ ]]; then
    echo "Expected a browser desktop ID such as firefox.desktop" >&2
    exit 2
fi
if [[ ! -f $quickshell/shell/shell.qml || ! -f $quickshell/hub/shell.qml ]]; then
    echo "Invalid Ryoku Quickshell tree: $quickshell" >&2
    exit 1
fi
hypr="$(dirname -- "${quickshell%/}")/hypr"
if [[ ! -f $hypr/modules/binds.lua ]]; then
    echo "Missing Ryoku Hyprland config: $hypr" >&2
    exit 1
fi

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -e $profile || -L $profile ]]; then
    echo "Choose a new profile directory: $profile" >&2
    exit 1
fi

draft=$(mktemp -d -- "$(dirname -- "$profile")/.tsukuyomi-preview.XXXXXXXX")
trap 'rm -rf -- "$draft"' EXIT
install -d "$draft/.config/quickshell" "$draft/.config/ryoku" "$draft/.local/share/applications" \
    "$draft/Pictures/Wallpapers"
find "$quickshell" -mindepth 1 -maxdepth 1 ! -name ryostore \
    -exec cp -a -t "$draft/.config/quickshell/" -- {} +
cp -a -- "$hypr" "$draft/.config/"
sed -i 's/Ryoku Settings/Tsukuyomi Hub/g' "$draft/.config/hypr/modules/window_rules.lua"
sed -i '/hl\.dsp\.global("ryoku:ask")/d; /ryoku-summon Rashin /d; s/ryoku-restart-audio/systemctl --user restart pipewire.service pipewire-pulse.service wireplumber.service/' \
    "$draft/.config/hypr/modules/binds.lua"

jq --arg browser "${browser%.desktop}" \
    '.dock.pinned = (["tsukuyomi-launcher", "org.kde.dolphin"] +
        ([$browser] | map(select(length > 0))) + ["kitty"])' \
    "$here/shell.json" > "$draft/.config/ryoku/shell.json"
printf '{"clockEnabled":false,"calendarEnabled":false}\n' > "$draft/.config/ryoku/widgets.json"
jq -n --arg browser "$browser" '
    {desktop:{apps:{files:"dolphin", browser:(
        if $browser == "" then "xdg-open about:blank"
        else "gtk-launch " + $browser end
    )}}}' > "$draft/.config/ryoku/desktop.json"
printf '{"enabled":false}\n' > "$draft/.config/ryoku/visualizer.json"
printf '{"scheme":"dark","followWallpaper":false}\n' > "$draft/.config/ryoku/theme.json"
printf '{"general":{"notifyOnWallpaperChange":false,"closeOnSelection":true},"keys":{"apply":"enter"}}\n' \
    > "$draft/.config/ryoku/ryogami.json"

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
