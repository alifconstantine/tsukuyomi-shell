.pragma library

// Registry of Tsukuyomi Dynamic Notch tabs and adaptive dimensions.
// Each tab defines its own compact/medium/wide dimensions so the Notch morphs
// smoothly to fit the active module's content rather than forcing a single box.

var TABS = [
    { id: "home",          label: "Home",          icon: "home",              w: 460, h: 184, file: "NotchHomeTab.qml" },
    { id: "music",         label: "Music",         icon: "music_note",        w: 548, h: 198, file: "NotchMusicTab.qml" },
    { id: "calendar",      label: "Calendar",      icon: "calendar_month",    w: 598, h: 274, file: "NotchCalendarTab.qml" },
    { id: "todo",          label: "ToDo",          icon: "checklist",         w: 584, h: 268, file: "NotchTodoTab.qml" },
    { id: "timer",         label: "Timer",         icon: "timer",             w: 486, h: 198, file: "NotchTimerTab.qml" },
    { id: "notifications", label: "Notifications", icon: "notifications",     w: 604, h: 282, file: "NotchNotifTab.qml" },
    { id: "clipboard",     label: "Clipboard",     icon: "content_paste",     w: 576, h: 264, file: "NotchClipboardTab.qml" },
    { id: "files",         label: "Files",         icon: "folder_open",       w: 604, h: 286, file: "NotchFilesTab.qml" },
    { id: "translate",     label: "Translate",     icon: "translate",         w: 584, h: 258, file: "NotchTranslateTab.qml" },
    { id: "teleprompter",  label: "Teleprompter",  icon: "subtitles",         w: 604, h: 320, file: "NotchTeleprompterTab.qml" },
    { id: "weather",       label: "Weather",       icon: "partly_cloudy_day", w: 620, h: 272, file: "NotchWeatherTab.qml" },
    { id: "health",        label: "Health",        icon: "favorite",          w: 598, h: 262, file: "NotchHealthTab.qml" },
    { id: "system",        label: "System",        icon: "monitoring",        w: 564, h: 210, file: "NotchSystemTab.qml" }
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

function orderedTabs(orderList) {
    if (!Array.isArray(orderList) || orderList.length === 0)
        return TABS.slice();
    var out = [];
    var seen = {};
    for (var i = 0; i < orderList.length; i++) {
        var id = orderList[i];
        for (var j = 0; j < TABS.length; j++) {
            if (TABS[j].id === id && !seen[id]) {
                out.push(TABS[j]);
                seen[id] = true;
                break;
            }
        }
    }
    for (var k = 0; k < TABS.length; k++) {
        if (!seen[TABS[k].id])
            out.push(TABS[k]);
    }
    return out;
}

function visibleTabs(hiddenList, orderList) {
    var hidden = Array.isArray(hiddenList) ? hiddenList : [];
    var ordered = orderedTabs(orderList);
    var out = [];
    for (var i = 0; i < ordered.length; i++) {
        if (ordered[i].id === "home" || hidden.indexOf(ordered[i].id) < 0)
            out.push(ordered[i]);
    }
    return out.length > 0 ? out : [TABS[0]];
}

function indexOfTab(tabs, id) {
    for (var i = 0; i < tabs.length; i++) {
        if (tabs[i].id === id) return i;
    }
    return -1;
}

function nextTabId(tabs, currentId, delta) {
    if (!tabs || tabs.length === 0) return "home";
    var idx = Math.max(0, indexOfTab(tabs, currentId));
    var next = (idx + delta + tabs.length) % tabs.length;
    return tabs[next].id;
}
