import QtQuick
import qs.modules.common

Rectangle {
    radius: 18
    border.width: 1
    border.color: TsukuyomiStyle.border
    gradient: Gradient {
        GradientStop { position: 0; color: TsukuyomiStyle.frostTop }
        GradientStop { position: 1; color: TsukuyomiStyle.frostBottom }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        border.width: TsukuyomiStyle.glass ? 1 : 0
        border.color: TsukuyomiStyle.dark ? "#18ffffff" : "#66ffffff"
    }
}
