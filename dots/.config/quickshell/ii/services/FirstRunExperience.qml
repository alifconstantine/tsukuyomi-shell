pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string firstRunFilePath: `${Directories.state}/user/first_run.txt`
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property string firstRunNotifSummary: "Welcome!"
    property string firstRunNotifBody: "Hit Super+/ for a list of keybinds"
    property string defaultWallpaperPath: FileUtils.trimFileProtocol(`${Directories.assetsPath}/images/default_wallpaper.webp`)
    property string welcomeQmlPath: FileUtils.trimFileProtocol(Quickshell.shellPath("welcome.qml"))
    property bool pendingFirstRun: false

    function load() {
        firstRunFileView.reload()
    }

    function enableNextTime() {
        Quickshell.execDetached(["rm", "-f", root.firstRunFilePath])
    }
    function disableNextTime() {
        Quickshell.execDetached(["bash", "-c", `echo '${root.firstRunFileContent}' > '${root.firstRunFilePath}'`])
    }

    function handleFirstRun() {
        const targetWall = Config.options.background.wallpaperPath.length > 0
            ? Config.options.background.wallpaperPath
            : root.defaultWallpaperPath
        if (Config.options.background.wallpaperPath.length === 0) {
            Config.options.background.wallpaperPath = targetWall
        }
        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, targetWall])
        Quickshell.execDetached(["bash", "-c", `qs -p '${root.welcomeQmlPath}'`])
    }

    function maybeTriggerFirstRun() {
        if (!root.pendingFirstRun || !Config.ready) return;
        root.pendingFirstRun = false;
        firstRunFileView.setText(root.firstRunFileContent);
        root.handleFirstRun();
    }

    Connections {
        target: Config
        function onReadyChanged() {
            root.maybeTriggerFirstRun();
        }
    }

    FileView {
        id: firstRunFileView
        path: Qt.resolvedUrl(firstRunFilePath)
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) {
                root.pendingFirstRun = true;
                root.maybeTriggerFirstRun();
            }
        }
    }
}
