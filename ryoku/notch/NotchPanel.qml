import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import shell.services
import Ryoku.Ui.Singletons
import "NotchRegistry.js" as Registry

// Expanded Tsukuyomi Dynamic Notch (replaces DashboardPopup in VariantRoot) +
// sibling Hub-styled NotchSettingsWindow popup.
// Morphs from the bar's clock island and mounts one dashboard page at a time.
Item {
    id: notchHost

    required property var root
    width: 0
    height: 0

    function openSettingsPopup(sec) {
        if (notchHost.root && notchHost.root.dashboardVisible)
            notchHost.root.dashboardVisible = false;
        settingsPopup.openWindow(sec || "appearance");
    }

    NotchSettingsWindow {
        id: settingsPopup
        root: notchHost.root
    }

    PanelWindow {
        id: panel

        readonly property var root: notchHost.root
        screen: panel.root ? panel.root.activePopupScreen : null

        // This transition only animates geometry and opacity on software renderers.
        readonly property bool anim: !Perf.userReduceMotion
        readonly property bool isOpen: panel.root ? panel.root.dashboardVisible : false

        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ryoku-dashboard"

        readonly property real pageVisibility: {
            const t = Math.max(0, Math.min(1, (reveal - 0.24) / 0.65));
            return t * t * (3 - 2 * t);
        }
        property real reveal: panel.isOpen ? 1.0 : 0.0
        Behavior on reveal {
            enabled: panel.anim
            NumberAnimation {
                duration: panel.isOpen ? 340 : 235
                easing.type: panel.isOpen ? Easing.OutCubic : Easing.InOutCubic
            }
        }
        visible: reveal > 0.002
        WlrLayershell.keyboardFocus: panel.isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        mask: !panel.isOpen ? noInput : (NotchConfig.autoCollapse ? null : cardInput)
        Region { id: noInput }
        Region { id: cardInput; item: card }

        Binding {
            target: panel.root
            property: "notchReveal"
            value: panel.reveal
            when: !!panel.root
        }
        function openSettingsPopup(sec) {
            notchHost.openSettingsPopup(sec);
        }

        NotchTheme { id: nt; root: panel.root }

    readonly property var tabs: Registry.visibleTabs(NotchConfig.hiddenTabs, NotchConfig.tabOrder)
    property string activeTabId: "home"
    property bool settingsOpen: false
    property bool switcherOpen: false
    property string _ipcPendingTab: ""
    property bool _ipcPendingSettings: false

    readonly property var activeMeta: panel.settingsOpen
        ? Registry.SETTINGS_META
        : Registry.findTab(panel.activeTabId)

    readonly property int barTopY: panel.root && panel.root.barGapLead !== undefined ? panel.root.barGapLead : 8
    readonly property int barH: panel.root && panel.root.v2BarHeight ? panel.root.v2BarHeight : 33
    readonly property real barR: panel.root && panel.root.barCornerRadius !== undefined ? panel.root.barCornerRadius : 17
    readonly property bool bottomBar: panel.root && panel.root.barPosition === "bottom"
    readonly property int maxW: Math.max(1, panel.width - 32)
    readonly property int maxH: Math.max(1, panel.height - panel.barTopY - 24)

    readonly property bool tpActive: !panel.settingsOpen && panel.activeTabId === "teleprompter"
    readonly property bool tpDistractionFree: panel.tpActive && NotchTeleprompterStore.focusMode
    readonly property real scaleFactor: panel.tpActive ? (NotchTeleprompterStore.scalePct / 100.0) : 1.0
    readonly property int quickBarExtra: (panel.switcherOpen && !panel.settingsOpen && !panel.tpDistractionFree) ? 42 : 0
    readonly property int homeExtraH: (!panel.settingsOpen && panel.activeTabId === "home" && (NotchConfig.homeTiles || []).length > 4) ? 56 : 0

    readonly property real targetW: Math.min(panel.maxW, Math.round(Number(panel.activeMeta.w || 468) * panel.scaleFactor))
    readonly property real targetH: Math.min(panel.maxH, Math.round((Number(panel.activeMeta.h || 214) + panel.homeExtraH) * panel.scaleFactor) + panel.quickBarExtra)

    function stepTab(delta) {
        if (panel.settingsOpen || panel.tpDistractionFree || panel.tabs.length < 2) return;
        const current = contentSlot.pendingTab || panel.activeTabId;
        panel.selectTab(Registry.nextTabId(panel.tabs, current, delta), delta);
    }

    function selectTab(id, direction) {
        const nextIdx = Registry.indexOfTab(panel.tabs, id);
        if (nextIdx < 0) return;
        const curIdx = Registry.indexOfTab(panel.tabs, contentSlot.pendingTab || panel.activeTabId);
        const sign = direction ? Math.sign(direction) : (nextIdx >= curIdx ? 1 : -1);
        panel.settingsOpen = false;
        panel.switcherOpen = false;
        contentSlot.switchTo(id, sign);
    }

    function commitTab(id) {
        panel.activeTabId = id;
        NotchConfig.lastTab = id;
    }

    onIsOpenChanged: {
        if (panel.isOpen) {
            panel.switcherOpen = false;
            if (panel._ipcPendingSettings) {
                panel._ipcPendingSettings = false;
                panel.settingsOpen = true;
            } else {
                panel.settingsOpen = false;
                var preferred = panel._ipcPendingTab !== ""
                    ? panel._ipcPendingTab
                    : (NotchConfig.defaultTab === "last" ? NotchConfig.lastTab : "home");
                panel._ipcPendingTab = "";
                if (Registry.indexOfTab(panel.tabs, preferred) < 0) preferred = "home";
                panel.activeTabId = preferred;
            }
            card.forceActiveFocus();
        } else {
            contentSlot.resetSwitch();
        }
    }

    IpcHandler {
        target: "notch"
        function open(tabId: string): void {
            var targetId = tabId && tabId !== "" ? tabId : "home";
            if (!panel.isOpen) {
                panel._ipcPendingTab = targetId;
                panel._ipcPendingSettings = false;
                if (panel.root) panel.root.openDashboard();
            } else {
                panel.selectTab(targetId);
            }
        }
        function openFilesTool(toolId: string): void {
            NotchFilesStore.openTool(toolId || "");
            open("files");
        }
        function openSettings(): void {
            panel.openSettingsPopup("appearance");
        }
        function close(): void {
            if (panel.root) panel.root.dashboardVisible = false;
        }
    }

    onTabsChanged: {
        if (Registry.indexOfTab(panel.tabs, panel.activeTabId) < 0) {
            contentSlot.resetSwitch();
            panel.activeTabId = panel.tabs.length > 0 ? panel.tabs[0].id : "home";
        }
    }

    SystemClock { id: sysClock; precision: SystemClock.Minutes }
    readonly property string headerClock: {
        var d = sysClock.date;
        var day = Config.formatLoc.standaloneDayName(d.getDay(), 1);
        var mon = Config.formatLoc.standaloneMonthName(d.getMonth(), 1);
        var datePart = day + " " + d.getDate() + " " + mon;
        var m = String(d.getMinutes()).padStart(2, "0");
        var timePart = TimeFormat.is24h
            ? String(d.getHours()).padStart(2, "0") + ":" + m
            : ((d.getHours() % 12 || 12) + ":" + m + (d.getHours() >= 12 ? " PM" : " AM"));
        return datePart + "  ·  " + timePart;
    }

    // Outside-click dismiss
    MouseArea {
        anchors.fill: parent
        enabled: panel.isOpen && NotchConfig.autoCollapse
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: if (panel.root) panel.root.dashboardVisible = false
    }

    // The silhouette, the bar hand-off, and the content share one timeline.
    Rectangle {
        id: card

        readonly property real idleW: panel.root && panel.root.notchAnchorWidth > 0 ? panel.root.notchAnchorWidth : 124
        readonly property real idleX: panel.root && panel.root.dashboardBarX > 0 ? panel.root.dashboardBarX : parent.width / 2
        readonly property real widePhase: panel.reveal + 0.075 * Math.sin(Math.PI * panel.reveal)
        property real pageWidth: panel.targetW
        property real pageHeight: panel.targetH
        Behavior on pageWidth {
            enabled: panel.anim && panel.reveal > 0.75
            NumberAnimation { duration: 245; easing.type: Easing.OutQuart }
        }
        Behavior on pageHeight {
            enabled: panel.anim && panel.reveal > 0.75
            NumberAnimation { duration: 245; easing.type: Easing.OutQuart }
        }
        width: Math.round(Math.min(panel.maxW, idleW + (pageWidth - idleW) * widePhase))
        height: Math.round(panel.barH + (pageHeight - panel.barH) * panel.reveal * panel.reveal)
        x: Math.round(Math.max(16, Math.min(parent.width - width - 16, idleX - width / 2)))
        y: panel.bottomBar ? parent.height - panel.barTopY - height : panel.barTopY

        radius: Math.round(panel.barR + (Math.max(14, Math.min(26, NotchConfig.cornerRadius)) - panel.barR) * panel.reveal)
        color: Perf.softwareRenderer || Perf.blurDisabled ? nt.solidSurface : nt.surface
        border.width: 1
        border.color: nt.border
        opacity: Math.min(1, panel.reveal * 5)
        clip: true
        focus: panel.isOpen

        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) {
                if (panel.switcherOpen) panel.switcherOpen = false;
                else if (panel.settingsOpen) panel.settingsOpen = false;
                else if (panel.root) panel.root.dashboardVisible = false;
                e.accepted = true;
            } else if (e.key === Qt.Key_Left && !panel.settingsOpen) {
                panel.stepTab(-1);
                e.accepted = true;
            } else if (e.key === Qt.Key_Right && !panel.settingsOpen) {
                panel.stepTab(1);
                e.accepted = true;
            }
        }

        // Swallow inner clicks so outside MouseArea doesn't dismiss
        MouseArea { anchors.fill: parent; onClicked: {} }

        // ── Expanded Header: [Icon + Title]  [Date · Clock]  [Settings] ──────
        Item {
            id: headerBar
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 10; leftMargin: 14; rightMargin: 14 }
            height: 28
            opacity: panel.pageVisibility
            enabled: panel.isOpen && panel.pageVisibility > 0.5
            transform: Translate { y: panel.anim ? (panel.bottomBar ? 8 : -8) * (1 - panel.pageVisibility) : 0 }

            MouseArea {
                id: slideDrag
                anchors { top: parent.top; bottom: parent.bottom; left: titleBtn.right; right: gearBtn.left }
                enabled: panel.isOpen && !panel.settingsOpen && !panel.tpDistractionFree
                    && !panel.switcherOpen && panel.tabs.length > 1
                property real startX: 0
                onPressed: mouse => { startX = mouse.x; }
                onPositionChanged: mouse => {
                    if (pressed && panel.anim && !contentSlot.pendingTab)
                        contentSlot.followDrag(mouse.x - startX);
                }
                onReleased: mouse => {
                    const distance = mouse.x - startX;
                    if (Math.abs(distance) >= 46)
                        panel.stepTab(distance < 0 ? 1 : -1);
                    else
                        contentSlot.settle();
                }
                onCanceled: contentSlot.settle()

                WheelHandler {
                    target: null
                    orientation: Qt.Horizontal
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    property real travel: 0
                    property bool committed: false
                    onActiveChanged: if (!active) { travel = 0; committed = false; }
                    onWheel: event => {
                        if (committed) return;
                        travel += event.pixelDelta.x || event.angleDelta.x;
                        if (Math.abs(travel) >= 52) {
                            committed = true;
                            panel.stepTab(travel < 0 ? 1 : -1);
                        }
                    }
                }
            }

            // Left: Back (in Settings) or Menu Icon + Menu Name (hidden in Teleprompter distraction-free mode)
            Rectangle {
                id: titleBtn
                visible: !panel.tpDistractionFree
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: titleRow.implicitWidth + 14
                height: 26
                radius: 9
                color: titleMa.containsMouse || panel.switcherOpen ? nt.cardHover : "transparent"
                Behavior on color { enabled: panel.anim; ColorAnimation { duration: 130 } }

                Row {
                    id: titleRow
                    anchors.centerIn: parent
                    spacing: 6

                    NotchIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.settingsOpen ? "arrow_back" : String(panel.activeMeta.icon || "home")
                        font.pixelSize: 15
                        fill: 1
                        color: nt.ink
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr(String(panel.activeMeta.label || "Home"))
                        color: nt.ink
                        font.family: Tokens.ui
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    NotchIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !panel.settingsOpen
                        text: panel.switcherOpen ? "expand_less" : "expand_more"
                        font.pixelSize: 14
                        color: nt.muted
                    }
                }

                MouseArea {
                    id: titleMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (panel.settingsOpen) panel.settingsOpen = false;
                        else panel.switcherOpen = !panel.switcherOpen;
                    }
                }
            }

            // Center: Clean Date & Clock (no RAM ring, no visualizer)
            Text {
                anchors.centerIn: parent
                text: panel.headerClock
                color: nt.muted
                font.family: nt.monoFont
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            // Right: Settings Gear
            Rectangle {
                id: gearBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 26; radius: 9
                color: panel.settingsOpen
                    ? Qt.rgba(nt.accent.r, nt.accent.g, nt.accent.b, 0.22)
                    : (gearMa.containsMouse ? nt.cardHover : "transparent")
                Behavior on color { enabled: panel.anim; ColorAnimation { duration: 130 } }

                NotchIcon {
                    anchors.centerIn: parent
                    text: "settings"
                    font.pixelSize: 16
                    fill: panel.settingsOpen ? 1 : 0
                    color: panel.settingsOpen ? nt.accent : nt.muted
                    rotation: panel.settingsOpen ? 45 : (gearMa.containsMouse ? 25 : 0)
                    Behavior on rotation { enabled: panel.anim; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: gearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        panel.switcherOpen = false;
                        panel.openSettingsPopup("appearance");
                    }
                }
            }
        }

        // Quick-Jump Tab Accordion Bar (opaque elevated tray pushing content smoothly down)
        Rectangle {
            id: quickBar
            anchors { top: headerBar.bottom; left: parent.left; right: parent.right; topMargin: 6; leftMargin: 14; rightMargin: 14 }
            height: panel.switcherOpen && !panel.settingsOpen && !panel.tpDistractionFree ? 34 : 0
            opacity: panel.switcherOpen && !panel.settingsOpen && !panel.tpDistractionFree ? 1 : 0
            visible: height > 1
            radius: 10
            color: nt.solidSurface
            border.width: 1
            border.color: nt.border
            clip: true
            z: 20

            Behavior on height { enabled: panel.anim; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { enabled: panel.anim; NumberAnimation { duration: 140 } }

            Flickable {
                id: qpFlick
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                contentWidth: qpRowWrap.implicitWidth
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    orientation: Qt.Vertical
                    onWheel: event => {
                        var delta = event.pixelDelta.y || event.angleDelta.y * 0.6;
                        var maxX = Math.max(0, qpFlick.contentWidth - qpFlick.width);
                        qpFlick.contentX = Math.max(0, Math.min(maxX, qpFlick.contentX - delta));
                        event.accepted = true;
                    }
                }

                Row {
                    id: qpRowWrap
                    x: Math.max(0, (qpFlick.width - implicitWidth) / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        model: panel.tabs
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool on: modelData.id === panel.activeTabId
                            width: qpRow.implicitWidth + 14
                            height: 26
                            radius: 8
                            color: on ? Qt.rgba(nt.accent.r, nt.accent.g, nt.accent.b, 0.28)
                                : (qpMa.containsMouse ? nt.cardHover : Qt.rgba(nt.ink.r, nt.ink.g, nt.ink.b, 0.04))
                            border.width: on ? 1 : 0
                            border.color: Qt.rgba(nt.accent.r, nt.accent.g, nt.accent.b, 0.55)
                            Row {
                                id: qpRow
                                anchors.centerIn: parent
                                spacing: 4
                                NotchIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    font.pixelSize: 13
                                    fill: on ? 1 : 0
                                    color: on ? nt.accent : nt.ink
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: I18n.tr(modelData.label)
                                    color: nt.ink
                                    font.family: Tokens.ui
                                    font.pixelSize: 10
                                    font.weight: on ? Font.DemiBold : Font.Normal
                                }
                            }
                            MouseArea {
                                id: qpMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panel.selectTab(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // ── Body Area + Side < > Chevrons ────────────────────────────────────
        Item {
            id: bodyHost
            anchors {
                top: headerBar.bottom
                topMargin: 8 + quickBar.height * (40 / 34)
                bottom: dotsRow.top
                bottomMargin: 6
                left: parent.left
                right: parent.right
            }
            opacity: panel.pageVisibility
            enabled: panel.isOpen && panel.pageVisibility > 0.5
            transform: Translate { y: panel.anim ? (panel.bottomBar ? 1 : -1) * (1 - panel.pageVisibility) * 12 : 0 }

            // Left < arrow
            Rectangle {
                id: prevBtn
                visible: !panel.settingsOpen && !panel.tpDistractionFree && panel.tabs.length > 1
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24; radius: 12
                color: prevMa.containsMouse ? nt.cardHover : nt.card
                border.width: 1; border.color: nt.border
                scale: prevMa.pressed ? 0.88 : 1.0
                Behavior on scale { enabled: panel.anim; NumberAnimation { duration: 100 } }
                NotchIcon { anchors.centerIn: parent; text: "chevron_left"; font.pixelSize: 16; color: nt.ink }
                MouseArea {
                    id: prevMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.stepTab(-1)
                }
            }

            // Right > arrow
            Rectangle {
                id: nextBtn
                visible: !panel.settingsOpen && !panel.tpDistractionFree && panel.tabs.length > 1
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24; radius: 12
                color: nextMa.containsMouse ? nt.cardHover : nt.card
                border.width: 1; border.color: nt.border
                scale: nextMa.pressed ? 0.88 : 1.0
                Behavior on scale { enabled: panel.anim; NumberAnimation { duration: 100 } }
                NotchIcon { anchors.centerIn: parent; text: "chevron_right"; font.pixelSize: 16; color: nt.ink }
                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.stepTab(1)
                }
            }

            // Finish the outgoing page before the loader replaces it.
            Item {
                id: contentSlot
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: prevBtn.visible ? prevBtn.right : parent.left
                    right: nextBtn.visible ? nextBtn.left : parent.right
                    leftMargin: prevBtn.visible ? 8 : 16
                    rightMargin: nextBtn.visible ? 8 : 16
                }
                clip: true

                property real slideOffset: 0
                property real pageOpacity: 1
                property string pendingTab: ""
                property int direction: 1
                property real exitOffset: 0
                readonly property real travel: Math.max(30, Math.min(56, width * 0.13))

                function resetSwitch() {
                    exitPage.stop();
                    enterPage.stop();
                    pendingTab = "";
                    slideOffset = 0;
                    pageOpacity = 1;
                }

                function settle() {
                    if (pendingTab || !panel.isOpen) return;
                    if (panel.anim && (slideOffset !== 0 || pageOpacity !== 1))
                        enterPage.restart();
                }

                function followDrag(offset) {
                    enterPage.stop();
                    slideOffset = Math.max(-travel, Math.min(travel, offset * 0.55));
                }

                function switchTo(tab, sign) {
                    if (!panel.anim || !contentLoader.item || panel.reveal < 0.85) {
                        resetSwitch();
                        panel.commitTab(tab);
                        return;
                    }
                    if (exitPage.running) {
                        pendingTab = tab;
                        direction = sign;
                        return;
                    }
                    if (tab === panel.activeTabId) {
                        settle();
                        return;
                    }
                    enterPage.stop();
                    pendingTab = tab;
                    direction = sign;
                    exitOffset = -sign * travel;
                    exitPage.start();
                }

                Connections {
                    target: panel
                    function onAnimChanged() {
                        if (!panel.anim) {
                            const tab = contentSlot.pendingTab;
                            contentSlot.resetSwitch();
                            if (tab) panel.commitTab(tab);
                        }
                    }
                }

                ParallelAnimation {
                    id: exitPage
                    NumberAnimation { target: contentSlot; property: "slideOffset"; to: contentSlot.exitOffset; duration: 85; easing.type: Easing.InQuad }
                    NumberAnimation { target: contentSlot; property: "pageOpacity"; to: 0; duration: 85; easing.type: Easing.InQuad }
                    onFinished: {
                        const tab = contentSlot.pendingTab;
                        contentSlot.pendingTab = "";
                        if (tab !== panel.activeTabId && Registry.indexOfTab(panel.tabs, tab) >= 0) {
                            contentSlot.slideOffset = contentSlot.direction * contentSlot.travel;
                            panel.commitTab(tab);
                        }
                        enterPage.start();
                    }
                }
                ParallelAnimation {
                    id: enterPage
                    NumberAnimation { target: contentSlot; property: "slideOffset"; to: 0; duration: 190; easing.type: Easing.OutQuart }
                    NumberAnimation { target: contentSlot; property: "pageOpacity"; to: 1; duration: 155; easing.type: Easing.OutCubic }
                }

                Loader {
                    id: contentLoader
                    width: parent.width
                    height: parent.height
                    x: contentSlot.slideOffset
                    opacity: contentSlot.pageOpacity
                    enabled: !exitPage.running
                    active: panel.reveal > 0.01
                    source: active ? Qt.resolvedUrl(String(panel.activeMeta.file || "NotchHomeTab.qml")) : ""

                    onLoaded: {
                        if (item) {
                            item.root = panel.root;
                            item.theme = nt;
                        }
                    }
                }

                Connections {
                    target: contentLoader.item
                    ignoreUnknownSignals: true
                    function onOpenSettingsRequested() {
                        panel.openSettingsPopup(panel.activeTabId === "notif" ? "behavior" : "media");
                    }
                }
            }
        }

        // ── Bottom Pagination Dots ───────────────────────────────────────────
        Row {
            id: dotsRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            height: !panel.settingsOpen && !panel.tpDistractionFree && panel.tabs.length > 1 ? 8 : 0
            visible: height > 0
            spacing: 6
            opacity: panel.pageVisibility
            enabled: panel.isOpen && panel.pageVisibility > 0.5

            Repeater {
                model: panel.tabs
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool activeDot: modelData.id === panel.activeTabId
                    width: activeDot ? 16 : 6
                    height: 5
                    radius: 2.5
                    color: activeDot ? nt.ink : Qt.rgba(nt.ink.r, nt.ink.g, nt.ink.b, 0.25)
                    Behavior on width { enabled: panel.anim; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { enabled: panel.anim; ColorAnimation { duration: 150 } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.selectTab(modelData.id)
                    }
                }
            }
        }
    }
    }
}
