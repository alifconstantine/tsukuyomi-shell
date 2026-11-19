# Tsukuyomi desktop preview

The preview brings up the Ryoku desktop as a nested Hyprland session with Tsukuyomi defaults. Both the preview and the ISO package use Ryoku revision `08ff328` and the same profile assembly. [Upstream notices](upstream/NOTICE)

## Open the preview

Open a terminal in the repository root from a Wayland desktop with the pinned Ryoku packages and `bubblewrap` installed.

```bash
./ryoku/run-preview.sh firefox.desktop
```

Pass the desktop ID of an installed browser. Omit it for a dock without a browser pin. The preview runs with a temporary profile and restores its defaults each time it starts.

- Click the Arch logo for System Controls. The sliders icon opens QS Bar Settings. The adjacent gear opens Tsukuyomi Hub.
- Click the clock to open the dashboard. The dock opens Applications, Dolphin, the supplied browser, and Kitty.
- Press `Ctrl+Shift+F11` to open the Hub or `Ctrl+Shift+F12` to close the preview window.

The nested session has a private D-Bus and runtime directory. Hardware actions, portals, and session locking require a real Tsukuyomi login. The default material is Frosted. To add the glass rim to the bar, open QS Bar Settings, choose Bar, then use Glass in the Surface section while Islands and Frost are selected.

## Build the desktop package

`stage-profile.sh UPSTREAM_QUICKSHELL_DIR NEW_PROFILE_DIR [BROWSER_DESKTOP_ID]` assembles the configuration for both entry points. The ISO builder ships the matching shell, Qt modules, Hyprland provider, and selected helpers. SDDM launches the Tsukuyomi session, which routes lock and idle through the existing `tsukuyomi-lock`. RyoStore and Rashin are excluded from the desktop package and the upstream update and lockscreen pages are hidden. [Tsukuyomi ISO build](https://github.com/alifconstantine/tsukuyomi)
