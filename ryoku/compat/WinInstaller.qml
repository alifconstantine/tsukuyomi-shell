pragma ComponentBehavior: Bound

import QtQuick
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
    property string errorText: ""
    property string activeSlug: ""

    readonly property var availableModes: {
        const list = [
            { id: "isolated", title: I18n.tr("Install in Isolated Prefix (Recommended)"), desc: I18n.tr("Creates a clean sandboxed container and adds shortcuts to App Launcher.") },
            { id: "portable", title: I18n.tr("Run Portable (Sandboxed)"), desc: I18n.tr("Runs directly in Bubblewrap without modifying system state.") }
        ];
        if (root.prefixes.length > 0) {
            list.push({ id: "existing", title: I18n.tr("Install into Existing Prefix"), desc: I18n.tr("Run inside an already installed application prefix.") });
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

    function computeSlug(rawName) {
        const base = String(rawName || "win-app").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 56) || "win-app";
        const used = {};
        for (let i = 0; i < root.prefixes.length; i++)
            used[String(root.prefixes[i].slug || "")] = true;
        if (!used[base])
            return base;
        let idx = 2;
        while (used[base + "-" + idx])
            idx++;
        return base + "-" + idx;
    }

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
        const chosenSlug = root.installMode === "existing"
            ? (root.existingSlug || "win-app")
            : (root.installMode === "portable" && !root.pinPortable
               ? "portable-sandbox"
               : root.computeSlug(root.appName || root.inspectData.product_name || "win-app"));
        root.activeSlug = chosenSlug;

        const cmd = [
            "/usr/lib/tsukuyomi/tsukuyomi-win", "install",
            "--file", root.targetFile,
            "--name", root.appName,
            "--mode", root.installMode,
            "--slug", chosenSlug,
            "--runner", root.runner,
            "--wayland", root.useWayland ? "true" : "false",
            "--sandbox", root.useSandbox ? "true" : "false",
            "--dxvk", root.useDxvk ? "true" : "false"
        ];
        if (root.installMode === "portable" && root.pinPortable)
            cmd.push("--pin-portable");
        installProc.command = cmd;
        installProc.running = true;
    }

    function cancelInstall() {
        if (installProc.running)
            installProc.running = false;
        if (root.activeSlug !== "") {
            const args = ["/usr/lib/tsukuyomi/tsukuyomi-win", "cancel", root.activeSlug];
            if (root.installMode === "isolated")
                args.push("--cleanup");
            cancelProc.command = args;
            cancelProc.running = true;
        } else {
            Qt.quit();
        }
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
            if (cancelProc.running)
                return;
            try {
                const res = JSON.parse(installOut.text);
                if (res.slug)
                    root.activeSlug = String(res.slug);
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
        onExited: Qt.quit()
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
                            title: I18n.tr("Runtime & Security")
                            collapsible: false

                            Column {
                                width: parent.width
                                padding: Tokens.s3
                                spacing: Tokens.s2

                                Flow {
                                    width: parent.width - Tokens.s3 * 2
                                    spacing: 8
                                    TogglePill {
                                        checked: root.useSandbox
                                        label: I18n.tr("Safe Sandbox (bwrap)")
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
                                        onToggled: next => root.runner = next ? "umu" : "wine"
                                    }
                                    TogglePill {
                                        visible: root.installMode === "portable"
                                        checked: root.pinPortable
                                        label: I18n.tr("Pin to App Launcher")
                                        onToggled: next => root.pinPortable = next
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

                        Rectangle {
                            width: parent.width - Tokens.s5 * 2
                            height: 6
                            radius: 3
                            color: Tsukuyomi.Style.line
                            Rectangle {
                                width: parent.width * 0.38
                                height: parent.height
                                radius: 3
                                color: Tsukuyomi.Style.accent
                            }
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
