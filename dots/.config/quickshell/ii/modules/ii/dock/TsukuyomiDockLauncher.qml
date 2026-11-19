pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.services

PopupWindow {
    id: root
    required property Item launcherButton
    readonly property var entries: {
        if (!root.visible) return [];
        const query = search.text.trim();
        const apps = query.length > 0 ? AppSearch.fuzzyQuery(query) : [...AppSearch.list]
            .sort((a, b) => a.name.localeCompare(b.name));
        return apps.filter(app => !app.noDisplay);
    }
    visible: false
    grabFocus: true
    color: "transparent"
    implicitWidth: Math.min(354, (launcherButton.QsWindow.window?.screen?.width ?? 400) - 20)
    implicitHeight: 334
    anchor.item: launcherButton
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top

    function activate(entry) {
        if (!entry) return;
        root.visible = false;
        entry.execute();
    }

    onVisibleChanged: {
        if (visible) {
            search.clear();
            Qt.callLater(() => search.forceActiveFocus());
        }
    }

    TsukuyomiSurface { anchors.fill: parent; radius: 16 }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            MaterialSymbol {
                text: "search"
                iconSize: 16
                color: TsukuyomiStyle.muted
            }
            TextField {
                id: search
                Layout.fillWidth: true
                placeholderText: Translation.tr("Find an app")
                Accessible.name: placeholderText
                font.family: Appearance.font.family.main
                font.pixelSize: 13
                color: TsukuyomiStyle.foreground
                placeholderTextColor: TsukuyomiStyle.muted
                leftPadding: 7
                rightPadding: 7
                background: Rectangle {
                    radius: 8
                    color: TsukuyomiStyle.raised
                    border.color: search.visualFocus ? TsukuyomiStyle.muted : TsukuyomiStyle.border
                }
                onTextChanged: results.currentIndex = 0
                onAccepted: root.activate(root.entries[results.currentIndex])
                Keys.onEscapePressed: root.visible = false
                Keys.onDownPressed: {
                    if (results.currentIndex < results.count - 1) results.incrementCurrentIndex();
                }
                Keys.onUpPressed: {
                    if (results.currentIndex > 0) results.decrementCurrentIndex();
                }
            }
        }

        ListView {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.entries
            currentIndex: 0
            clip: true
            spacing: 3
            keyNavigationEnabled: false
            ScrollBar.vertical: ScrollBar { }

            delegate: ItemDelegate {
                id: entry
                required property var modelData
                required property int index
                width: results.width - 8
                implicitHeight: 35
                leftPadding: 7
                rightPadding: 7
                Accessible.name: modelData.name
                onClicked: root.activate(modelData)
                Keys.onEscapePressed: root.visible = false
                background: Rectangle {
                    color: (entry.index === results.currentIndex || entry.hovered || entry.visualFocus)
                        ? TsukuyomiStyle.selection : "transparent"
                    radius: 7
                }
                contentItem: RowLayout {
                    spacing: 8
                    IconImage {
                        implicitSize: 23
                        source: Quickshell.iconPath(entry.modelData.icon || "application-x-executable", "image-missing")
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: entry.modelData.name
                        color: TsukuyomiStyle.foreground
                        font.family: Appearance.font.family.main
                        font.pixelSize: 13
                    }
                }
            }
        }
        Text {
            visible: results.count === 0
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: TsukuyomiStyle.muted
            text: Translation.tr("No applications found")
        }
    }
}
