pragma Singleton
import QtQuick
import Quickshell
import Ryoku.Ui.Singletons

// Background-running timer engine shared between NotchTimerTab and NotchCenterPill
// so Pomodoro, Countdown Timer, and Stopwatch keep ticking while Notch is closed.
Singleton {
    id: ts

    property string mode: "pomodoro"       // "pomodoro" | "timer" | "stopwatch"
    property string pomoPhase: "focus"     // "focus" | "short" | "long"
    property int pomoCycle: 0              // 0..3 completed focus sessions
    property int focusMinutes: 25
    property int shortBreakMinutes: 5
    property int longBreakMinutes: 15

    property int timerTotalSec: 15 * 60
    property int remainingSec: 25 * 60
    property int stopwatchSec: 0
    property var laps: []
    property bool running: false
    property bool finishedPulse: false

    readonly property int totalDurationSec: {
        if (ts.mode === "pomodoro") {
            if (ts.pomoPhase === "short") return ts.shortBreakMinutes * 60;
            if (ts.pomoPhase === "long") return ts.longBreakMinutes * 60;
            return ts.focusMinutes * 60;
        }
        if (ts.mode === "timer") return Math.max(5, ts.timerTotalSec);
        return 60;
    }

    readonly property real progress: {
        if (ts.mode === "stopwatch")
            return (ts.stopwatchSec % 60) / 60;
        var tot = Math.max(1, ts.totalDurationSec);
        return Math.max(0, Math.min(1, 1 - (ts.remainingSec / tot)));
    }

    readonly property string phaseLabel: {
        if (ts.mode === "stopwatch") return I18n.tr("STOPWATCH");
        if (ts.mode === "timer") return I18n.tr("TIMER");
        if (ts.pomoPhase === "short") return I18n.tr("SHORT BREAK");
        if (ts.pomoPhase === "long") return I18n.tr("LONG BREAK");
        return I18n.tr("FOCUS");
    }

    readonly property string formatted: {
        var sec = ts.mode === "stopwatch" ? ts.stopwatchSec : ts.remainingSec;
        var h = Math.floor(sec / 3600);
        var m = Math.floor((sec % 3600) / 60);
        var s = sec % 60;
        var mm = (m < 10 ? "0" : "") + m;
        var ss = (s < 10 ? "0" : "") + s;
        return h > 0 ? (h + ":" + mm + ":" + ss) : (mm + ":" + ss);
    }

    function setMode(nextMode) {
        if (ts.mode === nextMode) return;
        ts.running = false;
        ts.finishedPulse = false;
        ts.mode = nextMode;
        if (nextMode === "pomodoro")
            ts.remainingSec = ts.totalDurationSec;
        else if (nextMode === "timer")
            ts.remainingSec = ts.timerTotalSec;
    }

    function setPomoPhase(phase) {
        ts.running = false;
        ts.finishedPulse = false;
        ts.pomoPhase = phase;
        ts.remainingSec = ts.totalDurationSec;
    }

    function setFocusMinutes(mins) {
        ts.focusMinutes = Math.max(5, Math.min(120, Math.round(mins)));
        if (!ts.running && ts.mode === "pomodoro" && ts.pomoPhase === "focus")
            ts.remainingSec = ts.focusMinutes * 60;
    }

    function setTimerMinutes(mins) {
        var clamped = Math.max(1, Math.min(180, Math.round(mins)));
        ts.setTimerSeconds(clamped * 60);
    }

    function setTimerSeconds(totalSec) {
        var clamped = Math.max(5, Math.min(35999, Math.round(totalSec)));
        ts.running = false;
        ts.finishedPulse = false;
        ts.mode = "timer";
        ts.timerTotalSec = clamped;
        ts.remainingSec = clamped;
    }

    function adjustTimerMinutes(delta) {
        var cur = Math.round(ts.timerTotalSec / 60);
        ts.setTimerMinutes(cur + delta);
    }

    function toggle() {
        ts.finishedPulse = false;
        if (ts.mode !== "stopwatch" && ts.remainingSec <= 0)
            ts.remainingSec = ts.totalDurationSec;
        ts.running = !ts.running;
    }

    function reset() {
        ts.running = false;
        ts.finishedPulse = false;
        if (ts.mode === "stopwatch") {
            ts.stopwatchSec = 0;
            ts.laps = [];
        } else {
            ts.remainingSec = ts.totalDurationSec;
        }
    }

    function addLap() {
        if (ts.mode !== "stopwatch") return;
        var next = ts.laps.slice();
        next.unshift(ts.formatted);
        if (next.length > 8) next = next.slice(0, 8);
        ts.laps = next;
    }

    function skip() {
        if (ts.mode !== "pomodoro") {
            ts.reset();
            return;
        }
        ts.running = false;
        ts.finishedPulse = false;
        if (ts.pomoPhase === "focus") {
            var nextCycle = (ts.pomoCycle + 1) % 4;
            ts.pomoCycle = nextCycle;
            ts.pomoPhase = nextCycle === 0 ? "long" : "short";
        } else {
            ts.pomoPhase = "focus";
        }
        ts.remainingSec = ts.totalDurationSec;
    }

    function completeCountdown() {
        ts.running = false;
        NotchConfig.playSound(NotchConfig.timerRingtone);
        var msg = ts.mode === "pomodoro"
            ? (ts.pomoPhase === "focus" ? I18n.tr("Focus session complete — take a break!") : I18n.tr("Break finished — back to focus!"))
            : I18n.tr("Timer finished");
        Quickshell.execDetached(["sh", "-c",
            "command -v notify-send >/dev/null 2>&1 && notify-send -a 'Tsukuyomi Notch' \"$1\" \"$2\" || true",
            "_", ts.phaseLabel, msg]);
        if (ts.mode === "pomodoro") {
            if (ts.pomoPhase === "focus") {
                var nextCycle = (ts.pomoCycle + 1) % 4;
                ts.pomoCycle = nextCycle;
                ts.pomoPhase = nextCycle === 0 ? "long" : "short";
            } else {
                ts.pomoPhase = "focus";
            }
            ts.remainingSec = ts.totalDurationSec;
        }
        ts.finishedPulse = true;
        pulseClear.restart();
    }

    Timer {
        id: pulseClear
        interval: 4500
        onTriggered: ts.finishedPulse = false
    }

    Timer {
        id: ticker
        interval: 1000
        repeat: true
        running: ts.running
        onTriggered: {
            if (ts.mode === "stopwatch") {
                ts.stopwatchSec += 1;
            } else if (ts.remainingSec > 1) {
                ts.remainingSec -= 1;
            } else {
                ts.remainingSec = 0;
                ts.completeCountdown();
            }
        }
    }
}
