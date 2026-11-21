.pragma library

// Registry of Tsukuyomi Dynamic Notch tabs and adaptive dimensions.
// Each tab defines its own compact/medium/wide dimensions so the Notch morphs
// smoothly to fit the active module's content rather than forcing a single box.

var TABS = [
    { id: "home",      label: "Home",      icon: "tune",          w: 432, h: 192, file: "NotchHomeTab.qml" },
    { id: "music",     label: "Music",     icon: "music_note",    w: 536, h: 178, file: "NotchMusicTab.qml" },
    { id: "clipboard", label: "Clipboard", icon: "content_paste", w: 560, h: 242, file: "NotchClipboardTab.qml" },
    { id: "system",    label: "System",    icon: "monitoring",    w: 568, h: 212, file: "NotchSystemTab.qml" }
];

var SETTINGS_META = {
    id: "settings",
    label: "Notch Settings",
    icon: "settings",
    w: 580,
    h: 274,
    file: "NotchSettingsView.qml"
};

function findTab(id) {
    for (var i = 0; i < TABS.length; i++) {
        if (TABS[i].id === id) return TABS[i];
    }
    return TABS[0];
}

function visibleTabs(hiddenList) {
    var hidden = Array.isArray(hiddenList) ? hiddenList : [];
    var out = [];
    for (var i = 0; i < TABS.length; i++) {
        if (TABS[i].id === "home" || hidden.indexOf(TABS[i].id) < 0)
            out.push(TABS[i]);
    }
    return out.length > 0 ? out : [TABS[0]];
}

function indexOfTab(tabs, id) {
    for (var i = 0; i < tabs.length; i++) {
        if (tabs[i].id === id) return i;
    }
    return 0;
}

function nextTabId(tabs, currentId, delta) {
    if (!tabs || tabs.length === 0) return "home";
    var idx = indexOfTab(tabs, currentId);
    var next = (idx + delta + tabs.length) % tabs.length;
    return tabs[next].id;
}
