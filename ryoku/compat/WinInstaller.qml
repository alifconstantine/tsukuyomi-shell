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
    property string initialMode: Quickshell.env("TSUKUYOMI_COMPAT_MODE") || "isolated"
    property string step: targetFile !== "" ? "inspecting" : "pick"
    property var inspectData: ({})
    readonly property bool hasIconPreview: Boolean(inspectData && inspectData.icon_preview && String(inspectData.icon_preview) !== "")
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
    property bool shareInstallerFolder: false
    property string errorText: ""
    property string activeSlug: ""
    property bool cancelling: false

    readonly property var availableModes: {
        const list = [
            { id: "isolated", title: I18n.tr("Install Windows App"), desc: I18n.tr("Set up the app in its own environment and add it to App Launcher.") }
        ];
        if (root.inspectData.kind !== "msi")
            list.push({ id: "portable", title: I18n.tr("Run Without Installing"), desc: I18n.tr("Open a portable app directly.") });
        if (root.prefixes.length > 0) {
            list.push({ id: "existing", title: I18n.tr("Update or Use Existing Environment"), desc: I18n.tr("Run setup in an environment you already created.") });
        }
        return list;
    }

    component TogglePill: Rectangle {
        id: tp
        property bool checked: false
        property string label: ""
        signal toggled(bool nextState)

        width: tpRow.implicitWidth + 20
        height: 30
        radius: 8
        color: tp.checked ? Qt.alpha(Tsukuyomi.Style.accent, 0.16) : Tsukuyomi.Style.surface
        border.width: 1
        border.color: tp.checked ? Tsukuyomi.Style.accent : Tsukuyomi.Style.line

        Row {
            id: tpRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tp.checked ? "\ue834" : "\ue835"
                font.family: Tsukuyomi.Style.icons
                font.pixelSize: 15
                color: tp.checked ? Tsukuyomi.Style.accent : Tsukuyomi.Style.muted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tp.label
                color: Tsukuyomi.Style.text
                font.family: Tokens.ui
                font.pixelSize: 11
                font.weight: tp.checked ? Font.DemiBold : Font.Normal
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tp.toggled(!tp.checked)
        }
    }

    function pickFile() {
        if (!filePicker.running)
            filePicker.running = true;
    }

    function loadInspect(filePath) {
        if (!filePath || filePath === "")
            return;
        root.targetFile = filePath;
        root.shareInstallerFolder = false;
        root.step = "inspecting";
        root.inspectData = {};
        root.appName = "";
        inspectProc.command = ["/usr/lib/tsukuyomi/tsukuyomi-win", "inspect", filePath];
        inspectProc.running = true;
        listProc.running = true;
    }

    function startInstall() {
        if (root.targetFile === "" || installProc.running || listProc.running)
            return;
        root.errorText = "";
        root.step = "running";

        const cmd = [
            "/usr/lib/tsukuyomi/tsukuyomi-win", "install",
            "--file", root.targetFile,
            "--name", root.appName,
            "--mode", root.installMode,
            "--slug", root.installMode === "existing" ? root.existingSlug : "",
            "--runner", root.runner,
            "--wayland", root.useWayland ? "true" : "false",
            "--sandbox", root.useSandbox ? "true" : "false",
            "--dxvk", root.useDxvk ? "true" : "false"
        ];
        if (root.installMode === "portable" && root.pinPortable)
            cmd.push("--pin-portable");
        if (root.useSandbox && root.shareInstallerFolder)
            cmd.push("--share-installer-folder");
        installProc.command = cmd;
        installProc.running = true;
    }

    function cancelInstall() {
        if (root.cancelling || !installProc.running)
            return;
        root.cancelling = true;
        installProc.signal(15);
    }

    function exportSelected() {
        const picked = [];
        for (let i = 0; i < root.candidates.length; i++) {
            const c = root.candidates[i];
            if (root.selectedMap[c.exe] !== false)
                picked.push(c);
        }
        if (picked.length === 0 || exportProc.running)
            return;
        root.step = "exporting";
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
        command: ["sh", "-c", "if command -v kdialog >/dev/null; then exec kdialog --getopenfilename \"$HOME\" '*.exe *.msi *.lnk|Windows Executables'; else exec zenity --file-selection --title='Select Windows Installer or App' --file-filter='Windows Files | *.exe *.msi *.lnk'; fi"]
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
                if (obj.arch === "arm64")
                    throw new Error(I18n.tr("This file is for ARM64. Choose the Windows x64 or x86 download."));
                root.inspectData = obj;
                if (obj.kind === "msi" && root.installMode === "portable")
                    root.installMode = "isolated";
                root.appName = String(obj.product_name || "");
                root.step = "configure";
            } catch (e) {
                root.errorText = e.message || I18n.tr("Could not read the selected Windows file.");
                root.step = "error";
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
                    root.prefixes = (obj.prefixes || []).filter(p => p.slug !== "portable-sandbox" && p.meta.appliedState);
                    if (root.prefixes.length > 0 && root.existingSlug === "")
                        root.existingSlug = String(root.prefixes[0].slug || "");
                    if (obj.config) {
                        root.useSandbox = obj.config.defaultSandbox !== false;
                        root.useWayland = obj.config.defaultWayland === true;
                        root.useDxvk = obj.config.defaultDxvk !== false;
                        root.runner = obj.config.defaultRunner || "wine";
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: installProc
        stdout: StdioCollector { id: installOut }
        stderr: StdioCollector {}
        onExited: code => {
            try {
                const res = JSON.parse(installOut.text);
                if (res.cancelled) {
                    Qt.quit();
                    return;
                }
                root.cancelling = false;
                if (!res.ok || code !== 0) {
                    root.errorText = String(res.error || I18n.tr("Windows setup did not finish."));
                    root.step = "error";
                    return;
                }
                if (res.slug)
                    root.activeSlug = String(res.slug);
                if (res.exported && res.exported.length > 0) {
                    root.exportedApps = res.exported;
                    root.step = "done";
                    return;
                }
                if (res.mode === "portable") {
                    Qt.quit();
                    return;
                }
                const cands = res.candidates || [];
                root.candidates = cands;
                const map = {};
                for (let i = 0; i < cands.length; i++)
                    map[cands[i].exe] = true;
                root.selectedMap = map;
                if (cands.length === 1)
                    root.exportSelected();
                else if (cands.length > 1)
                    root.step = "shortcuts";
                else {
                    root.exportedApps = [];
                    root.step = "done";
                }
            } catch (e) {
                if (root.cancelling) {
                    Qt.quit();
                    return;
                }
                root.errorText = I18n.tr("Could not run Windows setup. Choose the file again or try changing its setup options.");
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
                if (!res.ok || code !== 0)
                    throw new Error(res.error);
                root.exportedApps = res.exported;
                root.step = "done";
            } catch (e) {
                root.errorText = e.message || I18n.tr("Could not add the app to App Launcher.");
                root.step = "error";
            }
        }
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
            onActivated: {
                if (root.step === "running")
                    root.cancelInstall();
                else if (root.step !== "exporting")
                    Qt.quit();
            }
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
                        sourceSize: Qt.size(68, 68)
                        asynchronous: true
                        cache: false
                        visible: root.hasIconPreview
                        source: root.hasIconPreview ? ("file://" + String(root.inspectData.icon_preview)) : ""
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !root.hasIconPreview
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
                            ? ((root.inspectData.version ? ("v" + root.inspectData.version + " · ") : "")
                               + String(root.inspectData.filename || root.targetFile.split("/").pop()))
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
                                    model: root.availableModes
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

                                Flow {
                                    visible: root.installMode === "existing" && root.prefixes.length > 0
                                    width: parent.width - Tokens.s3 * 2
                                    spacing: 6
                                    Repeater {
                                        model: root.prefixes
                                        delegate: TogglePill {
                                            id: pfxPill
                                            required property var modelData
                                            checked: root.existingSlug === String(pfxPill.modelData.slug || "")
                                            label: String(pfxPill.modelData.slug || "")
                                            onToggled: root.existingSlug = String(pfxPill.modelData.slug || "")
                                        }
                                    }
                                }
                            }
                        }

                        Tsukuyomi.SectionCard {
                            width: parent.width
                            title: I18n.tr("Advanced Options")
                            expanded: false

                            Column {
                                width: parent.width
                                padding: Tokens.s3
                                spacing: Tokens.s2

                                Flow {
                                    width: parent.width - Tokens.s3 * 2
                                    spacing: 8
                                    TogglePill {
                                        checked: root.useSandbox
                                        label: I18n.tr("Bubblewrap Isolation")
                                        onToggled: next => root.useSandbox = next
                                    }
                                    TogglePill {
                                        checked: root.useDxvk
                                        label: I18n.tr("DXVK / VKD3D")
                                        onToggled: next => root.useDxvk = next
                                    }
                                    TogglePill {
                                        checked: root.useWayland
                                        label: I18n.tr("Native Wayland Driver")
                                        onToggled: next => root.useWayland = next
                                    }
                                    TogglePill {
                                        checked: root.runner === "umu"
                                        label: root.runner === "umu" ? I18n.tr("Runner: UMU Proton") : I18n.tr("Runner: Wine Staging")
                                        onToggled: next => {
                                            root.runner = next ? "umu" : "wine";
                                            if (next)
                                                root.useSandbox = false;
                                        }
                                    }
                                    TogglePill {
                                        visible: root.installMode === "portable"
                                        checked: root.pinPortable
                                        label: I18n.tr("Pin to App Launcher")
                                        onToggled: next => root.pinPortable = next
                                    }
                                    TogglePill {
                                        visible: root.useSandbox && !(root.installMode === "portable" && root.pinPortable)
                                        checked: root.shareInstallerFolder
                                        label: I18n.tr("Share Installer Folder (Read Only)")
                                        onToggled: next => root.shareInstallerFolder = next
                                    }
                                }
                                Text {
                                    width: parent.width - Tokens.s3 * 2
                                    visible: root.runner === "umu" && root.useSandbox
                                    text: I18n.tr("Select Wine Staging to use Bubblewrap isolation.")
                                    color: Tsukuyomi.Style.secondary
                                    font.family: Tokens.ui
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }

                // Step: Running
                Tsukuyomi.SectionCard {
                    visible: ["inspecting", "running", "exporting"].includes(root.step)
                    anchors.fill: parent
                    title: root.step === "inspecting" ? I18n.tr("Reading Windows File")
                        : root.step === "exporting" ? I18n.tr("Adding to App Launcher")
                        : root.cancelling ? I18n.tr("Cancelling Setup") : I18n.tr("Setting Up Windows App")
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
                            visible: root.step === "running" && !root.cancelling
                            text: I18n.tr("Follow the Windows setup window. Shortcuts are added when setup finishes.")
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
                                delegate: TogglePill {
                                    id: candPill
                                    required property var modelData
                                    checked: root.selectedMap[candPill.modelData.exe] !== false
                                    label: candPill.modelData.name + " (" + String(candPill.modelData.exe).split("/").pop() + ")"
                                    onToggled: next => {
                                        const m = Object.assign({}, root.selectedMap);
                                        m[candPill.modelData.exe] = next;
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
                    title: root.step === "error" ? I18n.tr("Windows Setup Could Not Finish")
                        : root.exportedApps.length > 0 ? I18n.tr("Ready in App Launcher") : I18n.tr("Windows Setup Finished")
                    collapsible: false

                    Column {
                        width: parent.width
                        padding: Tokens.s4
                        spacing: Tokens.s3

                        Text {
                            width: parent.width - Tokens.s4 * 2
                            text: root.step === "done"
                                ? (root.exportedApps.length > 0 ? I18n.tr("Open the app from App Launcher (Super+Space).")
                                   : I18n.tr("Setup finished. It did not create an application shortcut."))
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
                    enabled: !listProc.running && !(root.runner === "umu" && root.useSandbox) && (root.installMode !== "existing" || root.existingSlug !== "")
                    text: root.installMode === "portable" && !root.pinPortable ? I18n.tr("Run Now") : I18n.tr("Install")
                    primary: true
                    onAct: root.startInstall()
                }
                Btn {
                    visible: root.step === "shortcuts"
                    enabled: root.candidates.some(c => root.selectedMap[c.exe] !== false)
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
                    visible: root.step === "error"
                    text: I18n.tr("Choose File")
                    primary: true
                    onAct: root.pickFile()
                }
                Btn {
                    visible: root.step === "error" && !!root.inspectData.product_name
                    text: I18n.tr("Setup Options")
                    onAct: root.step = "configure"
                }
                Btn {
                    visible: root.step !== "exporting"
                    enabled: !root.cancelling
                    text: root.step === "running" ? I18n.tr("Cancel Setup") : (root.step === "done" ? I18n.tr("Close") : I18n.tr("Cancel"))
                    onAct: root.step === "running" ? root.cancelInstall() : Qt.quit()
                }
            }
        }
    }
}
