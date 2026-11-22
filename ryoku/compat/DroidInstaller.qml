pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "tsukuyomi" as Tsukuyomi

ShellRoot {
    id: root

    property string targetFile: Quickshell.env("TSUKUYOMI_COMPAT_FILE") || ""
    property string step: targetFile !== "" ? "configure" : "pick" // pick | configure | running | done | error
    property var inspectData: ({})
    property string launchMode: "phone" // phone | landscape | game-gamescope
    property string errorText: ""
    property bool installingAddon: false

    function pickFile() {
        if (!filePicker.running)
            filePicker.running = true;
    }

    function loadInspect(filePath) {
        if (!filePath || filePath === "")
            return;
        root.targetFile = filePath;
        root.step = "configure";
        inspectProc.command = ["/usr/lib/tsukuyomi/tsukuyomi-droid", "inspect", filePath];
        inspectProc.running = true;
    }

    function installArmTranslation() {
        if (root.installingAddon)
            return;
        root.installingAddon = true;
        addonProc.command = ["/usr/lib/tsukuyomi/tsukuyomi-droid", "setup-addon", "libndk"];
        addonProc.running = true;
    }

    function startInstall() {
        if (root.targetFile === "")
            return;
        root.errorText = "";
        root.step = "running";
        installProc.command = [
            "/usr/lib/tsukuyomi/tsukuyomi-droid", "install",
            root.targetFile, "--mode", root.launchMode
        ];
        installProc.running = true;
    }

    Component.onCompleted: {
        if (root.targetFile !== "")
            root.loadInspect(root.targetFile);
    }

    Process {
        id: filePicker
        command: ["sh", "-c", "command -v kdialog >/dev/null && kdialog --getopenfilename \"$HOME\" '*.apk *.xapk *.apkm|Android Packages' || zenity --file-selection --title='Select Android Package' --file-filter='Android Packages | *.apk *.xapk *.apkm'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const picked = text.trim();
                if (picked !== "")
                    root.loadInspect(picked);
            }
        }
    }

    Process {
        id: inspectProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.inspectData = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: addonProc
        onExited: code => {
            root.installingAddon = false;
            if (code === 0)
                root.loadInspect(root.targetFile);
        }
    }

    Process {
        id: installProc
        stdout: StdioCollector { id: installOut }
        stderr: StdioCollector { id: installErr }
        onExited: code => {
            try {
                const res = JSON.parse(installOut.text);
                if (res.ok) {
                    root.step = "done";
                    return;
                }
                root.errorText = String(res.error || installErr.text || I18n.tr("Failed to install Android package."));
            } catch (e) {
                root.errorText = installErr.text.trim() || I18n.tr("Failed to install Android package.");
            }
            root.step = "error";
        }
    }

    FloatingWindow {
        id: win
        title: I18n.tr("Tsukuyomi Android Installer")
        implicitWidth: 580
        implicitHeight: 460
        color: Tsukuyomi.Style.surface
        visible: true

        Shortcut {
            sequence: "Escape"
            onActivated: if (root.step !== "running") Qt.quit()
        }

        Column {
            anchors.fill: parent
            anchors.margins: Tokens.s5
            spacing: Tokens.s4

            // Header
            Row {
                width: parent.width
                spacing: Tokens.s3

                Rectangle {
                    width: 48
                    height: 48
                    radius: 12
                    color: Tsukuyomi.Style.panel
                    border.width: 1
                    border.color: Tsukuyomi.Style.line

                    Image {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        fillMode: Image.PreserveAspectFit
                        visible: root.inspectData.icon_preview && root.inspectData.icon_preview !== ""
                        source: visible ? ("file://" + root.inspectData.icon_preview) : ""
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !root.inspectData.icon_preview || root.inspectData.icon_preview === ""
                        text: "\ue859"
                        font.family: Tsukuyomi.Style.icons
                        font.pixelSize: 24
                        color: Tsukuyomi.Style.accent
                    }
                }

                Column {
                    width: parent.width - 60
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: root.inspectData.name ? String(root.inspectData.name) : I18n.tr("Android Application Bridge")
                        color: Tsukuyomi.Style.text
                        font.family: Tokens.ui
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.inspectData.package
                            ? (String(root.inspectData.package) + (root.inspectData.version_name ? (" · v" + root.inspectData.version_name) : ""))
                            : (root.targetFile !== "" ? String(root.targetFile).split("/").pop() : I18n.tr("Select or drop an .apk, .xapk, or .apkm file"))
                        color: Tsukuyomi.Style.muted
                        font.family: Tokens.mono
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - 122

                Tsukuyomi.SectionCard {
                    visible: root.step === "pick"
                    anchors.fill: parent
                    title: I18n.tr("Select Android Package")
                    collapsible: false

                    Item {
                        width: parent.width
                        height: 240
                        DropArea {
                            anchors.fill: parent
                            onDropped: drop => {
                                if (drop.urls && drop.urls.length > 0) {
                                    const path = String(drop.urls[0]).replace(/^file:\/\//, "");
                                    root.loadInspect(decodeURIComponent(path));
                                }
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: Tokens.s3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr("Drop an .apk, .xapk, or .apkm bundle here")
                                color: Tsukuyomi.Style.secondary
                                font.family: Tokens.ui
                                font.pixelSize: 13
                            }
                            Btn {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr("Browse Package...")
                                primary: true
                                onAct: root.pickFile()
                            }
                        }
                    }
                }

                Column {
                    visible: root.step === "configure"
                    anchors.fill: parent
                    spacing: Tokens.s3

                    Rectangle {
                        width: parent.width
                        visible: !!root.inspectData.needs_arm_translation && !root.inspectData.arm_translation_installed
                        height: visible ? 58 : 0
                        radius: 10
                        color: Qt.alpha(Tsukuyomi.Style.accent, 0.14)
                        border.width: 1
                        border.color: Tsukuyomi.Style.accent

                        Row {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            Text {
                                width: parent.width - armBtn.width - 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("This APK targets ARM (%1). Install ARM translation (libndk) first so it runs on x86_64.").arg((root.inspectData.abis || []).join(", "))
                                color: Tsukuyomi.Style.text
                                font.family: Tokens.ui
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                            Btn {
                                id: armBtn
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.installingAddon ? I18n.tr("Installing...") : I18n.tr("Install ARM")
                                enabled: !root.installingAddon
                                primary: true
                                onAct: root.installArmTranslation()
                            }
                        }
                    }

                    Tsukuyomi.SectionCard {
                        width: parent.width
                        title: I18n.tr("Window & Orientation Profile")
                        collapsible: false

                        Column {
                            width: parent.width
                            padding: Tokens.s3
                            spacing: Tokens.s2

                            Repeater {
                                model: [
                                    { id: "phone", title: I18n.tr("Phone Window (9:16 Multi-Window)"), desc: I18n.tr("Best for messaging, social, and daily Android apps alongside Linux windows.") },
                                    { id: "landscape", title: I18n.tr("Landscape Tablet (16:9 Multi-Window)"), desc: I18n.tr("Wide layout with mouse-as-touch enabled.") },
                                    { id: "game-gamescope", title: I18n.tr("Game Mode (Gamescope 16:9 Resizable / Fullscreen)"), desc: I18n.tr("Hardware-scaled landscape viewport; drag resize or press Super+F cleanly.") }
                                ]
                                delegate: Rectangle {
                                    id: modeBtn
                                    required property var modelData
                                    width: parent.width - Tokens.s3 * 2
                                    height: 52
                                    radius: 8
                                    color: root.launchMode === modeBtn.modelData.id ? Qt.alpha(Tsukuyomi.Style.accent, 0.14) : Tsukuyomi.Style.surface
                                    border.width: 1
                                    border.color: root.launchMode === modeBtn.modelData.id ? Tsukuyomi.Style.accent : Tsukuyomi.Style.line

                                    Column {
                                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                                        spacing: 1
                                        Text { text: modeBtn.modelData.title; color: Tsukuyomi.Style.text; font.family: Tokens.ui; font.pixelSize: 12; font.weight: Font.Medium }
                                        Text { text: modeBtn.modelData.desc; color: Tsukuyomi.Style.muted; font.family: Tokens.ui; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.launchMode = modeBtn.modelData.id
                                    }
                                }
                            }
                        }
                    }
                }

                Tsukuyomi.SectionCard {
                    visible: root.step === "running"
                    anchors.fill: parent
                    title: I18n.tr("Installing Android App")
                    collapsible: false

                    Column {
                        width: parent.width
                        padding: Tokens.s5
                        spacing: Tokens.s3
                        ProgressBar {
                            width: parent.width - Tokens.s5 * 2
                            indeterminate: true
                        }
                        Text {
                            width: parent.width - Tokens.s5 * 2
                            text: I18n.tr("Preparing Waydroid container, installing package, and syncing launcher shortcut...")
                            color: Tsukuyomi.Style.secondary
                            font.family: Tokens.ui
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Tsukuyomi.SectionCard {
                    visible: root.step === "done" || root.step === "error"
                    anchors.fill: parent
                    title: root.step === "done" ? I18n.tr("Installed & Added to App Launcher") : I18n.tr("Installation Failed")
                    collapsible: false

                    Column {
                        width: parent.width
                        padding: Tokens.s4
                        spacing: Tokens.s3
                        Text {
                            width: parent.width - Tokens.s4 * 2
                            text: root.step === "done"
                                ? I18n.tr("%1 is ready in App Launcher (Super+Space). Press Alt+R while focused to cycle Phone/Tablet/Landscape sizes.").arg(root.inspectData.name || root.inspectData.package || "App")
                                : root.errorText
                            color: Tsukuyomi.Style.text
                            font.family: Tokens.ui
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Row {
                width: parent.width
                layoutDirection: Qt.RightToLeft
                spacing: Tokens.s2

                Btn {
                    visible: root.step === "configure"
                    text: I18n.tr("Install App")
                    primary: true
                    onAct: root.startInstall()
                }
                Btn {
                    visible: root.step === "done" && !!root.inspectData.package
                    text: I18n.tr("Launch App")
                    primary: true
                    onAct: {
                        Quickshell.execDetached(["/usr/lib/tsukuyomi/droid-launch", String(root.inspectData.package)]);
                        Qt.quit();
                    }
                }
                Btn {
                    visible: root.step !== "running"
                    text: root.step === "done" ? I18n.tr("Close") : I18n.tr("Cancel")
                    onAct: Qt.quit()
                }
            }
        }
    }
}
