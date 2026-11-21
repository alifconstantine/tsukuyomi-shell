import QtQuick
import Quickshell
import shell.services
import Ryoku.Ui.Singletons
import "NotchRegistry.js" as Registry

// Notch Settings view opened from the Gear icon in the Notch header.
// Covers Appearance (Follow System vs Custom Surface & Accent Hex),
// Behavior & Notifications, Music/Weather options, and Tab visibility.
Item {
    id: cfgView

    required property var root
    required property var theme
    readonly property bool anim: !Perf.reduceMotion

    property string weatherInput: Config.weatherLocation || ""
    property string surfaceHexInput: NotchConfig.customSurfaceHex
    property string accentHexInput: NotchConfig.customAccentHex

    readonly property var hexPresets: [
        { name: "Obsidian", surf: "#0B0B0E", acc: "#C92A2A" },
        { name: "Slate",    surf: "#14171C", acc: "#5E9EFF" },
        { name: "Jade",     surf: "#0D1512", acc: "#4ADE80" },
        { name: "Paper",    surf: "#F2EFE9", acc: "#C92A2A" }
    ]

    component ToggleChip: Rectangle {
        id: tc
        property string label: ""
        property bool checked: false
        signal toggled()

        width: tcRow.implicitWidth + 18
        height: 28
        radius: 9
        color: checked
            ? Qt.rgba(cfgView.theme.accent.r, cfgView.theme.accent.g, cfgView.theme.accent.b, 0.22)
            : (tcMa.containsMouse ? cfgView.theme.cardHover : cfgView.theme.card)
        border.width: 1
        border.color: checked ? cfgView.theme.accent : cfgView.theme.border
        Behavior on color { enabled: cfgView.anim; ColorAnimation { duration: 140 } }

        Row {
            id: tcRow
            anchors.centerIn: parent
            spacing: 5
            Rectangle {
                width: 7; height: 7; radius: 3.5
                anchors.verticalCenter: parent.verticalCenter
                color: tc.checked ? cfgView.theme.accent : cfgView.theme.muted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tc.label
                color: cfgView.theme.ink
                font.family: Tokens.ui
                font.pixelSize: 10
                font.weight: tc.checked ? Font.DemiBold : Font.Normal
            }
        }
        MouseArea {
            id: tcMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tc.toggled()
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: bodyCol.implicitHeight + 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: bodyCol
            width: flick.width
            spacing: 12

            // ── 1. Appearance & Custom Hex ───────────────────────────────────
            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: I18n.tr("APPEARANCE & COLOR")
                    color: cfgView.theme.muted
                    font.family: Tokens.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.2
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    ToggleChip {
                        label: I18n.tr("Follow System")
                        checked: NotchConfig.themeMode === "system"
                        onToggled: NotchConfig.themeMode = "system"
                    }
                    ToggleChip {
                        label: I18n.tr("Custom Hex")
                        checked: NotchConfig.themeMode === "custom"
                        onToggled: NotchConfig.themeMode = "custom"
                    }
                    ToggleChip {
                        label: I18n.tr("Frosted")
                        checked: NotchConfig.frosted
                        onToggled: NotchConfig.frosted = !NotchConfig.frosted
                    }
                }

                // Custom Hex editors + quick swatches (visible when Custom Hex active)
                Row {
                    width: parent.width
                    visible: NotchConfig.themeMode === "custom"
                    spacing: 8

                    // Surface Hex
                    Rectangle {
                        width: 148; height: 30; radius: 9
                        color: cfgView.theme.card
                        border.width: 1
                        border.color: surfField.activeFocus ? cfgView.theme.accent : cfgView.theme.border
                        Row {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6
                            Rectangle {
                                width: 16; height: 16; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: cfgView.theme.parseColor(surfField.text, cfgView.theme.baseSurface)
                                border.width: 1; border.color: cfgView.theme.border
                            }
                            TextInput {
                                id: surfField
                                width: parent.width - 24
                                anchors.verticalCenter: parent.verticalCenter
                                text: cfgView.surfaceHexInput
                                color: cfgView.theme.ink
                                font.family: Tokens.mono
                                font.pixelSize: 11
                                selectByMouse: true
                                onEditingFinished: {
                                    var norm = NotchConfig.normalizeHex(text, NotchConfig.customSurfaceHex);
                                    text = norm;
                                    cfgView.surfaceHexInput = norm;
                                    NotchConfig.customSurfaceHex = norm;
                                }
                            }
                        }
                    }

                    // Accent Hex
                    Rectangle {
                        width: 148; height: 30; radius: 9
                        color: cfgView.theme.card
                        border.width: 1
                        border.color: accField.activeFocus ? cfgView.theme.accent : cfgView.theme.border
                        Row {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6
                            Rectangle {
                                width: 16; height: 16; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: cfgView.theme.parseColor(accField.text, cfgView.theme.accent)
                                border.width: 1; border.color: cfgView.theme.border
                            }
                            TextInput {
                                id: accField
                                width: parent.width - 24
                                anchors.verticalCenter: parent.verticalCenter
                                text: cfgView.accentHexInput
                                color: cfgView.theme.ink
                                font.family: Tokens.mono
                                font.pixelSize: 11
                                selectByMouse: true
                                onEditingFinished: {
                                    var norm = NotchConfig.normalizeHex(text, NotchConfig.customAccentHex);
                                    text = norm;
                                    cfgView.accentHexInput = norm;
                                    NotchConfig.customAccentHex = norm;
                                }
                            }
                        }
                    }

                    // Quick theme swatches
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Repeater {
                            model: cfgView.hexPresets
                            delegate: Rectangle {
                                required property var modelData
                                width: 22; height: 22; radius: 11
                                color: modelData.surf
                                border.width: 2
                                border.color: modelData.acc
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        NotchConfig.customSurfaceHex = modelData.surf;
                                        NotchConfig.customAccentHex = modelData.acc;
                                        surfField.text = modelData.surf;
                                        accField.text = modelData.acc;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── 2. Behavior & Notifications ──────────────────────────────────
            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: I18n.tr("BEHAVIOR & NOTIFICATIONS")
                    color: cfgView.theme.muted
                    font.family: Tokens.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.2
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    ToggleChip {
                        label: I18n.tr("Open on Hover")
                        checked: NotchConfig.openOnHover
                        onToggled: NotchConfig.openOnHover = !NotchConfig.openOnHover
                    }
                    ToggleChip {
                        label: I18n.tr("Live Activities")
                        checked: NotchConfig.liveActivities
                        onToggled: NotchConfig.liveActivities = !NotchConfig.liveActivities
                    }
                    ToggleChip {
                        label: I18n.tr("Notifications in Notch")
                        checked: NotchConfig.notifInNotch
                        onToggled: NotchConfig.notifInNotch = !NotchConfig.notifInNotch
                    }
                    ToggleChip {
                        label: I18n.tr("Remember Last Tab")
                        checked: NotchConfig.defaultTab === "last"
                        onToggled: NotchConfig.defaultTab = (NotchConfig.defaultTab === "last" ? "home" : "last")
                    }
                }
            }

            // ── 3. Music & Weather Location ──────────────────────────────────
            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: I18n.tr("MUSIC & WEATHER")
                    color: cfgView.theme.muted
                    font.family: Tokens.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.2
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    ToggleChip {
                        label: I18n.tr("Now Playing")
                        checked: NotchConfig.musicSource === "nowplaying"
                        onToggled: NotchConfig.musicSource = "nowplaying"
                    }
                    ToggleChip {
                        label: I18n.tr("Orpheus")
                        checked: NotchConfig.musicSource === "orpheus"
                        onToggled: NotchConfig.musicSource = "orpheus"
                    }
                    ToggleChip {
                        label: I18n.tr("Album Gradient")
                        checked: NotchConfig.musicDynamicGradient
                        onToggled: NotchConfig.musicDynamicGradient = !NotchConfig.musicDynamicGradient
                    }
                    ToggleChip {
                        label: Config.weatherUnit === "imperial" ? "°F / mph" : "°C / km/h"
                        checked: true
                        onToggled: Weather.setUnit(Config.weatherUnit === "imperial" ? "metric" : "imperial")
                    }
                }

                // Weather location override
                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: parent.width - 78
                        height: 30
                        radius: 9
                        color: cfgView.theme.card
                        border.width: 1
                        border.color: wxLocField.activeFocus ? cfgView.theme.accent : cfgView.theme.border

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6
                            NotchIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "location_on"
                                font.pixelSize: 14
                                color: cfgView.theme.muted
                            }
                            TextInput {
                                id: wxLocField
                                width: parent.width - 24
                                anchors.verticalCenter: parent.verticalCenter
                                text: cfgView.weatherInput
                                color: cfgView.theme.ink
                                font.family: Tokens.ui
                                font.pixelSize: 11
                                selectByMouse: true
                                onAccepted: saveWeatherLoc()

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: wxLocField.text === ""
                                    text: I18n.tr("Weather location (blank = Auto IP, e.g. Jakarta)")
                                    color: cfgView.theme.muted
                                    font.family: Tokens.ui
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 70; height: 30; radius: 9
                        color: wxApplyMa.containsMouse ? Qt.lighter(cfgView.theme.accent, 1.1) : cfgView.theme.accent
                        Text {
                            anchors.centerIn: parent
                            text: I18n.tr("Apply")
                            color: cfgView.theme.onAccent
                            font.family: Tokens.ui
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: wxApplyMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: saveWeatherLoc()
                        }
                    }
                }
            }

            // ── 4. Tabs Visibility ───────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: I18n.tr("VISIBLE TABS")
                    color: cfgView.theme.muted
                    font.family: Tokens.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.2
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: Registry.TABS
                        delegate: ToggleChip {
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

    function saveWeatherLoc() {
        var next = wxLocField.text.trim();
        Weather.send("settings.patch", { path: "weatherLocation", value: next });
        Weather.send("weather.configure", {
            location: next,
            unit: Config.weatherUnit,
            clock24: TimeFormat.is24h
        });
    }
}
