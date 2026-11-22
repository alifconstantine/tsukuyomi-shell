import QtQuick
import Quickshell
import shell.services
import Ryoku.Ui.Singletons

// Notifications tab (Image 4 style):
// Top bar: Mark all read · Clear all.
// Left sidebar: All, Unread / While DND, and per-app filter rows with counts.
// Right list: Notification cards with app badge, summary, body, time, dismiss & actions.
// Footer: Retention summary + "Change" shortcut into Notch Settings.
Item {
    id: nf

    property var root: null
    property var theme: _fallbackTheme
    NotchTheme { id: _fallbackTheme; root: null }
    readonly property bool anim: !Perf.reduceMotion

    signal openSettingsRequested()

    property string filterKey: "all" // "all" | "unread" | "app:<name>"

    readonly property var allNotifs: {
        var h = Notifs.history || [];
        var cap = Math.max(10, NotchConfig.notifMaxCount || 200);
        return h.slice(0, cap);
    }

    readonly property int unreadCount: {
        var arr = nf.allNotifs;
        var seen = Notifs.seenMs || 0;
        var n = 0;
        for (var i = 0; i < arr.length; i++) {
            var ts = Number(Notifs.arrivalMs[arr[i].id] || 0);
            if (ts > seen) n++;
        }
        return n;
    }

    readonly property var appBuckets: {
        var arr = nf.allNotifs;
        var map = ({});
        var order = [];
        for (var i = 0; i < arr.length; i++) {
            var name = String(arr[i].appName || I18n.tr("System")).trim() || I18n.tr("System");
            if (!map[name]) {
                map[name] = 0;
                order.push(name);
            }
            map[name] += 1;
        }
        var out = [];
        for (var j = 0; j < order.length; j++)
            out.push({ name: order[j], count: map[order[j]] });
        return out;
    }

    readonly property var filteredList: {
        var arr = nf.allNotifs;
        var seen = Notifs.seenMs || 0;
        if (nf.filterKey === "all") return arr;
        if (nf.filterKey === "unread") {
            return arr.filter(function(n) {
                return Number(Notifs.arrivalMs[n.id] || 0) > seen;
            });
        }
        var target = nf.filterKey.slice(4);
        return arr.filter(function(n) {
            var name = String(n.appName || I18n.tr("System")).trim() || I18n.tr("System");
            return name === target;
        });
    }

    function appInitial(name) {
        var s = String(name || "N").trim();
        return s.length > 0 ? s[0].toUpperCase() : "N";
    }

    function appColor(name) {
        var s = String(name || "");
        var h = 0;
        for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 360;
        return Qt.hsla(h / 360, 0.55, nf.theme.lightSurface ? 0.44 : 0.56, 1.0);
    }

    Column {
        anchors.fill: parent
        spacing: 6

        // ── Top actions bar ──────────────────────────────────────────────────
        Row {
            width: parent.width
            height: 22
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 170
                text: NotchConfig.notifInNotch
                    ? (Notifs.dnd ? I18n.tr("Focus active · Notifications silenced") : I18n.tr("TODAY"))
                    : I18n.tr("Notch notification alerts disabled in Settings")
                color: nf.theme.muted
                font.family: theme.monoFont
                font.pixelSize: 10
                font.letterSpacing: 0.8
                elide: Text.ElideRight
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                opacity: nf.unreadCount > 0 ? 1 : 0.45
                NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "done_all"; font.pixelSize: 13; color: nf.theme.ink }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Mark all read")
                    color: nf.theme.ink
                    font.family: Tokens.ui
                    font.pixelSize: 10
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.markSeen()
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                opacity: nf.allNotifs.length > 0 ? 1 : 0.45
                NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "delete_sweep"; font.pixelSize: 13; color: nf.theme.muted }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Clear all")
                    color: nf.theme.muted
                    font.family: Tokens.ui
                    font.pixelSize: 10
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.clearAll()
                }
            }
        }

        // ── Main split: Filter sidebar + Notification timeline ───────────────
        Row {
            width: parent.width
            height: parent.height - 46
            spacing: 10

            // Left sidebar filters
            Flickable {
                width: 154
                height: parent.height
                contentWidth: width
                contentHeight: sideCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: sideCol
                    width: parent.width
                    spacing: 3

                    component FilterRow: Rectangle {
                        id: fr
                        property string key: ""
                        property string icon: "notifications"
                        property string label: ""
                        property int count: 0
                        property color badgeColor: nf.theme.accent
                        property bool appTile: false
                        readonly property bool active: nf.filterKey === fr.key

                        width: sideCol.width
                        height: 28
                        radius: 8
                        color: active ? Qt.rgba(nf.theme.ink.r, nf.theme.ink.g, nf.theme.ink.b, 0.12)
                            : (frMa.containsMouse ? nf.theme.cardHover : "transparent")
                        Behavior on color { enabled: nf.anim; ColorAnimation { duration: 120 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 7
                            anchors.rightMargin: 7
                            spacing: 6

                            Rectangle {
                                visible: fr.appTile
                                width: 16; height: 16; radius: 4.5
                                anchors.verticalCenter: parent.verticalCenter
                                color: fr.badgeColor
                                Text {
                                    anchors.centerIn: parent
                                    text: nf.appInitial(fr.label)
                                    color: "#FFFFFF"
                                    font.family: Tokens.ui
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }
                            NotchIcon {
                                visible: !fr.appTile
                                anchors.verticalCenter: parent.verticalCenter
                                text: fr.icon
                                font.pixelSize: 14
                                fill: fr.active ? 1 : 0
                                color: fr.active ? nf.theme.ink : nf.theme.muted
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 42
                                text: fr.label
                                color: fr.active ? nf.theme.ink : nf.theme.muted
                                font.family: Tokens.ui
                                font.pixelSize: 11
                                font.weight: fr.active ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(fr.count)
                                color: nf.theme.muted
                                font.family: theme.monoFont
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: frMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: nf.filterKey = fr.key
                        }
                    }

                    FilterRow { key: "all";    icon: "notifications"; label: I18n.tr("All");    count: nf.allNotifs.length }
                    FilterRow { key: "unread"; icon: "dark_mode";     label: I18n.tr("Unread"); count: nf.unreadCount }

                    Repeater {
                        model: nf.appBuckets
                        delegate: FilterRow {
                            required property var modelData
                            appTile: true
                            key: "app:" + modelData.name
                            label: modelData.name
                            count: modelData.count
                            badgeColor: nf.appColor(modelData.name)
                        }
                    }
                }
            }

            Rectangle { width: 1; height: parent.height; color: nf.theme.hairline }

            // Right list
            Item {
                width: parent.width - 165
                height: parent.height

                Column {
                    anchors.centerIn: parent
                    visible: nf.filteredList.length === 0
                    spacing: 4
                    NotchIcon { anchors.horizontalCenter: parent.horizontalCenter; text: "notifications_none"; font.pixelSize: 22; color: nf.theme.muted }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.tr("You're all caught up")
                        color: nf.theme.muted
                        font.family: Tokens.ui
                        font.pixelSize: 11
                    }
                }

                ListView {
                    anchors.fill: parent
                    visible: nf.filteredList.length > 0
                    model: nf.filteredList
                    spacing: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: nCard
                        required property var modelData
                        readonly property string appName: String(modelData.appName || I18n.tr("System"))
                        readonly property bool unread: Number(Notifs.arrivalMs[modelData.id] || 0) > (Notifs.seenMs || 0)

                        width: parent ? parent.width : 360
                        height: textCol.implicitHeight + 14
                        radius: 10
                        color: nMa.containsMouse ? nf.theme.cardHover : nf.theme.card
                        border.width: 1
                        border.color: nf.theme.border
                        Behavior on color { enabled: nf.anim; ColorAnimation { duration: 120 } }

                        MouseArea {
                            id: nMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: Notifs.markSeen(Number(Notifs.arrivalMs[modelData.id] || 0))
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 9

                            Rectangle {
                                width: 28; height: 28; radius: 8
                                anchors.top: parent.top
                                color: nf.appColor(nCard.appName)
                                Text {
                                    anchors.centerIn: parent
                                    text: nf.appInitial(nCard.appName)
                                    color: "#FFFFFF"
                                    font.family: Tokens.ui
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                }
                            }

                            Column {
                                id: textCol
                                width: parent.width - 74
                                spacing: 1

                                Text {
                                    width: parent.width
                                    text: nCard.appName
                                    color: nf.theme.muted
                                    font.family: Tokens.ui
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    visible: String(modelData.summary || "") !== ""
                                    text: String(modelData.summary || "")
                                    color: nf.theme.ink
                                    font.family: Tokens.ui
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    visible: String(modelData.body || "") !== ""
                                    text: String(modelData.body || "").replace(/\s+/g, " ")
                                    color: nf.theme.muted
                                    font.family: Tokens.ui
                                    font.pixelSize: 11
                                    maximumLineCount: 2
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                }
                            }

                            Column {
                                width: 28
                                anchors.top: parent.top
                                spacing: 4
                                Text {
                                    anchors.right: parent.right
                                    text: Notifs.timeLabel(modelData)
                                    color: nf.theme.muted
                                    font.family: theme.monoFont
                                    font.pixelSize: 9
                                }
                                Row {
                                    anchors.right: parent.right
                                    spacing: 4
                                    Rectangle {
                                        visible: nCard.unread
                                        width: 6; height: 6; radius: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: nf.theme.accent
                                    }
                                    NotchIcon {
                                        visible: nMa.containsMouse || disMa.containsMouse
                                        text: "close"
                                        font.pixelSize: 13
                                        color: disMa.containsMouse ? nf.theme.danger : nf.theme.muted
                                        MouseArea {
                                            id: disMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: Notifs.dismiss(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Footer: retention summary + Settings shortcut ────────────────────
        Row {
            width: parent.width
            height: 16
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Kept for %1 days, up to %2").arg(NotchConfig.notifRetentionDays).arg(NotchConfig.notifMaxCount)
                color: nf.theme.muted
                font.family: Tokens.ui
                font.pixelSize: 10
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Change")
                color: nf.theme.accent
                font.family: Tokens.ui
                font.pixelSize: 10
                font.weight: Font.Medium
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: nf.openSettingsRequested()
                }
            }
        }
    }
}
