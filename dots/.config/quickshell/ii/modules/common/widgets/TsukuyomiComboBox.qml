pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.common

ComboBox {
    id: root
    implicitWidth: 148
    implicitHeight: 33
    leftPadding: 10
    rightPadding: 28
    font.family: Appearance.font.family.main
    font.pixelSize: 13

    contentItem: Text {
        text: root.displayText
        color: TsukuyomiStyle.foreground
        font: root.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: MaterialSymbol {
        x: root.width - width - 8
        y: (root.height - height) / 2
        text: root.popup.visible ? "expand_less" : "expand_more"
        iconSize: 16
        color: TsukuyomiStyle.foreground
    }
    background: Rectangle {
        radius: 9
        color: TsukuyomiStyle.raised
        border.width: root.visualFocus ? 2 : 1
        border.color: root.visualFocus ? TsukuyomiStyle.foreground : TsukuyomiStyle.border
    }
    delegate: ItemDelegate {
        id: choice
        required property int index
        required property string modelData
        width: root.width - 8
        height: 32
        highlighted: root.highlightedIndex === index
        text: modelData
        contentItem: Text {
            text: (choice.index === root.currentIndex ? "✓  " : "    ") + choice.text
            color: TsukuyomiStyle.foreground
            font: root.font
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 6
            color: choice.highlighted || choice.hovered ? TsukuyomiStyle.selection : "transparent"
        }
    }
    popup: Popup {
        y: root.height + 4
        width: root.width
        padding: 4
        implicitHeight: contentItem.implicitHeight + padding * 2
        contentItem: ListView {
            implicitHeight: contentHeight
            clip: true
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
        }
        background: Rectangle {
            radius: 10
            color: TsukuyomiStyle.surface
            border.color: TsukuyomiStyle.border
        }
    }
}
