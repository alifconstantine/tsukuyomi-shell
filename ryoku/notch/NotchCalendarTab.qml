import QtQuick
import Quickshell
import shell.services
import Ryoku.Ui.Singletons

// Calendar tab: left month grid (< Month Year >, today ring, event/holiday dots);
// right selected-day agenda (Events.qml + Holidays.qml) with inline + Add Event.
Item {
    id: cal

    property var root: null
    property var theme: _fallbackTheme
    NotchTheme { id: _fallbackTheme; root: null }
    readonly property bool anim: !Perf.reduceMotion

    property int monthOffset: 0
    property string selectedDate: cal.todayKey()
    property bool addingEvent: false

    function pad2(n) { return (n < 10 ? "0" : "") + n; }
    function dateKey(y, m, d) { return y + "-" + pad2(m + 1) + "-" + pad2(d); }
    function todayKey() {
        var now = new Date();
        return dateKey(now.getFullYear(), now.getMonth(), now.getDate());
    }

    readonly property var viewMonthDate: {
        var now = new Date();
        return new Date(now.getFullYear(), now.getMonth() + cal.monthOffset, 1);
    }
    readonly property int viewYear: viewMonthDate.getFullYear()
    readonly property int viewMonth: viewMonthDate.getMonth()
    readonly property string monthLabel: {
        return Config.formatLoc.standaloneMonthName(cal.viewMonth, 0) + " " + cal.viewYear;
    }

    readonly property var gridCells: {
        var y = cal.viewYear;
        var m = cal.viewMonth;
        var firstDow = (new Date(y, m, 1).getDay() + 6) % 7; // Mon=0..Sun=6
        var daysInMonth = new Date(y, m + 1, 0).getDate();
        var prevDays = new Date(y, m, 0).getDate();
        var today = cal.todayKey();
        var cells = [];
        for (var i = 0; i < 42; i++) {
            var dayNum = 0;
            var cellY = y;
            var cellM = m;
            var inMonth = true;
            if (i < firstDow) {
                inMonth = false;
                dayNum = prevDays - (firstDow - 1 - i);
                cellM = m - 1;
                if (cellM < 0) { cellM = 11; cellY--; }
            } else if (i >= firstDow + daysInMonth) {
                inMonth = false;
                dayNum = (i - (firstDow + daysInMonth)) + 1;
                cellM = m + 1;
                if (cellM > 11) { cellM = 0; cellY++; }
            } else {
                dayNum = (i - firstDow) + 1;
            }
            var k = cal.dateKey(cellY, cellM, dayNum);
            cells.push({
                day: dayNum,
                key: k,
                inMonth: inMonth,
                isToday: k === today,
                hasEvent: Events.hasEvents(k),
                hasHoliday: Holidays.hasDate(k)
            });
        }
        return cells;
    }

    readonly property var dayEvents: {
        void(Events.events);
        return Events.forDate(cal.selectedDate);
    }
    readonly property var dayHolidays: {
        void(Holidays.days);
        return Holidays.forDate(cal.selectedDate);
    }

    Component.onCompleted: {
        Holidays.configure(Config.weatherLocation || "", [cal.viewYear]);
    }

    function submitEvent() {
        var title = titleField.text.trim();
        if (title === "") return;
        var t = timeField.text.trim();
        if (t !== "") {
            Events.addEntry(cal.selectedDate, t + " " + title);
        } else {
            Events.add(cal.selectedDate, "", "", "", title);
        }
        titleField.text = "";
        timeField.text = "";
        cal.addingEvent = false;
    }

    Row {
        anchors.fill: parent
        spacing: 12

        // ── Left: Compact Month Grid ─────────────────────────────────────────
        Rectangle {
            width: 248
            height: parent.height
            radius: 13
            color: cal.theme.card
            border.width: 1
            border.color: cal.theme.border

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                // Month switcher
                Item {
                    width: parent.width
                    height: 22

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 7
                        color: prevMonMa.containsMouse ? cal.theme.cardHover : "transparent"
                        NotchIcon { anchors.centerIn: parent; text: "chevron_left"; font.pixelSize: 15; color: cal.theme.ink }
                        MouseArea {
                            id: prevMonMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: cal.monthOffset--
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cal.monthLabel
                        color: cal.theme.ink
                        font.family: Tokens.ui
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { cal.monthOffset = 0; cal.selectedDate = cal.todayKey(); }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 7
                        color: nextMonMa.containsMouse ? cal.theme.cardHover : "transparent"
                        NotchIcon { anchors.centerIn: parent; text: "chevron_right"; font.pixelSize: 15; color: cal.theme.ink }
                        MouseArea {
                            id: nextMonMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: cal.monthOffset++
                        }
                    }
                }

                // Weekday headers
                Row {
                    width: parent.width
                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        delegate: Text {
                            required property string modelData
                            required property int index
                            width: parent.width / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: index >= 5 ? cal.theme.accent : cal.theme.muted
                            font.family: Tokens.mono
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // 6x7 days grid
                Grid {
                    width: parent.width
                    columns: 7
                    readonly property real cellW: width / 7
                    readonly property real cellH: 22

                    Repeater {
                        model: cal.gridCells
                        delegate: Item {
                            required property var modelData
                            readonly property bool selected: modelData.key === cal.selectedDate
                            width: parent.cellW
                            height: parent.cellH

                            Rectangle {
                                anchors.centerIn: parent
                                width: 20; height: 20; radius: 6
                                color: selected ? cal.theme.accent
                                    : (modelData.isToday ? Qt.rgba(cal.theme.ink.r, cal.theme.ink.g, cal.theme.ink.b, 0.14)
                                    : (dMa.containsMouse ? cal.theme.cardHover : "transparent"))
                                Behavior on color { enabled: cal.anim; ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: String(modelData.day)
                                    color: selected ? cal.theme.onAccent
                                        : (modelData.inMonth ? cal.theme.ink : Qt.rgba(cal.theme.muted.r, cal.theme.muted.g, cal.theme.muted.b, 0.4))
                                    font.family: Tokens.mono
                                    font.pixelSize: 10
                                    font.weight: (selected || modelData.isToday) ? Font.Bold : Font.Normal
                                }

                                Rectangle {
                                    visible: modelData.hasEvent || modelData.hasHoliday
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 1.5
                                    width: 3; height: 3; radius: 1.5
                                    color: selected ? cal.theme.onAccent
                                        : (modelData.hasHoliday ? cal.theme.warning : cal.theme.accent)
                                }
                            }

                            MouseArea {
                                id: dMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cal.selectedDate = modelData.key
                            }
                        }
                    }
                }
            }
        }

        // ── Right: Selected Day Agenda + Inline Composer ─────────────────────
        Item {
            width: parent.width - 260
            height: parent.height

            Column {
                anchors.fill: parent
                spacing: 8

                // Selected date header + Add button
                Row {
                    width: parent.width
                    height: 26
                    spacing: 6

                    Text {
                        width: parent.width - 80
                        anchors.verticalCenter: parent.verticalCenter
                        text: cal.selectedDate === cal.todayKey()
                            ? (I18n.tr("Today") + " · " + cal.selectedDate)
                            : cal.selectedDate
                        color: cal.theme.ink
                        font.family: Tokens.ui
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        width: 74; height: 26; radius: 8
                        color: cal.addingEvent
                            ? cal.theme.cardHover
                            : Qt.rgba(cal.theme.accent.r, cal.theme.accent.g, cal.theme.accent.b, 0.22)
                        border.width: 1
                        border.color: cal.addingEvent ? cal.theme.border : cal.theme.accent

                        Row {
                            anchors.centerIn: parent
                            spacing: 3
                            NotchIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: cal.addingEvent ? "close" : "add"
                                font.pixelSize: 13
                                color: cal.theme.ink
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: cal.addingEvent ? I18n.tr("Cancel") : I18n.tr("Event")
                                color: cal.theme.ink
                                font.family: Tokens.ui
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cal.addingEvent = !cal.addingEvent
                        }
                    }
                }

                // Inline event composer
                Rectangle {
                    width: parent.width
                    visible: cal.addingEvent
                    height: cal.addingEvent ? 34 : 0
                    radius: 10
                    color: cal.theme.card
                    border.width: 1
                    border.color: cal.theme.accent

                    Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        Rectangle {
                            width: 54; height: parent.height; radius: 7
                            color: Qt.rgba(cal.theme.ink.r, cal.theme.ink.g, cal.theme.ink.b, 0.06)
                            TextInput {
                                id: timeField
                                anchors.fill: parent
                                anchors.margins: 5
                                verticalAlignment: TextInput.AlignVCenter
                                color: cal.theme.ink
                                font.family: Tokens.mono
                                font.pixelSize: 10
                                selectByMouse: true
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: timeField.text === ""
                                    text: "09:00"
                                    color: cal.theme.muted
                                    font.family: Tokens.mono
                                    font.pixelSize: 10
                                }
                            }
                        }

                        TextInput {
                            id: titleField
                            width: parent.width - 110
                            height: parent.height
                            verticalAlignment: TextInput.AlignVCenter
                            color: cal.theme.ink
                            font.family: Tokens.ui
                            font.pixelSize: 11
                            clip: true
                            selectByMouse: true
                            onAccepted: cal.submitEvent()
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: titleField.text === ""
                                text: I18n.tr("Event title…")
                                color: cal.theme.muted
                                font.family: Tokens.ui
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            width: 44; height: parent.height; radius: 7
                            color: cal.theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: I18n.tr("Add")
                                color: cal.theme.onAccent
                                font.family: Tokens.ui
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cal.submitEvent()
                            }
                        }
                    }
                }

                // Events & Holidays list
                Item {
                    width: parent.width
                    height: parent.height - (cal.addingEvent ? 74 : 34)

                    Column {
                        anchors.centerIn: parent
                        visible: cal.dayEvents.length === 0 && cal.dayHolidays.length === 0
                        spacing: 4
                        NotchIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "event_available"
                            font.pixelSize: 22
                            color: cal.theme.muted
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: I18n.tr("No events scheduled")
                            color: cal.theme.muted
                            font.family: Tokens.ui
                            font.pixelSize: 11
                        }
                    }

                    ListView {
                        anchors.fill: parent
                        visible: cal.dayEvents.length > 0 || cal.dayHolidays.length > 0
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: {
                            var out = [];
                            for (var h = 0; h < cal.dayHolidays.length; h++)
                                out.push({ isHoliday: true, time: I18n.tr("Holiday"), text: String(cal.dayHolidays[h].name || cal.dayHolidays[h]) });
                            for (var e = 0; e < cal.dayEvents.length; e++) {
                                var ev = cal.dayEvents[e];
                                out.push({ isHoliday: false, id: ev.id, time: ev.time || I18n.tr("All day"), text: ev.text });
                            }
                            return out;
                        }

                        delegate: Rectangle {
                            required property var modelData
                            width: parent ? parent.width : 280
                            height: 36
                            radius: 10
                            color: cal.theme.card
                            border.width: 1
                            border.color: cal.theme.border

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 8

                                Rectangle {
                                    width: 3; height: 18; radius: 1.5
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: modelData.isHoliday ? cal.theme.warning : cal.theme.accent
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 46
                                    text: modelData.time
                                    color: cal.theme.muted
                                    font.family: Tokens.mono
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 96
                                    text: modelData.text
                                    color: cal.theme.ink
                                    font.family: Tokens.ui
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    visible: !modelData.isHoliday
                                    width: 22; height: 22; radius: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: delEvMa.containsMouse ? Qt.rgba(cal.theme.danger.r, cal.theme.danger.g, cal.theme.danger.b, 0.2) : "transparent"
                                    NotchIcon {
                                        anchors.centerIn: parent
                                        text: "close"
                                        font.pixelSize: 13
                                        color: delEvMa.containsMouse ? cal.theme.danger : cal.theme.muted
                                    }
                                    MouseArea {
                                        id: delEvMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: Events.remove(modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
