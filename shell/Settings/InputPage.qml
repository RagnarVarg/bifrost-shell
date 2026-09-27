import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text

Item {
    id: page
    readonly property string kind: SettingsNav.page.startsWith("input/") ? SettingsNav.page.slice(6) : ""
    Loader { anchors.fill: parent; sourceComponent: page.kind ? devicePage : hub }
    Component { id: devicePage; InputDevicePage { kind: page.kind } }
    Component { id: hub; PageBase {
        title: I18n.tr("Input")
        BText { width: parent.width; text: I18n.tr("Choose an input device category."); tone: "muted"; wrapMode: Text.WordWrap }
        SettingsRows { keys: ["input.resizeOnBorder"] }
        Repeater {
            model: [{kind:"keyboard",label:I18n.tr("Keyboard"),icon:"keyboard"},{kind:"gestures",label:I18n.tr("Gestures"),icon:"motion"},{kind:"mouse",label:I18n.tr("Mouse"),icon:"mouse"},{kind:"trackpad",label:I18n.tr("Trackpad"),icon:"trackpad"}]
            delegate: BButton {
                required property var modelData
                width: parent.width
                height: Theme.control.height.lg + Theme.space.xl
                size: "lg"
                text: modelData.label
                icon: modelData.icon
                onClicked: SettingsNav.open("input/"+modelData.kind)
            }
        }
    } }
}
