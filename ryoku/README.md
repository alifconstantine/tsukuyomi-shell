# Tsukuyomi desktop preview

This branch brings up the Ryoku desktop as a nested Hyprland session with Tsukuyomi defaults. It uses the installed Ryoku binaries and QML from revision `08ff328`. `stage-preview.sh` checks the exact package versions before applying patches. [Upstream notices](https://github.com/Ryoku-dev/ryoku/blob/main/NOTICE)

## Open the preview

Open a terminal in the repository root from a Wayland desktop with the pinned Ryoku packages and `bubblewrap` installed.

```bash
./ryoku/run-preview.sh firefox.desktop
```

Pass the desktop ID of an installed browser. Omit it for a dock without a browser pin. The preview runs with a temporary profile and restores its defaults each time it starts.

- Click the Arch logo for System Controls. The sliders icon opens QS Bar Settings. The adjacent gear opens Tsukuyomi Hub.
- Click the clock to open the dashboard. The dock opens Applications, Dolphin, the supplied browser, and Kitty.
- Press `Ctrl+Shift+F11` to open the Hub or `Ctrl+Shift+F12` to close the preview window.

The nested session has a private D-Bus and runtime directory. Hardware actions, portals, and session locking require testing from a real Tsukuyomi login in a VM. The preview uses Frosted. Liquid Glass is a follow-up preset once the desktop defaults are approved.

## Prepare the next ISO iteration

Use `stage-preview.sh NEW_PROFILE_DIR [BROWSER_DESKTOP_ID]` to build a fresh profile without opening the nested window. For the ISO candidate, package the matching shell, Qt modules, Hyprland provider and selected helpers in the offline repository. Review the upstream package hooks before integrating them. Route lock, idle and suspend through Tsukuyomi's existing `tsukuyomi-lock`. The preview hides RyoStore and Rashin entry points, and defers the upstream update and lockscreen pages. Audit optional package dependencies again when defining the ISO package list.
