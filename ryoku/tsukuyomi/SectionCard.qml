import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: card
    property string title
    property string kana
    property string summary
    property bool collapsible: true
    property bool expanded: true
    default property alias content: rows.data

    implicitHeight: heading.height + (expanded ? rows.implicitHeight : 0)
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Tokens.px(12)
        color: Style.panel
        border.color: Style.line
        border.width: 1
    }

    Item {
        id: heading
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: Tokens.px(42)
        activeFocusOnTab: card.collapsible
        Accessible.role: Accessible.Button
        Accessible.name: card.title
        Accessible.description: !card.expanded ? card.summary : ""
        Accessible.onPressAction: if (card.collapsible) card.expanded = !card.expanded
        Keys.onReturnPressed: if (card.collapsible) card.expanded = !card.expanded
        Keys.onSpacePressed: if (card.collapsible) card.expanded = !card.expanded

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            visible: heading.activeFocus
            color: "transparent"
            radius: Tokens.px(10)
            border.color: Style.accent
            border.width: 2
        }
        Text {
            anchors { left: parent.left; leftMargin: Tokens.s4; right: arrow.left; rightMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
            text: card.title
            color: Style.text
            elide: Text.ElideRight
            font.family: Tokens.ui
            font.pixelSize: Tokens.fBody
            font.weight: Font.DemiBold
        }
        Text {
            id: arrow
            anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
            visible: card.collapsible
            text: card.expanded ? "\ue5cf" : "\ue5cc"
            color: Style.secondary
            font.family: Style.icons
            font.pixelSize: Tokens.px(17)
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.margins: Tokens.s4
            anchors.bottomMargin: 0
            height: 1
            visible: card.expanded
            color: Style.line
        }
        HoverHandler { enabled: card.collapsible; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: card.collapsible; onTapped: card.expanded = !card.expanded }
    }

    Column {
        id: rows
        anchors { left: parent.left; right: parent.right; top: heading.bottom }
        visible: card.expanded
    }
}
