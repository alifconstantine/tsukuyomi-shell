pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent configuration for the Tsukuyomi Dynamic Notch, stored at
// ~/.config/ryoku/notch.json with atomic writes so live updates from Notch
// Settings or external edits stay synchronized cleanly.
Singleton {
    id: cfg

    property alias themeMode: adapter.themeMode               // "system" | "custom"
    property alias customSurfaceHex: adapter.customSurfaceHex
    property alias customAccentHex: adapter.customAccentHex
    property alias frosted: adapter.frosted
    property alias cornerRadius: adapter.cornerRadius

    property alias openOnHover: adapter.openOnHover
    property alias autoCollapse: adapter.autoCollapse
    property alias liveActivities: adapter.liveActivities
    property alias notifInNotch: adapter.notifInNotch
    property alias notifRetentionDays: adapter.notifRetentionDays
    property alias notifMaxCount: adapter.notifMaxCount
    property alias notifShowWhileDnd: adapter.notifShowWhileDnd

    property alias musicSource: adapter.musicSource           // "nowplaying" | "orpheus"
    property alias musicDynamicGradient: adapter.musicDynamicGradient
    property alias weatherDynamicGradient: adapter.weatherDynamicGradient

    property alias defaultTab: adapter.defaultTab             // "home" | "last"
    property alias lastTab: adapter.lastTab
    property alias hiddenTabs: adapter.hiddenTabs             // array of hidden tab IDs
    property alias tabOrder: adapter.tabOrder                 // ordered tab IDs

    property alias timerRingtone: adapter.timerRingtone       // "alarm-clock-elapsed" | "complete" | "bell" | "message" | "none"
    property alias notifSound: adapter.notifSound             // "message-new-instant" | "bell" | "dialog-information" | "none"
    property alias homeTiles: adapter.homeTiles               // active Home quick control IDs

    function isHomeTileEnabled(id) {
        var arr = cfg.homeTiles || ["wifi", "bluetooth", "focus", "coffee"];
        return arr.indexOf(id) >= 0;
    }

    function toggleHomeTile(id) {
        var arr = (cfg.homeTiles || ["wifi", "bluetooth", "focus", "coffee"]).slice();
        var idx = arr.indexOf(id);
        if (idx >= 0) {
            if (arr.length <= 2) return; // keep at least 2 controls
            arr.splice(idx, 1);
        } else {
            if (arr.length >= 8) return; // max 8 (2 rows of 4)
            arr.push(id);
        }
        cfg.homeTiles = arr;
    }

    function playSound(soundId) {
        var id = String(soundId || "");
        if (id === "" || id === "none") return;
        if (!/^[a-z0-9-]+$/.test(id)) return;
        Quickshell.execDetached([
            "sh", "-c",
            "f=\"/usr/share/sounds/freedesktop/stereo/$1.oga\"; [ -r \"$f\" ] || exit 0; " +
            "if command -v pw-play >/dev/null 2>&1; then pw-play \"$f\"; " +
            "elif command -v paplay >/dev/null 2>&1; then paplay \"$f\"; fi",
            "_", id
        ]);
    }

    function isTabEnabled(id) {
        if (id === "home") return true;
        var h = cfg.hiddenTabs || [];
        return h.indexOf(id) < 0;
    }

    function setTabEnabled(id, enabled) {
        if (id === "home") return;
        var h = (cfg.hiddenTabs || []).slice();
        var idx = h.indexOf(id);
        if (enabled && idx >= 0) {
            h.splice(idx, 1);
            cfg.hiddenTabs = h;
        } else if (!enabled && idx < 0) {
            h.push(id);
            cfg.hiddenTabs = h;
        }
    }

    function moveTab(id, delta, allTabIds) {
        var cur = (cfg.tabOrder && cfg.tabOrder.length > 0) ? cfg.tabOrder.slice() : [];
        for (var i = 0; i < allTabIds.length; i++) {
            if (cur.indexOf(allTabIds[i]) < 0) cur.push(allTabIds[i]);
        }
        var idx = cur.indexOf(id);
        var nextIdx = idx + delta;
        if (idx < 0 || nextIdx < 0 || nextIdx >= cur.length) return;
        var tmp = cur[idx];
        cur[idx] = cur[nextIdx];
        cur[nextIdx] = tmp;
        cfg.tabOrder = cur;
    }

    function resetTabOrder() {
        cfg.tabOrder = [];
    }

    function normalizeHex(raw, fallback) {
        var s = String(raw || "").trim();
        if (s.length > 0 && s[0] !== "#") s = "#" + s;
        if (/^#[0-9A-Fa-f]{6}$/.test(s) || /^#[0-9A-Fa-f]{8}$/.test(s))
            return s.toUpperCase();
        return fallback;
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/notch.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter
            property string themeMode: "system"
            property string customSurfaceHex: "#0B0B0E"
            property string customAccentHex: "#C92A2A"
            property bool frosted: true
            property int cornerRadius: 20

            property bool openOnHover: false
            property bool autoCollapse: true
            property bool liveActivities: true
            property bool notifInNotch: true
            property int notifRetentionDays: 3
            property int notifMaxCount: 200
            property bool notifShowWhileDnd: true

            property string musicSource: "nowplaying"
            property bool musicDynamicGradient: true
            property bool weatherDynamicGradient: true

            property string defaultTab: "home"
            property string lastTab: "home"
            property var hiddenTabs: []
            property var tabOrder: []

            property string timerRingtone: "alarm-clock-elapsed"
            property string notifSound: "message-new-instant"
            property var homeTiles: ["wifi", "bluetooth", "focus", "coffee"]
        }
    }

    Component.onCompleted: if (!file.text()) file.writeAdapter()
}
