#!/usr/bin/env bash
# Run the test desktop inside a nested Hyprland window.
set -euo pipefail

if (( $# > 1 )); then
    echo "Usage: $0 [BROWSER_DESKTOP_ID]" >&2
    exit 2
fi

if [[ -z ${XDG_RUNTIME_DIR:-} || -z ${WAYLAND_DISPLAY:-} ]]; then
    echo 'Open the preview from a Wayland desktop session.' >&2
    exit 1
fi

parent=$WAYLAND_DISPLAY
[[ $parent = /* ]] || parent=$XDG_RUNTIME_DIR/$parent
if [[ ! -S $parent ]]; then
    echo "Wayland socket unavailable: $parent" >&2
    exit 1
fi

for command in bwrap dbus-run-session start-hyprland ryogami; do
    if ! command -v "$command" >/dev/null; then
        echo "Missing preview dependency: $command" >&2
        exit 1
    fi
done

shopt -s nullglob
gpu=()
for node in /dev/dri/renderD*; do
    [[ ! -r $node || ! -w $node ]] || gpu+=(--dev-bind "$node" "$node")
done
if (( ${#gpu[@]} == 0 )); then
    echo 'Hyprland preview needs an accessible DRM render node.' >&2
    exit 1
fi

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
"$here/stage-preview.sh" "$work/profile" "${1:-}"
mkdir -m 700 "$work/runtime"

# Only the parent Wayland socket and GPU render nodes cross from the session.
# The preview gets its own home, runtime sockets, D-Bus and network namespace.
bwrap --unshare-all --die-with-parent \
    --ro-bind /usr /usr --ro-bind /etc /etc --ro-bind /sys /sys \
    --symlink usr/bin /bin --symlink usr/lib /lib --symlink usr/lib /lib64 \
    --proc /proc --dev /dev "${gpu[@]}" --tmpfs /run --tmpfs /tmp --tmpfs /var \
    --bind "$work" /preview --ro-bind "$parent" /preview/runtime/parent-wayland \
    --ro-bind "$here/preview.lua" /preview/hyprland.lua \
    --ro-bind "$here/preview-session.sh" /preview/session.sh \
    --clearenv --setenv PATH /usr/bin --setenv LANG C.UTF-8 \
    --setenv HOME /preview/profile --setenv XDG_RUNTIME_DIR /preview/runtime \
    --setenv XDG_SESSION_TYPE wayland --setenv XDG_CURRENT_DESKTOP Hyprland \
    --setenv WAYLAND_DISPLAY parent-wayland --setenv QT_QPA_PLATFORM wayland \
    --setenv RYOKU_WM hyprland --chdir /preview/profile \
    -- /usr/bin/dbus-run-session /usr/bin/start-hyprland -- --config /preview/hyprland.lua
