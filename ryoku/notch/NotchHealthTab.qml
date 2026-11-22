import QtQuick
import Quickshell
import shell.services
import Ryoku.Ui.Singletons

// Health tab (Image 6 + Water Reminder hourly bar chart from video):
// Left: 3 concentric Activity Rings (Movement, Water, Breathing) + summary counts.
// Right: 2x2 Bento (Water -/+, Movement break, Breathing 4-4-6, Eye break 20-20-20)
// OR toggleable Water Reminder hourly chart view.
Item {
    id: hl

    property var root: null
    property var theme: _fallbackTheme
    NotchTheme { id: _fallbackTheme; root: null }
    readonly property bool anim: !Perf.reduceMotion

    property bool waterChartView: false

    readonly property color cMove: "#4ADE80"
    readonly property color cWater: "#60A5FA"
    readonly property color cBreath: "#C084FC"
    readonly property color cEye: "#FACC15"

    readonly property string lastBreakLabel: {
        if (!NotchHealthStore.lastBreakMs || NotchHealthStore.lastBreakMs <= 0)
            return I18n.tr("No breaks logged yet today");
        var mins = Math.max(0, Math.round((Date.now() - NotchHealthStore.lastBreakMs) / 60000));
        return mins < 1 ? I18n.tr("Last break just now") : I18n.tr("Last break %1m ago").arg(mins);
    }

    function fmtSec(sec) {
        var m = Math.floor(sec / 60);
        var s = sec % 60;
        return (m > 0 ? (m + ":") : "") + (m > 0 && s < 10 ? "0" : "") + s + (m === 0 ? "s" : "");
    }

    Column {
        anchors.fill: parent
        spacing: 8

        // Top metadata row
        Row {
            width: parent.width
            height: 20
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 210
                text: hl.lastBreakLabel
                color: hl.theme.muted
                font.family: Tokens.ui
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Rectangle {
                width: 96; height: 20; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                color: hl.waterChartView ? Qt.rgba(hl.cWater.r, hl.cWater.g, hl.cWater.b, 0.22) : hl.theme.card
                border.width: 1
                border.color: hl.waterChartView ? hl.cWater : hl.theme.border
                Text {
                    anchors.centerIn: parent
                    text: hl.waterChartView ? I18n.tr("Activity View") : I18n.tr("Water Chart")
                    color: hl.theme.ink
                    font.family: Tokens.ui
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: hl.waterChartView = !hl.waterChartView
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "local_fire_department"; font.pixelSize: 13; fill: 1; color: hl.theme.warning }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("%1 day streak").arg(NotchHealthStore.streakDays)
                    color: hl.theme.ink
                    font.family: Tokens.ui
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
            }
        }

        // ── View A: Activity Rings + 2x2 Health Bento (Image 6) ──────────────
        Row {
            visible: !hl.waterChartView
            width: parent.width
            height: parent.height - 28
            spacing: 12

            // Left: Concentric Rings
            Column {
                width: 152
                height: parent.height
                spacing: 6

                Item {
                    width: 130; height: 130
                    anchors.horizontalCenter: parent.horizontalCenter

                    Canvas {
                        id: ringsCanvas
                        anchors.fill: parent
                        property real fMove: NotchHealthStore.moveFrac
                        property real fWater: NotchHealthStore.waterFrac
                        property real fBreath: NotchHealthStore.breathFrac

                        Behavior on fMove { enabled: hl.anim; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on fWater { enabled: hl.anim; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on fBreath { enabled: hl.anim; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        onFMoveChanged: requestPaint()
                        onFWaterChanged: requestPaint()
                        onFBreathChanged: requestPaint()
                        Component.onCompleted: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var cx = width / 2, cy = height / 2;
                            var specs = [
                                { r: 54, f: fMove, col: hl.cMove },
                                { r: 41, f: fWater, col: hl.cWater },
                                { r: 28, f: fBreath, col: hl.cBreath }
                            ];
                            ctx.lineWidth = 9;
                            ctx.lineCap = "round";
                            for (var i = 0; i < specs.length; i++) {
                                var sp = specs[i];
                                ctx.beginPath();
                                ctx.arc(cx, cy, sp.r, 0, Math.PI * 2);
                                ctx.strokeStyle = Qt.rgba(sp.col.r, sp.col.g, sp.col.b, 0.16);
                                ctx.stroke();

                                if (sp.f > 0.01) {
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, sp.r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * sp.f);
                                    ctx.strokeStyle = sp.col;
                                    ctx.stroke();
                                }
                            }
                        }
                    }

                    // Live breathing orb cue inside ring center when breathing session runs
                    Rectangle {
                        anchors.centerIn: parent
                        visible: NotchHealthStore.activeSession === "breathing"
                        width: NotchHealthStore.breathingCue === "Exhale" ? 20 : 34
                        height: width; radius: width / 2
                        color: Qt.rgba(hl.cBreath.r, hl.cBreath.g, hl.cBreath.b, 0.35)
                        Behavior on width { enabled: hl.anim; NumberAnimation { duration: 1200; easing.type: Easing.InOutSine } }
                        Text {
                            anchors.centerIn: parent
                            text: NotchHealthStore.breathingCue
                            color: hl.theme.ink
                            font.family: Tokens.ui
                            font.pixelSize: 8
                            font.weight: Font.Bold
                        }
                    }
                }

                // Legend row
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Text { text: "● " + NotchHealthStore.movementDone + "/" + NotchHealthStore.movementGoal; color: hl.cMove; font.family: Tokens.mono; font.pixelSize: 10 }
                    Text { text: "● " + NotchHealthStore.waterGlasses + "/" + NotchHealthStore.waterGoal; color: hl.cWater; font.family: Tokens.mono; font.pixelSize: 10 }
                    Text { text: "● " + NotchHealthStore.breathingDone + "/" + NotchHealthStore.breathingGoal; color: hl.cBreath; font.family: Tokens.mono; font.pixelSize: 10 }
                }
            }

            // Right: 2x2 Bento Grid
            Grid {
                width: parent.width - 164
                height: parent.height
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                readonly property real cardW: Math.floor((width - 8) / 2)
                readonly property real cardH: Math.floor((height - 8) / 2)

                // 1. Water counter
                Rectangle {
                    width: parent.cardW; height: parent.cardH; radius: 13
                    color: hl.theme.card; border.width: 1; border.color: hl.theme.border
                    Column {
                        anchors.fill: parent; anchors.margins: 10; spacing: 8
                        Row {
                            spacing: 6
                            NotchIcon { text: "water_drop"; font.pixelSize: 15; fill: 1; color: hl.cWater }
                            Text { text: I18n.tr("Water"); color: hl.theme.ink; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.DemiBold }
                        }
                        Item {
                            width: parent.width; height: 28
                            Rectangle {
                                anchors.left: parent.left; width: 26; height: 26; radius: 13
                                color: wMinMa.containsMouse ? hl.theme.cardHover : Qt.rgba(hl.theme.ink.r, hl.theme.ink.g, hl.theme.ink.b, 0.08)
                                NotchIcon { anchors.centerIn: parent; text: "remove"; font.pixelSize: 14; color: hl.theme.ink }
                                MouseArea { id: wMinMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotchHealthStore.addWater(-1) }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: NotchHealthStore.waterGlasses + " / " + NotchHealthStore.waterGoal
                                color: hl.theme.ink; font.family: Tokens.mono; font.pixelSize: 14; font.weight: Font.Bold
                            }
                            Rectangle {
                                anchors.right: parent.right; width: 26; height: 26; radius: 13
                                color: wPlusMa.containsMouse ? Qt.rgba(hl.cWater.r, hl.cWater.g, hl.cWater.b, 0.25) : Qt.rgba(hl.theme.ink.r, hl.theme.ink.g, hl.theme.ink.b, 0.08)
                                NotchIcon { anchors.centerIn: parent; text: "add"; font.pixelSize: 14; color: hl.theme.ink }
                                MouseArea { id: wPlusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotchHealthStore.addWater(1) }
                            }
                        }
                    }
                }

                // 2. Movement break
                Rectangle {
                    width: parent.cardW; height: parent.cardH; radius: 13
                    color: hl.theme.card; border.width: 1
                    border.color: NotchHealthStore.activeSession === "movement" ? hl.cMove : hl.theme.border
                    Column {
                        anchors.fill: parent; anchors.margins: 10; spacing: 4
                        Row {
                            spacing: 6
                            NotchIcon { text: "directions_walk"; font.pixelSize: 15; color: hl.cMove }
                            Text { text: I18n.tr("Movement break"); color: hl.theme.ink; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.DemiBold }
                        }
                        Text { text: I18n.tr("Desk stretches · 2 min"); color: hl.theme.muted; font.family: Tokens.ui; font.pixelSize: 10 }
                        Rectangle {
                            width: parent.width; height: 24; radius: 8
                            color: NotchHealthStore.activeSession === "movement"
                                ? Qt.rgba(hl.cMove.r, hl.cMove.g, hl.cMove.b, 0.24)
                                : (mvMa.containsMouse ? hl.theme.cardHover : Qt.rgba(hl.theme.ink.r, hl.theme.ink.g, hl.theme.ink.b, 0.08))
                            Row {
                                anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                NotchIcon { text: NotchHealthStore.activeSession === "movement" ? "stop" : "play_arrow"; font.pixelSize: 13; fill: 1; color: hl.theme.ink }
                                Text {
                                    text: NotchHealthStore.activeSession === "movement"
                                        ? hl.fmtSec(NotchHealthStore.sessionSecLeft)
                                        : I18n.tr("Start")
                                    color: hl.theme.ink; font.family: Tokens.ui; font.pixelSize: 10; font.weight: Font.Medium
                                }
                            }
                            MouseArea { id: mvMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotchHealthStore.startSession("movement") }
                        }
                    }
                }

                // 3. Breathing
                Rectangle {
                    width: parent.cardW; height: parent.cardH; radius: 13
                    color: hl.theme.card; border.width: 1
                    border.color: NotchHealthStore.activeSession === "breathing" ? hl.cBreath : hl.theme.border
                    Column {
                        anchors.fill: parent; anchors.margins: 10; spacing: 4
                        Row {
                            spacing: 6
                            NotchIcon { text: "self_improvement"; font.pixelSize: 15; color: hl.cBreath }
                            Text { text: I18n.tr("Breathing"); color: hl.theme.ink; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.DemiBold }
                        }
                        Text { text: I18n.tr("Calm 4-4-6 breathing · 1 min"); color: hl.theme.muted; font.family: Tokens.ui; font.pixelSize: 10 }
                        Rectangle {
                            width: parent.width; height: 24; radius: 8
                            color: NotchHealthStore.activeSession === "breathing"
                                ? Qt.rgba(hl.cBreath.r, hl.cBreath.g, hl.cBreath.b, 0.24)
                                : (brMa.containsMouse ? hl.theme.cardHover : Qt.rgba(hl.theme.ink.r, hl.theme.ink.g, hl.theme.ink.b, 0.08))
                            Row {
                                anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                NotchIcon { text: NotchHealthStore.activeSession === "breathing" ? "stop" : "play_arrow"; font.pixelSize: 13; fill: 1; color: hl.theme.ink }
                                Text {
                                    text: NotchHealthStore.activeSession === "breathing"
                                        ? (NotchHealthStore.breathingCue + " · " + hl.fmtSec(NotchHealthStore.sessionSecLeft))
                                        : I18n.tr("Start")
                                    color: hl.theme.ink; font.family: Tokens.ui; font.pixelSize: 10; font.weight: Font.Medium
                                }
                            }
                            MouseArea { id: brMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotchHealthStore.startSession("breathing") }
                        }
                    }
                }

                // 4. Eye break 20-20-20
                Rectangle {
                    width: parent.cardW; height: parent.cardH; radius: 13
                    color: hl.theme.card; border.width: 1
                    border.color: NotchHealthStore.activeSession === "eye" ? hl.cEye : hl.theme.border
                    Column {
                        anchors.fill: parent; anchors.margins: 10; spacing: 4
                        Row {
                            spacing: 6
                            NotchIcon { text: "visibility"; font.pixelSize: 15; fill: 1; color: hl.cEye }
                            Text { text: I18n.tr("Eye break"); color: hl.theme.ink; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.DemiBold }
                        }
                        Text { text: I18n.tr("20-20-20: look 20 ft away for 20 s"); color: hl.theme.muted; font.family: Tokens.ui; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width }
                        Rectangle {
                            width: parent.width; height: 24; radius: 8
                            color: NotchHealthStore.activeSession === "eye"
                                ? Qt.rgba(hl.cEye.r, hl.cEye.g, hl.cEye.b, 0.24)
                                : (eyMa.containsMouse ? hl.theme.cardHover : Qt.rgba(hl.theme.ink.r, hl.theme.ink.g, hl.theme.ink.b, 0.08))
                            Row {
                                anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                NotchIcon { text: NotchHealthStore.activeSession === "eye" ? "stop" : "play_arrow"; font.pixelSize: 13; fill: 1; color: hl.theme.ink }
                                Text {
                                    text: NotchHealthStore.activeSession === "eye"
                                        ? hl.fmtSec(NotchHealthStore.sessionSecLeft)
                                        : I18n.tr("Now (%1 today)").arg(NotchHealthStore.eyeDone)
                                    color: hl.theme.ink; font.family: Tokens.ui; font.pixelSize: 10; font.weight: Font.Medium
                                }
                            }
                            MouseArea { id: eyMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotchHealthStore.startSession("eye") }
                        }
                    }
                }
            }
        }

        // ── View B: Water Reminder Detail Chart (from reference video) ───────
        Row {
            visible: hl.waterChartView
            width: parent.width
            height: parent.height - 28
            spacing: 14

            Column {
                width: 230
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Row {
                    spacing: 8
                    Text {
                        text: NotchHealthStore.waterLiters.toFixed(1)
                        color: hl.theme.ink; font.family: Tokens.ui; font.pixelSize: 28; font.weight: Font.Bold
                    }
                    Text {
                        anchors.baseline: parent.children[0].baseline
                        text: "/ " + NotchHealthStore.waterGoalLiters.toFixed(1) + " L"
                        color: hl.theme.muted; font.family: Tokens.mono; font.pixelSize: 13
                    }
                }

                Text {
                    text: I18n.tr("Today · %1%").arg(Math.round(NotchHealthStore.waterFrac * 100))
                        + (NotchHealthStore.waterFrac >= 1 ? (" · " + I18n.tr("Goal reached")) : "")
                    color: hl.cWater; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.Medium
                }

                Rectangle {
                    width: parent.width; height: 5; radius: 2.5
                    color: Qt.rgba(hl.theme.ink.r, hl.theme.ink.g, hl.theme.ink.b, 0.12)
                    Rectangle {
                        width: Math.round(parent.width * NotchHealthStore.waterFrac)
                        height: parent.height; radius: 2.5; color: hl.cWater
                        Behavior on width { enabled: hl.anim; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    }
                }

                Row {
                    spacing: 8
                    Rectangle {
                        width: 106; height: 32; radius: 11
                        color: Qt.rgba(hl.cWater.r, hl.cWater.g, hl.cWater.b, 0.24)
                        border.width: 1; border.color: hl.cWater
                        Row {
                            anchors.centerIn: parent; spacing: 5
                            NotchIcon { text: "water_drop"; font.pixelSize: 15; fill: 1; color: hl.cWater }
                            Text { text: I18n.tr("Drink"); color: hl.theme.ink; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.DemiBold }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotchHealthStore.addWater(1) }
                    }
                    Rectangle {
                        width: 80; height: 32; radius: 11
                        color: hl.theme.card; border.width: 1; border.color: hl.theme.border
                        Text { anchors.centerIn: parent; text: I18n.tr("- 1 glass"); color: hl.theme.muted; font.family: Tokens.ui; font.pixelSize: 11 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotchHealthStore.addWater(-1) }
                    }
                }
            }

            // Hourly bar chart (08:00..21:00)
            Rectangle {
                width: parent.width - 244
                height: parent.height
                radius: 13
                color: hl.theme.card
                border.width: 1
                border.color: hl.theme.border

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Repeater {
                        model: 12
                        delegate: Column {
                            required property int index
                            readonly property int hour: index + 8
                            readonly property int ml: Number((NotchHealthStore.waterHourly || [])[hour] || 0)
                            readonly property real barFrac: Math.min(1, ml / 500)
                            width: (parent.width - 11 * 8) / 12
                            height: parent.height
                            spacing: 4

                            Item {
                                width: parent.width
                                height: parent.height - 18

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.min(14, parent.width)
                                    height: Math.max(4, Math.round(parent.height * barFrac))
                                    radius: 4
                                    color: ml > 0 ? hl.cWater : Qt.rgba(hl.theme.ink.r, hl.theme.ink.g, hl.theme.ink.b, 0.10)
                                    Behavior on height { enabled: hl.anim; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (hour % 3 === 0) ? (hour < 10 ? "0" + hour : String(hour)) : ""
                                color: hl.theme.muted
                                font.family: Tokens.mono
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }
        }
    }
}
