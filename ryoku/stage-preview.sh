#!/usr/bin/env bash
# Seed a fresh test profile from the Ryoku QML matching the installed binaries.
set -euo pipefail

if (( $# < 1 || $# > 2 )); then
    echo "Usage: $0 NEW_PROFILE_DIR [BROWSER_DESKTOP_ID]" >&2
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

exec "$here/stage-profile.sh" /usr/share/ryoku/config/quickshell "$@"
