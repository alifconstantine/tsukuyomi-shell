pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent ToDo list with optional HH:MM scheduling for the Timeline view.
// Stored atomically at ~/.local/state/ryoku/notch-todo.json.
Singleton {
    id: store

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku"
    property var items: []
    property int nextId: 1

    readonly property int doneCount: {
        var n = 0;
        for (var i = 0; i < store.items.length; i++)
            if (store.items[i] && store.items[i].done) n++;
        return n;
    }

    readonly property var timelineItems: {
        var out = store.items.slice();
        out.sort(function(a, b) {
            var at = (a && a.time) ? String(a.time) : "99:99";
            var bt = (b && b.time) ? String(b.time) : "99:99";
            if (at !== bt) return at < bt ? -1 : 1;
            return Number(a.id || 0) - Number(b.id || 0);
        });
        return out;
    }

    function normalizeTime(raw) {
        var m = String(raw || "").trim().match(/^(\d{1,2}):(\d{2})$/);
        if (!m) return "";
        var hh = parseInt(m[1], 10);
        var mm = parseInt(m[2], 10);
        if (hh < 0 || hh > 23 || mm < 0 || mm > 59) return "";
        return (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm;
    }

    function addTask(text, timeStr) {
        var clean = String(text || "").trim();
        if (clean === "") return;
        var next = store.items.slice();
        next.unshift({
            id: store.nextId,
            text: clean,
            time: store.normalizeTime(timeStr),
            done: false
        });
        store.nextId += 1;
        store.items = next;
        store.persist();
    }

    function toggleTask(id) {
        var next = [];
        for (var i = 0; i < store.items.length; i++) {
            var it = store.items[i];
            if (it && it.id === id)
                next.push({ id: it.id, text: it.text, time: it.time || "", done: !it.done });
            else
                next.push(it);
        }
        store.items = next;
        store.persist();
    }

    function removeTask(id) {
        store.items = store.items.filter(function(it) { return it && it.id !== id; });
        store.persist();
    }

    function clearDone() {
        store.items = store.items.filter(function(it) { return it && !it.done; });
        store.persist();
    }

    function persist() {
        file.setText(JSON.stringify({ nextId: store.nextId, items: store.items }));
    }

    function reloadFromDisk() {
        try {
            var raw = file.text();
            if (!raw || raw.trim() === "") return;
            var obj = JSON.parse(raw);
            var arr = Array.isArray(obj.items) ? obj.items : [];
            var maxId = 0;
            for (var i = 0; i < arr.length; i++)
                if (Number(arr[i].id || 0) > maxId) maxId = Number(arr[i].id);
            store.nextId = Math.max(Number(obj.nextId || 1), maxId + 1);
            store.items = arr;
        } catch (e) {
            store.items = [];
        }
    }

    Process {
        command: ["mkdir", "-p", store.stateDir]
        running: true
    }

    FileView {
        id: file
        path: store.stateDir + "/notch-todo.json"
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: store.reloadFromDisk()
    }
}
