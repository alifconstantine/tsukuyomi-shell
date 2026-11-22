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
    property string initialMode: Quickshell.env("TSUKUYOMI_COMPAT_MODE") || "isolated"
    property string step: targetFile !== "" ? "configure" : "pick" // pick | configure | running | shortcuts | done | error
    property var inspectData: ({})
    property var prefixes: []
    property var candidates: []
    property var selectedMap: ({})
    property var exportedApps: []

    property string appName: ""
    property string installMode: initialMode === "portable" ? "portable" : "isolated"
    property string existingSlug: ""
    property string runner: "wine"
    property bool useSandbox: true
    property bool useWayland: false
    property bool useDxvk: true
    property bool pinPortable: false
    property string errorText: ""
    property string activeSlug: ""

    function pickFile() {
        if (!filePicker.running)
            filePicker.running = true;
    }

    function loadInspect(filePath) {
        if (!filePath || filePath === "")
            return;
        root.targetFile = filePath;
        root.step = "configure";
        inspectProc.command = ["/usr/lib/tsukuyomi/tsukuyomi-win", "inspect", filePath];
        inspectProc.running = true;
        listProc.running = true;
    }

    function startInstall() {
        if (root.targetFile === "")
            return;
        root.errorText = "";
        root.step = "running";
        const cmd = [
            "/usr/lib/tsukuyomi/tsukuyomi-win", "install",
            "--file", root.targetFile,
            "--name", root.appName,
            "--mode", root.installMode,
            "--runner", root.runner,
            "--wayland", root.useWayland ? "true" : "false",
            "--sandbox", root.useSandbox ? "true" : "false",
            "--dxvk", root.useDxvk ? "true" : "false"
        ];
        if (root.installMode === "existing" && root.existingSlug !== "")
            cmd.push("--slug", root.existingSlug);
        if (root.installMode === "portable" && root.pinPortable)
            cmd.push("--pin-portable");
        installProc.command = cmd;
        installProc.running = true;
    }

    function cancelInstall() {
        if (root.activeSlug !== "") {
            cancelProc.command = ["/usr/lib/tsukuyomi/tsukuyomi-win", "cancel", root.activeSlug, "--cleanup"];
            cancelProc.running = true;
        }
        Qt.quit();
    }

    function exportSelected() {
        const picked = [];
        for (let i = 0; i < root.candidates.length; i++) {
            const c = root.candidates[i];
            if (root.selectedMap[c.exe] !== false)
                picked.push(c);
        }
        if (picked.length === 0) {
            root.step = "done";
            return;
        }
        exportProc.command = [
            "/usr/lib/tsukuyomi/tsukuyomi-win", "export-desktop",
            root.activeSlug, "--select", JSON.stringify(picked)
        ];
        exportProc.running = true;
    }

    Component.onCompleted: {
        if (root.targetFile !== "")
            root.loadInspect(root.targetFile);
        else
            listProc.running = true;
    }

    Process {
        id: filePicker
        command: ["sh", "-c", "command -v kdialog >/dev/null && kdialog --getopenfilename \"$HOME\" '*.exe *.msi *.lnk|Windows Executables' || zenity --file-selection --title='Select Windows Installer or App' --file-filter='Windows Files | *.exe *.msi *.lnk'"]
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
                    const obj = JSON.parse(text);
                    root.inspectData = obj;
                    if (obj.product_name)
                        root.appName = String(obj.product_name);
                } catch (e) {}
            }
        }
    }

    Process {
        id: listProc
        command: ["/usr/lib/tsukuyomi/tsukuyomi-win", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const obj = JSON.parse(text);
                    root.prefixes = obj.prefixes || [];
                    if (root.prefixes.length > 0 && root.existingSlug === "")
                        root.existingSlug = String(root.prefixes[0].slug || "");
                } catch (e) {}
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
                root.activeSlug = String(res.slug || "");
                if (res.exported && res.exported.length > 0) {
                    root.exportedApps = res.exported;
                    root.step = "done";
                    return;
                }
                if (res.mode === "portable") {
                    if (res.ok)
                        Qt.quit();
                    else {
                        root.errorText = installErr.text.trim() || I18n.tr("Portable execution exited with error.");
                        root.step = "error";
                    }
                    return;
                }
                const cands = res.candidates || [];
                root.candidates = cands;
                const map = {};
                for (let i = 0; i < cands.length; i++)
                    map[cands[i].exe] = true;
                root.selectedMap = map;
                if (cands.length > 0)
                    root.step = "shortcuts";
                else if (res.ok)
                    root.step = "done";
                else {
                    root.errorText = installErr.text.trim() || I18n.tr("Installer exited with an error.");
                    root.step = "error";
                }
            } catch (e) {
                root.errorText = installErr.text.trim() || I18n.tr("Failed to run Windows installer.");
                root.step = "error";
            }
        }
    }

    Process {
        id: exportProc
        stdout: StdioCollector { id: exportOut }
        onExited: code => {
            try {
                const res = JSON.parse(exportOut.text);
                root.exportedApps = res.exported || [];
            } catch (e) {}
            root.step = "done";
        }
    }

    Process {
        id: cancelProc
    }

    FloatingWindow {
        id: win
        title: I18n.tr("Tsukuyomi Windows Installer")
        implicitWidth: 580
        implicitHeight: 470
        color: Tsukuyomi.Style.surface
        visible: true

        Shortcut {
            sequence: "Escape"
            onActivated: root.step === "running" ? root.cancelInstall() : Qt.quit()
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
                    radius: 10
                    color: Tsukuyomi.Style.panel
                    border.width: 1
                    border.color: Tsukuyomi.Style.line

                    Image {
                        anchors.centerIn: parent
                        width: 34
                        height: 34
                        fillMode: Image.PreserveAspectFit
                        visible: root.inspectData.icon_preview && root.inspectData.icon_preview !== ""
                        source: visible ? ("file://" + root.inspectData.icon_preview) : ""
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !root.inspectData.icon_preview || root.inspectData.icon_preview === ""
                        text: "\ue875"
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
                        text: root.appName !== "" ? root.appName : I18n.tr("Windows Application Bridge")
                        color: Tsukuyomi.Style.text
                        font.family: Tokens.ui
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.targetFile !== ""
                            ? ((root.inspectData.arch || "PE") + (root.inspectData.version ? (" · v" + root.inspectData.version) : "") + " · " + String(root.inspectData.filename || ""))
                            : I18n.tr("Select or drop an .exe, .msi, or .lnk file")
                        color: Tsukuyomi.Style.muted
                        font.family: Tokens.mono
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                    }
                }
            }

            // Body container
            Item {
                width: parent.width
                height: parent.height - 122

                // Step: Pick
                Tsukuyomi.SectionCard {
                    visible: root.step === "pick"
                    anchors.fill: parent
                    title: I18n.tr("Select Windows Executable")
                    collapsible: false

                    Item {
                        width: parent.width
                        height: 250

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
                            width: parent.width - 40

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr("Drop a .exe or .msi setup file here")
                                color: Tsukuyomi.Style.secondary
                                font.family: Tokens.ui
                                font.pixelSize: 13
                            }
                            Btn {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr("Browse File...")
                                primary: true
                                onAct: root.pickFile()
                            }
                        }
                    }
                }

                // Step: Configure
                Flickable {
                    visible: root.step === "configure"
                    anchors.fill: parent
                    clip: true
                    contentHeight: cfgCol.height

                    Column {
                        id: cfgCol
                        width: parent.width
                        spacing: Tokens.s3

                        Tsukuyomi.SectionCard {
                            width: parent.width
                            title: I18n.tr("Installation Mode")
                            collapsible: false

                            Column {
                                width: parent.width
                                padding: Tokens.s3
                                spacing: Tokens.s2

                                Repeater {
                                    model: [
                                        { id: "isolated", title: I18n.tr("Install in Isolated Prefix (Recommended)"), desc: I18n.tr("Creates a clean sandboxed container and adds shortcuts to App Launcher.") },
                                        { id: "portable", title: I18n.tr("Run Portable (Sandboxed)"), desc: I18n.tr("Runs directly in Bubblewrap without modifying system state.") },
                                        { id: "existing", title: I18n.tr("Install into Existing Prefix"), desc: I18n.tr("Run inside an already installed application prefix.") }
                                    ]
                                    delegate: Rectangle {
                                        id: modeBtn
                                        required property var modelData
                                        width: parent.width - Tokens.s3 * 2
                                        height: 46
                                        radius: 8
                                        color: root.installMode === modeBtn.modelData.id ? Qt.alpha(Tsukuyomi.Style.accent, 0.14) : Tsukuyomi.Style.surface
                                        border.width: 1
                                        border.color: root.installMode === modeBtn.modelData.id ? Tsukuyomi.Style.accent : Tsukuyomi.Style.line

                                        Column {
                                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                                            spacing: 1
                                            Text { text: modeBtn.modelData.title; color: Tsukuyomi.Style.text; font.family: Tokens.ui; font.pixelSize: 12; font.weight: Font.Medium }
                                            Text { text: modeBtn.modelData.desc; color: Tsukuyomi.Style.muted; font.family: Tokens.ui; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.installMode = modeBtn.modelData.id
                                        }
                                    }
                                }
                            }
                        }

                        Tsukuyomi.SectionCard {
                            width: parent.width
                            title: I18n.tr("Runtime & Security")
                            collapsible: false

                            Column {
                                width: parent.width
                                padding: Tokens.s3
                                spacing: Tokens.s2

                                Row {
                                    width: parent.width - Tokens.s3 * 2
                                    spacing: Tokens.s3
                                    CheckBox {
                                        checked: root.useSandbox
                                        text: I18n.tr("Safe Sandbox (isolate ~/Documents & Z:\\)")
                                        onToggled: root.useSandbox = checked
                                    }
                                    CheckBox {
                                        checked: root.useDxvk
                                        text: I18n.tr("DXVK / VKD3D")
                                        onToggled: root.useDxvk = checked
                                    }
                                }
                                Row {
                                    width: parent.width - Tokens.s3 * 2
                                    spacing: Tokens.s3
                                    CheckBox {
                                        checked: root.useWayland
                                        text: I18n.tr("Native Wayland Driver (Experimental)")
                                        onToggled: root.useWayland = checked
                                    }
                                    CheckBox {
                                        visible: root.installMode === "portable"
                                        checked: root.pinPortable
                                        text: I18n.tr("Pin to App Launcher")
                                        onToggled: root.pinPortable = checked
                                    }
                                }
                            }
                        }
                    }
                }

                // Step: Running
                Tsukuyomi.SectionCard {
                    visible: root.step === "running"
                    anchors.fill: parent
                    title: I18n.tr("Running Windows Setup")
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
                            text: I18n.tr("Complete the Windows setup wizard if one appeared. Tsukuyomi WinBridge will scan new Start Menu shortcuts automatically when setup closes.")
                            color: Tsukuyomi.Style.secondary
                            font.family: Tokens.ui
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Step: Shortcuts selection
                Tsukuyomi.SectionCard {
                    visible: root.step === "shortcuts"
                    anchors.fill: parent
                    title: I18n.tr("Add Shortcuts to App Launcher")
                    collapsible: false

                    Flickable {
                        width: parent.width
                        height: 245
                        clip: true
                        contentHeight: scCol.height

                        Column {
                            id: scCol
                            width: parent.width
                            padding: Tokens.s3
                            spacing: Tokens.s2

                            Repeater {
                                model: root.candidates
                                delegate: CheckBox {
                                    required property var modelData
                                    checked: root.selectedMap[modelData.exe] !== false
                                    text: modelData.name + " (" + String(modelData.exe).split("/").pop() + ")"
                                    onToggled: {
                                        const m = Object.assign({}, root.selectedMap);
                                        m[modelData.exe] = checked;
                                        root.selectedMap = m;
                                    }
                                }
                            }
                        }
                    }
                }

                // Step: Done / Error
                Tsukuyomi.SectionCard {
                    visible: root.step === "done" || root.step === "error"
                    anchors.fill: parent
                    title: root.step === "done" ? I18n.tr("Ready in App Launcher") : I18n.tr("Installation Failed")
                    collapsible: false

                    Column {
                        width: parent.width
                        padding: Tokens.s4
                        spacing: Tokens.s3

                        Text {
                            width: parent.width - Tokens.s4 * 2
                            text: root.step === "done"
                                ? I18n.tr("%1 shortcut(s) added to App Launcher (Super+Space).").arg(root.exportedApps.length)
                                : root.errorText
                            color: Tsukuyomi.Style.text
                            font.family: Tokens.ui
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // Footer ActionBar
            Row {
                width: parent.width
                layoutDirection: Qt.RightToLeft
                spacing: Tokens.s2

                Btn {
                    visible: root.step === "configure"
                    text: root.installMode === "portable" && !root.pinPortable ? I18n.tr("Run Now") : I18n.tr("Install")
                    primary: true
                    onAct: root.startInstall()
                }
                Btn {
                    visible: root.step === "shortcuts"
                    text: I18n.tr("Add to Launcher")
                    primary: true
                    onAct: root.exportSelected()
                }
                Btn {
                    visible: root.step === "done" && root.exportedApps.length > 0
                    text: I18n.tr("Launch App")
                    primary: true
                    onAct: {
                        Quickshell.execDetached(["/usr/lib/tsukuyomi/win-launch", String(root.exportedApps[0].id)]);
                        Qt.quit();
                    }
                }
                Btn {
                    text: root.step === "running" ? I18n.tr("Cancel Setup") : (root.step === "done" ? I18n.tr("Close") : I18n.tr("Cancel"))
                    onAct: root.step === "running" ? root.cancelInstall() : Qt.quit()
                }
            }
        }
    }
}
