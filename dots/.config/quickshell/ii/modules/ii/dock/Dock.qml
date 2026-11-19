import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Scope { // Scope
    id: root
    property bool pinned: Config.options?.dock.pinnedOnStartup ?? false

    Variants {
        // For each monitor
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            // Window
            required property var modelData
            screen: modelData
            readonly property var monitor: Hyprland.monitorFor(modelData)
            readonly property var workspace: monitor?.activeWorkspace
            readonly property bool fullscreen: workspace?.toplevels.values.some(window => window.wayland?.fullscreen) ?? false
            readonly property bool workspaceEmpty: (workspace?.toplevels.values.length ?? 0) === 0
            visible: !GlobalStates.screenLocked && !fullscreen
            onVisibleChanged: {
                if (!visible && launcherMenu) launcherMenu.visible = false;
            }

            property bool reveal: root.pinned || (Config.options?.dock.hoverToReveal && dockMouseArea.containsMouse)
                || dockApps.requestDockShow || launcherMenu.visible || workspaceEmpty

            anchors {
                bottom: true
                left: true
                right: true
            }

            exclusiveZone: root.pinned ? implicitHeight - (Appearance.sizes.hyprlandGapsOut) - (Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut) : 0

            implicitWidth: dockBackground.implicitWidth
            WlrLayershell.namespace: "quickshell:dock"
            color: "transparent"

            implicitHeight: (Config.options?.dock.height ?? 70) + Appearance.sizes.elevationMargin + Appearance.sizes.hyprlandGapsOut

            mask: Region {
                item: dockMouseArea
            }

            MouseArea {
                id: dockMouseArea
                height: parent.height
                anchors {
                    top: parent.top
                    topMargin: dockRoot.reveal ? 0 : Config.options?.dock.hoverToReveal ? (dockRoot.implicitHeight - Config.options.dock.hoverRegionHeight) : (dockRoot.implicitHeight + 1)
                    horizontalCenter: parent.horizontalCenter
                }
                implicitWidth: dockHoverRegion.implicitWidth + Appearance.sizes.elevationMargin * 2
                hoverEnabled: true

                Behavior on anchors.topMargin {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                Item {
                    id: dockHoverRegion
                    anchors.fill: parent
                    implicitWidth: dockBackground.implicitWidth

                    Item { // Wrapper for the dock background
                        id: dockBackground
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                        }

                        implicitWidth: dockRow.implicitWidth + 8 * 2
                        height: parent.height - Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut

                        StyledRectangularShadow {
                            target: dockVisualBackground
                        }
                        TsukuyomiSurface {
                            id: dockVisualBackground
                            property real margin: Appearance.sizes.elevationMargin
                            anchors.fill: parent
                            anchors.topMargin: Appearance.sizes.elevationMargin
                            anchors.bottomMargin: Appearance.sizes.hyprlandGapsOut
                            radius: 17
                            upperColor: TsukuyomiStyle.glass ? (TsukuyomiStyle.dark ? "#c63a404c" : "#ddffffff") : TsukuyomiStyle.surface
                            lowerColor: TsukuyomiStyle.glass ? (TsukuyomiStyle.dark ? "#b51b2029" : "#c9dfe4eb") : TsukuyomiStyle.surface
                        }

                        RowLayout {
                            id: dockRow
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3
                            property real padding: 5

                            DockButton {
                                id: launcher
                                Layout.fillHeight: true
                                Accessible.name: Translation.tr("Applications")
                                Loader {
                                    active: launcher.hovered && !launcherMenu.visible
                                    sourceComponent: TsukuyomiTooltip {
                                        owner: launcher
                                        text: Translation.tr("Applications")
                                        above: true
                                    }
                                }
                                onClicked: launcherMenu.visible = !launcherMenu.visible
                                topInset: Appearance.sizes.hyprlandGapsOut + dockRow.padding
                                bottomInset: Appearance.sizes.hyprlandGapsOut + dockRow.padding
                                contentItem: Item {
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 32
                                        height: 32
                                        radius: 10
                                        color: launcherMenu.visible ? TsukuyomiStyle.selection : TsukuyomiStyle.raised
                                        border.color: TsukuyomiStyle.border
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            iconSize: 21
                                            text: "grid_view"
                                            color: TsukuyomiStyle.foreground
                                        }
                                    }
                                }
                            }
                            TsukuyomiDockLauncher {
                                id: launcherMenu
                                launcherButton: launcher
                            }
                            DockApps {
                                id: dockApps
                                buttonPadding: dockRow.padding
                            }
                        }
                    }
                }
            }
        }
    }
}
