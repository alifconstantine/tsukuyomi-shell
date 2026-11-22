import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import shell.services
import Ryoku.Ui.Singletons
import "../../utils/artcolor.js" as ArtColor

// Music + Synced Lyrics tab (Image 2 style):
// Left: album cover, title/artist, seekable progress bar, transport & lyrics toggle.
// Right: LRCLIB synced lyrics (or plain lyrics / empty state when unavailable).
// Background smoothly washes with a dynamic gradient extracted from cover art.
Item {
    id: mus

    property var root: null
    property var theme: _fallbackTheme
    NotchTheme { id: _fallbackTheme; root: null }
    readonly property bool anim: !Perf.reduceMotion

    property bool showLyrics: true
    readonly property var player: Media.player
    readonly property bool present: Media.present
    readonly property bool playing: Media.playing
    readonly property string artSource: Music.coverFor(mus.player)
    readonly property bool hasArt: artSource !== ""
    readonly property bool hasSynced: Music.synced && Music.lines.length > 0
    readonly property bool hasPlain: Music.unsynced && Music.plain.length > 0
    readonly property bool hasLyrics: mus.hasSynced || mus.hasPlain

    Component.onCompleted: Music.hold(mus, true)
    Component.onDestruction: Music.hold(mus, false)

    ColorQuantizer {
        id: quant
        source: mus.artSource
        depth: 3
        rescaleSize: 48
    }

    readonly property color albumAccent: mus.hasArt
        ? ArtColor.accentOf(quant.colors, mus.theme.accent)
        : mus.theme.accent

    // Soft album gradient overlay (toggleable in Notch Settings)
    Rectangle {
        anchors.fill: parent
        anchors.margins: -10
        radius: 16
        visible: NotchConfig.musicDynamicGradient && mus.present && mus.hasArt
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: mus.anim; NumberAnimation { duration: 240 } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(mus.albumAccent.r, mus.albumAccent.g, mus.albumAccent.b, 0.28) }
            GradientStop { position: 0.55; color: Qt.rgba(mus.albumAccent.r, mus.albumAccent.g, mus.albumAccent.b, 0.08) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    function sendPlayPause() {
        if (mus.player && mus.player.canTogglePlaying) mus.player.togglePlaying();
        else Media.toggle();
    }
    function sendPrev() {
        if (mus.player && mus.player.canGoPrevious) mus.player.previous();
        else Media.previous();
    }
    function sendNext() {
        if (mus.player && mus.player.canGoNext) mus.player.next();
        else Media.next();
    }

    // Empty state when no active MPRIS track
    Column {
        anchors.centerIn: parent
        visible: !mus.present
        spacing: 6

        NotchIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "music_note"
            font.pixelSize: 28
            color: mus.theme.muted
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: NotchConfig.musicSource === "orpheus"
                ? I18n.tr("Orpheus integration pending · Play via any media app")
                : I18n.tr("Nothing playing")
            color: mus.theme.ink
            font.family: Tokens.ui
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.tr("Start music in your player or browser to show cover & lyrics")
            color: mus.theme.muted
            font.family: Tokens.ui
            font.pixelSize: 10
        }
    }

    // Active Player + Lyrics split layout
    Row {
        anchors.fill: parent
        visible: mus.present
        spacing: 14

        // ── Left: Player Card ────────────────────────────────────────────────
        Item {
            width: mus.showLyrics ? Math.round(parent.width * 0.48) : parent.width
            height: parent.height

            Column {
                anchors.fill: parent
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 10

                    // Cover art
                    Rectangle {
                        width: 56
                        height: 56
                        radius: 11
                        color: mus.theme.card
                        border.width: 1
                        border.color: mus.theme.border
                        clip: true

                        scale: mus.playing ? 1.0 : 0.94
                        Behavior on scale {
                            enabled: mus.anim
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }

                        Image {
                            anchors.fill: parent
                            source: mus.artSource
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            visible: mus.hasArt && status === Image.Ready
                        }
                        NotchIcon {
                            anchors.centerIn: parent
                            visible: !mus.hasArt
                            text: "album"
                            font.pixelSize: 24
                            color: mus.theme.muted
                        }
                    }

                    // Track metadata
                    Column {
                        width: parent.width - 66
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: Music.title || I18n.tr("Unknown Track")
                            color: mus.theme.ink
                            font.family: Tokens.ui
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: [Music.artist, Music.album].filter(function(s) { return s && s.length > 0; }).join(" — ")
                            color: mus.theme.muted
                            font.family: Tokens.ui
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                // Seek bar + timestamps
                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Music.stamp(Music.elapsed)
                        color: mus.theme.muted
                        font.family: Tokens.mono
                        font.pixelSize: 10
                    }

                    Item {
                        id: seekTrack
                        width: parent.width - 84
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter

                        readonly property real frac: Music.duration > 0
                            ? Math.max(0, Math.min(1, Music.elapsed / Music.duration))
                            : 0

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Qt.rgba(mus.theme.ink.r, mus.theme.ink.g, mus.theme.ink.b, 0.16)

                            Rectangle {
                                width: Math.round(parent.width * seekTrack.frac)
                                height: parent.height
                                radius: 2
                                color: mus.hasArt ? mus.albumAccent : mus.theme.ink
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: Music.duration > 0 && mus.player && mus.player.canSeek
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: e => {
                                var r = Math.max(0, Math.min(1, e.x / Math.max(1, width)));
                                Music.seek(r * Music.duration);
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Music.duration > 0 ? ("-" + Music.stamp(Math.max(0, Music.duration - Music.elapsed))) : "0:00"
                        color: mus.theme.muted
                        font.family: Tokens.mono
                        font.pixelSize: 10
                    }
                }

                // Transport buttons
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: lyrMa.containsMouse ? mus.theme.cardHover : "transparent"
                        NotchIcon {
                            anchors.centerIn: parent
                            text: "lyrics"
                            font.pixelSize: 16
                            fill: mus.showLyrics ? 1 : 0
                            color: mus.showLyrics ? mus.theme.ink : mus.theme.muted
                        }
                        MouseArea {
                            id: lyrMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mus.showLyrics = !mus.showLyrics
                        }
                    }

                    Rectangle {
                        width: 30; height: 30; radius: 15
                        anchors.verticalCenter: parent.verticalCenter
                        color: prevMa.containsMouse ? mus.theme.cardHover : "transparent"
                        scale: prevMa.pressed ? 0.9 : 1.0
                        Behavior on scale { enabled: mus.anim; NumberAnimation { duration: 100 } }
                        NotchIcon {
                            anchors.centerIn: parent
                            text: "skip_previous"
                            font.pixelSize: 20
                            fill: 1
                            color: mus.theme.ink
                        }
                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mus.sendPrev()
                        }
                    }

                    Rectangle {
                        width: 34; height: 34; radius: 17
                        anchors.verticalCenter: parent.verticalCenter
                        color: mus.theme.ink
                        scale: playMa.pressed ? 0.92 : (playMa.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { enabled: mus.anim; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        NotchIcon {
                            anchors.centerIn: parent
                            text: mus.playing ? "pause" : "play_arrow"
                            font.pixelSize: 20
                            fill: 1
                            color: mus.theme.baseSurface
                        }
                        MouseArea {
                            id: playMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mus.sendPlayPause()
                        }
                    }

                    Rectangle {
                        width: 30; height: 30; radius: 15
                        anchors.verticalCenter: parent.verticalCenter
                        color: nextMa.containsMouse ? mus.theme.cardHover : "transparent"
                        scale: nextMa.pressed ? 0.9 : 1.0
                        Behavior on scale { enabled: mus.anim; NumberAnimation { duration: 100 } }
                        NotchIcon {
                            anchors.centerIn: parent
                            text: "skip_next"
                            font.pixelSize: 20
                            fill: 1
                            color: mus.theme.ink
                        }
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mus.sendNext()
                        }
                    }
                }
            }
        }

        // Hairline divider
        Rectangle {
            visible: mus.showLyrics
            width: 1
            height: parent.height - 8
            anchors.verticalCenter: parent.verticalCenter
            color: mus.theme.hairline
        }

        // ── Right: Synced / Plain Lyrics ─────────────────────────────────────
        Item {
            visible: mus.showLyrics
            width: parent.width - Math.round(parent.width * 0.48) - 29
            height: parent.height
            clip: true

            // Synced LRCLIB lyrics
            ListView {
                id: lyricView
                anchors.fill: parent
                visible: mus.hasSynced
                model: Music.lines
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: height * 0.34
                preferredHighlightEnd: height * 0.62
                highlightMoveDuration: mus.anim ? 260 : 0
                currentIndex: Music.index >= 0 ? Music.index : 0

                delegate: Text {
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: index === Music.index
                    width: lyricView.width
                    text: modelData.text || "♪"
                    wrapMode: Text.WordWrap
                    color: isCurrent ? mus.theme.ink : Qt.rgba(mus.theme.ink.r, mus.theme.ink.g, mus.theme.ink.b, 0.38)
                    font.family: Tokens.ui
                    font.pixelSize: isCurrent ? 14 : 12
                    font.weight: isCurrent ? Font.Bold : Font.Normal
                    Behavior on color { enabled: mus.anim; ColorAnimation { duration: 180 } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (modelData.t !== undefined) Music.seek(modelData.t)
                    }
                }
            }

            // Plain unsynced lyrics fallback
            ListView {
                anchors.fill: parent
                visible: !mus.hasSynced && mus.hasPlain
                model: Music.plain
                spacing: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                delegate: Text {
                    required property var modelData
                    width: parent ? parent.width : 200
                    text: String(modelData || "")
                    wrapMode: Text.WordWrap
                    color: mus.theme.ink
                    font.family: Tokens.ui
                    font.pixelSize: 12
                }
            }

            // Searching / No lyrics empty state
            Text {
                anchors.centerIn: parent
                width: parent.width - 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: !mus.hasLyrics
                text: Music.searching ? I18n.tr("Looking up lyrics…") : I18n.tr("No lyrics available for this track")
                color: mus.theme.muted
                font.family: Tokens.ui
                font.pixelSize: 11
            }
        }
    }
}
