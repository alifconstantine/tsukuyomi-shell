pragma Singleton

import QtQuick
import Ryoku.Ui.Singletons

QtObject {
    readonly property bool dark: !Tokens.light
    readonly property color surface: dark ? "#1a1c22" : "#f5f6f9"
    readonly property color sidebar: dark ? "#20232b" : "#ebedf3"
    readonly property color panel: dark ? "#252932" : "#ffffff"
    readonly property color text: dark ? "#f2f4f8" : "#252a36"
    readonly property color secondary: dark ? "#b2bac9" : "#555f71"
    readonly property color line: dark ? "#373d49" : "#dce0e9"
    readonly property color hover: dark ? "#2c303a" : "#e1e4ec"
    readonly property color selected: dark ? "#3a2c35" : "#f2dde2"
    readonly property color accent: dark ? "#ff9e92" : "#9f3045"
    readonly property string icons: "Material Symbols Outlined"

    function sectionIcon(key) {
        switch (key) {
        case "profile": return "\ue853";
        case "updates": return "\ue8d7";
        case "displays": return "\ue30a";
        case "connections": return "\ue63e";
        case "input": case "keybinds": return "\ue312";
        case "gpu": case "performance": return "\ue1a3";
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
