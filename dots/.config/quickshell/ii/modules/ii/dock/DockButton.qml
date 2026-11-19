import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    Layout.fillHeight: true
    Layout.topMargin: Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut
    implicitWidth: implicitHeight - topInset - bottomInset
    buttonRadius: 12
    rippleEnabled: false
    colBackgroundHover: TsukuyomiStyle.dark ? "#29ffffff" : "#1a202124"

    background.implicitHeight: 50
}
