pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.common
import qs.services

RowLayout {
    id: root
    Layout.fillWidth: true
    spacing: 11
    readonly property color line: TsukuyomiStyle.border

    component Caption: Text {
        color: TsukuyomiStyle.muted
        font.family: Appearance.font.family.main
        font.pixelSize: 10
        font.letterSpacing: 0.5
    }

    component Meter: ColumnLayout {
        id: meter
        required property string label
        required property string value
        required property real fraction
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            Caption {
                Layout.fillWidth: true
                text: meter.label
            }
            Text {
                text: meter.value
                color: TsukuyomiStyle.foreground
                font.family: Appearance.font.family.main
                font.pixelSize: 11
                font.features: ({tnum: 1})
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 3
            radius: 2
            color: root.line
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, meter.fraction))
                height: parent.height
                radius: parent.radius
                color: TsukuyomiStyle.muted
            }
        }
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignTop
        spacing: 4
        Caption { text: "CPU" }
        Text {
            color: TsukuyomiStyle.foreground
            text: ResourceUsage.cpuReady ? Math.round(ResourceUsage.cpuUsage * 100) + "%" : "–"
            font.family: Appearance.font.family.main
            font.pixelSize: 25
            font.features: ({tnum: 1})
        }
        GridLayout {
            columns: 8
            columnSpacing: 3
            rowSpacing: 3
            Repeater {
                model: ResourceUsage.coreUsage
                Rectangle {
                    required property real modelData
                    implicitWidth: 5
                    implicitHeight: 9
                    radius: 3
                    color: Qt.tint(root.line, Qt.rgba(TsukuyomiStyle.foreground.r, TsukuyomiStyle.foreground.g,
                        TsukuyomiStyle.foreground.b, Math.max(0.1, modelData)))
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 44
        Layout.alignment: Qt.AlignTop
        spacing: 6
        Caption {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Translation.tr("Activity") + " · CPU / RAM"
        }
        Rectangle {
            id: chart
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            clip: true
            color: "transparent"
            border.color: root.line
            radius: 5

            function points(values) {
                const visibleValues = values.slice(-24);
                return visibleValues.map((value, index) => Qt.point(
                    2 + (width - 4) * index / Math.max(1, visibleValues.length - 1),
                    2 + (height - 4) * (1 - Math.max(0, Math.min(1, value)))));
            }

            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: 1
                    y: (chart.height - 1) * (index + 1) / 4
                    width: chart.width - 2
                    height: 1
                    color: root.line
                    opacity: 0.35
                }
            }
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeWidth: 1
                    strokeColor: TsukuyomiStyle.muted
                    strokeStyle: ShapePath.DashLine
                    fillColor: "transparent"
                    PathPolyline { path: chart.points(ResourceUsage.memoryUsageHistory) }
                }
                ShapePath {
                    strokeWidth: 1.4
                    strokeColor: TsukuyomiStyle.foreground
                    fillColor: "transparent"
                    PathPolyline { path: chart.points(ResourceUsage.cpuUsageHistory) }
                }
            }
        }
    }

    ColumnLayout {
        Layout.preferredWidth: root.width >= 340 ? 132 : 98
        Layout.alignment: Qt.AlignTop
        spacing: 7
        Meter {
            label: "RAM"
            value: ResourceUsage.memoryTotal > 1 ? ResourceUsage.kbToGbString(ResourceUsage.memoryUsed) : "–"
            fraction: ResourceUsage.memoryTotal > 1 ? ResourceUsage.memoryUsedPercentage : 0
        }
        Meter {
            visible: ResourceUsage.swapTotal > 0
            label: Translation.tr("Swap")
            value: ResourceUsage.kbToGbString(ResourceUsage.swapUsed)
            fraction: ResourceUsage.swapUsedPercentage
        }
        Meter {
            visible: Battery.available
            label: Translation.tr("Battery")
            value: Math.round(Battery.percentage * 100) + "%"
            fraction: Battery.percentage
        }
    }
}
