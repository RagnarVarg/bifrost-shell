pragma Singleton
import QtQuick
import qs.Core

// Layout of the Settings window: rows in glass groups, spaced with the theme
// (appearance.density scales it like everything else).
QtObject {
    readonly property bool grouped: true
    readonly property real innerPadding: Theme.space.lg
    readonly property real groupSpacing: Theme.space.xl
    readonly property real rowSpacing: Theme.space.sm
    readonly property real contentPadding: Theme.space.xxxl
    readonly property real separatorInset: Theme.space.xl
    readonly property real titleSpacing: Theme.space.sm
    readonly property real descriptionSpacing: Theme.space.xxs
    readonly property bool background: true
    readonly property bool separators: true
    readonly property real dividerOpacity: 1
    readonly property bool dashed: false
    readonly property var material: Theme.materials.settingsGroups || Theme.materials.panel
}
