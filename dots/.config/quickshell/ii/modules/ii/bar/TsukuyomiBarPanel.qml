pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.calendar
import qs.services

PanelWindow {
    id: root
    required property TsukuyomiBarContent bar
    readonly property bool bottom: Config.options.bar.bottom
    readonly property bool clockMenu: bar.panel === "clock"
    property string pendingAction: ""
    property string pendingLabel: ""

    screen: bar.QsWindow.window?.screen ?? null
    visible: bar.panel !== ""
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.min(clockMenu ? 352 : 424, (screen?.width ?? 800) - 24)
    implicitHeight: Math.min(body.implicitHeight + 28, (screen?.height ?? 640) - 66)
    WlrLayershell.namespace: "tsukuyomi:controls"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors {
        left: !root.clockMenu && root.bar.panel !== "status"
        right: root.bar.panel === "status"
        top: !root.bottom
        bottom: root.bottom
    }
    margins {
        top: root.bottom ? 0 : root.bar.height + 3
        bottom: root.bottom ? root.bar.height + 3 : 0
        left: 12
        right: 12
    }

    function closePanel() {
        bar.panel = "";
    }

    function openSettings() {
        closePanel();
        Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("settings.qml")]);
    }

    function sessionAction(action, label) {
        if (action === "lock" || action === "suspend") {
            if (action === "lock") Session.lock();
            else Session.suspend();
            closePanel();
            return;
        }
        pendingAction = action;
        pendingLabel = label;
    }

    component LevelSlider: Slider {
        id: level
        Layout.fillWidth: true
        implicitHeight: 28
        from: 0
        to: 1
        background: Rectangle {
            x: level.leftPadding
            y: (level.height - height) / 2
            width: level.availableWidth
            height: 4
            radius: 2
            color: TsukuyomiStyle.border
            Rectangle {
                width: parent.width * level.visualPosition
                height: parent.height
                radius: parent.radius
                color: TsukuyomiStyle.foreground
            }
        }
        handle: Rectangle {
            x: level.leftPadding + level.visualPosition * (level.availableWidth - width)
            y: (level.height - height) / 2
            implicitWidth: 13
            implicitHeight: 13
            radius: 7
            color: TsukuyomiStyle.foreground
            border.color: TsukuyomiStyle.surface
            border.width: level.visualFocus ? 2 : 1
        }
    }

    Component.onCompleted: {
        GlobalFocusGrab.addDismissable(root);
        closeButton.forceActiveFocus();
    }
    Component.onDestruction: GlobalFocusGrab.removeDismissable(root)
    Connections {
        target: GlobalFocusGrab
        function onDismissed() { root.closePanel(); }
    }
    Connections {
        target: root.bar
        function onPanelChanged() {
            root.pendingAction = "";
            closeButton.forceActiveFocus();
        }
    }

    TsukuyomiSurface { anchors.fill: parent }
    FocusScope {
        anchors.fill: parent
        Keys.onEscapePressed: {
            if (root.pendingAction.length > 0) root.pendingAction = "";
            else if (root.bar.panel === "customize") root.bar.panel = "controls";
            else root.closePanel();
        }
        ScrollView {
            id: scroll
            anchors.fill: parent
            anchors.margins: 14
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                id: body
                width: scroll.availableWidth
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: TsukuyomiStyle.foreground
                        font.family: Appearance.font.family.main
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        text: {
                            switch (root.bar.panel) {
                            case "customize": return Translation.tr("Bar & Dock");
                            case "clock": return DateTime.time;
                            case "status": return Translation.tr("Status");
                            default: return Translation.tr("System Controls");
                            }
                        }
                    }
                    TsukuyomiButton {
                        visible: root.bar.panel === "controls" || root.bar.panel === "status"
                        glyph: "tune"
                        text: Translation.tr("Customize Bar")
                        onClicked: root.bar.panel = "customize"
                    }
                    TsukuyomiButton {
                        visible: root.bar.panel === "controls" || root.bar.panel === "status"
                        glyph: "settings"
                        description: Translation.tr("Settings")
                        onClicked: root.openSettings()
                    }
                    TsukuyomiButton {
                        id: closeButton
                        glyph: root.bar.panel === "customize" ? "arrow_back" : "close"
                        description: root.bar.panel === "customize" ? Translation.tr("System Controls") : Translation.tr("Close")
                        flatSurface: true
                        onClicked: {
                            if (root.bar.panel === "customize") root.bar.panel = "controls";
                            else root.closePanel();
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    sourceComponent: {
                        switch (root.bar.panel) {
                        case "clock": return clockContents;
                        case "customize": return customization;
                        case "status": return statusContents;
                        default: return controlContents;
                        }
                    }
                }
            }
        }
    }

    Component {
        id: controlContents
        ColumnLayout {
            spacing: 10
            TsukuyomiVitals {}
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: TsukuyomiStyle.border
            }
            RowLayout {
                spacing: 8
                TsukuyomiButton {
                    Layout.fillWidth: true
                    enabled: Network.wifi
                    text: Translation.tr("Wi-Fi")
                    glyph: Network.wifiEnabled ? "wifi" : "wifi_off"
                    selected: Network.wifiEnabled
                    onClicked: Network.toggleWifi()
                }
                TsukuyomiButton {
                    Layout.fillWidth: true
                    visible: BluetoothStatus.available
                    text: Translation.tr("Bluetooth")
                    glyph: BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                    selected: BluetoothStatus.enabled
                    onClicked: {
                        const adapter = Bluetooth.defaultAdapter;
                        if (adapter) adapter.enabled = !adapter.enabled;
                    }
                }
            }
            RowLayout {
                visible: Audio.ready
                TsukuyomiButton {
                    glyph: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                    description: Translation.tr("Mute")
                    onClicked: Audio.toggleMute()
                }
                LevelSlider {
                    Accessible.name: Translation.tr("Volume")
                    value: Math.min(to, Audio.value)
                    onMoved: {
                        if (Audio.sink?.audio) Audio.sink.audio.volume = value;
                    }
                }
                Text {
                    width: 40
                    text: Math.round(Audio.value * 100) + "%"
                    color: TsukuyomiStyle.muted
                }
            }
            RowLayout {
                visible: root.bar.brightness?.ready ?? false
                MaterialSymbol {
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: 16
                    text: "light_mode"
                    color: TsukuyomiStyle.foreground
                }
                LevelSlider {
                    Accessible.name: Translation.tr("Brightness")
                    value: root.bar.brightness?.brightness ?? 0
                    onMoved: root.bar.brightness?.setBrightness(value)
                }
                Text {
                    width: 40
                    text: Math.round((root.bar.brightness?.brightness ?? 0) * 100) + "%"
                    color: TsukuyomiStyle.muted
                }
            }
            RowLayout {
                Text {
                    Layout.fillWidth: true
                    text: Translation.tr("Power Profile")
                    color: TsukuyomiStyle.foreground
                }
                TsukuyomiComboBox {
                    Accessible.name: Translation.tr("Power Profile")
                    model: PowerProfiles.hasPerformanceProfile
                        ? [Translation.tr("Power Saver"), Translation.tr("Balanced"), Translation.tr("Performance")]
                        : [Translation.tr("Power Saver"), Translation.tr("Balanced")]
                    currentIndex: PowerProfiles.profile
                    onActivated: index => PowerProfiles.profile = index
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [
                        ["lock", "lock", Translation.tr("Lock")],
                        ["suspend", "dark_mode", Translation.tr("Sleep")],
                        ["logout", "logout", Translation.tr("Log Out")],
                        ["reboot", "restart_alt", Translation.tr("Restart")],
                        ["poweroff", "power_settings_new", Translation.tr("Shut Down")]
                    ]
                    TsukuyomiButton {
                        required property var modelData
                        Layout.fillWidth: true
                        glyph: modelData[1]
                        description: modelData[2]
                        onClicked: root.sessionAction(modelData[0], modelData[2])
                    }
                }
            }
            RowLayout {
                visible: root.pendingAction.length > 0
                TsukuyomiButton {
                    Layout.fillWidth: true
                    text: Translation.tr("Cancel")
                    onClicked: root.pendingAction = ""
                }
                TsukuyomiButton {
                    Layout.fillWidth: true
                    text: root.pendingLabel
                    selected: true
                    onClicked: {
                        const action = root.pendingAction;
                        if (action === "logout") Session.logout();
                        else if (action === "reboot") Session.reboot();
                        else if (action === "poweroff") Session.poweroff();
                        root.closePanel();
                    }
                }
            }
        }
    }

    Component {
        id: statusContents
        ColumnLayout {
            Repeater {
                model: root.bar.activeIndicators
                RowLayout {
                    id: statusRow
                    required property string modelData
                    MaterialSymbol {
                        iconSize: 16
                        text: root.bar.catalogue[statusRow.modelData][1]
                        color: TsukuyomiStyle.foreground
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.bar.catalogue[statusRow.modelData][0]
                        color: TsukuyomiStyle.foreground
                    }
                    Text {
                        text: root.bar.statusValue(statusRow.modelData)
                        color: TsukuyomiStyle.muted
                    }
                }
            }
            TsukuyomiButton {
                Layout.fillWidth: true
                glyph: "tune"
                text: Translation.tr("System Controls")
                onClicked: root.bar.panel = "controls"
            }
        }
    }

    Component {
        id: clockContents
        ColumnLayout {
            CalendarWidget { Layout.fillWidth: true }
            TsukuyomiButton {
                Layout.fillWidth: true
                glyph: "notifications"
                text: Translation.tr("Notifications") + (Notifications.unread > 0 ? " · " + Notifications.unread : "")
                onClicked: {
                    root.closePanel();
                    GlobalStates.sidebarRightOpen = true;
                }
            }
        }
    }

    Component {
        id: customization
        TsukuyomiBarSettings { catalogue: root.bar.catalogue }
    }
}
