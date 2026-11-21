import QtQuick
import Ryoku.Ui.Singletons

Text {
    height: Math.max(implicitHeight, Tokens.px(34))
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    color: Style.text
    font.family: Tokens.ui
    font.pixelSize: Tokens.px(16)
    font.weight: Font.DemiBold
}
