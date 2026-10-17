import QtQuick
import qs.Core
import qs.Services
import qs.Components.Controls
import qs.Components.Text

Card {
    id: card
    property var device: null
    readonly property var saved: Config.get("input.gestures") || ({})
    readonly property var directions: ["swipe","horizontal","vertical","left","right","up","down","pinchin","pinchout"]
    readonly property var labels: [I18n.tr("Any swipe"),I18n.tr("Horizontal swipe"),I18n.tr("Vertical swipe"),I18n.tr("Swipe left"),I18n.tr("Swipe right"),I18n.tr("Swipe up"),I18n.tr("Swipe down"),I18n.tr("Pinch out"),I18n.tr("Pinch in")]
    // The action picker lists the central catalogue (window actions, minimize
    // and restore, workspace, overview, launcher…), so a new Bifrost action
    // needs only a catalogue entry (hypr/keybinds.json gestureActions).
    readonly property var actions: InputDevices.gestureActions.map(a => ({ value: a.value, label: I18n.tr(a.label) }))
    BText { text: I18n.tr("Gestures"); role: "heading" }
    BText {
        width: parent.width
        text: I18n.tr("Gesture mappings are shared by all trackpads. Existing mappings are replaced only when you choose an action. Conflicting swipe mappings are disabled when you choose a new direction.")
        role: "caption"; tone: "muted"; wrapMode: Text.WordWrap
    }
    Repeater {
        model: card.device && card.device.capabilities.maxFingers >= 4 ? [3,4] : card.device && card.device.capabilities.maxFingers >= 3 ? [3] : []
        delegate: Column {
            required property int modelData
            id: fingers
            width: parent.width; spacing: Theme.space.sm
            BText { text: I18n.tr("%1-finger gestures").arg(fingers.modelData); role: "caption"; font.weight: Theme.font.weight.semibold; tone: "muted" }
            Repeater {
                model: card.directions
                // One row per direction: label left, action menu right
                // (stacked under the label when the card is narrow).
                delegate: Item {
                    required property string modelData
                    required property int index
                    id: gesture
                    readonly property string key: fingers.modelData+":"+modelData
                    readonly property var inherited: InputDevices.gestures[key]
                    readonly property bool stacked: width < Theme.layout.settingsEditorWidth * 2
                    width: parent.width
                    height: stacked ? name.implicitHeight + Theme.space.sm + menu.height : Math.max(name.implicitHeight, menu.height)
                    SettingsDivider {
                        visible: gesture.index > 0
                        x: SettingsStyle.groupInset
                        y: -Theme.space.sm / 2
                        width: parent.width - x
                    }
                    BText {
                        id: name
                        x: SettingsStyle.groupInset
                        y: gesture.stacked ? 0 : (parent.height - height) / 2
                        width: gesture.stacked ? parent.width - x : parent.width - menu.width - Theme.space.lg - x
                        text: card.labels[gesture.index]; role: "label"; elide: Text.ElideRight
                    }
                    BDropdown {
                        id: menu
                        x: gesture.stacked ? name.x : parent.width - width
                        y: gesture.stacked ? name.implicitHeight + Theme.space.sm : 0
                        width: gesture.stacked ? parent.width - name.x : Theme.layout.settingsEditorWidth
                        model: card.actions
                        currentValue: card.saved[gesture.key] !== undefined ? card.saved[gesture.key] : gesture.inherited ? gesture.inherited.action : ""
                        placeholder: gesture.inherited && gesture.inherited.custom ? I18n.tr("Custom compositor action") : I18n.tr("Existing configuration")
                        onActivated: action => InputDevices.setGesture(gesture.key,action)
                    }
                }
            }
        }
    }
}
