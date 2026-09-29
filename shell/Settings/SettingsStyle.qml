pragma Singleton
import QtQuick
import qs.Core

// Layout of the Settings window: rows in glass groups, spaced with the theme
// (appearance.density scales it like everything else) and adapted to the
// window's width (SettingsApp sets windowWidth, live while resizing):
// compact = one column (navigation or page), normal, wide = more room.
QtObject {
    // The Settings window's width; SettingsApp binds it.
    property real windowWidth: Theme.layout.settingsWidth

    readonly property string size: windowWidth < Theme.layout.settingsCompactBelow ? "compact" : windowWidth >= Theme.layout.settingsWideFrom ? "wide" : "normal"
    readonly property bool compact: size === "compact"
    readonly property bool wide: size === "wide"

    // Sidebar: full width in compact (it is the page then), else a column
    // that grows a little in wide windows.
    readonly property real sidebarWidth: compact ? windowWidth : wide ? Theme.layout.sidebarWideWidth : Theme.layout.sidebarWidth
    // Readable line length: the page grows with a wide window, up to a limit.
    readonly property real pageMaxWidth: wide ? Theme.layout.pageWideMaxWidth : Theme.layout.pageMaxWidth
    // Headings follow the window a little, never far from the theme's size.
    readonly property real titleScale: compact ? 0.9 : wide ? 1.08 : 1

    readonly property bool grouped: true
    readonly property real innerPadding: compact ? Theme.space.md : Theme.space.lg
    readonly property real groupSpacing: compact ? Theme.space.lg : wide ? Theme.space.xxl : Theme.space.xl
    readonly property real rowSpacing: Theme.space.sm
    readonly property real contentPadding: compact ? Theme.space.lg : wide ? Theme.space.xxxl + Theme.space.md : Theme.space.xxxl
    readonly property real separatorInset: compact ? Theme.space.lg : Theme.space.xl
    readonly property real titleSpacing: Theme.space.sm
    readonly property real descriptionSpacing: Theme.space.xxs
    readonly property bool background: true
    readonly property bool separators: true
    readonly property real dividerOpacity: 1
    readonly property bool dashed: false
    readonly property var material: Theme.materials.settingsGroups || Theme.materials.panel
}
