import QtQuick
import Quickshell
import shell.services
import Ryoku.Ui.Singletons

// Home tab: quick controls directly available upon opening the Notch.
// Top row: Wi-Fi, Bluetooth, Focus (DND), Coffee (Keep Awake).
// Bottom row: Display brightness slider + Sound volume slider.
Item {
    id: home

    property var root: null
    property var theme: _fallbackTheme
    NotchTheme { id: _fallbackTheme; root: null }
    readonly property bool anim: !Perf.reduceMotion

    Component.onCompleted: Devices.startProbes("notch-home")
    Component.onDestruction: Devices.stopProbes("notch-home")

    readonly property var sink: Audio.sink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property bool soundMuted: sinkAudio ? sinkAudio.muted : false
    readonly property int soundPct: sinkAudio ? Math.round(Math.max(0, Math.min(1.5, sinkAudio.volume)) * 100) : 0

    readonly property var source: Audio.source
    readonly property var sourceAudio: source ? source.audio : null
    readonly property bool micMuted: sourceAudio ? sourceAudio.muted : false

    readonly property bool hasBacklight: Devices.backlightAvailable
    readonly property int displayPct: hasBacklight ? Math.max(1, Devices.backlightPct) : 100

    readonly property var activeTileIds: {
        var raw = NotchConfig.homeTiles;
        return (raw && raw.length > 0) ? raw : ["wifi", "bluetooth", "focus", "coffee"];
    }

    function tileProps(tileId) {
        switch (tileId) {
        case "wifi":
            return {
                icon: Network.wifiRadio ? "wifi" : "wifi_off",
                label: I18n.tr("Wi-Fi"),
                active: Network.wifiRadio,
                enabled: Network.wifiPresent,
                activeColor: home.theme.accent
            };
        case "bluetooth":
            return {
                icon: BluetoothPower.enabled
                    ? (home.btConnectedCount > 0 ? "bluetooth_connected" : "bluetooth")
                    : "bluetooth_disabled",
                label: I18n.tr("Bluetooth"),
                active: BluetoothPower.enabled,
                enabled: BluetoothPower.available,
                activeColor: home.theme.accent
            };
        case "focus":
            return {
                icon: Flags.dnd ? "dark_mode" : "notifications_active",
                label: I18n.tr("Focus"),
                active: Flags.dnd,
                enabled: true,
                activeColor: home.theme.accent
            };
        case "coffee":
            return {
                icon: "local_cafe",
                label: I18n.tr("Coffee"),
                active: Flags.keepAwake,
                enabled: true,
                activeColor: home.theme.warning
            };
        case "nightlight":
            return {
                icon: "bedtime",
                label: I18n.tr("Night"),
                active: Nightlight.on,
                enabled: true,
                activeColor: home.theme.warning
            };
        case "mic":
            return {
                icon: home.micMuted ? "mic_off" : "mic",
                label: I18n.tr("Mic"),
                active: !home.micMuted,
                enabled: home.sourceAudio !== null,
                activeColor: home.theme.accent
            };
        case "gamemode":
            return {
                icon: "sports_esports",
                label: I18n.tr("Game"),
                active: Flags.gameMode,
                enabled: true,
                activeColor: home.theme.accent
            };
        case "screenshot":
            return {
                icon: "screenshot_region",
                label: I18n.tr("Capture"),
                active: Capture.selecting !== "",
                enabled: true,
                activeColor: home.theme.accent
            };
        default:
            return { icon: "tune", label: tileId, active: false, enabled: false, activeColor: home.theme.accent };
        }
    }

    function triggerTile(tileId) {
        switch (tileId) {
        case "wifi": Network.setWifiEnabled(!Network.wifiRadio); break;
        case "bluetooth": BluetoothPower.toggle(); break;
        case "focus": Flags.dnd = !Flags.dnd; break;
        case "coffee": Flags.keepAwake = !Flags.keepAwake; break;
        case "nightlight": Nightlight.toggle(); break;
        case "mic":
            if (home.sourceAudio) home.sourceAudio.muted = !home.sourceAudio.muted;
            break;
        case "gamemode": Flags.gameMode = !Flags.gameMode; break;
        case "screenshot": Capture.shoot("region"); break;
        }
    }

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
        property bool active: false
        property bool enabledControl: true
        property color activeColor: home.theme.accent
        signal triggered()

        height: 48
        radius: 13
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
            width: parent.width - 12
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
            font.family: theme.monoFont
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

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: homeCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: homeCol
            width: parent.width
            spacing: 8

            // Dynamic Quick Tiles grid (4 per row; clean uniform 48px pills, no text wrapping bloat)
            Flow {
                id: tileFlow
                width: parent.width
                spacing: 8
                readonly property int count: home.activeTileIds.length
                readonly property int cols: count <= 4 ? Math.max(1, count) : 4
                readonly property real tileW: Math.floor((width - (cols - 1) * 8) / cols)

                Repeater {
                    model: home.activeTileIds
                    delegate: ControlPill {
                        required property string modelData
                        readonly property var info: home.tileProps(modelData)
                        width: tileFlow.tileW
                        icon: info.icon
                        label: info.label
                        active: info.active
                        enabledControl: info.enabled
                        activeColor: info.activeColor
                        onTriggered: home.triggerTile(modelData)
                    }
                }
            }

            // Bottom row: Display & Sound sliders
            Row {
                width: parent.width
                spacing: 8
                readonly property real sliderW: Math.floor((width - 8) / 2)

                QuickSlider {
                    width: parent.sliderW
                    height: 42
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
                    height: 42
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
}
