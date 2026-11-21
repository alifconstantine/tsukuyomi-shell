import QtQuick

// Material Symbols Rounded glyph helper for the Dynamic Notch.
Text {
    id: icon
    property real fill: 0
    renderType: Text.QtRendering
    font.family: "Material Symbols Rounded"
    font.variableAxes: ({ "FILL": icon.fill })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
