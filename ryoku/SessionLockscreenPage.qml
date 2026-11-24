pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."

Item {
    id: page

    property var hub
    readonly property bool fullBleed: true
    readonly property string defaultSlug: "clockwork/orbital"
    readonly property var stockTheme: ({
        slug: defaultSlug,
        name: I18n.tr("Clockwork Orbital"),
        preview: Qt.resolvedUrl("clockwork-orbital-preview.webp")
    })
    property var themes: [stockTheme]
    property string activeSlug: defaultSlug
    property string pendingSlug: ""
    property string errorMessage: ""

    Process {
        id: listThemes
        command: ["ryoku-hub", "lock", "list"]
        running: true
        stdout: StdioCollector { id: themesOutput }
        onExited: code => {
            try {
                if (code !== 0)
                    throw new Error();
                const result = JSON.parse(themesOutput.text);
                if (result.error)
                    throw new Error();
                const installed = (result.skins || []).filter(theme => theme.slug !== page.defaultSlug);
                page.themes = [page.stockTheme].concat(installed);
                page.activeSlug = page.themes.some(theme => theme.slug === result.active)
                    ? result.active : page.defaultSlug;
            } catch (error) {
                page.errorMessage = I18n.tr("Could not load lockscreen themes. Refresh to try again.");
            }
        }
    }

    Process {
        id: applyTheme
        stderr: StdioCollector { id: applyError }
        onExited: code => {
            if (code === 0)
                page.activeSlug = page.pendingSlug;
            else
                page.errorMessage = applyError.text.trim() || I18n.tr("Could not apply the lockscreen theme.");
            page.pendingSlug = "";
        }
    }

    SchemaPage {
        id: settings

        anchors.fill: parent
        anchors.margins: Tokens.s6
        schema: []
        draft: null
        defaults: ({})
        title: I18n.tr("Lockscreen")
        eyebrow: I18n.tr("DESKTOP")
        blurb: I18n.tr("Choose the theme shown when you lock your session.")

        Column {
            width: parent.width
            spacing: Tokens.s4

            Flow {
                width: parent.width
                spacing: Tokens.s3
                Btn {
                    text: I18n.tr("Browse Tsukuyomi Store")
                    onAct: Quickshell.execDetached(["ryostore", "open", "lockscreens"])
                }
                Btn {
                    text: I18n.tr("Refresh installed themes")
                    enabled: !listThemes.running && !applyTheme.running
                    onAct: {
                        page.errorMessage = "";
                        listThemes.running = true;
                    }
                }
            }

            Text {
                width: parent.width
                visible: page.errorMessage !== ""
                text: page.errorMessage
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: Tokens.fBody
                wrapMode: Text.WordWrap
            }

            Grid {
                id: gallery

                width: parent.width
                columns: width >= 640 && page.themes.length > 1 ? 2 : 1
                spacing: Tokens.s4

                Repeater {
                    model: page.themes
                    delegate: SettingCard {
                        id: card

                        required property var modelData
                        readonly property bool bundled: modelData.slug === page.defaultSlug
                        readonly property bool activeTheme: modelData.slug === page.activeSlug

                        width: Math.floor((gallery.width - (gallery.columns - 1) * gallery.spacing) / gallery.columns)
                        title: modelData.name || modelData.slug
                        collapsible: false

                        Column {
                            x: Tokens.s4
                            width: parent.width - 2 * x
                            topPadding: Tokens.s3
                            bottomPadding: Tokens.s4
                            spacing: Tokens.s3

                            Rectangle {
                                id: preview

                                readonly property bool nearViewport: {
                                    const view = settings.viewport;
                                    if (!view || !view.contentItem)
                                        return true;
                                    const scrollY = view.contentY;
                                    const top = mapToItem(view.contentItem, 0, 0).y - scrollY;
                                    return top + height > -height && top < view.height + height;
                                }

                                width: Math.min(parent.width, 560)
                                height: Math.round(width * 9 / 16)
                                color: Tokens.tint5
                                border.color: Tokens.line
                                radius: Tokens.radius
                                clip: true

                                Loader {
                                    id: media
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    active: preview.nearViewport && !!card.modelData.preview
                                    sourceComponent: card.bundled ? stillPreview : animatedPreview
                                }

                                Component {
                                    id: stillPreview
                                    Image {
                                        source: card.modelData.preview
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize: Qt.size(
                                            Math.max(1, Math.round(preview.width * Screen.devicePixelRatio)),
                                            Math.max(1, Math.round(preview.height * Screen.devicePixelRatio))
                                        )
                                        asynchronous: true
                                    }
                                }

                                Component {
                                    id: animatedPreview
                                    AnimatedImage {
                                        source: card.modelData.preview
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        cache: false
                                        playing: !Tokens.reduceMotion
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !card.modelData.preview || (media.item && media.item.status === Image.Error)
                                    text: I18n.tr("Preview unavailable")
                                    color: Tokens.inkMuted
                                    font.family: Tokens.ui
                                    font.pixelSize: Tokens.fBody
                                }
                            }

                            Flow {
                                width: parent.width
                                spacing: Tokens.s3
                                Btn {
                                    text: card.activeTheme ? I18n.tr("Active") : I18n.tr("Use theme")
                                    enabled: !listThemes.running && !applyTheme.running && !card.activeTheme
                                    onAct: {
                                        page.errorMessage = "";
                                        page.pendingSlug = card.modelData.slug;
                                        applyTheme.command = ["tsukuyomi-lock-theme", "set", page.pendingSlug];
                                        applyTheme.running = true;
                                    }
                                }
                                Btn {
                                    text: I18n.tr("Lock to test")
                                    visible: card.activeTheme
                                    enabled: !listThemes.running && !applyTheme.running
                                    onAct: Quickshell.execDetached(["ryoku-shell", "lock"])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
