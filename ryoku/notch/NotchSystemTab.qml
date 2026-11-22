import QtQuick
import Quickshell
import Quickshell.Io
import shell.services
import Ryoku.Ui.Singletons

// System tab: live telemetry summary (CPU, RAM, GPU, Thermals, Storage)
// with animated bars and a Quick Action to launch Tsukuyomi Monitor (ryomanager).
Item {
    id: sys

    property var root: null
    property var theme: _fallbackTheme
    NotchTheme { id: _fallbackTheme; root: null }
    readonly property bool anim: !Perf.reduceMotion

    Component.onCompleted: {
        if (sys.root && sys.root.notchSystemActive !== undefined)
            sys.root.notchSystemActive = true;
        droidStatusProc.running = true;
    }

    property bool droidActive: false

    Process {
        id: droidStatusProc
        command: ["tsukuyomi-droid", "status"]
        stdout: StdioCollector { id: droidOut }
        onExited: code => {
            if (code === 0) {
                try {
                    const st = JSON.parse(droidOut.text);
                    sys.droidActive = !!(st.sessionRunning || st.containerActive);
                } catch (e) {}
            }
        }
    }

    Process {
        id: droidSleepProc
        command: ["tsukuyomi-droid", "sleep"]
        onExited: droidStatusProc.running = true
    }
    Component.onDestruction: {
        if (sys.root && sys.root.notchSystemActive !== undefined)
            sys.root.notchSystemActive = false;
    }

    readonly property int cpuPct: sys.root ? sys.root.cpuPercent : 0
    readonly property int memPct: sys.root ? sys.root.systemMemPercent : 0
    readonly property real memUsed: sys.root ? sys.root.systemMemUsedGiB : 0
    readonly property real memTotal: sys.root ? sys.root.systemMemTotalGiB : 0
    readonly property int gpuPct: sys.root ? sys.root.gpuPercent : 0
    readonly property int gpuTemp: sys.root && sys.root.gpuTemperatureC ? sys.root.gpuTemperatureC : 0
    readonly property int cpuTemp: sys.root ? sys.root.cpuTemperatureC : 0
    readonly property int diskPct: sys.root ? sys.root.storagePercent : 0
    readonly property real diskUsed: sys.root && sys.root.storageUsedGiB ? sys.root.storageUsedGiB : 0
    readonly property real diskTotal: sys.root && sys.root.storageTotalGiB ? sys.root.storageTotalGiB : 0

    component MetricCard: Rectangle {
        id: mc
        property string icon: ""
        property string label: ""
        property string valueText: ""
        property string subText: ""
        property real frac: 0
        property color barColor: sys.theme.accent

        height: 62
        radius: 12
        color: sys.theme.card
        border.width: 1
        border.color: sys.theme.border

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5

            Row {
                width: parent.width
                spacing: 5
                NotchIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: mc.icon
                    font.pixelSize: 14
                    color: mc.barColor
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: mc.label
                    color: sys.theme.muted
                    font.family: Tokens.ui
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
                Item { width: 1; height: 1 }
            }

            Row {
                width: parent.width
                spacing: 6
                Text {
                    text: mc.valueText
                    color: sys.theme.ink
                    font.family: theme.monoFont
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.baseline: parent.children[0].baseline
                    text: mc.subText
                    color: sys.theme.muted
                    font.family: theme.monoFont
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                width: parent.width
                height: 3
                radius: 1.5
                color: Qt.rgba(sys.theme.ink.r, sys.theme.ink.g, sys.theme.ink.b, 0.12)

                Rectangle {
                    width: Math.round(parent.width * Math.max(0, Math.min(1, mc.frac)))
                    height: parent.height
                    radius: 1.5
                    color: mc.barColor
                    Behavior on width {
                        enabled: sys.anim
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: sysCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: sysCol
            width: parent.width
            spacing: 8

        // Top row: CPU · RAM · GPU
        Row {
            width: parent.width
            spacing: 8
            readonly property real col3W: Math.floor((width - 16) / 3)

            MetricCard {
                width: parent.col3W
                icon: "memory"
                label: I18n.tr("CPU")
                valueText: sys.cpuPct + "%"
                subText: sys.cpuTemp > 0 ? (sys.cpuTemp + "°C") : ""
                frac: sys.cpuPct / 100
                barColor: sys.cpuPct >= 85 ? sys.theme.danger : sys.theme.accent
            }

            MetricCard {
                width: parent.col3W
                icon: "straighten"
                label: I18n.tr("RAM")
                valueText: sys.memPct + "%"
                subText: sys.memTotal > 0 ? (sys.memUsed.toFixed(1) + "/" + sys.memTotal.toFixed(0) + "G") : ""
                frac: sys.memPct / 100
                barColor: sys.memPct >= 85 ? sys.theme.danger : sys.theme.success
            }

            MetricCard {
                width: parent.col3W
                icon: "developer_board"
                label: I18n.tr("GPU")
                valueText: sys.gpuPct + "%"
                subText: sys.gpuTemp > 0 ? (sys.gpuTemp + "°C") : ""
                frac: sys.gpuPct / 100
                barColor: sys.gpuPct >= 85 ? sys.theme.danger : sys.theme.accent
            }
        }

        // Bottom row: Temp · Storage · Open Monitor Quick Action
        Row {
            width: parent.width
            spacing: 8
            readonly property real col3W: Math.floor((width - 16) / 3)

            MetricCard {
                width: parent.col3W
                icon: "thermostat"
                label: I18n.tr("Thermals")
                valueText: sys.cpuTemp > 0 ? (sys.cpuTemp + "°C") : "--"
                subText: sys.cpuTemp >= 85 ? I18n.tr("Hot") : (sys.cpuTemp > 0 ? I18n.tr("Normal") : I18n.tr("No sensor"))
                frac: Math.min(1, sys.cpuTemp / 100)
                barColor: sys.cpuTemp >= 85 ? sys.theme.danger : (sys.cpuTemp >= 70 ? sys.theme.warning : sys.theme.success)
            }

            MetricCard {
                width: parent.col3W
                icon: "hard_drive"
                label: I18n.tr("Storage")
                valueText: sys.diskPct + "%"
                subText: sys.diskTotal > 0 ? (sys.diskUsed.toFixed(0) + "/" + sys.diskTotal.toFixed(0) + "G") : ""
                frac: sys.diskPct / 100
                barColor: sys.diskPct >= 90 ? sys.theme.danger : sys.theme.accent
            }

            // Quick Action to Tsukuyomi Monitor
            Rectangle {
                width: parent.col3W
                height: 62
                radius: 12
                color: monMa.containsMouse
                    ? Qt.rgba(sys.theme.accent.r, sys.theme.accent.g, sys.theme.accent.b, 0.22)
                    : sys.theme.card
                border.width: 1
                border.color: monMa.containsMouse ? sys.theme.accent : sys.theme.border
                scale: monMa.pressed ? 0.96 : 1.0

                Behavior on color { enabled: sys.anim; ColorAnimation { duration: 140 } }
                Behavior on border.color { enabled: sys.anim; ColorAnimation { duration: 140 } }
                Behavior on scale { enabled: sys.anim; NumberAnimation { duration: 100 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    NotchIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "open_in_new"
                        font.pixelSize: 18
                        color: monMa.containsMouse ? sys.theme.accent : sys.theme.ink
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.tr("Open Monitor")
                        color: sys.theme.ink
                        font.family: Tokens.ui
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: monMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Spawn.runApp(["ryomanager"], { label: "ryomanager" });
                        if (sys.root) sys.root.dashboardVisible = false;
                    }
                }
            }
        }

        // Quick Compat Runtime Bar (Android status/sleep/resize + Install App)
        Rectangle {
            width: parent.width
            height: 36
            radius: 10
            color: sys.theme.card
            border.width: 1
            border.color: sys.theme.border

            Row {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 8 }
                spacing: 6

                NotchIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "phone_android"
                    font.pixelSize: 15
                    color: sys.droidActive ? sys.theme.success : sys.theme.muted
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 210
                    elide: Text.ElideRight
                    text: sys.droidActive ? I18n.tr("Android: Running") : I18n.tr("Android: Sleeping")
                    color: sys.theme.ink
                    font.family: Tokens.ui
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: sys.droidActive
                    width: sleepTxt.implicitWidth + 14; height: 22; radius: 7
                    color: sleepMa.containsMouse ? sys.theme.cardHover : "transparent"
                    border.width: 1; border.color: sys.theme.border
                    Text { id: sleepTxt; anchors.centerIn: parent; text: I18n.tr("Sleep"); color: sys.theme.ink; font.family: Tokens.ui; font.pixelSize: 9; font.weight: Font.DemiBold }
                    MouseArea { id: sleepMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (!droidSleepProc.running) droidSleepProc.running = true }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: sys.droidActive
                    width: resTxt.implicitWidth + 14; height: 22; radius: 7
                    color: resMa.containsMouse ? sys.theme.cardHover : "transparent"
                    border.width: 1; border.color: sys.theme.border
                    Text { id: resTxt; anchors.centerIn: parent; text: I18n.tr("Resize"); color: sys.theme.ink; font.family: Tokens.ui; font.pixelSize: 9; font.weight: Font.DemiBold }
                    MouseArea { id: resMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["/usr/lib/tsukuyomi/droid-cycle-resize"]) }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: instTxt.implicitWidth + 14; height: 22; radius: 7
                    color: instMa.containsMouse ? sys.theme.cardHover : Qt.rgba(sys.theme.accent.r, sys.theme.accent.g, sys.theme.accent.b, 0.14)
                    border.width: 1; border.color: sys.theme.accent
                    Text { id: instTxt; anchors.centerIn: parent; text: I18n.tr("Install Win"); color: sys.theme.accent; font.family: Tokens.ui; font.pixelSize: 9; font.weight: Font.DemiBold }
                    MouseArea { id: instMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached(["tsukuyomi-win-installer"]); if (sys.root) sys.root.dashboardVisible = false; } }
                }
            }
        }
        }
    }
}
