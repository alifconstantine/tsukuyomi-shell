# 月読 · Tsukuyomi Shell

Desktop profile, Hyprland Lua configuration patches, Dynamic Notch, Compatibility UI (`WinInstaller` / `DroidInstaller` / `CompatPage`), and branding/performance patches for **Tsukuyomi OS** (pinned to upstream Ryoku revision `08ff328`).

## Repository Structure

```text
tsukuyomi-shell/
├── DESIGN.md                  # Visual, layout, and interaction specification
├── LICENSE                    # GPL-3.0-only
└── ryoku/
    ├── stage-profile.sh       # Assembles Quickshell + Hyprland profile for both preview and ISO
    ├── stage-ui.sh            # Patches shared Ryoku.Ui singletons & dropdown pickers
    ├── stage-picker.sh        # Patches Tsukuyomi Wallpapers (ryogami) QML
    ├── build-shell.sh         # Builds the patched ryoku-shell Go IPC daemon
    ├── run-preview.sh         # Launches a nested Hyprland desktop preview
    ├── shell.json             # Default neutral Dark/Light + QS Bar Islands + Frosted profile
    ├── notch/                 # Tsukuyomi Dynamic Notch (13 tabs + Hub-styled Settings window)
    ├── compat/                # WinInstaller.qml & DroidInstaller.qml GUI wizards
    ├── tsukuyomi/             # Shared monochrome Hub/Store/Notch UI primitives & AntigravityCaption
    ├── CompatPage.qml         # Tsukuyomi Hub → Compatibility page (Windows & Android)
    ├── SessionLockscreenPage.qml # Tsukuyomi Hub → Appearance → Lockscreen page
    ├── patches/               # Quickshell (Hub, Store, QS Bar, Dock, Launcher, Welcome) patches
    ├── hypr-patches/          # Hyprland 0.57+ Lua patches (window rules, motion, software renderer, cursor/XDPH)
    ├── ui-patches/            # Shared Ryoku.Ui patches
    ├── wallpaper-patches/     # Tsukuyomi Wallpapers (ryogami) patches
    ├── shell-patches/         # ryoku-shell Go daemon patches
    ├── monitor-patches/       # Tsukuyomi Monitor (ryomanager) branding, WebKitGTK & telemetry patches
    └── wallpapers/            # Bundled default wallpapers (Cloud Valley default)
```

## Key Features

- **QS Bar Islands & Dynamic Notch:** Three-pill Frosted top bar (`Islands`) with a unified Dynamic Notch center pill featuring live RAM ring, clock, audio visualizer, Live Activity morphs, 13 modular tabs (`Home`, `Music`, `Calendar`, `To-Do`, `Timer`, `Notifications`, `Clipboard`, `Files` with Shelf & rclone Google Drive, `Translate`, `Teleprompter`, `Weather`, `Health`, `System`), and a lazy-loaded Hub-styled Settings window.
- **Tsukuyomi Hub:** Unified monochrome settings app with `General` (including `Tsukuyomi Folders` icon theme), `Theme & Accent`, `Bar Studio`, `Dock` + Stage Editor, `Lockscreen` (`Clockwork Orbital` + Store themes), `Compatibility`, `Add-ons`, and `Subshells`.
- **Tsukuyomi Store:** Flatpak/Flathub apps, themes, bars, lockscreens, bundles, and `Compat Add-ons` (`winboat`, `faugus-launcher`, `proton-cachyos-native`).
- **Tsukuyomi Monitor & Wallpapers:** Hardened `ryomanager` (Wayland/NVIDIA/software-renderer WebKitGTK safety, LUKS/Btrfs/IPv4/IPv6/RTD3 telemetry) and patched `ryogami` wallpaper picker (`Super+W`).
- **Windows & Android Compatibility UI:** Native GUI wizards for `.exe`/`.msi`/`.lnk` and `.apk`/`.xapk`/`.apkm`, App Launcher `/win` & `/apk` filters + badges, Hub Compatibility manager with Windows `Force Stop` and Android Phone viewport presets, and `Super+Alt+R` resize cycler.
- **Software Renderer Profile:** Automatic `TSUKUYOMI_SOFTWARE_RENDERER=1` detection disables FBO blurs, shadows, and heavy transitions across Hyprland, QS Bar, Stage Editor, Dynamic Notch, Store, Wallpapers, and Monitor.

## Local Preview

From an active Wayland desktop with the pinned Ryoku packages and `bubblewrap` installed:

```bash
./ryoku/run-preview.sh firefox.desktop
```

See [ryoku/README.md](ryoku/README.md) for preview shortcuts and staging details, and [tsukuyomi](https://github.com/alifconstantine/tsukuyomi) for ISO building.
