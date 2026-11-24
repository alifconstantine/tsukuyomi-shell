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
find "$quickshell" -mindepth 1 -maxdepth 1 \
    -exec cp -a -t "$draft/.config/quickshell/" -- {} +
install -m 644 "$here/SessionLockscreenPage.qml" "$here/CompatPage.qml" "$here/clockwork-orbital-preview.webp" \
    "$draft/.config/quickshell/hub/pages/"
# Quickshell isolates each config's relative imports.
for config in hub ryostore shell; do
    cp -a -- "$here/tsukuyomi" "$draft/.config/quickshell/$config/"
done
if [[ -d "$here/compat" ]]; then
    cp -a -- "$here/compat" "$draft/.config/quickshell/compat"
    cp -a -- "$here/tsukuyomi" "$draft/.config/quickshell/compat/"
fi
cp -a -- "$here/notch" "$draft/.config/quickshell/shell/modules/notch"
cp -a -- "$hypr" "${hypr%/hypr}/matugen" "$draft/.config/"
sed -i -e 's/Ryoku Settings/Tsukuyomi Hub/g' \
    -e '/name   = "float-ryostore",/{ N; s/name   = "float-ryostore",\n    match  = { title = "\^(Ryostore)/name   = "float-tsukuyomi-store",\n    match  = { title = "^(Tsukuyomi Store)/; }' \
    "$draft/.config/hypr/modules/window_rules.lua"
sed -i '/hl\.dsp\.global("ryoku:ask")/d; /ryoku-summon Rashin /d; /hl\.dsp\.exec_cmd("ryotunes")/d; s/ryoku-restart-audio/systemctl --user restart pipewire.service pipewire-pulse.service wireplumber.service/' \
    "$draft/.config/hypr/modules/binds.lua"
sed -i '/hl\.dsp\.global("ryoku:launcher")/c\
hl.bind(K(mod .. " + Space"), hl.dsp.exec_cmd("ryoku-shell launcher"))' \
    "$draft/.config/hypr/modules/binds.lua"

jq --arg browser "${browser%.desktop}" \
    '.dock.pinned = (["tsukuyomi-launcher", "org.kde.dolphin"] +
        ([$browser] | map(select(length > 0))) + ["kitty"])' \
    "$here/shell.json" > "$draft/.config/ryoku/shell.json"
printf '{"clockEnabled":true,"clockDesign":"digital","clock24h":true,"dateShow":true,"calendarEnabled":false}\n' > "$draft/.config/ryoku/widgets.json"
jq -n --arg browser "$browser" '
    {desktop:{apps:{files:"dolphin", browser:(
        if $browser == "" then "gtk-launch \"$(xdg-settings get default-web-browser)\""
        else "gtk-launch " + $browser end
    )}}}' > "$draft/.config/ryoku/desktop.json"
printf '{"enabled":false}\n' > "$draft/.config/ryoku/visualizer.json"
printf '{"followWallpaper":true}\n' > "$draft/.config/ryoku/theme.json"
printf '{"general":{"notifyOnWallpaperChange":false,"closeOnSelection":true},"keys":{"apply":"enter"},"selector":{"livePreview":true},"transition":{"enabled":true,"family":"random","shader":"random","durationMs":900,"preview":true},"performance":{"maxThumbJobs":4}}\n' \
    > "$draft/.config/ryoku/ryogami.json"

install -m 644 "$here"/wallpapers/* "$draft/Pictures/Wallpapers/"
install -m 644 "$here/tsukuyomi-launcher.desktop" "$draft/.local/share/applications/"
install -m 644 "$here/tsukuyomi-store.desktop" "$draft/.local/share/applications/"
install -m 644 "$here/ryoku-hub.desktop" "$draft/.local/share/applications/"
for app in ryostore rashin-app; do
    printf '[Desktop Entry]\nType=Application\nName=%s\nHidden=true\n' "$app" \
        > "$draft/.local/share/applications/$app.desktop"
done

shopt -s nullglob
for change in "$here"/patches/*.patch; do
    patch --batch --forward --fuzz=0 --no-backup-if-mismatch -d "$draft/.config/quickshell" -p1 < "$change"
done
for change in "$here"/hypr-patches/*.patch; do
    patch --batch --forward --fuzz=0 --no-backup-if-mismatch -d "$draft/.config/hypr" -p1 < "$change"
done
find "$draft" -name '*.orig' -delete

# Build-time syntax gates: never ship broken Lua or JSON configs.
if command -v luac >/dev/null 2>&1; then
    while IFS= read -r -d '' lua_file; do
        luac -p "$lua_file"
    done < <(find "$draft/.config/hypr" -name '*.lua' -type f -print0)
fi
while IFS= read -r -d '' json_file; do
    jq empty "$json_file"
done < <(find "$draft/.config/ryoku" -name '*.json' -type f -print0)

widget_catalog="$draft/.config/quickshell/shell/modules/bar/barstyles/qsbar/core"
{
    printf '.pragma library\nvar entries = '
    jq -ac . "$widget_catalog/widgets.json"
} > "$widget_catalog/WidgetCatalogData.js"

mv -T --no-clobber -- "$draft" "$profile"
if [[ -d $draft ]]; then
    echo "Profile already exists: $profile" >&2
    exit 1
fi
printf 'Staged Tsukuyomi desktop preview in %s\n' "$profile"
