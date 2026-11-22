pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons

// Persistent state for the Dynamic Notch Teleprompter so script text, font,
// WPM, and live playback state survive closing/reopening the Notch.
Singleton {
    id: tp

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku"

    property string scriptText: "Welcome to Tsukuyomi OS.\n\nKeep your cadence steady, breathe between sections, and let the Dynamic Notch handle your controls, media, health reminders, and live telemetry without leaving your workspace.\n\nAdjust WPM, font size, or typeface anytime from the top HUD bar."
    property int fontSize: 18
    property string fontPreset: "sans"    // "sans" | "mono" | "serif"
    property int wpm: 140
    property bool mirrorX: false
    property int scalePct: 100            // 100 | 130 | 160
    property bool focusMode: false
    property bool playing: false
    property bool editMode: false
    property real scrollY: 0

    readonly property string fontFamilyName: {
        if (tp.fontPreset === "mono") return Tokens.mono;
        if (tp.fontPreset === "serif") return "Georgia";
        return Tokens.ui;
    }

    readonly property string fontDisplayLabel: {
        if (tp.fontPreset === "mono") return "Mono";
        if (tp.fontPreset === "serif") return "Serif";
        return "Sans";
    }

    readonly property int wordCount: {
        var t = String(tp.scriptText || "").trim();
        if (t === "") return 0;
        return t.split(/\s+/).length;
    }

    readonly property string etaText: {
        var wc = tp.wordCount;
        if (wc === 0) return "0:00";
        var totalSec = Math.max(1, Math.round((wc / Math.max(40, tp.wpm)) * 60));
        var m = Math.floor(totalSec / 60);
        var s = totalSec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function cycleFont() {
        if (tp.fontPreset === "sans") tp.fontPreset = "mono";
        else if (tp.fontPreset === "mono") tp.fontPreset = "serif";
        else tp.fontPreset = "sans";
        tp.persist();
    }

    function adjustFontSize(delta) {
        tp.fontSize = Math.max(12, Math.min(34, tp.fontSize + delta));
        tp.persist();
    }

    function adjustWpm(delta) {
        tp.wpm = Math.max(60, Math.min(280, tp.wpm + delta));
        tp.persist();
    }

    function cycleScale() {
        if (tp.scalePct === 100) tp.scalePct = 130;
        else if (tp.scalePct === 130) tp.scalePct = 160;
        else tp.scalePct = 100;
        tp.persist();
    }

    function toggleFocusMode() {
        tp.focusMode = !tp.focusMode;
        if (tp.focusMode && tp.scalePct === 100)
            tp.scalePct = 130;
        tp.persist();
    }

    function setScript(txt) {
        tp.scriptText = String(txt || "");
        tp.scrollY = 0;
        tp.persist();
    }

    function persist() {
        file.setText(JSON.stringify({
            scriptText: tp.scriptText,
            fontSize: tp.fontSize,
            fontPreset: tp.fontPreset,
            wpm: tp.wpm,
            mirrorX: tp.mirrorX,
            scalePct: tp.scalePct,
            focusMode: tp.focusMode
        }));
    }

    FileView {
        id: file
        path: tp.stateDir + "/notch-teleprompter.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", tp.stateDir]);
        var raw = file.text();
        if (raw) {
            try {
                var parsed = JSON.parse(raw);
                if (typeof parsed.scriptText === "string") tp.scriptText = parsed.scriptText;
                if (parsed.fontSize) tp.fontSize = Math.max(12, Math.min(34, Number(parsed.fontSize)));
                if (parsed.fontPreset) tp.fontPreset = String(parsed.fontPreset);
                if (parsed.wpm) tp.wpm = Math.max(60, Math.min(280, Number(parsed.wpm)));
                if (parsed.mirrorX !== undefined) tp.mirrorX = !!parsed.mirrorX;
                if (parsed.scalePct === 100 || parsed.scalePct === 130 || parsed.scalePct === 160) tp.scalePct = parsed.scalePct;
                if (parsed.focusMode !== undefined) tp.focusMode = !!parsed.focusMode;
            } catch (e) {}
        }
    }
}
