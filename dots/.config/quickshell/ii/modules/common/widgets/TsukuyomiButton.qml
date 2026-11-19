import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.common

Button {
    id: root
    property string glyph: ""
    property string description: text
    property bool selected: false
    property bool flatSurface: false
    property real cornerRadius: 8
    property real minimumHeight: 28
    property real glyphSize: 16
    property bool tooltipAbove: false
    hoverEnabled: true
    padding: 6
    leftPadding: text.length > 0 ? 9 : 6
    rightPadding: leftPadding
    implicitWidth: Math.max(28, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(minimumHeight, implicitContentHeight + topPadding + bottomPadding)
    Accessible.name: description
    Loader {
        active: root.hovered && !root.selected && root.text.length === 0
            && root.description.length > 0 && root.QsWindow.window !== null
        sourceComponent: TsukuyomiTooltip {
            owner: root
            text: root.description
            above: root.tooltipAbove
        }
    }

    background: Rectangle {
        radius: root.cornerRadius
        color: root.selected ? TsukuyomiStyle.selection
            : (root.pressed || root.hovered || !root.flatSurface ? TsukuyomiStyle.raised : "transparent")
        border.width: root.visualFocus ? 2 : 0
        border.color: TsukuyomiStyle.foreground
        opacity: root.enabled ? 1 : 0.4
    }

    contentItem: RowLayout {
        spacing: 5
        opacity: root.enabled ? 1 : 0.42
        MaterialSymbol {
            visible: root.glyph.length > 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            text: root.glyph
            iconSize: root.glyphSize
            color: TsukuyomiStyle.foreground
        }
        Text {
            visible: root.text.length > 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            text: root.text
            color: TsukuyomiStyle.foreground
            font.family: Appearance.font.family.main
            font.pixelSize: 13
        }
    }
}
