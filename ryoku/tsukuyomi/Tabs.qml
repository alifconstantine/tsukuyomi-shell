import QtQuick
import Ryoku.Ui.Singletons

Flow {
    id: tabs
    property var options: []
    property string current
    signal chose(string option)

    spacing: Tokens.s1

    Repeater {
        model: tabs.options

        delegate: Rectangle {
            id: tab
            required property string modelData
            readonly property bool selected: tabs.current === modelData
            width: Math.min(tabs.width, label.implicitWidth + Tokens.s5)
            height: Tokens.px(34)
            radius: Tokens.px(8)
            color: selected ? Style.selected : (hover.hovered ? Style.hover : "transparent")
            border.color: Style.accent
            border.width: activeFocus ? 2 : 0
            activeFocusOnTab: true
            Accessible.role: Accessible.PageTab
            Accessible.name: label.text
            Accessible.selected: selected
            Accessible.onPressAction: tabs.chose(modelData)
            Keys.onReturnPressed: tabs.chose(modelData)
            Keys.onSpacePressed: tabs.chose(modelData)

            Text {
                id: label
                anchors.fill: parent
                anchors.leftMargin: Tokens.s2
                anchors.rightMargin: Tokens.s2
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: I18n.tr(tab.modelData)
                color: tab.selected ? Style.text : Style.secondary
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall
                font.weight: tab.selected ? Font.DemiBold : Font.Normal
            }
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: tabs.chose(tab.modelData) }
        }
    }
}
