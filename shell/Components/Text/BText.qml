import QtQuick
import qs.Core
import qs.Components.Motion

// Text styled by a typography role and a colour tone, both from tokens.
//   role: display | title | heading | body | label | caption | overline | mono | readout
//   tone: primary | muted | faint | accent | onAccent | success | warning | danger
Text {
    id: label

    property string role: "body"
    property string tone: "primary"

    readonly property var spec: Theme.typography[role] || Theme.typography.body
    readonly property var tones: ({
            primary: Theme.color.text,
            muted: Theme.color.textMuted,
            faint: Theme.color.textFaint,
            accent: Theme.color.accent,
            onAccent: Theme.color.onAccent,
            success: Theme.color.success,
            warning: Theme.color.warning,
            danger: Theme.color.danger
        })

    color: tones[tone] || Theme.color.text
    font.family: spec.family
    font.pixelSize: spec.size
    font.weight: spec.weight
    font.letterSpacing: spec.letterSpacing
    font.capitalization: spec.uppercase ? Font.AllUppercase : Font.MixedCase
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        BColorAnimation {}
    }
}
