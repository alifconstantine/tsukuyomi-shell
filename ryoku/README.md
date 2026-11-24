# Tsukuyomi Desktop Preview & Staging

The preview brings up the Tsukuyomi desktop as a nested Hyprland session using the exact same pinned Ryoku (`08ff328`) profile assembly, QML patches, and Hyprland Lua patches shipped in the ISO. [Upstream notices](upstream/NOTICE)

## Open the Preview

Open a terminal in `tsukuyomi-shell/` from a Wayland desktop with the pinned Ryoku packages and `bubblewrap` installed:

```bash
./ryoku/run-preview.sh firefox.desktop
```

Pass the desktop ID of an installed browser (omit it for a dock without a browser pin). The preview uses a temporary profile and restores defaults on each run.

### Highlights & Shortcuts

- **Top Bar & Dynamic Notch:** Click the Arch logo for System Controls, sliders for QS Bar Settings, or gear for Tsukuyomi Hub. Click the center **Dynamic Notch** pill (RAM ring + clock + media visualizer) to open the 13-tab dashboard (`Home`, `Music`, `Calendar`, `To-Do`, `Timer`, `Notifications`, `Clipboard`, `Files` Shelf + Google Drive, `Translate`, `Teleprompter`, `Weather`, `Health`, `System`) and click the gear inside the Notch for **Notch Settings**.
- **Hub → Appearance:** Manage `Theme & Accent`, `Bar Studio`, `Dock` (`Show dock` / `Auto-hide` + Stage Editor), and `Lockscreen` (`Clockwork Orbital` + Store themes).
- **Hub → Compatibility:** Manage offline Windows (`.exe`/`.msi`/`.lnk` via WinBridge + Bubblewrap + Force Stop) and Android (`.apk`/`.xapk`/`.apkm` via DroidBridge + Waydroid Phone viewport + Gamescope Game Mode) apps.
- **Shortcuts:** `Super+Space` (Main Launcher with `/win` & `/apk` filters), `Super+Enter` (Kitty), `Super+E` (Dolphin), `Super+W` (Tsukuyomi Wallpapers — `Space` previews, `Enter` applies), `Super+Alt+R` (cycle Waydroid window size), `Super+L` (Lock), `Ctrl+Shift+F11` (open Hub in preview), `Ctrl+Shift+F12` (close preview).

## Staging & Package Scripts

- `stage-profile.sh UPSTREAM_QUICKSHELL_DIR NEW_PROFILE_DIR [BROWSER_DESKTOP_ID]` — stages Quickshell, Dynamic Notch, Compatibility UI, and Hyprland Lua patches (`--no-backup-if-mismatch`, zero `.orig` files).
- `stage-ui.sh STAGED_RYOKU_UI_DIR` — patches shared `Ryoku.Ui` singletons and dropdown pickers.
- `stage-picker.sh STAGED_PICKER_DIR` — patches `ryogami` (`Tsukuyomi Wallpapers`).
- `build-shell.sh OUTPUT_BIN SOURCE_CACHE` — builds the patched `ryoku-shell` Go daemon.

See [Tsukuyomi ISO build](https://github.com/alifconstantine/tsukuyomi) for full ISO assembly.
