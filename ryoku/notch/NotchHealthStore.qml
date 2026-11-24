pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Daily Health tracker (Water glasses + hourly chart, Movement breaks,
// Guided 4-4-6 Breathing, 20-20-20 Eye break) persisted per date.
Singleton {
    id: hs

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku"

    property string dateKey: ""
    property int waterGlasses: 0
    property int waterGoal: 8
    property int movementDone: 0
    property int movementGoal: 6
    property int breathingDone: 0
    property int breathingGoal: 5
    property int eyeDone: 0
    property int streakDays: 1
    property var waterHourly: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    property real lastBreakMs: 0
    property bool waterReminderEnabled: true

    // Active guided session ("none" | "movement" | "breathing" | "eye")
    property string activeSession: "none"
    property int sessionSecLeft: 0
    property int sessionTotalSec: 1

    readonly property int mlPerGlass: 250
    readonly property real waterLiters: (hs.waterGlasses * hs.mlPerGlass) / 1000.0
    readonly property real waterGoalLiters: (hs.waterGoal * hs.mlPerGlass) / 1000.0
    readonly property real waterFrac: Math.min(1, hs.waterGlasses / Math.max(1, hs.waterGoal))
    readonly property real moveFrac: Math.min(1, hs.movementDone / Math.max(1, hs.movementGoal))
    readonly property real breathFrac: Math.min(1, hs.breathingDone / Math.max(1, hs.breathingGoal))

    readonly property string breathingCue: {
        if (hs.activeSession !== "breathing") return "";
        var elapsed = hs.sessionTotalSec - hs.sessionSecLeft;
        var cycle = elapsed % 14; // 4s inhale, 4s hold, 6s exhale
        if (cycle < 4) return "Inhale";
        if (cycle < 8) return "Hold";
        return "Exhale";
    }

    function todayStr() {
        var d = new Date();
        var m = d.getMonth() + 1;
        var day = d.getDate();
        return d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (day < 10 ? "0" : "") + day;
    }

    function ensureToday() {
        var t = hs.todayStr();
        if (hs.dateKey === t) return;
        if (hs.dateKey !== "" && (hs.waterGlasses > 0 || hs.movementDone > 0 || hs.breathingDone > 0))
            hs.streakDays += 1;
        hs.dateKey = t;
        hs.waterGlasses = 0;
        hs.movementDone = 0;
        hs.breathingDone = 0;
        hs.eyeDone = 0;
        hs.waterHourly = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
        hs.persist();
    }

    function addWater(delta) {
        hs.ensureToday();
        var next = Math.max(0, Math.min(24, hs.waterGlasses + delta));
        if (next === hs.waterGlasses) return;
        hs.waterGlasses = next;
        var hr = (new Date()).getHours();
        var buckets = hs.waterHourly.slice();
        while (buckets.length < 24) buckets.push(0);
        buckets[hr] = Math.max(0, Number(buckets[hr] || 0) + delta * hs.mlPerGlass);
        hs.waterHourly = buckets;
        hs.persist();
    }

    function startSession(kind) {
        hs.ensureToday();
        if (hs.activeSession === kind) {
            hs.activeSession = "none";
            sessionTimer.stop();
            return;
        }
        hs.activeSession = kind;
        if (kind === "movement") hs.sessionTotalSec = 120;
        else if (kind === "breathing") hs.sessionTotalSec = 56;
        else hs.sessionTotalSec = 20;
        hs.sessionSecLeft = hs.sessionTotalSec;
        sessionTimer.restart();
    }

    function finishSession() {
        sessionTimer.stop();
        var k = hs.activeSession;
        hs.activeSession = "none";
        hs.lastBreakMs = Date.now();
        if (k === "movement") hs.movementDone += 1;
        else if (k === "breathing") hs.breathingDone += 1;
        else if (k === "eye") hs.eyeDone += 1;
        hs.persist();
    }

    Timer {
        id: sessionTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (hs.sessionSecLeft > 1) hs.sessionSecLeft -= 1;
            else hs.finishSession();
        }
    }

    property bool _suppressReload: false

    Timer {
        id: suppressClear
        interval: 350
        onTriggered: hs._suppressReload = false
    }

    function persist() {
        hs._suppressReload = true;
        suppressClear.restart();
        file.setText(JSON.stringify({
            dateKey: hs.dateKey,
            waterGlasses: hs.waterGlasses,
            waterGoal: hs.waterGoal,
            movementDone: hs.movementDone,
            movementGoal: hs.movementGoal,
            breathingDone: hs.breathingDone,
            breathingGoal: hs.breathingGoal,
            eyeDone: hs.eyeDone,
            streakDays: hs.streakDays,
            waterHourly: hs.waterHourly,
            lastBreakMs: hs.lastBreakMs,
            waterReminderEnabled: hs.waterReminderEnabled
        }));
    }

    function reloadFromDisk() {
        try {
            var raw = file.text();
            if (!raw || raw.trim() === "") {
                hs.ensureToday();
                return;
            }
            var o = JSON.parse(raw);
            hs.dateKey = String(o.dateKey || "");
            hs.waterGlasses = Number(o.waterGlasses || 0);
            hs.waterGoal = Math.max(1, Number(o.waterGoal || 8));
            hs.movementDone = Number(o.movementDone || 0);
            hs.movementGoal = Math.max(1, Number(o.movementGoal || 6));
            hs.breathingDone = Number(o.breathingDone || 0);
            hs.breathingGoal = Math.max(1, Number(o.breathingGoal || 5));
            hs.eyeDone = Number(o.eyeDone || 0);
            hs.streakDays = Math.max(1, Number(o.streakDays || 1));
            hs.waterHourly = Array.isArray(o.waterHourly) && o.waterHourly.length === 24
                ? o.waterHourly : [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
            hs.lastBreakMs = Number(o.lastBreakMs || 0);
            hs.waterReminderEnabled = o.waterReminderEnabled !== false;
            hs.ensureToday();
        } catch (e) {
            hs.ensureToday();
        }
    }

    Process {
        command: ["mkdir", "-p", hs.stateDir]
        running: true
    }

    FileView {
        id: file
        path: hs.stateDir + "/notch-health.json"
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: {
            if (!hs._suppressReload) reload();
        }
        onLoaded: {
            if (!hs._suppressReload) hs.reloadFromDisk();
        }
        onLoadFailed: hs.ensureToday()
    }
}
