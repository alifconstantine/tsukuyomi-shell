import QtQuick
import Quickshell
import Quickshell.Io
import shell.services
import Ryoku.Ui.Singletons

// Files Hub & Toolbox:
// Hub shows 9 actions (Shelf, Compress, Convert, Extract, Copy to, Move To, GDrive, OpenWith, Delete).
// Entering any sub-menu reveals a prominent < Back header + format-aware UX.
Item {
    id: fl

    property var root: null
    property var theme: _fallbackTheme
    NotchTheme { id: _fallbackTheme; root: null }
    readonly property bool anim: !Perf.reduceMotion

    property int imgQuality: 75
    property bool deletePermanent: false
    property string customDest: (Quickshell.env("HOME") || "") + "/Downloads"

    Connections {
        target: NotchFilesStore
        function onPickedDestDirChanged() {
            if (NotchFilesStore.pickedDestDir !== "")
                fl.customDest = NotchFilesStore.pickedDestDir;
        }
    }

    readonly property var tools: [
        { id: "shelf",    label: "Shelf",    icon: "inventory_2",  hint: "Pin & stage files" },
        { id: "compress", label: "Compress", icon: "compress",     hint: "Archive / Image / PDF" },
        { id: "convert",  label: "Convert",  icon: "transform",    hint: "Format conversion" },
        { id: "extract",  label: "Extract",  icon: "unarchive",    hint: "ZIP / TAR / 7Z" },
        { id: "copy",     label: "Copy to",  icon: "file_copy",    hint: "Duplicate to folder" },
        { id: "move",     label: "Move To",  icon: "drive_file_move", hint: "Relocate items" },
        { id: "gdrive",   label: "GDrive",   icon: "cloud",        hint: "Google Drive sync" },
        { id: "openwith", label: "OpenWith", icon: "open_in_new",  hint: "Choose app handler" },
        { id: "delete",   label: "Delete",   icon: "delete",       hint: "Trash or erase" }
    ]

    Process {
        id: clipPathPaste
        command: ["wl-paste", "-n"]
        stdout: StdioCollector {
            onStreamFinished: NotchFilesStore.pastePathFromClipboard(text)
        }
    }

    function toolMeta(id) {
        for (var i = 0; i < fl.tools.length; i++)
            if (fl.tools[i].id === id) return fl.tools[i];
        return fl.tools[0];
    }

    component ActionPill: Rectangle {
        id: ap
        property string icon: ""
        property string label: ""
        property bool primary: false
        property bool danger: false
        property bool enabledBtn: true
        signal clicked()

        height: 28
        width: Math.max(76, apRow.implicitWidth + 18)
        radius: 9
        opacity: ap.enabledBtn ? 1.0 : 0.45
        color: ap.danger
            ? Qt.rgba(fl.theme.danger.r, fl.theme.danger.g, fl.theme.danger.b, 0.20)
            : (ap.primary ? fl.theme.accent : (apMa.containsMouse ? fl.theme.cardHover : fl.theme.card))
        border.width: 1
        border.color: ap.danger ? fl.theme.danger : (ap.primary ? fl.theme.accent : fl.theme.border)

        Row {
            id: apRow
            anchors.centerIn: parent
            spacing: 4
            NotchIcon {
                visible: ap.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: ap.icon
                font.pixelSize: 13
                color: ap.danger ? fl.theme.danger : (ap.primary ? fl.theme.onAccent : fl.theme.ink)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ap.label
                color: ap.danger ? fl.theme.danger : (ap.primary ? fl.theme.onAccent : fl.theme.ink)
                font.family: Tokens.ui
                font.pixelSize: 10
                font.weight: (ap.primary || ap.danger) ? Font.DemiBold : Font.Medium
            }
        }
        MouseArea {
            id: apMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: ap.enabledBtn
            cursorShape: Qt.PointingHandCursor
            onClicked: ap.clicked()
        }
    }

    readonly property var contextActions: {
        if (NotchFilesStore.selectedCount === 0) return [];
        var list = [{ id: "compress", label: "Compress", icon: "compress", primary: false, danger: false }];
        if (NotchFilesStore.selectionCategory !== "archive" && NotchFilesStore.selectionCategory !== "folder")
            list.push({ id: "convert", label: "Convert", icon: "transform", primary: false, danger: false });
        if (NotchFilesStore.archiveSelected)
            list.push({ id: "extract", label: "Extract", icon: "unarchive", primary: true, danger: false });
        list.push({ id: "copy",     label: "Copy",   icon: "file_copy",       primary: false, danger: false });
        list.push({ id: "move",     label: "Move",   icon: "drive_file_move", primary: false, danger: false });
        list.push({ id: "gdrive",   label: "GDrive", icon: "cloud_upload",    primary: false, danger: false });
        list.push({ id: "openwith", label: "Open",   icon: "open_in_new",     primary: false, danger: false });
        list.push({ id: "delete",   label: "Delete", icon: "delete",          primary: false, danger: true });
        return list;
    }

    // ── VIEW A: SHELF-FIRST WORKSPACE (Drag-Drop / Pick / Select -> Actions) ──
    Column {
        anchors.fill: parent
        visible: NotchFilesStore.activeTool === ""
        spacing: 8

        // Top Shelf bar anchored Left/Right so GDrive & pills never clip
        Item {
            width: parent.width
            height: 28

            Rectangle {
                anchors.left: parent.left
                anchors.right: rightTopBtns.left
                anchors.rightMargin: 8
                height: 28
                radius: 9
                color: fl.theme.card
                border.width: 1
                border.color: fl.theme.border

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    spacing: 6

                    NotchIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: NotchFilesStore.selectedCount > 0 ? "check_circle" : "inventory_2"
                        font.pixelSize: 14
                        fill: NotchFilesStore.selectedCount > 0 ? 1 : 0
                        color: NotchFilesStore.selectedCount > 0 ? fl.theme.accent : fl.theme.muted
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 22
                        text: NotchFilesStore.selectedCount > 0
                            ? (NotchFilesStore.selectedCount === 1
                                ? NotchFilesStore.nameOf(NotchFilesStore.selectedPaths[0]) + " (" + NotchFilesStore.selectionCategory + ")"
                                : NotchFilesStore.selectedCount + I18n.tr(" selected (") + NotchFilesStore.selectionCategory + ")")
                            : (NotchFilesStore.shelfFiles.length > 0
                                ? NotchFilesStore.shelfFiles.length + I18n.tr(" on shelf · select to act")
                                : I18n.tr("Shelf"))
                        color: NotchFilesStore.selectedCount > 0 ? fl.theme.ink : fl.theme.muted
                        font.family: Tokens.ui
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }

            Row {
                id: rightTopBtns
                anchors.right: parent.right
                height: 28
                spacing: 5

                ActionPill {
                    visible: NotchFilesStore.shelfFiles.length > 0
                    width: 44
                    icon: ""
                    label: NotchFilesStore.selectedCount === NotchFilesStore.shelfFiles.length ? I18n.tr("None") : I18n.tr("All")
                    onClicked: {
                        if (NotchFilesStore.selectedCount === NotchFilesStore.shelfFiles.length) {
                            NotchFilesStore.selectedPaths = [];
                        } else {
                            var all = [];
                            for (var i = 0; i < NotchFilesStore.shelfFiles.length; i++)
                                all.push(NotchFilesStore.shelfFiles[i].path);
                            NotchFilesStore.selectedPaths = all;
                        }
                    }
                }

                ActionPill {
                    visible: NotchFilesStore.shelfFiles.length > 0
                    width: 48
                    icon: ""
                    label: I18n.tr("Clear")
                    onClicked: NotchFilesStore.clearShelf()
                }

                ActionPill {
                    width: 72
                    icon: "add"
                    label: I18n.tr("Browse")
                    onClicked: NotchFilesStore.pickNativeFile(false)
                }

                ActionPill {
                    width: 58
                    icon: "content_paste"
                    label: I18n.tr("Path")
                    onClicked: clipPathPaste.running = true
                }

                ActionPill {
                    width: 70
                    icon: NotchFilesStore.gdriveRemote !== "" ? "cloud_done" : "cloud"
                    label: I18n.tr("GDrive")
                    onClicked: NotchFilesStore.openTool("gdrive")
                }
            }
        }

        // Center Shelf DropZone + Populated Grid
        Item {
            width: parent.width
            height: Math.max(80, parent.height - (NotchFilesStore.selectedCount > 0 ? 72 : 36))

            DropArea {
                id: shelfDrop
                anchors.fill: parent
                onDropped: drop => {
                    if (drop.hasUrls) {
                        NotchFilesStore.addUrlsToShelf(drop.urls);
                        drop.acceptProposedAction();
                    }
                }
            }

            // Empty State: pure centered dropzone
            Rectangle {
                visible: NotchFilesStore.shelfFiles.length === 0
                anchors.fill: parent
                radius: 14
                color: shelfDrop.containsDrag
                    ? Qt.rgba(fl.theme.accent.r, fl.theme.accent.g, fl.theme.accent.b, 0.14)
                    : (emptyDropMa.containsMouse ? fl.theme.cardHover : fl.theme.card)
                border.width: shelfDrop.containsDrag ? 1.5 : 0
                border.color: fl.theme.accent

                Canvas {
                    anchors.fill: parent
                    visible: !shelfDrop.containsDrag
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = Qt.rgba(fl.theme.ink.r, fl.theme.ink.g, fl.theme.ink.b, 0.22);
                        ctx.lineWidth = 1.2;
                        ctx.setLineDash([6, 5]);
                        var r = 13, x = 2, y = 2, w = width - 4, h = height - 4;
                        ctx.beginPath();
                        ctx.moveTo(x + r, y);
                        ctx.lineTo(x + w - r, y);
                        ctx.quadraticCurveTo(x + w, y, x + w, y + r);
                        ctx.lineTo(x + w, y + h - r);
                        ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
                        ctx.lineTo(x + r, y + h);
                        ctx.quadraticCurveTo(x, y + h, x, y + h - r);
                        ctx.lineTo(x, y + r);
                        ctx.quadraticCurveTo(x, y, x + r, y);
                        ctx.stroke();
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    NotchIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "inbox"
                        font.pixelSize: 28
                        fill: 1
                        color: shelfDrop.containsDrag ? fl.theme.accent : fl.theme.ink
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.tr("Drop files here")
                        color: fl.theme.ink
                        font.family: fl.theme.uiFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.tr("Click anywhere to browse · select items for Compress, Convert, Move, GDrive & more")
                        color: fl.theme.muted
                        font.family: fl.theme.uiFont
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    id: emptyDropMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotchFilesStore.pickNativeFile(false)
                }
            }

            // Populated Shelf Grid
            Flickable {
                id: shelfFlick
                visible: NotchFilesStore.shelfFiles.length > 0
                anchors.fill: parent
                contentWidth: width
                contentHeight: shelfGrid.implicitHeight
                flickableDirection: Flickable.VerticalFlick
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var dy = (event.pixelDelta && Math.abs(event.pixelDelta.y) > 0)
                            ? -event.pixelDelta.y
                            : (-event.angleDelta.y * 0.4);
                        var step = Math.max(-54, Math.min(54, dy));
                        var maxY = Math.max(0, shelfFlick.contentHeight - shelfFlick.height);
                        shelfFlick.contentY = Math.max(0, Math.min(maxY, shelfFlick.contentY + step));
                        event.accepted = true;
                    }
                }

                Grid {
                    id: shelfGrid
                    width: parent.width
                    columns: 3
                    columnSpacing: 8
                    rowSpacing: 8

                    Repeater {
                        model: NotchFilesStore.shelfFiles
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool picked: NotchFilesStore.isSelected(modelData.path)
                            width: Math.floor((shelfGrid.width - 16) / 3)
                            height: 58
                            radius: 11
                            color: picked
                                ? Qt.rgba(fl.theme.accent.r, fl.theme.accent.g, fl.theme.accent.b, 0.18)
                                : (shMa.containsMouse ? fl.theme.cardHover : fl.theme.card)
                            border.width: 1
                            border.color: picked ? fl.theme.accent : fl.theme.border

                            Column {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 3

                                Row {
                                    width: parent.width
                                    spacing: 6
                                    Rectangle {
                                        width: 24; height: 24; radius: 7
                                        color: Qt.rgba(fl.theme.accent.r, fl.theme.accent.g, fl.theme.accent.b, 0.16)
                                        NotchIcon {
                                            anchors.centerIn: parent
                                            text: NotchFilesStore.iconForCategory(modelData.category)
                                            font.pixelSize: 14
                                            color: fl.theme.accent
                                        }
                                    }
                                    Column {
                                        width: parent.width - 48
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            width: parent.width
                                            text: modelData.name
                                            color: fl.theme.ink
                                            font.family: fl.theme.uiFont
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideMiddle
                                        }
                                        Text {
                                            text: (modelData.ext ? modelData.ext.toUpperCase() + " · " : "") + modelData.sizeText
                                            color: fl.theme.muted
                                            font.family: fl.theme.monoFont
                                            font.pixelSize: 9
                                        }
                                    }
                                    NotchIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "close"
                                        font.pixelSize: 13
                                        color: fl.theme.muted
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -3
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: NotchFilesStore.removeFromShelf(modelData.path)
                                        }
                                    }
                                }

                                Text {
                                    text: picked ? I18n.tr("Selected ✓") : I18n.tr("Click to select")
                                    color: picked ? fl.theme.accent : fl.theme.muted
                                    font.family: fl.theme.uiFont
                                    font.pixelSize: 9
                                }
                            }

                            MouseArea {
                                id: shMa
                                anchors.fill: parent
                                z: -1
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotchFilesStore.toggleSelectPath(modelData.path)
                            }
                        }
                    }
                }
            }
        }

        // Bottom Contextual Action Dock (equal-width responsive pills, zero clipping)
        Row {
            visible: NotchFilesStore.selectedCount > 0
            width: parent.width
            height: 28
            spacing: 5

            Repeater {
                model: fl.contextActions
                delegate: ActionPill {
                    required property var modelData
                    width: Math.floor((parent.width - Math.max(0, fl.contextActions.length - 1) * 5) / Math.max(1, fl.contextActions.length))
                    icon: modelData.icon
                    label: I18n.tr(modelData.label)
                    primary: modelData.primary
                    danger: modelData.danger
                    onClicked: NotchFilesStore.openTool(modelData.id)
                }
            }
        }
    }

    // ── VIEW B: SUB-MENU WITH < BACK HEADER ──────────────────────────────────
    Column {
        anchors.fill: parent
        visible: NotchFilesStore.activeTool !== ""
        spacing: 8

        // Sub-menu Header: [< Back] + [Tool Title] + [Selection Pill]
        Row {
            width: parent.width
            height: 28
            spacing: 8

            Rectangle {
                width: 68; height: 28; radius: 9
                color: backMa.containsMouse ? fl.theme.cardHover : fl.theme.card
                border.width: 1; border.color: fl.theme.border
                Row {
                    anchors.centerIn: parent
                    spacing: 2
                    NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "arrow_back"; font.pixelSize: 14; color: fl.theme.ink }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Shelf"); color: fl.theme.ink; font.family: Tokens.ui; font.pixelSize: 10; font.weight: Font.DemiBold }
                }
                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotchFilesStore.openTool("")
                }
            }

            NotchIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: fl.toolMeta(NotchFilesStore.activeTool).icon
                font.pixelSize: 16
                fill: 1
                color: NotchFilesStore.activeTool === "delete" ? fl.theme.danger : fl.theme.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr(fl.toolMeta(NotchFilesStore.activeTool).label)
                color: fl.theme.ink
                font.family: Tokens.ui
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Item { width: Math.max(4, parent.width - 340); height: 1 }

            Rectangle {
                height: 24
                width: Math.min(180, selChipTxt.implicitWidth + 16)
                radius: 8
                color: fl.theme.card
                border.width: 1; border.color: fl.theme.border
                Text {
                    id: selChipTxt
                    anchors.centerIn: parent
                    width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                    text: NotchFilesStore.selectedCount > 0
                        ? (NotchFilesStore.selectedCount === 1
                            ? NotchFilesStore.nameOf(NotchFilesStore.selectedPaths[0])
                            : NotchFilesStore.selectedCount + " selected")
                        : I18n.tr("0 selected")
                    color: NotchFilesStore.selectedCount > 0 ? fl.theme.ink : fl.theme.muted
                    font.family: theme.monoFont
                    font.pixelSize: 9
                    elide: Text.ElideMiddle
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotchFilesStore.pickNativeFile(false)
                }
            }
        }

        // ── 2. COMPRESS (Smart format-aware + Archive) ───────────────────────
        Column {
            width: parent.width
            height: parent.height - 56
            visible: NotchFilesStore.activeTool === "compress"
            spacing: 8

            Text {
                text: NotchFilesStore.selectedCount === 0
                    ? I18n.tr("Select files in Shelf first, or click the pill top-right to pick files.")
                    : I18n.tr("Detected type: ") + NotchFilesStore.selectionCategory.toUpperCase()
                color: fl.theme.muted
                font.family: Tokens.ui
                font.pixelSize: 10
            }

            // Format-specific Compression when images / PDF / video detected
            Rectangle {
                width: parent.width
                height: 62
                radius: 12
                visible: NotchFilesStore.selectionCategory === "image"
                    || NotchFilesStore.selectionCategory === "document"
                    || NotchFilesStore.selectionCategory === "video"
                color: fl.theme.card
                border.width: 1; border.color: fl.theme.border

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Column {
                        width: parent.width - 210
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: NotchFilesStore.selectionCategory === "image"
                                ? I18n.tr("Image Quality Compression (ImageMagick)")
                                : (NotchFilesStore.selectionCategory === "video"
                                    ? I18n.tr("Video Transcode Compression (H.264 CRF 28)")
                                    : I18n.tr("PDF / Document Size Reduction (150 dpi)"))
                            color: fl.theme.ink; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.DemiBold
                        }
                        Text {
                            text: NotchFilesStore.selectionCategory === "image"
                                ? I18n.tr("Strips EXIF & saves *_qN without overwriting originals")
                                : I18n.tr("Creates a smaller copy beside original file")
                            color: fl.theme.muted; font.family: Tokens.ui; font.pixelSize: 9
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        visible: NotchFilesStore.selectionCategory === "image"
                        Repeater {
                            model: [85, 70, 50]
                            delegate: ActionPill {
                                required property int modelData
                                label: modelData + "%"
                                primary: modelData === 70
                                enabledBtn: !NotchFilesStore.busy
                                onClicked: NotchFilesStore.runCompress("img_opt", modelData)
                            }
                        }
                    }

                    ActionPill {
                        visible: NotchFilesStore.selectionCategory === "video" || NotchFilesStore.selectionCategory === "document"
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "compress"
                        label: I18n.tr("Optimize Now")
                        primary: true
                        enabledBtn: !NotchFilesStore.busy
                        onClicked: NotchFilesStore.runCompress(NotchFilesStore.selectionCategory === "video" ? "video_opt" : "pdf_opt", 75)
                    }
                }
            }

            // Universal Archive Packaging
            Rectangle {
                width: parent.width
                height: 68
                radius: 12
                color: fl.theme.card
                border.width: 1; border.color: fl.theme.border
                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8
                    Column {
                        width: parent.width - 246
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text { text: I18n.tr("Package into Archive"); color: fl.theme.ink; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.DemiBold }
                        Text { text: I18n.tr("Works for any file, document, or folder"); color: fl.theme.muted; font.family: Tokens.ui; font.pixelSize: 9 }
                    }
                    ActionPill { anchors.verticalCenter: parent.verticalCenter; label: ".ZIP"; primary: true; enabledBtn: NotchFilesStore.selectedCount > 0 && !NotchFilesStore.busy; onClicked: NotchFilesStore.runCompress("zip", 0) }
                    ActionPill { anchors.verticalCenter: parent.verticalCenter; label: ".TAR.GZ"; enabledBtn: NotchFilesStore.selectedCount > 0 && !NotchFilesStore.busy; onClicked: NotchFilesStore.runCompress("tar.gz", 0) }
                    ActionPill { anchors.verticalCenter: parent.verticalCenter; label: ".7Z"; enabledBtn: NotchFilesStore.selectedCount > 0 && !NotchFilesStore.busy; onClicked: NotchFilesStore.runCompress("7z", 0) }
                }
            }
        }

        // ── 3. CONVERT ───────────────────────────────────────────────────────
        Column {
            width: parent.width
            height: parent.height - 56
            visible: NotchFilesStore.activeTool === "convert"
            spacing: 10

            Text {
                text: NotchFilesStore.selectedCount === 0
                    ? I18n.tr("Pick or select file(s) from Shelf to see matching target formats.")
                    : I18n.tr("Convert ") + NotchFilesStore.selectedCount + " " + NotchFilesStore.selectionCategory + I18n.tr(" item(s) into:")
                color: fl.theme.muted
                font.family: Tokens.ui
                font.pixelSize: 10
            }

            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: NotchFilesStore.selectionCategory === "image"
                        ? ["webp", "png", "jpg", "avif", "pdf"]
                        : (NotchFilesStore.selectionCategory === "video" || NotchFilesStore.selectionCategory === "audio"
                            ? ["mp4", "webm", "gif", "mp3", "wav", "flac"]
                            : (NotchFilesStore.selectionCategory === "document"
                                ? ["pdf", "docx", "html", "txt"]
                                : ["webp", "png", "jpg", "pdf", "mp4", "mp3"]))
                    delegate: ActionPill {
                        required property string modelData
                        icon: "transform"
                        label: "." + modelData.toUpperCase()
                        primary: modelData === "webp" || modelData === "pdf" || modelData === "mp4"
                        enabledBtn: NotchFilesStore.selectedCount > 0 && !NotchFilesStore.busy
                        onClicked: NotchFilesStore.runConvert(modelData)
                    }
                }
            }
        }

        // ── 4. EXTRACT ───────────────────────────────────────────────────────
        Column {
            width: parent.width
            height: parent.height - 56
            visible: NotchFilesStore.activeTool === "extract"
            spacing: 10

            Rectangle {
                width: parent.width
                height: 82
                radius: 12
                color: fl.theme.card
                border.width: 1; border.color: fl.theme.border
                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: "unarchive"; font.pixelSize: 28; color: fl.theme.accent }
                    Column {
                        width: parent.width - 170
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text { text: I18n.tr("Extract Archive"); color: fl.theme.ink; font.family: Tokens.ui; font.pixelSize: 12; font.weight: Font.DemiBold }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: NotchFilesStore.archiveSelected
                                ? I18n.tr("Ready to extract into a subfolder beside the selected archive(s).")
                                : I18n.tr("Select a .zip, .tar.gz, .tar.zst, .7z, .rar, or .iso file.")
                            color: fl.theme.muted; font.family: Tokens.ui; font.pixelSize: 10
                        }
                    }
                    ActionPill {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "unarchive"
                        label: I18n.tr("Extract")
                        primary: true
                        enabledBtn: NotchFilesStore.archiveSelected && !NotchFilesStore.busy
                        onClicked: NotchFilesStore.runExtract()
                    }
                }
            }
        }

        // ── 5 & 6. COPY TO / MOVE TO ─────────────────────────────────────────
        Column {
            width: parent.width
            height: parent.height - 56
            visible: NotchFilesStore.activeTool === "copy" || NotchFilesStore.activeTool === "move"
            spacing: 8

            Text { text: I18n.tr("Quick Destination Folder"); color: fl.theme.muted; font.family: Tokens.ui; font.pixelSize: 10 }

            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: [
                        { label: "Downloads", path: (Quickshell.env("HOME") || "") + "/Downloads" },
                        { label: "Documents", path: (Quickshell.env("HOME") || "") + "/Documents" },
                        { label: "Pictures",  path: (Quickshell.env("HOME") || "") + "/Pictures" },
                        { label: "Desktop",   path: (Quickshell.env("HOME") || "") + "/Desktop" },
                        { label: "/tmp",      path: "/tmp" }
                    ]
                    delegate: ActionPill {
                        required property var modelData
                        icon: "folder"
                        label: modelData.label
                        primary: fl.customDest === modelData.path
                        onClicked: fl.customDest = modelData.path
                    }
                }
            }

            Row {
                width: parent.width
                height: 30
                spacing: 6
                Rectangle {
                    width: parent.width - 196
                    height: 30
                    radius: 9
                    color: fl.theme.card
                    border.width: 1; border.color: destInp.activeFocus ? fl.theme.accent : fl.theme.border
                    TextInput {
                        id: destInp
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        text: fl.customDest
                        color: fl.theme.ink
                        font.family: fl.theme.monoFont
                        font.pixelSize: 10
                        onTextChanged: fl.customDest = text
                    }
                }
                ActionPill {
                    icon: "folder_open"
                    label: I18n.tr("Browse")
                    onClicked: NotchFilesStore.pickNativeFile(true)
                }
                ActionPill {
                    icon: NotchFilesStore.activeTool === "move" ? "drive_file_move" : "file_copy"
                    label: NotchFilesStore.activeTool === "move" ? I18n.tr("Move Here") : I18n.tr("Copy Here")
                    primary: true
                    enabledBtn: NotchFilesStore.selectedCount > 0 && !NotchFilesStore.busy
                    onClicked: NotchFilesStore.runTransfer(fl.customDest, NotchFilesStore.activeTool === "move")
                }
            }
        }

        // ── 7. GOOGLE DRIVE (rclone) ─────────────────────────────────────────
        Column {
            width: parent.width
            height: parent.height - 56
            visible: NotchFilesStore.activeTool === "gdrive"
            spacing: 8

            // Disconnected / Not Installed / Auth Card
            Rectangle {
                visible: NotchFilesStore.gdriveRemote === ""
                width: parent.width
                height: 112
                radius: 12
                color: fl.theme.card
                border.width: 1; border.color: fl.theme.border

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 28
                    spacing: 6
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        NotchIcon { text: "cloud_off"; font.pixelSize: 20; color: fl.theme.warning }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: NotchFilesStore.rcloneInstalled
                                ? I18n.tr("Google Drive Not Signed In")
                                : I18n.tr("rclone Not Installed")
                            color: fl.theme.ink; font.family: Tokens.ui; font.pixelSize: 12; font.weight: Font.DemiBold
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: NotchFilesStore.rcloneInstalled
                            ? I18n.tr("Click Connect below to authenticate once in your browser via rclone OAuth.")
                            : I18n.tr("Install rclone (included in Tsukuyomi base packages) to enable Google Drive sync.")
                        color: fl.theme.muted; font.family: Tokens.ui; font.pixelSize: 10
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        ActionPill {
                            visible: NotchFilesStore.rcloneInstalled
                            icon: "login"
                            label: I18n.tr("Connect Google Drive")
                            primary: true
                            onClicked: NotchFilesStore.connectGdrive()
                        }
                        ActionPill {
                            icon: "refresh"
                            label: I18n.tr("Refresh")
                            onClicked: NotchFilesStore.checkRclone()
                        }
                    }
                }
            }

            // Connected Drive Controls + Browser
            Column {
                visible: NotchFilesStore.gdriveRemote !== ""
                width: parent.width
                height: parent.height
                spacing: 6

                Row {
                    width: parent.width
                    height: 28
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: NotchFilesStore.gdriveRemote + (NotchFilesStore.gdriveSubdir || "/")
                        color: fl.theme.ink; font.family: theme.monoFont; font.pixelSize: 10
                        width: parent.width - 178
                        elide: Text.ElideRight
                    }
                    ActionPill {
                        icon: "cloud_upload"
                        label: I18n.tr("Upload")
                        primary: true
                        enabledBtn: NotchFilesStore.selectedCount > 0 && !NotchFilesStore.busy
                        onClicked: NotchFilesStore.uploadToGdrive()
                    }
                    ActionPill {
                        icon: "refresh"
                        label: I18n.tr("Sync")
                        onClicked: NotchFilesStore.listGdrive()
                    }
                }

                ListView {
                    width: parent.width
                    height: parent.height - 34
                    clip: true
                    spacing: 3
                    model: NotchFilesStore.gdriveEntries
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 24
                        radius: 7
                        color: gdMa.containsMouse ? fl.theme.cardHover : fl.theme.card
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 6
                            NotchIcon { anchors.verticalCenter: parent.verticalCenter; text: modelData.isDir ? "folder" : "cloud_done"; font.pixelSize: 13; color: modelData.isDir ? fl.theme.warning : fl.theme.accent }
                            Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120; text: modelData.name; color: fl.theme.ink; font.family: Tokens.ui; font.pixelSize: 10; elide: Text.ElideRight }
                            Text { anchors.verticalCenter: parent.verticalCenter; width: 54; horizontalAlignment: Text.AlignRight; text: modelData.sizeText; color: fl.theme.muted; font.family: theme.monoFont; font.pixelSize: 9 }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.isDir ? "Open" : "Download"; color: fl.theme.accent; font.family: Tokens.ui; font.pixelSize: 9; font.weight: Font.DemiBold }
                        }
                        MouseArea {
                            id: gdMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.isDir) NotchFilesStore.listGdrive(modelData.path);
                                else NotchFilesStore.downloadFromGdrive(modelData);
                            }
                        }
                    }
                }
            }
        }

        // ── 8. OPEN WITH ─────────────────────────────────────────────────────
        Flow {
            width: parent.width
            height: parent.height - 56
            visible: NotchFilesStore.activeTool === "openwith"
            spacing: 8
            Repeater {
                model: [
                    { label: "System Default", cmd: "xdg-open",    icon: "open_in_new" },
                    { label: "Dolphin",        cmd: "dolphin",     icon: "folder_open" },
                    { label: "Terminal",       cmd: "terminal",    icon: "terminal" },
                    { label: "LibreOffice",    cmd: "libreoffice", icon: "description" },
                    { label: "MPV Player",     cmd: "mpv",         icon: "smart_display" },
                    { label: "Firefox",        cmd: "firefox",     icon: "public" }
                ]
                delegate: ActionPill {
                    required property var modelData
                    icon: modelData.icon
                    label: I18n.tr(modelData.label)
                    enabledBtn: NotchFilesStore.selectedCount > 0
                    onClicked: NotchFilesStore.runOpenWith(modelData.cmd)
                }
            }
        }

        // ── 9. DELETE ────────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: parent.height - 56
            visible: NotchFilesStore.activeTool === "delete"
            radius: 12
            color: fl.theme.card
            border.width: 1
            border.color: Qt.rgba(fl.theme.danger.r, fl.theme.danger.g, fl.theme.danger.b, 0.40)

            Column {
                anchors.centerIn: parent
                width: parent.width - 28
                spacing: 8

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    NotchIcon { text: "warning"; font.pixelSize: 20; color: fl.theme.danger }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: NotchFilesStore.selectedCount > 0
                            ? I18n.tr("Remove ") + NotchFilesStore.selectedCount + I18n.tr(" selected item(s)?")
                            : I18n.tr("No item selected to delete")
                        color: fl.theme.ink; font.family: Tokens.ui; font.pixelSize: 12; font.weight: Font.DemiBold
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    ActionPill {
                        icon: "delete"
                        label: I18n.tr("Move to Trash")
                        primary: true
                        enabledBtn: NotchFilesStore.selectedCount > 0 && !NotchFilesStore.busy
                        onClicked: NotchFilesStore.runDelete(false)
                    }
                    ActionPill {
                        icon: "delete_forever"
                        label: I18n.tr("Permanent Delete")
                        danger: true
                        enabledBtn: NotchFilesStore.selectedCount > 0 && !NotchFilesStore.busy
                        onClicked: NotchFilesStore.runDelete(true)
                    }
                }
            }
        }

        // Sub-view Status Feedback Toast (only shown when active)
        Text {
            visible: NotchFilesStore.statusMsg !== ""
            width: parent.width
            height: visible ? 14 : 0
            text: NotchFilesStore.statusMsg
            color: NotchFilesStore.statusError ? fl.theme.danger : fl.theme.ink
            font.family: fl.theme.uiFont
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }
}
