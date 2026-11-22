import QtQuick
import Quickshell
import Quickshell.Io
import shell.services
import Ryoku.Ui.Singletons

// Clipboard tab: newest-first clipboard history from ryoku-shell (Clipboard.qml).
// Supports 1-click paste/copy icon per row, Pin (star), Select mode for
// batch Pin / Delete, search filter, and Clear.
Item {
    id: cb

    property var root: null
    property var theme: _fallbackTheme
    NotchTheme { id: _fallbackTheme; root: null }
    readonly property bool anim: !Perf.reduceMotion

    property string query: ""
    property bool selectMode: false
    property var selectedIds: ({})
    property string copiedId: ""

    readonly property var filteredEntries: {
        var list = Clipboard.entries || [];
        var q = cb.query.trim().toLowerCase();
        var out = [];
        for (var i = 0; i < list.length; i++) {
            var e = list[i];
            if (!e) continue;
            if (q !== "") {
                var text = String(e.preview || e.mime || "").toLowerCase();
                if (text.indexOf(q) < 0) continue;
            }
            out.push(e);
        }
        return out;
    }

    readonly property bool allSelected: {
        if (cb.filteredEntries.length === 0) return false;
        for (var i = 0; i < cb.filteredEntries.length; i++) {
            var e = cb.filteredEntries[i];
            if (e && !cb.selectedIds[e.id]) return false;
        }
        return true;
    }

    function toggleSelectAll() {
        if (cb.allSelected) {
            cb.selectedIds = ({});
            return;
        }
        var next = {};
        for (var i = 0; i < cb.filteredEntries.length; i++) {
            var e = cb.filteredEntries[i];
            if (e && e.id) next[e.id] = true;
        }
        cb.selectedIds = next;
    }

    Process {
        id: pasteSyncProc
        command: ["sh", "-c", "t=$(wl-paste -n 2>/dev/null || true); [ -n \"$t\" ] && wl-copy -- \"$t\""]
    }

    readonly property int selectedCount: {
        var n = 0;
        for (var k in cb.selectedIds)
            if (cb.selectedIds[k]) n++;
        return n;
    }

    function toggleSelect(id) {
        var next = Object.assign({}, cb.selectedIds);
        if (next[id]) delete next[id];
        else next[id] = true;
        cb.selectedIds = next;
    }

    function clearSelection() {
        cb.selectedIds = ({});
        cb.selectMode = false;
    }

    function copyEntry(id) {
        Clipboard.copy(id);
        cb.copiedId = id;
        copiedReset.restart();
    }

    function deleteSelected() {
        for (var k in cb.selectedIds) {
            if (cb.selectedIds[k]) Clipboard.del(k);
        }
        cb.clearSelection();
    }

    function pinSelected() {
        for (var k in cb.selectedIds) {
            if (cb.selectedIds[k]) Clipboard.star(k, true);
        }
        cb.clearSelection();
    }

    Timer {
        id: copiedReset
        interval: 1200
        onTriggered: cb.copiedId = ""
    }

    Column {
        anchors.fill: parent
        spacing: 8

        // ── Top bar: Search · Paste · Select (or Select All · Pin · Delete · Done) ─
        Row {
            width: parent.width
            height: 28
            spacing: 6

            // Search box
            Rectangle {
                width: cb.selectMode ? Math.max(120, parent.width - 236) : Math.max(160, parent.width - 134)
                height: 28
                radius: 9
                color: cb.theme.card
                border.width: 1
                border.color: searchInput.activeFocus ? cb.theme.accent : cb.theme.border

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    NotchIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        font.pixelSize: 14
                        color: cb.theme.muted
                    }

                    TextInput {
                        id: searchInput
                        width: parent.width - 36
                        anchors.verticalCenter: parent.verticalCenter
                        color: cb.theme.ink
                        font.family: Tokens.ui
                        font.pixelSize: 11
                        clip: true
                        selectByMouse: true
                        onTextChanged: cb.query = text

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text === ""
                            text: I18n.tr("Search clipboard…")
                            color: cb.theme.muted
                            font.family: Tokens.ui
                            font.pixelSize: 11
                        }
                    }

                    NotchIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text !== ""
                        text: "close"
                        font.pixelSize: 13
                        color: cb.theme.muted
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: searchInput.text = ""
                        }
                    }
                }
            }

            // Paste pill (default view)
            Rectangle {
                visible: !cb.selectMode
                width: 64; height: 28; radius: 9
                color: pasteTopMa.containsMouse ? cb.theme.cardHover : cb.theme.card
                border.width: 1
                border.color: cb.theme.border

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    NotchIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "content_paste"
                        font.pixelSize: 13
                        color: cb.theme.ink
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Paste")
                        color: cb.theme.ink
                        font.family: Tokens.ui
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }
                }
                MouseArea {
                    id: pasteTopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pasteSyncProc.running = true
                }
            }

            // Select All (in Select mode)
            Rectangle {
                visible: cb.selectMode
                width: 72; height: 28; radius: 9
                color: cb.allSelected
                    ? Qt.rgba(cb.theme.accent.r, cb.theme.accent.g, cb.theme.accent.b, 0.22)
                    : (selAllMa.containsMouse ? cb.theme.cardHover : cb.theme.card)
                border.width: 1
                border.color: cb.allSelected ? cb.theme.accent : cb.theme.border
                Text {
                    anchors.centerIn: parent
                    text: cb.allSelected ? I18n.tr("Unselect") : I18n.tr("Select All")
                    color: cb.theme.ink
                    font.family: Tokens.ui
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: selAllMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cb.toggleSelectAll()
                }
            }

            // Batch Pin / Delete when in Select mode
            Rectangle {
                visible: cb.selectMode
                width: 44; height: 28; radius: 9
                opacity: cb.selectedCount > 0 ? 1 : 0.4
                color: batchPinMa.containsMouse ? cb.theme.cardHover : cb.theme.card
                border.width: 1
                border.color: cb.theme.border
                Row {
                    anchors.centerIn: parent
                    spacing: 2
                    NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "push_pin"; font.pixelSize: 12; fill: 1; color: cb.theme.ink }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Pin"); color: cb.theme.ink; font.family: Tokens.ui; font.pixelSize: 10 }
                }
                MouseArea {
                    id: batchPinMa
                    anchors.fill: parent
                    enabled: cb.selectedCount > 0
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: cb.pinSelected()
                }
            }
            Rectangle {
                visible: cb.selectMode
                width: 48; height: 28; radius: 9
                opacity: cb.selectedCount > 0 ? 1 : 0.4
                color: batchDelMa.containsMouse ? Qt.rgba(cb.theme.danger.r, cb.theme.danger.g, cb.theme.danger.b, 0.2) : cb.theme.card
                border.width: 1
                border.color: cb.theme.border
                Row {
                    anchors.centerIn: parent
                    spacing: 2
                    NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "delete"; font.pixelSize: 12; color: cb.theme.danger }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Del"); color: cb.theme.danger; font.family: Tokens.ui; font.pixelSize: 10 }
                }
                MouseArea {
                    id: batchDelMa
                    anchors.fill: parent
                    enabled: cb.selectedCount > 0
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: cb.deleteSelected()
                }
            }

            // Select / Done toggle
            Rectangle {
                width: 58; height: 28; radius: 9
                color: cb.selectMode
                    ? Qt.rgba(cb.theme.accent.r, cb.theme.accent.g, cb.theme.accent.b, 0.22)
                    : (selMa.containsMouse ? cb.theme.cardHover : cb.theme.card)
                border.width: 1
                border.color: cb.selectMode ? cb.theme.accent : cb.theme.border

                Text {
                    anchors.centerIn: parent
                    text: cb.selectMode ? I18n.tr("Done") : I18n.tr("Select")
                    color: cb.theme.ink
                    font.family: Tokens.ui
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: selMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (cb.selectMode) cb.clearSelection();
                        else cb.selectMode = true;
                    }
                }
            }
        }

        // ── History list (newest first) ──────────────────────────────────────
        Item {
            width: parent.width
            height: parent.height - 36

            Column {
                anchors.centerIn: parent
                visible: cb.filteredEntries.length === 0
                spacing: 4
                NotchIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "content_paste"
                    font.pixelSize: 22
                    color: cb.theme.muted
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: cb.query !== "" || cb.pinnedOnly
                        ? I18n.tr("No matching clipboard entries")
                        : I18n.tr("Clipboard history is empty")
                    color: cb.theme.muted
                    font.family: Tokens.ui
                    font.pixelSize: 11
                }
            }

            ListView {
                id: listView
                anchors.fill: parent
                visible: cb.filteredEntries.length > 0
                model: cb.filteredEntries
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: rowCard
                    required property var modelData
                    required property int index

                    readonly property string entryId: String(modelData.id || "")
                    readonly property string kind: String(modelData.kind || "")
                    readonly property bool isImage: kind === "image"
                    readonly property bool isStarred: modelData.starred === true
                    readonly property bool isSelected: cb.selectedIds[entryId] === true
                    readonly property bool justCopied: cb.copiedId === entryId

                    width: listView.width
                    height: isImage ? 54 : 44
                    radius: 11
                    color: isSelected
                        ? Qt.rgba(cb.theme.accent.r, cb.theme.accent.g, cb.theme.accent.b, 0.16)
                        : (rowMa.containsMouse ? cb.theme.cardHover : cb.theme.card)
                    border.width: 1
                    border.color: justCopied ? cb.theme.success
                        : (isSelected ? cb.theme.accent
                        : (isStarred ? Qt.rgba(cb.theme.accent.r, cb.theme.accent.g, cb.theme.accent.b, 0.45) : cb.theme.border))

                    Behavior on color { enabled: cb.anim; ColorAnimation { duration: 130 } }
                    Behavior on border.color { enabled: cb.anim; ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (cb.selectMode) cb.toggleSelect(rowCard.entryId);
                            else cb.copyEntry(rowCard.entryId);
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8

                        // Checkbox in Select mode
                        Rectangle {
                            visible: cb.selectMode
                            width: 16; height: 16; radius: 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: rowCard.isSelected ? cb.theme.accent : "transparent"
                            border.width: 1.5
                            border.color: rowCard.isSelected ? cb.theme.accent : cb.theme.muted
                            NotchIcon {
                                anchors.centerIn: parent
                                visible: rowCard.isSelected
                                text: "check"
                                font.pixelSize: 12
                                color: cb.theme.onAccent
                            }
                        }

                        // Image thumbnail or type icon
                        Rectangle {
                            visible: rowCard.isImage && modelData.thumb
                            width: 40; height: 40; radius: 7
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(0, 0, 0, 0.25)
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: modelData.thumb ? ("file://" + modelData.thumb) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        // Preview text
                        Column {
                            width: parent.width - (cb.selectMode ? 24 : 0) - (rowCard.isImage && modelData.thumb ? 48 : 0) - 94
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                width: parent.width
                                text: rowCard.isImage
                                    ? I18n.tr("Image %1×%2").arg(modelData.w || "?").arg(modelData.h || "?")
                                    : (String(modelData.preview || modelData.mime || "").replace(/\s+/g, " ").trim() || I18n.tr("(Empty)"))
                                color: cb.theme.ink
                                font.family: Tokens.ui
                                font.pixelSize: 11
                                font.weight: rowCard.isStarred ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: rowCard.justCopied || rowCard.isStarred
                                text: rowCard.justCopied ? I18n.tr("Copied to clipboard") : I18n.tr("Pinned")
                                color: rowCard.justCopied ? cb.theme.success : cb.theme.accent
                                font.family: Tokens.mono
                                font.pixelSize: 9
                            }
                        }

                        // Quick 1-click Paste/Copy icon, Pin icon, Delete icon
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Rectangle {
                                width: 26; height: 26; radius: 7
                                color: copyBtnMa.containsMouse ? Qt.rgba(cb.theme.accent.r, cb.theme.accent.g, cb.theme.accent.b, 0.22) : "transparent"
                                NotchIcon {
                                    anchors.centerIn: parent
                                    text: rowCard.justCopied ? "check" : "content_paste"
                                    font.pixelSize: 15
                                    color: rowCard.justCopied ? cb.theme.success : cb.theme.ink
                                }
                                MouseArea {
                                    id: copyBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: cb.copyEntry(rowCard.entryId)
                                }
                            }

                            Rectangle {
                                width: 26; height: 26; radius: 7
                                color: pinBtnMa.containsMouse ? cb.theme.cardHover : "transparent"
                                NotchIcon {
                                    anchors.centerIn: parent
                                    text: "push_pin"
                                    font.pixelSize: 14
                                    fill: rowCard.isStarred ? 1 : 0
                                    color: rowCard.isStarred ? cb.theme.accent : cb.theme.muted
                                }
                                MouseArea {
                                    id: pinBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Clipboard.star(rowCard.entryId, !rowCard.isStarred)
                                }
                            }

                            Rectangle {
                                width: 26; height: 26; radius: 7
                                color: delBtnMa.containsMouse ? Qt.rgba(cb.theme.danger.r, cb.theme.danger.g, cb.theme.danger.b, 0.2) : "transparent"
                                NotchIcon {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    font.pixelSize: 14
                                    color: delBtnMa.containsMouse ? cb.theme.danger : cb.theme.muted
                                }
                                MouseArea {
                                    id: delBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Clipboard.del(rowCard.entryId)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
