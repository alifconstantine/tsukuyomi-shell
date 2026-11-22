import QtQuick
import Quickshell
import shell.services
import Ryoku.Ui.Singletons

// Timer tab (Image 3 style):
// Left: Circular progress ring with live countdown and riding indicator dot.
// Right: Mode switcher (Pomodoro | Timer | Stopwatch), sub-mode/presets, and controls.
Item {
    id: tm

    property var root: null
    property var theme: _fallbackTheme
    NotchTheme { id: _fallbackTheme; root: null }
    readonly property bool anim: !Perf.reduceMotion

    component ModePill: Rectangle {
        id: mp
        property string label: ""
        property bool active: false
        signal chose()

        width: mpText.implicitWidth + 18
        height: 26
        radius: 8
        color: active ? Qt.rgba(tm.theme.ink.r, tm.theme.ink.g, tm.theme.ink.b, 0.14)
            : (mpMa.containsMouse ? tm.theme.cardHover : "transparent")
        Behavior on color { enabled: tm.anim; ColorAnimation { duration: 130 } }

        Text {
            id: mpText
            anchors.centerIn: parent
            text: mp.label
            color: mp.active ? tm.theme.ink : tm.theme.muted
            font.family: Tokens.ui
            font.pixelSize: 11
            font.weight: mp.active ? Font.DemiBold : Font.Normal
        }
        MouseArea {
            id: mpMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: mp.chose()
        }
    }

    Row {
        anchors.fill: parent
        spacing: 16

        // ── Left: Circular Progress Ring ─────────────────────────────────────
        Item {
            width: 134
            height: parent.height

            Canvas {
                id: ringCanvas
                anchors.centerIn: parent
                width: 122
                height: 122

                property real prog: NotchTimerState.progress
                Behavior on prog {
                    enabled: tm.anim
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                onProgChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: tm.theme
                    function onAccentChanged() { ringCanvas.requestPaint() }
                    function onInkChanged() { ringCanvas.requestPaint() }
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    var cx = width / 2;
                    var cy = height / 2;
                    var r = (width / 2) - 8;

                    ctx.lineWidth = 5;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    ctx.strokeStyle = Qt.rgba(tm.theme.ink.r, tm.theme.ink.g, tm.theme.ink.b, 0.14);
                    ctx.stroke();

                    var start = -Math.PI / 2;
                    var end = start + Math.PI * 2 * Math.max(0.005, prog);
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, start, end);
                    ctx.strokeStyle = tm.theme.accent;
                    ctx.stroke();

                    // Riding dot at progress head
                    var dx = cx + r * Math.cos(end);
                    var dy = cy + r * Math.sin(end);
                    ctx.beginPath();
                    ctx.arc(dx, dy, 4.2, 0, Math.PI * 2);
                    ctx.fillStyle = tm.theme.accent;
                    ctx.fill();
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: NotchTimerState.formatted
                    color: tm.theme.ink
                    font.family: Tokens.mono
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: NotchTimerState.phaseLabel
                    color: tm.theme.muted
                    font.family: Tokens.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.0
                }
            }
        }

        // ── Right: Modes, Sub-presets & Transport ────────────────────────────
        Column {
            width: parent.width - 150
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // Primary mode bar
            Rectangle {
                width: modeRow.implicitWidth + 6
                height: 32
                radius: 10
                color: tm.theme.card
                border.width: 1
                border.color: tm.theme.border

                Row {
                    id: modeRow
                    anchors.centerIn: parent
                    spacing: 2
                    ModePill { label: I18n.tr("Pomodoro"); active: NotchTimerState.mode === "pomodoro"; onChose: NotchTimerState.setMode("pomodoro") }
                    ModePill { label: I18n.tr("Timer");    active: NotchTimerState.mode === "timer";    onChose: NotchTimerState.setMode("timer") }
                    ModePill { label: I18n.tr("Stopwatch");active: NotchTimerState.mode === "stopwatch";onChose: NotchTimerState.setMode("stopwatch") }
                }
            }

            // Sub-mode selector: Pomodoro phases / Timer presets / Stopwatch laps
            Rectangle {
                visible: NotchTimerState.mode !== "stopwatch"
                width: subRow.implicitWidth + 6
                height: 30
                radius: 9
                color: tm.theme.card
                border.width: 1
                border.color: tm.theme.border

                Row {
                    id: subRow
                    anchors.centerIn: parent
                    spacing: 2

                    // Pomodoro phases
                    ModePill { visible: NotchTimerState.mode === "pomodoro"; label: I18n.tr("Focus");       active: NotchTimerState.pomoPhase === "focus"; onChose: NotchTimerState.setPomoPhase("focus") }
                    ModePill { visible: NotchTimerState.mode === "pomodoro"; label: I18n.tr("Short break"); active: NotchTimerState.pomoPhase === "short"; onChose: NotchTimerState.setPomoPhase("short") }
                    ModePill { visible: NotchTimerState.mode === "pomodoro"; label: I18n.tr("Long break");  active: NotchTimerState.pomoPhase === "long";  onChose: NotchTimerState.setPomoPhase("long") }

                    // Timer presets & +/- 1m
                    ModePill { visible: NotchTimerState.mode === "timer"; label: "5m";  active: NotchTimerState.timerTotalSec === 300;  onChose: NotchTimerState.setTimerMinutes(5) }
                    ModePill { visible: NotchTimerState.mode === "timer"; label: "15m"; active: NotchTimerState.timerTotalSec === 900;  onChose: NotchTimerState.setTimerMinutes(15) }
                    ModePill { visible: NotchTimerState.mode === "timer"; label: "25m"; active: NotchTimerState.timerTotalSec === 1500; onChose: NotchTimerState.setTimerMinutes(25) }
                    ModePill { visible: NotchTimerState.mode === "timer"; label: "-1";  active: false; onChose: NotchTimerState.adjustTimerMinutes(-1) }
                    ModePill { visible: NotchTimerState.mode === "timer"; label: "+1";  active: false; onChose: NotchTimerState.adjustTimerMinutes(1) }
                }
            }

            // Stopwatch latest laps strip
            Row {
                visible: NotchTimerState.mode === "stopwatch"
                width: parent.width
                height: 28
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: NotchTimerState.laps.length > 0
                        ? (I18n.tr("Laps: ") + NotchTimerState.laps.slice(0, 3).join("  ·  "))
                        : I18n.tr("Press flag to record a lap")
                    color: tm.theme.muted
                    font.family: Tokens.mono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            // Controls row + Pomodoro cycle dots
            Row {
                spacing: 12

                // Reset
                Rectangle {
                    width: 34; height: 34; radius: 17
                    anchors.verticalCenter: parent.verticalCenter
                    color: rstMa.containsMouse ? tm.theme.cardHover : tm.theme.card
                    border.width: 1; border.color: tm.theme.border
                    scale: rstMa.pressed ? 0.9 : 1.0
                    Behavior on scale { enabled: tm.anim; NumberAnimation { duration: 100 } }
                    NotchIcon { anchors.centerIn: parent; text: "replay"; font.pixelSize: 17; color: tm.theme.ink }
                    MouseArea {
                        id: rstMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: NotchTimerState.reset()
                    }
                }

                // Prominent Play/Pause circle
                Rectangle {
                    width: 42; height: 42; radius: 21
                    anchors.verticalCenter: parent.verticalCenter
                    color: tm.theme.ink
                    scale: ppMa.pressed ? 0.92 : (ppMa.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { enabled: tm.anim; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    NotchIcon {
                        anchors.centerIn: parent
                        text: NotchTimerState.running ? "pause" : "play_arrow"
                        font.pixelSize: 22
                        fill: 1
                        color: tm.theme.baseSurface
                    }
                    MouseArea {
                        id: ppMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: NotchTimerState.toggle()
                    }
                }

                // Skip / Lap
                Rectangle {
                    width: 34; height: 34; radius: 17
                    anchors.verticalCenter: parent.verticalCenter
                    color: skMa.containsMouse ? tm.theme.cardHover : tm.theme.card
                    border.width: 1; border.color: tm.theme.border
                    scale: skMa.pressed ? 0.9 : 1.0
                    Behavior on scale { enabled: tm.anim; NumberAnimation { duration: 100 } }
                    NotchIcon {
                        anchors.centerIn: parent
                        text: NotchTimerState.mode === "stopwatch" ? "flag" : "skip_next"
                        font.pixelSize: 17
                        fill: 1
                        color: tm.theme.ink
                    }
                    MouseArea {
                        id: skMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (NotchTimerState.mode === "stopwatch") NotchTimerState.addLap();
                            else NotchTimerState.skip();
                        }
                    }
                }

                // Pomodoro cycle dots
                Row {
                    visible: NotchTimerState.mode === "pomodoro"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            width: 7; height: 7; radius: 3.5
                            color: index < NotchTimerState.pomoCycle
                                ? tm.theme.accent
                                : Qt.rgba(tm.theme.ink.r, tm.theme.ink.g, tm.theme.ink.b, 0.18)
                        }
                    }
                }
            }
        }
    }
}
