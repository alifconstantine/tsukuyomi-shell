import QtQuick
import Quickshell
import Ryoku.Ui.Singletons

// ToDo tab with Timeline:
// Left: quick task composer (optional HH:MM + text) and interactive checklist.
// Right: vertical chronological timeline showing scheduled tasks & completion ratio.
Item {
    id: td

    property var root: null
    property var theme: _fallbackTheme
    NotchTheme { id: _fallbackTheme; root: null }
    readonly property bool anim: !Perf.reduceMotion

    function addNew() {
        var txt = taskInput.text.trim();
        if (txt === "") return;
        NotchTodoStore.addTask(txt, timeInput.text);
        taskInput.text = "";
        timeInput.text = "";
    }

    Row {
        anchors.fill: parent
        spacing: 12

        // ── Left: Quick Composer + Checklist ─────────────────────────────────
        Column {
            width: Math.round(parent.width * 0.56)
            height: parent.height
            spacing: 8

            // Composer row
            Rectangle {
                width: parent.width
                height: 32
                radius: 10
                color: td.theme.card
                border.width: 1
                border.color: taskInput.activeFocus || timeInput.activeFocus ? td.theme.accent : td.theme.border

                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 6

                    Rectangle {
                        width: 48; height: parent.height; radius: 7
                        color: Qt.rgba(td.theme.ink.r, td.theme.ink.g, td.theme.ink.b, 0.06)
                        TextInput {
                            id: timeInput
                            anchors.fill: parent
                            anchors.margins: 4
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            color: td.theme.ink
                            font.family: theme.monoFont
                            font.pixelSize: 10
                            selectByMouse: true
                            Text {
                                anchors.centerIn: parent
                                visible: timeInput.text === ""
                                text: "HH:MM"
                                color: td.theme.muted
                                font.family: theme.monoFont
                                font.pixelSize: 9
                            }
                        }
                    }

                    TextInput {
                        id: taskInput
                        width: parent.width - 96
                        height: parent.height
                        verticalAlignment: TextInput.AlignVCenter
                        color: td.theme.ink
                        font.family: Tokens.ui
                        font.pixelSize: 11
                        clip: true
                        selectByMouse: true
                        onAccepted: td.addNew()
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: taskInput.text === ""
                            text: I18n.tr("Add a task…")
                            color: td.theme.muted
                            font.family: Tokens.ui
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        width: 34; height: parent.height; radius: 7
                        color: td.theme.accent
                        NotchIcon { anchors.centerIn: parent; text: "add"; font.pixelSize: 16; color: td.theme.onAccent }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: td.addNew()
                        }
                    }
                }
            }

            // Checklist
            Item {
                width: parent.width
                height: parent.height - 40

                Column {
                    anchors.centerIn: parent
                    visible: NotchTodoStore.items.length === 0
                    spacing: 4
                    NotchIcon { anchors.horizontalCenter: parent.horizontalCenter; text: "checklist"; font.pixelSize: 22; color: td.theme.muted }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.tr("No tasks yet")
                        color: td.theme.muted
                        font.family: Tokens.ui
                        font.pixelSize: 11
                    }
                }

                ListView {
                    anchors.fill: parent
                    visible: NotchTodoStore.items.length > 0
                    model: NotchTodoStore.items
                    spacing: 5
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        width: parent ? parent.width : 260
                        height: 34
                        radius: 9
                        color: tdRowMa.containsMouse ? td.theme.cardHover : td.theme.card
                        border.width: 1
                        border.color: td.theme.border
                        opacity: modelData.done ? 0.65 : 1.0
                        Behavior on opacity { enabled: td.anim; NumberAnimation { duration: 150 } }

                        MouseArea {
                            id: tdRowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotchTodoStore.toggleTask(modelData.id)
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 6
                            spacing: 8

                            Rectangle {
                                width: 16; height: 16; radius: 5
                                anchors.verticalCenter: parent.verticalCenter
                                color: modelData.done ? td.theme.accent : "transparent"
                                border.width: 1.5
                                border.color: modelData.done ? td.theme.accent : td.theme.muted
                                NotchIcon {
                                    anchors.centerIn: parent
                                    visible: modelData.done
                                    text: "check"
                                    font.pixelSize: 12
                                    color: td.theme.onAccent
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - (modelData.time ? 90 : 48)
                                text: String(modelData.text || "")
                                color: td.theme.ink
                                font.family: Tokens.ui
                                font.pixelSize: 11
                                font.strikeout: modelData.done === true
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: Boolean(modelData.time)
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(modelData.time || "")
                                color: td.theme.accent
                                font.family: theme.monoFont
                                font.pixelSize: 9
                            }

                            Rectangle {
                                width: 22; height: 22; radius: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: delTdMa.containsMouse ? Qt.rgba(td.theme.danger.r, td.theme.danger.g, td.theme.danger.b, 0.2) : "transparent"
                                NotchIcon {
                                    anchors.centerIn: parent
                                    text: "close"
                                    font.pixelSize: 13
                                    color: delTdMa.containsMouse ? td.theme.danger : td.theme.muted
                                }
                                MouseArea {
                                    id: delTdMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotchTodoStore.removeTask(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Right: Vertical Timeline ─────────────────────────────────────────
        Rectangle {
            width: parent.width - Math.round(parent.width * 0.56) - 12
            height: parent.height
            radius: 13
            color: td.theme.card
            border.width: 1
            border.color: td.theme.border

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 6
                    Text {
                        width: parent.width - clearBtn.width - 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Timeline") + " · " + NotchTodoStore.doneCount + "/" + NotchTodoStore.items.length
                        color: td.theme.ink
                        font.family: Tokens.ui
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    Text {
                        id: clearBtn
                        anchors.verticalCenter: parent.verticalCenter
                        visible: NotchTodoStore.doneCount > 0
                        text: I18n.tr("Clear done")
                        color: td.theme.accent
                        font.family: Tokens.ui
                        font.pixelSize: 10
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: NotchTodoStore.clearDone()
                        }
                    }
                }

                ListView {
                    width: parent.width
                    height: parent.height - 26
                    clip: true
                    spacing: 8
                    boundsBehavior: Flickable.StopAtBounds
                    model: NotchTodoStore.timelineItems

                    delegate: Row {
                        required property var modelData
                        width: parent ? parent.width : 180
                        height: 24
                        spacing: 8

                        Text {
                            width: 34
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.time ? modelData.time : "—"
                            color: modelData.time ? td.theme.accent : td.theme.muted
                            font.family: theme.monoFont
                            font.pixelSize: 9
                        }

                        Item {
                            width: 10
                            height: parent.height
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: -4
                                width: 1.5
                                height: parent.height + 8
                                color: td.theme.hairline
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: 8; height: 8; radius: 4
                                color: modelData.done ? td.theme.success : td.theme.accent
                            }
                        }

                        Text {
                            width: parent.width - 56
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(modelData.text || "")
                            color: modelData.done ? td.theme.muted : td.theme.ink
                            font.family: Tokens.ui
                            font.pixelSize: 10
                            font.strikeout: modelData.done === true
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
