pragma Singleton

import QtQuick
import Ryoku.Ui.Singletons

QtObject {
    readonly property bool dark: !Tokens.light
    readonly property color surface: dark ? "#161616" : "#f5f5f5"
    readonly property color sidebar: dark ? "#1c1c1c" : "#ededed"
    readonly property color panel: dark ? "#222222" : "#ffffff"
    readonly property color input: dark ? "#191919" : "#ffffff"
    readonly property color text: dark ? "#efefef" : "#242424"
    readonly property color secondary: dark ? "#b9b9b9" : "#555555"
    readonly property color muted: dark ? "#a1a1a1" : "#626262"
    readonly property color line: dark ? "#383838" : "#d7d7d7"
    readonly property color lineStrong: dark ? "#626262" : "#8a8a8a"
    readonly property color hover: dark ? "#2b2b2b" : "#e8e8e8"
    readonly property color selected: dark ? "#383838" : "#dedede"
    readonly property color accent: Tokens.sun
    readonly property string icons: "Material Symbols Outlined"

    function sectionIcon(key) {
        switch (key) {
        case "profile": return "\ue853";
        case "updates": return "\ue8d7";
        case "displays": return "\ue30a";
        case "connections": return "\ue63e";
        case "input": case "keybinds": return "\ue312";
        case "gpu": case "performance": return "\ue1a3";
        case "appearance": return "\ue40a";
        case "lockscreen": return "\ue897";
        case "windowmanager": case "windowrules": return "\ue42a";
        case "plugins": case "addons": case "community": return "\ue87b";
        case "subshells": case "layout": return "\ue42a";
        case "bar-studio": case "bars": case "dock": return "\ue30c";
        case "desktop": return "\ue1b1";
        case "controls": return "\ue429";
        case "overlays": return "\ue53b";
        case "gamebar": return "\ue30f";
        case "launcher": case "launchers": case "flatpak": return "\ue5c3";
        case "recording": return "\ue04b";
        case "dictation": return "\ue029";
        case "global": case "identity": return "\ue8b8";
        case "discover": return "\ue87a";
        case "library": return "\ue02f";
        case "colorschemes": case "rices": return "\ue40a";
        case "docks": case "barstyles": return "\ue30c";
        case "lockscreens": return "\ue897";
        case "notifications": return "\ue7f4";
        default: return "\ue1bd";
        }
    }
}
