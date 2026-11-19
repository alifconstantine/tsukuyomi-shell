pragma ComponentBehavior: Bound

import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root
    readonly property var options: Config.options.tsukuyomi
    readonly property var monitor: Hyprland.monitorFor(QsWindow.window?.screen)
    readonly property var brightness: Brightness.getMonitorForScreen(QsWindow.window?.screen)
    readonly property real sideBudget: Math.max(0, (width - clock.width) / 2 - 18)
    readonly property int activeWorkspace: monitor?.activeWorkspace?.id ?? 1
    readonly property int groupSize: Math.max(1, Config.options.bar.workspaces.shown)
    readonly property var workspaceIds: {
        const first = Math.floor((activeWorkspace - 1) / groupSize) * groupSize + 1;
        const initial = Array.from({length: Math.min(3, groupSize)}, (_, i) => first + i);
        const occupied = Hyprland.workspaces.values
            .filter(ws => ws.id >= first && ws.id < first + groupSize && ws.monitor === root.monitor)
            .map(ws => ws.id);
        const count = Math.max(1, Math.floor((sideBudget - 38) / 24));
        return Array.from(new Set([activeWorkspace, ...initial, ...occupied]))
            .slice(0, count).sort((a, b) => a - b);
    }
    readonly property var catalogue: ({
        network: [Translation.tr("Network"), Network.materialSymbol],
        volume: [Translation.tr("Volume"), Audio.sink?.audio?.muted ? "volume_off" : "volume_up"],
        battery: [Translation.tr("Battery"), Battery.isCharging ? "battery_charging_full" : "battery_std"],
        brightness: [Translation.tr("Brightness"), "light_mode"],
        bluetooth: [Translation.tr("Bluetooth"), "bluetooth"],
        power: [Translation.tr("Power Profile"), "bolt"],
        media: [Translation.tr("Now Playing"), "music_note"],
        notifications: [Translation.tr("Notifications"), "notifications"],
        keyboard: [Translation.tr("Keyboard Layout"), "keyboard"],
        cpu: [Translation.tr("CPU"), "developer_board"],
        ram: [Translation.tr("Memory"), "memory"]
    })
    readonly property var activeIndicators: Array.from(new Set(options.indicators)).filter(key => {
        switch (key) {
        case "volume": return Audio.ready;
        case "battery": return Battery.available;
        case "brightness": return root.brightness?.ready ?? false;
        case "bluetooth": return BluetoothStatus.available;
        case "media": return MprisController.activePlayer !== null;
        case "keyboard": return HyprlandXkb.currentLayoutCode.length > 0;
        default: return key in root.catalogue;
        }
    })
    readonly property int capacity: Math.max(0, Math.floor((sideBudget - 10) / 58))
    readonly property bool overflow: activeIndicators.length > capacity
    readonly property var shownIndicators: activeIndicators.slice(0, Math.max(0, capacity - (overflow ? 1 : 0)))
    readonly property Item leftPill: left
    readonly property Item clockPill: clock
    readonly property Item rightPill: right
    property string panel: ""

    function statusValue(key) {
        switch (key) {
        case "volume": return Math.round(Audio.value * 100) + "%";
        case "battery": return Math.round(Battery.percentage * 100) + "%";
        case "brightness": return Math.round((brightness?.brightness ?? 0) * 100) + "%";
        case "notifications": return Notifications.unread > 0 ? String(Notifications.unread) : "";
        case "keyboard": return HyprlandXkb.currentLayoutCode.toUpperCase();
        case "cpu": return Math.round(ResourceUsage.cpuUsage * 100) + "%";
        case "ram": return Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%";
        default: return "";
        }
    }

    function togglePanel(name) {
        root.panel = root.panel === name ? "" : name;
    }

    TsukuyomiSurface {
        id: left
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: leftRow.implicitWidth + 10
        height: 36
        gradient: null
        color: TsukuyomiStyle.surface
        RowLayout {
            id: leftRow
            anchors.centerIn: parent
            spacing: 0
            TsukuyomiButton {
                flatSurface: true
                description: Translation.tr("System Controls")
                selected: root.panel === "controls" || root.panel === "customize"
                onClicked: {
                    if (root.panel === "customize") root.panel = "";
                    else root.togglePanel("controls");
                }
                contentItem: Item {
                    implicitWidth: 18
                    implicitHeight: 18
                    Text {
                        visible: root.options.logo === "moon"
                        anchors.centerIn: parent
                        text: "月"
                        font.pixelSize: 17
                        color: TsukuyomiStyle.foreground
                    }
                    Image {
                        id: logoImage
                        visible: false
                        anchors.fill: parent
                        source: root.options.logo === "tux" ? Quickshell.shellPath("assets/icons/linux-symbolic.svg")
                            : Quickshell.shellPath("assets/icons/arch-symbolic.svg")
                    }
                    ColorOverlay {
                        visible: root.options.logo !== "moon"
                        anchors.fill: logoImage
                        source: logoImage
                        color: TsukuyomiStyle.foreground
                    }
                }
            }
            Rectangle {
                implicitWidth: 1
                implicitHeight: 16
                color: TsukuyomiStyle.border
            }
            Repeater {
                model: root.workspaceIds
                TsukuyomiButton {
                    id: workspace
                    required property int modelData
                    flatSurface: true
                    description: Translation.tr("Workspace %1").arg(modelData)
                    implicitWidth: 24
                    onClicked: Hyprland.dispatch(`hl.dsp.focus({workspace = ${modelData}})`)
                    contentItem: Item {
                        implicitWidth: 12
                        implicitHeight: 12
                        Rectangle {
                            anchors.centerIn: parent
                            width: workspace.modelData === root.activeWorkspace ? 13 : 5
                            height: 5
                            radius: 3
                            color: workspace.modelData === root.activeWorkspace ? TsukuyomiStyle.foreground : TsukuyomiStyle.muted
                        }
                    }
                }
            }
        }
    }

    TsukuyomiSurface {
        id: clock
        anchors.centerIn: parent
        width: timeButton.implicitWidth + 8
        height: 36
        gradient: null
        color: TsukuyomiStyle.surface
        TsukuyomiButton {
            id: timeButton
            anchors.centerIn: parent
            flatSurface: true
            glyph: "expand_more"
            text: DateTime.time
            selected: root.panel === "clock"
            onClicked: root.togglePanel("clock")
        }
    }

    TsukuyomiSurface {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: indicators.implicitWidth + 10
        height: 36
        visible: root.activeIndicators.length > 0
        gradient: null
        color: TsukuyomiStyle.surface
        RowLayout {
            id: indicators
            anchors.centerIn: parent
            spacing: 0
            Repeater {
                model: root.shownIndicators
                TsukuyomiButton {
                    required property string modelData
                    flatSurface: true
                    glyph: root.catalogue[modelData][1]
                    description: text.length > 0 ? root.catalogue[modelData][0] + " " + text : root.catalogue[modelData][0]
                    text: root.statusValue(modelData)
                    leftPadding: 5
                    rightPadding: 5
                    onClicked: root.togglePanel("status")
                }
            }
            TsukuyomiButton {
                visible: root.overflow
                flatSurface: true
                glyph: "more_horiz"
                description: Translation.tr("More Indicators")
                onClicked: root.togglePanel("status")
            }
        }
    }

    Loader {
        active: root.panel !== "" && root.QsWindow.window !== null
        sourceComponent: TsukuyomiBarPanel {
            bar: root
        }
    }
}
