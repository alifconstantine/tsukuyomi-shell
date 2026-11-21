import QtQuick
import Ryoku.Ui.Singletons

Column {
    id: panel

    property string text
    property int titleSize: Tokens.px(22)
    spacing: Tokens.px(3)
    Accessible.role: Accessible.Heading
    Accessible.name: "Tsukuyomi " + text

    Text {
        width: parent.width
        text: "Tsukuyomi"
        color: Style.secondary
        font.family: Tokens.ui
        font.pixelSize: Tokens.px(11)
        font.letterSpacing: Tokens.px(1.5)
        font.capitalization: Font.AllUppercase
        elide: Text.ElideRight
    }

    Text {
        width: parent.width
        text: panel.text
        color: Style.text
        font.family: Tokens.ui
        font.pixelSize: panel.titleSize
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }
}
