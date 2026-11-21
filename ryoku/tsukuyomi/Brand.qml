import QtQuick
import Ryoku.Ui.Singletons

Row {
    id: brand
    property string title
    spacing: Tokens.s3

    Rectangle {
        width: Tokens.px(34)
        height: width
        radius: Tokens.px(10)
        color: Style.selected
        Text {
            anchors.centerIn: parent
            text: UiPreferences.text("月", "T")
            color: Style.accent
            font.family: Tokens.jp
            font.pixelSize: Tokens.px(18)
        }
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: brand.title
        color: Style.text
        font.family: Tokens.ui
        font.pixelSize: Tokens.fRow
        font.weight: Font.DemiBold
    }
}
