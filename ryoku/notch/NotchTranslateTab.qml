import QtQuick
import Quickshell
import Quickshell.Io
import shell.services
import Ryoku.Ui.Singletons

// Translate tab (Online-only as requested):
// Displays a clean unavailable/offline overlay when internet connectivity is
// absent, and uses HTTPS translation when online with Paste / Swap / Copy.
Item {
    id: tr

    property var root: null
    property var theme: _fallbackTheme
    NotchTheme { id: _fallbackTheme; root: null }
    readonly property bool anim: !Perf.reduceMotion

    readonly property var srcLangs: [
        { code: "auto", label: "Auto" },
        { code: "en",   label: "EN" },
        { code: "id",   label: "ID" },
        { code: "ja",   label: "JA" },
        { code: "zh-CN", label: "ZH" },
        { code: "ko",   label: "KO" },
        { code: "ar",   label: "AR" }
    ]
    readonly property var dstLangs: [
        { code: "id",    label: "ID" },
        { code: "en",    label: "EN" },
        { code: "ja",    label: "JA" },
        { code: "zh-CN", label: "ZH" },
        { code: "ko",    label: "KO" },
        { code: "ar",    label: "AR" },
        { code: "es",    label: "ES" }
    ]

    property string srcCode: "auto"
    property string dstCode: "id"
    property string detectedCode: ""
    property string outputText: ""
    property bool busy: false
    property bool netError: false
    property bool copied: false

    // Offline whenever NetworkManager reports no internet connection and offline-probe failed.
    readonly property bool isOnline: Network.connection.online === true
        || Network.connectivity === "full"
        || Network.connectivity === "limited"
        || Network.wifiConnectivity === "Connected"
        || Network.wired.connectivity === "Connected"

    function langLabel(list, code) {
        for (var i = 0; i < list.length; i++)
            if (list[i].code === code) return list[i].label;
        return code.toUpperCase();
    }

    function cycleLang(list, cur) {
        for (var i = 0; i < list.length; i++) {
            if (list[i].code === cur)
                return list[(i + 1) % list.length].code;
        }
        return list[0].code;
    }

    function swapLanguages() {
        var nextSrc = tr.dstCode;
        var nextDst = tr.srcCode === "auto"
            ? (tr.detectedCode !== "" ? tr.detectedCode : "en")
            : tr.srcCode;
        if (nextSrc === nextDst) nextDst = (nextSrc === "id" ? "en" : "id");
        tr.srcCode = nextSrc;
        tr.dstCode = nextDst;
        if (tr.outputText.trim() !== "") {
            srcEdit.text = tr.outputText;
            tr.runTranslate();
        }
    }

    function runTranslate() {
        if (!tr.isOnline) {
            tr.netError = true;
            return;
        }
        var q = srcEdit.text.trim();
        if (q === "") {
            tr.outputText = "";
            tr.detectedCode = "";
            return;
        }
        tr.busy = true;
        tr.netError = false;
        txProc.command = [
            "python3", "-c",
            "import sys, json, urllib.request, urllib.parse\n" +
            "sl, tl, txt = sys.argv[1], sys.argv[2], sys.argv[3]\n" +
            "url = 'https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&sl=' + urllib.parse.quote(sl) + '&tl=' + urllib.parse.quote(tl) + '&q=' + urllib.parse.quote(txt)\n" +
            "req = urllib.request.Request(url, headers={'User-Agent': 'TsukuyomiNotch/1.0'})\n" +
            "with urllib.request.urlopen(req, timeout=6) as r:\n" +
            "  data = json.loads(r.read().decode('utf-8'))\n" +
            "tr_text = ''.join(seg[0] for seg in (data[0] or []) if seg and seg[0])\n" +
            "det = data[2] if len(data) > 2 and isinstance(data[2], str) else ''\n" +
            "print(json.dumps({'text': tr_text, 'detected': det}))",
            tr.srcCode, tr.dstCode, q
        ];
        txProc.running = true;
    }

    Process {
        id: txProc
        stdout: StdioCollector {
            onStreamFinished: {
                tr.busy = false;
                try {
                    var res = JSON.parse(text || "{}");
                    tr.outputText = String(res.text || "");
                    tr.detectedCode = String(res.detected || "");
                    tr.netError = false;
                } catch (e) {
                    tr.netError = true;
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                tr.busy = false;
                tr.netError = true;
            }
        }
    }

    Process {
        id: pasteProc
        command: ["wl-paste", "-n"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(text || "");
                if (t !== "") {
                    srcEdit.text = t;
                    tr.runTranslate();
                }
            }
        }
    }

    Timer {
        id: debounceTx
        interval: 420
        repeat: false
        onTriggered: if (srcEdit.text.trim() !== "") tr.runTranslate()
    }

    Timer {
        id: copyReset
        interval: 1200
        onTriggered: tr.copied = false
    }

    // ── Main Online Content ──────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        spacing: 8
        opacity: tr.isOnline ? 1.0 : 0.20
        enabled: tr.isOnline

        // Top Language Controls + Online badge
        Row {
            width: parent.width
            height: 28
            spacing: 6

            // Source Language pill
            Rectangle {
                height: 28
                width: srcPillRow.implicitWidth + 18
                radius: 9
                color: srcLangMa.containsMouse ? tr.theme.cardHover : tr.theme.card
                border.width: 1
                border.color: tr.theme.border
                Row {
                    id: srcPillRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tr.langLabel(tr.srcLangs, tr.srcCode)
                            + (tr.srcCode === "auto" && tr.detectedCode !== "" ? (" (" + tr.detectedCode.toUpperCase() + ")") : "")
                        color: tr.theme.ink
                        font.family: Tokens.ui
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    NotchIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "expand_more"
                        font.pixelSize: 13
                        color: tr.theme.muted
                    }
                }
                MouseArea {
                    id: srcLangMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        tr.srcCode = tr.cycleLang(tr.srcLangs, tr.srcCode);
                        if (srcEdit.text.trim() !== "") tr.runTranslate();
                    }
                }
            }

            // Swap button
            Rectangle {
                width: 28; height: 28; radius: 9
                color: swapMa.containsMouse ? tr.theme.cardHover : tr.theme.card
                border.width: 1; border.color: tr.theme.border
                NotchIcon { anchors.centerIn: parent; text: "swap_horiz"; font.pixelSize: 15; color: tr.theme.ink }
                MouseArea {
                    id: swapMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tr.swapLanguages()
                }
            }

            // Target Language pill
            Rectangle {
                height: 28
                width: dstPillRow.implicitWidth + 18
                radius: 9
                color: Qt.rgba(tr.theme.accent.r, tr.theme.accent.g, tr.theme.accent.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(tr.theme.accent.r, tr.theme.accent.g, tr.theme.accent.b, 0.48)
                Row {
                    id: dstPillRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tr.langLabel(tr.dstLangs, tr.dstCode)
                        color: tr.theme.accent
                        font.family: Tokens.ui
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    NotchIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "expand_more"
                        font.pixelSize: 13
                        color: tr.theme.accent
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        tr.dstCode = tr.cycleLang(tr.dstLangs, tr.dstCode);
                        if (srcEdit.text.trim() !== "") tr.runTranslate();
                    }
                }
            }

            Item { width: Math.max(4, parent.width - 376); height: 1 }

            // Paste clipboard
            Rectangle {
                height: 28
                width: 62
                radius: 9
                color: pasteMa.containsMouse ? tr.theme.cardHover : tr.theme.card
                border.width: 1; border.color: tr.theme.border
                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "content_paste"; font.pixelSize: 13; color: tr.theme.ink }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Paste"); color: tr.theme.ink; font.family: Tokens.ui; font.pixelSize: 10 }
                }
                MouseArea {
                    id: pasteMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pasteProc.running = true
                }
            }

            // Online status + Translate button
            Rectangle {
                height: 28
                width: 80
                radius: 9
                color: tr.busy ? tr.theme.card : tr.theme.accent
                border.width: 1
                border.color: tr.busy ? tr.theme.border : tr.theme.accent
                Text {
                    anchors.centerIn: parent
                    text: tr.busy ? I18n.tr("Translating…") : I18n.tr("Translate")
                    color: tr.busy ? tr.theme.muted : tr.theme.onAccent
                    font.family: Tokens.ui
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tr.runTranslate()
                }
            }
        }

        // Split Source <-> Result cards
        Row {
            width: parent.width
            height: parent.height - 36
            spacing: 8

            // Source box
            Rectangle {
                width: (parent.width - 8) / 2
                height: parent.height
                radius: 12
                color: tr.theme.card
                border.width: 1
                border.color: srcEdit.activeFocus ? tr.theme.accent : tr.theme.border

                Flickable {
                    id: srcFlick
                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.bottomMargin: 24
                    contentWidth: width
                    contentHeight: srcEdit.implicitHeight
                    clip: true

                    TextEdit {
                        id: srcEdit
                        width: srcFlick.width
                        wrapMode: TextEdit.Wrap
                        color: tr.theme.ink
                        font.family: Tokens.ui
                        font.pixelSize: 12
                        selectByMouse: true
                        onTextChanged: {
                            if (text.trim() === "") {
                                tr.outputText = "";
                                tr.detectedCode = "";
                            } else {
                                debounceTx.restart();
                            }
                        }

                        Text {
                            visible: srcEdit.text === ""
                            text: I18n.tr("Type or paste text to translate…")
                            color: tr.theme.muted
                            font.family: Tokens.ui
                            font.pixelSize: 11
                        }
                    }
                }

                Row {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 8; bottomMargin: 5 }
                    Text {
                        text: srcEdit.text.length + " chars"
                        color: tr.theme.muted
                        font.family: Tokens.mono
                        font.pixelSize: 9
                    }
                    Item { width: parent.width - 78; height: 1 }
                    Text {
                        visible: srcEdit.text !== ""
                        text: I18n.tr("Clear")
                        color: tr.theme.muted
                        font.family: Tokens.ui
                        font.pixelSize: 9
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { srcEdit.text = ""; tr.outputText = ""; tr.detectedCode = ""; }
                        }
                    }
                }
            }

            // Target output box
            Rectangle {
                width: (parent.width - 8) / 2
                height: parent.height
                radius: 12
                color: Qt.rgba(tr.theme.accent.r, tr.theme.accent.g, tr.theme.accent.b, 0.06)
                border.width: 1
                border.color: tr.theme.border

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.bottomMargin: 24
                    contentWidth: width
                    contentHeight: dstText.implicitHeight
                    clip: true

                    TextEdit {
                        id: dstText
                        width: parent.width
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        text: tr.netError
                            ? I18n.tr("Network error reaching translation service.")
                            : (tr.outputText !== "" ? tr.outputText : "")
                        color: tr.netError ? tr.theme.danger : tr.theme.ink
                        font.family: Tokens.ui
                        font.pixelSize: 12

                        Text {
                            visible: tr.outputText === "" && !tr.netError
                            text: I18n.tr("Translation appears here")
                            color: tr.theme.muted
                            font.family: Tokens.ui
                            font.pixelSize: 11
                        }
                    }
                }

                Row {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 8; bottomMargin: 5 }
                    Text {
                        text: "Online · Google Translate"
                        color: tr.theme.muted
                        font.family: Tokens.mono
                        font.pixelSize: 9
                    }
                    Item { width: parent.width - 180; height: 1 }
                    Rectangle {
                        visible: tr.outputText !== ""
                        width: 56; height: 18; radius: 6
                        color: tr.copied ? tr.theme.success : tr.theme.cardHover
                        Text {
                            anchors.centerIn: parent
                            text: tr.copied ? I18n.tr("Copied") : I18n.tr("Copy")
                            color: tr.copied ? "#FFFFFF" : tr.theme.ink
                            font.family: Tokens.ui
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["wl-copy", tr.outputText]);
                                tr.copied = true;
                                copyReset.restart();
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Offline Gate Overlay (Unavailable when offline) ──────────────────────
    Rectangle {
        visible: !tr.isOnline
        anchors.centerIn: parent
        width: 340
        height: 126
        radius: 14
        color: tr.theme.surface
        border.width: 1
        border.color: tr.theme.border

        Column {
            anchors.centerIn: parent
            width: parent.width - 28
            spacing: 6

            NotchIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "cloud_off"
                font.pixelSize: 28
                color: tr.theme.danger
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr("Offline — Translate Unavailable")
                color: tr.theme.ink
                font.family: Tokens.ui
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: I18n.tr("Connect to Wi-Fi or Ethernet to use online translation.")
                color: tr.theme.muted
                font.family: Tokens.ui
                font.pixelSize: 10
            }
        }
    }
}
