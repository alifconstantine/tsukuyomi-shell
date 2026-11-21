import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: row
    property string section
    property string label
    property string detail
    property bool current: false
    signal activated()

    implicitHeight: Tokens.px(36)
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: detail === "" ? label : label + ", " + detail
    Accessible.onPressAction: activated()
    Keys.onReturnPressed: activated()
    Keys.onSpacePressed: activated()

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        radius: Tokens.px(8)
        color: row.current ? Style.selected : (hover.hovered ? Style.hover : "transparent")
        border.color: Style.accent
        border.width: row.activeFocus ? 2 : 0
    }
    Text {
        id: icon
        anchors { left: parent.left; leftMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
        font.family: Style.icons
        font.pixelSize: Tokens.px(18)
        color: row.current ? Style.accent : Style.secondary
        text: Style.sectionIcon(row.section)
    }
    Text {
        anchors { left: icon.right; leftMargin: Tokens.s2; right: parent.right; rightMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
        color: row.current ? Style.text : Style.secondary
        font.family: Tokens.ui
        font.pixelSize: Tokens.fBody
        font.weight: row.current ? Font.DemiBold : Font.Normal
        text: row.label
        elide: Text.ElideRight
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: row.activated() }
}
