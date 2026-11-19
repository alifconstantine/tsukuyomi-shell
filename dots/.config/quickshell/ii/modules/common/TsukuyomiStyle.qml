pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property bool dark: Config.options.tsukuyomi.appearance === "system"
        ? Appearance.m3colors.darkmode : Config.options.tsukuyomi.appearance === "dark"
    readonly property bool glass: Config.options.tsukuyomi.glass
    readonly property color surface: dark ? "#202124" : "#f4f5f7"
    readonly property color foreground: dark ? "#f2f3f5" : "#202124"
    readonly property color muted: dark ? "#b0b4bc" : "#585d66"
    readonly property color border: dark ? "#555861" : "#c0c5ce"
    readonly property color raised: dark ? "#34363c" : "#e2e5eb"
    readonly property color accent: {
        const options = Config.options.tsukuyomi;
        switch (options.accentSource) {
        case "wallpaper": return Appearance.m3colors.m3primary;
        case "preset": return options.accentPreset;
        case "custom": return options.customAccent;
        default: return foreground;
        }
    }
    readonly property color selection: Qt.tint(raised, Qt.rgba(accent.r, accent.g, accent.b, 0.20))
    readonly property color frostTop: glass ? (dark ? "#e0282c34" : "#edffffff") : surface
    readonly property color frostBottom: glass ? (dark ? "#df15171d" : "#ebdfe4eb") : surface
}
