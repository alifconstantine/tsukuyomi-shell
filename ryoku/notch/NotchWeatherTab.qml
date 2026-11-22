import QtQuick
import Quickshell
import shell.services
import Ryoku.Ui.Singletons
import "../../services/lib/weather.js" as Wx

// Weather tab (Image 5 style):
// Optional atmospheric gradient backdrop, large current conditions + location,
// 6 metric pills (Humidity, Wind, UV, Pressure, Sunrise, Sunset),
// and bottom Hourly + 7-Day forecast cards.
Item {
    id: wx

    property var root: null
    property var theme: _fallbackTheme
    NotchTheme { id: _fallbackTheme; root: null }
    readonly property bool anim: !Perf.reduceMotion

    signal openSettingsRequested()

    readonly property var cur: Weather.current
    readonly property bool ready: Weather.available && wx.cur !== null
    readonly property bool isDay: wx.ready ? (wx.cur.isDay !== false) : true
    readonly property int code: wx.ready ? Number(wx.cur.code || 0) : 3

    readonly property color skyTop: {
        if (!wx.isDay) return "#1B2440";
        if (wx.code >= 51) return "#2C456B";
        return "#2F66A9";
    }
    readonly property color skyBot: {
        if (!wx.isDay) return "#2A385C";
        if (wx.code >= 51) return "#4A668C";
        return "#5B95D6";
    }
    readonly property bool useSkyBg: NotchConfig.weatherDynamicGradient && wx.ready
    readonly property color fgInk: wx.useSkyBg ? Qt.color("#F6F8FC") : wx.theme.ink
    readonly property color fgMuted: wx.useSkyBg ? Qt.rgba(1, 1, 1, 0.78) : wx.theme.muted
    readonly property color pillFill: wx.useSkyBg ? Qt.rgba(0, 0, 0, 0.22) : wx.theme.card
    readonly property color pillBorder: wx.useSkyBg ? Qt.rgba(1, 1, 1, 0.14) : wx.theme.border

    // Atmospheric backdrop inside card
    Rectangle {
        anchors.fill: parent
        anchors.margins: -8
        radius: 16
        visible: wx.useSkyBg
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: wx.skyTop }
            GradientStop { position: 1.0; color: wx.skyBot }
        }
    }

    // Loading / Offline state
    Column {
        anchors.centerIn: parent
        visible: !wx.ready
        spacing: 8

        NotchIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Weather.status === "loading" ? "cloud_sync" : "cloud_off"
            font.pixelSize: 26
            color: wx.theme.muted
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Weather.status === "loading" ? I18n.tr("Loading weather…") : (Weather.errorText || I18n.tr("Weather offline"))
            color: wx.theme.ink
            font.family: Tokens.ui
            font.pixelSize: 12
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 78; height: 26; radius: 8
            color: wx.theme.card
            border.width: 1; border.color: wx.theme.border
            Text { anchors.centerIn: parent; text: I18n.tr("Retry"); color: wx.theme.ink; font.family: Tokens.ui; font.pixelSize: 11 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Weather.retry() }
        }
    }

    Column {
        anchors.fill: parent
        visible: wx.ready
        spacing: 10

        // ── Top Row: Current Temp/Location + 6 Metric Pills ──────────────────
        Row {
            width: parent.width
            height: 76
            spacing: 12

            // Left: Icon + Temp + Condition + Location
            Row {
                width: Math.round(parent.width * 0.48)
                height: parent.height
                spacing: 10

                NotchIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wx.ready ? Wx.symbolFor(wx.code, wx.isDay) : "cloud"
                    font.pixelSize: 42
                    fill: 1
                    color: wx.fgInk
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wx.ready ? (wx.cur.temp + "°") : "--"
                    color: wx.fgInk
                    font.family: Tokens.ui
                    font.pixelSize: 34
                    font.weight: Font.Bold
                }

                Column {
                    width: parent.width - 122
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: wx.ready ? (wx.cur.condition || Wx.labelFor(wx.code)) : ""
                        color: wx.fgInk
                        font.family: Tokens.ui
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Row {
                        width: parent.width
                        spacing: 3
                        NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "location_on"; font.pixelSize: 11; color: wx.fgMuted }
                        Text {
                            width: parent.width - 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.location || Weather.city || I18n.tr("Auto location")
                            color: wx.fgMuted
                            font.family: Tokens.ui
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: wx.openSettingsRequested()
                        }
                    }
                    Text {
                        width: parent.width
                        text: wx.ready
                            ? ("H " + (wx.cur.hi !== undefined ? wx.cur.hi + "°" : wx.cur.high)
                               + " · L " + (wx.cur.lo !== undefined ? wx.cur.lo + "°" : wx.cur.low)
                               + " · Feels " + wx.cur.feels + "°")
                            : ""
                        color: wx.fgMuted
                        font.family: theme.monoFont
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }

            // Right: 3x2 Metric Pills
            Grid {
                width: parent.width - Math.round(parent.width * 0.48) - 12
                height: parent.height
                columns: 3
                rowSpacing: 6
                columnSpacing: 6
                readonly property real pillW: Math.floor((width - 12) / 3)

                Repeater {
                    model: wx.ready ? [
                        { icon: "water_drop", label: wx.cur.humidity + "%" },
                        { icon: "air",        label: (wx.cur.windValue !== undefined ? wx.cur.windValue + " " + (wx.cur.windUnits || "km/h") : String(wx.cur.wind || "")) },
                        { icon: "wb_sunny",   label: "UV " + (wx.cur.uvIndex !== undefined ? wx.cur.uvIndex : 0) },
                        { icon: "compress",   label: String(wx.cur.pressure || "--") },
                        { icon: "wb_twilight",label: String(wx.cur.sunrise || "--") },
                        { icon: "nights_stay",label: String(wx.cur.sunset || "--") }
                    ] : []
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.pillW
                        height: 32
                        radius: 9
                        color: wx.pillFill
                        border.width: 1
                        border.color: wx.pillBorder

                        Row {
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 10)
                            spacing: 4
                            NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; font.pixelSize: 13; color: wx.fgInk }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, parent.width - 18)
                                text: modelData.label
                                color: wx.fgInk
                                font.family: theme.monoFont
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // ── Bottom Row: Hourly (Left) + 7-Day Forecast (Right) ───────────────
        Row {
            width: parent.width
            height: parent.height - 86
            spacing: 10

            // Hourly card
            Rectangle {
                width: Math.floor((parent.width - 10) / 2)
                height: parent.height
                radius: 13
                color: wx.pillFill
                border.width: 1
                border.color: wx.pillBorder

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    readonly property int count: Math.min(7, Weather.hourly.length)
                    readonly property real colW: count > 0 ? width / count : width

                    Repeater {
                        model: parent.count
                        delegate: Column {
                            required property int index
                            readonly property var h: Weather.hourly[index]
                            width: parent.colW
                            height: parent.height
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: index === 0 ? I18n.tr("Now") : String(h.time || h.hour || "")
                                color: wx.fgMuted
                                font.family: theme.monoFont
                                font.pixelSize: 9
                            }
                            NotchIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Wx.symbolFor(h.code, h.isDay)
                                font.pixelSize: 18
                                fill: 1
                                color: wx.fgInk
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: h.temp + "°"
                                color: wx.fgInk
                                font.family: theme.monoFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: Number(h.precip || 0) > 0
                                text: h.precip + "%"
                                color: wx.fgMuted
                                font.family: theme.monoFont
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }

            // 7-Day card
            Rectangle {
                width: Math.floor((parent.width - 10) / 2)
                height: parent.height
                radius: 13
                color: wx.pillFill
                border.width: 1
                border.color: wx.pillBorder

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    readonly property int count: Math.min(7, Weather.daily.length)
                    readonly property real colW: count > 0 ? width / count : width

                    Repeater {
                        model: parent.count
                        delegate: Column {
                            required property int index
                            readonly property var d: Weather.daily[index]
                            width: parent.colW
                            height: parent.height
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: index === 0 ? I18n.tr("Today") : String(d.weekday || d.day || "").slice(0, 3)
                                color: wx.fgMuted
                                font.family: Tokens.ui
                                font.pixelSize: 10
                                font.weight: index === 0 ? Font.DemiBold : Font.Normal
                            }
                            NotchIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Wx.symbolFor(d.code, true)
                                font.pixelSize: 18
                                fill: 1
                                color: wx.fgInk
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (d.hi !== undefined ? d.hi + "°" : String(d.high || ""))
                                color: wx.fgInk
                                font.family: theme.monoFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (d.lo !== undefined ? d.lo + "°" : String(d.low || ""))
                                color: wx.fgMuted
                                font.family: theme.monoFont
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }
}
