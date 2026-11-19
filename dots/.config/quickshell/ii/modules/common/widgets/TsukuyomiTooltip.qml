import QtQuick
import Quickshell
import qs.modules.common

PopupWindow {
    id: root
    required property Item owner
    required property string text
    property bool above: false
    visible: false
    color: "transparent"
    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 10
    anchor.item: owner
    anchor.edges: above ? Edges.Top : Edges.Bottom
    anchor.gravity: anchor.edges
    mask: Region {}

    Timer {
        running: true
        interval: 450
        onTriggered: root.visible = true
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: TsukuyomiStyle.surface
        border.color: TsukuyomiStyle.border
    }
    Text {
        id: label
        anchors.centerIn: parent
        color: TsukuyomiStyle.foreground
        text: root.text
        font.family: Appearance.font.family.main
        font.pixelSize: 12
    }
}
