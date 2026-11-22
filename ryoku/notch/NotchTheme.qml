import QtQuick

// Resolves Dynamic Notch surface, card, ink, border, and accent colors.
// Defaults to the active shell theme ("system") and supports custom hex
// surface/accent overrides configured in Notch Settings.
QtObject {
    id: nt

    property var root: null

    readonly property bool customMode: NotchConfig.themeMode === "custom"
    readonly property color sysSurface: nt.root ? nt.root.paper : "#161616"
    readonly property color sysInk: nt.root ? nt.root.ink : "#eae2d5"
    readonly property color sysMuted: nt.root ? nt.root.sumi : "#8c857a"
    readonly property color sysAccent: nt.root ? nt.root.seal : "#c92a2a"

    function parseColor(hexStr, fallback) {
        var s = NotchConfig.normalizeHex(hexStr, "");
        return s !== "" ? Qt.color(s) : fallback;
    }

    readonly property color baseSurface: nt.customMode
        ? nt.parseColor(NotchConfig.customSurfaceHex, nt.sysSurface)
        : nt.sysSurface

    readonly property real surfaceLum: (baseSurface.r * 0.299) + (baseSurface.g * 0.587) + (baseSurface.b * 0.114)
    readonly property bool lightSurface: nt.surfaceLum > 0.54

    readonly property color surface: NotchConfig.frosted
        ? Qt.rgba(baseSurface.r, baseSurface.g, baseSurface.b, nt.lightSurface ? 0.90 : 0.90)
        : Qt.rgba(baseSurface.r, baseSurface.g, baseSurface.b, 0.97)
    readonly property color solidSurface: Qt.rgba(baseSurface.r, baseSurface.g, baseSurface.b, 0.97)

    readonly property string uiFont: Tokens.ui
    readonly property string displayFont: Tokens.display
    readonly property string monoFont: (nt.root && nt.root.mono) ? nt.root.mono : "JetBrainsMono Nerd Font"

    readonly property color accent: nt.customMode
        ? nt.parseColor(NotchConfig.customAccentHex, nt.sysAccent)
        : nt.sysAccent

    readonly property real sysInkLum: (sysInk.r * 0.299) + (sysInk.g * 0.587) + (sysInk.b * 0.114)
    readonly property color ink: (nt.customMode || (nt.lightSurface && nt.sysInkLum > 0.50) || (!nt.lightSurface && nt.sysInkLum < 0.40))
        ? (nt.lightSurface ? Qt.color("#141416") : Qt.color("#F2EFE9"))
        : nt.sysInk

    readonly property color muted: (nt.customMode || nt.lightSurface)
        ? Qt.rgba(ink.r, ink.g, ink.b, 0.62)
        : nt.sysMuted

    readonly property color card: Qt.rgba(ink.r, ink.g, ink.b, nt.lightSurface ? 0.06 : 0.065)
    readonly property color cardHover: Qt.rgba(ink.r, ink.g, ink.b, nt.lightSurface ? 0.10 : 0.11)
    readonly property color border: Qt.rgba(ink.r, ink.g, ink.b, nt.lightSurface ? 0.14 : 0.11)
    readonly property color hairline: Qt.rgba(ink.r, ink.g, ink.b, 0.10)
    readonly property real accentLum: (accent.r * 0.299) + (accent.g * 0.587) + (accent.b * 0.114)
    readonly property color onAccent: nt.accentLum > 0.54 ? Qt.color("#111114") : Qt.color("#F7F5F0")
    readonly property color danger: Qt.hsla(0.99, 0.72, nt.lightSurface ? 0.45 : 0.60, 1)
    readonly property color success: Qt.hsla(0.39, 0.60, nt.lightSurface ? 0.38 : 0.58, 1)
    readonly property color warning: Qt.hsla(0.11, 0.80, nt.lightSurface ? 0.44 : 0.60, 1)
}
