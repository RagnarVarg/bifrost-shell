pragma Singleton
import QtQuick
import qs.Core

QtObject {
    readonly property bool grouped: Config.get("settingsUI.layout") !== "boxed"
    readonly property var values: Config.values.settingsUI ? Config.values.settingsUI.grouped || ({}) : ({})
    readonly property string densityName: values.density || "inherit"
    readonly property real factor: !grouped || densityName === "inherit" ? 1 : ((Theme.tokens.densityProfiles || {})[densityName] || Theme.density).space / Theme.density.space
    function size(key, fallback) { return grouped && values[key] !== null && values[key] !== undefined ? values[key] : fallback * factor; }
    readonly property real innerPadding: size("innerPadding",Theme.space.lg)
    readonly property real groupSpacing: size("groupSpacing",Theme.space.xl)
    readonly property real rowSpacing: size("rowSpacing",Theme.space.sm)
    readonly property real contentPadding: size("contentPadding",Theme.space.xxxl)
    readonly property real separatorInset: size("separatorInset",Theme.space.xl)
    readonly property real titleSpacing: size("titleSpacing",Theme.space.sm)
    readonly property real descriptionSpacing: size("descriptionSpacing",Theme.space.xxs)
    readonly property bool background: !grouped || values.background !== false
    readonly property bool separators: grouped && values.separators !== false
    readonly property real dividerOpacity: (values.dividerOpacity === undefined ? 100 : values.dividerOpacity) / 100
    readonly property bool dashed: values.dividerStyle === "dashed"
    readonly property var material: Theme.materials.settingsGroups || Theme.materials.panel
}
