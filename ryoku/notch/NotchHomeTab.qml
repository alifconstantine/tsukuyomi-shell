import QtQuick
import Quickshell
import shell.services
import Ryoku.Ui.Singletons

// Home tab: quick controls directly available upon opening the Notch.
// Top row: Wi-Fi, Bluetooth, Focus (DND), Coffee (Keep Awake).
// Bottom row: Display brightness slider + Sound volume slider.
Item {
    id: home

    required property var root
    required property var theme
    readonly property bool anim: !Perf.reduceMotion

    Component.onCompleted: Devices.startProbes("notch-home")
    Component.onDestruction: Devices.stopProbes("notch-home")

    readonly property var sink: Audio.sink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property bool soundMuted: sinkAudio ? sinkAudio.muted : false
    readonly property int soundPct: sinkAudio ? Math.round(Math.max(0, Math.min(1.5, sinkAudio.volume)) * 100) : 0

    readonly property bool hasBacklight: Devices.backlightAvailable
    readonly property int displayPct: hasBacklight ? Math.max(1, Devices.backlightPct) : 100

    readonly property int btConnectedCount: {
        var list = BluetoothPower.devices || [];
        var n = 0;
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].connected) n++;
        return n;
    }

    component ControlPill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property string sublabel: ""
        property bool active: false
        property bool enabledControl: true
        property color activeColor: home.theme.accent
        signal triggered()

        height: 54
        radius: 14
        opacity: enabledControl ? 1.0 : 0.45
        color: active
            ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.22)
            : (pma.containsMouse ? home.theme.cardHover : home.theme.card)
        border.width: 1
        border.color: active
            ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.55)
            : home.theme.border
        scale: pma.pressed ? 0.96 : 1.0

        Behavior on color { enabled: home.anim; ColorAnimation { duration: 150 } }
        Behavior on border.color { enabled: home.anim; ColorAnimation { duration: 150 } }
        Behavior on scale { enabled: home.anim; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

        Column {
            anchors.centerIn: parent
            width: parent.width - 14
            spacing: 2

            NotchIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pill.icon
                font.pixelSize: 18
                fill: pill.active ? 1 : 0
                color: pill.active ? pill.activeColor : home.theme.ink
                Behavior on color { enabled: home.anim; ColorAnimation { duration: 150 } }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: pill.label
                color: home.theme.ink
                font.family: Tokens.ui
                font.pixelSize: 11
                font.weight: pill.active ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: pill.sublabel !== ""
                text: pill.sublabel
                color: pill.active ? pill.activeColor : home.theme.muted
                font.family: Tokens.mono
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: pma
            anchors.fill: parent
            enabled: pill.enabledControl
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: pill.triggered()
        }
    }

    component QuickSlider: Rectangle {
        id: qs
        property string icon: ""
        property string label: ""
        property int value: 50
        property int minValue: 0
        property int maxValue: 100
        property bool muted: false
        property bool interactive: true
        signal iconClicked()
        signal valuePicked(int v)

        height: 44
        radius: 13
        color: home.theme.card
        border.width: 1
        border.color: home.theme.border
        opacity: interactive ? 1.0 : 0.45

        readonly property real frac: Math.max(0, Math.min(1,
            (value - minValue) / Math.max(1, maxValue - minValue)))

        // Smooth active progress fill inside pill
        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.round(parent.width * qs.frac)
                radius: qs.radius
                color: qs.muted
                    ? Qt.rgba(home.theme.muted.r, home.theme.muted.g, home.theme.muted.b, 0.16)
                    : Qt.rgba(home.theme.accent.r, home.theme.accent.g, home.theme.accent.b, 0.24)
                Behavior on width {
                    enabled: home.anim && !dragArea.pressed
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Item {
                width: 22
                height: 22
                anchors.verticalCenter: parent.verticalCenter
                NotchIcon {
                    anchors.centerIn: parent
                    text: qs.icon
                    font.pixelSize: 17
                    fill: qs.muted ? 0 : 1
                    color: qs.muted ? home.theme.muted : home.theme.ink
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: qs.iconClicked()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qs.label
                color: home.theme.ink
                font.family: Tokens.ui
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: qs.muted ? I18n.tr("Muted") : (qs.value + "%")
            color: qs.muted ? home.theme.muted : home.theme.ink
            font.family: Tokens.mono
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: dragArea
            anchors.left: parent.left
            anchors.leftMargin: 36
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            enabled: qs.interactive
            cursorShape: Qt.PointingHandCursor
            function updateFromX(mx) {
                var ratio = Math.max(0, Math.min(1, mx / Math.max(1, width)));
                var v = Math.round(qs.minValue + ratio * (qs.maxValue - qs.minValue));
                qs.valuePicked(v);
            }
            onPressed: e => updateFromX(e.x)
            onPositionChanged: e => { if (pressed) updateFromX(e.x); }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 10

        // Top row: 4 quick toggles
        Row {
            width: parent.width
            spacing: 8
            readonly property real tileW: Math.floor((width - 24) / 4)

            ControlPill {
                width: parent.tileW
                icon: Network.wifiRadio ? "wifi" : "wifi_off"
                label: I18n.tr("Wi-Fi")
                sublabel: Network.wifiRadio
                    ? (Network.activeSsid !== "" ? Network.activeSsid : I18n.tr("On"))
                    : I18n.tr("Off")
                active: Network.wifiRadio
                enabledControl: Network.wifiPresent
                onTriggered: Network.setWifiEnabled(!Network.wifiRadio)
            }

            ControlPill {
                width: parent.tileW
                icon: BluetoothPower.enabled
                    ? (home.btConnectedCount > 0 ? "bluetooth_connected" : "bluetooth")
                    : "bluetooth_disabled"
                label: I18n.tr("Bluetooth")
                sublabel: BluetoothPower.enabled
                    ? (home.btConnectedCount > 0 ? I18n.tr("%1 paired").arg(home.btConnectedCount) : I18n.tr("On"))
                    : I18n.tr("Off")
                active: BluetoothPower.enabled
                enabledControl: BluetoothPower.available
                onTriggered: BluetoothPower.toggle()
            }

            ControlPill {
                width: parent.tileW
                icon: Flags.dnd ? "dark_mode" : "notifications_active"
                label: I18n.tr("Focus")
                sublabel: Flags.dnd ? I18n.tr("Silenced") : I18n.tr("Normal")
                active: Flags.dnd
                onTriggered: Flags.dnd = !Flags.dnd
            }

            ControlPill {
                width: parent.tileW
                icon: "local_cafe"
                label: I18n.tr("Coffee")
                sublabel: Flags.keepAwake ? I18n.tr("Awake") : I18n.tr("Idle lock")
                active: Flags.keepAwake
                activeColor: home.theme.warning
                onTriggered: Flags.keepAwake = !Flags.keepAwake
            }
        }

        // Bottom row: Display & Sound sliders
        Row {
            width: parent.width
            spacing: 8
            readonly property real sliderW: Math.floor((width - 8) / 2)

            QuickSlider {
                width: parent.sliderW
                icon: "light_mode"
                label: I18n.tr("Display")
                value: home.displayPct
                minValue: 1
                maxValue: 100
                interactive: home.hasBacklight
                onValuePicked: v => Devices.setBacklight(v)
            }

            QuickSlider {
                width: parent.sliderW
                icon: home.soundMuted || home.soundPct === 0 ? "volume_off" : "volume_up"
                label: I18n.tr("Sound")
                value: Math.min(100, home.soundPct)
                minValue: 0
                maxValue: 100
                muted: home.soundMuted
                interactive: home.sinkAudio !== null
                onIconClicked: {
                    if (home.sinkAudio)
                        home.sinkAudio.muted = !home.sinkAudio.muted;
                }
                onValuePicked: v => {
                    if (home.sinkAudio) {
                        home.sinkAudio.muted = false;
                        home.sinkAudio.volume = Math.max(0, Math.min(1, v / 100));
                    }
                }
            }
        }
    }
}
