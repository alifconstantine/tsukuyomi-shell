import QtQuick
import Quickshell
import Quickshell.Io
import shell.services
import Ryoku.Ui.Singletons

// Teleprompter tab: dual-mode Edit Script & Live Prompter HUD displaying font
// family, font size, WPM speed, estimated read duration, Mirror toggle, and Play/Pause.
Item {
    id: tpView

    property var root: null
    property var theme: _fallbackTheme
    NotchTheme { id: _fallbackTheme; root: null }
    readonly property bool anim: !Perf.reduceMotion

    readonly property bool isEditing: NotchTeleprompterStore.editMode
        || String(NotchTeleprompterStore.scriptText || "").trim() === ""

    Process {
        id: clipPaste
        command: ["wl-paste", "-n"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(text || "");
                if (t.trim() !== "") {
                    NotchTeleprompterStore.setScript(t);
                    scriptEditor.text = t;
                }
            }
        }
    }

    // Smooth auto-scroll engine driven by WPM & font size
    Timer {
        id: scrollTick
        interval: 20
        repeat: true
        running: !tpView.isEditing && NotchTeleprompterStore.playing
        onTriggered: {
            var maxScroll = Math.max(0, prompterFlick.contentHeight - prompterFlick.height);
            if (maxScroll <= 0) {
                NotchTeleprompterStore.playing = false;
                return;
            }
            // Roughly ~5 chars/word; pixels/sec scales cleanly with fontSize & wpm
            var linesPerSec = (NotchTeleprompterStore.wpm / 60.0) / 6.5;
            var pxPerSec = Math.max(14, linesPerSec * (NotchTeleprompterStore.fontSize * 1.45));
            var nextY = prompterFlick.contentY + (pxPerSec * 0.02);
            if (nextY >= maxScroll) {
                prompterFlick.contentY = maxScroll;
                NotchTeleprompterStore.playing = false;
            } else {
                prompterFlick.contentY = nextY;
            }
            NotchTeleprompterStore.scrollY = prompterFlick.contentY;
        }
    }

    component HudStepper: Rectangle {
        id: hs
        property string label: ""
        property string valueText: ""
        signal decrement()
        signal increment()

        height: 26
        width: hsRow.implicitWidth + 12
        radius: 8
        color: tpView.theme.card
        border.width: 1
        border.color: tpView.theme.border

        Row {
            id: hsRow
            anchors.centerIn: parent
            spacing: 5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: hs.label !== ""
                text: hs.label
                color: tpView.theme.muted
                font.family: Tokens.ui
                font.pixelSize: 9
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "−"
                color: tpView.theme.ink
                font.family: Tokens.mono
                font.pixelSize: 12
                font.weight: Font.Bold
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: hs.decrement()
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: hs.valueText
                color: tpView.theme.ink
                font.family: Tokens.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "+"
                color: tpView.theme.ink
                font.family: Tokens.mono
                font.pixelSize: 12
                font.weight: Font.Bold
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: hs.increment()
                }
            }
        }
    }

    // ── MODE 1: SCRIPT INPUT / EDIT ──────────────────────────────────────────
    Column {
        anchors.fill: parent
        visible: tpView.isEditing
        spacing: 8

        Row {
            width: parent.width
            height: 28
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Script Editor") + " · "
                    + NotchTeleprompterStore.wordCount + " words · ~"
                    + NotchTeleprompterStore.etaText + " @ " + NotchTeleprompterStore.wpm + " WPM"
                color: tpView.theme.muted
                font.family: Tokens.mono
                font.pixelSize: 10
                width: parent.width - 234
                elide: Text.ElideRight
            }

            Rectangle {
                width: 66; height: 26; radius: 8
                color: pasteBtnMa.containsMouse ? tpView.theme.cardHover : tpView.theme.card
                border.width: 1; border.color: tpView.theme.border
                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "content_paste"; font.pixelSize: 13; color: tpView.theme.ink }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Paste"); color: tpView.theme.ink; font.family: Tokens.ui; font.pixelSize: 10 }
                }
                MouseArea {
                    id: pasteBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: clipPaste.running = true
                }
            }

            Rectangle {
                width: 56; height: 26; radius: 8
                color: clrBtnMa.containsMouse ? tpView.theme.cardHover : tpView.theme.card
                border.width: 1; border.color: tpView.theme.border
                Text { anchors.centerIn: parent; text: I18n.tr("Clear"); color: tpView.theme.muted; font.family: Tokens.ui; font.pixelSize: 10 }
                MouseArea {
                    id: clrBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        scriptEditor.text = "";
                        NotchTeleprompterStore.setScript("");
                    }
                }
            }

            Rectangle {
                width: 94; height: 26; radius: 8
                enabled: String(scriptEditor.text || "").trim() !== ""
                opacity: enabled ? 1.0 : 0.45
                color: tpView.theme.accent
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "play_arrow"; font.pixelSize: 14; fill: 1; color: tpView.theme.onAccent }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Prompter"); color: tpView.theme.onAccent; font.family: Tokens.ui; font.pixelSize: 10; font.weight: Font.DemiBold }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        NotchTeleprompterStore.setScript(scriptEditor.text);
                        NotchTeleprompterStore.editMode = false;
                        prompterFlick.contentY = 0;
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: parent.height - 36
            radius: 12
            color: tpView.theme.card
            border.width: 1
            border.color: scriptEditor.activeFocus ? tpView.theme.accent : tpView.theme.border

            Flickable {
                id: editFlick
                anchors.fill: parent
                anchors.margins: 10
                contentWidth: width
                contentHeight: Math.max(height, scriptEditor.implicitHeight)
                clip: true

                TextEdit {
                    id: scriptEditor
                    width: editFlick.width
                    height: Math.max(editFlick.height, implicitHeight)
                    text: NotchTeleprompterStore.scriptText
                    wrapMode: TextEdit.Wrap
                    color: tpView.theme.ink
                    font.family: Tokens.ui
                    font.pixelSize: 12
                    selectByMouse: true
                    onTextChanged: NotchTeleprompterStore.scriptText = text

                    Text {
                        visible: scriptEditor.text === ""
                        text: I18n.tr("Paste or write your speaking script here…")
                        color: tpView.theme.muted
                        font.family: Tokens.ui
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    // ── MODE 2: LIVE PROMPTER PREVIEW & PLAYBACK ─────────────────────────────
    Column {
        anchors.fill: parent
        visible: !tpView.isEditing
        spacing: 8

        // Top HUD Strip: Font Family · Size · WPM · Mirror · Edit
        Row {
            width: parent.width
            height: 26
            spacing: 5

            // Font family pill
            Rectangle {
                height: 26
                width: fontRow.implicitWidth + 14
                radius: 8
                color: fontMa.containsMouse ? tpView.theme.cardHover : tpView.theme.card
                border.width: 1; border.color: tpView.theme.border
                Row {
                    id: fontRow
                    anchors.centerIn: parent
                    spacing: 4
                    NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "font_download"; font.pixelSize: 13; color: tpView.theme.accent }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: NotchTeleprompterStore.fontDisplayLabel
                        color: tpView.theme.ink
                        font.family: Tokens.ui
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: fontMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotchTeleprompterStore.cycleFont()
                }
            }

            HudStepper {
                valueText: NotchTeleprompterStore.fontSize + "px"
                onDecrement: NotchTeleprompterStore.adjustFontSize(-2)
                onIncrement: NotchTeleprompterStore.adjustFontSize(2)
            }

            HudStepper {
                valueText: NotchTeleprompterStore.wpm + " WPM"
                onDecrement: NotchTeleprompterStore.adjustWpm(-10)
                onIncrement: NotchTeleprompterStore.adjustWpm(10)
            }

            // Mirror toggle
            Rectangle {
                height: 26; width: 28; radius: 8
                color: NotchTeleprompterStore.mirrorX
                    ? Qt.rgba(tpView.theme.accent.r, tpView.theme.accent.g, tpView.theme.accent.b, 0.22)
                    : tpView.theme.card
                border.width: 1
                border.color: NotchTeleprompterStore.mirrorX ? tpView.theme.accent : tpView.theme.border
                NotchIcon {
                    anchors.centerIn: parent
                    text: "flip"
                    font.pixelSize: 14
                    color: NotchTeleprompterStore.mirrorX ? tpView.theme.accent : tpView.theme.muted
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        NotchTeleprompterStore.mirrorX = !NotchTeleprompterStore.mirrorX;
                        NotchTeleprompterStore.persist();
                    }
                }
            }

            Item { width: Math.max(2, parent.width - 420); height: 1 }

            // Edit Script button
            Rectangle {
                height: 26; width: 58; radius: 8
                color: editHudMa.containsMouse ? tpView.theme.cardHover : tpView.theme.card
                border.width: 1; border.color: tpView.theme.border
                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "edit_note"; font.pixelSize: 14; color: tpView.theme.ink }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Edit"); color: tpView.theme.ink; font.family: Tokens.ui; font.pixelSize: 10 }
                }
                MouseArea {
                    id: editHudMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        NotchTeleprompterStore.playing = false;
                        NotchTeleprompterStore.editMode = true;
                    }
                }
            }
        }

        // Prompter Viewport
        Rectangle {
            width: parent.width
            height: parent.height - 68
            radius: 12
            color: tpView.theme.card
            border.width: 1
            border.color: tpView.theme.border
            clip: true

            // Reading guide eye-line highlight across center
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                height: Math.round(NotchTeleprompterStore.fontSize * 1.75)
                color: Qt.rgba(tpView.theme.accent.r, tpView.theme.accent.g, tpView.theme.accent.b, 0.10)
            }
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: Math.round(NotchTeleprompterStore.fontSize * 1.45)
                radius: 1.5
                color: tpView.theme.accent
            }

            Flickable {
                id: prompterFlick
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                contentWidth: width
                contentHeight: prompterCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                onContentYChanged: NotchTeleprompterStore.scrollY = contentY

                Column {
                    id: prompterCol
                    width: prompterFlick.width

                    Item { width: 1; height: Math.round(prompterFlick.height * 0.42) }

                    Text {
                        width: parent.width
                        text: NotchTeleprompterStore.scriptText
                        color: tpView.theme.ink
                        font.family: NotchTeleprompterStore.fontFamilyName
                        font.pixelSize: NotchTeleprompterStore.fontSize
                        font.weight: Font.Medium
                        lineHeight: 1.38
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        transform: Scale {
                            origin.x: width / 2
                            xScale: NotchTeleprompterStore.mirrorX ? -1 : 1
                        }
                    }

                    Item { width: 1; height: Math.round(prompterFlick.height * 0.48) }
                }
            }
        }

        // Bottom Transport Bar (Reset · Play/Pause · ETA & Progress)
        Row {
            width: parent.width
            height: 28
            spacing: 8

            Rectangle {
                width: 28; height: 28; radius: 14
                color: rstMa.containsMouse ? tpView.theme.cardHover : tpView.theme.card
                border.width: 1; border.color: tpView.theme.border
                NotchIcon { anchors.centerIn: parent; text: "replay"; font.pixelSize: 15; color: tpView.theme.ink }
                MouseArea {
                    id: rstMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        NotchTeleprompterStore.playing = false;
                        prompterFlick.contentY = 0;
                        NotchTeleprompterStore.scrollY = 0;
                    }
                }
            }

            Rectangle {
                width: 96; height: 28; radius: 14
                color: tpView.theme.accent
                scale: playMa.pressed ? 0.94 : 1.0
                Behavior on scale { enabled: tpView.anim; NumberAnimation { duration: 100 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    NotchIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: NotchTeleprompterStore.playing ? "pause" : "play_arrow"
                        font.pixelSize: 16
                        fill: 1
                        color: tpView.theme.onAccent
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: NotchTeleprompterStore.playing ? I18n.tr("Pause") : I18n.tr("Play")
                        color: tpView.theme.onAccent
                        font.family: Tokens.ui
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: playMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var maxScroll = Math.max(0, prompterFlick.contentHeight - prompterFlick.height);
                        if (!NotchTeleprompterStore.playing && prompterFlick.contentY >= maxScroll - 2)
                            prompterFlick.contentY = 0;
                        NotchTeleprompterStore.playing = !NotchTeleprompterStore.playing;
                    }
                }
            }

            // Progress bar + ETA
            Column {
                width: parent.width - 140
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Row {
                    width: parent.width
                    Text {
                        text: NotchTeleprompterStore.wordCount + " " + I18n.tr("words")
                            + " · ~" + NotchTeleprompterStore.etaText
                        color: tpView.theme.muted
                        font.family: Tokens.mono
                        font.pixelSize: 9
                        width: parent.width - 42
                    }
                    Text {
                        width: 42
                        horizontalAlignment: Text.AlignRight
                        text: {
                            var maxS = Math.max(1, prompterFlick.contentHeight - prompterFlick.height);
                            return Math.round(Math.min(1, Math.max(0, prompterFlick.contentY / maxS)) * 100) + "%";
                        }
                        color: tpView.theme.ink
                        font.family: Tokens.mono
                        font.pixelSize: 9
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 3
                    radius: 1.5
                    color: Qt.rgba(tpView.theme.ink.r, tpView.theme.ink.g, tpView.theme.ink.b, 0.14)
                    Rectangle {
                        readonly property real maxS: Math.max(1, prompterFlick.contentHeight - prompterFlick.height)
                        width: Math.round(parent.width * Math.min(1, Math.max(0, prompterFlick.contentY / maxS)))
                        height: parent.height
                        radius: 1.5
                        color: tpView.theme.accent
                    }
                }
            }
        }
    }
}
