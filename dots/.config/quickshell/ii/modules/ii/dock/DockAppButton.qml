import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

DockButton {
    id: root
    property var appToplevel
    property var appListRoot
    property int lastFocused: -1
    property real iconSize: 35
    property bool appIsActive: appToplevel.toplevels.find(t => (t.activated == true)) !== undefined

    readonly property bool isSeparator: appToplevel.appId === "SEPARATOR"
    property var desktopEntry: DesktopEntries.heuristicLookup(appToplevel.appId)
    enabled: !isSeparator
    implicitWidth: isSeparator ? 1 : implicitHeight - topInset - bottomInset
    Accessible.name: desktopEntry?.name ?? appToplevel.appId
    ToolTip.visible: hovered && !isSeparator && appToplevel.toplevels.length === 0
    ToolTip.delay: 450
    ToolTip.text: Accessible.name

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.desktopEntry = DesktopEntries.heuristicLookup(appToplevel.appId);
        }
    }

    Loader {
        active: isSeparator
        anchors {
            fill: parent
            topMargin: root.topInset + 4
            bottomMargin: root.bottomInset + 4
        }
        sourceComponent: DockSeparator {}
    }

    Loader {
        anchors.fill: parent
        active: appToplevel.toplevels.length > 0
        sourceComponent: MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: {
                appListRoot.lastHoveredButton = root
                appListRoot.buttonHovered = true
                lastFocused = appToplevel.toplevels.length - 1
            }
            onExited: {
                if (appListRoot.lastHoveredButton === root) {
                    appListRoot.buttonHovered = false
                }
            }
        }
    }

    onClicked: {
        if (appToplevel.toplevels.length === 0) {
            root.desktopEntry?.execute();
            return;
        }
        lastFocused = (lastFocused + 1) % appToplevel.toplevels.length
        appToplevel.toplevels[lastFocused].activate()
    }

    middleClickAction: () => {
        root.desktopEntry?.execute();
    }

    altAction: () => {
        appListRoot.contextButton = root;
        appMenu.visible = true;
    }

    PopupWindow {
        id: appMenu
        visible: false
        grabFocus: true
        color: "transparent"
        implicitWidth: menuContents.implicitWidth + 16
        implicitHeight: menuContents.implicitHeight + 16
        anchor.item: root
        anchor.edges: Edges.Top | Edges.Right
        anchor.gravity: Edges.Top | Edges.Right

        onVisibleChanged: {
            if (!visible && root.appListRoot.contextButton === root)
                root.appListRoot.contextButton = null;
        }
        TsukuyomiSurface { anchors.fill: parent; radius: 12 }
        ColumnLayout {
            id: menuContents
            anchors.fill: parent
            anchors.margins: 8
            TsukuyomiButton {
                Layout.fillWidth: true
                flatSurface: true
                glyph: "add"
                text: Translation.tr("Open New Window")
                enabled: root.desktopEntry !== null
                onClicked: {
                    appMenu.visible = false;
                    root.desktopEntry?.execute();
                }
            }
            TsukuyomiButton {
                Layout.fillWidth: true
                flatSurface: true
                glyph: "keep"
                text: root.appToplevel.pinned ? Translation.tr("Unpin from Dock") : Translation.tr("Pin to Dock")
                onClicked: {
                    appMenu.visible = false;
                    TaskbarApps.togglePin(root.appToplevel.appId);
                }
            }
        }
    }

    contentItem: Loader {
        active: !isSeparator
        sourceComponent: Item {
            anchors.centerIn: parent

            Loader {
                id: iconImageLoader
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                active: !root.isSeparator
                sourceComponent: IconImage {
                    source: Quickshell.iconPath(AppSearch.guessIcon(appToplevel.appId), "image-missing")
                    implicitSize: root.iconSize
                }
            }

            Loader {
                active: Config.options.dock.monochromeIcons
                anchors.fill: iconImageLoader
                sourceComponent: Item {
                    Desaturate {
                        id: desaturatedIcon
                        visible: false // There's already color overlay
                        anchors.fill: parent
                        source: iconImageLoader
                        desaturation: 0.8
                    }
                    ColorOverlay {
                        anchors.fill: desaturatedIcon
                        source: desaturatedIcon
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                    }
                }
            }

            Rectangle {
                visible: appToplevel.toplevels.length > 0
                anchors {
                    top: iconImageLoader.bottom
                    topMargin: 2
                    horizontalCenter: parent.horizontalCenter
                }
                width: 4
                height: 4
                radius: 2
                color: appIsActive ? TsukuyomiStyle.foreground : TsukuyomiStyle.muted
            }
        }
    }
}
