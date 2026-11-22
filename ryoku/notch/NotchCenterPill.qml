import QtQuick
import Quickshell
import shell.services
import Ryoku.Ui.Singletons

// Center Dynamic Island pill (Closed / Idle state + Live Activity Morph).
// Idle shows: [RAM Usage Ring]  [Clock]  [Now Playing Visualizer / Music Icon].
// Transient Live Activities (charging, Bluetooth connect, Focus/Coffee toggle,
// screen recording) smoothly morph the pill width with spring-like motion.
Item {
    id: pill

    required property var root
    property var screen: null

    readonly property bool anim: !Perf.reduceMotion
    readonly property int memPct: pill.root ? pill.root.systemMemPercent : 0
    readonly property bool musicPlaying: Media.playing
    readonly property bool musicPresent: Media.present
    readonly property bool expanded: pill.root ? pill.root.dashboardVisible : false

    // Live Activity transient state
    property bool liveActive: false
    property string liveKind: ""      // "battery" | "bt" | "record" | "focus" | "coffee" | "notif" | "timer"
    property string liveTitle: ""
    property string liveDetail: ""
    property color liveColor: nt.accent
    property string liveIcon: "bolt"

    // Previous values for edge-triggered live animations (guarded after init)
    property bool _ready: false
    property bool _prevCharging: Battery.charging
    property bool _prevLow: Battery.low
    property int _prevBtConnected: 0
    property bool _prevDnd: Flags.dnd
    property bool _prevAwake: Flags.keepAwake
    property bool _prevRec: Recorder.active
    property double _prevNotifMs: Notifs.arrivalMs
    property bool _prevTimerPulse: NotchTimerState.finishedPulse

    readonly property var btConnectedNames: {
        var list = BluetoothPower.devices || [];
        var names = [];
        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            if (d && d.connected)
                names.push(d.name || d.deviceName || "Bluetooth");
        }
        return names;
    }

    function triggerLive(kind, icon, title, detail, col, sticky) {
        if (!NotchConfig.liveActivities || pill.expanded) return;
        pill.liveKind = kind;
        pill.liveIcon = icon;
        pill.liveTitle = title;
        pill.liveDetail = detail;
        pill.liveColor = col;
        pill.liveActive = true;
        if (sticky) {
            liveTimer.stop();
        } else {
            liveTimer.restart();
        }
    }

    function clearLive() {
        liveTimer.stop();
        if (Recorder.active && NotchConfig.liveActivities) {
            pill.liveKind = "record";
            pill.liveIcon = "radio_button_checked";
            pill.liveTitle = I18n.tr("REC");
            pill.liveDetail = Recorder.elapsedText;
            pill.liveColor = nt.danger;
            pill.liveActive = true;
            return;
        }
        pill.liveActive = false;
    }

    Timer {
        id: liveTimer
        interval: 3200
        repeat: false
        onTriggered: pill.clearLive()
    }

    Timer {
        id: initGuard
        interval: 1500
        running: true
        repeat: false
        onTriggered: {
            pill._prevCharging = Battery.charging;
            pill._prevLow = Battery.low;
            pill._prevBtConnected = pill.btConnectedNames.length;
            pill._prevDnd = Flags.dnd;
            pill._prevAwake = Flags.keepAwake;
            pill._prevRec = Recorder.active;
            pill._prevNotifMs = Notifs.arrivalMs;
            pill._prevTimerPulse = NotchTimerState.finishedPulse;
            pill._ready = true;
            if (Recorder.active && NotchConfig.liveActivities) {
                pill.triggerLive("record", "radio_button_checked", I18n.tr("REC"), Recorder.elapsedText, nt.danger, true);
            }
        }
    }

    Connections {
        target: Battery
        function onChargingChanged() {
            if (!pill._ready) return;
            if (Battery.charging && !pill._prevCharging) {
                pill.triggerLive("battery", "battery_charging_full", I18n.tr("Charging"), Battery.pct + "%", nt.success, false);
            }
            pill._prevCharging = Battery.charging;
        }
        function onLowChanged() {
            if (!pill._ready) return;
            if (Battery.low && !pill._prevLow) {
                pill.triggerLive("battery", "battery_alert", I18n.tr("Low Battery"), Battery.pct + "%", nt.danger, false);
            }
            pill._prevLow = Battery.low;
        }
    }

    onBtConnectedNamesChanged: {
        if (!pill._ready) return;
        var count = pill.btConnectedNames.length;
        if (count > pill._prevBtConnected && count > 0) {
            pill.triggerLive("bt", "bluetooth_connected", pill.btConnectedNames[count - 1], I18n.tr("Connected"), nt.accent, false);
        } else if (count < pill._prevBtConnected) {
            pill.triggerLive("bt", "bluetooth", I18n.tr("Bluetooth"), I18n.tr("Disconnected"), nt.muted, false);
        }
        pill._prevBtConnected = count;
    }

    Connections {
        target: Flags
        function onDndChanged() {
            if (!pill._ready || Flags.dnd === pill._prevDnd) return;
            pill._prevDnd = Flags.dnd;
            pill.triggerLive("focus", Flags.dnd ? "dark_mode" : "notifications_active",
                I18n.tr("Focus"), Flags.dnd ? I18n.tr("On") : I18n.tr("Off"),
                Flags.dnd ? nt.accent : nt.muted, false);
        }
        function onKeepAwakeChanged() {
            if (!pill._ready || Flags.keepAwake === pill._prevAwake) return;
            pill._prevAwake = Flags.keepAwake;
            pill.triggerLive("coffee", "local_cafe",
                I18n.tr("Coffee"), Flags.keepAwake ? I18n.tr("Awake") : I18n.tr("Off"),
                Flags.keepAwake ? nt.warning : nt.muted, false);
        }
    }

    Connections {
        target: Recorder
        function onActiveChanged() {
            if (!pill._ready) return;
            pill._prevRec = Recorder.active;
            if (Recorder.active) {
                pill.triggerLive("record", "radio_button_checked", I18n.tr("REC"), Recorder.elapsedText, nt.danger, true);
            } else {
                pill.triggerLive("record", "stop_circle", I18n.tr("Recording"), I18n.tr("Saved"), nt.success, false);
            }
        }
        function onElapsedTextChanged() {
            if (pill.liveActive && pill.liveKind === "record" && Recorder.active)
                pill.liveDetail = Recorder.elapsedText;
        }
    }

    Connections {
        target: Notifs
        function onArrivalMsChanged() {
            if (!pill._ready) return;
            if (Notifs.arrivalMs <= pill._prevNotifMs) return;
            pill._prevNotifMs = Notifs.arrivalMs;
            if (!NotchConfig.notifInNotch) return;
            if (Notifs.dnd && !NotchConfig.notifShowWhileDnd) return;
            var hist = Notifs.history || [];
            if (hist.length === 0) return;
            var latest = hist[0];
            var app = String((latest && (latest.appName || latest.app)) || I18n.tr("Notification"));
            var body = String((latest && (latest.summary || latest.body)) || "");
            if (app.length > 16) app = app.slice(0, 15) + "…";
            if (body.length > 26) body = body.slice(0, 25) + "…";
            pill.triggerLive("notif", "notifications", app, body, nt.accent, false);
            if (!Notifs.dnd)
                NotchConfig.playSound(NotchConfig.notifSound);
        }
    }

    Connections {
        target: NotchTimerState
        function onFinishedPulseChanged() {
            if (!pill._ready) return;
            if (NotchTimerState.finishedPulse && !pill._prevTimerPulse) {
                pill.triggerLive("timer", "timer", I18n.tr("Timer"), I18n.tr("Time's up!"), nt.accent, false);
            }
            pill._prevTimerPulse = NotchTimerState.finishedPulse;
        }
    }

    NotchTheme { id: nt; root: pill.root }

    // Claim AudioBars only while playing & visible in idle pill
    readonly property bool wantsBars: pill.musicPlaying && !pill.expanded && !pill.liveActive && !Perf.reduceMotion
    onWantsBarsChanged: AudioBars.setActive(pill, pill.wantsBars)
    Component.onCompleted: AudioBars.setActive(pill, pill.wantsBars)
    Component.onDestruction: AudioBars.setActive(pill, false)

    // Fallback wave phase if Cava feed is temporarily quiet while playing
    property real wavePhase: 0
    Timer {
        interval: 90
        repeat: true
        running: pill.wantsBars && AudioBars.silent
        onTriggered: pill.wavePhase = (pill.wavePhase + 0.45) % (Math.PI * 2)
    }

    SystemClock { id: sysClock; precision: SystemClock.Minutes }
    readonly property string timeText: {
        var d = sysClock.date;
        var m = String(d.getMinutes()).padStart(2, "0");
        if (TimeFormat.is24h)
            return String(d.getHours()).padStart(2, "0") + ":" + m;
        var h12 = d.getHours() % 12;
        if (h12 === 0) h12 = 12;
        return h12 + ":" + m;
    }

    readonly property real targetWidth: Math.round((pill.liveActive ? liveRow.implicitWidth : idleRow.implicitWidth) + 22)
    implicitWidth: pill.targetWidth
    implicitHeight: 28

    Behavior on implicitWidth {
        enabled: pill.anim
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    opacity: pill.expanded ? 0.0 : 1.0
    scale: pill.expanded ? 0.86 : 1.0
    Behavior on opacity {
        enabled: pill.anim
        NumberAnimation { duration: pill.expanded ? 120 : 200; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        enabled: pill.anim
        NumberAnimation { duration: pill.expanded ? 140 : 240; easing.type: pill.expanded ? Easing.InCubic : Easing.OutBack; easing.overshoot: 0.7 }
    }

    function openNotch() {
        if (!pill.root) return;
        if (pill.screen) pill.root.activatePopupScreen(pill.screen);
        pill.root.openDashboard();
    }

    Timer {
        id: hoverOpenTimer
        interval: 220
        repeat: false
        onTriggered: {
            if (ma.containsMouse && NotchConfig.openOnHover && !pill.expanded)
                pill.openNotch();
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: if (NotchConfig.openOnHover && !pill.expanded) hoverOpenTimer.restart()
        onExited: hoverOpenTimer.stop()
        onClicked: e => {
            if (e.button === Qt.RightButton)
                TimeFormat.set24h(!TimeFormat.is24h);
            else
                pill.openNotch();
        }
    }

    // ── Idle view: [RAM ring]  [Clock]  [Visualizer / Music icon] ───────────
    Row {
        id: idleRow
        anchors.centerIn: parent
        spacing: 10
        opacity: pill.liveActive ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity {
            enabled: pill.anim
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        // 1. RAM usage circular ring
        Item {
            width: 15
            height: 15
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: ramRing
                anchors.fill: parent
                property real ratio: Math.max(0, Math.min(1, pill.memPct / 100))
                property color ringColor: pill.memPct >= 90 ? nt.danger
                    : (pill.memPct >= 75 ? nt.warning : nt.success)

                Behavior on ratio {
                    enabled: pill.anim
                    NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                }
                onRatioChanged: requestPaint()
                onRingColorChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    var cx = width / 2;
                    var cy = height / 2;
                    var r = (width / 2) - 1.6;
                    ctx.lineWidth = 2.1;
                    ctx.lineCap = "round";

                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    ctx.strokeStyle = Qt.rgba(nt.ink.r, nt.ink.g, nt.ink.b, 0.16);
                    ctx.stroke();

                    if (ratio > 0.01) {
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * ratio);
                        ctx.strokeStyle = ringColor;
                        ctx.stroke();
                    }
                }
            }
        }

        // 2. Clock
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.timeText
            color: pill.root ? pill.root.ink : nt.ink
            font.family: nt.monoFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        // 2b. Compact Timer countdown pill while running in background
        Rectangle {
            visible: NotchTimerState.running
            anchors.verticalCenter: parent.verticalCenter
            width: timerMiniRow.implicitWidth + 10
            height: 18
            radius: 9
            color: Qt.rgba(nt.accent.r, nt.accent.g, nt.accent.b, 0.20)
            Row {
                id: timerMiniRow
                anchors.centerIn: parent
                spacing: 3
                NotchIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "timer"
                    font.pixelSize: 11
                    color: nt.accent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: NotchTimerState.formatted
                    color: nt.ink
                    font.family: nt.monoFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }
        }

        // 3. Now Playing visualizer OR music icon
        Item {
            width: 16
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            // Animated 4-bar visualizer when playing
            Row {
                anchors.centerIn: parent
                spacing: 1.8
                visible: pill.musicPlaying
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2.2
                        radius: 1.1
                        color: pill.root ? pill.root.ink : nt.ink
                        readonly property real sampleLevel: {
                            if (!pill.musicPlaying) return 0.2;
                            if (!AudioBars.silent && AudioBars.levels && AudioBars.levels.length > 0) {
                                var band = Math.min(AudioBars.levels.length - 1, 2 + index * 6);
                                return Math.max(0.22, Math.min(1.0, Number(AudioBars.levels[band] || 0.25)));
                            }
                            return 0.35 + 0.45 * Math.abs(Math.sin(pill.wavePhase + index * 0.9));
                        }
                        height: Math.round(3 + sampleLevel * 10)
                        Behavior on height {
                            enabled: pill.anim
                            NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }

            // Static music note icon when not playing
            NotchIcon {
                anchors.centerIn: parent
                visible: !pill.musicPlaying
                text: "music_note"
                font.pixelSize: 14
                fill: pill.musicPresent ? 1 : 0
                color: pill.musicPresent
                    ? (pill.root ? pill.root.seal : nt.accent)
                    : Qt.rgba(nt.ink.r, nt.ink.g, nt.ink.b, 0.55)
            }
        }
    }

    // ── Live Activity Morph view ─────────────────────────────────────────────
    Row {
        id: liveRow
        anchors.centerIn: parent
        spacing: 7
        opacity: pill.liveActive ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            enabled: pill.anim
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        NotchIcon {
            id: liveGlyph
            anchors.verticalCenter: parent.verticalCenter
            text: pill.liveIcon
            font.pixelSize: 15
            fill: 1
            color: pill.liveColor

            SequentialAnimation on opacity {
                running: pill.liveActive && pill.anim && (pill.liveKind === "record" || pill.liveKind === "battery")
                loops: Animation.Infinite
                alwaysRunToEnd: false
                NumberAnimation { from: 1.0; to: 0.45; duration: 650; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.45; to: 1.0; duration: 650; easing.type: Easing.InOutSine }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.liveTitle
            color: nt.ink
            font.family: Tokens.ui
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.liveDetail !== ""
            text: pill.liveDetail
            color: nt.muted
            font.family: nt.monoFont
            font.pixelSize: 11
        }
    }
}
