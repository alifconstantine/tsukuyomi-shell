pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import shell.services
import Ryoku.Ui.Singletons
import "../../tsukuyomi" as Tsukuyomi
import "NotchRegistry.js" as Registry

// Comprehensive Hub/Store-styled pop-up window for Dynamic Notch configuration.
// Supports Theme Presets + Custom Hex, Home Quick Tiles & Tab Reordering,
// Timer Ringtones & Notification Sounds with live Test playback, Google Drive rclone auth,
// Music/Weather, and Health/Timer/Teleprompter settings.
PanelWindow {
    id: win

    property var root: null
    property bool open: false

    readonly property bool anim: !Perf.reduceMotion
    readonly property string monoFont: (win.root && win.root.mono) ? win.root.mono : "JetBrainsMono Nerd Font"
    readonly property real accentLum: (Tsukuyomi.Style.accent.r * 0.299) + (Tsukuyomi.Style.accent.g * 0.587) + (Tsukuyomi.Style.accent.b * 0.114)
    readonly property color onAccent: win.accentLum > 0.54 ? "#141416" : "#FFFFFF"

    property string section: "appearance"
    onSectionChanged: bodyFlick.contentY = 0
    property string weatherInput: Config.weatherLocation || ""
    property string surfaceHexInput: NotchConfig.customSurfaceHex
    property string accentHexInput: NotchConfig.customAccentHex

    readonly property var sections: [
        { id: "appearance", label: "Appearance",      icon: "palette",              eyebrow: "SURFACE & PALETTE", title: "Appearance & Theme",  sub: "Select curated theme presets, follow desktop material, or dial in custom Hex accents." },
        { id: "layout",     label: "Home & Tabs",     icon: "dashboard_customize",  eyebrow: "LAYOUT & ORDER",    title: "Home & Notch Layout", sub: "Customize Quick Control tiles on Home and reorder or toggle visible Notch modules." },
        { id: "behavior",   label: "Sounds & Alerts", icon: "notifications_active", eyebrow: "AUDIO & ROUTING",   title: "Sounds & Alerts",     sub: "Choose completion ringtones, notification chimes, and Dynamic Island behavior." },
        { id: "media",      label: "Cloud & Media",   icon: "cloud_sync",           eyebrow: "STORAGE & SOURCES", title: "Cloud, Media & Sky",  sub: "Connect Google Drive via rclone, choose music source, and configure forecast location." },
        { id: "health",     label: "Health & Timer",  icon: "favorite",             eyebrow: "WELLNESS & FOCUS",  title: "Health & Timer",      sub: "Configure daily hydration goals, Pomodoro durations, and Teleprompter defaults." }
    ]

    readonly property var themePresets: [
        { id: "system",  name: "System Neutral",    surf: "#16161A", acc: "#8C857A", dark: true,  mode: "system" },
        { id: "crimson", name: "Tsukuyomi Crimson", surf: "#120E0E", acc: "#C92A2A", dark: true,  mode: "custom" },
        { id: "gold",    name: "Obsidian Gold",     surf: "#0B0B0E", acc: "#D4A359", dark: true,  mode: "custom" },
        { id: "slate",   name: "Nordic Slate",      surf: "#13171D", acc: "#5E9EFF", dark: true,  mode: "custom" },
        { id: "paper",   name: "Paper Light",       surf: "#F2EFE9", acc: "#C92A2A", dark: false, mode: "custom" }
    ]

    readonly property var homeTileCatalog: [
        { id: "wifi",       label: "Wi-Fi",       hint: "Toggle wireless radio",         icon: "wifi" },
        { id: "bluetooth",  label: "Bluetooth",   hint: "Toggle Bluetooth adapter",      icon: "bluetooth" },
        { id: "focus",      label: "Focus",       hint: "Silence notifications (DND)",   icon: "dark_mode" },
        { id: "coffee",     label: "Coffee",      hint: "Keep screen awake indefinitely",icon: "local_cafe" },
        { id: "nightlight", label: "Night Light", hint: "Warm display temperature",      icon: "bedtime" },
        { id: "mic",        label: "Microphone",  hint: "Mute default audio input",      icon: "mic" },
        { id: "gamemode",   label: "Game Mode",   hint: "Suspend heavy desktop effects", icon: "sports_esports" },
        { id: "screenshot", label: "Capture",     hint: "Snap region to clipboard",      icon: "screenshot_region" }
    ]

    readonly property var timerSounds: [
        { id: "alarm-clock-elapsed", label: "Alarm" },
        { id: "complete",            label: "Chime" },
        { id: "bell",                label: "Bell" },
        { id: "message",             label: "Ping" },
        { id: "none",                label: "Silent" }
    ]

    readonly property var notifSounds: [
        { id: "message-new-instant", label: "Instant" },
        { id: "bell",                label: "Bell" },
        { id: "dialog-information",  label: "Info" },
        { id: "none",                label: "Silent" }
    ]

    readonly property var allTabIds: {
        var out = [];
        for (var i = 0; i < Registry.TABS.length; i++)
            out.push(Registry.TABS[i].id);
        return out;
    }

    function openWindow(initialSection) {
        if (initialSection) win.section = initialSection;
        win.weatherInput = Config.weatherLocation || "";
        win.surfaceHexInput = NotchConfig.customSurfaceHex;
        win.accentHexInput = NotchConfig.customAccentHex;
        if (win.section === "media")
            NotchFilesStore.checkRclone();
        win.open = true;
        card.forceActiveFocus();
    }

    function closeWindow() {
        win.open = false;
    }

    function currentSecMeta() {
        for (var i = 0; i < win.sections.length; i++)
            if (win.sections[i].id === win.section) return win.sections[i];
        return win.sections[0];
    }

    screen: win.root ? win.root.activePopupScreen : null
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-notch-settings"
    WlrLayershell.keyboardFocus: win.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    Region { id: noInput }
    mask: win.open ? null : noInput

    property real reveal: win.open ? 1.0 : 0.0
    Behavior on reveal {
        enabled: win.anim
        NumberAnimation {
            duration: win.open ? 220 : 150
            easing.type: win.open ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.002

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.36 * win.reveal)
        MouseArea {
            anchors.fill: parent
            enabled: win.open
            onClicked: win.closeWindow()
        }
    }

    component HubSwitch: Rectangle {
        id: hsw
        property bool checked: false
        property bool interactive: true
        signal toggled()

        width: 40
        height: 22
        radius: 11
        opacity: interactive ? 1.0 : 0.45
        color: checked ? Tsukuyomi.Style.accent : Tsukuyomi.Style.input
        border.width: 1
        border.color: checked
            ? (win.accentLum > 0.72 ? Tsukuyomi.Style.lineStrong : Tsukuyomi.Style.accent)
            : Tsukuyomi.Style.line
        Behavior on color { enabled: win.anim; ColorAnimation { duration: 140 } }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: hsw.checked ? parent.width - width - 3 : 3
            color: hsw.checked ? win.onAccent : Tsukuyomi.Style.secondary
            Behavior on x { enabled: win.anim; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            enabled: hsw.interactive
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: hsw.toggled()
        }
    }

    component HubChip: Rectangle {
        id: hc
        property string label: ""
        property bool checked: false
        signal toggled()

        height: 28
        width: hcRow.implicitWidth + 18
        radius: 8
        color: checked
            ? Qt.rgba(Tsukuyomi.Style.accent.r, Tsukuyomi.Style.accent.g, Tsukuyomi.Style.accent.b, 0.20)
            : (hcMa.containsMouse ? Tsukuyomi.Style.hover : Tsukuyomi.Style.input)
        border.width: 1
        border.color: checked ? Tsukuyomi.Style.accent : Tsukuyomi.Style.line
        Behavior on color { enabled: win.anim; ColorAnimation { duration: 130 } }

        Row {
            id: hcRow
            anchors.centerIn: parent
            spacing: 6
            Rectangle {
                width: 6; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: hc.checked ? Tsukuyomi.Style.accent : Tsukuyomi.Style.muted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: hc.label
                color: Tsukuyomi.Style.text
                font.family: Tokens.ui
                font.pixelSize: 11
                font.weight: hc.checked ? Font.DemiBold : Font.Normal
            }
        }
        MouseArea {
            id: hcMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hc.toggled()
        }
    }

    component SettingRow: Item {
        id: srow
        property string label: ""
        property string sub: ""
        property bool divider: true
        default property alias control: ctrlSlot.data

        width: parent ? parent.width : 400
        height: 52

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: ctrlSlot.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: srow.label
                color: Tsukuyomi.Style.text
                font.family: Tokens.ui
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                visible: srow.sub !== ""
                width: parent.width
                text: srow.sub
                color: Tsukuyomi.Style.muted
                font.family: Tokens.ui
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Row {
            id: ctrlSlot
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
        }

        Rectangle {
            visible: srow.divider
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14 }
            height: 1
            color: Tsukuyomi.Style.line
            opacity: 0.65
        }
    }

    // Unclipped shadow sibling behind the pop-up card
    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        blur: 24
        spread: 0
        offset: Qt.vector2d(0, 10)
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: card.opacity
        scale: card.scale
        visible: !Perf.softwareRenderer && !Perf.shadowsDisabled && win.reveal > 0.2
    }

    // Pop-up Card (Hub / Store grammar)
    Rectangle {
        id: card
        width: Math.min(776, Math.max(480, win.width - 48))
        height: Math.min(532, Math.max(360, win.height - 48))
        anchors.centerIn: parent
        radius: 14
        color: Tsukuyomi.Style.surface
        border.width: 1
        border.color: Tsukuyomi.Style.line
        clip: true
        focus: win.open
        opacity: win.reveal
        scale: win.open ? 1.0 : 0.94
        Behavior on scale {
            enabled: win.anim
            NumberAnimation { duration: 230; easing.type: win.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.65 }
        }

        Keys.onEscapePressed: win.closeWindow()
        MouseArea { anchors.fill: parent; onClicked: {} }

        Row {
            anchors.fill: parent

            // ── Left Navigation Sidebar ──────────────────────────────────────
            Rectangle {
                width: 192
                height: parent.height
                color: Tsukuyomi.Style.sidebar

                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: Tsukuyomi.Style.line
                }

                Column {
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                    spacing: 4

                    Text {
                        text: "TSUKUYOMI"
                        color: Tsukuyomi.Style.muted
                        font.family: win.monoFont
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                    }
                    Text {
                        text: I18n.tr("Notch Settings")
                        color: Tsukuyomi.Style.text
                        font.family: Tokens.display
                        font.pixelSize: 19
                    }
                    Item { width: 1; height: 8 }

                    Repeater {
                        model: win.sections
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: win.section === modelData.id
                            width: parent.width
                            height: 34
                            radius: 8
                            color: active ? Tsukuyomi.Style.selected : (navMa.containsMouse ? Tsukuyomi.Style.hover : "transparent")
                            Behavior on color { enabled: win.anim; ColorAnimation { duration: 120 } }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8
                                NotchIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    font.pixelSize: 16
                                    fill: active ? 1 : 0
                                    color: active ? Tsukuyomi.Style.accent : Tsukuyomi.Style.secondary
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: I18n.tr(modelData.label)
                                    color: active ? Tsukuyomi.Style.text : Tsukuyomi.Style.secondary
                                    font.family: Tokens.ui
                                    font.pixelSize: 12
                                    font.weight: active ? Font.DemiBold : Font.Normal
                                }
                            }
                            MouseArea {
                                id: navMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    win.section = modelData.id;
                                    if (modelData.id === "media")
                                        NotchFilesStore.checkRclone();
                                }
                            }
                        }
                    }
                }

                Column {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 14 }
                    spacing: 8

                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 8
                        color: rstAllMa.containsMouse ? Tsukuyomi.Style.hover : Tsukuyomi.Style.panel
                        border.width: 1; border.color: Tsukuyomi.Style.line
                        Text {
                            anchors.centerIn: parent
                            text: I18n.tr("Reset Defaults")
                            color: Tsukuyomi.Style.secondary
                            font.family: Tokens.ui
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: rstAllMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                NotchConfig.themeMode = "system";
                                NotchConfig.customSurfaceHex = "#0B0B0E";
                                NotchConfig.customAccentHex = "#C92A2A";
                                NotchConfig.frosted = true;
                                NotchConfig.cornerRadius = 20;
                                NotchConfig.openOnHover = false;
                                NotchConfig.autoCollapse = true;
                                NotchConfig.liveActivities = true;
                                NotchConfig.notifInNotch = true;
                                NotchConfig.notifShowWhileDnd = true;
                                NotchConfig.timerRingtone = "alarm-clock-elapsed";
                                NotchConfig.notifSound = "message-new-instant";
                                NotchConfig.homeTiles = ["wifi", "bluetooth", "focus", "coffee"];
                                NotchConfig.defaultTab = "home";
                                NotchConfig.hiddenTabs = [];
                                NotchConfig.tabOrder = [];
                                NotchTeleprompterStore.scalePct = 100;
                                NotchTeleprompterStore.wpm = 140;
                                NotchTeleprompterStore.persist();
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: I18n.tr("Changes save live")
                        color: Tsukuyomi.Style.muted
                        font.family: win.monoFont
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // ── Right Content Column ─────────────────────────────────────────
            Item {
                width: parent.width - 192
                height: parent.height

                Item {
                    id: rightHead
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 18; bottomMargin: 0 }
                    height: 52

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 76
                        spacing: 2
                        Text {
                            text: win.currentSecMeta().eyebrow
                            color: Tsukuyomi.Style.muted
                            font.family: win.monoFont
                            font.pixelSize: 9
                            font.letterSpacing: 1.4
                        }
                        Text {
                            text: I18n.tr(win.currentSecMeta().title)
                            color: Tsukuyomi.Style.text
                            font.family: Tokens.display
                            font.pixelSize: 21
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        width: 68; height: 28; radius: 8
                        color: closeMa.containsMouse ? Tsukuyomi.Style.hover : Tsukuyomi.Style.panel
                        border.width: 1; border.color: Tsukuyomi.Style.line
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "close"; font.pixelSize: 14; color: Tsukuyomi.Style.text }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Close"); color: Tsukuyomi.Style.text; font.family: Tokens.ui; font.pixelSize: 11 }
                        }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.closeWindow()
                        }
                    }
                }

                Rectangle {
                    id: headDivider
                    anchors { top: rightHead.bottom; left: parent.left; right: parent.right; leftMargin: 18; rightMargin: 18; topMargin: 10 }
                    height: 1
                    color: Tsukuyomi.Style.line
                }

                Flickable {
                    id: bodyFlick
                    anchors { top: headDivider.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 18; topMargin: 14 }
                    contentWidth: width
                    contentHeight: secBody.implicitHeight + 14
                    flickableDirection: Flickable.VerticalFlick
                    interactive: false
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            var dy = (event.pixelDelta && Math.abs(event.pixelDelta.y) > 0)
                                ? -event.pixelDelta.y
                                : (-event.angleDelta.y * 0.45);
                            var step = Math.max(-72, Math.min(72, dy));
                            var maxY = Math.max(0, bodyFlick.contentHeight - bodyFlick.height);
                            bodyFlick.contentY = Math.max(0, Math.min(maxY, bodyFlick.contentY + step));
                            event.accepted = true;
                        }
                    }

                    Column {
                        id: secBody
                        width: bodyFlick.width
                        spacing: 12

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: I18n.tr(win.currentSecMeta().sub)
                            color: Tsukuyomi.Style.secondary
                            font.family: Tokens.ui
                            font.pixelSize: 12
                        }

                        // ── 1. APPEARANCE ────────────────────────────────────
                        Column {
                            visible: win.section === "appearance"
                            width: parent.width
                            spacing: 12

                            Tsukuyomi.SectionCard {
                                width: parent.width
                                title: I18n.tr("Theme Presets")
                                collapsible: false

                                Column {
                                    width: parent.width
                                    padding: 14
                                    spacing: 10

                                    Flow {
                                        width: parent.width - 28
                                        spacing: 8
                                        Repeater {
                                            model: win.themePresets
                                            delegate: Rectangle {
                                                required property var modelData
                                                readonly property bool isActive: modelData.mode === "system"
                                                    ? (NotchConfig.themeMode === "system")
                                                    : (NotchConfig.themeMode === "custom"
                                                        && NotchConfig.customSurfaceHex.toUpperCase() === modelData.surf.toUpperCase()
                                                        && NotchConfig.customAccentHex.toUpperCase() === modelData.acc.toUpperCase())
                                                width: Math.floor((parent.width - 16) / 3)
                                                height: 46
                                                radius: 10
                                                color: modelData.surf
                                                border.width: isActive ? 2 : 1
                                                border.color: isActive ? modelData.acc : Tsukuyomi.Style.line

                                                Row {
                                                    anchors.fill: parent
                                                    anchors.margins: 10
                                                    spacing: 8
                                                    Rectangle {
                                                        width: 12; height: 12; radius: 6
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        color: modelData.acc
                                                    }
                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: parent.width - 24
                                                        text: I18n.tr(modelData.name)
                                                        color: modelData.dark ? "#F2EFE9" : "#16161A"
                                                        font.family: Tokens.ui
                                                        font.pixelSize: 11
                                                        font.weight: isActive ? Font.DemiBold : Font.Medium
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (modelData.mode === "system") {
                                                            NotchConfig.themeMode = "system";
                                                        } else {
                                                            NotchConfig.themeMode = "custom";
                                                            NotchConfig.customSurfaceHex = modelData.surf;
                                                            NotchConfig.customAccentHex = modelData.acc;
                                                            win.surfaceHexInput = modelData.surf;
                                                            win.accentHexInput = modelData.acc;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Tsukuyomi.SectionCard {
                                width: parent.width
                                title: I18n.tr("Surface Material & Custom Hex")
                                collapsible: false

                                Column {
                                    width: parent.width

                                    SettingRow {
                                        label: I18n.tr("Frosted Glass Backdrop")
                                        sub: I18n.tr("Blend translucent island cards over active windows")
                                        HubSwitch { checked: NotchConfig.frosted; onToggled: NotchConfig.frosted = !NotchConfig.frosted }
                                    }

                                    SettingRow {
                                        label: I18n.tr("Island Corner Radius")
                                        sub: I18n.tr("Outer curvature of expanded Dynamic Notch panels")
                                        Row {
                                            spacing: 6
                                            Repeater {
                                                model: [14, 18, 20, 24]
                                                delegate: HubChip {
                                                    required property int modelData
                                                    label: modelData + "px"
                                                    checked: NotchConfig.cornerRadius === modelData
                                                    onToggled: NotchConfig.cornerRadius = modelData
                                                }
                                            }
                                        }
                                    }

                                    SettingRow {
                                        label: I18n.tr("Use Custom Hex Palette")
                                        sub: I18n.tr("Override desktop neutral surface & accent tokens")
                                        HubSwitch {
                                            checked: NotchConfig.themeMode === "custom"
                                            onToggled: NotchConfig.themeMode = (NotchConfig.themeMode === "custom" ? "system" : "custom")
                                        }
                                    }

                                    Item {
                                        width: parent.width
                                        height: 54
                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 14
                                            spacing: 8

                                            Rectangle {
                                                width: Math.floor((parent.width - 110) / 2); height: 32; radius: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: Tsukuyomi.Style.input; border.width: 1
                                                border.color: sInp.activeFocus ? Tsukuyomi.Style.accent : Tsukuyomi.Style.line
                                                Row {
                                                    anchors.fill: parent; anchors.margins: 8; spacing: 6
                                                    Rectangle { width: 12; height: 12; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: NotchConfig.normalizeHex(sInp.text, NotchConfig.customSurfaceHex); border.width: 1; border.color: Tsukuyomi.Style.line }
                                                    TextInput { id: sInp; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; text: win.surfaceHexInput; color: Tsukuyomi.Style.text; font.family: win.monoFont; font.pixelSize: 11; selectByMouse: true }
                                                }
                                            }

                                            Rectangle {
                                                width: Math.floor((parent.width - 110) / 2); height: 32; radius: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: Tsukuyomi.Style.input; border.width: 1
                                                border.color: aInp.activeFocus ? Tsukuyomi.Style.accent : Tsukuyomi.Style.line
                                                Row {
                                                    anchors.fill: parent; anchors.margins: 8; spacing: 6
                                                    Rectangle { width: 12; height: 12; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: NotchConfig.normalizeHex(aInp.text, NotchConfig.customAccentHex); border.width: 1; border.color: Tsukuyomi.Style.line }
                                                    TextInput { id: aInp; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; text: win.accentHexInput; color: Tsukuyomi.Style.text; font.family: win.monoFont; font.pixelSize: 11; selectByMouse: true }
                                                }
                                            }

                                            Rectangle {
                                                width: 94; height: 32; radius: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: Tsukuyomi.Style.accent
                                                Text { anchors.centerIn: parent; text: I18n.tr("Apply Hex"); color: win.onAccent; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.DemiBold }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        NotchConfig.themeMode = "custom";
                                                        NotchConfig.customSurfaceHex = NotchConfig.normalizeHex(sInp.text, NotchConfig.customSurfaceHex);
                                                        NotchConfig.customAccentHex = NotchConfig.normalizeHex(aInp.text, NotchConfig.customAccentHex);
                                                        win.surfaceHexInput = NotchConfig.customSurfaceHex;
                                                        win.accentHexInput = NotchConfig.customAccentHex;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── 2. HOME & TABS LAYOUT ────────────────────────────
                        Column {
                            visible: win.section === "layout"
                            width: parent.width
                            spacing: 12

                            Tsukuyomi.SectionCard {
                                width: parent.width
                                title: I18n.tr("Home Quick Controls")
                                    + " (" + (NotchConfig.homeTiles || []).length + "/8 · "
                                    + ((NotchConfig.homeTiles || []).length > 4 ? I18n.tr("2 rows") : I18n.tr("1 row")) + ")"
                                collapsible: false

                                Column {
                                    width: parent.width
                                    padding: 14
                                    spacing: 10

                                    Grid {
                                        width: parent.width - 28
                                        columns: 2
                                        columnSpacing: 8
                                        rowSpacing: 8

                                        Repeater {
                                            model: win.homeTileCatalog
                                            delegate: Rectangle {
                                                required property var modelData
                                                readonly property bool active: NotchConfig.isHomeTileEnabled(modelData.id)
                                                width: Math.floor((parent.width - 8) / 2)
                                                height: 46
                                                radius: 10
                                                color: active
                                                    ? Qt.rgba(Tsukuyomi.Style.accent.r, Tsukuyomi.Style.accent.g, Tsukuyomi.Style.accent.b, 0.16)
                                                    : (htMa.containsMouse ? Tsukuyomi.Style.hover : Tsukuyomi.Style.input)
                                                border.width: 1
                                                border.color: active ? Tsukuyomi.Style.accent : Tsukuyomi.Style.line

                                                Row {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    anchors.rightMargin: 10
                                                    spacing: 8
                                                    NotchIcon {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: modelData.icon
                                                        font.pixelSize: 16
                                                        fill: active ? 1 : 0
                                                        color: active ? Tsukuyomi.Style.accent : Tsukuyomi.Style.secondary
                                                    }
                                                    Column {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: parent.width - 56
                                                        Text {
                                                            text: I18n.tr(modelData.label)
                                                            color: Tsukuyomi.Style.text
                                                            font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.DemiBold
                                                        }
                                                        Text {
                                                            width: parent.width
                                                            text: I18n.tr(modelData.hint)
                                                            color: Tsukuyomi.Style.muted
                                                            font.family: Tokens.ui; font.pixelSize: 9
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                    NotchIcon {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: active ? "check_circle" : "add_circle_outline"
                                                        font.pixelSize: 16
                                                        fill: active ? 1 : 0
                                                        color: active ? Tsukuyomi.Style.accent : Tsukuyomi.Style.muted
                                                    }
                                                }
                                                MouseArea {
                                                    id: htMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: NotchConfig.toggleHomeTile(modelData.id)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Tsukuyomi.SectionCard {
                                width: parent.width
                                title: I18n.tr("Tab Order & Visibility")
                                collapsible: false

                                Column {
                                    width: parent.width

                                    SettingRow {
                                        label: I18n.tr("Reset Default Order")
                                        sub: I18n.tr("Restore standard left-to-right Notch sequence")
                                        HubChip {
                                            label: I18n.tr("Restore Order")
                                            checked: (NotchConfig.tabOrder || []).length === 0
                                            onToggled: NotchConfig.resetTabOrder()
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        height: win.allTabIds.length * 44

                                        Repeater {
                                            model: Registry.orderedTabs(NotchConfig.tabOrder)
                                        delegate: Item {
                                            required property var modelData
                                            required property int index
                                            width: parent.width
                                            height: 44

                                            Row {
                                                anchors.fill: parent
                                                anchors.leftMargin: 14
                                                anchors.rightMargin: 14
                                                spacing: 10

                                                Text {
                                                    width: 18
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: (index + 1) + "."
                                                    color: Tsukuyomi.Style.muted
                                                    font.family: win.monoFont; font.pixelSize: 10
                                                }
                                                NotchIcon {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.icon
                                                    font.pixelSize: 16
                                                    fill: 1
                                                    color: NotchConfig.isTabEnabled(modelData.id) ? Tsukuyomi.Style.accent : Tsukuyomi.Style.muted
                                                }
                                                Text {
                                                    width: parent.width - 178
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: I18n.tr(modelData.label)
                                                    color: Tsukuyomi.Style.text
                                                    font.family: Tokens.ui; font.pixelSize: 12; font.weight: Font.Medium
                                                }

                                                // Move Left/Up
                                                Rectangle {
                                                    width: 26; height: 24; radius: 6
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: upMa.containsMouse ? Tsukuyomi.Style.hover : Tsukuyomi.Style.input
                                                    border.width: 1; border.color: Tsukuyomi.Style.line
                                                    opacity: index > 0 ? 1.0 : 0.35
                                                    NotchIcon { anchors.centerIn: parent; text: "arrow_upward"; font.pixelSize: 13; color: Tsukuyomi.Style.text }
                                                    MouseArea {
                                                        id: upMa; anchors.fill: parent; hoverEnabled: true
                                                        enabled: index > 0
                                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                        onClicked: NotchConfig.moveTab(modelData.id, -1, win.allTabIds)
                                                    }
                                                }

                                                // Move Right/Down
                                                Rectangle {
                                                    width: 26; height: 24; radius: 6
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: dnMa.containsMouse ? Tsukuyomi.Style.hover : Tsukuyomi.Style.input
                                                    border.width: 1; border.color: Tsukuyomi.Style.line
                                                    opacity: index < win.allTabIds.length - 1 ? 1.0 : 0.35
                                                    NotchIcon { anchors.centerIn: parent; text: "arrow_downward"; font.pixelSize: 13; color: Tsukuyomi.Style.text }
                                                    MouseArea {
                                                        id: dnMa; anchors.fill: parent; hoverEnabled: true
                                                        enabled: index < win.allTabIds.length - 1
                                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                        onClicked: NotchConfig.moveTab(modelData.id, 1, win.allTabIds)
                                                    }
                                                }

                                                HubSwitch {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    checked: NotchConfig.isTabEnabled(modelData.id)
                                                    interactive: modelData.id !== "home"
                                                    onToggled: NotchConfig.setTabEnabled(modelData.id, !NotchConfig.isTabEnabled(modelData.id))
                                                }
                                            }

                                            Rectangle {
                                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14 }
                                                height: 1; color: Tsukuyomi.Style.line; opacity: 0.45
                                            }
                                        }
                                    }
                                    }
                                }
                            }
                        }

                        // ── 3. SOUNDS & ALERTS ───────────────────────────────
                        Column {
                            visible: win.section === "behavior"
                            width: parent.width
                            spacing: 12

                            Tsukuyomi.SectionCard {
                                width: parent.width
                                title: I18n.tr("Ringtones & Audio Cues")
                                collapsible: false

                                Column {
                                    width: parent.width

                                    SettingRow {
                                        label: I18n.tr("Timer Completion Ringtone")
                                        sub: I18n.tr("Played when Pomodoro or Countdown hits 00:00")
                                        Row {
                                            spacing: 5
                                            Repeater {
                                                model: win.timerSounds
                                                delegate: HubChip {
                                                    required property var modelData
                                                    label: I18n.tr(modelData.label)
                                                    checked: NotchConfig.timerRingtone === modelData.id
                                                    onToggled: {
                                                        NotchConfig.timerRingtone = modelData.id;
                                                        NotchConfig.playSound(modelData.id);
                                                    }
                                                }
                                            }
                                            Rectangle {
                                                width: 28; height: 28; radius: 8
                                                color: testTmMa.containsMouse ? Tsukuyomi.Style.hover : Tsukuyomi.Style.panel
                                                border.width: 1; border.color: Tsukuyomi.Style.line
                                                NotchIcon { anchors.centerIn: parent; text: "volume_up"; font.pixelSize: 15; color: Tsukuyomi.Style.accent }
                                                MouseArea {
                                                    id: testTmMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: NotchConfig.playSound(NotchConfig.timerRingtone)
                                                }
                                            }
                                        }
                                    }

                                    SettingRow {
                                        label: I18n.tr("Notification Sound")
                                        sub: I18n.tr("Chime played when alerts arrive outside DND")
                                        divider: false
                                        Row {
                                            spacing: 5
                                            Repeater {
                                                model: win.notifSounds
                                                delegate: HubChip {
                                                    required property var modelData
                                                    label: I18n.tr(modelData.label)
                                                    checked: NotchConfig.notifSound === modelData.id
                                                    onToggled: {
                                                        NotchConfig.notifSound = modelData.id;
                                                        NotchConfig.playSound(modelData.id);
                                                    }
                                                }
                                            }
                                            Rectangle {
                                                width: 28; height: 28; radius: 8
                                                color: testNfMa.containsMouse ? Tsukuyomi.Style.hover : Tsukuyomi.Style.panel
                                                border.width: 1; border.color: Tsukuyomi.Style.line
                                                NotchIcon { anchors.centerIn: parent; text: "volume_up"; font.pixelSize: 15; color: Tsukuyomi.Style.accent }
                                                MouseArea {
                                                    id: testNfMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: NotchConfig.playSound(NotchConfig.notifSound)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Tsukuyomi.SectionCard {
                                width: parent.width
                                title: I18n.tr("Notch Behavior & Notification Routing")
                                collapsible: false

                                Column {
                                    width: parent.width
                                    SettingRow {
                                        label: I18n.tr("Open Notch on Hover")
                                        sub: I18n.tr("Expand panel automatically when cursor rests on top pill")
                                        HubSwitch { checked: NotchConfig.openOnHover; onToggled: NotchConfig.openOnHover = !NotchConfig.openOnHover }
                                    }
                                    SettingRow {
                                        label: I18n.tr("Auto-Collapse Outside Click")
                                        sub: I18n.tr("Retract island back to pill on outside pointer click")
                                        HubSwitch { checked: NotchConfig.autoCollapse; onToggled: NotchConfig.autoCollapse = !NotchConfig.autoCollapse }
                                    }
                                    SettingRow {
                                        label: I18n.tr("Dynamic Live Activities")
                                        sub: I18n.tr("Animate pill on charger, Bluetooth, timer, and volume changes")
                                        HubSwitch { checked: NotchConfig.liveActivities; onToggled: NotchConfig.liveActivities = !NotchConfig.liveActivities }
                                    }
                                    SettingRow {
                                        label: I18n.tr("Remember Last Opened Tab")
                                        sub: I18n.tr("Reopen the previously viewed tool instead of Home")
                                        HubSwitch { checked: NotchConfig.defaultTab === "last"; onToggled: NotchConfig.defaultTab = (NotchConfig.defaultTab === "last" ? "home" : "last") }
                                    }
                                    SettingRow {
                                        label: I18n.tr("Show Notifications in Notch")
                                        sub: I18n.tr("Route desktop notifications into Notch banner & log")
                                        HubSwitch { checked: NotchConfig.notifInNotch; onToggled: NotchConfig.notifInNotch = !NotchConfig.notifInNotch }
                                    }
                                    SettingRow {
                                        label: I18n.tr("Show Alerts While Focus Active")
                                        sub: I18n.tr("Keep recording silent alerts while Do Not Disturb is on")
                                        divider: false
                                        HubSwitch { checked: NotchConfig.notifShowWhileDnd; onToggled: NotchConfig.notifShowWhileDnd = !NotchConfig.notifShowWhileDnd }
                                    }
                                }
                            }
                        }

                        // ── 4. CLOUD, MEDIA & WEATHER ────────────────────────
                        Column {
                            visible: win.section === "media"
                            width: parent.width
                            spacing: 12

                            Tsukuyomi.SectionCard {
                                width: parent.width
                                title: I18n.tr("Google Drive Account (rclone)")
                                collapsible: false

                                SettingRow {
                                    divider: false
                                    label: NotchFilesStore.gdriveRemote !== ""
                                        ? (I18n.tr("Connected: ") + NotchFilesStore.gdriveRemote)
                                        : (NotchFilesStore.rcloneInstalled ? I18n.tr("Google Drive Not Signed In") : I18n.tr("rclone Package Required"))
                                    sub: NotchFilesStore.gdriveRemote !== ""
                                        ? I18n.tr("Ready to upload shelved files directly from Files -> GDrive")
                                        : (NotchFilesStore.rcloneInstalled
                                            ? I18n.tr("Opens browser OAuth once to link your Drive remote")
                                            : I18n.tr("rclone binary not detected in PATH"))

                                    HubChip {
                                        visible: NotchFilesStore.rcloneInstalled
                                        label: NotchFilesStore.gdriveRemote !== "" ? I18n.tr("Re-link") : I18n.tr("Connect Google Drive")
                                        checked: NotchFilesStore.gdriveRemote === ""
                                        onToggled: NotchFilesStore.connectGdrive()
                                    }
                                    HubChip {
                                        label: I18n.tr("Refresh")
                                        checked: false
                                        onToggled: NotchFilesStore.checkRclone()
                                    }
                                }
                            }

                            Tsukuyomi.SectionCard {
                                width: parent.width
                                title: I18n.tr("Music & Visual Gradients")
                                collapsible: false

                                Column {
                                    width: parent.width
                                    SettingRow {
                                        label: I18n.tr("Playback Source")
                                        sub: I18n.tr("System MPRIS Now Playing or local Orpheus daemon")
                                        Row {
                                            spacing: 6
                                            HubChip { label: I18n.tr("Now Playing"); checked: NotchConfig.musicSource === "nowplaying"; onToggled: NotchConfig.musicSource = "nowplaying" }
                                            HubChip { label: I18n.tr("Orpheus"); checked: NotchConfig.musicSource === "orpheus"; onToggled: NotchConfig.musicSource = "orpheus" }
                                        }
                                    }
                                    SettingRow {
                                        label: I18n.tr("Dynamic Album Backdrop")
                                        sub: I18n.tr("Sample track cover colors for ambient player gradient")
                                        HubSwitch { checked: NotchConfig.musicDynamicGradient; onToggled: NotchConfig.musicDynamicGradient = !NotchConfig.musicDynamicGradient }
                                    }
                                    SettingRow {
                                        label: I18n.tr("Dynamic Weather Sky")
                                        sub: I18n.tr("Adapt weather card gradient to time of day & sky")
                                        HubSwitch { checked: NotchConfig.weatherDynamicGradient; onToggled: NotchConfig.weatherDynamicGradient = !NotchConfig.weatherDynamicGradient }
                                    }
                                    SettingRow {
                                        label: I18n.tr("Forecast Measurement Units")
                                        sub: I18n.tr("Switch between Metric (°C / km/h) and Imperial (°F / mph)")
                                        divider: false
                                        Row {
                                            spacing: 6
                                            HubChip { label: "°C / km/h"; checked: Config.weatherUnit !== "imperial"; onToggled: Weather.setUnit("metric") }
                                            HubChip { label: "°F / mph";  checked: Config.weatherUnit === "imperial"; onToggled: Weather.setUnit("imperial") }
                                        }
                                    }
                                }
                            }

                            Tsukuyomi.SectionCard {
                                width: parent.width
                                title: I18n.tr("Weather Location")
                                collapsible: false
                                Column {
                                    width: parent.width; padding: 14; spacing: 8
                                    Row {
                                        width: parent.width - 28
                                        spacing: 8
                                        Rectangle {
                                            width: parent.width - 170; height: 32; radius: 8
                                            color: Tsukuyomi.Style.input; border.width: 1
                                            border.color: wxInp.activeFocus ? Tsukuyomi.Style.accent : Tsukuyomi.Style.line
                                            TextInput {
                                                id: wxInp
                                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                text: win.weatherInput
                                                color: Tsukuyomi.Style.text
                                                font.family: Tokens.ui; font.pixelSize: 11
                                                onAccepted: win.saveWeatherLoc()
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: wxInp.text === ""
                                                    text: I18n.tr("City or leave blank for Auto IP (e.g. Jakarta)")
                                                    color: Tsukuyomi.Style.muted; font.family: Tokens.ui; font.pixelSize: 11
                                                }
                                            }
                                        }
                                        Rectangle {
                                            width: 74; height: 32; radius: 8; color: Tsukuyomi.Style.accent
                                            Text { anchors.centerIn: parent; text: I18n.tr("Apply"); color: win.onAccent; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.DemiBold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.saveWeatherLoc() }
                                        }
                                        Rectangle {
                                            width: 78; height: 32; radius: 8; color: Tsukuyomi.Style.panel; border.width: 1; border.color: Tsukuyomi.Style.line
                                            Text { anchors.centerIn: parent; text: I18n.tr("Auto IP"); color: Tsukuyomi.Style.secondary; font.family: Tokens.ui; font.pixelSize: 11 }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { wxInp.text = ""; win.saveWeatherLoc(); }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── 5. HEALTH, TIMER & TELEPROMPTER ──────────────────
                        Column {
                            visible: win.section === "health"
                            width: parent.width
                            spacing: 12

                            Tsukuyomi.SectionCard {
                                width: parent.width
                                title: I18n.tr("Hydration & Wellness")
                                collapsible: false
                                Column {
                                    width: parent.width
                                    SettingRow {
                                        label: I18n.tr("Daily Water Goal")
                                        sub: (NotchHealthStore.waterGoal * 0.25).toFixed(2) + " L " + I18n.tr("target per day")
                                        Row {
                                            spacing: 8
                                            Rectangle {
                                                width: 26; height: 26; radius: 7
                                                color: Tsukuyomi.Style.input; border.width: 1; border.color: Tsukuyomi.Style.line
                                                Text { anchors.centerIn: parent; text: "−"; color: Tsukuyomi.Style.text; font.family: win.monoFont; font.pixelSize: 13 }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { NotchHealthStore.waterGoal = Math.max(4, NotchHealthStore.waterGoal - 1); NotchHealthStore.persist(); } }
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: NotchHealthStore.waterGoal + " gl"
                                                color: Tsukuyomi.Style.text; font.family: win.monoFont; font.pixelSize: 11; font.weight: Font.DemiBold
                                            }
                                            Rectangle {
                                                width: 26; height: 26; radius: 7
                                                color: Tsukuyomi.Style.input; border.width: 1; border.color: Tsukuyomi.Style.line
                                                Text { anchors.centerIn: parent; text: "+"; color: Tsukuyomi.Style.text; font.family: win.monoFont; font.pixelSize: 13 }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { NotchHealthStore.waterGoal = Math.min(16, NotchHealthStore.waterGoal + 1); NotchHealthStore.persist(); } }
                                            }
                                        }
                                    }
                                    SettingRow {
                                        label: I18n.tr("Hydration Reminders")
                                        sub: I18n.tr("Periodic nudge in Health card when intake is behind")
                                        divider: false
                                        HubSwitch {
                                            checked: NotchHealthStore.waterReminderEnabled
                                            onToggled: { NotchHealthStore.waterReminderEnabled = !NotchHealthStore.waterReminderEnabled; NotchHealthStore.persist(); }
                                        }
                                    }
                                }
                            }

                            Tsukuyomi.SectionCard {
                                width: parent.width
                                title: I18n.tr("Pomodoro & Teleprompter")
                                collapsible: false
                                Column {
                                    width: parent.width
                                    SettingRow {
                                        label: I18n.tr("Pomodoro Focus Duration")
                                        sub: I18n.tr("Default Focus session length")
                                        Row {
                                            spacing: 5
                                            Repeater {
                                                model: [15, 25, 45, 50]
                                                delegate: HubChip {
                                                    required property int modelData
                                                    label: modelData + "m"
                                                    checked: NotchTimerState.focusMinutes === modelData
                                                    onToggled: NotchTimerState.setFocusMinutes(modelData)
                                                }
                                            }
                                        }
                                    }
                                    SettingRow {
                                        label: I18n.tr("Short Break Length")
                                        sub: I18n.tr("Rest duration between focus rounds")
                                        Row {
                                            spacing: 5
                                            Repeater {
                                                model: [5, 10]
                                                delegate: HubChip {
                                                    required property int modelData
                                                    label: modelData + "m"
                                                    checked: NotchTimerState.shortBreakMinutes === modelData
                                                    onToggled: {
                                                        NotchTimerState.shortBreakMinutes = modelData;
                                                        if (!NotchTimerState.running && NotchTimerState.mode === "pomodoro" && NotchTimerState.pomoPhase === "short")
                                                            NotchTimerState.remainingSec = modelData * 60;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    SettingRow {
                                        label: I18n.tr("Teleprompter Window Size")
                                        sub: I18n.tr("Viewport expansion scale when reading scripts")
                                        Row {
                                            spacing: 5
                                            Repeater {
                                                model: [100, 130, 160]
                                                delegate: HubChip {
                                                    required property int modelData
                                                    label: modelData + "%"
                                                    checked: NotchTeleprompterStore.scalePct === modelData
                                                    onToggled: { NotchTeleprompterStore.scalePct = modelData; NotchTeleprompterStore.persist(); }
                                                }
                                            }
                                        }
                                    }
                                    SettingRow {
                                        label: I18n.tr("Teleprompter Cadence")
                                        sub: I18n.tr("Default reading scroll speed (WPM)")
                                        divider: false
                                        Row {
                                            spacing: 5
                                            Repeater {
                                                model: [110, 140, 170]
                                                delegate: HubChip {
                                                    required property int modelData
                                                    label: modelData + " WPM"
                                                    checked: NotchTeleprompterStore.wpm === modelData
                                                    onToggled: { NotchTeleprompterStore.wpm = modelData; NotchTeleprompterStore.persist(); }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function saveWeatherLoc() {
        var next = wxInp.text.trim();
        Weather.send("settings.patch", { path: "weatherLocation", value: next });
        Weather.send("weather.configure", {
            location: next,
            unit: Config.weatherUnit,
            clock24: TimeFormat.is24h
        });
    }
}
