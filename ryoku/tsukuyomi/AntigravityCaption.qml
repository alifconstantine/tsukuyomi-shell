pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Ryoku.Ui.Singletons

PanelWindow {
    id: caption

    readonly property var window: Wm.focusedWindow
    readonly property string candidate: Wm.caps.windowGeometry && window
        && String(window.appId).toLowerCase() === "antigravity.exe" && !window.floating
        ? String(window.id) : ""
    property string matched: ""

    // Confirm that this is the primary XWayland window managed by the
    // corresponding Hyprland rule. Native Wine and dialogs keep their controls.
    onCandidateChanged: {
        if (candidate && !windowCheck.running)
            windowCheck.running = true;
    }

    Process {
        id: windowCheck
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const active = JSON.parse(text);
                    caption.matched = active.xwayland && active.fullscreen === 1
                        && String(active.initialTitle).toLowerCase() === "antigravity"
                        && String(active.initialClass).toLowerCase() === "antigravity.exe"
                        ? String(active.address) : "";
                } catch (error) {
                    caption.matched = "";
                }
            }
        }
    }

    screen: window ? (Quickshell.screens.find(screen => screen.name === window.output) ?? null) : null
    visible: Boolean(screen && candidate && matched === candidate)
    anchors { top: true; right: true }
    margins.top: screen && window ? Math.max(0, window.y - screen.y) : 0
    margins.right: screen && window ? Math.max(0, screen.x + screen.width - window.x - window.width) : 0
    implicitWidth: 145
    implicitHeight: 32
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "tsukuyomi-antigravity-controls"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: Style.surface

    Row {
        anchors.fill: parent
        Repeater {
            model: [
                { icon: "−", name: qsTr("Minimize"), available: false },
                { icon: "□", name: qsTr("Resize"), available: false },
                { icon: "×", name: qsTr("Close"), available: true }
            ]

            Rectangle {
                id: control
                required property var modelData
                width: caption.width / 3
                height: caption.height
                color: hover.hovered && modelData.available ? "#C92A2A" : "transparent"
                enabled: modelData.available
                Accessible.role: Accessible.Button
                Accessible.name: modelData.name
                Accessible.onPressAction: {
                    if (enabled)
                        Wm.closeWindow(caption.candidate);
                }

                Text {
                    anchors.centerIn: parent
                    text: control.modelData.icon
                    color: hover.hovered && control.enabled ? "#FFFFFF" : (control.enabled ? Style.text : Style.muted)
                    font.pixelSize: 16
                }

                HoverHandler { id: hover }
                TapHandler { onTapped: Wm.closeWindow(caption.candidate) }
            }
        }
    }
}
