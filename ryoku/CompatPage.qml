pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."
import "../tsukuyomi" as Tsukuyomi

Item {
    id: page

    property var hub
    readonly property bool fullBleed: true

    property string currentTab: "Windows (WinBridge)"
    property var winStatus: ({})
    readonly property var winConfig: winStatus.config || ({})
    property var winApps: []
    property var droidStatus: ({})
    readonly property var droidGpu: droidStatus.gpu || ({})
    readonly property var droidArm: droidStatus.armTranslation || ({})
    readonly property var droidConfig: droidStatus.config || ({})
    property var droidApps: []
    property string statusNotice: ""
    property bool busy: winStatusProc.running || droidStatusProc.running || actionProc.running

    function refreshAll() {
        winStatusProc.running = true;
        winListProc.running = true;
        droidStatusProc.running = true;
        droidListProc.running = true;
    }

    function runAction(cmd, notice) {
        if (actionProc.running)
            return;
        page.statusNotice = notice || "";
        actionProc.command = cmd;
        actionProc.running = true;
    }

    Process {
        id: winStatusProc
        command: ["tsukuyomi-win", "status"]
        running: true
        stdout: StdioCollector { id: winStatusOut }
        onExited: code => {
            if (code === 0) {
                try { page.winStatus = JSON.parse(winStatusOut.text); } catch (e) {}
            }
        }
    }

    Process {
        id: winListProc
        command: ["tsukuyomi-win", "list"]
        running: true
        stdout: StdioCollector { id: winListOut }
        onExited: code => {
            if (code === 0) {
                try {
                    const data = JSON.parse(winListOut.text);
                    page.winApps = data.apps || [];
                } catch (e) {}
            }
        }
    }

    Process {
        id: droidStatusProc
        command: ["tsukuyomi-droid", "status"]
        running: true
        stdout: StdioCollector { id: droidStatusOut }
        onExited: code => {
            if (code === 0) {
                try { page.droidStatus = JSON.parse(droidStatusOut.text); } catch (e) {}
            }
        }
    }

    Process {
        id: droidListProc
        command: ["tsukuyomi-droid", "list"]
        running: true
        stdout: StdioCollector { id: droidListOut }
        onExited: code => {
            if (code === 0) {
                try {
                    const data = JSON.parse(droidListOut.text);
                    const all = data.apps || [];
                    const showSys = !!(data.config && data.config.showSystemApps);
                    page.droidApps = all.filter(function (a) { return showSys || !a.system; });
                } catch (e) {}
            }
        }
    }

    Process {
        id: actionProc
        stdout: StdioCollector { id: actionOut }
        stderr: StdioCollector { id: actionErr }
        onExited: code => {
            if (code !== 0) {
                let detail = actionErr.text.trim();
                try { detail = JSON.parse(actionOut.text).error || detail; } catch (e) {}
                page.statusNotice = detail || I18n.tr("The action could not finish. Check runtime status and try again.");
            }
            page.refreshAll();
        }
    }

    Process {
        id: termActionProc
        onExited: page.refreshAll()
    }

    SchemaPage {
        id: settings

        anchors.fill: parent
        anchors.margins: Tokens.s6
        schema: []
        draft: null
        defaults: ({})
        title: I18n.tr("Compatibility")
        eyebrow: I18n.tr("SYSTEM")
        blurb: I18n.tr("Install Windows and Android apps, manage their settings, and open them from App Launcher.")

        Column {
            width: parent.width
            spacing: Tokens.s4

            Tsukuyomi.Tabs {
                width: parent.width
                options: ["Windows (WinBridge)", "Android (DroidBridge)"]
                current: page.currentTab
                onChose: opt => page.currentTab = opt
            }

            Text {
                width: parent.width
                visible: page.statusNotice !== ""
                text: page.statusNotice
                color: Tsukuyomi.Style.secondary
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall
                wrapMode: Text.WordWrap
            }

            // ─── Windows (WinBridge) ───────────────────────────────────────
            Column {
                width: parent.width
                visible: page.currentTab === "Windows (WinBridge)"
                spacing: Tokens.s4

                SettingCard {
                    width: parent.width
                    title: I18n.tr("WinBridge Runtime")
                    collapsible: false

                    Column {
                        x: Tokens.s4
                        width: parent.width - 2 * x
                        topPadding: Tokens.s3
                        bottomPadding: Tokens.s4
                        spacing: Tokens.s3

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            color: Tsukuyomi.Style.secondary
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall
                            text: page.winStatus.wineAvailable
                                ? I18n.tr("Bundled Windows runtime ready") : I18n.tr("Windows runtime unavailable")
                                + "  ·  NTSync: " + (page.winStatus.ntsyncAvailable ? I18n.tr("Active") : I18n.tr("Unavailable"))
                                + "  ·  Sandbox: " + (page.winStatus.bwrapAvailable ? I18n.tr("Bubblewrap Ready") : I18n.tr("Missing"))
                                + "  ·  DXVK: " + (page.winStatus.dxvkAvailable ? I18n.tr("Ready") : I18n.tr("Missing"))
                        }

                        Flow {
                            width: parent.width
                            spacing: Tokens.s2
                            Btn {
                                text: I18n.tr("Install Windows App")
                                onAct: Quickshell.execDetached(["tsukuyomi-win-installer"])
                            }
                            Btn {
                                text: I18n.tr("Refresh")
                                enabled: !page.busy
                                onAct: page.refreshAll()
                            }
                            Btn {
                                text: I18n.tr("Optional Gaming Store Add-ons")
                                onAct: Quickshell.execDetached(["ryostore", "open", "compat-addons"])
                            }
                        }
                    }
                }

                SettingCard {
                    width: parent.width
                    title: I18n.tr("Default Prefix & Security Policy")
                    collapsible: false

                    Column {
                        x: Tokens.s4
                        width: parent.width - 2 * x
                        topPadding: Tokens.s3
                        bottomPadding: Tokens.s4
                        spacing: Tokens.s3

                        Flow {
                            width: parent.width
                            spacing: Tokens.s2

                            Btn {
                                readonly property string nextRunner: (page.winConfig.defaultRunner || "wine") === "wine" ? "umu" : "wine"
                                text: I18n.tr("Runner: ") + String(page.winConfig.defaultRunner || "wine").toUpperCase()
                                enabled: !page.busy
                                onAct: page.runAction(["tsukuyomi-win", "set-defaults", "--runner", nextRunner], I18n.tr("Updated default runner."))
                            }
                            Btn {
                                readonly property bool curSandbox: page.winConfig.defaultSandbox !== false
                                text: I18n.tr("Bubblewrap Sandbox: ") + (curSandbox ? I18n.tr("ON") : I18n.tr("OFF"))
                                enabled: !page.busy
                                onAct: page.runAction(["tsukuyomi-win", "set-defaults", "--sandbox", curSandbox ? "false" : "true"], I18n.tr("Updated default sandbox policy."))
                            }
                            Btn {
                                readonly property bool curWayland: !!page.winConfig.defaultWayland
                                text: I18n.tr("Wine Wayland Driver: ") + (curWayland ? I18n.tr("ON") : I18n.tr("OFF (XWayland IME)"))
                                enabled: !page.busy
                                onAct: page.runAction(["tsukuyomi-win", "set-defaults", "--wayland", curWayland ? "false" : "true"], I18n.tr("Updated Wine display driver default."))
                            }
                            Btn {
                                readonly property bool curDxvk: page.winConfig.defaultDxvk !== false
                                text: I18n.tr("DXVK / VKD3D: ") + (curDxvk ? I18n.tr("ON") : I18n.tr("OFF"))
                                enabled: !page.busy
                                onAct: page.runAction(["tsukuyomi-win", "set-defaults", "--dxvk", curDxvk ? "false" : "true"], I18n.tr("Updated DXVK default."))
                            }
                        }
                    }
                }

                SettingCard {
                    width: parent.width
                    title: I18n.tr("Installed Windows Applications") + " (" + page.winApps.length + ")"
                    collapsible: false

                    Column {
                        x: Tokens.s4
                        width: parent.width - 2 * x
                        topPadding: Tokens.s3
                        bottomPadding: Tokens.s4
                        spacing: Tokens.s3

                        Text {
                            width: parent.width
                            visible: page.winApps.length === 0
                            color: Tsukuyomi.Style.muted
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall
                            text: I18n.tr("No Windows applications exported yet. Open any .exe or .msi to create an isolated prefix.")
                            wrapMode: Text.WordWrap
                        }

                        Repeater {
                            model: page.winApps
                            delegate: Rectangle {
                                id: winRow
                                required property var modelData
                                width: parent.width
                                height: winCol.implicitHeight + Tokens.s3 * 2
                                radius: 10
                                color: Tsukuyomi.Style.surface
                                border.width: 1
                                border.color: Tsukuyomi.Style.line

                                Column {
                                    id: winCol
                                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Tokens.s3 }
                                    spacing: Tokens.s2

                                    Text {
                                        width: parent.width
                                        text: (winRow.modelData.name || winRow.modelData.id) + "  [" + String(winRow.modelData.runner || "wine").toUpperCase() + (winRow.modelData.sandbox === false ? " · Unsandboxed" : " · bwrap") + "]"
                                        color: Tsukuyomi.Style.text
                                        font.family: Tokens.ui
                                        font.pixelSize: Tokens.fBody
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: winRow.modelData.exe || ""
                                        color: Tsukuyomi.Style.muted
                                        font.family: Tokens.mono
                                        font.pixelSize: Tokens.fSmall
                                        elide: Text.ElideMiddle
                                    }
                                    Flow {
                                        width: parent.width
                                        spacing: Tokens.s2
                                        Btn {
                                            text: I18n.tr("Launch")
                                            onAct: Quickshell.execDetached(["tsukuyomi-win", "run", winRow.modelData.id])
                                        }
                                        Btn {
                                            text: I18n.tr("Winecfg")
                                            onAct: Quickshell.execDetached(["tsukuyomi-win", "winecfg", winRow.modelData.id])
                                        }
                                        Btn {
                                            text: I18n.tr("Prefix Folder")
                                            onAct: Quickshell.execDetached(["tsukuyomi-win", "open-prefix", winRow.modelData.id])
                                        }
                                        Btn {
                                            text: I18n.tr("Toggle Sandbox")
                                            enabled: !page.busy
                                            onAct: page.runAction(["tsukuyomi-win", "configure", winRow.modelData.id, "--sandbox", winRow.modelData.sandbox === false ? "true" : "false"], I18n.tr("Updated app sandbox setting."))
                                        }
                                        Btn {
                                            text: I18n.tr("Uninstall")
                                            enabled: !page.busy
                                            onAct: page.runAction(["tsukuyomi-win", "uninstall", winRow.modelData.id], I18n.tr("Uninstalled ") + (winRow.modelData.name || winRow.modelData.id))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ─── Android (DroidBridge) ─────────────────────────────────────
            Column {
                width: parent.width
                visible: page.currentTab === "Android (DroidBridge)"
                spacing: Tokens.s4

                SettingCard {
                    width: parent.width
                    title: I18n.tr("DroidBridge Runtime (Waydroid + Gamescope)")
                    collapsible: false

                    Column {
                        x: Tokens.s4
                        width: parent.width - 2 * x
                        topPadding: Tokens.s3
                        bottomPadding: Tokens.s4
                        spacing: Tokens.s3

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            color: Tsukuyomi.Style.secondary
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall
                            text: I18n.tr("Initialized: ") + (page.droidStatus.initialized ? I18n.tr("Yes") : I18n.tr("No (Ready Offline)"))
                                + "  ·  " + I18n.tr("Container: ") + (page.droidStatus.sessionRunning ? I18n.tr("Running") : I18n.tr("Sleeping"))
                                + "  ·  " + I18n.tr("GPU: ") + String(page.droidGpu.mode || "auto").toUpperCase()
                                + "  ·  " + I18n.tr("ARM Translation: ") + (page.droidArm.libndk ? "libndk" : (page.droidArm.libhoudini ? "libhoudini" : I18n.tr("Not Installed")))
                        }

                        Flow {
                            width: parent.width
                            spacing: Tokens.s2

                            Btn {
                                text: I18n.tr("Install Android App")
                                onAct: Quickshell.execDetached(["tsukuyomi-droid-installer"])
                            }
                            Btn {
                                visible: !page.droidStatus.initialized
                                text: I18n.tr("Initialize Offline")
                                enabled: !page.busy
                                onAct: page.runAction(["tsukuyomi-droid", "init", "--offline"], I18n.tr("Initialized Android runtime offline."))
                            }
                            Btn {
                                text: I18n.tr("Open Android")
                                onAct: Quickshell.execDetached(["tsukuyomi-droid", "open-ui"])
                            }
                            Btn {
                                text: I18n.tr("Sleep Container")
                                enabled: !page.busy
                                onAct: page.runAction(["tsukuyomi-droid", "sleep"], I18n.tr("Android container stopped to free RAM."))
                            }
                            Btn {
                                text: I18n.tr("Sync Launcher Apps")
                                enabled: !page.busy
                                onAct: page.runAction(["tsukuyomi-droid", "sync-desktop"], I18n.tr("Synced Android launcher shortcuts."))
                            }
                        }
                    }
                }

                SettingCard {
                    width: parent.width
                    title: I18n.tr("Viewport Size, Downloads & Game Mode")
                    collapsible: false

                    Column {
                        x: Tokens.s4
                        width: parent.width - 2 * x
                        topPadding: Tokens.s3
                        bottomPadding: Tokens.s4
                        spacing: Tokens.s3

                        Flow {
                            width: parent.width
                            spacing: Tokens.s2
                            Repeater {
                                model: ["compact", "phone", "tablet", "landscape", "reset"]
                                delegate: Btn {
                                    id: presetBtn
                                    required property string modelData
                                    text: I18n.tr("Resize: ") + presetBtn.modelData.charAt(0).toUpperCase() + presetBtn.modelData.slice(1)
                                    onAct: Quickshell.execDetached(["tsukuyomi-droid", "resize", presetBtn.modelData])
                                }
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: Tokens.s2

                            Btn {
                                readonly property bool curSys: !!page.droidConfig.showSystemApps
                                text: I18n.tr("System Apps in Launcher: ") + (curSys ? I18n.tr("SHOWN") : I18n.tr("HIDDEN"))
                                enabled: !page.busy
                                onAct: page.runAction(["tsukuyomi-droid", "set-config", "--show-system-apps", curSys ? "false" : "true"], I18n.tr("Updated system app visibility."))
                            }
                            Btn {
                                readonly property bool curDl: !!page.droidConfig.sharedDownloads
                                text: I18n.tr("Share ~/Downloads: ") + (curDl ? I18n.tr("ON") : I18n.tr("OFF (Isolated)"))
                                enabled: !page.busy
                                onAct: page.runAction(["tsukuyomi-droid", "set-config", "--shared-downloads", curDl ? "false" : "true"], I18n.tr("Updated shared Downloads setting."))
                            }
                            Btn {
                                readonly property string curRes: String(page.droidConfig.gameResolution || "1280x720")
                                readonly property string nextRes: curRes === "1280x720" ? "1920x1080" : (curRes === "1920x1080" ? "2560x1440" : "1280x720")
                                text: I18n.tr("Game Mode Res: ") + curRes
                                enabled: !page.busy
                                onAct: page.runAction(["tsukuyomi-droid", "set-config", "--game-resolution", nextRes], I18n.tr("Updated Gamescope target resolution."))
                            }
                        }
                    }
                }

                SettingCard {
                    width: parent.width
                    title: I18n.tr("Optional ARM Translation & Google Play (Requires Internet)")
                    collapsible: false

                    Column {
                        x: Tokens.s4
                        width: parent.width - 2 * x
                        topPadding: Tokens.s3
                        bottomPadding: Tokens.s4
                        spacing: Tokens.s3

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            color: Tsukuyomi.Style.muted
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall
                            text: I18n.tr("Install upstream ARM translation libraries (for ARM-only APKs and mobile games) or OpenGApps via terminal setup.")
                        }

                        Flow {
                            width: parent.width
                            spacing: Tokens.s2
                            Btn {
                                text: I18n.tr("Install libndk (AMD/Universal ARM)")
                                enabled: !termActionProc.running
                                onAct: {
                                    termActionProc.command = ["kitty", "-e", "bash", "-lc", "tsukuyomi-droid setup-addon libndk; echo; read -r -p 'Press Enter to close...'"];
                                    termActionProc.running = true;
                                }
                            }
                            Btn {
                                text: I18n.tr("Install libhoudini (Intel)")
                                enabled: !termActionProc.running
                                onAct: {
                                    termActionProc.command = ["kitty", "-e", "bash", "-lc", "tsukuyomi-droid setup-addon libhoudini; echo; read -r -p 'Press Enter to close...'"];
                                    termActionProc.running = true;
                                }
                            }
                            Btn {
                                text: I18n.tr("Install Google Play (GAPPS)")
                                enabled: !termActionProc.running
                                onAct: {
                                    termActionProc.command = ["kitty", "-e", "bash", "-lc", "tsukuyomi-droid setup-addon gapps; echo; read -r -p 'Press Enter to close...'"];
                                    termActionProc.running = true;
                                }
                            }
                        }
                    }
                }

                SettingCard {
                    width: parent.width
                    title: I18n.tr("Installed Android Applications") + " (" + page.droidApps.length + ")"
                    collapsible: false

                    Column {
                        x: Tokens.s4
                        width: parent.width - 2 * x
                        topPadding: Tokens.s3
                        bottomPadding: Tokens.s4
                        spacing: Tokens.s3

                        Text {
                            width: parent.width
                            visible: page.droidApps.length === 0
                            color: Tsukuyomi.Style.muted
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall
                            text: I18n.tr("No Android apps listed yet. Initialize Android Offline or install an .apk/.xapk.")
                            wrapMode: Text.WordWrap
                        }

                        Repeater {
                            model: page.droidApps
                            delegate: Rectangle {
                                id: droidRow
                                required property var modelData
                                width: parent.width
                                height: droidCol.implicitHeight + Tokens.s3 * 2
                                radius: 10
                                color: Tsukuyomi.Style.surface
                                border.width: 1
                                border.color: Tsukuyomi.Style.line

                                Column {
                                    id: droidCol
                                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Tokens.s3 }
                                    spacing: Tokens.s2

                                    Text {
                                        width: parent.width
                                        text: (droidRow.modelData.name || droidRow.modelData.package) + "  [" + String(droidRow.modelData.mode || "phone") + "]"
                                        color: Tsukuyomi.Style.text
                                        font.family: Tokens.ui
                                        font.pixelSize: Tokens.fBody
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: droidRow.modelData.package || ""
                                        color: Tsukuyomi.Style.muted
                                        font.family: Tokens.mono
                                        font.pixelSize: Tokens.fSmall
                                        elide: Text.ElideRight
                                    }
                                    Flow {
                                        width: parent.width
                                        spacing: Tokens.s2
                                        Btn {
                                            text: I18n.tr("Launch")
                                            onAct: Quickshell.execDetached(["tsukuyomi-droid", "launch", droidRow.modelData.package])
                                        }
                                        Btn {
                                            readonly property string curMode: String(droidRow.modelData.mode || "phone")
                                            readonly property string nextMode: curMode === "phone" ? "landscape" : (curMode === "landscape" ? "game-gamescope" : "phone")
                                            text: I18n.tr("Mode: ") + curMode
                                            enabled: !page.busy
                                            onAct: page.runAction(["tsukuyomi-droid", "set-profile", droidRow.modelData.package, "--mode", nextMode], I18n.tr("Updated Android launch mode."))
                                        }
                                        Btn {
                                            text: I18n.tr("Force Stop")
                                            enabled: !page.busy
                                            onAct: page.runAction(["tsukuyomi-droid", "force-stop", droidRow.modelData.package], I18n.tr("Stopped ") + (droidRow.modelData.name || droidRow.modelData.package))
                                        }
                                        Btn {
                                            text: I18n.tr("Uninstall")
                                            enabled: !page.busy
                                            onAct: page.runAction(["tsukuyomi-droid", "uninstall", droidRow.modelData.package], I18n.tr("Uninstalled ") + (droidRow.modelData.name || droidRow.modelData.package))
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
}
