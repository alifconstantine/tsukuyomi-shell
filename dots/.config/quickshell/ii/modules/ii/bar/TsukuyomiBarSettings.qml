pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ColumnLayout {
    id: root
    required property var catalogue
    readonly property var options: Config.options.tsukuyomi
    readonly property var modes: ["system", "dark", "light"]
    readonly property var logos: ["arch", "tux", "moon"]
    readonly property var accents: ["neutral", "preset", "custom", "wallpaper"]
    readonly property var presets: ["#6389bf", "#509478", "#ad7851", "#927cb7"]
    readonly property var orderedKeys: Array.from(new Set([...options.indicators, ...Object.keys(catalogue)]))
        .filter(key => key in root.catalogue)
    spacing: 8

    function moveIndicator(key, step) {
        const order = [...options.indicators];
        const index = order.indexOf(key);
        const next = index + step;
        if (index < 0 || next < 0 || next >= order.length) return;
        order[index] = order[next];
        order[next] = key;
        options.indicators = order;
    }

    component SettingsLabel: Text {
        Layout.fillWidth: true
        color: TsukuyomiStyle.foreground
        font.family: Appearance.font.family.main
        font.pixelSize: 13
    }
    RowLayout {
        SettingsLabel { text: Translation.tr("Appearance") }
        TsukuyomiComboBox {
            Accessible.name: Translation.tr("Appearance")
            model: [Translation.tr("System"), Translation.tr("Dark"), Translation.tr("Light")]
            currentIndex: Math.max(0, root.modes.indexOf(root.options.appearance))
            onActivated: index => root.options.appearance = root.modes[index]
        }
    }
    RowLayout {
        SettingsLabel { text: Translation.tr("Panel Material") }
        TsukuyomiComboBox {
            Accessible.name: Translation.tr("Panel Material")
            model: [Translation.tr("Frosted Glass"), Translation.tr("Solid")]
            currentIndex: root.options.glass ? 0 : 1
            onActivated: index => root.options.glass = index === 0
        }
    }
    RowLayout {
        SettingsLabel { text: Translation.tr("Bar Logo") }
        TsukuyomiComboBox {
            Accessible.name: Translation.tr("Bar Logo")
            model: ["Arch", "Tux", "月"]
            currentIndex: Math.max(0, root.logos.indexOf(root.options.logo))
            onActivated: index => root.options.logo = root.logos[index]
        }
    }
    RowLayout {
        SettingsLabel { text: Translation.tr("Accent Source") }
        TsukuyomiComboBox {
            Accessible.name: Translation.tr("Accent Source")
            model: [Translation.tr("Neutral"), Translation.tr("Preset"), "HEX", Translation.tr("Wallpaper")]
            currentIndex: Math.max(0, root.accents.indexOf(root.options.accentSource))
            onActivated: index => root.options.accentSource = root.accents[index]
        }
    }
    RowLayout {
        visible: root.options.accentSource === "preset"
        SettingsLabel { text: Translation.tr("Accent Preset") }
        TsukuyomiComboBox {
            Accessible.name: Translation.tr("Accent Preset")
            model: [Translation.tr("Blue"), Translation.tr("Green"), Translation.tr("Amber"), Translation.tr("Lavender")]
            currentIndex: Math.max(0, root.presets.indexOf(String(root.options.accentPreset)))
            onActivated: index => root.options.accentPreset = root.presets[index]
        }
    }
    RowLayout {
        visible: root.options.accentSource === "custom"
        SettingsLabel { text: Translation.tr("Custom Accent") }
        TextField {
            Accessible.name: Translation.tr("Custom Accent")
            Layout.preferredWidth: 148
            text: String(root.options.customAccent)
            color: TsukuyomiStyle.foreground
            maximumLength: 7
            validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}/ }
            onEditingFinished: {
                if (acceptableInput) root.options.customAccent = text;
                else text = String(root.options.customAccent);
            }
            background: Rectangle {
                radius: 8
                color: TsukuyomiStyle.raised
                border.color: TsukuyomiStyle.border
            }
        }
    }
    RowLayout {
        SettingsLabel { text: Translation.tr("Show Dock") }
        Switch {
            Accessible.name: Translation.tr("Show Dock")
            checked: Config.options.dock.enable
            onToggled: Config.options.dock.enable = checked
        }
    }
    SettingsLabel {
        text: Translation.tr("Status Indicators")
        font.weight: Font.DemiBold
    }
    Repeater {
        model: root.orderedKeys
        RowLayout {
            id: indicator
            required property string modelData
            readonly property int position: root.options.indicators.indexOf(modelData)
            readonly property string label: root.catalogue[modelData][0]
            CheckBox {
                id: toggleIndicator
                Layout.fillWidth: true
                implicitHeight: 28
                spacing: 8
                Accessible.name: indicator.label
                text: indicator.label
                checked: indicator.position >= 0
                indicator: Rectangle {
                    implicitWidth: 17
                    implicitHeight: 17
                    x: toggleIndicator.leftPadding
                    anchors.verticalCenter: parent.verticalCenter
                    color: toggleIndicator.checked ? TsukuyomiStyle.selection : TsukuyomiStyle.raised
                    border.color: toggleIndicator.visualFocus ? TsukuyomiStyle.foreground : TsukuyomiStyle.border
                    border.width: toggleIndicator.visualFocus ? 2 : 1
                    radius: 4
                    MaterialSymbol {
                        visible: toggleIndicator.checked
                        anchors.centerIn: parent
                        iconSize: 13
                        text: "check"
                        color: TsukuyomiStyle.foreground
                    }
                }
                contentItem: Text {
                    leftPadding: toggleIndicator.indicator.width + toggleIndicator.spacing
                    text: toggleIndicator.text
                    color: TsukuyomiStyle.foreground
                    font.family: Appearance.font.family.main
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                }
                onToggled: {
                    const key = indicator.modelData;
                    const order = root.options.indicators;
                    root.options.indicators = checked ? [...order, key] : order.filter(id => id !== key);
                }
            }
            TsukuyomiButton {
                glyph: "keyboard_arrow_up"
                description: Translation.tr("Move %1 Up").arg(indicator.label)
                enabled: indicator.position > 0
                onClicked: root.moveIndicator(indicator.modelData, -1)
            }
            TsukuyomiButton {
                glyph: "keyboard_arrow_down"
                description: Translation.tr("Move %1 Down").arg(indicator.label)
                enabled: indicator.position >= 0 && indicator.position < root.options.indicators.length - 1
                onClicked: root.moveIndicator(indicator.modelData, 1)
            }
        }
    }
}
