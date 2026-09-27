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
            width: parent.width; spacing: Theme.space.md
            BText { text: I18n.tr("%1-finger gestures").arg(fingers.modelData); role: "heading" }
            Repeater {
                model: card.directions
                delegate: Column {
                    required property string modelData
                    required property int index
                    id: gesture
                    readonly property string key: fingers.modelData+":"+modelData
                    readonly property var inherited: InputDevices.gestures[key]
                    width: parent.width; spacing: Theme.space.sm
                    BText { text: card.labels[gesture.index]; role: "label" }
                    BDropdown {
                        width: parent.width
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
