import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import shell.services
import Ryoku.Ui.Singletons
import "../../tsukuyomi" as Tsukuyomi
import "NotchRegistry.js" as Registry

// Compact Hub/Store-styled pop-up window for all Dynamic Notch configurations.
// Opened from the Notch Settings gear, Notification "Change", Weather location, or IPC.
PanelWindow {
    id: win

    property var root: null
    property bool open: false

    readonly property bool anim: !Perf.reduceMotion
    readonly property string monoFont: (win.root && win.root.mono) ? win.root.mono : "JetBrainsMono Nerd Font"

    property string section: "appearance"
    property string weatherInput: Config.weatherLocation || ""
    property string surfaceHexInput: NotchConfig.customSurfaceHex
    property string accentHexInput: NotchConfig.customAccentHex

    readonly property var sections: [
        { id: "appearance", label: "Appearance",      icon: "palette",      eyebrow: "SURFACE & COLOR",   title: "Appearance & Theme",  sub: "Match the desktop shell or configure custom Hex colors and glass." },
        { id: "behavior",   label: "Behavior",        icon: "tune",         eyebrow: "INTERACTION",       title: "Behavior & Alerts",   sub: "Hover open, live island activities, and notification routing." },
        { id: "media",      label: "Media & Weather", icon: "music_note",   eyebrow: "SOURCES & UNITS",   title: "Media & Weather",     sub: "Player source, dynamic gradients, units, and forecast city." },
        { id: "health",     label: "Health & Timer",  icon: "favorite",     eyebrow: "WELLNESS & FOCUS",  title: "Health & Timer",      sub: "Daily hydration goals, Pomodoro durations, and Teleprompter size." },
        { id: "tabs",       label: "Visible Tabs",    icon: "view_column",  eyebrow: "MODULES",           title: "Visible Notch Tabs",  sub: "Choose which tools appear inside your Dynamic Notch switcher." }
    ]

    readonly property var hexPresets: [
        { name: "Obsidian", surf: "#0B0B0E", acc: "#C92A2A" },
        { name: "Crimson",  surf: "#120E0E", acc: "#C92A2A" },
        { name: "Slate",    surf: "#14171C", acc: "#5E9EFF" },
        { name: "Paper",    surf: "#F2EFE9", acc: "#C92A2A" }
    ]

    function openWindow(initialSection) {
        if (initialSection) win.section = initialSection;
        win.weatherInput = Config.weatherLocation || "";
        win.surfaceHexInput = NotchConfig.customSurfaceHex;
        win.accentHexInput = NotchConfig.customAccentHex;
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

    property real reveal: win.open ? 1.0 : 0.0
    Behavior on reveal {
        enabled: win.anim
        NumberAnimation {
            duration: win.open ? 220 : 150
            easing.type: win.open ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.002

    // Dim scrim
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.36 * win.reveal)
        MouseArea {
            anchors.fill: parent
            enabled: win.open
            onClicked: win.closeWindow()
        }
    }

    component HubChip: Rectangle {
        id: hc
        property string label: ""
        property bool checked: false
        signal toggled()

        height: 30
        width: hcRow.implicitWidth + 20
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
                width: 7; height: 7; radius: 3.5
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

    // Pop-up Card (Hub / Store grammar)
    Rectangle {
        id: card
        width: Math.min(736, Math.max(460, win.width - 48))
        height: Math.min(486, Math.max(320, win.height - 48))
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

        RectangularShadow {
            anchors.fill: parent
            radius: parent.radius
            blur: 24
            spread: 0
            offset: Qt.vector2d(0, 10)
            color: Qt.rgba(0, 0, 0, 0.5)
            visible: !Perf.softwareRenderer && win.reveal > 0.2
            z: -1
        }

        Keys.onEscapePressed: win.closeWindow()
        MouseArea { anchors.fill: parent; onClicked: {} }

        Row {
            anchors.fill: parent

            // ── Left Navigation Sidebar (Hub/Store style) ────────────────────
            Rectangle {
                width: 184
                height: parent.height
                color: Tsukuyomi.Style.sidebar

                // Right vertical divider
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
                                onClicked: win.section = modelData.id
                            }
                        }
                    }
                }

                // Bottom reset + saved note
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
                                NotchConfig.defaultTab = "home";
                                NotchConfig.hiddenTabs = [];
                                NotchTeleprompterStore.scalePct = 100;
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
                width: parent.width - 184
                height: parent.height

                // Page Heading + Close button
                Item {
                    id: rightHead
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 18; bottomMargin: 0 }
                    height: 54

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
                    contentHeight: secBody.implicitHeight + 12
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: secBody
                        width: bodyFlick.width
                        spacing: 12

                        // Subtitle note
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
                                title: I18n.tr("Surface & Material")
                                collapsible: false

                                Column {
                                    width: parent.width
                                    padding: 14
                                    spacing: 10

                                    Flow {
                                        width: parent.width - 28
                                        spacing: 8
                                        HubChip {
                                            label: I18n.tr("Follow System")
                                            checked: NotchConfig.themeMode === "system"
                                            onToggled: NotchConfig.themeMode = "system"
                                        }
                                        HubChip {
                                            label: I18n.tr("Custom Hex")
                                            checked: NotchConfig.themeMode === "custom"
                                            onToggled: NotchConfig.themeMode = "custom"
                                        }
                                        HubChip {
                                            label: I18n.tr("Frosted Glass")
                                            checked: NotchConfig.frosted
                                            onToggled: NotchConfig.frosted = !NotchConfig.frosted
                                        }
                                    }

                                    Row {
                                        width: parent.width - 28
                                        spacing: 6
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: I18n.tr("Corner Radius") + ":"
                                            color: Tsukuyomi.Style.secondary
                                            font.family: Tokens.ui
                                            font.pixelSize: 11
                                        }
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
                            }

                            Tsukuyomi.SectionCard {
                                width: parent.width
                                title: I18n.tr("Custom Palette & Hex")
                                collapsible: false
                                visible: NotchConfig.themeMode === "custom"

                                Column {
                                    width: parent.width
                                    padding: 14
                                    spacing: 10

                                    Row {
                                        spacing: 8
                                        Repeater {
                                            model: win.hexPresets
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: 88; height: 28; radius: 8
                                                color: modelData.surf
                                                border.width: 1
                                                border.color: NotchConfig.customSurfaceHex === modelData.surf
                                                    ? modelData.acc : Tsukuyomi.Style.line
                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: 5
                                                    Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: modelData.acc }
                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: modelData.name
                                                        color: modelData.name === "Paper" ? "#141416" : "#F2EFE9"
                                                        font.family: Tokens.ui
                                                        font.pixelSize: 10
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        win.surfaceHexInput = modelData.surf;
                                                        win.accentHexInput = modelData.acc;
                                                        NotchConfig.customSurfaceHex = modelData.surf;
                                                        NotchConfig.customAccentHex = modelData.acc;
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Row {
                                        width: parent.width - 28
                                        spacing: 8
                                        Rectangle {
                                            width: 150; height: 32; radius: 8
                                            color: Tsukuyomi.Style.input; border.width: 1
                                            border.color: sInp.activeFocus ? Tsukuyomi.Style.accent : Tsukuyomi.Style.line
                                            Row {
                                                anchors.fill: parent; anchors.margins: 8; spacing: 6
                                                Rectangle { width: 12; height: 12; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: NotchConfig.normalizeHex(sInp.text, NotchConfig.customSurfaceHex); border.width: 1; border.color: Tsukuyomi.Style.line }
                                                TextInput { id: sInp; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; text: win.surfaceHexInput; color: Tsukuyomi.Style.text; font.family: win.monoFont; font.pixelSize: 11; selectByMouse: true }
                                            }
                                        }
                                        Rectangle {
                                            width: 150; height: 32; radius: 8
                                            color: Tsukuyomi.Style.input; border.width: 1
                                            border.color: aInp.activeFocus ? Tsukuyomi.Style.accent : Tsukuyomi.Style.line
                                            Row {
                                                anchors.fill: parent; anchors.margins: 8; spacing: 6
                                                Rectangle { width: 12; height: 12; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: NotchConfig.normalizeHex(aInp.text, NotchConfig.customAccentHex); border.width: 1; border.color: Tsukuyomi.Style.line }
                                                TextInput { id: aInp; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; text: win.accentHexInput; color: Tsukuyomi.Style.text; font.family: win.monoFont; font.pixelSize: 11; selectByMouse: true }
                                            }
                                        }
                                        Rectangle {
                                            width: 92; height: 32; radius: 8
                                            color: Tsukuyomi.Style.accent
                                            Text { anchors.centerIn: parent; text: I18n.tr("Apply Hex"); color: "#FFFFFF"; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.DemiBold }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
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

                        // ── 2. BEHAVIOR & NOTIFICATIONS ──────────────────────
                        Tsukuyomi.SectionCard {
                            visible: win.section === "behavior"
                            width: parent.width
                            title: I18n.tr("Notch & Notification Routing")
                            collapsible: false

                            Column {
                                width: parent.width
                                padding: 14
                                spacing: 10
                                Flow {
                                    width: parent.width - 28
                                    spacing: 8
                                    HubChip { label: I18n.tr("Open on Hover"); checked: NotchConfig.openOnHover; onToggled: NotchConfig.openOnHover = !NotchConfig.openOnHover }
                                    HubChip { label: I18n.tr("Auto Collapse"); checked: NotchConfig.autoCollapse; onToggled: NotchConfig.autoCollapse = !NotchConfig.autoCollapse }
                                    HubChip { label: I18n.tr("Live Activities"); checked: NotchConfig.liveActivities; onToggled: NotchConfig.liveActivities = !NotchConfig.liveActivities }
                                    HubChip { label: I18n.tr("Remember Last Tab"); checked: NotchConfig.defaultTab === "last"; onToggled: NotchConfig.defaultTab = (NotchConfig.defaultTab === "last" ? "home" : "last") }
                                    HubChip { label: I18n.tr("Notifications in Notch"); checked: NotchConfig.notifInNotch; onToggled: NotchConfig.notifInNotch = !NotchConfig.notifInNotch }
                                    HubChip { label: I18n.tr("Show Alerts While DND"); checked: NotchConfig.notifShowWhileDnd; onToggled: NotchConfig.notifShowWhileDnd = !NotchConfig.notifShowWhileDnd }
                                }
                            }
                        }

                        // ── 3. MEDIA & WEATHER ───────────────────────────────
                        Column {
                            visible: win.section === "media"
                            width: parent.width
                            spacing: 12

                            Tsukuyomi.SectionCard {
                                width: parent.width
                                title: I18n.tr("Music & Visual Gradients")
                                collapsible: false
                                Column {
                                    width: parent.width; padding: 14; spacing: 8
                                    Flow {
                                        width: parent.width - 28; spacing: 8
                                        HubChip { label: I18n.tr("Now Playing"); checked: NotchConfig.musicSource === "nowplaying"; onToggled: NotchConfig.musicSource = "nowplaying" }
                                        HubChip { label: I18n.tr("Orpheus"); checked: NotchConfig.musicSource === "orpheus"; onToggled: NotchConfig.musicSource = "orpheus" }
                                        HubChip { label: I18n.tr("Album Gradient"); checked: NotchConfig.musicDynamicGradient; onToggled: NotchConfig.musicDynamicGradient = !NotchConfig.musicDynamicGradient }
                                        HubChip { label: I18n.tr("Weather Gradient"); checked: NotchConfig.weatherDynamicGradient; onToggled: NotchConfig.weatherDynamicGradient = !NotchConfig.weatherDynamicGradient }
                                        HubChip { label: Config.weatherUnit === "imperial" ? "°F / mph" : "°C / km/h"; checked: true; onToggled: Weather.setUnit(Config.weatherUnit === "imperial" ? "metric" : "imperial") }
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
                                            Text { anchors.centerIn: parent; text: I18n.tr("Apply"); color: "#FFFFFF"; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.DemiBold }
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

                        // ── 4. HEALTH & TIMER & TELEPROMPTER ─────────────────
                        Tsukuyomi.SectionCard {
                            visible: win.section === "health"
                            width: parent.width
                            title: I18n.tr("Hydration, Pomodoro & Teleprompter")
                            collapsible: false
                            Column {
                                width: parent.width; padding: 14; spacing: 10
                                Flow {
                                    width: parent.width - 28; spacing: 8
                                    Rectangle {
                                        height: 30; width: wgRow.implicitWidth + 18; radius: 8
                                        color: Tsukuyomi.Style.input; border.width: 1; border.color: Tsukuyomi.Style.line
                                        Row {
                                            id: wgRow; anchors.centerIn: parent; spacing: 8
                                            Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Water Goal") + ":"; color: Tsukuyomi.Style.secondary; font.family: Tokens.ui; font.pixelSize: 11 }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter; text: "−"; color: Tsukuyomi.Style.text; font.family: win.monoFont; font.pixelSize: 13; font.weight: Font.Bold
                                                MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: { NotchHealthStore.waterGoal = Math.max(4, NotchHealthStore.waterGoal - 1); NotchHealthStore.persist(); } }
                                            }
                                            Text { anchors.verticalCenter: parent.verticalCenter; text: NotchHealthStore.waterGoal + " (" + (NotchHealthStore.waterGoal * 0.25).toFixed(1) + "L)"; color: Tsukuyomi.Style.text; font.family: win.monoFont; font.pixelSize: 11; font.weight: Font.DemiBold }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter; text: "+"; color: Tsukuyomi.Style.text; font.family: win.monoFont; font.pixelSize: 13; font.weight: Font.Bold
                                                MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: { NotchHealthStore.waterGoal = Math.min(16, NotchHealthStore.waterGoal + 1); NotchHealthStore.persist(); } }
                                            }
                                        }
                                    }
                                    HubChip { label: I18n.tr("Water Reminder"); checked: NotchHealthStore.waterReminderEnabled; onToggled: { NotchHealthStore.waterReminderEnabled = !NotchHealthStore.waterReminderEnabled; NotchHealthStore.persist(); } }
                                    Repeater {
                                        model: [25, 45, 50]
                                        delegate: HubChip {
                                            required property int modelData
                                            label: I18n.tr("Focus") + " " + modelData + "m"
                                            checked: NotchTimerState.focusMinutes === modelData
                                            onToggled: NotchTimerState.setFocusMinutes(modelData)
                                        }
                                    }
                                    Repeater {
                                        model: [100, 130, 160]
                                        delegate: HubChip {
                                            required property int modelData
                                            label: I18n.tr("Teleprompter") + " " + modelData + "%"
                                            checked: NotchTeleprompterStore.scalePct === modelData
                                            onToggled: { NotchTeleprompterStore.scalePct = modelData; NotchTeleprompterStore.persist(); }
                                        }
                                    }
                                }
                            }
                        }

                        // ── 5. VISIBLE TABS ──────────────────────────────────
                        Tsukuyomi.SectionCard {
                            visible: win.section === "tabs"
                            width: parent.width
                            title: I18n.tr("Modules Shown in Notch")
                            collapsible: false
                            Column {
                                width: parent.width; padding: 14; spacing: 10
                                Flow {
                                    width: parent.width - 28; spacing: 8
                                    Repeater {
                                        model: Registry.TABS
                                        delegate: HubChip {
                                            required property var modelData
                                            label: I18n.tr(modelData.label)
                                            checked: NotchConfig.isTabEnabled(modelData.id)
                                            onToggled: NotchConfig.setTabEnabled(modelData.id, !NotchConfig.isTabEnabled(modelData.id))
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
