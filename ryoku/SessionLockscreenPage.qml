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
    property var themes: []
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
                page.themes = [{slug: page.defaultSlug, name: I18n.tr("Clockwork Orbital")}].concat(installed);
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

            Row {
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

            Repeater {
                model: page.themes
                delegate: SettingCard {
                    id: card
                    required property var modelData
                    width: parent.width
                    title: modelData.name || modelData.slug

                    Row {
                        spacing: Tokens.s3
                        Btn {
                            text: card.modelData.slug === page.activeSlug ? I18n.tr("Active") : I18n.tr("Use theme")
                            enabled: !listThemes.running && !applyTheme.running && card.modelData.slug !== page.activeSlug
                            onAct: {
                                page.errorMessage = "";
                                page.pendingSlug = card.modelData.slug;
                                applyTheme.command = ["tsukuyomi-lock-theme", "set", page.pendingSlug];
                                applyTheme.running = true;
                            }
                        }
                        Btn {
                            text: I18n.tr("Lock to preview")
                            enabled: !applyTheme.running
                            onAct: Quickshell.execDetached(["ryoku-qylock-lock", card.modelData.slug])
                        }
                    }
                }
            }
        }
    }
}
