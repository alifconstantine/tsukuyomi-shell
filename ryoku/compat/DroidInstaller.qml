pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "tsukuyomi" as Tsukuyomi

ShellRoot {
    id: root

    property string targetFile: Quickshell.env("TSUKUYOMI_COMPAT_FILE") || ""
    property string step: targetFile !== "" ? "inspecting" : "pick"
    property var inspectData: ({})
    readonly property bool hasIconPreview: Boolean(inspectData && inspectData.icon_preview && String(inspectData.icon_preview) !== "")
    property string errorText: ""
    property bool installingAddon: false
    property bool launcherReady: false
    readonly property bool needsArm: !!inspectData.needs_arm_translation && !inspectData.arm_translation_installed

    function pickFile() {
        if (!filePicker.running)
            filePicker.running = true;
    }

    function loadInspect(filePath) {
        if (!filePath || filePath === "")
            return;
        root.targetFile = filePath;
        root.step = "inspecting";
        root.inspectData = {};
        root.errorText = "";
        inspectProc.command = ["/usr/lib/tsukuyomi/tsukuyomi-droid", "inspect", filePath];
        inspectProc.running = true;
    }

    function installArmTranslation() {
        if (root.installingAddon)
            return;
        root.installingAddon = true;
        addonProc.running = true;
    }

    function startInstall() {
        if (root.targetFile === "" || root.needsArm || root.installingAddon || installProc.running)
            return;
        root.errorText = "";
        root.step = "running";
        installProc.command = [
            "/usr/lib/tsukuyomi/tsukuyomi-droid", "install",
            root.targetFile
        ];
        installProc.running = true;
    }

    Component.onCompleted: {
        if (root.targetFile !== "")
            root.loadInspect(root.targetFile);
    }

    Process {
        id: filePicker
        command: ["sh", "-c", "if command -v kdialog >/dev/null; then exec kdialog --getopenfilename \"$HOME\" '*.apk *.xapk *.apkm|Android Packages'; else exec zenity --file-selection --title='Select Android Package' --file-filter='Android Packages | *.apk *.xapk *.apkm'; fi"]
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
        stdout: StdioCollector { id: inspectOut }
        onExited: code => {
            try {
                const obj = JSON.parse(inspectOut.text);
                if (code !== 0 || obj.error)
                    throw new Error(obj.error);
                root.inspectData = obj;
                root.step = "configure";
            } catch (e) {
                root.errorText = e.message || I18n.tr("Could not read the Android package.");
                root.step = "error";
            }
        }
    }

    Process {
        id: addonProc
        command: ["/usr/lib/tsukuyomi/tsukuyomi-droid", "setup-addon", "libndk"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            root.installingAddon = false;
            if (code === 0)
                root.loadInspect(root.targetFile);
            else {
                root.errorText = I18n.tr("Could not install ARM support. Check your connection and try again.");
                root.step = "error";
            }
        }
    }

    Process {
        id: installProc
        stdout: StdioCollector { id: installOut }
        stderr: StdioCollector { id: installErr }
        onExited: code => {
            try {
                const res = JSON.parse(installOut.text);
                if (code === 0 && res.ok) {
                    root.launcherReady = res.launcherReady === true;
                    root.inspectData = Object.assign({}, root.inspectData, {package: res.package, name: res.name});
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
            onActivated: if (root.step !== "running" && !root.installingAddon) Qt.quit()
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
                        visible: root.hasIconPreview
                        source: root.hasIconPreview ? ("file://" + String(root.inspectData.icon_preview)) : ""
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !root.hasIconPreview
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

                Flickable {
                    visible: root.step === "configure" && !root.installingAddon
                    anchors.fill: parent
                    clip: true
                    contentHeight: settingsColumn.implicitHeight

                    Column {
                        id: settingsColumn
                        width: parent.width
                        spacing: Tokens.s3

                        Rectangle {
                            width: parent.width
                            visible: root.needsArm
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
                                    text: I18n.tr("This app requires ARM support. The add-on downloads once and can take a few minutes.")
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

                        Text {
                            width: parent.width
                            visible: !root.needsArm
                            text: I18n.tr("Install this app to open it from App Launcher.")
                            color: Tsukuyomi.Style.secondary
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fBody
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Tsukuyomi.SectionCard {
                    visible: root.step === "inspecting" || root.step === "running" || root.installingAddon
                    anchors.fill: parent
                    title: root.installingAddon ? I18n.tr("Installing ARM Support")
                        : root.step === "inspecting" ? I18n.tr("Reading Android Package") : I18n.tr("Installing Android App")
                    collapsible: false

                    Column {
                        width: parent.width
                        padding: Tokens.s5
                        spacing: Tokens.s3
                        Controls.BusyIndicator {
                            width: 28
                            height: 28
                            running: parent.parent.visible
                        }
                        Text {
                            width: parent.width - Tokens.s5 * 2
                            visible: root.step === "running"
                            text: I18n.tr("Starting Android and installing the app. The first start can take a minute.")
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
                    title: root.step === "error" ? I18n.tr("Android App Could Not Install")
                        : root.launcherReady ? I18n.tr("Ready in App Launcher") : I18n.tr("Android App Installed")
                    collapsible: false

                    Column {
                        width: parent.width
                        padding: Tokens.s4
                        spacing: Tokens.s3
                        Text {
                            width: parent.width - Tokens.s4 * 2
                            text: root.step === "done"
                                ? (root.launcherReady ? I18n.tr("Open the app from App Launcher (Super+Space).")
                                   : I18n.tr("Android installed the package. App Launcher has no shortcut for it yet."))
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
                    visible: root.step === "configure" && !root.installingAddon
                    enabled: !root.needsArm
                    text: I18n.tr("Install App")
                    primary: true
                    onAct: root.startInstall()
                }
                Btn {
                    visible: root.step === "done" && root.launcherReady
                    text: I18n.tr("Launch App")
                    primary: true
                    onAct: {
                        Quickshell.execDetached(["/usr/lib/tsukuyomi/droid-launch", String(root.inspectData.package)]);
                        Qt.quit();
                    }
                }
                Btn {
                    visible: root.step === "error"
                    text: I18n.tr("Choose File")
                    primary: true
                    onAct: root.pickFile()
                }
                Btn {
                    visible: root.step === "error" && !!root.inspectData.package
                    text: I18n.tr("Try Again")
                    onAct: root.step = "configure"
                }
                Btn {
                    visible: root.step === "error" && !!root.inspectData.split
                    text: I18n.tr("Open Android")
                    onAct: Quickshell.execDetached(["/usr/lib/tsukuyomi/tsukuyomi-droid", "open-ui"])
                }
                Btn {
                    visible: root.step !== "running" && !root.installingAddon
                    text: root.step === "done" ? I18n.tr("Close") : I18n.tr("Cancel")
                    onAct: Qt.quit()
                }
            }
        }
    }
}
