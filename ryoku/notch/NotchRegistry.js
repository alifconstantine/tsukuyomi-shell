.pragma library

// Registry of Tsukuyomi Dynamic Notch tabs and adaptive dimensions.
// Each tab defines its own compact/medium/wide dimensions so the Notch morphs
// smoothly to fit the active module's content rather than forcing a single box.

var TABS = [
    { id: "home",          label: "Home",          icon: "tune",              w: 440, h: 192, file: "NotchHomeTab.qml" },
    { id: "music",         label: "Music",         icon: "music_note",        w: 544, h: 184, file: "NotchMusicTab.qml" },
    { id: "calendar",      label: "Calendar",      icon: "calendar_month",    w: 584, h: 256, file: "NotchCalendarTab.qml" },
    { id: "todo",          label: "ToDo",          icon: "checklist",         w: 576, h: 252, file: "NotchTodoTab.qml" },
    { id: "timer",         label: "Timer",         icon: "timer",             w: 536, h: 214, file: "NotchTimerTab.qml" },
    { id: "notifications", label: "Notifications", icon: "notifications",     w: 596, h: 268, file: "NotchNotifTab.qml" },
    { id: "clipboard",     label: "Clipboard",     icon: "content_paste",     w: 560, h: 242, file: "NotchClipboardTab.qml" },
    { id: "files",         label: "Files",         icon: "folder_open",       w: 604, h: 282, file: "NotchFilesTab.qml" },
    { id: "translate",     label: "Translate",     icon: "translate",         w: 572, h: 236, file: "NotchTranslateTab.qml" },
    { id: "teleprompter",  label: "Teleprompter",  icon: "subtitles",         w: 568, h: 248, file: "NotchTeleprompterTab.qml" },
    { id: "weather",       label: "Weather",       icon: "partly_cloudy_day", w: 608, h: 246, file: "NotchWeatherTab.qml" },
    { id: "health",        label: "Health",        icon: "favorite",          w: 588, h: 242, file: "NotchHealthTab.qml" },
    { id: "system",        label: "System",        icon: "monitoring",        w: 568, h: 212, file: "NotchSystemTab.qml" }
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
