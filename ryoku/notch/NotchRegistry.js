.pragma library

// Registry of Tsukuyomi Dynamic Notch tabs and adaptive dimensions.
// Each tab defines its own compact/medium/wide dimensions so the Notch morphs
// smoothly to fit the active module's content rather than forcing a single box.

var TABS = [
    { id: "home",          label: "Home",          icon: "home",              w: 468, h: 214, file: "NotchHomeTab.qml" },
    { id: "music",         label: "Music",         icon: "music_note",        w: 556, h: 204, file: "NotchMusicTab.qml" },
    { id: "calendar",      label: "Calendar",      icon: "calendar_month",    w: 604, h: 282, file: "NotchCalendarTab.qml" },
    { id: "todo",          label: "ToDo",          icon: "checklist",         w: 590, h: 278, file: "NotchTodoTab.qml" },
    { id: "timer",         label: "Timer",         icon: "timer",             w: 552, h: 234, file: "NotchTimerTab.qml" },
    { id: "notifications", label: "Notifications", icon: "notifications",     w: 608, h: 290, file: "NotchNotifTab.qml" },
    { id: "clipboard",     label: "Clipboard",     icon: "content_paste",     w: 584, h: 274, file: "NotchClipboardTab.qml" },
    { id: "files",         label: "Files",         icon: "folder_open",       w: 628, h: 316, file: "NotchFilesTab.qml" },
    { id: "translate",     label: "Translate",     icon: "translate",         w: 588, h: 266, file: "NotchTranslateTab.qml" },
    { id: "teleprompter",  label: "Teleprompter",  icon: "subtitles",         w: 588, h: 286, file: "NotchTeleprompterTab.qml" },
    { id: "weather",       label: "Weather",       icon: "partly_cloudy_day", w: 624, h: 278, file: "NotchWeatherTab.qml" },
    { id: "health",        label: "Health",        icon: "favorite",          w: 604, h: 268, file: "NotchHealthTab.qml" },
    { id: "system",        label: "System",        icon: "monitoring",        w: 580, h: 246, file: "NotchSystemTab.qml" }
];

var SETTINGS_META = {
    id: "settings",
    label: "Notch Settings",
    icon: "settings",
    w: 596,
    h: 316,
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
