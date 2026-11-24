# Tsukuyomi Desktop Design Specification

Tsukuyomi Desktop builds on pinned upstream **Ryoku (`08ff328`)** with a neutral monochrome desktop identity, shared UI grammar across Hub/Store/Notch/Monitor, and automatic degradation for software-rendered sessions.

## Palette & Material

- **Neutral Default Surfaces:** Dark mode uses `#161616` primary surface, `#1C1C1C` navigation rail, `#222222` elevated cards, and silver keyboard focus. Light mode follows the Ryoku light neutral tokens.
- **Independent Accent Source:** Accent color can follow preset palettes, custom HEX, or wallpaper extraction independently of Dark/Light mode.
- **Frosted & Software Fallback:** Menus, dock, and Dynamic Notch use rounded Frosted cards with compositor blur (`ignore_alpha`) on hardware GPUs. When `TSUKUYOMI_SOFTWARE_RENDERER=1` or Low Power / Reduce Motion is active, surfaces switch to crisp solid colors with shadows, blur passes, and heavy geometry animations disabled.

## Bar & Dynamic Notch

- **QS Bar (`Islands`):** Locked to the three-pill `Islands` form with Arch logo for System Controls, live workspaces, right-side status/RAM readout, and centered **Dynamic Notch** pill.
- **Dynamic Notch:** Morphs directly out of the center pill on the active monitor and mounts only one active module at a time via `Loader.setSource`. Includes 13 tabs (`Home`, `Music`, `Calendar`, `To-Do`, `Timer`, `Notifications`, `Clipboard`, `Files`, `Translate`, `Teleprompter`, `Weather`, `Health`, `System`) plus a lazy-loaded Hub-styled `NotchSettingsWindow`.

## Dock, Launcher & Wallpapers

- **Dock:** Shared capsule dock with launcher, Dolphin, installer-selected browser, and Kitty. Visibility and auto-hide are controlled in **Hub → Appearance → Dock**; design, position, and pins are edited in Stage Editor.
- **App Launcher (`Super+Space`):** Main search launcher with `/win` and `/apk` runtime filters and `WIN` / `APK` badges.
- **Wallpapers (`Super+W`):** Patched `ryogami` picker bundled with `Cloud Valley` default, live preview, shader transitions (instant/lightweight on software renderer), and `Enter` confirmation.

## Hub, Store, Monitor & Compatibility

- **Tsukuyomi Hub:** Starts at `General`, keeps a consistent bottom `ActionBar`, and unifies desktop, appearance, lockscreen (`Clockwork Orbital`), add-ons, subshells, and `Compatibility` management.
- **Tsukuyomi Store:** Matches Hub window geometry, integrates Flatpak/Flathub setup and `Compat Add-ons`, and ships bundled package helpers for Store bundles.
- **Tsukuyomi Monitor:** Patched `ryomanager` (`Processes`, `Performance`, `System`) floating/centered in Hyprland with Wayland/NVIDIA/llvmpipe WebKitGTK hardening.
- **WinBridge & DroidBridge UI:** Floating `WinInstaller` & `DroidInstaller` dialogs, `CompatPage` runtime management (Windows `Force Stop`, UMU/bwrap guard, Android Phone viewport presets), and Dynamic Notch Files Shelf contextual `Install App` pill.
