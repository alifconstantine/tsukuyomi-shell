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

    function parseManualDuration(raw) {
        var s = String(raw || "").trim().toLowerCase();
        if (s === "") return -1;
        if (s.indexOf(":") >= 0) {
            var parts = s.split(":");
            if (parts.length !== 2) return -1;
            var mm = parseInt(parts[0], 10);
            var ss = parseInt(parts[1], 10);
            if (isNaN(mm) || isNaN(ss) || mm < 0 || ss < 0 || ss >= 60) return -1;
            return mm * 60 + ss;
        }
        if (s.endsWith("s")) {
            var secs = parseInt(s.slice(0, -1), 10);
            return isNaN(secs) || secs <= 0 ? -1 : secs;
        }
        var mins = parseInt(s.replace(/m$/, ""), 10);
        return isNaN(mins) || mins <= 0 ? -1 : mins * 60;
    }

    function applyManualDuration() {
        var secs = tm.parseManualDuration(manualInput.text);
        if (secs > 0) {
            NotchTimerState.setTimerSeconds(secs);
            manualInput.text = "";
            manualInput.focus = false;
        }
    }

    component ModePill: Rectangle {
        id: mp
        property string label: ""
        property bool active: false
        property real fixedW: 0
        signal chose()

        width: fixedW > 0 ? fixedW : (mpText.implicitWidth + 16)
        height: 24
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
        spacing: 14

        // ── Left: Circular Progress Ring ─────────────────────────────────────
        Item {
            width: 126
            height: parent.height

            Canvas {
                id: ringCanvas
                anchors.centerIn: parent
                width: 118
                height: 118

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
                    font.family: theme.monoFont
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: NotchTimerState.phaseLabel
                    color: tm.theme.muted
                    font.family: theme.monoFont
                    font.pixelSize: 9
                    font.letterSpacing: 1.0
                }
            }
        }

        // ── Right: Modes, Sub-presets & Transport ────────────────────────────
        Column {
            width: parent.width - 140
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Primary mode bar (stretches full width to avoid dead space)
            Rectangle {
                width: parent.width
                height: 30
                radius: 10
                color: tm.theme.card
                border.width: 1
                border.color: tm.theme.border

                Row {
                    id: modeRow
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 2
                    readonly property real cellW: Math.floor((width - 4) / 3)
                    ModePill { fixedW: modeRow.cellW; label: I18n.tr("Pomodoro"); active: NotchTimerState.mode === "pomodoro"; onChose: NotchTimerState.setMode("pomodoro") }
                    ModePill { fixedW: modeRow.cellW; label: I18n.tr("Timer");    active: NotchTimerState.mode === "timer";    onChose: NotchTimerState.setMode("timer") }
                    ModePill { fixedW: modeRow.cellW; label: I18n.tr("Stopwatch");active: NotchTimerState.mode === "stopwatch";onChose: NotchTimerState.setMode("stopwatch") }
                }
            }

            // Sub-mode selector: Pomodoro phases / Timer presets & +/-1
            Rectangle {
                visible: NotchTimerState.mode !== "stopwatch"
                width: parent.width
                height: 30
                radius: 9
                color: tm.theme.card
                border.width: 1
                border.color: tm.theme.border

                Row {
                    visible: NotchTimerState.mode === "pomodoro"
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 2
                    readonly property real cellW: Math.floor((width - 4) / 3)
                    ModePill { fixedW: parent.cellW; label: I18n.tr("Focus");       active: NotchTimerState.pomoPhase === "focus"; onChose: NotchTimerState.setPomoPhase("focus") }
                    ModePill { fixedW: parent.cellW; label: I18n.tr("Short break"); active: NotchTimerState.pomoPhase === "short"; onChose: NotchTimerState.setPomoPhase("short") }
                    ModePill { fixedW: parent.cellW; label: I18n.tr("Long break");  active: NotchTimerState.pomoPhase === "long";  onChose: NotchTimerState.setPomoPhase("long") }
                }

                Row {
                    visible: NotchTimerState.mode === "timer"
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 2
                    readonly property real cellW: Math.floor((width - 8) / 5)
                    ModePill { fixedW: parent.cellW; label: "5m";  active: NotchTimerState.timerTotalSec === 300;  onChose: NotchTimerState.setTimerMinutes(5) }
                    ModePill { fixedW: parent.cellW; label: "15m"; active: NotchTimerState.timerTotalSec === 900;  onChose: NotchTimerState.setTimerMinutes(15) }
                    ModePill { fixedW: parent.cellW; label: "25m"; active: NotchTimerState.timerTotalSec === 1500; onChose: NotchTimerState.setTimerMinutes(25) }
                    ModePill { fixedW: parent.cellW; label: "-1";  active: false; onChose: NotchTimerState.adjustTimerMinutes(-1) }
                    ModePill { fixedW: parent.cellW; label: "+1";  active: false; onChose: NotchTimerState.adjustTimerMinutes(1) }
                }
            }

            // Stopwatch latest laps strip
            Row {
                visible: NotchTimerState.mode === "stopwatch"
                width: parent.width
                height: 30
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    text: NotchTimerState.laps.length > 0
                        ? (I18n.tr("Laps: ") + NotchTimerState.laps.slice(0, 3).join("  ·  "))
                        : I18n.tr("Press flag to record a lap")
                    color: tm.theme.muted
                    font.family: theme.monoFont
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            // Controls row + Pomodoro dots OR Manual Timer Input
            Item {
                width: parent.width
                height: 38

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // Reset
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: rstMa.containsMouse ? tm.theme.cardHover : tm.theme.card
                        border.width: 1; border.color: tm.theme.border
                        scale: rstMa.pressed ? 0.9 : 1.0
                        Behavior on scale { enabled: tm.anim; NumberAnimation { duration: 100 } }
                        NotchIcon { anchors.centerIn: parent; text: "replay"; font.pixelSize: 16; color: tm.theme.ink }
                        MouseArea {
                            id: rstMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: NotchTimerState.reset()
                        }
                    }

                    // Prominent Play/Pause circle
                    Rectangle {
                        width: 38; height: 38; radius: 19
                        anchors.verticalCenter: parent.verticalCenter
                        color: tm.theme.ink
                        scale: ppMa.pressed ? 0.92 : (ppMa.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { enabled: tm.anim; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        NotchIcon {
                            anchors.centerIn: parent
                            text: NotchTimerState.running ? "pause" : "play_arrow"
                            font.pixelSize: 20
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
                        width: 32; height: 32; radius: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: skMa.containsMouse ? tm.theme.cardHover : tm.theme.card
                        border.width: 1; border.color: tm.theme.border
                        scale: skMa.pressed ? 0.9 : 1.0
                        Behavior on scale { enabled: tm.anim; NumberAnimation { duration: 100 } }
                        NotchIcon {
                            anchors.centerIn: parent
                            text: NotchTimerState.mode === "stopwatch" ? "flag" : "skip_next"
                            font.pixelSize: 16
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
                }

                // Pomodoro cycle indicator
                Row {
                    visible: NotchTimerState.mode === "pomodoro"
                    anchors.right: parent.right
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
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: NotchTimerState.pomoCycle + "/4"
                        color: tm.theme.muted
                        font.family: theme.monoFont
                        font.pixelSize: 10
                    }
                }

                // Manual duration input for Timer mode (e.g. "12" min or "01:30" or "45s")
                Row {
                    visible: NotchTimerState.mode === "timer"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        width: 82
                        height: 28
                        radius: 8
                        color: tm.theme.card
                        border.width: 1
                        border.color: manualInput.activeFocus ? tm.theme.accent : tm.theme.border

                        TextInput {
                            id: manualInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            color: tm.theme.ink
                            font.family: theme.monoFont
                            font.pixelSize: 11
                            selectByMouse: true
                            clip: true
                            onAccepted: tm.applyManualDuration()

                            Text {
                                anchors.centerIn: parent
                                visible: manualInput.text === ""
                                text: "MM:SS"
                                color: tm.theme.muted
                                font.family: theme.monoFont
                                font.pixelSize: 10
                            }
                        }
                    }

                    Rectangle {
                        width: 42
                        height: 28
                        radius: 8
                        color: setMa.containsMouse ? tm.theme.accentHover : tm.theme.accent
                        Text {
                            anchors.centerIn: parent
                            text: I18n.tr("Set")
                            color: tm.theme.onAccent
                            font.family: Tokens.ui
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: setMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tm.applyManualDuration()
                        }
                    }
                }
            }
        }
    }
}
